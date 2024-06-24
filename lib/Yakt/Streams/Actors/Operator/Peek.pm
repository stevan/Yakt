#!perl

use v5.40;
use experimental qw[ class ];

use Yakt::Streams::OnNext;

class Yakt::Streams::Actors::Operator::Peek :isa(Yakt::Streams::Actors::Operator) {
    use Yakt::Logging;

    field $f :param;

    method on_next ($context, $message) {
        $context->logger->log(DEBUG, "OnNext called" ) if DEBUG;
        $f->( $message->value );
        $self->subscriber->send(
             Yakt::Streams::OnNext->new(
                sender => $context->self,
                value  => $message->value,
            )
        );
    }
}
