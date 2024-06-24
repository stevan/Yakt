#!perl

use v5.40;
use experimental qw[ class ];

use Yakt::System::Signals;
use Yakt::Streams;

class Yakt::Streams::Actors::Flow :isa(Yakt::Actor) {
    use Yakt::Logging;

    field $source    :param;
    field $sink      :param;
    field $operators :param;

    field $subscriber;

    method subscribe :Receive(Yakt::Streams::Subscribe) ($context, $message) {
        $context->logger->log(DEBUG, "Subscribe called" ) if DEBUG;

        $subscriber = $message->subscriber;
        $subscriber->send( Yakt::Streams::OnSubscribe->new( sender => $context->self ) );

        # spawn everything ...
        my $start = $context->spawn( $source );
        my $end   = $context->spawn( $sink   );
        my @ops   = map $context->spawn( $_ ), @$operators;

        # connect everything ...
        my $op = $start;
        foreach my $next (@ops) {
            $op->send( Yakt::Streams::Subscribe->new( subscriber => $next ));
            $op = $next;
        }

        $op->send( Yakt::Streams::Subscribe->new( subscriber => $end ));
    }

    method unsubscribe :Receive(Yakt::Streams::Unsubscribe) ($context, $message) {
        $context->logger->log(DEBUG, "Unsubscribe called" ) if DEBUG;
        $subscriber->send( Yakt::Streams::OnUnsubscribe->new );
        $context->stop;
    }

    method on_child_terminated :Signal(Yakt::System::Signals::Terminated) ($context, $signal) {
        my $child = $signal->ref;
        $context->logger->log(WARN, "Got Terminated($child) while in state(".($context->is_alive ? 'alive' : 'not alive').")") if WARN;

        if (my $error = $signal->with_error) {
            $context->logger->log(DEBUG, "Got error($error) from Terminated Child" ) if DEBUG;
            $subscriber->send( Yakt::Streams::OnError->new( error => $error ) );
            $context->stop;
        }
        elsif (scalar $context->children == 0) {
            $context->logger->log(DEBUG, "All Children have Terminated cleanly!!" ) if DEBUG;
            $subscriber->send( Yakt::Streams::OnSuccess->new( value => true ) );
            $context->stop;
        }
    }

}
