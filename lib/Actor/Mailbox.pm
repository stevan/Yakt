#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

use Actor::Signals;
use Actor::Message;

class Actor::Mailbox {
    field $address :param;
    field $props   :param;
    field $context :param;

    field $ref;

    field $behavior;
    field $actor;

    field $queue;
    field @messages;
    field @buffer;

    field @signals;

    ADJUST {
        # create all our moving parts
        $behavior = $props->behavior_for_actor;
        $actor    = $props->new_actor;
        $ref      = Actor::Ref->new( address => $address, context => $context );
        $queue    = \@messages;

        # and get things started ...
        push @signals => Actor::Signals::Lifecycle->STARTED;
    }

    method address { $address }
    method props   { $props   }
    method context { $context }
    method ref     { $ref     }

    # ...

    method is_activated { !! ($actor)                }
    method has_messages { !! (scalar @messages)      }
    method has_signals  { !! (scalar @signals)       }
    method to_be_run    { !! (@signals || @messages) }

    # ...

    method suspend {
        @buffer   = @messages;
        @messages = ();
        $queue = \@buffer;
        warn sprintf "~ SUSPEND(%s)[ buffered: %d / messages: %d ]\n", $address->path, (scalar @buffer), (scalar @messages);
    }

    method resume {
        @messages = @buffer;
        @buffer   = ();
        $queue = \@messages;
        warn sprintf "~ RESUME(%s)[ buffered: %d / messages: %d ]\n", $address->path, (scalar @buffer), (scalar @messages);
    }

    # ...

    method stop {
        $self->suspend;
        push @signals => Actor::Signals::Lifecycle->STOPPING
    }

    method restart {
        $self->suspend;
        push @signals => Actor::Signals::Lifecycle->RESTARTING
    }

    # ...

    method enqueue_message ( $message ) { push @$queue => $message }

    # ...

    method tick {
        my @dead_letters;

        if (@signals) {
            my @sigs  = @signals;
            @signals = ();

            while (@sigs) {
                my $signal = shift @sigs;

                warn sprintf "> SIG: to:(%s), sig:(%s)\n" => $ref->address->url, blessed $signal;

                try {
                    $behavior->signal( $actor, $context, $signal );
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
                    unshift @signals => Actor::Signals::Lifecycle->STOPPED;
                    last;
                }
                ## ----------------------------------------------------
                ## Restarting
                ## ----------------------------------------------------
                # if we have just processed a Restarting signal
                # then we are prepared for a restart, and can
                # do that below
                elsif ( $signal isa Actor::Signals::Lifecycle::Restarting ) {
                    # recreate the actor ...
                    $actor = $props->new_actor;
                    # and resume the mailbox ...
                    $self->resume;
                    # and make sure the Started signal is the very next
                    # thing we process here so that any initialization
                    # needed can be done
                    unshift @signals => Actor::Signals::Lifecycle->STARTED;
                    last;
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
                    push @dead_letters => @messages, @buffer;
                    $actor    = undef;
                    @messages = ();
                    @buffer   = ();
                    # signals have already been cleared
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
                    $behavior->receive( $actor, $context, $message )
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
