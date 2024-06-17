#!perl

use v5.40;
use experimental qw[ class ];

use Yakt::Streams;

class Yakt::Streams::Actors::Observer :isa(Yakt::Actor) {
    use Yakt::Logging;

    field $on_next        :param;
    field $on_completed   :param;
    field $on_error       :param;
    field $on_subscribe   :param = undef;
    field $on_unsubscribe :param = undef;

    method on_subscribe :Receive(Yakt::Streams::OnSubscribe) ($context, $message) {
        $context->logger->log(DEBUG, "OnSubscribe called" ) if DEBUG;
        $on_subscribe && $on_subscribe->($context, $message);
    }

    method on_unsubscribe :Receive(Yakt::Streams::OnUnsubscribe) ($context, $message) {
        $context->logger->log(DEBUG, "OnUnsubscribe called" ) if DEBUG;
        $on_unsubscribe && $on_unsubscribe->($context, $message);
    }

    method on_next :Receive(Yakt::Streams::OnNext) ($context, $message) {
        $context->logger->log(DEBUG, "OnNext called" ) if DEBUG;
        $on_next->($context, $message);
    }

    method on_completed :Receive(Yakt::Streams::OnCompleted) ($context, $message) {
        $context->logger->log(DEBUG, "OnCompleted called" ) if DEBUG;
        $on_completed->($context, $message);
    }

    method on_error :Receive(Yakt::Streams::OnError) ($context, $message) {
        $context->logger->log(DEBUG, "OnError called" ) if DEBUG;
        $on_error->($context, $message);
    }
}
