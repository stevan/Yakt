#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

use Test::More;
use Actor;

class PingPong::Ping :isa(Actor::Message) {}
class PingPong::Pong :isa(Actor::Message) {}

class Ping :isa(Actor::Behavior) {
    field $pong;
    field $count = 0;

    method signal ($context, $signal) {
        if ( $signal isa Actor::Signals::Lifecycle::Activated ) {
            say('Ping is activated, creating Pong ...');
            $pong = $context->spawn(
                '/pong',
                Actor::Props->new(
                    class => 'Pong',
                    args  => { ping => $context->self },
                )
            );
        }
        elsif ( $signal isa Actor::Signals::Lifecycle::Deactivated ) {
            say('Ping is deactivated and Pong will also be');
        }
    }

    method receive ($context, $message) {
        if ( $message isa PingPong::Ping ) {
            $count++;
            say("Got Ping($count) sending Pong");
            $pong->send( PingPong::Pong->new( from => $context->self ) );
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

    method signal ($context, $signal) {
        if ( $signal isa Actor::Signals::Lifecycle::Activated ) {
            say('Pong is Activated');
        }
        elsif ( $signal isa Actor::Signals::Lifecycle::Deactivated ) {
            say('Pong is Deactivated');
        }
    }

    method receive ($context, $message) {
        if ( $message isa PingPong::Pong ) {
            $count++;
            say("Got Pong($count) sending Ping");
            $ping->send( PingPong::Ping->new( from => $context->self ) );
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

warn "Mailboxes:\n    ",(join ', ' => sort $system->list_mailboxes),"\n";

my $root = $system->root->context;

my $ping = $root->spawn( '/ping' => Actor::Props->new( class => 'Ping' ) );

warn "Mailboxes:\n    ",(join ', ' => sort $system->list_mailboxes),"\n";

$ping->send( PingPong::Ping->new( from => $system->root ) );

$system->tick foreach 0 .. 9;

$ping->context->exit;

$system->tick foreach 0 .. 9;

# these both end up in dead-letters ...

$ping->send( PingPong::Ping->new( from => $system->root ) );
$system->tick foreach 0 .. 9;

$ping->send( PingPong::Ping->new( from => $system->root ) );
$system->tick foreach 0 .. 9;

if ( my @dead_letters = $system->get_dead_letters ) {
    warn "Dead Letters:\n";
    warn map {
        sprintf "    to:(%s), from:(%s), msg:(%s)\n" => (
            $_->[0]->address->url,
            $_->[1]->from->address->url,
            $_->[1]->body // blessed $_->[1]
        )
    } @dead_letters;
}

warn "Mailboxes:\n    ",(join ', ' => sort $system->list_mailboxes),"\n";

done_testing;


__END__





