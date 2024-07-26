#!perl

use v5.40;
use experimental qw[ class ];

use Yakt::Behavior;

use Yakt::Streams::Subscribe;
use Yakt::Streams::OnSubscribe;
use Yakt::Streams::Unsubscribe;
use Yakt::Streams::OnUnsubscribe;

class Yakt::Streams::Actors::Mono :isa(Yakt::Actor) {
    use Yakt::Logging;

    method subscribe;

    method unsubscribe ($context, $message) {
        $context->logger->log(DEBUG, "Unsubscribe called" ) if DEBUG;
        my $subscriber = $message->subscriber;
        $subscriber->send( Yakt::Streams::OnUnsubscribe->new );
        $context->stop;
    }

    my %BEHAVIORS_FOR;
    sub behavior_for ($pkg) {
        $BEHAVIORS_FOR{$pkg} //= Yakt::Behavior->new(
            receivers => {
                Yakt::Streams::Subscribe::   => $pkg->can('subscribe'),
                Yakt::Streams::Unsubscribe:: => $pkg->can('unsubscribe'),
            }
        );
    }
}
