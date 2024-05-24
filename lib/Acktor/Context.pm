#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

class Acktor::Context {
    use overload '""' => \&to_string;

    field $ref     :param;
    field $system  :param;
    field $mailbox :param;

    ADJUST {
        $ref->set_context( $self );
    }

    method self     { $ref               }
    method parent   { $mailbox->parent   }
    method children { $mailbox->children }
    method props    { $mailbox->props    }

    method spawn ($props) {
        say "+ $self -> spawn($props)";
        my $child = $system->spawn_actor($props, $ref);
        $mailbox->add_child( $child );
        return $child;
    }

    method send_message ($to, $message) {
        say ">> $self -> send_message($to, $message)";
        $system->enqueue_message( $to, $message );
    }

    method stop {
        say ">> $self -> stop($ref)[".$ref->pid."]";
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
