#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

class Acktor::Context {
    use Acktor::Logging;

    use overload '""' => \&to_string;

    field $ref     :param;
    field $system  :param;
    field $mailbox :param;

    field $logger;

    ADJUST {
        $logger = Acktor::Logging->logger($self->to_string) if LOG_LEVEL;

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

    method to_string {
        sprintf 'Context(%s)[%03d]' => $mailbox->props->class, $ref->pid;
    }
}
