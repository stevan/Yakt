#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

use Test::More;
use Actor;

class PingPong::Serve   :isa(Actor::Message) {}
class PingPong::EndGame :isa(Actor::Message) {}

class PingPong::Bounce :isa(Actor::Message) {
    field $count :param;
    method count { $count }
    method to_string { sprintf '%s[%d]' => blessed $self, $count }
}

class PingPong::Ping :isa(PingPong::Bounce) {}
class PingPong::Pong :isa(PingPong::Bounce) {}

class Pong {
    use Actor::Logging;

    field $ping :param;

    field $logger;

    ADJUST {
        $logger = Actor::Logging->logger( "Pong" ) if LOG_LEVEL;
    }

    my $BEHAVIOR //= Actor::Behavior->new(
        receivers => {
            PingPong::Ping:: => method ($context, $message) {
                my $next = PingPong::Pong->new( count => $message->count + 1 );
                $logger->log(INFO, "Got $message sending $next") if INFO;
                $ping->send( $next );

                if (($next->count % 3) == 0) {
                    die "!!! Sending Restart to Pong";
                }
            }
        },
        signals => {
            Actor::Signals::Lifecycle::Started:: => method ($, $) {
                $logger->log(INFO, "Pong is Activated") if INFO;
            },
            Actor::Signals::Lifecycle::Stopping:: => method ($, $) {
                $logger->log(INFO, "Pong is Stopping") if INFO;
            },
            Actor::Signals::Lifecycle::Restarting:: => method ($, $) {
                $logger->log(INFO, "Pong is Restarting") if INFO;
            },
            Actor::Signals::Lifecycle::Stopped:: => method ($, $) {
                $logger->log(INFO, "Pong is Deactivated") if INFO;
            },
        }
    );

    sub BEHAVIOR { $BEHAVIOR }

    sub SUPERVISOR { Actor::Supervisors->Restart }
}

class Ping {
    use Actor::Logging;

    field $pong;

    field $logger;

    ADJUST {
        $logger = Actor::Logging->logger( "Ping" ) if LOG_LEVEL;
    }

    my $BEHAVIOR //= Actor::Behavior->new(
        receivers => {
            PingPong::Serve:: => method ($, $) {
                my $first = PingPong::Ping->new( count => 0 );
                $logger->log(INFO, "Serving $first to Pong") if INFO;
                $pong->send( $first );
            },
            PingPong::Pong:: => method ($context, $message) {
                my $next = PingPong::Ping->new( count => $message->count + 1 );
                $logger->log(INFO, "Got $message sending $next") if INFO;
                $pong->send( $next );

                if (($next->count % 10) == 0) {
                    die "OH NOES!! Ping is dying!";
                }
            },
            PingPong::EndGame:: => method ($context, $) {
                $logger->log(INFO, "Okay, that is enough") if INFO;
                $context->stop;
            },
        },
        signals => {
            Actor::Signals::Lifecycle::Started:: => method ($context, $) {
                $logger->log(INFO, "Ping is activated, creating Pong ...") if INFO;
                $pong = $context->spawn(
                    '/pong',
                    Actor::Props->new(
                        class => Pong::,
                        args  => { ping => $context->self },
                    )
                );

                $context->self->send( PingPong::Serve->new );
            },
            Actor::Signals::Lifecycle::Stopping:: => method ($context, $) {
                $logger->log(INFO, "Ping is Stopping") if INFO;
            },
            Actor::Signals::Lifecycle::Restarting:: => method ($context, $) {
                state $restarts = 0;
                $restarts++;
                if ($restarts <= 2) {
                    $logger->log(INFO, "Ping is Restarting($restarts) and killing Pong") if INFO;
                    $context->kill( $pong );
                }
                else {
                    $logger->log(INFO, "Ping is Restarting($restarts) for the last time") if INFO;
                    $context->self->send( PingPong::EndGame->new );
                }
            },
            Actor::Signals::Lifecycle::Stopped:: => method ($, $) {
                $logger->log(INFO, "Ping is deactivated and Pong will also be") if INFO;
            },
        }
    );

    sub BEHAVIOR { $BEHAVIOR }

    sub SUPERVISOR { Actor::Supervisors->Restart }
}

## ----------------------------------------------------------------------------


my $system = Actor::System->new(
    address => Actor::Address->new
);

my $root = $system->root->context;
my $ping = $root->spawn( '/ping' => Actor::Props->new( class => 'Ping' ) );

$system->loop_until_done;

done_testing;


__END__





