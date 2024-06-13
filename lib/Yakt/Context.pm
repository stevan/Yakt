#!perl

use v5.40;
use experimental qw[ class ];

class Yakt::Context {
    use Yakt::Logging;

    use overload '""' => \&to_string;

    field $ref     :param;
    field $system  :param;
    field $mailbox :param;

    field $logger;
    field $context_logger;

    ADJUST {
        $logger = Yakt::Logging->logger($self->to_string) if LOG_LEVEL;

        $ref->set_context( $self );
    }

    method self     { $ref               }
    method parent   { $mailbox->parent   }
    method children { $mailbox->children }
    method props    { $mailbox->props    }

    method system { $system }

    method is_stopped { $mailbox->is_stopped }
    method is_alive   { $mailbox->is_alive   }

    method spawn ($props) {
        $logger->log(DEBUG, "spawn($props)" ) if DEBUG;
        my $child = $system->spawn_actor($props, $ref);
        $mailbox->add_child( $child );
        return $child;
    }

    method send_message ($to, $message) {
        $logger->log(INTERNALS, "send_message($to, $message)" ) if INTERNALS;
        $system->enqueue_message( $to, $message );
    }

    method schedule (%options) { $system->schedule_timer( %options ) }

    method stop {
        $logger->log(DEBUG, "stop($ref)" ) if DEBUG;
        $system->despawn_actor( $ref );
    }

    method notify ($signal) {
        $mailbox->notify( $signal )
    }

    method restart { $mailbox->restart }

    method logger {
        $context_logger //= Yakt::Logging->logger(
            sprintf '%s[%03d]' => $mailbox->props->class, $ref->pid
        );
    }

    method to_string {
        sprintf 'Context(%s)[%03d]' => $mailbox->props->class, $ref->pid;
    }
}
