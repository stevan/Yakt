#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

use Test::More;

## ----------------------------------------------------------------------------

class Actor::Address {
    field $host :param = '0';
    field $path :param = +[];

    my sub normalize_path ($p) { ref $p ? $p : [ grep $_, split '/' => $p ] }

    ADJUST { $path = normalize_path($path) }

    method host { $host                          }
    method path { join '/' => @$path             }
    method url  { join '/' => $host, $self->path }

    method with_path (@p) {
        Actor::Address->new(
            host => $host,
            path => [ @$path, map normalize_path($_)->@*, @p ]
        )
    }
}

class Actor::Message {
    field $from :param;
    field $body :param;

    method from { $from }
    method body { $body }
}

class Actor::Signal {
    field $type :param;
    field $body :param = undef;

    method type { $type }
    method body { $body }
}

class Actor::Props {
    field $class :param;
    field $args  :param = +{};

    method class { $class }
    method args  { $args  }

    method new_actor {
        $class->new( %$args )
    }
}

class Actor::Context {
    field $system :param;
    field $parent :param;

    field $ref;
    field @children;

    method has_self         { !! $ref      }
    method self             {    $ref      }
    method assign_self ($r) {    $ref = $r }

    method has_parent   { !! $parent          }
    method has_children { !! scalar @children }

    method parent   { $parent   }
    method children { @children }

    # ...

    method spawn ($path, $props) {
        my $child = $system->spawn_actor( $ref->address->with_path($path), $props, $ref );
        push @children => $child;
        return $child;
    }

    method send_to ($to, $message) {
        $system->deliver_message( $to, $message );
        return;
    }

    method kill ($r) { $system->despawn_actor( $r ) }

    method exit {
        if ( @children ) {
            $system->despawn_actor( $_ ) foreach @children;
            $system->despawn_actor( $ref );
        }
        else {
            $system->despawn_actor( $ref );
        }
    }
}

class Actor::Ref {
    field $address :param;
    field $props   :param;
    field $context :param;

    ADJUST { $context->assign_self( $self ) }

    method props   { $props   }
    method address { $address }
    method context { $context }

    method send ($message) {
        $context->send_to( $self, $message );
        return;
    }
}

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

    method to_be_run { @signals || @messages }

    # ...

    method activate {
        $behavior = $ref->props->new_actor;
        push @signals => Actor::Signal->new( type => 'activated' );
    }

    method deactivate {
        push @signals => Actor::Signal->new( type => 'deactivated' );
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

                warn sprintf "SIGNAL: to:(%s), sig:(%s)\n" => $ref->address->url, $signal->type;

                if ( $signal->type eq 'activated' ) {
                    $activated = true;
                }

                try {
                    $behavior->signal( $context, $signal );
                } catch ($e) {
                    warn "Error handling signal(".$signal->type.") : $e";
                }

                if ( $signal->type eq 'deactivated' ) {
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

                warn sprintf "TICK: to:(%s), from:(%s), body:(%s)\n" => $ref->address->url, $message->from->address->url, $message->body;

                try {
                    $behavior->receive( $context, $message )
                        or push @dead_letters => $message;
                } catch ($e) {
                    # TODO: add restart strategy here ...
                    warn sprintf "ERROR: MSG( to:(%s), from:(%s), body:(%s) )\n" => $ref->address->url, $message->from->address->url, $message->body;
                    push @dead_letters => $message;
                }
            }
        }

        return map [ $ref, $_ ], @dead_letters;
    }
}

class Actor::System {
    field $address :param;

    field $root;

    field %mailboxes;
    field @dead_letters;

    ADJUST {
        $root = $self->spawn_actor(
            $address->with_path('/-'),
            Actor::Props->new( class => 'Actor::Behavior' )
        );
    }

    method address { $address }
    method root    { $root    }

    method spawn_actor ($addr, $props, $parent=undef) {
        my $ref = Actor::Ref->new(
            address => $addr,
            props   => $props,
            context => Actor::Context->new(
                system => $self,
                parent => $parent
            )
        );

        my $mailbox = Actor::Mailbox->new( ref => $ref );
        $mailbox->activate;

        $mailboxes{ $ref->address->path } = $mailbox;

        return $ref;
    }

    method despawn_actor ($ref) {
        if ( my $mailbox = $mailboxes{ $ref->address->path } ) {
            $mailbox->deactivate;
        }
    }

    method deliver_message ($to, $message) {
        if ( my $mailbox = $mailboxes{ $to->address->path } ) {
            $mailbox->enqueue_message( $message );
        }
        else {
            push @dead_letters => [ $to, $message ];
        }
    }

    method deliver_signal ($to, $signal) {
        if ( my $mailbox = $mailboxes{ $to->address->path } ) {
            $mailbox->enqueue_signal( $signal );
        }
    }

    method get_dead_letters          {      @dead_letters       }
    method send_to_dead_letters (@m) { push @dead_letters => @m }

    method list_mailboxes { keys %mailboxes }

    method tick {
        my @to_run = grep $_->to_be_run, values %mailboxes;

        foreach my $mailbox ( @to_run ) {
            push @dead_letters => $mailbox->tick;

            delete $mailboxes{ $mailbox->ref->address->path }
                if $mailbox->is_deactivated;
        }
    }
}

## ----------------------------------------------------------------------------

class Actor::Behavior {
    method receive ($context, $message) {}
    method signal  ($context, $signal ) {}
}

## ----------------------------------------------------------------------------


class Ping :isa(Actor::Behavior) {
    field $pong;
    field $count = 0;

    method signal ($context, $signal) {
        if ( $signal->type eq 'activated' ) {
            say('Ping is activated, creating Pong ...');
            $pong = $context->spawn(
                '/pong',
                Actor::Props->new(
                    class => 'Pong',
                    args  => { ping => $context->self },
                )
            );
        }
        elsif ( $signal->type eq 'deactivated' ) {
            say('Ping is deactivated and Pong will also be');
        }
    }

    method receive ($context, $message) {
        if ( $message->body eq 'Ping' ) {
            $count++;
            say("Got Ping($count) sending Pong");
            $pong->send( Actor::Message->new( from => $context->self, body => 'Pong' ) );
            return true;
        } else {
            say("Unknown message: ".$message->body);
            return false;
        }
    }
}

class Pong :isa(Actor::Behavior) {
    field $ping :param;

    field $count = 0;

    method signal ($context, $signal) {
        if ( $signal->type eq 'activated' ) {
            say('Pong is Activated');
        }
        elsif ( $signal->type eq 'deactivated' ) {
            say('Pong is Deactivated');
        }
    }

    method receive ($context, $message) {
        if ( $message->body eq 'Pong' ) {
            $count++;
            say("Got Pong($count) sending Ping");
            $ping->send( Actor::Message->new( from => $context->self, body => 'Ping' ) );
            return true;
        } else {
            say("Unknown message: ".$message->body);
            return false;
        }
    }
}

## ----------------------------------------------------------------------------


my $system = Actor::System->new(
    address => Actor::Address->new( host => '0:3000' )
);

warn "Mailboxes:\n    ",(join ', ' => sort $system->list_mailboxes),"\n";

my $root = $system->root->context;

my $ping = $root->spawn( '/ping' => Actor::Props->new( class => 'Ping' ) );

warn "Mailboxes:\n    ",(join ', ' => sort $system->list_mailboxes),"\n";

$ping->send( Actor::Message->new( from => $system->root, body => 'Ping' ) );

$system->tick foreach 0 .. 9;

$ping->context->exit;

$system->tick foreach 0 .. 9;

# these both end up in dead-letters ...

$ping->send( Actor::Message->new( from => $system->root, body => 'Ping' ) );
$system->tick foreach 0 .. 9;

$ping->send( Actor::Message->new( from => $system->root, body => 'Ping' ) );
$system->tick foreach 0 .. 9;

if ( my @dead_letters = $system->get_dead_letters ) {
    warn "Dead Letters:\n";
    warn map {
        sprintf "    to:(%s), from:(%s), msg:(%s)\n" => (
            $_->[0]->address->url,
            $_->[1]->from->address->url,
            $_->[1]->body
        )
    } @dead_letters;
}

warn "Mailboxes:\n    ",(join ', ' => sort $system->list_mailboxes),"\n";

done_testing;


__END__





