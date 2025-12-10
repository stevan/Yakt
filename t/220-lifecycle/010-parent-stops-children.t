#!perl

use v5.40;
use experimental qw[ class ];

use Test::More;

use ok 'Yakt::System';

class ChildActor :isa(Yakt::Actor) {
    our $STARTED_COUNT = 0;
    our $STOPPED_COUNT = 0;

    method on_started :Signal(Yakt::System::Signals::Started) ($context, $signal) {
        $STARTED_COUNT++;
    }

    method on_stopped :Signal(Yakt::System::Signals::Stopped) ($context, $signal) {
        $STOPPED_COUNT++;
    }
}

class StopParent :isa(Yakt::Message) {}

class ParentActor :isa(Yakt::Actor) {
    our $STARTED = 0;
    our $STOPPED = 0;

    method on_started :Signal(Yakt::System::Signals::Started) ($context, $signal) {
        $STARTED++;
        # Spawn children
        $context->spawn(Yakt::Props->new( class => 'ChildActor' ));
        $context->spawn(Yakt::Props->new( class => 'ChildActor' ));
        $context->spawn(Yakt::Props->new( class => 'ChildActor' ));
    }

    method on_stopped :Signal(Yakt::System::Signals::Stopped) ($context, $signal) {
        $STOPPED++;
    }

    method on_stop :Receive(StopParent) ($context, $message) {
        $context->stop;
    }
}

subtest 'Stopping parent stops all children' => sub {
    $ChildActor::STARTED_COUNT = 0;
    $ChildActor::STOPPED_COUNT = 0;
    $ParentActor::STARTED = 0;
    $ParentActor::STOPPED = 0;

    my $sys = Yakt::System->new->init(sub ($context) {
        my $parent = $context->spawn(Yakt::Props->new( class => 'ParentActor' ));

        # Give children time to start, then stop parent
        $context->schedule(
            after    => 0.01,
            callback => sub { $parent->send(StopParent->new) }
        );
    });

    $sys->loop_until_done;

    is($ChildActor::STARTED_COUNT, 3, '... all children started');
    is($ChildActor::STOPPED_COUNT, 3, '... all children stopped when parent stopped');
    is($ParentActor::STARTED, 1, '... parent started');
    is($ParentActor::STOPPED, 1, '... parent stopped');
};

done_testing;
