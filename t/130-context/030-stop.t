#!perl

use v5.40;
use experimental qw[ class ];

use Test::More;

use ok 'Yakt::System';

class StopSelf :isa(Yakt::Message) {}

class StoppableActor :isa(Yakt::Actor) {
    our $STARTED  = 0;
    our $STOPPING = 0;
    our $STOPPED  = 0;

    method on_started :Signal(Yakt::System::Signals::Started) ($context, $signal) {
        $STARTED++;
    }

    method on_stopping :Signal(Yakt::System::Signals::Stopping) ($context, $signal) {
        $STOPPING++;
    }

    method on_stopped :Signal(Yakt::System::Signals::Stopped) ($context, $signal) {
        $STOPPED++;
    }

    method on_stop_self :Receive(StopSelf) ($context, $message) {
        $context->stop;
    }
}

subtest 'context->stop triggers shutdown sequence' => sub {
    $StoppableActor::STARTED  = 0;
    $StoppableActor::STOPPING = 0;
    $StoppableActor::STOPPED  = 0;

    my $sys = Yakt::System->new->init(sub ($context) {
        my $actor = $context->spawn(Yakt::Props->new( class => 'StoppableActor' ));
        $actor->send(StopSelf->new);
    });

    $sys->loop_until_done;

    is($StoppableActor::STARTED, 1, '... Started signal received');
    is($StoppableActor::STOPPING, 1, '... Stopping signal received');
    is($StoppableActor::STOPPED, 1, '... Stopped signal received');
};

class ImmediateStopActor :isa(Yakt::Actor) {
    our $STOPPED = 0;

    method on_started :Signal(Yakt::System::Signals::Started) ($context, $signal) {
        $context->stop;
    }

    method on_stopped :Signal(Yakt::System::Signals::Stopped) ($context, $signal) {
        $STOPPED++;
    }
}

subtest 'stop can be called from Started handler' => sub {
    $ImmediateStopActor::STOPPED = 0;

    my $sys = Yakt::System->new->init(sub ($context) {
        $context->spawn(Yakt::Props->new( class => 'ImmediateStopActor' ));
    });

    $sys->loop_until_done;

    is($ImmediateStopActor::STOPPED, 1, '... actor stopped from Started handler');
};

done_testing;
