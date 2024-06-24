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

    field $state;

    field $context;
    field $ref;

    field $supervisor;
    field $actor;

    field @children;

    field $inbox;

    field @messages;
    field @signals;

    field $logger;

    field $halted = false;

    my $PID_SEQ = 0;

    ADJUST {
        $state   = Yakt::System::Mailbox::State->STARTING;
        $ref     = Yakt::Ref->new( pid => ++$PID_SEQ );
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
                # XXX - what to do here???
                $logger->log(ERROR, "!!! GOT AN ERROR($e) WHILE PROCESSING SIGNALS!" ) if ERROR;
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

                if ($parent) {
                    $logger->log(DEBUG, "is Stopped, notifying parent($parent)" ) if DEBUG;
                    $parent->context->notify( Yakt::System::Signals::Terminated->new( ref => $ref, with_error => $halted ) );
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
                    $halted = $e;
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
