#!perl

use v5.40;
use experimental qw[ class ];

use Test::More;

use ok 'Yakt::System';

class StopNow :isa(Yakt::Message) {}

class WatchedActor :isa(Yakt::Actor) {
    method on_stop :Receive(StopNow) ($context, $message) {
        $context->stop;
    }
}

class WatcherActor :isa(Yakt::Actor) {
    our $TERMINATED_COUNT = 0;
    our $TERMINATED_REF;

    field $to_watch :param;

    method on_started :Signal(Yakt::System::Signals::Started) ($context, $signal) {
        $context->watch($to_watch);
        # Tell the watched actor to stop
        $to_watch->send(StopNow->new);
    }

    method on_terminated :Signal(Yakt::System::Signals::Terminated) ($context, $signal) {
        $TERMINATED_COUNT++;
        $TERMINATED_REF = $signal->ref;
        $context->stop;
    }
}

subtest 'watch receives Terminated when watched actor stops' => sub {
    $WatcherActor::TERMINATED_COUNT = 0;
    $WatcherActor::TERMINATED_REF = undef;

    my $watched_ref;
    my $sys = Yakt::System->new->init(sub ($context) {
        my $watched = $context->spawn(Yakt::Props->new( class => 'WatchedActor' ));
        $watched_ref = $watched;

        $context->spawn(Yakt::Props->new(
            class => 'WatcherActor',
            args  => { to_watch => $watched }
        ));
    });

    $sys->loop_until_done;

    is($WatcherActor::TERMINATED_COUNT, 1, '... watcher received Terminated');
    is($WatcherActor::TERMINATED_REF->pid, $watched_ref->pid, '... Terminated ref matches watched actor');
};

class MultiWatcherActor :isa(Yakt::Actor) {
    our $TERMINATED_COUNT = 0;

    field $to_watch :param;

    method on_started :Signal(Yakt::System::Signals::Started) ($context, $signal) {
        for my $actor (@$to_watch) {
            $context->watch($actor);
            $actor->send(StopNow->new);
        }
    }

    method on_terminated :Signal(Yakt::System::Signals::Terminated) ($context, $signal) {
        $TERMINATED_COUNT++;
        if ($TERMINATED_COUNT >= 3) {
            $context->stop;
        }
    }
}

subtest 'can watch multiple actors' => sub {
    $MultiWatcherActor::TERMINATED_COUNT = 0;

    my $sys = Yakt::System->new->init(sub ($context) {
        my @watched = map {
            $context->spawn(Yakt::Props->new( class => 'WatchedActor' ))
        } 1..3;

        $context->spawn(Yakt::Props->new(
            class => 'MultiWatcherActor',
            args  => { to_watch => \@watched }
        ));
    });

    $sys->loop_until_done;

    is($MultiWatcherActor::TERMINATED_COUNT, 3, '... received Terminated for all watched actors');
};

done_testing;
