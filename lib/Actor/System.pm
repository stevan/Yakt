#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

use Actor::Props;
use Actor::Ref;
use Actor::Context;
use Actor::Mailbox;
use Actor::Address;

class Actor::System {
    field $address :param;

    field $root;

    field %mailboxes;
    field @dead_letters;

    ADJUST {
        $root = $self->spawn_actor(
            $address->with_path('/-'),
            Actor::Props->new( class => 'Actor::Behavior' )
        );
    }

    method address { $address }
    method root    { $root    }

    # ...

    method spawn_actor ($addr, $props, $parent=undef) {
        my $ref = Actor::Ref->new(
            address => $addr,
            props   => $props,
            context => Actor::Context->new(
                system => $self,
                parent => $parent
            )
        );

        my $mailbox = Actor::Mailbox->new( ref => $ref );
        $mailbox->activate;

        $mailboxes{ $ref->address->path } = $mailbox;

        return $ref;
    }

    method despawn_actor ($ref) {
        if ( my $mailbox = $mailboxes{ $ref->address->path } ) {
            $mailbox->deactivate;
        }
    }

    # ...

    method deliver_message ($to, $message) {
        if ( my $mailbox = $mailboxes{ $to->address->path } ) {
            $mailbox->enqueue_message( $message );
        }
        else {
            push @dead_letters => [ $to, $message ];
        }
    }

    method deliver_signal ($to, $signal) {
        if ( my $mailbox = $mailboxes{ $to->address->path } ) {
            $mailbox->enqueue_signal( $signal );
        }
    }

    # ...

    method get_dead_letters          {      @dead_letters       }
    method send_to_dead_letters (@m) { push @dead_letters => @m }

    method list_mailboxes { keys %mailboxes }

    # ...

    method tick {
        my @to_run = grep $_->to_be_run, values %mailboxes;

        foreach my $mailbox ( @to_run ) {
            push @dead_letters => $mailbox->tick;

            delete $mailboxes{ $mailbox->ref->address->path }
                if $mailbox->is_deactivated;
        }
    }
}
