#!perl

use v5.40;
use experimental qw[ class ];

use Test::More;

use ok 'Yakt::System';

class Ping :isa(Yakt::Message) {}
class Pong :isa(Yakt::Message) {}

class Sender :isa(Yakt::Actor) {
    our $PONG_COUNT = 0;

    field $target;

    method on_start :Signal(Yakt::System::Signals::Started) ($context, $signal) {
        # Spawn target, watch it so we get notified when it stops
        $target = $context->spawn( Yakt::Props->new( class => 'Stopper' ) );
        $context->watch( $target );
    }

    method on_terminated :Signal(Yakt::System::Signals::Terminated) ($context, $signal) {
        # Target has stopped, try to send to it
        $target->send(Ping->new( sender => $context->self ));

        # Schedule stop after a tick to let any responses arrive
        $context->schedule( after => 0.05, callback => sub {
            $context->stop;
        });
    }

    method pong :Receive(Pong) ($context, $message) {
        $PONG_COUNT++;  # Should not happen
    }
}

class Stopper :isa(Yakt::Actor) {
    method on_start :Signal(Yakt::System::Signals::Started) ($context, $signal) {
        $context->stop;  # Stop immediately
    }

    method ping :Receive(Ping) ($context, $message) {
        # Should never be called - we're stopped
        $message->sender->send(Pong->new);
    }
}

my $sys = Yakt::System->new->init(sub ($context) {
    $context->spawn( Yakt::Props->new( class => 'Sender' ) );
});

$sys->loop_until_done;

is($Sender::PONG_COUNT, 0, '... no pong received (message to stopped actor was dropped)');

done_testing;
