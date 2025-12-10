#!perl

use v5.40;
use experimental qw[ class ];

use Yakt::Actor;
use Yakt::Props;
use Yakt::Ref;
use Yakt::Context;

use Yakt::System::Signals;

class Yakt::System::Mailbox::State {
    use constant STARTING   => 0;
    use constant ALIVE      => 1;
    use constant RUNNING    => 2;
    use constant SUSPENDED  => 3;
    use constant STOPPING   => 4;
    use constant RESTARTING => 5;
    use constant STOPPED    => 6;

    our @STATES = qw(
        STARTING
        ALIVE
        RUNNING
        SUSPENDED
        STOPPING
        RESTARTING
        STOPPED
    );
}

class Yakt::System::Mailbox {
    use Yakt::Logging;

    use overload '""' => \&to_string;

    field $system :param;
    field $props  :param;
    field $parent :param;
    field $pid    :param;

    field $state;

    field $context;
    field $ref;

    field $supervisor;
    field $actor;

    field @children;
    field %watchers;

    field $inbox;

    field @messages;
    field @signals;

    field $logger;

    field $halted_on;

    ADJUST {
        $state   = Yakt::System::Mailbox::State->STARTING;
        $ref     = Yakt::Ref->new( pid => $pid );
        $context = Yakt::Context->new( ref => $ref, mailbox => $self, system => $system );

        $supervisor = $props->supervisor;

        $logger = Yakt::Logging->logger($self->to_string) if LOG_LEVEL;

        $inbox = \@messages;

        push @signals => Yakt::System::Signals::Started->new;
    }

    method to_string { sprintf "Mailbox(%s)[%03d]" => $props->class, $ref->pid }

    method props  { $props  }
    method system { $system }

    method parent   { $parent   }
    method children { @children }

    method add_child ($child) { push @children => $child }

    method add_watcher ($watcher) { $watchers{refaddr $watcher} = $watcher }

    method ref     { $ref     }
    method context { $context }

    method is_starting   { $state == Yakt::System::Mailbox::State->STARTING   }
    method is_alive      { $state == Yakt::System::Mailbox::State->ALIVE || $self->is_running }
    method is_running    { $state == Yakt::System::Mailbox::State->RUNNING    }
    method is_suspended  { $state == Yakt::System::Mailbox::State->SUSPENDED  }
    method is_stopping   { $state == Yakt::System::Mailbox::State->STOPPING   }
    method is_restarting { $state == Yakt::System::Mailbox::State->RESTARTING }
    method is_stopped    { $state == Yakt::System::Mailbox::State->STOPPED    }

    method suspend { $state = Yakt::System::Mailbox::State->SUSPENDED }
    method resume  { $state = Yakt::System::Mailbox::State->ALIVE     }

    method restart {
        $self->suspend;
        push @signals => Yakt::System::Signals::Restarting->new;
    }

    method stop {
        $self->suspend;
        push @signals => Yakt::System::Signals::Stopping->new;
    }

    method to_be_run { @messages || @signals }

    method notify          ($signal)  { push @signals => $signal }
    method enqueue_message ($message) { push @$inbox => $message }

    method prepare {
        $inbox = [];
        $state = Yakt::System::Mailbox::State->RUNNING
            if $state == Yakt::System::Mailbox::State->ALIVE;
    }

    method finish {
        push @messages => @$inbox;
        $inbox = \@messages;
        $state = Yakt::System::Mailbox::State->ALIVE
            if $state == Yakt::System::Mailbox::State->RUNNING;
    }

    method tick {

        $logger->line("start $self") if DEBUG;

        my @sigs = @signals;
        @signals = ();

         while (@sigs) {
            my $sig = shift @sigs;
            $logger->log(INTERNALS, "Got signal($sig)" ) if INTERNALS;

            if ($sig isa Yakt::System::Signals::Started) {
                $state = Yakt::System::Mailbox::State->ALIVE;
                $actor = $props->new_actor;
            }
            elsif ($sig isa Yakt::System::Signals::Terminated) {
                my $child = $sig->ref;

                $logger->log(INTERNALS, "got TERMINATED($child) while in state(".$Yakt::System::Mailbox::State::STATES[$state].")" ) if INTERNALS;

                $logger->log(INTERNALS, "CHILDREN: ", join ', ' => @children ) if INTERNALS;
                $logger->log(INTERNALS, "BEFORE num children: ".scalar(@children) ) if INTERNALS;
                @children = grep { $_->pid ne $child->pid } @children;
                $logger->log(INTERNALS, "AFTER num children: ".scalar(@children) ) if INTERNALS;

                # TODO: the logic here needs some testing
                # I am not 100% sure it is correct.
                if (@children == 0) {
                    $logger->log(INTERNALS, "no more children, resuming state(".$Yakt::System::Mailbox::State::STATES[$state].")" ) if INTERNALS;
                    if ($state == Yakt::System::Mailbox::State->STOPPING) {
                        unshift @signals => Yakt::System::Signals::Stopped->new;
                        last;
                    }
                    elsif ($state == Yakt::System::Mailbox::State->RESTARTING) {
                        unshift @signals => Yakt::System::Signals::Started->new;
                        last;
                    }
                    # otherwise just keep on going ...
                }
            }

            try {
                $actor->signal($context, $sig);
            } catch ($e) {
                chomp $e;
                $logger->log(ERROR, "Got Error($e) while processing signal($sig)") if ERROR;

                # Started errors are fatal - can't continue with broken initialization
                if ($sig isa Yakt::System::Signals::Started) {
                    $logger->log(ERROR, "Actor failed to start, stopping") if ERROR;
                    $halted_on = $e;
                    unshift @signals => Yakt::System::Signals::Stopped->new;
                    last;
                }
                # Stopping/Stopped/Terminated errors - log but continue shutdown
                elsif ($sig isa Yakt::System::Signals::Stopping
                    || $sig isa Yakt::System::Signals::Stopped
                    || $sig isa Yakt::System::Signals::Terminated) {
                    # Already in shutdown path, just log and continue
                }
                # Other signals - defer to supervisor
                else {
                    my $action = $supervisor->supervise( $self, $e );
                    if ($action == $supervisor->HALT) {
                        $logger->log(DEBUG, "supervisor said to halt after signal error") if DEBUG;
                        $halted_on = $e;
                        $self->stop;
                        last;
                    }
                    # RETRY/RESUME don't make sense for signals, treat as continue
                }
            }

            if ($sig isa Yakt::System::Signals::Stopping) {
                if ( @children ) {
                    # wait for the children
                    $state = Yakt::System::Mailbox::State->STOPPING;
                    $_->context->stop foreach @children;
                } else {
                    # if there are no children then
                    # make sure Stopped is the next
                    # thing processed
                    unshift @signals => Yakt::System::Signals::Stopped->new;
                    last;
                }
            }
            elsif ($sig isa Yakt::System::Signals::Restarting) {
                if ( @children ) {
                    # wait for the children
                    $state = Yakt::System::Mailbox::State->RESTARTING;
                    $_->context->stop foreach @children;
                } else {
                    # if there are no children then
                    # restart the actor and make sure
                    # Started is the next signal
                    # that is processed
                    unshift @signals => Yakt::System::Signals::Started->new;
                    last;
                }
            }
            elsif ($sig isa Yakt::System::Signals::Stopped) {
                # ... what to do here
                $state = Yakt::System::Mailbox::State->STOPPED;
                # we can destruct the mailbox here
                $actor    = undef;
                @messages = ();

                # notify the parent of termination
                if ($parent) {
                    $logger->log(DEBUG, "is Stopped, notifying parent($parent)" ) if DEBUG;
                    $parent->context->notify( Yakt::System::Signals::Terminated->new( ref => $ref, with_error => $halted_on ) );
                }

                # notify the watchers of termination
                if (my @watchers = values %watchers) {
                    foreach my $watcher (@watchers) {
                        $logger->log(DEBUG, "is Stopped, notifying watcher($watcher)" ) if DEBUG;
                        $watcher->context->notify( Yakt::System::Signals::Terminated->new( ref => $ref, with_error => $halted_on ) );
                    }
                }

                # and exit
                last;
            }
        }

        unless ($self->is_alive) {
            $logger->line("$self in state(".$Yakt::System::Mailbox::State::STATES[$state].") ... skipping message processing") if DEBUG;
            return;
        }

        my @msgs  = @messages;
        @messages = ();

        my @unhandled;

        while (@msgs) {
            my $msg = shift @msgs;
            try {
                $actor->receive($context, $msg)
                    or push @unhandled => $msg;
            } catch ($e) {
                chomp $e;

                $logger->log(ERROR, "got Error($e) while receiving message($msg), ... supervising") if ERROR;

                my $action = $supervisor->supervise( $self, $e );

                if ($action == $supervisor->RETRY) {
                    $logger->log(DEBUG, "supervisor said to retry ...") if DEBUG;
                    unshift @msgs => $msg;
                }
                elsif ($action == $supervisor->RESUME) {
                    $logger->log(DEBUG, "supervisor said to resume (and not retry) ...") if DEBUG;
                    next;
                }
                elsif ($action == $supervisor->HALT) {
                    $logger->log(DEBUG, "supervisor said to halt ...") if DEBUG;
                    unshift @messages => @msgs;
                    $halted_on = $e;
                    last;
                }
            }
        }

        $logger->line("done $self") if DEBUG;

        return map {
            Yakt::System::Actors::DeadLetterQueue::DeadLetter->new(
                to      => $ref,
                message => $_,
            )
        } @unhandled;
    }

}

__END__

=pod

=encoding UTF-8

=head1 NAME

Yakt::System::Mailbox - Actor lifecycle state machine and message queue

=head1 DESCRIPTION

C<Yakt::System::Mailbox> is an internal class that manages an actor's lifecycle
and message processing. Each actor has exactly one Mailbox.

B<This is an internal class.> Users should interact with actors through
L<Yakt::Context> and L<Yakt::Ref>.

=head1 STATUS

B<Internal> - API may change. Documented for implementors.

=head1 LIFECYCLE STATES

The Mailbox implements a state machine with these states:

    STARTING    Actor is initializing, waiting for Started signal
        ↓
    ALIVE       Actor is ready to process messages
        ↓
    RUNNING     Actor is currently processing (within a tick)
        ↓
    SUSPENDED   Actor is paused (during restart or error handling)
        ↓
    STOPPING    Actor is shutting down, waiting for children
        ↓
    RESTARTING  Actor is restarting, waiting for children
        ↓
    STOPPED     Actor has terminated

=head2 State Transitions

    STARTING → ALIVE         (on Started signal processed)
    ALIVE → RUNNING          (on tick begin)
    RUNNING → ALIVE          (on tick end)
    ALIVE → SUSPENDED        (on stop/restart request)
    SUSPENDED → STOPPING     (when children done, stopping)
    SUSPENDED → RESTARTING   (when children done, restarting)
    STOPPING → STOPPED       (on Stopped signal)
    RESTARTING → STARTING    (loops back for restart)

=head1 MESSAGE PROCESSING

Each tick:

=over 4

=item 1. Process pending signals (lifecycle events)

=item 2. If alive, process pending messages

=item 3. Return unhandled messages to dead letter queue

=back

=head1 SIGNAL HANDLING

Signals are processed before messages. Special handling:

=over 4

=item B<Started> - Creates the actor instance, transitions to ALIVE

=item B<Stopping> - Stops children, waits, then sends Stopped

=item B<Restarting> - Stops children, waits, then sends Started

=item B<Stopped> - Destroys actor, notifies parent and watchers

=item B<Terminated> - Received when a child/watched actor stops

=back

=head1 ERROR HANDLING

Errors in signal handlers:

=over 4

=item * C<Started> errors → immediately stop the actor

=item * C<Stopping>/C<Stopped>/C<Terminated> errors → log and continue

=item * Other signals → defer to supervisor

=back

Errors in message handlers are always deferred to the supervisor.

=head1 SUPERVISION

When a message handler throws, the supervisor's C<supervise> method is called.
It returns one of:

=over 4

=item * C<HALT> - Stop the actor

=item * C<RESUME> - Skip the message, continue

=item * C<RETRY> - Re-deliver the message

=back

The C<Restart> supervisor triggers HALT then a restart cycle.

=head1 KEY METHODS

=head2 to_be_run

Returns true if the mailbox has pending messages or signals.

=head2 tick

Processes one cycle of signals and messages.

=head2 stop

Initiates graceful shutdown.

=head2 restart

Initiates restart sequence.

=head2 notify($signal)

Queues a signal for processing.

=head2 enqueue_message($message)

Queues a message for processing.

=head1 FIELDS

=over 4

=item C<props> - The Props used to create this actor

=item C<system> - The System this actor belongs to

=item C<parent> - Parent actor's Ref

=item C<pid> - Unique process ID

=item C<ref> - This actor's Ref

=item C<context> - This actor's Context

=item C<supervisor> - Supervision strategy

=item C<actor> - The actual actor instance (or undef if stopped)

=back

=head1 SEE ALSO

L<Yakt::System>, L<Yakt::Actor>, L<Yakt::Context>

=cut
