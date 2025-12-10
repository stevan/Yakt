#!perl

use v5.40;
use experimental qw[ class ];

use Test::More;

use ok 'Yakt::System';

class Ping :isa(Yakt::Message) {}
class Pong :isa(Yakt::Message) {}
class Done :isa(Yakt::Message) {}

class PingActor :isa(Yakt::Actor) {
    our $PONG_COUNT = 0;

    field $ponger :param;

    method on_started :Signal(Yakt::System::Signals::Started) ($context, $signal) {
        $ponger->send(Ping->new( sender => $context->self ));
    }

    method on_pong :Receive(Pong) ($context, $message) {
        $PONG_COUNT++;
        $context->stop;
    }
}

class PongActor :isa(Yakt::Actor) {
    our $PING_COUNT = 0;

    method on_ping :Receive(Ping) ($context, $message) {
        $PING_COUNT++;
        $message->sender->send(Pong->new);
        $context->stop;
    }
}

subtest 'send_message delivers message to target actor' => sub {
    $PingActor::PONG_COUNT = 0;
    $PongActor::PING_COUNT = 0;

    my $sys = Yakt::System->new->init(sub ($context) {
        my $ponger = $context->spawn(Yakt::Props->new( class => 'PongActor' ));
        $context->spawn(Yakt::Props->new(
            class => 'PingActor',
            args  => { ponger => $ponger }
        ));
    });

    $sys->loop_until_done;

    is($PongActor::PING_COUNT, 1, '... Ping was delivered to PongActor');
    is($PingActor::PONG_COUNT, 1, '... Pong was delivered to PingActor');
};

class CountingActor :isa(Yakt::Actor) {
    our $COUNT = 0;

    method on_ping :Receive(Ping) ($context, $message) {
        $COUNT++;
        if ($COUNT >= 5) {
            $context->stop;
        }
    }
}

subtest 'multiple messages delivered in order' => sub {
    $CountingActor::COUNT = 0;

    my $sys = Yakt::System->new->init(sub ($context) {
        my $counter = $context->spawn(Yakt::Props->new( class => 'CountingActor' ));

        for (1..5) {
            $counter->send(Ping->new);
        }
    });

    $sys->loop_until_done;

    is($CountingActor::COUNT, 5, '... all messages delivered');
};

done_testing;
