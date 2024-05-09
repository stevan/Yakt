#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

use Test::More;
use Actor;

class PingPong::Ping :isa(Actor::Message) {}
class PingPong::Pong :isa(Actor::Message) {}

class Pong {
    use Actor::Logging;

    field $ping :param;
    field $count = 0;

    field $logger;

    my $restarts = 0;

    ADJUST {
        $logger = Actor::Logging->logger( "Pong" ) if LOG_LEVEL;
    }

    my $BEHAVIOR //= Actor::Behavior->new(
        receivers => {
            PingPong::Pong:: => method ($context, $) {
                $count++;
                $logger->log(INFO, "Got Pong[$restarts]($count) sending Ping") if INFO;
                $ping->send( PingPong::Ping->new );

                if ($count >= 3) {
                    die "!!! Sending Restart to Pong";
                }
            }
        },
        signals => {
            Actor::Signals::Lifecycle::Started:: => method ($, $) {
                $logger->log(INFO, "Pong[$restarts] is Activated") if INFO;
            },
            Actor::Signals::Lifecycle::Stopping:: => method ($, $) {
                $logger->log(INFO, "Pong[$restarts] is Stopping") if INFO;
            },
            Actor::Signals::Lifecycle::Restarting:: => method ($, $) {
                $logger->log(INFO, "Pong[$restarts] is Restarting") if INFO;
                $restarts++;
            },
            Actor::Signals::Lifecycle::Stopped:: => method ($, $) {
                $logger->log(INFO, "Pong[$restarts] is Deactivated") if INFO;
                $restarts++;
            },
        }
    );

    sub BEHAVIOR { $BEHAVIOR }

    sub SUPERVISOR { Actor::Supervisors->Restart }
}

class Ping {
    use Actor::Logging;

    field $pong;
    field $count = 0;

    field $logger;

    my $restarts = 0;

    ADJUST {
        $logger = Actor::Logging->logger( "Ping" ) if LOG_LEVEL;
    }

    my $BEHAVIOR //= Actor::Behavior->new(
        receivers => {
            PingPong::Ping:: => method ($context, $) {
                if ($restarts == 2) {
                    $logger->log(INFO, "!! Stopping Ping[$restarts]($count)") if INFO;
                    $context->stop;
                    return;
                }

                $count++;
                $logger->log(INFO, "Got Ping[$restarts]($count) sending Pong") if INFO;
                $pong->send( PingPong::Pong->new );

                if ($count == 9) {
                    die "OH NOES!! Ping is dying!";
                }
            }
        },
        signals => {
            Actor::Signals::Lifecycle::Started:: => method ($context, $) {
                $logger->log(INFO, "Ping[$restarts] is activated, creating Pong ...") if INFO;
                $pong = $context->spawn(
                    '/pong',
                    Actor::Props->new(
                        class => Pong::,
                        args  => { ping => $context->self },
                    )
                );

                $pong->send( PingPong::Pong->new );
            },
            Actor::Signals::Lifecycle::Stopping:: => method ($context, $) {
                $logger->log(INFO, "Ping[$restarts] is Stopping") if INFO;
            },
            Actor::Signals::Lifecycle::Restarting:: => method ($context, $) {
                $logger->log(INFO, "Ping[$restarts] is Restarting") if INFO;
                $context->kill( $pong );
                $restarts++;
            },
            Actor::Signals::Lifecycle::Stopped:: => method ($, $) {
                $logger->log(INFO, "Ping[$restarts] is deactivated and Pong will also be") if INFO;
                $restarts++;
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





