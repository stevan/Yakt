# Yakt Session Summary - December 10, 2025

## What Was Done

This session performed a deep code review and fixed regressions in the Yakt actor system.

### Background

Yakt is an actor-based concurrency framework for Perl 5.40+ that evolved from:
- **Stella** (original) → **Acktor** (middle) → **Yakt** (current)

The evolution introduced some regressions that were identified and fixed.

### Completed Work

#### Phase 1: Removed Streams Implementation
- Deleted `lib/Yakt/Streams/` (20 files) and `lib/Yakt/IO/` (2 files)
- Deleted 4 stream-related tests
- The Streams layer was incomplete and didn't match the intended design

#### Phase 2: Fixed become/unbecome
- **Bug**: `become` overwrote instead of pushing, `unbecome` cleared instead of popping
- **Fix**: Restored Acktor's stack semantics with `unshift`/`shift`
- Updated `t/004-parser.t` which relied on the broken behavior
- Added `t/230-become-unbecome.t` and `t/231-become-stacking.t`

#### Phase 3: Handle Signal Errors
- **Bug**: Signal errors were logged but swallowed, leaving actors in bad state
- **Fix**: In `Mailbox.pm`:
  - `Started` errors → stop the actor immediately
  - `Stopping`/`Stopped`/`Terminated` errors → log and continue
  - Other signals → defer to supervisor
- Added `t/240-signal-errors.t`

#### Phase 4: Prevent Operations on Stopped Actors
- **Fix**: Added guard in `Ref::send()` to warn and drop messages to stopped actors
- Added `t/250-stopped-actor-send.t`

#### Phase 5: Fix Shutdown Race Condition
- **Fix**: Added check for transitional states before triggering shutdown in `System.pm`
- Added `t/260-shutdown-timing.t`

#### Phase 6: Per-System PID Sequence
- **Bug**: `$PID_SEQ` was a class variable shared across all System instances
- **Fix**: Moved to instance field in System, passed to Mailbox constructor
- Added `t/270-isolated-systems.t`

### Commits Made

```
1a70ffa Make PID sequence per-system
5da5a92 Fix shutdown race condition
399e83d Prevent send to stopped actors
fe0a3eb Handle signal errors properly in Mailbox
d71590f become-unbecome
3e0e292 removing-streams
```

### Test Status

**20 tests, 78 assertions, all passing**

```bash
COLUMNS=80 LINES=24 prove -l t/0*.t t/1*.t t/2*.t t/310-buffered.t
```

Note: `t/300-io.t` requires `IO::Socket::SSL` which may not be installed.

### Files Modified

**Core changes:**
- `lib/Yakt/Actor.pm` - become/unbecome fix
- `lib/Yakt/System.pm` - shutdown race fix, per-system PID
- `lib/Yakt/System/Mailbox.pm` - signal error handling, accept PID param
- `lib/Yakt/Ref.pm` - guard against sends to stopped actors

**Tests added:**
- `t/230-become-unbecome.t`
- `t/231-become-stacking.t`
- `t/240-signal-errors.t`
- `t/250-stopped-actor-send.t`
- `t/260-shutdown-timing.t`
- `t/270-isolated-systems.t`

**Tests updated:**
- `t/004-parser.t` - adjusted for proper become/unbecome semantics

### Remaining Work (from TODO.md)

- Behaviors helper function placement
- Context method for adding Selectors
- Async Logger implementation
- Configurable Supervisors with error dispatch tables
- Child supervision improvements
- Error classification (caught vs fatal)
- Signal exporters for Ready/Terminated
- Better shutdown/zombie detection

### Architecture Notes

The core actor system (~750 lines) is now solid:
- **System** - Event loop (timers → mailboxes → IO)
- **Mailbox** - Actor lifecycle state machine
- **Actor** - Base class with attribute dispatch (`@Receive`, `@Signal`)
- **Behavior** - Message/signal routing
- **Context** - Actor API facade
- **Ref** - Actor reference with location transparency
- **Props** - Actor factory configuration

Key design: Signals (lifecycle) are separate from Messages (business logic).
