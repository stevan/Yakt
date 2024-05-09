#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

use Actor::Signals;
use Actor::Message;

class Actor::Mailbox {
    use Actor::Logging;

    field $address :param;
    field $props   :param;
    field $context :param;

    field $ref;

    field $logger;
    field $behavior;
    field $supervisor;
    field $actor;

    field $queue;
    field @messages;
    field @buffer;

    field @signals;

    ADJUST {
        # create all our moving parts
        $behavior   = $props->behavior_for_actor;
        $supervisor = $props->supervisor_for_actor;
        $actor      = $props->new_actor;
        $ref        = Actor::Ref->new( address => $address, context => $context );
        $queue      = \@messages;
        $logger     = Actor::Logging->logger( sprintf 'Mailbox(%d)[%s]', refaddr $self, $address->url );

        # and get things started ...
        push @signals => Actor::Signals::Lifecycle->Started;
    }

    method address { $address }
    method props   { $props   }
    method context { $context }
    method ref     { $ref     }

    # ...
    method is_suspended { $queue != \@messages }
    method is_activated { !! ($actor)                }
    method has_messages { !! (scalar @messages)      }
    method has_signals  { !! (scalar @signals)       }
    method to_be_run    { !! (@signals || @messages) }

    # ...

    method suspend {
        @buffer   = @messages;
        @messages = ();
        $queue = \@buffer;
        $logger->log(INTERNALS,
            sprintf "~ SUSPEND(%s)[ buffered: %d <- messages: %d ]\n",
                $address->path, (scalar @buffer), (scalar @messages)
        ) if INTERNALS;
    }

    method resume {
        $logger->log(INTERNALS,
            sprintf "~ RESUME(%s)[ buffered: %d -> messages: %d ]\n",
                $address->path, (scalar @buffer), (scalar @messages)
        ) if INTERNALS;
        @messages = @buffer;
        @buffer   = ();
        $queue = \@messages;
    }

    # ...

    method stop {
        if ($self->is_suspended) {
            $logger->log(WARN, "Trying to stop something that is already suspeneded" ) if WARN;
            # be forceful!
            unshift @signals => Actor::Signals::Lifecycle->Stopping
                # unless we already were being forceful already
                unless $signals[0] isa Actor::Signals::Lifecycle::Stopping::;
        }
        else {
            $self->suspend;
            unshift @signals => Actor::Signals::Lifecycle->Stopping;
        }
    }

    method restart {
        if ($self->is_suspended) {
            $logger->log(ERROR,"Cannot restart something that is already suspeneded") if ERROR;
        }
        else {
            $self->suspend;
            push @signals => Actor::Signals::Lifecycle->Restarting
        }
    }

    # ...

    method enqueue_message ( $message ) { push @$queue => $message }

    # ...

    method tick {
        my @dead_letters;

        $logger->line("tick[ ".$address->url." ]", "[ $actor ]") if DEBUG;

        if (@signals) {
            my @sigs  = @signals;
            @signals = ();

          SIGNAL:
            while (@sigs) {
                my $signal = shift @sigs;

                $logger->log(DEBUG,
                    sprintf "> SIG: to:(%s), sig:(%s)\n" =>
                        $ref->address->url, blessed $signal
                ) if DEBUG;

                try {
                    $behavior->signal( $actor, $context, $signal );
                } catch ($e) {
                    $logger->log(ERROR, "Error handling signal(".$signal->type.") : $e") if ERROR;
                }

                $logger->log(INTERNALS,
                    "__ CHECKING LIFECYCLE >> SIGNAL: ", blessed $signal
                ) if INTERNALS;

                ## ----------------------------------------------------
                ## Stopping
                ## ----------------------------------------------------
                # if we have just processed a Stopping signal, that
                # means we are now ready to stop, so we just add
                # that signal to be the first one processed on the
                # next tick. This should be fine because the mailbox
                # is suspended, and we will exit this loop immediately
                # resulting in this tick exiting. The subsequent tick
                # will then result with the STOPPED signal as the first
                # thing processed.
                if ( $signal isa Actor::Signals::Lifecycle::Stopping:: ) {
                    $logger->log(INTERNALS, "__ STOPPING") if INTERNALS;
                    unshift @signals => Actor::Signals::Lifecycle->Stopped;
                    last SIGNAL;
                }
                ## ----------------------------------------------------
                ## Restarting
                ## ----------------------------------------------------
                # if we have just processed a Restarting signal
                # then we are prepared for a restart, and can
                # do that below
                if ( $signal isa Actor::Signals::Lifecycle::Restarting:: ) {
                    $logger->log(INTERNALS, "__ RESTARTING") if INTERNALS;
                    # recreate the actor ...
                    $actor = $props->new_actor;
                    # and resume the mailbox ...
                    $self->resume;
                    # and make sure the Started signal is the very next
                    # thing we process here so that any initialization
                    # needed can be done. This is kind of the opposite
                    # of what needs to be done. If we were to use `last`
                    # here, then it would start processing messages
                    # since we resumed the mailbox. However, that is
                    # not what want, so we actually `return` here
                    # instead, and assure that Started signal is the
                    # very next things we process.
                    unshift @signals => Actor::Signals::Lifecycle->Started;
                    return;
                }
                ## ----------------------------------------------------
                ## Stopped
                ## ----------------------------------------------------
                # if we have encountered a Stopped signal, that is
                # our queue to destruct the actor and deactive the
                # mailbox. We also remove all the messages and return
                # them to the deadletter queue, just before exiting
                # this loop.
                if ( $signal isa Actor::Signals::Lifecycle::Stopped:: ) {
                    $logger->log(INTERNALS, sprintf "__ STOPPED (%d, %d)" => scalar(@messages), scalar(@buffer)) if INTERNALS;
                    push @dead_letters => @messages, @buffer;
                    $actor    = undef;
                    @messages = ();
                    @buffer   = ();
                    # signals have already been cleared
                    last SIGNAL;
                }

                $logger->log(INTERNALS, "__ END LIFECYCLE CHECK") if INTERNALS;
            }
        }

        if (@messages) {
            my @msgs  = @messages;
            @messages = ();

            my $context = $ref->context;

          MESSAGE:
            while (@msgs) {
                my $message = shift @msgs;

                $logger->log(DEBUG,
                    sprintf "> MSG: to:(%s), from:(%s), body:(%s)\n" =>
                        $ref->address->url,
                        $message->from ? $message->from->address->url : '~',
                        $message->body // blessed $message
                ) if DEBUG;

                try {
                    $behavior->receive( $actor, $context, $message )
                        or push @dead_letters => $message;
                } catch ($e) {
                    $logger->log(ERROR,
                        sprintf "! ERR[ %s ] MSG[ to:(%s), from:(%s), body:(%s) ]\n" =>
                            $e =~ s/\n$//r,
                            $ref->address->url,
                            $message->from ? $message->from->address->url : '~',
                            $message->body // blessed $message
                    ) if ERROR;

                    #push @dead_letters => $message;

                    my $action = $supervisor->supervise($self, $e, $message);

                    if ($action == $supervisor->RETRY) {
                        $logger->log(INTERNALS, "supervisor said to retry ...") if INTERNALS;
                        unshift @msgs => $message;
                    }
                    elsif ($action == $supervisor->RESUME) {
                        $logger->log(INTERNALS, "supervisor said to resume (and not retry) ...") if INTERNALS;
                        next MESSAGE;
                    }
                    elsif ($action == $supervisor->HALT) {
                        $logger->log(INTERNALS, "supervisor said to halt ...") if INTERNALS;
                        unshift @buffer => @msgs;
                        last MESSAGE;
                    }
                }

                last if $self->is_suspended;
            }
        }

        return map [ $ref, $_ ], @dead_letters;
    }
}
