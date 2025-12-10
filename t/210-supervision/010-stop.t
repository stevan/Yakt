#!perl

use v5.40;
use experimental qw[ class ];

use Test::More;

use ok 'Yakt::System';

class FailingMessage :isa(Yakt::Message) {}

class StopOnErrorActor :isa(Yakt::Actor) {
    our $STARTED  = 0;
    our $MESSAGES = 0;
    our $STOPPED  = 0;

    method on_started :Signal(Yakt::System::Signals::Started) ($context, $signal) {
        $STARTED++;
    }

    method on_stopped :Signal(Yakt::System::Signals::Stopped) ($context, $signal) {
        $STOPPED++;
    }

    method on_fail :Receive(FailingMessage) ($context, $message) {
        $MESSAGES++;
        die "Intentional error!";
    }
}

subtest 'Stop supervisor stops actor on error (default behavior)' => sub {
    $StopOnErrorActor::STARTED  = 0;
    $StopOnErrorActor::MESSAGES = 0;
    $StopOnErrorActor::STOPPED  = 0;

    my $sys = Yakt::System->new->init(sub ($context) {
        my $actor = $context->spawn(Yakt::Props->new(
            class => 'StopOnErrorActor'
            # Default supervisor is Stop
        ));
        $actor->send(FailingMessage->new);
    });

    $sys->loop_until_done;

    is($StopOnErrorActor::STARTED, 1, '... Started once');
    is($StopOnErrorActor::MESSAGES, 1, '... Message received once');
    is($StopOnErrorActor::STOPPED, 1, '... Stopped after error');
};

subtest 'Stop supervisor with explicit configuration' => sub {
    $StopOnErrorActor::STARTED  = 0;
    $StopOnErrorActor::MESSAGES = 0;
    $StopOnErrorActor::STOPPED  = 0;

    my $sys = Yakt::System->new->init(sub ($context) {
        my $actor = $context->spawn(Yakt::Props->new(
            class      => 'StopOnErrorActor',
            supervisor => Yakt::System::Supervisors::Stop->new
        ));
        $actor->send(FailingMessage->new);
    });

    $sys->loop_until_done;

    is($StopOnErrorActor::STARTED, 1, '... Started once');
    is($StopOnErrorActor::STOPPED, 1, '... Stopped after error');
};

done_testing;
