#!perl

use v5.40;
use experimental qw[ class ];

use Test::More;

use ok 'Yakt::System';

class TestMessage :isa(Yakt::Message) {
    field $value :param;
    method value { $value }
}

class SendReceiver :isa(Yakt::Actor) {
    our @RECEIVED;

    method on_message :Receive(TestMessage) ($context, $message) {
        push @RECEIVED => $message->value;
        if (scalar @RECEIVED >= 3) {
            $context->stop;
        }
    }
}

subtest 'send delivers message to actor' => sub {
    @SendReceiver::RECEIVED = ();

    my $sys = Yakt::System->new->init(sub ($context) {
        my $ref = $context->spawn(Yakt::Props->new( class => 'SendReceiver' ));

        $ref->send(TestMessage->new( value => 'first' ));
        $ref->send(TestMessage->new( value => 'second' ));
        $ref->send(TestMessage->new( value => 'third' ));
    });

    $sys->loop_until_done;

    is_deeply(
        \@SendReceiver::RECEIVED,
        ['first', 'second', 'third'],
        '... all messages delivered in order'
    );
};

done_testing;
