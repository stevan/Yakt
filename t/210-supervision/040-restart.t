#!perl

use v5.40;
use experimental qw[ class ];

use Test::More;

use ok 'Yakt::System';

class FailMessage :isa(Yakt::Message) {}
class StopMessage :isa(Yakt::Message) {}

class RestartingActor :isa(Yakt::Actor) {
    our $STARTED_COUNT    = 0;
    our $RESTARTING_COUNT = 0;
    our $FAIL_COUNT       = 0;

    method on_started :Signal(Yakt::System::Signals::Started) ($context, $signal) {
        $STARTED_COUNT++;
    }

    method on_restarting :Signal(Yakt::System::Signals::Restarting) ($context, $signal) {
        $RESTARTING_COUNT++;
    }

    method on_fail :Receive(FailMessage) ($context, $message) {
        $FAIL_COUNT++;
        die "Intentional failure";
    }

    method on_stop :Receive(StopMessage) ($context, $message) {
        $context->stop;
    }
}

subtest 'Restart supervisor restarts actor on error' => sub {
    $RestartingActor::STARTED_COUNT    = 0;
    $RestartingActor::RESTARTING_COUNT = 0;
    $RestartingActor::FAIL_COUNT       = 0;

    my $sys = Yakt::System->new->init(sub ($context) {
        my $actor = $context->spawn(Yakt::Props->new(
            class      => 'RestartingActor',
            supervisor => Yakt::System::Supervisors::Restart->new
        ));

        $actor->send(FailMessage->new);
        $actor->send(StopMessage->new);
    });

    $sys->loop_until_done;

    is($RestartingActor::FAIL_COUNT, 1, '... failed once');
    is($RestartingActor::RESTARTING_COUNT, 1, '... Restarting signal received');
    is($RestartingActor::STARTED_COUNT, 2, '... Started twice (initial + after restart)');
};

class MultiRestartActor :isa(Yakt::Actor) {
    our $STARTED_COUNT = 0;
    our $FAIL_COUNT    = 0;
    our $MAX_FAILS     = 3;

    method on_started :Signal(Yakt::System::Signals::Started) ($context, $signal) {
        $STARTED_COUNT++;
    }

    method on_fail :Receive(FailMessage) ($context, $message) {
        $FAIL_COUNT++;
        if ($FAIL_COUNT < $MAX_FAILS) {
            die "Failure $FAIL_COUNT";
        }
        $context->stop;
    }
}

subtest 'Restart supervisor can restart multiple times' => sub {
    $MultiRestartActor::STARTED_COUNT = 0;
    $MultiRestartActor::FAIL_COUNT    = 0;
    $MultiRestartActor::MAX_FAILS     = 3;

    my $sys = Yakt::System->new->init(sub ($context) {
        my $actor = $context->spawn(Yakt::Props->new(
            class      => 'MultiRestartActor',
            supervisor => Yakt::System::Supervisors::Restart->new
        ));

        # Send multiple fail messages
        $actor->send(FailMessage->new);
        $actor->send(FailMessage->new);
        $actor->send(FailMessage->new);
    });

    $sys->loop_until_done;

    is($MultiRestartActor::FAIL_COUNT, 3, '... received 3 fail messages');
    is($MultiRestartActor::STARTED_COUNT, 3, '... restarted 3 times');
};

done_testing;
