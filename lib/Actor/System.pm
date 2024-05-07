#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

use Actor::Props;
use Actor::Ref;
use Actor::Context;
use Actor::Mailbox;
use Actor::Address;

class Actor::System::Actors::Root {
    sub BEHAVIOR { Actor::Behavior->new }
}

class Actor::System {
    field $address :param;

    field $root;

    field %active;
    field %inactive;

    field @dead_letters;

    ADJUST {
        $root = $self->spawn_actor(
            $address->with_path('/-'),
            Actor::Props->new( class => Actor::System::Actors::Root:: )
        );
    }

    method address { $address }
    method root    { $root    }

    # ...

    method lookup_mailbox ($address) { $active{ $address->path } }

    method spawn_actor ($address, $props, $parent=undef) {
        ($active{ $address->path } = Actor::Mailbox->new(
            address => $address,
            props   => $props,
            context => Actor::Context->new(
                system => $self,
                parent => $parent,
            )
        ))->ref
    }

    method despawn_actor ($ref) {
        if ( my $mailbox = $active{ $ref->address->path } ) {
            $mailbox->stop;
        }
    }

    # ...

    method deliver_message ($to, $message) {
        if ( my $mailbox = $active{ $to->address->path } ) {
            $mailbox->enqueue_message( $message );
        }
        else {
            push @dead_letters => [ $to, $message ];
        }
    }

    # ...

    method get_dead_letters          {      @dead_letters       }
    method send_to_dead_letters (@m) { push @dead_letters => @m }

    method list_active_mailboxes   { keys %active   }
    method list_inactive_mailboxes { keys %inactive }

    # ...

    method tick {
        warn "-- tick ------------------------------------------------------------\n";
        my @to_run = grep $_->to_be_run, values %active;

        return false unless @to_run;

        foreach my $mailbox ( @to_run ) {
            push @dead_letters => $mailbox->tick;

            $inactive{ $mailbox->ref->address->path }
                = delete $active{ $mailbox->ref->address->path }
                    if !$mailbox->is_activated;
        }

        return true;
    }

    method loop_until_done {
        1 while $self->tick;
    }
}




