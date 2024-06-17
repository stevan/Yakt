#!perl

use v5.40;
use experimental qw[ class ];

use Yakt::Streams;

class Yakt::Streams::Actors::Operator::Map :isa(Yakt::Actor) {
    use Yakt::Logging;

    field $f :param;

    field $subscriber;
    field $subject;

    ## ... Observerable

    # an observer subscribing to my output ...
    method subscribe :Receive(Yakt::Streams::Subscribe) ($context, $message) {
        $context->logger->log(DEBUG, "Subscribe called" ) if DEBUG;
        $subscriber = $message->subscriber;
        $subscriber->send( Yakt::Streams::OnSubscribe->new( sender => $context->self ) );
    }

    # an observer unsubscrobing to my output ...
    method unsubscribe :Receive(Yakt::Streams::Unsubscribe) ($context, $message) {
        $context->logger->log(DEBUG, "Unsubscribe called" ) if DEBUG;
        $subscriber->send( Yakt::Streams::OnUnsubscribe->new );
        $subject->send( Yakt::Streams::Unsubscribe->new( subscriber => $context->self ) );
    }

    ## ... Observer

    # an observable sending confirmation of subscription
    method on_subscribe :Receive(Yakt::Streams::OnSubscribe) ($context, $message) {
        $context->logger->log(DEBUG, "OnSubscribe called" ) if DEBUG;
        $subject = $message->sender;
    }

    # an observable sending confirmation of unsubscription
    method on_unsubscribe :Receive(Yakt::Streams::OnUnsubscribe) ($context, $message) {
        $context->logger->log(DEBUG, "OnUnsubscribe called" ) if DEBUG;
        $context->stop;
    }

    # events sent from observables ...

    method on_next :Receive(Yakt::Streams::OnNext) ($context, $message) {
        $context->logger->log(DEBUG, "OnNext called" ) if DEBUG;
        $subscriber->send(
             Yakt::Streams::OnNext->new(
                sender => $context->self,
                value  => $f->( $message->value )
            )
        );
    }

    method on_completed :Receive(Yakt::Streams::OnCompleted) ($context, $message) {
        $context->logger->log(DEBUG, "OnCompleted called" ) if DEBUG;
        $subscriber->send( Yakt::Streams::OnCompleted->new( sender => $context->self ) );
    }

    method on_error :Receive(Yakt::Streams::OnError) ($context, $message) {
        $context->logger->log(DEBUG, "OnError called" ) if DEBUG;
        $subscriber->send( Yakt::Streams::OnError->new( error => $message->error ) );
    }
}
