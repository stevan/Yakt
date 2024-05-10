#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

use Actor::Props;
use Actor::Ref;
use Actor::Context;
use Actor::Mailbox;
use Actor::Address;

class Actor::System::Actors::Root {}

class Actor::System {
    use Actor::Logging;

    field $address :param;

    field $root;

    field %active;
    field %stopping;
    field %inactive;

    field @dead_letters;

    field $logger;

    ADJUST {
        $logger = Actor::Logging->logger( sprintf "System[%s]" => $address->url ) if LOG_LEVEL;
        $root   = $self->spawn_actor(
            $address,
            Actor::Props->new( class => Actor::System::Actors::Root:: )
        );
    }

    method address { $address }
    method root    { $root    }

    # ...

    method lookup_mailbox ($address) { $active{ $address->path } }

    method spawn_actor ($address, $props, $parent=undef) {
        my $mailbox = Actor::Mailbox->new(
            address => $address,
            props   => $props,
            context => Actor::Context->new(
                system => $self,
                parent => $parent,
            )
        );

        $active{ $mailbox->address->pid } = $mailbox;
        return $mailbox->ref;
    }

    method despawn_actor ($ref) {
        if ( my $mailbox = delete $active{ $ref->address->pid } ) {
            $mailbox->stop;
            $stopping{ $ref->address->pid } = $mailbox;
        }
    }

    # ...

    method deliver_message ($to, $message) {
        if ( my $mailbox = $active{ $to->address->pid } ) {
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
        $logger->header('tick') if DEBUG;
        my @active  = values %active;
        my @to_run  = grep $_->to_be_run, @active;
        my @to_stop = values %stopping;

        return false unless @to_run || @to_stop;

        $logger->log(DEBUG, join "\n" =>
            (sprintf "  > ACTIVE    : %s", join ', ' => map $_->address->url, values %active),
            (sprintf "  + RUNNING   : %s", join ', ' => map $_->address->url, @to_run),
            (sprintf "  - SUSPENDED : %s", join ', ' => map $_->address->url, grep $_->is_suspended, @active),
            (sprintf "  < STOPPING  : %s", join ', ' => map $_->address->url, values %stopping),
            (sprintf "  * INACTIVE  : %s", join ', ' => map $_->address->url, values %inactive),
        ) if DEBUG;

        my @dead;

        foreach my $mailbox ( @to_stop ) {
            push @dead => $mailbox->tick;
            $inactive{ $mailbox->address->pid }
                = delete $stopping{ $mailbox->address->pid }
                    if !$mailbox->is_activated;
        }

        foreach my $mailbox ( @to_run ) {
            push @dead => $mailbox->tick;
            $inactive{ $mailbox->address->pid }
                = delete $active{ $mailbox->address->pid }
                    if !$mailbox->is_activated;
        }

        if (WARN && @dead ) {
            $logger->alert('Dead Letters');
            $logger->log(WARN, join "\n" =>
                map {
                    sprintf "    to:(%s), from:(%s), msg:(%s)" => (
                        $_->[0]->address->url,
                        $_->[1]->from ? $_->[1]->from->address->url : '~',
                        $_->[1]->to_string
                    )
                } @dead
            );
            push @dead_letters => @dead;
        }

        return true;
    }

    method loop_until_done {
        $logger->line('starting loop') if DEBUG;
        1 while $self->tick;
        $logger->line('ending loop') if DEBUG;

        if (DEBUG) {
            if (keys %active || keys %stopping) {
                $logger->alert('Zombies');
                $logger->log(DEBUG, join "\n" =>
                    (sprintf "  > ACTIVE    : %s", join ', ' => map $_->address->url, values %active),
                    (sprintf "  < STOPPING  : %s", join ', ' => map $_->address->url, values %stopping),
                    (sprintf "  * INACTIVE  : %s", join ', ' => map $_->address->url, values %inactive),
                );
            }
        }

        if (WARN && @dead_letters) {
            $logger->alert('Final Dead Letters');
            $logger->log(WARN, join "\n" =>
                map {
                    sprintf "    to:(%s), from:(%s), msg:(%s)" => (
                        $_->[0]->address->url,
                        $_->[1]->from ? $_->[1]->from->address->url : '~',
                        $_->[1]->to_string
                    )
                } @dead_letters
            );
        }

    }
}




