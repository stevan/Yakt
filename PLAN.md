# Yakt Regression Fixes and Cleanup Plan

This plan addresses regressions from the Stella → Acktor → Yakt evolution,
removes the incomplete Streams implementation, and adds tests to prevent
future regressions.

---

## Phase 1: Remove Streams Implementation

The Streams layer didn't work out as intended. Remove it cleanly.

### 1.1 Delete Streams Files

**Files to delete:**
```
lib/Yakt/Streams.pm
lib/Yakt/Streams/OnNext.pm
lib/Yakt/Streams/OnCompleted.pm
lib/Yakt/Streams/OnError.pm
lib/Yakt/Streams/OnSuccess.pm
lib/Yakt/Streams/Subscribe.pm
lib/Yakt/Streams/OnSubscribe.pm
lib/Yakt/Streams/Unsubscribe.pm
lib/Yakt/Streams/OnUnsubscribe.pm
lib/Yakt/Streams/Actors/Observer.pm
lib/Yakt/Streams/Actors/Observer/Single.pm
lib/Yakt/Streams/Actors/Observable.pm
lib/Yakt/Streams/Actors/Observable/FromSource.pm
lib/Yakt/Streams/Actors/Observable/FromProducer.pm
lib/Yakt/Streams/Actors/Operator.pm
lib/Yakt/Streams/Actors/Operator/Map.pm
lib/Yakt/Streams/Actors/Operator/Grep.pm
lib/Yakt/Streams/Actors/Operator/Peek.pm
lib/Yakt/Streams/Actors/Flow.pm
lib/Yakt/Streams/Composers/Flow.pm
```

**Directories to remove (after files):**
```
lib/Yakt/Streams/
```

### 1.2 Delete IO Actors (depend on Streams)

**Files to delete:**
```
lib/Yakt/IO/Actors/StreamReader.pm
lib/Yakt/IO/Actors/StreamWriter.pm
```

**Directories to remove:**
```
lib/Yakt/IO/
```

### 1.3 Delete Streams Tests

**Tests to delete:**
```
t/400-flow.t
t/401-flow-and-io.t
t/402-flow-and-io-writer.t
t/490-flow-error.t
```

### 1.4 Update Documentation

- Remove references to Streams from `docs/STREAMS.md` (or delete the file)
- Update `TODO.md` to remove Streams-related items

### 1.5 Verify

```bash
prove -l t/
```

All remaining tests should pass.

---

## Phase 2: Fix `become`/`unbecome`

The current implementation is broken - it overwrites instead of stacking.

### 2.1 The Bug

**Current (broken):**
```perl
method become ($b) { $behaviors[0] = $b; }  # Overwrites
method unbecome    { @behaviors    = (); }  # Clears all
```

**Acktor's working version:**
```perl
method become ($b) { unshift @behaviors => $b }  # Push to front
method unbecome    { shift @behaviors }           # Pop from front
```

### 2.2 The Fix

In `lib/Yakt/Actor.pm`, change:

```perl
method become ($b) { unshift @behaviors => $b }
method unbecome    { shift @behaviors }
```

### 2.3 Write Tests

Create `t/230-become-unbecome.t`:

```perl
#!perl

use v5.40;
use experimental qw[ class ];

use Test::More;

use ok 'Yakt::System';

# Test messages
class Ping {}
class Pong {}
class Reset {}
class GetState {}
class State { field $value :param; method value { $value } }

# Actor that switches behaviors
class StateSwitcher :isa(Yakt::Actor) {
    use Yakt::Logging;

    our @EVENTS;

    field $reply_to;

    method on_start :Signal(Yakt::System::Signals::Started) ($context, $signal) {
        push @EVENTS => 'started:normal';
    }

    method ping :Receive(Ping) ($context, $message) {
        push @EVENTS => 'normal:ping';
        $reply_to = $message->sender;
        # Switch to "pong mode"
        $self->become( $self->pong_behavior );
    }

    method reset :Receive(Reset) ($context, $message) {
        push @EVENTS => 'normal:reset';
        $context->stop;
    }

    # Alternate behavior
    method pong_behavior {
        Yakt::Behavior->new(
            receivers => {
                'Pong'  => $self->can('pong'),
                'Reset' => $self->can('back_to_normal'),
            }
        );
    }

    method pong ($context, $message) {
        push @EVENTS => 'pong_mode:pong';
        $reply_to->send(Ping->new( sender => $context->self ));
    }

    method back_to_normal ($context, $message) {
        push @EVENTS => 'pong_mode:reset';
        $self->unbecome;
        # Now back in normal mode - reset should work
        $context->self->send(Reset->new);
    }
}

# Test: become switches behavior, unbecome restores it
my $sys = Yakt::System->new->init(sub ($context) {
    my $switcher = $context->spawn( Yakt::Props->new( class => 'StateSwitcher' ) );

    # Start in normal mode
    $switcher->send(Ping->new( sender => $switcher ));  # -> becomes pong mode
    # Now in pong mode
    $switcher->send(Pong->new);  # -> handled by pong mode
    $switcher->send(Reset->new); # -> back_to_normal, unbecome, then Reset in normal mode
});

$sys->loop_until_done;

is_deeply(\@StateSwitcher::EVENTS, [
    'started:normal',
    'normal:ping',
    'pong_mode:pong',
    'pong_mode:reset',
    'normal:reset',
], '... behavior switching works correctly');

done_testing;
```

Create `t/231-become-stacking.t`:

```perl
#!perl

use v5.40;
use experimental qw[ class ];

use Test::More;

use ok 'Yakt::System';

class Msg { field $n :param; method n { $n } }
class Done {}

# Actor that stacks multiple behaviors
class StackingActor :isa(Yakt::Actor) {
    use Yakt::Logging;

    our @EVENTS;

    method on_start :Signal(Yakt::System::Signals::Started) ($context, $signal) {
        push @EVENTS => 'base';
    }

    method handle :Receive(Msg) ($context, $message) {
        my $n = $message->n;
        push @EVENTS => "base:$n";

        if ($n == 1) {
            # Stack first behavior
            $self->become($self->make_behavior('first'));
        }
    }

    method done :Receive(Done) ($context, $message) {
        push @EVENTS => 'base:done';
        $context->stop;
    }

    method make_behavior ($name) {
        Yakt::Behavior->new(
            receivers => {
                'Msg'  => sub ($self, $ctx, $msg) {
                    my $n = $msg->n;
                    push @EVENTS => "$name:$n";
                    if ($n == 2) {
                        # Stack another behavior
                        $self->become($self->make_behavior('second'));
                    } elsif ($n == 4) {
                        # Pop back to previous
                        $self->unbecome;
                    }
                },
                'Done' => sub ($self, $ctx, $msg) {
                    push @EVENTS => "$name:done";
                    $self->unbecome;
                },
            }
        );
    }
}

my $sys = Yakt::System->new->init(sub ($context) {
    my $actor = $context->spawn( Yakt::Props->new( class => 'StackingActor' ) );

    $actor->send(Msg->new( n => 0 ));  # base handles
    $actor->send(Msg->new( n => 1 ));  # base handles, becomes 'first'
    $actor->send(Msg->new( n => 2 ));  # first handles, becomes 'second'
    $actor->send(Msg->new( n => 3 ));  # second handles
    $actor->send(Msg->new( n => 4 ));  # second handles, unbecome -> first
    $actor->send(Msg->new( n => 5 ));  # first handles
    $actor->send(Done->new);           # first handles, unbecome -> base
    $actor->send(Done->new);           # base handles, stops
});

$sys->loop_until_done;

is_deeply(\@StackingActor::EVENTS, [
    'base',
    'base:0',
    'base:1',
    'first:2',
    'second:3',
    'second:4',
    'first:5',
    'first:done',
    'base:done',
], '... behavior stacking works correctly');

done_testing;
```

---

## Phase 3: Handle Signal Errors

Currently, errors in signal handlers are logged but swallowed. This can leave
actors in inconsistent states.

### 3.1 The Bug

In `lib/Yakt/System/Mailbox.pm`:
```perl
try {
    $actor->signal($context, $sig);
} catch ($e) {
    chomp $e;
    # XXX - what to do here???
    $logger->log(ERROR, "!!! GOT AN ERROR($e) WHILE PROCESSING SIGNALS!" ) if ERROR;
}
```

### 3.2 Design Decision

Signal errors should trigger supervision, just like message errors. However,
some signals are special:

- `Started` error → Stop the actor (can't start properly)
- `Stopping`/`Stopped` error → Log and continue (already stopping)
- `Terminated` error → Log and continue (notification only)
- Other signals → Defer to supervisor

### 3.3 The Fix

In `lib/Yakt/System/Mailbox.pm`, replace the signal error handling:

```perl
try {
    $actor->signal($context, $sig);
} catch ($e) {
    chomp $e;
    $logger->log(ERROR, "Got Error($e) while processing signal($sig)") if ERROR;

    # Started errors are fatal - can't continue with broken initialization
    if ($sig isa Yakt::System::Signals::Started) {
        $logger->log(ERROR, "Actor failed to start, stopping") if ERROR;
        $halted_on = $e;
        unshift @signals => Yakt::System::Signals::Stopped->new;
        last;
    }
    # Stopping/Stopped/Terminated errors - log but continue shutdown
    elsif ($sig isa Yakt::System::Signals::Stopping
        || $sig isa Yakt::System::Signals::Stopped
        || $sig isa Yakt::System::Signals::Terminated) {
        # Already in shutdown path, just log
    }
    # Other signals - defer to supervisor
    else {
        my $action = $supervisor->supervise( $self, $e );
        if ($action == $supervisor->HALT) {
            $halted_on = $e;
            unshift @signals => Yakt::System::Signals::Stopping->new;
            last;
        }
        # RETRY/RESUME don't make sense for signals, treat as continue
    }
}
```

### 3.4 Write Tests

Create `t/240-signal-errors.t`:

```perl
#!perl

use v5.40;
use experimental qw[ class ];

use Test::More;

use ok 'Yakt::System';

class Ping {}

# Actor that fails on Started
class FailOnStart :isa(Yakt::Actor) {
    our $STARTED = 0;
    our $STOPPED = 0;

    method on_start :Signal(Yakt::System::Signals::Started) ($context, $signal) {
        $STARTED++;
        die "Failed to start!";
    }

    method on_stopped :Signal(Yakt::System::Signals::Stopped) ($context, $signal) {
        $STOPPED++;
    }

    method ping :Receive(Ping) ($context, $message) {
        # Should never be called
        die "Should not receive messages!";
    }
}

# Actor that fails on custom signal (Ready)
class FailOnReady :isa(Yakt::Actor) {
    our $STARTED = 0;
    our $STOPPED = 0;

    method on_start :Signal(Yakt::System::Signals::Started) ($context, $signal) {
        $STARTED++;
        # Notify self with Ready to trigger the error
        $context->notify(Yakt::System::Signals::Ready->new( ref => $context->self ));
    }

    method on_ready :Signal(Yakt::System::Signals::Ready) ($context, $signal) {
        die "Failed on Ready!";
    }

    method on_stopped :Signal(Yakt::System::Signals::Stopped) ($context, $signal) {
        $STOPPED++;
    }
}

subtest 'Actor that fails on Started is stopped' => sub {
    local $FailOnStart::STARTED = 0;
    local $FailOnStart::STOPPED = 0;

    my $sys = Yakt::System->new->init(sub ($context) {
        my $actor = $context->spawn( Yakt::Props->new( class => 'FailOnStart' ) );
        $actor->send(Ping->new);  # Should go to dead letters
    });

    $sys->loop_until_done;

    is($FailOnStart::STARTED, 1, '... Started was called');
    is($FailOnStart::STOPPED, 1, '... actor was stopped after Start failure');
};

subtest 'Actor that fails on Ready is stopped by supervisor' => sub {
    local $FailOnReady::STARTED = 0;
    local $FailOnReady::STOPPED = 0;

    my $sys = Yakt::System->new->init(sub ($context) {
        $context->spawn( Yakt::Props->new( class => 'FailOnReady' ) );
    });

    $sys->loop_until_done;

    is($FailOnReady::STARTED, 1, '... Started was called');
    is($FailOnReady::STOPPED, 1, '... actor was stopped after Ready failure');
};

done_testing;
```

---

## Phase 4: Prevent Operations on Stopped Actors

Currently, you can call `$ref->send()` on a stopped actor, which goes through
a dead context to a stopped mailbox.

### 4.1 The Bug

`Ref::send` doesn't check if the actor is stopped:
```perl
method send ($message) {
    $context->send_message( $self, $message );
}
```

### 4.2 The Fix

Option A: Check in `Ref::send` (fail fast):
```perl
method send ($message) {
    $logger->log(DEBUG, "send($message)" ) if DEBUG;
    if ($context->is_stopped) {
        $logger->log(WARN, "Attempt to send to stopped actor, ignoring") if WARN;
        return;
    }
    $context->send_message( $self, $message );
}
```

Option B: Let it go to dead letters (current behavior via System::enqueue_message)

**Recommendation:** Option A - fail fast with warning. Messages to stopped actors
are programming errors and should be visible.

### 4.3 Write Tests

Create `t/250-stopped-actor-send.t`:

```perl
#!perl

use v5.40;
use experimental qw[ class ];

use Test::More;

use ok 'Yakt::System';

class Ping {}
class Pong {}

class Sender :isa(Yakt::Actor) {
    our $PONG_COUNT = 0;

    field $target;

    method on_start :Signal(Yakt::System::Signals::Started) ($context, $signal) {
        # Spawn target, it will stop itself immediately
        $target = $context->spawn( Yakt::Props->new( class => 'Stopper' ) );
    }

    method on_terminated :Signal(Yakt::System::Signals::Terminated) ($context, $signal) {
        # Target has stopped, try to send to it
        $target->send(Ping->new( sender => $context->self ));

        # Schedule stop after a tick to let any responses arrive
        $context->schedule( after => 0.01, callback => sub {
            $context->stop;
        });
    }

    method pong :Receive(Pong) ($context, $message) {
        $PONG_COUNT++;  # Should not happen
    }
}

class Stopper :isa(Yakt::Actor) {
    method on_start :Signal(Yakt::System::Signals::Started) ($context, $signal) {
        $context->stop;  # Stop immediately
    }

    method ping :Receive(Ping) ($context, $message) {
        # Should never be called - we're stopped
        $message->sender->send(Pong->new);
    }
}

my $sys = Yakt::System->new->init(sub ($context) {
    $context->spawn( Yakt::Props->new( class => 'Sender' ) );
});

$sys->loop_until_done;

is($Sender::PONG_COUNT, 0, '... no pong received (message to stopped actor was dropped)');

done_testing;
```

---

## Phase 5: Fix Shutdown Race Condition

The shutdown detection can trigger while children are still in STOPPING state.

### 5.1 The Bug

In `System.pm`:
```perl
if ( $usr->is_alive && !$usr->children && !(grep $_->to_be_run, @mailboxes) ) {
    $usr->context->stop;
}
```

The check `!$usr->children` fires when children list is empty, but a child
might be in STOPPING state (still processing Stopped signal).

### 5.2 The Fix

Add a check for any mailbox in transitional state:

```perl
method loop_until_done {
    # ...
    while (1) {
        $self->tick;

        next if $timers->has_active_timers
             || $io->has_active_selectors;

        # Check if any mailbox is in a transitional state
        my $any_transitioning = grep {
            $_->is_stopping || $_->is_restarting || $_->is_starting
        } @mailboxes;

        next if $any_transitioning;

        if ( my $usr = $lookup{ '//usr' } ) {
            if ( $usr->is_alive && !$usr->children && !(grep $_->to_be_run, @mailboxes) ) {
                $usr->context->stop;
            }
        }

        last unless @mailboxes;
    }
}
```

### 5.3 Write Tests

Create `t/260-shutdown-timing.t`:

```perl
#!perl

use v5.40;
use experimental qw[ class ];

use Test::More;

use ok 'Yakt::System';

class Msg {}

# Parent that spawns children which do cleanup work on Stopping
class Parent :isa(Yakt::Actor) {
    our @EVENTS;

    method on_start :Signal(Yakt::System::Signals::Started) ($context, $signal) {
        push @EVENTS => 'parent:started';

        # Spawn several children
        for my $i (1..3) {
            $context->spawn( Yakt::Props->new(
                class => 'SlowChild',
                args  => { id => $i }
            ));
        }

        # Schedule stop after children are spawned
        $context->schedule( after => 0.01, callback => sub {
            push @EVENTS => 'parent:requesting_stop';
            $context->stop;
        });
    }

    method on_stopping :Signal(Yakt::System::Signals::Stopping) ($context, $signal) {
        push @EVENTS => 'parent:stopping';
    }

    method on_stopped :Signal(Yakt::System::Signals::Stopped) ($context, $signal) {
        push @EVENTS => 'parent:stopped';
    }
}

class SlowChild :isa(Yakt::Actor) {
    field $id :param;

    method on_start :Signal(Yakt::System::Signals::Started) ($context, $signal) {
        push @Parent::EVENTS => "child$id:started";
    }

    method on_stopping :Signal(Yakt::System::Signals::Stopping) ($context, $signal) {
        push @Parent::EVENTS => "child$id:stopping";
    }

    method on_stopped :Signal(Yakt::System::Signals::Stopped) ($context, $signal) {
        push @Parent::EVENTS => "child$id:stopped";
    }
}

my $sys = Yakt::System->new->init(sub ($context) {
    $context->spawn( Yakt::Props->new( class => 'Parent' ) );
});

$sys->loop_until_done;

# Verify all children stopped before parent
my $parent_stopped_idx = 0;
my @child_stopped_idxs;

for my $i (0..$#Parent::EVENTS) {
    if ($Parent::EVENTS[$i] eq 'parent:stopped') {
        $parent_stopped_idx = $i;
    }
    if ($Parent::EVENTS[$i] =~ /child\d:stopped/) {
        push @child_stopped_idxs => $i;
    }
}

is(scalar @child_stopped_idxs, 3, '... all 3 children stopped');
ok((all { $_ < $parent_stopped_idx } @child_stopped_idxs),
   '... all children stopped before parent');

# Helper
sub all (&@) {
    my $code = shift;
    for (@_) { return 0 unless $code->() }
    return 1;
}

done_testing;
```

---

## Phase 6: Make PID Sequence Per-System

Currently `$PID_SEQ` is a class variable shared across all System instances.

### 6.1 The Fix

Move `$PID_SEQ` into the System and pass it to Mailbox:

**In `System.pm`:**
```perl
field $pid_seq = 0;

method spawn_actor ($props, $parent=undef) {
    my $mailbox = Yakt::System::Mailbox->new(
        props     => $props,
        system    => $self,
        parent    => $parent,
        pid       => ++$pid_seq,
    );
    # ...
}
```

**In `Mailbox.pm`:**
```perl
field $pid :param;  # Now passed in

ADJUST {
    $ref = Yakt::Ref->new( pid => $pid );
    # ...
}
```

Remove the `my $PID_SEQ = 0;` line from Mailbox.pm.

### 6.2 Write Tests

Create `t/270-isolated-systems.t`:

```perl
#!perl

use v5.40;
use experimental qw[ class ];

use Test::More;

use ok 'Yakt::System';

class Counter :isa(Yakt::Actor) {
    our @PIDS;

    method on_start :Signal(Yakt::System::Signals::Started) ($context, $signal) {
        push @PIDS => $context->self->pid;
        $context->stop;
    }
}

# Run two separate systems
subtest 'First system' => sub {
    local @Counter::PIDS = ();

    my $sys1 = Yakt::System->new->init(sub ($context) {
        $context->spawn( Yakt::Props->new( class => 'Counter' ) );
        $context->spawn( Yakt::Props->new( class => 'Counter' ) );
    });
    $sys1->loop_until_done;

    # PIDs should be low numbers (system actors + 2 user actors)
    ok($Counter::PIDS[0] < 10, '... first system has low PIDs');
};

subtest 'Second system (independent)' => sub {
    local @Counter::PIDS = ();

    my $sys2 = Yakt::System->new->init(sub ($context) {
        $context->spawn( Yakt::Props->new( class => 'Counter' ) );
    });
    $sys2->loop_until_done;

    # With per-system PIDs, this should also be a low number
    # With global PIDs, this would be higher
    ok($Counter::PIDS[0] < 10, '... second system also has low PIDs (independent sequence)');
};

done_testing;
```

---

## Implementation Order

1. **Phase 1: Remove Streams** - Clean slate, removes dead code
2. **Phase 2: Fix become/unbecome** - Core functionality fix
3. **Phase 3: Signal errors** - Safety improvement
4. **Phase 4: Stopped actor sends** - Safety improvement
5. **Phase 5: Shutdown race** - Correctness fix
6. **Phase 6: Per-system PIDs** - Isolation improvement

Each phase should:
1. Write the tests first (they should fail)
2. Implement the fix
3. Verify tests pass
4. Run full test suite to check for regressions

---

## Verification

After all phases:

```bash
prove -l t/
```

All tests should pass. The test numbering convention:
- `0xx` - Basic loading and setup
- `1xx` - Timers
- `2xx` - Actors and lifecycle
- `3xx` - IO
- `4xx` - (removed - was Streams)
