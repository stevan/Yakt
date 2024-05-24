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
        $logger = Acktor::Logging->logger(__PACKAGE__) if LOG_LEVEL;

        $ref->set_context( $self );
    }

    method self     { $ref               }
    method parent   { $mailbox->parent   }
    method children { $mailbox->children }
    method props    { $mailbox->props    }

    method spawn ($props) {
        $logger->log(DEBUG, "+ $self -> spawn($props)" ) if DEBUG;
        my $child = $system->spawn_actor($props, $ref);
        $mailbox->add_child( $child );
        return $child;
    }

    method send_message ($to, $message) {
        $logger->log(DEBUG, ">> $self -> send_message($to, $message)" ) if DEBUG;
        $system->enqueue_message( $to, $message );
    }

    method stop {
        $logger->log(DEBUG, ">> $self -> stop($ref)[".$ref->pid."]" ) if DEBUG;
        $system->despawn_actor( $ref );
    }

    method notify ($terminated) {
        $mailbox->notify( $terminated )
    }

    method restart { $mailbox->restart }

    method to_string {
        sprintf 'Context{ %s }' => $ref;
    }
}
