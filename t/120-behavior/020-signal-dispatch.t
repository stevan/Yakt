#!perl

use v5.40;
use experimental qw[ class ];

use Test::More;

use ok 'Yakt::System';

class DoStop :isa(Yakt::Message) {}

class SignalActor :isa(Yakt::Actor) {
    our $STARTED_COUNT    = 0;
    our $STOPPING_COUNT   = 0;
    our $STOPPED_COUNT    = 0;
    our $RESTARTING_COUNT = 0;

    method on_started :Signal(Yakt::System::Signals::Started) ($context, $signal) {
        $STARTED_COUNT++;
    }

    method on_stopping :Signal(Yakt::System::Signals::Stopping) ($context, $signal) {
        $STOPPING_COUNT++;
    }

    method on_stopped :Signal(Yakt::System::Signals::Stopped) ($context, $signal) {
        $STOPPED_COUNT++;
    }

    method on_restarting :Signal(Yakt::System::Signals::Restarting) ($context, $signal) {
        $RESTARTING_COUNT++;
    }

    method do_stop :Receive(DoStop) ($context, $message) {
        $context->stop;
    }
}

subtest 'Lifecycle signals dispatch to correct handlers' => sub {
    $SignalActor::STARTED_COUNT    = 0;
    $SignalActor::STOPPING_COUNT   = 0;
    $SignalActor::STOPPED_COUNT    = 0;
    $SignalActor::RESTARTING_COUNT = 0;

    my $sys = Yakt::System->new->init(sub ($context) {
        my $actor = $context->spawn(Yakt::Props->new( class => 'SignalActor' ));
        $actor->send(DoStop->new);
    });

    $sys->loop_until_done;

    is($SignalActor::STARTED_COUNT, 1, '... Started signal received');
    is($SignalActor::STOPPING_COUNT, 1, '... Stopping signal received');
    is($SignalActor::STOPPED_COUNT, 1, '... Stopped signal received');
    is($SignalActor::RESTARTING_COUNT, 0, '... Restarting signal not received');
};

done_testing;
