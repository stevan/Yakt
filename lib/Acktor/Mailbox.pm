#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

use Acktor::Ref;
use Acktor::Context;
use Acktor::Signals;

class Acktor::Mailbox::State {
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

class Acktor::Mailbox {
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

    my $PID_SEQ = 0;

    ADJUST {
        $state   = Acktor::Mailbox::State->STARTING;
        $ref     = Acktor::Ref->new( pid => ++$PID_SEQ );
        $context = Acktor::Context->new( ref => $ref, mailbox => $self, system => $system );

        $supervisor = $props->new_supervisor;
        $behavior   = $props->new_behavior;

        push @signals => Acktor::Signals::Started->new;
    }

    method to_string { "Mailbox( $ref )" }

    method parent   { $parent   }
    method children { @children }

    method add_child ($child) { push @children => $child }

    method props  { $props  }
    method system { $system }

    method is_starting   { $state == Acktor::Mailbox::State->STARTING   }
    method is_alive      { $state == Acktor::Mailbox::State->ALIVE      }
    method is_suspended  { $state == Acktor::Mailbox::State->SUSPENDED  }
    method is_stopping   { $state == Acktor::Mailbox::State->STOPPING   }
    method is_restarting { $state == Acktor::Mailbox::State->RESTARTING }
    method is_stopped    { $state == Acktor::Mailbox::State->STOPPED    }

    method ref     { $ref     }
    method context { $context }

    method to_be_run { @messages || @signals }

    method enqueue_message ($message) { push @messages => $message }

    method suspend { $state = Acktor::Mailbox::State->SUSPENDED }
    method resume  { $state = Acktor::Mailbox::State->ALIVE     }

    method restart {
        $self->suspend;
        push @signals => Acktor::Signals::Restarting->new;
    }
    method stop {
        $self->suspend;
        push @signals => Acktor::Signals::Stopping->new;
    }

    method notify ($terminated) {
        push @signals => $terminated;
    }

    method tick {

        my @sigs = @signals;
        @signals = ();

         while (@sigs) {
            my $sig = shift @sigs;
            say "%% GOT SIGNAL($sig)";
            try {
                if ($sig isa Acktor::Signals::Started) {
                    $state = Acktor::Mailbox::State->ALIVE;
                    $actor = $props->new_actor;
                    $actor->post_start( $context );
                }
                elsif ($sig isa Acktor::Signals::Stopping) {
                    $actor->pre_stop( $context );
                    if ( @children ) {
                        # wait for the children
                        $state = Acktor::Mailbox::State->STOPPING;
                        $_->context->stop foreach @children;
                    } else {
                        # if there are no children then
                        # make sure Stopped is the next
                        # thing processed
                        unshift @signals => Acktor::Signals::Stopped->new;
                        last;
                    }
                }
                elsif ($sig isa Acktor::Signals::Restarting) {
                    $actor->pre_restart( $context );
                    if ( @children ) {
                        # wait for the children
                        $state = Acktor::Mailbox::State->RESTARTING;
                        $_->context->stop foreach @children;
                    } else {
                        # if there are no children then
                        # restart the actor and make sure
                        # Started is the next signal
                        # that is processed
                        unshift @signals => Acktor::Signals::Started->new;
                        last;
                    }
                }
                elsif ($sig isa Acktor::Signals::Stopped) {
                    # ... what to do here
                    $actor->post_stop( $context );
                    $state = Acktor::Mailbox::State->STOPPED;
                    # we can destruct the mailbox here
                    $actor    = undef;
                    @messages = ();

                    if ($parent) {
                        say "$self is Stopped, notifying $parent";
                        $parent->context->notify( Acktor::Signals::Terminated->new( ref => $ref ) );
                    }
                    # and exit
                    last;
                }
                elsif ($sig isa Acktor::Signals::Terminated) {
                    my $child = $sig->ref;

                    say "$self got TERMINATED($child) while in state(".$Acktor::Mailbox::State::STATES[$state].")";

                    say "CHILDREN: ", join ', ' => @children;
                    say "BEFORE num children: ".scalar(@children);
                    @children = grep { $_->pid ne $child->pid } @children;
                    say "AFTER num children: ".scalar(@children);

                    if (@children == 0) {
                        say "no more children, resuming state(".$Acktor::Mailbox::State::STATES[$state].")";
                        if ($state == Acktor::Mailbox::State->STOPPING) {
                            unshift @signals => Acktor::Signals::Stopped->new;
                        }
                        elsif ($state == Acktor::Mailbox::State->RESTARTING) {
                            unshift @signals => Acktor::Signals::Started->new;
                        }

                        last;
                    }
                }
                else {
                    $behavior->receive_signal($actor, $context, $sig);
                }
            } catch ($e) {
                chomp $e;
                # XXX - what to do here???
                say "!!! GOT AN ERROR($e) WHILE PROCESSING SIGNALS!";
            }
        }

        return unless $self->is_alive;

        my @msgs  = @messages;
        @messages = ();

        foreach my $msg (@msgs) {
            try {
                $behavior->receive_message($actor, $context, $msg);
            } catch ($e) {
                $supervisor->supervise( $self, $e );
            }
        }

        return;
    }

}