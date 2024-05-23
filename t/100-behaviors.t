#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

use Test::More;

## ------------------------------------------------------------------
## Signals
## ------------------------------------------------------------------

class Signal {}

class Started    :isa(Signal) {}
class Stopping   :isa(Signal) {}
class Restarting :isa(Signal) {}
class Stopped    :isa(Signal) {}

class Terminated :isa(Signal) {
    field $ref :param;
    method ref { $ref }
}

## ------------------------------------------------------------------
## Ref
## ------------------------------------------------------------------

class Ref {
    field $pid :param;

    field $context;

    method set_context ($c) { $context = $c; $self }
    method context { $context }

    method pid { $pid }

    method send ($message) {
        say "> Ref($self)::send($message)";
        $context->send_message( $self, $message );
    }
}

## ------------------------------------------------------------------
## Context
## ------------------------------------------------------------------

class Context {
    field $ref     :param;
    field $mailbox :param;

    ADJUST {
        $ref->set_context( $self );
    }

    method self     { $ref               }
    method parent   { $mailbox->parent   }
    method children { $mailbox->children }
    method props    { $mailbox->props    }

    method spawn ($props) {
        say "+ Context($self)::spawn($props)";
        return $mailbox->spawn_child($props);
    }

    method send_message ($to, $message) {
        say ">> Context($self)::send_message($to, $message)";
        $mailbox->system->enqueue_message( $to, $message );
    }

    method stop    { $mailbox->system->despawn_actor( $ref ) }
    method restart { $mailbox->restart }
}

## ------------------------------------------------------------------
## Actor
## ------------------------------------------------------------------

class Actor {
    method apply ($context, $message) {}

    # Event handlers for Signals
    method post_start  ($context) { } # Started
    method pre_stop    ($context) { } # Stopping
    method pre_restart ($context) { } # Restarting
    method post_stop   ($context) { } # Stopped
}

## ------------------------------------------------------------------
## Supervisor
## ------------------------------------------------------------------

class Supervisor {
    method supervise ($mailbox, $e) {
        say "!!! OH NOES, we got an error ($e)";
    }
}

## ------------------------------------------------------------------
## Behaviors
## ------------------------------------------------------------------

class Behavior {
    method receive_message ($actor, $context, $message) {
        say "<<< Behavior($self)::receive_message(actor($actor), context($context), message($message))";
        $actor->apply($context, $message);
    }

    method receive_signal  ($actor, $context, $signal)  {
        say "<<< Behavior($self)::receive_signal(actor($actor), context($context), signal($signal))";
        $actor->apply($context, $signal);
    }
}

## ------------------------------------------------------------------
## Props
## ------------------------------------------------------------------

class Props {
    field $class :param;
    field $args  :param = {};

    method class { $class }

    method new_actor {
        say "++ Props($self)::new_actor($class)";
        $class->new( %$args )
    }

    method new_supervisor { Supervisor->new }
    method new_behavior   { Behavior->new }
}


## ------------------------------------------------------------------
## Mailboxes
## ------------------------------------------------------------------

class MailboxState {
    use constant STARTING  => 0;
    use constant ALIVE     => 1;
    use constant SUSPENDED => 2;
    use constant WAITING   => 3;
    use constant STOPPED   => 4;
}

class Mailbox {
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
        $state   = MailboxState->STARTING;
        $ref     = Ref->new( pid => ++$PID_SEQ );
        $context = Context->new( ref => $ref, mailbox => $self );

        $supervisor = $props->new_supervisor;
        $behavior   = $props->new_behavior;

        push @signals => Started->new;
    }

    method parent   { $parent   }
    method children { @children }

    method props  { $props  }
    method system { $system }

    method spawn_child ($props) {
        my $child = $system->spawn_actor( $props, $ref );
        push @children => $child;
        return $child;
    }

    method is_starting  { $state == MailboxState->STARTING  }
    method is_alive     { $state == MailboxState->ALIVE     }
    method is_suspended { $state == MailboxState->SUSPENDED }
    method is_waiting   { $state == MailboxState->WAITING   }
    method is_stopped   { $state == MailboxState->STOPPED   }

    method ref     { $ref     }
    method context { $context }

    method enqueue_message ($message) {
        if ($message isa Signal) {
            push @signals => $message;
        }
        else {
            push @messages => $message;
        }
    }

    method suspend { $state = MailboxState->SUSPENDED }
    method resume  { $state = MailboxState->ALIVE     }

    method restart {
        $self->suspend;
        push @signals => Restarting->new;
    }
    method stop {
        $self->suspend;
        push @signals => Stopping->new;
    }

    method tick {

        my @sigs = @signals;
        @signals = ();

         while (@sigs) {
            my $sig = shift @sigs;
            say "%% GOT SIGNAL($sig)";
            try {
                if ($sig isa Started) {
                    $state = MailboxState->ALIVE;
                    $actor = $props->new_actor;
                    $actor->post_start( $context );
                }
                elsif ($sig isa Stopping) {
                    $actor->pre_stop( $context );
                    if ( @children ) {
                        # wait for the children
                        $state = MailboxState->WAITING;
                        $system->despawn_actor( $_ ) foreach @children;
                    } else {
                        # if there are no children then
                        # make sure Stopped is the next
                        # thing processed
                        unshift @signals => Stopped->new;
                        last;
                    }
                }
                elsif ($sig isa Restarting) {
                    $actor->pre_restart( $context );
                    if ( @children ) {
                        # wait for the children
                        $state = MailboxState->WAITING;
                        $system->despawn_actor( $_ ) foreach @children;
                    } else {
                        # if there are no children then
                        # restart the actor and make sure
                        # Started is the next signal
                        # that is processed
                        unshift @signals => Started->new;
                        last;
                    }
                }
                elsif ($sig isa Stopped) {
                    # ... what to do here
                    $actor->post_stop( $context );
                    $state = MailboxState->STOPPED;
                    # we can destruct the mailbox here
                    $actor    = undef;
                    @messages = ();

                    if ($parent) {
                        $parent->send( Terminated->new( ref => $ref ) );
                    }
                    # and exit
                    last;
                }
                elsif ($sig isa Terminated && $self->is_waiting) {
                    my $child = $sig->ref;

                    say "::::: GOT TERMINATED!!! ($child)[".$child->pid."]";

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

## ------------------------------------------------------------------
## System
## ------------------------------------------------------------------

class System::Root :isa(Actor) {
    method post_start  ($context) { say "Started ($self)"    }
    method pre_stop    ($context) { say "Stopping ($self)"   }
    method pre_restart ($context) { say "Restarting ($self)" }
    method post_stop   ($context) { say "Stopped ($self)"    }
}

class DeadLetter {
    field $to      :param;
    field $message :param;
    method to      { $to      }
    method message { $message }
    method to_string { sprintf '%s(%03d) (%s)' => $to->context->props->class, $to->pid, "$message" }
}

class System::DeadLetter :isa(Actor) {
    field @dead_letters;

    method post_start  ($context) { say "Started ($self)"    }
    method pre_stop    ($context) { say "Stopping ($self)"   }
    method pre_restart ($context) { say "Restarting ($self)" }
    method post_stop   ($context) { say "Stopped ($self)"    }

    method dead_letters { @dead_letters }

    method apply ($context, $message) {
        push @dead_letters => DeadLetter->new( to => $context->self, message => $message );
        say "*** DEAD LETTER(".$dead_letters[-1].") ***";
    }
}

class System {

    field $root;
    field $dead_letters;

    field %lookup;
    field @mailboxes;

    method spawn_actor ($props, $parent=undef) {
        say "+++ System::spawn($props)";
        my $mailbox = Mailbox->new( props => $props, system => $self, parent => $parent );
        $lookup{ $mailbox->ref->pid } = $mailbox;
        push @mailboxes => $mailbox;
        return $mailbox->ref;
    }

    method despawn_actor ($ref) {
        say "+++ System::despawn($ref) for ".$ref->context->props->class;
        if (my $m = $lookup{ $ref->pid }) {
            $lookup{ $ref->pid } = $lookup{ $dead_letters->pid };
            $m->stop;
        }
        else {
            warn "ACTOR NOT FOUND: $ref";
        }
    }

    method enqueue_message ($to, $message) {
        say ">>> System::enqueue_message to($to) message($message)";
        if (my $m = $lookup{ $to->pid }) {
            $m->enqueue_message( $message );
        }
        else {
            warn "DEAD LETTERS: $to $message";
        }
    }

    method root_context { $root->context }

    method init {
        $root         = $self->spawn_actor( Props->new( class => 'System::Root')  );
        $dead_letters = $root->context->spawn( Props->new( class => 'System::DeadLetter') );
        $self;
    }

    method tick {
        say "-- start:tick -----------------------------------------";
        foreach my $mailbox ( @mailboxes ) {
            say "~~ Tick for mailbox($mailbox)(".$mailbox->props->class.")";
            $mailbox->tick;
        }
        @mailboxes = grep !$_->is_stopped, @mailboxes;
        say "-- end:tick -------------------------------------------";
    }

}


## ------------------------------------------------------------------

class Bar {}

class Foo :isa(Actor) {

    method apply ($context, $message) {
        say "HELLO JOE! => { Actor($self) got context($context) and message($message) }";
    }

    method post_start  ($context) { say "Started ($self)"    }
    method pre_stop    ($context) { say "Stopping ($self)"   }
    method pre_restart ($context) { say "Restarting ($self)" }
    method post_stop   ($context) { say "Stopped ($self)"    }
}

my $sys = System->new->init;

my $root = $sys->root_context;
my $foo = $root->spawn( Props->new( class => 'Foo' ) );

$foo->send(Bar->new);
$sys->tick;

$foo->context->restart;
$foo->send(Bar->new);
$foo->send(Bar->new);
$foo->send(Bar->new);

$sys->tick;
$sys->tick;
$sys->tick;

$foo->context->stop;
$foo->send(Bar->new);

$sys->tick;
$sys->tick;
$sys->tick;

$root->stop;

$sys->tick;
$sys->tick;
$sys->tick;













