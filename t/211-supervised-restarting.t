#!perl

use v5.40;
use experimental qw[ class ];

use Test::More;

use ok 'Yakt::System';

class Hello {
    field $count = 0;

    ADJUST { $count++ }

    method count { $count++; $self }
    method total { $count }
}

class Joe :isa(Yakt::Actor) {
    use Yakt::Logging;

    our $MESSAGED    = 0;
    our $STARTED     = 0;
    our $RESTARTED   = 0;
    our $STOPPING    = 0;
    our $STOPPED     = 0;
    our $TOTAL_HELLO = 0;

    method on_start :Signal(Yakt::System::Signals::Started) ($context, $signal) {
        $STARTED++;
        $context->logger->log(INFO, sprintf 'Started %s' => $context->self ) if INFO;
    }

    method on_stopping :Signal(Yakt::System::Signals::Stopping) ($context, $signal) {
        $STOPPING++;
        $context->logger->log( INFO, sprintf 'Stopping %s' => $context->self ) if INFO
    }

    method on_restarting :Signal(Yakt::System::Signals::Restarting) ($context, $signal) {
        $RESTARTED++;
        $context->logger->log( INFO, sprintf 'Restarting %s' => $context->self ) if INFO
    }

    method on_stopped :Signal(Yakt::System::Signals::Stopped) ($context, $signal) {
        $STOPPED++;
        $context->logger->log( INFO, sprintf 'Stopped %s' => $context->self ) if INFO
    }

    method hello :Receive(Hello) ($context, $message) {
        $MESSAGED++;
        $context->logger->log(INFO, "HELLO JOE! => { Actor($self), $context, message($message) }" ) if INFO;
        $context->logger->log(INFO, "... called ". $message->total ." times") if INFO;
        if ($RESTARTED < 5) {
            $context->self->send($message->count);
            die 'OH NOES!';
        }
        else {
            $context->logger->log(INFO, "!!! max restarts, ... stopping". $message->total ." times") if INFO;
            $TOTAL_HELLO = $message->total;
            $context->stop;
            return true;
        }
    }
}

my $sys = Yakt::System->new->init(sub ($context) {
    my $joe = $context->spawn(Yakt::Props->new(
        class      => 'Joe',
        supervisor => Yakt::System::Supervisors::Restart->new
    ));
    $joe->send(Hello->new);
});

$sys->loop_until_done;

is($Joe::MESSAGED,    6, '... got the expected messaged');
is($Joe::RESTARTED,   5, '... got the expected restarted');
is($Joe::STARTED,     6, '... got the expected started');
is($Joe::STOPPING,    1, '... got the expected stopping');
is($Joe::STOPPED,     1, '... got the expected stopped');
is($Joe::TOTAL_HELLO, 6, '... got the expected Hello->total');

done_testing;

