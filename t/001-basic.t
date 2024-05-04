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

    method type { $type }
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

    method stop ($r) { $system->despawn_actor( $r   ) }
    method exit      { $system->despawn_actor( $ref ) }
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

    # ...

    method activate {
        $behavior = $ref->props->new_actor;
        push @signals => Actor::Signal->new( type => 'activate' );
    }

    method deactivate {
        push @signals => Actor::Signal->new( type => 'deactivate' );
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

                if ( $signal->type eq 'activate' ) {
                    $activated = true;
                }

                $behavior->signal( $context, $signal );

                if ( $signal->type eq 'deactivate' ) {
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

                warn sprintf "TICK: to:(%s), from:(%s), msg:(%s)\n" => $ref->address->url, $message->from->address->url, $message->body;

                $behavior->receive( $context, $message )
                    or push @dead_letters => $message;
            }
        }

        return map [ $ref, $_ ], @dead_letters;
    }
}

class Actor::System {
    field $address :param;

    field $root;

    field @to_be_run;
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
        push @to_be_run => $mailbox;

        $mailboxes{ $ref->address->path } = $mailbox;

        return $ref;
    }

    method despawn_actor ($ref) {
        if ( my $mailbox = delete $mailboxes{ $ref->address->path } ) {
            $mailbox->deactivate;
            push @to_be_run => $mailbox;
        }
    }

    method deliver_message ($to, $message) {
        if ( my $mailbox = $mailboxes{ $to->address->path } ) {
            $mailbox->enqueue_message( $message );
            push @to_be_run => $mailbox;
        }
        else {
            push @dead_letters => [ $to, $message ];
        }
    }

    method get_dead_letters          {      @dead_letters       }
    method send_to_dead_letters (@m) { push @dead_letters => @m }

    method list_mailboxes { keys %mailboxes }

    method tick {
        if (@to_be_run) {
            my @to_run = @to_be_run;
            @to_be_run = ();
            push @dead_letters => map $_->tick, @to_run;
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
        if ( $signal->type eq 'activate' ) {
            say('Activing Ping and creating Pong');
            $pong = $context->spawn(
                '/pong',
                Actor::Props->new(
                    class => 'Pong',
                    args  => { ping => $context->self },
                )
            );
        }
        elsif ( $signal->type eq 'deactivate' ) {
            say('Deactiving Ping and stopping Pong');
            $context->stop( $pong );
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
        if ( $signal->type eq 'activate' ) {
            say('Activing Pong');
        }
        elsif ( $signal->type eq 'deactivate' ) {
            say('Deactiving Pong');
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

sub dump_actor_heirarchy ($ctx, $indent=0) {
    warn(('    ' x $indent), $ctx->self->address->url, "\n");
    foreach my $child ($ctx->children) {
        dump_actor_heirarchy($child->context, $indent + 1);
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

dump_actor_heirarchy($root);

$ping->send( Actor::Message->new( from => $system->root, body => 'Ping' ) );

$system->tick foreach 0 .. 9;

$ping->context->exit;

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





