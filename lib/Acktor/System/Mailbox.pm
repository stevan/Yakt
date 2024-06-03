#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

use Acktor::Ref;
use Acktor::Context;
use Acktor::System::Signals;

class Acktor::System::Mailbox::State {
    use constant STARTING   => 0;
    use constant ALIVE      => 1;
    use constant SUSPENDED  => 2;
    use constant STOPPING   => 3;
    use constant RESTARTING => 4;
    use constant STOPPED    => 5;

    our @STATES = qw(
        STARTING
        ALIVE
        SUSPENDED
        STOPPING
        RESTARTING
        STOPPED
    );
}

class Acktor::System::Mailbox {
    use Acktor::Logging;

    use overload '""' => \&to_string;

    field $system :param;
    field $props  :param;
    field $parent :param;

    field $state;

    field $context;
    field $ref;

    field $supervisor;
    field $behavior;
    field $actor;

    field @children;

    field @messages;
    field @signals;

    field $logger;

    my $PID_SEQ = 0;

    ADJUST {
        $logger = Acktor::Logging->logger(__PACKAGE__) if LOG_LEVEL;

        $state   = Acktor::System::Mailbox::State->STARTING;
        $ref     = Acktor::Ref->new( pid => ++$PID_SEQ );
        $context = Acktor::Context->new( ref => $ref, mailbox => $self, system => $system );

        $supervisor = $props->new_supervisor;
        $behavior   = $props->new_behavior;

        push @signals => Acktor::System::Signals::Started->new;
    }

    method to_string { "Mailbox( $ref )" }

    method parent   { $parent   }
    method children { @children }

    method add_child ($child) { push @children => $child }

    method props  { $props  }
    method system { $system }

    method is_starting   { $state == Acktor::System::Mailbox::State->STARTING   }
    method is_alive      { $state == Acktor::System::Mailbox::State->ALIVE      }
    method is_suspended  { $state == Acktor::System::Mailbox::State->SUSPENDED  }
    method is_stopping   { $state == Acktor::System::Mailbox::State->STOPPING   }
    method is_restarting { $state == Acktor::System::Mailbox::State->RESTARTING }
    method is_stopped    { $state == Acktor::System::Mailbox::State->STOPPED    }

    method ref     { $ref     }
    method context { $context }

    method to_be_run { @messages || @signals }

    method enqueue_message ($message) { push @messages => $message }

    method suspend { $state = Acktor::System::Mailbox::State->SUSPENDED }
    method resume  { $state = Acktor::System::Mailbox::State->ALIVE     }

    method restart {
        $self->suspend;
        push @signals => Acktor::System::Signals::Restarting->new;
    }
    method stop {
        $self->suspend;
        push @signals => Acktor::System::Signals::Stopping->new;
    }

    method notify ($signal) {
        push @signals => $signal;
    }

    method tick {

        $logger->line($self->to_string) if DEBUG;

        my @sigs = @signals;
        @signals = ();

         while (@sigs) {
            my $sig = shift @sigs;
            $logger->log(INTERNALS, "%% GOT SIGNAL($sig)" ) if INTERNALS;

            if ($sig isa Acktor::System::Signals::Started) {
                $state = Acktor::System::Mailbox::State->ALIVE;
                $actor = $props->new_actor;
            }

            try {
                $behavior->receive_signal($actor, $context, $sig);
            } catch ($e) {
                chomp $e;
                # XXX - what to do here???
                $logger->log(ERROR, "!!! GOT AN ERROR($e) WHILE PROCESSING SIGNALS!" ) if ERROR;
            }

            if ($sig isa Acktor::System::Signals::Stopping) {
                if ( @children ) {
                    # wait for the children
                    $state = Acktor::System::Mailbox::State->STOPPING;
                    $_->context->stop foreach @children;
                } else {
                    # if there are no children then
                    # make sure Stopped is the next
                    # thing processed
                    unshift @signals => Acktor::System::Signals::Stopped->new;
                    last;
                }
            }
            elsif ($sig isa Acktor::System::Signals::Restarting) {
                if ( @children ) {
                    # wait for the children
                    $state = Acktor::System::Mailbox::State->RESTARTING;
                    $_->context->stop foreach @children;
                } else {
                    # if there are no children then
                    # restart the actor and make sure
                    # Started is the next signal
                    # that is processed
                    unshift @signals => Acktor::System::Signals::Started->new;
                    last;
                }
            }
            elsif ($sig isa Acktor::System::Signals::Stopped) {
                # ... what to do here
                $state = Acktor::System::Mailbox::State->STOPPED;
                # we can destruct the mailbox here
                $actor    = undef;
                @messages = ();

                if ($parent) {
                    $logger->log(DEBUG, "$self is Stopped, notifying $parent" ) if DEBUG;
                    $parent->context->notify( Acktor::System::Signals::Terminated->new( ref => $ref ) );
                }
                # and exit
                last;
            }
            elsif ($sig isa Acktor::System::Signals::Terminated) {
                my $child = $sig->ref;

                $logger->log(DEBUG, "$self got TERMINATED($child) while in state(".$Acktor::System::Mailbox::State::STATES[$state].")" ) if DEBUG;

                $logger->log(INTERNALS, "CHILDREN: ", join ', ' => @children ) if INTERNALS;
                $logger->log(INTERNALS, "BEFORE num children: ".scalar(@children) ) if INTERNALS;
                @children = grep { $_->pid ne $child->pid } @children;
                $logger->log(INTERNALS, "AFTER num children: ".scalar(@children) ) if INTERNALS;

                # TODO: the logic here needs some testing
                # I am not 100% sure it is correct.
                if (@children == 0) {
                    $logger->log(DEBUG, "no more children, resuming state(".$Acktor::System::Mailbox::State::STATES[$state].")" ) if DEBUG;
                    if ($state == Acktor::System::Mailbox::State->STOPPING) {
                        unshift @signals => Acktor::System::Signals::Stopped->new;
                        last;
                    }
                    elsif ($state == Acktor::System::Mailbox::State->RESTARTING) {
                        unshift @signals => Acktor::System::Signals::Started->new;
                        last;
                    }
                    # otherwise just keep on going ...
                }
            }
        }

        return unless $self->is_alive;

        my @msgs  = @messages;
        @messages = ();

        while (@msgs) {
            my $msg = shift @msgs;
            try {
                $behavior->receive_message($actor, $context, $msg);
            } catch ($e) {
                chomp $e;

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
                    last;
                }
            }
        }

        return;
    }

}
