#!perl

use v5.40;
use experimental qw[ class ];

use Test::More;

use ok 'Yakt::System';

class Hello   :isa(Yakt::Message) {}
class Goodbye :isa(Yakt::Message) {}

class Joe :isa(Yakt::Actor) {
    use Yakt::Logging;

    our $HELLO      = 0;
    our $GOODBYE    = 0;
    our $STARTED    = 0;
    our $RESTARTED  = 0;
    our $STOPPING   = 0;
    our $STOPPED    = 0;
    our $TERMINATED = 0;

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

    method on_terminated :Signal(Yakt::System::Signals::Terminated) ($context, $signal) {
        $TERMINATED++;
        $context->logger->log( INFO, sprintf 'Got Terminated(%s)' => $signal->ref ) if INFO;
        $context->stop;
    }

    method hello :Receive(Hello) ($context, $message) {
        $HELLO++;
        $context->logger->log(INFO, "HELLO JOE! => { Actor($self), $context, message($message) }" ) if INFO;

        my $other_joe = $message->sender;
        $context->watch( $other_joe );

        $other_joe->send(Goodbye->new);
    }

    method goodbye :Receive(Goodbye) ($context, $message) {
        $GOODBYE++;
        $context->logger->log(INFO, "GOODBYE JOE! => { Actor($self), $context, message($message) }" ) if INFO;
        $context->stop;
    }
}

my $sys = Yakt::System->new->init(sub ($context) {
    my $joe1 = $context->spawn( Yakt::Props->new( class => 'Joe' ) );
    my $joe2 = $context->spawn( Yakt::Props->new( class => 'Joe' ) );

    $joe1->send(Hello->new( sender => $joe2 ));
});

$sys->loop_until_done;

is($Joe::HELLO,     1, '... got the expected hello message');
is($Joe::GOODBYE,   1, '... got the expected goodbye message');
is($Joe::RESTARTED, 0, '... got the expected restarted');
is($Joe::STARTED,   2, '... got the expected started');
is($Joe::STOPPING,  2, '... got the expected stopping');
is($Joe::STOPPED,   2, '... got the expected stopped');
is($Joe::TERMINATED,1, '... got the expected terminated');

done_testing;

