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
    use overload '""' => \&to_string;

    field $pid :param;

    field $context;

    method set_context ($c) { $context = $c; $self }
    method context { $context }

    method pid { $pid }

    method send ($message) {
        say "> Ref($self)::send($message)";
        $context->send_message( $self, $message );
    }

    method to_string {
        sprintf '<%s>[%03d]' => $context->props->class, $pid;
    }
}

## ------------------------------------------------------------------
## Context
## ------------------------------------------------------------------

class Context {
    use overload '""' => \&to_string;

    field $ref     :param;
    field $system  :param;
    field $mailbox :param;

    ADJUST {
        $ref->set_context( $self );
    }

    method self     { $ref               }
    method parent   { $mailbox->parent   }
    method children { $mailbox->children }
    method props    { $mailbox->props    }

    method spawn ($props) {
        say "+ $self -> spawn($props)";
        my $child = $system->spawn_actor($props, $ref);
        $mailbox->add_child( $child );
        return $child;
    }

    method send_message ($to, $message) {
        say ">> $self -> send_message($to, $message)";
        $system->enqueue_message( $to, $message );
    }

    method stop {
        say ">> $self -> stop($ref)[".$ref->pid."]";
        $system->despawn_actor( $ref );
    }

    method notify ($terminated) {
        $mailbox->notify( $terminated )
    }

    method restart { $mailbox->restart }

    method to_string {
        sprintf 'Context{ %s }' => $ref;
    }
}

## ------------------------------------------------------------------
## Actor
## ------------------------------------------------------------------

class Actor {
    method apply ($context, $message) {}

    # Event handlers for Signals
    method post_start  ($context) { say sprintf 'Started    %s' => $context->self }
    method pre_stop    ($context) { say sprintf 'Stopping   %s' => $context->self }
    method pre_restart ($context) { say sprintf 'Restarting %s' => $context->self }
    method post_stop   ($context) { say sprintf 'Stopped    %s' => $context->self }
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
        say "<<< Behavior->receive_message(actor($actor), context($context), message($message))";
        $actor->apply($context, $message);
    }

    method receive_signal  ($actor, $context, $signal)  {
        say "<<< Behavior->receive_signal(actor($actor), context($context), signal($signal))";
        $actor->apply($context, $signal);
    }
}

## ------------------------------------------------------------------
## Props
## ------------------------------------------------------------------

class Props {
    use overload '""' => \&to_string;

    field $class :param;
    field $args  :param = {};
    field $alias :param = undef;

    method class { $class }
    method alias { $alias }

    method new_actor {
        say "++ $self -> new_actor($class)";
        $class->new( %$args )
    }

    method new_supervisor { Supervisor->new }
    method new_behavior   { Behavior->new }

    method to_string { "Props[$class]" }
}


## ------------------------------------------------------------------
## Mailboxes
## ------------------------------------------------------------------

class MailboxState {
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

class Mailbox {
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
        $state   = MailboxState->STARTING;
        $ref     = Ref->new( pid => ++$PID_SEQ );
        $context = Context->new( ref => $ref, mailbox => $self, system => $system );

        $supervisor = $props->new_supervisor;
        $behavior   = $props->new_behavior;

        push @signals => Started->new;
    }

    method to_string { "Mailbox( $ref )" }

    method parent   { $parent   }
    method children { @children }

    method add_child ($child) { push @children => $child }

    method props  { $props  }
    method system { $system }

    method is_starting   { $state == MailboxState->STARTING   }
    method is_alive      { $state == MailboxState->ALIVE      }
    method is_suspended  { $state == MailboxState->SUSPENDED  }
    method is_stopping   { $state == MailboxState->STOPPING   }
    method is_restarting { $state == MailboxState->RESTARTING }
    method is_stopped    { $state == MailboxState->STOPPED    }

    method ref     { $ref     }
    method context { $context }

    method to_be_run { @messages || @signals }

    method enqueue_message ($message) { push @messages => $message }

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
                if ($sig isa Started) {
                    $state = MailboxState->ALIVE;
                    $actor = $props->new_actor;
                    $actor->post_start( $context );
                }
                elsif ($sig isa Stopping) {
                    $actor->pre_stop( $context );
                    if ( @children ) {
                        # wait for the children
                        $state = MailboxState->STOPPING;
                        $_->context->stop foreach @children;
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
                        $state = MailboxState->RESTARTING;
                        $_->context->stop foreach @children;
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
                        say "$self is Stopped, notifying $parent";
                        $parent->context->notify( Terminated->new( ref => $ref ) );
                    }
                    # and exit
                    last;
                }
                elsif ($sig isa Terminated) {
                    my $child = $sig->ref;

                    say "$self got TERMINATED($child) while in state(".$MailboxState::STATES[$state].")";

                    say "CHILDREN: ", join ', ' => @children;
                    say "BEFORE num children: ".scalar(@children);
                    @children = grep { $_->pid ne $child->pid } @children;
                    say "AFTER num children: ".scalar(@children);

                    if (@children == 0) {
                        say "no more children, resuming state(".$MailboxState::STATES[$state].")";
                        if ($state == MailboxState->STOPPING) {
                            unshift @signals => Stopped->new;
                        }
                        elsif ($state == MailboxState->RESTARTING) {
                            unshift @signals => Started->new;
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

## ------------------------------------------------------------------
## System Actors
## ------------------------------------------------------------------

class DeadLetter {
    field $to      :param;
    field $message :param;
    method to      { $to      }
    method message { $message }
    method to_string { sprintf '%s(%03d) (%s)' => $to->context->props->class, $to->pid, "$message" }
}

class System::Actors::DeadLetter :isa(Actor) {
    field @dead_letters;

    method dead_letters { @dead_letters }

    method apply ($context, $message) {
        push @dead_letters => DeadLetter->new( to => $context->self, message => $message );
        say "*** DEAD LETTER(".$dead_letters[-1].") ***";
    }
}

## ------------------------------------------------------------------

class System::Actors::System :isa(Actor) {
    method post_start  ($context) {
        say sprintf 'Started    %s' => $context->self;
        $context->spawn( Props->new(
            class => 'System::Actors::DeadLetter',
            alias => '//sys/dead_letters',
        ));
    }
}

class System::Actors::Users :isa(Actor) {
    field $init :param;

    method post_start  ($context) {
        say sprintf 'Started    %s' => $context->self;
        try {
            say "Running init callback for $context";
            $init->($context);
        } catch ($e) {
            say "!!!!!! Error running init callback for $context with ($e)";
        }
    }
}

## ------------------------------------------------------------------

class System::Root :isa(Actor) {
    field $init :param;

    method post_start  ($context) {
        say sprintf 'Started    %s' => $context->self;

        $context->spawn( Props->new( class => 'System::Actors::System', alias => '//sys') );
        $context->spawn( Props->new( class => 'System::Actors::Users',  alias => '//usr', args => { init => $init }) );
    }
}

## ------------------------------------------------------------------
## System
## ------------------------------------------------------------------

class System {

    field $root;

    field %lookup;
    field @mailboxes;

    method spawn_actor ($props, $parent=undef) {
        say "+++ System::spawn($props)";
        my $mailbox = Mailbox->new( props => $props, system => $self, parent => $parent );
        $lookup{ $mailbox->ref->pid } = $mailbox;
        if (my $alias = $mailbox->props->alias ) {
            $lookup{ $alias } = $mailbox;
        }
        push @mailboxes => $mailbox;
        return $mailbox->ref;
    }

    method despawn_actor ($ref) {
        say "+++ System::despawn($ref) for ".$ref->context->props->class ."[".$ref->pid."]";
        if (my $mailbox = $lookup{ $ref->pid }) {
            $lookup{ $ref->pid } = $lookup{ '//sys/dead_letters' };
            if (my $alias = $mailbox->props->alias ) {
                delete $lookup{ $alias };
            }
            $mailbox->stop;
        }
        else {
            warn "ACTOR NOT FOUND: $ref";
        }
    }

    method enqueue_message ($to, $message) {
        say ">>> System::enqueue_message to($to) message($message)";
        if (my $mailbox = $lookup{ $to->pid }) {
            $mailbox->enqueue_message( $message );
        }
        else {
            die "DEAD LETTERS: $to $message";
        }
    }

    method init ($init) {
        $root = $self->spawn_actor( Props->new( class => 'System::Root', alias => '//', args => { init => $init } ) );
        $self;
    }

    method tick {
        say "-- start:tick -----------------------------------------";

        my @to_run = grep $_->to_be_run, @mailboxes;

        foreach my $mailbox ( @to_run  ) {
            say "~~ BEGIN tick for $mailbox";
            $mailbox->tick;
            say "~~ END tick for $mailbox";
        }

        @mailboxes = grep !$_->is_stopped, @mailboxes;

        say "-- end:tick -------------------------------------------";
        $self->print_actor_tree($root);
    }

    method loop_until_done {
        say "-- start:loop -----------------------------------------";
        while (1) {
            $self->tick;

            if (my $usr = $lookup{ '//usr' } ) {
                if ( $usr->is_alive && !$usr->children ) {
                    say "/// ENTERING SHUTDOWN ///";
                    $root->context->stop;
                }
            }

            last unless @mailboxes;
        }
        say "-- end:loop -------------------------------------------";
    }

    method print_actor_tree ($ref, $indent='') {
        say sprintf '%s<%s>[%03d]' => $indent, $ref->context->props->class, $ref->pid;
        $indent .= '  ';
        foreach my $child ( $ref->context->children ) {
            $self->print_actor_tree( $child, $indent );
        }
    }

}


## ------------------------------------------------------------------

class Bar {}

class Foo :isa(Actor) {
    field $depth :param = 1;
    field $max   :param = 4;

    method apply ($context, $message) {
        say "HELLO JOE! => { Actor($self) got $context and message($message) }";
    }

    method post_start  ($context) {
        say sprintf 'Started    %s' => $context->self;
        if ( $depth <= $max ) {
            $context->spawn(Props->new(
                class => 'Foo',
                args => {
                    depth => $depth + 1,
                    max   => $max
                }
            ));
        }
        else {
            # find the topmost Foo
            my $x = $context->self;
            do {
                $x = $x->context->parent;
            } while $x->context->parent
                 && $x->context->parent->context->props->class eq 'Foo';

            # and stop it
            $x->context->stop;
        }
    }

    method pre_stop    ($context) { say sprintf 'Stopping   %s' => $context->self }
    method pre_restart ($context) { say sprintf 'Restarting %s' => $context->self }
    method post_stop   ($context) { say sprintf 'Stopped    %s' => $context->self }
}

my $sys = System->new->init(sub ($context) {
    $context->spawn( Props->new( class => 'Foo' ) );
});


$sys->loop_until_done;

