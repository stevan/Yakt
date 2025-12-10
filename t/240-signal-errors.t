#!perl

use v5.40;
use experimental qw[ class ];

use Test::More;

use ok 'Yakt::System';

class Ping {}

# Actor that fails on Started
class FailOnStart :isa(Yakt::Actor) {
    our $STARTED = 0;
    our $STOPPED = 0;

    method on_start :Signal(Yakt::System::Signals::Started) ($context, $signal) {
        $STARTED++;
        die "Failed to start!";
    }

    method on_stopped :Signal(Yakt::System::Signals::Stopped) ($context, $signal) {
        $STOPPED++;
    }

    method ping :Receive(Ping) ($context, $message) {
        # Should never be called
        die "Should not receive messages!";
    }
}

# Actor that fails on custom signal (Ready)
class FailOnReady :isa(Yakt::Actor) {
    our $STARTED = 0;
    our $READY_FAILED = 0;
    our $STOPPED = 0;

    method on_start :Signal(Yakt::System::Signals::Started) ($context, $signal) {
        $STARTED++;
        # Notify self with Ready to trigger the error
        $context->notify(Yakt::System::Signals::Ready->new( ref => $context->self ));
    }

    method on_ready :Signal(Yakt::System::Signals::Ready) ($context, $signal) {
        $READY_FAILED++;
        die "Failed on Ready!";
    }

    method on_stopped :Signal(Yakt::System::Signals::Stopped) ($context, $signal) {
        $STOPPED++;
    }
}

subtest 'Actor that fails on Started is stopped' => sub {
    local $FailOnStart::STARTED = 0;
    local $FailOnStart::STOPPED = 0;

    my $sys = Yakt::System->new->init(sub ($context) {
        my $actor = $context->spawn( Yakt::Props->new( class => 'FailOnStart' ) );
        $actor->send(Ping->new);  # Should go to dead letters
    });

    $sys->loop_until_done;

    is($FailOnStart::STARTED, 1, '... Started was called');
    is($FailOnStart::STOPPED, 1, '... actor was stopped after Start failure');
};

subtest 'Actor that fails on Ready is stopped by supervisor' => sub {
    local $FailOnReady::STARTED = 0;
    local $FailOnReady::READY_FAILED = 0;
    local $FailOnReady::STOPPED = 0;

    my $sys = Yakt::System->new->init(sub ($context) {
        $context->spawn( Yakt::Props->new( class => 'FailOnReady' ) );
    });

    $sys->loop_until_done;

    is($FailOnReady::STARTED, 1, '... Started was called');
    is($FailOnReady::READY_FAILED, 1, '... Ready handler was called');
    is($FailOnReady::STOPPED, 1, '... actor was stopped after Ready failure');
};

done_testing;
