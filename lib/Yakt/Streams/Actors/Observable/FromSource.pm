#!perl

use v5.40;
use experimental qw[ class ];

use Yakt::Streams::OnNext;
use Yakt::Streams::OnCompleted;
use Yakt::Streams::OnError;
use Yakt::Streams::Subscribe;
use Yakt::Streams::OnSubscribe;
use Yakt::Streams::Unsubscribe;
use Yakt::Streams::OnUnsubscribe;

class Yakt::Streams::Actors::Observable::FromSource :isa(Yakt::Actor) {
    use Yakt::Logging;

    field $source :param;

    method subscribe :Receive(Yakt::Streams::Subscribe) ($context, $message) {
        $context->logger->log(DEBUG, "Subscribe called" ) if DEBUG;
        my $subscriber = $message->subscriber;

        $subscriber->send( Yakt::Streams::OnSubscribe->new( sender => $context->self ) );

        try {
            while (defined( my $next = $source->next )) {
                $subscriber->send( Yakt::Streams::OnNext->new( value => $next, sender => $context->self ) );
            }
            $subscriber->send( Yakt::Streams::OnCompleted->new( sender => $context->self ) );
        } catch ($e) {
            $subscriber->send( Yakt::Streams::OnError->new( error => $e, sender => $context->self ) );
        }
    }

    method unsubscribe :Receive(Yakt::Streams::Unsubscribe) ($context, $message) {
        $context->logger->log(DEBUG, "Unsubscribe called" ) if DEBUG;
        my $subscriber = $message->subscriber;
        $subscriber->send( Yakt::Streams::OnUnsubscribe->new );
        $context->stop;
    }
}
