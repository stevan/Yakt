#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

use Test::More;

## ----------------------------------------------------------------------------

class Actor::Address {
    field $host :param = '-';
    field $path :param = +[];

    my sub normalize_path ($p) { ref $p ? $p : [ grep $_, split '/' => $p ] }

    ADJUST { $path = normalize_path($path) }

    method path { join '/' => @$path }
    method url  { join '/' => $host, $self->path }

    method with_path (@p) {
        Actor::Address->new(
            host => $host,
            path => [ @$path, map normalize_path($_)->@*, @p ]
        )
    }
}

class Actor::Props {
    field $class :param;
    field $args  :param = +{};

    method new_actor {
        $class->new( %$args )
    }
}

class Actor::Context {
    field $system :param;
    field $ref    :param;

    field $current_sender;
    field $current_message;

    method self    { $ref             }
    method sender  { $current_sender  }
    method message { $current_message }

    method set_message_context ($sender, $message) {
        $current_sender  = $sender;
        $current_message = $message;
    }

    method clear_message_context {
        $current_sender  = undef;
        $current_message = undef;
    }

    method spawn ($path, $props) {
        return $system->spawn_actor( $path, $props );
    }

    method send ($to, $message) {
        $system->deliver_message( $to, $ref, $message );
        return;
    }

    method stop ($r) { $system->despawn_actor( $r   ) }
    method exit      { $system->despawn_actor( $ref ) }
}

class Actor::Ref {
    field $address :param;

    field $context;

    method address { $address }
    method context { $context }

    method set_context ($ctx) { $context = $ctx }

    method send ($to, $message) {
        $context->send( $to, $message );
        return;
    }
}

class Actor::Mailbox {
    field $ref   :param;
    field $props :param;

    field $behavior;
    field @messages;

    method ref   { $ref   }
    method props { $props }

    # ...

    method is_active    { !! $behavior }
    method has_messages { !! scalar @messages }

    method activate ($system) {
        $behavior = $props->new_actor;
        $behavior->activate( $ref->context );
    }

    method deactivate ($system) {
        $behavior->deactivate( $ref->context );
        $behavior = undef;

        if (@messages) {
            $system->send_to_dead_letters( map [ $ref, @$_ ], @messages );
            @messages = ();
        }
    }

    # ...

    method enqueue_message ( $from, $message ) {
        push @messages => [ $from, $message ];
    }

    # ...

    method tick {
        my @dead_letters;

        if (@messages) {
            my @msgs  = @messages;
            @messages = ();

            my $context = $ref->context;
            while (@msgs) {
                my ($from, $message) = (shift @msgs)->@*;

                warn sprintf "TICK: to:(%s), from:(%s), msg:(%s)\n" => $ref->address->url, $from->address->url, $message;

                $context->set_message_context( $from, $message );
                unless ( $behavior->accept( $context, $message ) ) {
                    push @dead_letters => $message;
                }
                $context->clear_message_context;
            }
        }

        return @dead_letters;
    }
}

class Actor::System {
    field $address :param;

    field @to_be_run;
    field %mailboxes;
    field @dead_letters;

    method address { $address }

    method spawn_actor ($path, $props) {
        my $ref = Actor::Ref->new( address => $address->with_path( $path ) );
        $ref->set_context( Actor::Context->new( system => $self, ref => $ref ) );

        my $mailbox = Actor::Mailbox->new( ref => $ref, props => $props );
        $mailbox->activate( $self );

        $mailboxes{ $ref->address->url } = $mailbox;

        return $ref;
    }

    method despawn_actor ($ref) {
        if ( my $mailbox = delete $mailboxes{ $ref->address->url } ) {
            $mailbox->deactivate( $self );
        }
    }

    method deliver_message ($to, $from, $message) {
        if ( my $mailbox = $mailboxes{ $to->address->url } ) {
            $mailbox->enqueue_message( $from, $message );
            push @to_be_run => $mailbox;
        }
        else {
            push @dead_letters => [ $to, $from, $message ];
        }
    }

    method get_dead_letters { @dead_letters }
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
    method activate   ($context) {}
    method deactivate ($context) {}
    method accept     ($context, $message) { ... }
}

## ----------------------------------------------------------------------------

class Ping :isa(Actor::Behavior) {

    field $pong;
    field $count = 0;

    method activate ($context) {
        say('Activing Ping and creating Pong');
        $pong = $context->spawn(
            '/pong',
            Actor::Props->new(
                class => 'Pong',
                args  => { ping => $context->self },
            )
        );
    }

    method deactivate ($context) {
        say('Deactiving Ping and stopping Pong');
        $context->stop( $pong );
        $pong = undef;
    }

    method accept ($context, $message) {
        if ( $message eq 'Ping' ) {
            $count++;
            say("Got Ping($count) sending Pong");
            $context->send( $pong, 'Pong' );
            return true;
        } else {
            say("Unknown message: $message");
            return false;
        }
    }
}

class Pong :isa(Actor::Behavior) {
    field $ping :param;

    field $count = 0;

    method activate ($context) {
        say('Activing Pong');
    }

    method deactivate ($context) {
        say('Deactiving Pong');
        $ping = undef;
    }

    method accept ($context, $message) {
        if ( $message eq 'Pong' ) {
            $count++;
            say("Got Pong($count) sending Ping");
            $context->send( $ping, 'Ping' );
            return true;
        } else {
            say("Unknown message: $message");
            return false;
        }
    }
}


## ----------------------------------------------------------------------------


my $system = Actor::System->new(
    address => Actor::Address->new( host => '0:3000' )
);

my $ping = $system->spawn_actor(
    '/ping' => Actor::Props->new( class => 'Ping' )
);

warn "Mailboxes: ",(join ', ' => $system->list_mailboxes),"\n";

$system->deliver_message( $ping, $system, 'Ping' );

$system->tick foreach 0 .. 10;

$ping->context->exit;

warn "Dead Letters:\n";
warn map {
    sprintf "to:(%s), from:(%s), msg:(%s)\n" => $_->[0]->address->url, $_->[1]->address->url, $_->[2]
} $system->get_dead_letters;

done_testing;


__END__





