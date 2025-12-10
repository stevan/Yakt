#!perl

use v5.40;
use experimental qw[ class ];

use Test::More;

use ok 'Yakt::System';

class ChildOfRestarting :isa(Yakt::Actor) {
    our $STARTED_COUNT = 0;
    our $STOPPED_COUNT = 0;

    method on_started :Signal(Yakt::System::Signals::Started) ($context, $signal) {
        $STARTED_COUNT++;
    }

    method on_stopped :Signal(Yakt::System::Signals::Stopped) ($context, $signal) {
        $STOPPED_COUNT++;
    }
}

class FailAndRestart :isa(Yakt::Message) {}
class StopNow :isa(Yakt::Message) {}

class RestartingParent :isa(Yakt::Actor) {
    our $STARTED_COUNT    = 0;
    our $RESTARTING_COUNT = 0;
    our $CHILDREN_AFTER_RESTART = 0;

    method on_started :Signal(Yakt::System::Signals::Started) ($context, $signal) {
        $STARTED_COUNT++;
        # Spawn children on each start
        $context->spawn(Yakt::Props->new( class => 'ChildOfRestarting' ));
        $context->spawn(Yakt::Props->new( class => 'ChildOfRestarting' ));

        if ($STARTED_COUNT > 1) {
            $CHILDREN_AFTER_RESTART = scalar $context->children;
        }
    }

    method on_restarting :Signal(Yakt::System::Signals::Restarting) ($context, $signal) {
        $RESTARTING_COUNT++;
    }

    method on_fail :Receive(FailAndRestart) ($context, $message) {
        die "Intentional failure to trigger restart";
    }

    method on_stop :Receive(StopNow) ($context, $message) {
        $context->stop;
    }
}

subtest 'Children are stopped when parent restarts' => sub {
    $ChildOfRestarting::STARTED_COUNT = 0;
    $ChildOfRestarting::STOPPED_COUNT = 0;
    $RestartingParent::STARTED_COUNT = 0;
    $RestartingParent::RESTARTING_COUNT = 0;
    $RestartingParent::CHILDREN_AFTER_RESTART = 0;

    my $sys = Yakt::System->new->init(sub ($context) {
        my $parent = $context->spawn(Yakt::Props->new(
            class      => 'RestartingParent',
            supervisor => Yakt::System::Supervisors::Restart->new
        ));

        $parent->send(FailAndRestart->new);
        $parent->send(StopNow->new);
    });

    $sys->loop_until_done;

    is($RestartingParent::STARTED_COUNT, 2, '... parent started twice');
    is($RestartingParent::RESTARTING_COUNT, 1, '... parent restarted once');
    is($ChildOfRestarting::STARTED_COUNT, 4, '... 4 children started (2 before + 2 after restart)');
    is($ChildOfRestarting::STOPPED_COUNT, 4, '... all 4 children stopped');
    is($RestartingParent::CHILDREN_AFTER_RESTART, 2, '... parent has 2 fresh children after restart');
};

done_testing;
