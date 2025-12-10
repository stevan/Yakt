#!perl

use v5.40;
use experimental qw[ class ];

use Test::More;

use ok 'Yakt::System';

class StopMe :isa(Yakt::Message) {}

# An actor that handles NO signals - should still work fine
class NoSignalHandlerActor :isa(Yakt::Actor) {
    our $MESSAGE_COUNT = 0;

    method on_stop :Receive(StopMe) ($context, $message) {
        $MESSAGE_COUNT++;
        $context->stop;
    }
}

subtest 'Actor without signal handlers still processes lifecycle' => sub {
    $NoSignalHandlerActor::MESSAGE_COUNT = 0;

    my $sys = Yakt::System->new->init(sub ($context) {
        my $actor = $context->spawn(Yakt::Props->new( class => 'NoSignalHandlerActor' ));
        $actor->send(StopMe->new);
    });

    $sys->loop_until_done;

    is($NoSignalHandlerActor::MESSAGE_COUNT, 1, '... actor processed message despite no signal handlers');
};

# An actor that only handles Started
class PartialSignalActor :isa(Yakt::Actor) {
    our $STARTED = 0;
    our $STOPPED = 0;

    method on_started :Signal(Yakt::System::Signals::Started) ($context, $signal) {
        $STARTED++;
    }

    # Note: No Stopping or Stopped handlers

    method on_stop :Receive(StopMe) ($context, $message) {
        $context->stop;
    }
}

subtest 'Actor with partial signal handlers works correctly' => sub {
    $PartialSignalActor::STARTED = 0;
    $PartialSignalActor::STOPPED = 0;

    my $sys = Yakt::System->new->init(sub ($context) {
        my $actor = $context->spawn(Yakt::Props->new( class => 'PartialSignalActor' ));
        $actor->send(StopMe->new);
    });

    $sys->loop_until_done;

    is($PartialSignalActor::STARTED, 1, '... Started handler was called');
    # Stopped handler doesn't exist, but actor should still stop cleanly
};

done_testing;
