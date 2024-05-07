#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

use Test::More;
use Actor;

class PingPong::Ping :isa(Actor::Message) {}
class PingPong::Pong :isa(Actor::Message) {}

class Pong {
    field $ping :param;
    field $count = 0;

    my $BEHAVIOR //= Actor::Behavior->new(
        receivers => {
            PingPong::Pong:: => method ($, $) {
                $count++;
                say("Got Pong($count) sending Ping");
                $ping->send( PingPong::Ping->new );
            }
        },
        signals => {
            Actor::Signals::Lifecycle::Started:: => method ($, $) {
                say('Pong is Activated');
            },
            Actor::Signals::Lifecycle::Stopping:: => method ($, $) {
                say('Pong is Stopping');
            },
            Actor::Signals::Lifecycle::Restarting:: => method ($, $) {
                say('Pong is Restarting');
            },
            Actor::Signals::Lifecycle::Stopped:: => method ($, $) {
                say('Pong is Deactivated');
            },
        }
    );

    sub BEHAVIOR { $BEHAVIOR }
}

class Ping {
    field $pong;
    field $count = 0;

    my $BEHAVIOR //= Actor::Behavior->new(
        receivers => {
            PingPong::Ping:: => method ($context, $) {
                $count++;
                say("Got Ping($count) sending Pong");
                $pong->send( PingPong::Pong->new );
                if ($count > 9) {
                    $context->stop;
                }
            }
        },
        signals => {
            Actor::Signals::Lifecycle::Started:: => method ($context, $) {
                say('Ping is activated, creating Pong ...');
                $pong = $context->spawn(
                    '/pong',
                    Actor::Props->new(
                        class => Pong::,
                        args  => { ping => $context->self },
                    )
                );
            },
            Actor::Signals::Lifecycle::Stopping:: => method ($, $) {
                say('Ping is Stopping');
            },
            Actor::Signals::Lifecycle::Restarting:: => method ($, $) {
                say('Ping is Restarting');
            },
            Actor::Signals::Lifecycle::Stopped:: => method ($, $) {
                say('Ping is deactivated and Pong will also be');
            },
        }
    );

    sub BEHAVIOR { $BEHAVIOR }
}

## ----------------------------------------------------------------------------


my $system = Actor::System->new(
    address => Actor::Address->new
);

warn "Mailboxes:\n    ",(join ', ' => sort $system->list_active_mailboxes),"\n";

my $root = $system->root->context;
my $ping = $root->spawn( '/ping' => Actor::Props->new( class => 'Ping' ) );

warn "Mailboxes:\n    ",(join ', ' => sort $system->list_active_mailboxes),"\n";

$ping->send( PingPong::Ping->new );

$system->loop_until_done;

if ( my @dead_letters = $system->get_dead_letters ) {
    warn "Dead Letters:\n";
    warn map {
        sprintf "    to:(%s), from:(%s), msg:(%s)\n" => (
            $_->[0]->address->url,
            $_->[1]->from ? $_->[1]->from->address->url : '~',
            $_->[1]->body // blessed $_->[1]
        )
    } @dead_letters;
}

warn "Active Mailboxes:  \n    ",(join ', ' => sort $system->list_active_mailboxes  ),"\n";
warn "Inactive Mailboxes:\n    ",(join ', ' => sort $system->list_inactive_mailboxes),"\n";

done_testing;


__END__





