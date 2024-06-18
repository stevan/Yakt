#!perl

use v5.40;
use experimental qw[ class ];

use Yakt::Behavior;

use Yakt::Streams::OnNext;
use Yakt::Streams::OnCompleted;
use Yakt::Streams::OnError;
use Yakt::Streams::Subscribe;
use Yakt::Streams::OnSubscribe;
use Yakt::Streams::Unsubscribe;
use Yakt::Streams::OnUnsubscribe;

class Yakt::Streams::Actors::Operator :isa(Yakt::Actor) {
    use Yakt::Logging;

    field $subscriber :reader;
    field $subject    :reader;

    ## ... Observerable

    # an observer subscribing to my output ...
    method subscribe ($context, $message) {
        $context->logger->log(DEBUG, "Subscribe called" ) if DEBUG;
        $subscriber = $message->subscriber;
        $subscriber->send( Yakt::Streams::OnSubscribe->new( sender => $context->self ) );
    }

    # an observer unsubscrobing to my output ...
    method unsubscribe ($context, $message) {
        $context->logger->log(DEBUG, "Unsubscribe called" ) if DEBUG;
        $subscriber->send( Yakt::Streams::OnUnsubscribe->new );
        $subject->send( Yakt::Streams::Unsubscribe->new( subscriber => $context->self ) );
    }

    ## ... Observer

    # an observable sending confirmation of subscription
    method on_subscribe ($context, $message) {
        $context->logger->log(DEBUG, "OnSubscribe called" ) if DEBUG;
        $subject = $message->sender;
    }

    # an observable sending confirmation of unsubscription
    method on_unsubscribe ($context, $message) {
        $context->logger->log(DEBUG, "OnUnsubscribe called" ) if DEBUG;
        $context->stop;
    }

    # events sent from observables ...

    method on_next;

    method on_completed ($context, $message) {
        $context->logger->log(DEBUG, "OnCompleted called" ) if DEBUG;
        $subscriber->send( Yakt::Streams::OnCompleted->new( sender => $context->self ) );
    }

    method on_error ($context, $message) {
        $context->logger->log(DEBUG, "OnError called" ) if DEBUG;
        $subscriber->send( Yakt::Streams::OnError->new( error => $message->error ) );
    }

    my %BEHAVIORS_FOR;
    sub behavior_for ($pkg) {
        $BEHAVIORS_FOR{$pkg} //= Yakt::Behavior->new(
            receivers => {
                Yakt::Streams::Subscribe::     => $pkg->can('subscribe'),
                Yakt::Streams::Unsubscribe::   => $pkg->can('unsubscribe'),
                Yakt::Streams::OnSubscribe::   => $pkg->can('on_subscribe'),
                Yakt::Streams::OnUnsubscribe:: => $pkg->can('on_unsubscribe'),
                Yakt::Streams::OnNext::        => $pkg->can('on_next'),
                Yakt::Streams::OnCompleted::   => $pkg->can('on_completed'),
                Yakt::Streams::OnError::       => $pkg->can('on_error'),
            }
        );
    }

}
