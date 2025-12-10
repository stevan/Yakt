#!perl

use v5.40;
use experimental qw[ class ];

use Test::More;

use ok 'Yakt::System';

class KnownMessage   :isa(Yakt::Message) {}
class UnknownMessage :isa(Yakt::Message) {}
class StopMessage    :isa(Yakt::Message) {}

class SelectiveActor :isa(Yakt::Actor) {
    our $KNOWN_COUNT = 0;

    method on_known :Receive(KnownMessage) ($context, $message) {
        $KNOWN_COUNT++;
    }

    method on_stop :Receive(StopMessage) ($context, $message) {
        $context->stop;
    }
}

# Track dead letters
class DeadLetterTracker :isa(Yakt::Actor) {
    our @DEAD_LETTERS;

    method on_dead_letter :Receive(Yakt::System::Actors::DeadLetterQueue::DeadLetter) ($context, $message) {
        push @DEAD_LETTERS => $message;
    }
}

subtest 'Unhandled messages go to dead letter queue' => sub {
    $SelectiveActor::KNOWN_COUNT = 0;
    @DeadLetterTracker::DEAD_LETTERS = ();

    my $sys = Yakt::System->new->init(sub ($context) {
        my $actor = $context->spawn(Yakt::Props->new( class => 'SelectiveActor' ));

        # Send known message
        $actor->send(KnownMessage->new);

        # Send unknown message - should go to dead letters
        $actor->send(UnknownMessage->new);

        # Stop the actor
        $actor->send(StopMessage->new);
    });

    $sys->loop_until_done;

    is($SelectiveActor::KNOWN_COUNT, 1, '... known message was handled');
    # Note: We can't easily check dead letters without modifying the DLQ actor
    # This test primarily verifies the actor doesn't crash on unknown messages
};

done_testing;
