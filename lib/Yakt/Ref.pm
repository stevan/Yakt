#!perl

use v5.40;
use experimental qw[ class ];


class Yakt::Ref {
    use Yakt::Logging;

    use overload '""' => \&to_string;

    field $pid :param;

    field $context;
    field $logger;

    method set_context ($c) {
        $context = $c;
        $logger  = Yakt::Logging->logger($self->to_string) if LOG_LEVEL;
        $self
    }

    method context { $context }

    method pid { $pid }

    method send ($message) {
        $logger->log(DEBUG, "send($message)" ) if DEBUG;
        if ($context->is_stopped) {
            $logger->log(WARN, "Attempt to send($message) to stopped actor, ignoring") if WARN;
            return;
        }
        $context->send_message( $self, $message );
    }

    method to_string {
        sprintf 'Ref(%s)[%03d]' => $context->props->class, $pid;
    }
}
