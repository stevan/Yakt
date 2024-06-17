#!perl

use v5.40;
use experimental qw[ class ];

use Yakt::Streams;

class Yakt::Streams::Actors::Observable::FromSource :isa(Yakt::Actor) {
    use Yakt::Logging;

    field $producer :param;

    method subscribe :Receive(Yakt::Streams::Subscribe) ($context, $message) {
        my $subscriber = $message->subscriber;

        $subscriber->send( Yakt::Streams::OnSubscribe->new( sender => $context->self ) );

        try {
            while (my $next = $producer->()) {
                $subscriber->send( Yakt::Streams::OnNext->new( value => $next, sender => $context->self ) );
            }
            $subscriber->send( Yakt::Streams::OnCompleted->new( sender => $context->self ) );
        } catch ($e) {
            $subscriber->send( Yakt::Streams::OnError->new( error => $e, sender => $context->self ) );
        }
    }

    method unsubscribe :Receive(Yakt::Streams::UnSubscribe) ($context, $message) {
        $context->logger->log(DEBUG, "Unsubscribe called" ) if DEBUG;
        my $subscriber = $message->subscriber;
        $subscriber->send( Yakt::Streams::OnUnsubscribe->new );
        $context->stop;
    }
}
