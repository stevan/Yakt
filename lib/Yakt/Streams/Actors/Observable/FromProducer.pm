#!perl

use v5.40;
use experimental qw[ class ];

use Yakt::Streams::OnNext;
use Yakt::Streams::OnCompleted;
use Yakt::Streams::OnError;
use Yakt::Streams::Subscribe;
use Yakt::Streams::OnSubscribe;

class Yakt::Streams::Actors::Observable::FromProducer :isa(Yakt::Streams::Actors::Observable) {
    use Yakt::Logging;

    field $producer :param;

    method subscribe :Receive(Yakt::Streams::Subscribe) ($context, $message) {
        $context->logger->log(DEBUG, "Subscribe called" ) if DEBUG;
        my $subscriber = $message->subscriber;

        $subscriber->send( Yakt::Streams::OnSubscribe->new( sender => $context->self ) );

        try {
            while (defined( my $next = $producer->() )) {
                $subscriber->send( Yakt::Streams::OnNext->new( value => $next, sender => $context->self ) );
            }
            $subscriber->send( Yakt::Streams::OnCompleted->new( sender => $context->self ) );
        } catch ($e) {
            $subscriber->send( Yakt::Streams::OnError->new( error => $e, sender => $context->self ) );
        }
    }
}
