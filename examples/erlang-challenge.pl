#!/usr/bin/env perl

use v5.40;
use experimental qw[ class ];

use lib 'lib';

use Time::HiRes qw(time);

$|++;  # Autoflush output

use Yakt::System;

=pod

Erlang Ring Benchmark Challenge
http://whealy.com/erlang/challenge.html

From Joe Armstrong's "Programming Erlang" Chapter 8:
"Write a ring benchmark. Create N processes in a ring. Send a message
round the ring M times so that a total of N * M messages get sent."

This benchmark tests:
1. Process/actor creation speed
2. Message passing performance
3. How well the system handles many actors

Usage:
    perl examples/erlang-challenge.pl [num_nodes] [num_trips]
    perl examples/erlang-challenge.pl 1000 1000    # 1M messages
    perl examples/erlang-challenge.pl 10000 10000  # 100M messages

=cut

# =============================================================================
# Global timing
# =============================================================================

our $START_TIME;
our $SPAWN_TIME;
our $MSG_START;
our $NUM_NODES;
our $NUM_TRIPS;

# =============================================================================
# Messages
# =============================================================================

class Ping :isa(Yakt::Message) {
    field $count :param :reader;
}

# =============================================================================
# Ring Node Actor - forms the chain, passes messages to next node
# =============================================================================

class RingNode :isa(Yakt::Actor) {
    field $id   :param;
    field $next :param;  # ActorRef to the next node in the ring

    method ping :Receive(Ping) ($context, $message) {
        $next->send(Ping->new(count => $message->count + 1));
    }
}

# =============================================================================
# Ring Tail Actor - the end of the chain, tracks trips and completion
# =============================================================================

class RingTail :isa(Yakt::Actor) {
    use Time::HiRes qw(time);

    field $id :param;

    field $trips_completed = 0;

    method ping :Receive(Ping) ($context, $message) {
        $trips_completed++;

        if ($trips_completed >= $NUM_TRIPS) {
            # All trips complete - report results
            my $total_messages = $NUM_NODES * $NUM_TRIPS;
            my $msg_time = time() - $MSG_START;
            my $total_time = time() - $START_TIME;

            # Avoid division by zero for very fast runs
            $msg_time = 0.000001 if $msg_time <= 0;

            say "";
            say "=== Erlang Challenge Results ===";
            say sprintf("Nodes (N):        %d", $NUM_NODES);
            say sprintf("Trips (M):        %d", $NUM_TRIPS);
            say sprintf("Total messages:   %d (N × M)", $total_messages);
            say "";
            say sprintf("Spawn time:       %.4f seconds", $SPAWN_TIME);
            say sprintf("Message time:     %.4f seconds", $msg_time);
            say sprintf("Total time:       %.4f seconds", $total_time);
            say "";
            say sprintf("Messages/second:  %.0f", $total_messages / $msg_time);
            say sprintf("Avg msg latency:  %.3f µs", ($msg_time / $total_messages) * 1_000_000);
            say "";

            $context->system->shutdown;
        }
    }
}

# =============================================================================
# Main
# =============================================================================

$NUM_NODES = $ARGV[0] // 1000;
$NUM_TRIPS = $ARGV[1] // 1000;

say "Erlang Ring Benchmark Challenge";
say "================================";
say "Creating ring of $NUM_NODES nodes, sending message around $NUM_TRIPS times";
say "Total messages to send: " . ($NUM_NODES * $NUM_TRIPS);
say "";

$START_TIME = time();

my $system = Yakt::System->new->init(sub ($context) {
    my $SPAWN_START = time();

    # Create tail first (end of chain)
    my $tail = $context->spawn(Yakt::Props->new(
        class => 'RingTail',
        args  => { id => 0 },
    ));

    # Build chain: each new node points to the previous one
    my $next = $tail;
    for my $id (1 .. $NUM_NODES - 1) {
        $next = $context->spawn(Yakt::Props->new(
            class => 'RingNode',
            args  => {
                id   => $id,
                next => $next,
            },
        ));
    }

    my $head = $next;

    $SPAWN_TIME = time() - $SPAWN_START;

    say sprintf("Spawned %d actors in %.4f seconds (%.0f actors/sec)",
        $NUM_NODES, $SPAWN_TIME, $NUM_NODES / ($SPAWN_TIME > 0 ? $SPAWN_TIME : 0.000001));

    say "Starting message passing...";

    $MSG_START = time();

    # Send M pings to the head to start M trips around the ring
    for (1 .. $NUM_TRIPS) {
        $head->send(Ping->new(count => 0));
    }
});

$system->loop_until_done;
