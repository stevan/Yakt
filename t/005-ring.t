#!perl

use v5.40;
use experimental qw[ class ];

use Test::More;

use ok 'Yakt::System';
use ok 'Yakt::Logging';

# TODO:
# actually model a TokenRing network
# https://en.wikipedia.org/wiki/Token_Ring#Access_control

class StartRing    { field $length :param :reader; }
class RingComplete { field $end    :param :reader; }
class VisitRings   { field $count  :param :reader; }
class ConnectRing  { field $start  :param :reader; }
class ShutdownRing {}

class Ring :isa(Yakt::Actor) {
    use Yakt::Logging;

    field $prev :param = undef;
    field $next;

    field $is_root;

    ADJUST {
        $is_root = !$prev;
    }

    our $STARTED;
    our $VISITED;

    method start_ring :Receive(StartRing) ($context, $message) {
        $context->logger->log(INFO, "StartRing called ...") if INFO;
        if ($message->length <= 0) {
            $context->logger->log(INFO, "Got to the end of the ring") if INFO;
            $context->self->send(RingComplete->new( end => $context->self ));
        } else {
            $context->logger->log(INFO, "Creating next ring ...") if INFO;
            $next = $context->spawn( Yakt::Props->new( class => __CLASS__, args => {
                prev => $context->self
            }));
            $context->logger->log(INFO, "Created $next, sending StartRing to it") if INFO;
            $next->send(StartRing->new( length => $message->length - 1 ));
            $STARTED++;
        }
    }

    method ring_complete :Receive(RingComplete) ($context, $message) {
        $context->logger->log(INFO, "RingComplete called") if INFO;
        if ($prev) {
            $context->logger->log(INFO, "Sending $prev the RingComplete message") if INFO;
            $prev->send($message);
        } else {
            $context->logger->log(INFO, "Found start(".$context->self.") of the ring!") if INFO;
            $prev = $message->end;
            $prev->send(ConnectRing->new( start => $context->self ));
        }
    }

    method connect_ring :Receive(ConnectRing) ($context, $message) {
        $context->logger->log(INFO, "ConnectRing called") if INFO;
        $context->logger->log(INFO, "Connecting end(".$context->self.") to start(".$message->start.") of ring!") if INFO;
        $next = $message->start;
        $next->send(VisitRings->new( count => 1000 ));
    }

    method visit_rings :Receive(VisitRings) ($context, $message) {
        $context->logger->log(INFO, "VisitRings called with count(".$message->count.")") if INFO;
        if ($message->count <= 0) {
            $context->logger->log(INFO, "Visited all the rings") if INFO;
            $context->self->send(ShutdownRing->new);
        } else {
            $context->logger->log(INFO, "Visited the next($next) ring ...") if INFO;
            $next->send( VisitRings->new( count => $message->count - 1 ));
            $VISITED++;
        }
    }

    method shutdown_ring :Receive(ShutdownRing) ($context, $message) {
        $context->logger->log(INFO, "ShutdownRing called") if INFO;
        if ($is_root) {
            $context->stop;
        } else {
            $next->send($message);
        }
    }

}

my $sys = Yakt::System->new->init(sub ($context) {
    my $ring = $context->spawn(Yakt::Props->new( class => Ring:: ));
    $ring->send(StartRing->new( length => 100 ));
});

$sys->loop_until_done;

is($Ring::VISITED, 1000, '... got the right visited count');
is($Ring::STARTED, 100, '... got the right started count');

done_testing;
