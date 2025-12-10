#!perl

use v5.40;
use experimental qw[ class ];

use Test::More;

use ok 'Yakt::System';

# Test that Props alias is properly registered in the system

class Ping :isa(Yakt::Message) {}
class Pong :isa(Yakt::Message) {}

class AliasedActor :isa(Yakt::Actor) {
    our $RECEIVED = 0;

    method on_ping :Receive(Ping) ($context, $message) {
        $RECEIVED++;
        $context->stop;
    }
}

subtest 'Actor with alias can be looked up' => sub {
    $AliasedActor::RECEIVED = 0;

    my $sys = Yakt::System->new->init(sub ($context) {
        my $actor = $context->spawn(Yakt::Props->new(
            class => 'AliasedActor',
            alias => '//usr/my-actor'
        ));

        # Send message to the actor
        $actor->send(Ping->new);
    });

    $sys->loop_until_done;

    is($AliasedActor::RECEIVED, 1, '... actor received the message');
};

done_testing;
