#!perl

use v5.40;
use experimental qw[ class ];

use Test::More;

use ok 'Yakt::System';

class Greeting :isa(Yakt::Message) {}
class Farewell :isa(Yakt::Message) {}

class GreeterActor :isa(Yakt::Actor) {
    our $GREETING_COUNT = 0;
    our $FAREWELL_COUNT = 0;

    method on_greeting :Receive(Greeting) ($context, $message) {
        $GREETING_COUNT++;
    }

    method on_farewell :Receive(Farewell) ($context, $message) {
        $FAREWELL_COUNT++;
        $context->stop;
    }
}

subtest 'Messages dispatch to correct handler' => sub {
    $GreeterActor::GREETING_COUNT = 0;
    $GreeterActor::FAREWELL_COUNT = 0;

    my $sys = Yakt::System->new->init(sub ($context) {
        my $greeter = $context->spawn(Yakt::Props->new( class => 'GreeterActor' ));

        $greeter->send(Greeting->new);
        $greeter->send(Greeting->new);
        $greeter->send(Farewell->new);
    });

    $sys->loop_until_done;

    is($GreeterActor::GREETING_COUNT, 2, '... Greeting handler called twice');
    is($GreeterActor::FAREWELL_COUNT, 1, '... Farewell handler called once');
};

done_testing;
