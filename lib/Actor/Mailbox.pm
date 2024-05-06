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

    method to_be_run { !! (@signals || ($activated && @messages)) }

    # ...

    method activate {
        $behavior = $ref->props->new_actor;
        push @signals => Actor::Signals::Lifecycle->STARTED;
    }

    method stop {
        push @signals => Actor::Signals::Lifecycle->STOPPING;
    }

    method restart {
        push @signals => Actor::Signals::Lifecycle->RESTARTING;
    }

    method deactivate {
        push @signals => Actor::Signals::Lifecycle->STOPPED;
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

                warn sprintf "> SIG: to:(%s), sig:(%s)\n" => $ref->address->url, blessed $signal;

                ## ----------------------------------------------------
                ## Started
                ## ----------------------------------------------------
                # Before we process this signal, the mailbox has
                # not been activated, and we want it to be active
                # by the time it processes this, so we set it here
                if ( $signal isa Actor::Signals::Lifecycle::Started ) {
                    die "Activated signal sent to already activated actor, this is not okay"
                        if $activated;

                    $activated = true;
                }

                try {
                    $behavior->signal( $context, $signal );
                } catch ($e) {
                    warn "Error handling signal(".$signal->type.") : $e";
                }

                ## ----------------------------------------------------
                ## Stopping
                ## ----------------------------------------------------
                # if we have just processed a Stopping signal, that
                # means we are now ready to stop, so we just add
                # that signal to be the first one processed on the
                # next loop and explicitly NOT on the next tick,
                # or after other signals, ... as we do not want this
                # actor to process any further messages, and the very
                # next thing it should do is stop
                if ( $signal isa Actor::Signals::Lifecycle::Stopping ) {
                    unshift @sigs => Actor::Signals::Lifecycle->STOPPED;
                }
                ## ----------------------------------------------------
                ## Restarting
                ## ----------------------------------------------------
                # if we have just processed a Restarting signal
                # then we are prepared for a restart, and can
                # do that below
                elsif ( $signal isa Actor::Signals::Lifecycle::Restarting ) {
                    # recreate the actor ...
                    $behavior = $ref->props->new_actor;
                    # and make sure the Started signal is the very next
                    # thing we process here so that any initialization
                    # needed can be done
                    unshift @sigs => Actor::Signals::Lifecycle->STARTED;
                }
                ## ----------------------------------------------------
                ## Stopped
                ## ----------------------------------------------------
                # if we have encountered a Stopped signal, that is
                # our queue to destruct the actor and deactive the
                # mailbox. We also remove all the messages and return
                # them to the deadletter queue, just before exiting
                # this loop.
                elsif ( $signal isa Actor::Signals::Lifecycle::Stopped ) {
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

                warn sprintf "> MSG: to:(%s), from:(%s), body:(%s)\n" => $ref->address->url, $message->from ? $message->from->address->url : '~', $message->body // blessed $message;

                try {
                    $behavior->receive( $context, $message )
                        or push @dead_letters => $message;
                } catch ($e) {
                    warn sprintf "! ERR[ %s ] MSG[ to:(%s), from:(%s), body:(%s) ]\n" => $e, $ref->address->url, $message->from->address->url, $message->body // blessed $message;
                    push @dead_letters => $message;
                }
            }
        }

        return map [ $ref, $_ ], @dead_letters;
    }
}
