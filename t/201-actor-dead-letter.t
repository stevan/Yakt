#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

use Test::More;

use ok 'Acktor::System';

class Hello {}
class Goodbye {}

class Joe :isa(Acktor) {
    use Acktor::Logging;

    our $MESSAGED   = 0;
    our $UNHANDLED  = 0;
    our $STARTED    = 0;
    our $RESTARTED  = 0;
    our $STOPPING   = 0;
    our $STOPPED    = 0;

    method on_start :Signal(Acktor::System::Signals::Started) ($context, $signal) {
        $STARTED++;
        $self->logger->log(INFO, sprintf 'Started %s' => $context->self ) if INFO;
    }

    method on_stopping :Signal(Acktor::System::Signals::Stopping) ($context, $signal) {
        $STOPPING++;
        $self->logger->log( INFO, sprintf 'Stopping %s' => $context->self ) if INFO
    }

    method on_restarting :Signal(Acktor::System::Signals::Restarting) ($context, $signal) {
        $RESTARTED++;
        $self->logger->log( INFO, sprintf 'Restarting %s' => $context->self ) if INFO
    }

    method on_stopped :Signal(Acktor::System::Signals::Stopped) ($context, $signal) {
        $STOPPED++;
        $self->logger->log( INFO, sprintf 'Stopped %s' => $context->self ) if INFO
    }

    method hello :Receive(Hello) ($context, $message) {
        $MESSAGED++;
        $self->logger->log(INFO, "HELLO JOE! => { Actor($self), $context, message($message) }" ) if INFO;
        $context->self->send(Goodbye->new);
    }

    method apply ($context, $message) {
        $UNHANDLED++;
        $self->logger->log(INFO, "Unknown Message { Actor($self), $context, message($message) }" ) if INFO;
        $context->stop;
        return false;
    }
}

my $sys = Acktor::System->new->init(sub ($context) {
    my $joe = $context->spawn( Acktor::Props->new( class => 'Joe' ) );
    $joe->send(Hello->new);
});

$sys->loop_until_done;

is($Joe::MESSAGED,  1, '... got the expected messaged');
is($Joe::UNHANDLED, 1, '... got the expected unhandled');
is($Joe::RESTARTED, 0, '... got the expected restarted');
is($Joe::STARTED,   1, '... got the expected started');
is($Joe::STOPPING,  1, '... got the expected stopping');
is($Joe::STOPPED,   1, '... got the expected stopped');

done_testing;

