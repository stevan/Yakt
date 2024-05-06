#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

use Actor::Signals::Lifecycle;
use Actor::Message;

class Actor::Mailbox {
    field $ref :param;

    field $activated = false;

    field $behavior;
    field @messages;
    field @signals;

    method ref { $ref }

    # ...

    method is_activated   {   $activated }
    method is_deactivated { ! $activated }

    method has_messages { !! scalar @messages }
    method has_signals  { !! scalar @signals  }

    method to_be_run { @signals || ($activated && @messages) }

    # ...

    method activate {
        $behavior = $ref->props->new_actor;
        push @signals => Actor::Signals::Lifecycle->ACTIVATED;
    }

    method deactivate {
        push @signals => Actor::Signals::Lifecycle->DEACTIVATED;
    }

    # ...

    method enqueue_message ( $message ) {
        push @messages => $message;
    }

    method enqueue_signal ( $signal ) {
        push @signals => $signal;
    }

    # ...

    method tick {
        my @dead_letters;

        if (@signals) {
            my @sigs  = @signals;
            @signals = ();

            my $context = $ref->context;
            while (@sigs) {
                my $signal = shift @sigs;

                warn sprintf "SIGNAL: to:(%s), sig:(%s)\n" => $ref->address->url, blessed $signal;

                if ( $signal isa Actor::Signals::Lifecycle::Activated ) {
                    die "Activated signal sent to already activated actor, this is not okay"
                        if $activated;

                    $activated = true;
                }

                try {
                    $behavior->signal( $context, $signal );
                } catch ($e) {
                    warn "Error handling signal(".$signal->type.") : $e";
                }

                if ( $signal isa Actor::Signals::Lifecycle::Deactivated ) {
                    push @dead_letters => @messages;
                    $behavior  = undef;
                    $activated = false;
                    @messages = ();
                    last;
                }
            }
        }

        if (@messages) {
            my @msgs  = @messages;
            @messages = ();

            my $context = $ref->context;
            while (@msgs) {
                my $message = shift @msgs;

                warn sprintf "TICK: to:(%s), from:(%s), body:(%s)\n" => $ref->address->url, $message->from ? $message->from->address->url : '~', $message->body // blessed $message;

                try {
                    $behavior->receive( $context, $message )
                        or push @dead_letters => $message;
                } catch ($e) {
                    warn sprintf "ERROR[ %s ] MSG[ to:(%s), from:(%s), body:(%s) ]\n" => $e, $ref->address->url, $message->from->address->url, $message->body // blessed $message;
                    push @dead_letters => $message;
                }
            }
        }

        return map [ $ref, $_ ], @dead_letters;
    }
}
