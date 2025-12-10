# Yakt Session Summary - December 10, 2025

## Session 2b: Documentation

Added POD documentation to all main modules:

### Documented Modules

| Module | Status | Notes |
|--------|--------|-------|
| `Yakt::System` | Stable | Main entry point, event loop |
| `Yakt::Actor` | Stable | Base class, @Receive/@Signal |
| `Yakt::Context` | Stable | Actor API facade |
| `Yakt::Ref` | Stable | Actor reference for messaging |
| `Yakt::Props` | Stable | Actor configuration |
| `Yakt::Message` | Stable | Message base class |
| `Yakt::Behavior` | Internal | Message routing |
| `Yakt::System::Mailbox` | Internal | Lifecycle state machine |

### Documentation Style

- Honest about status (Stable, In Development, Internal)
- KNOWN ISSUES and FUTURE WORK sections
- Focused on implementors, not end-users yet
- Examples in SYNOPSIS

### Updated TODO.md

Added items identified during documentation:
- Signal Exporters
- Actor Lookup by Alias
- Context::add_selector
- Backpressure mechanism

---

## Session 2a: Test Coverage Improvement

This session focused on improving test coverage with a structured, focused test suite.

### Test Structure Created

```
t/
├── 100-timers/           # Timer functionality (4 tests)
│   ├── 010-basic.t       # Single/multiple timer firing
│   ├── 020-cancel.t      # Timer cancellation
│   ├── 030-same-time.t   # Multiple timers at same time
│   └── 040-callback-errors.t  # Error handling in callbacks
│
├── 110-props/            # Props configuration (4 tests)
│   ├── 010-basic.t       # Basic Props creation
│   ├── 020-alias.t       # Actor aliasing
│   ├── 030-supervisor.t  # Supervisor configuration
│   └── 040-new-actor.t   # Actor instantiation with args
│
├── 120-behavior/         # Behavior & message dispatch (4 tests)
│   ├── 010-message-dispatch.t   # @Receive handlers
│   ├── 020-signal-dispatch.t    # @Signal handlers
│   ├── 030-unhandled-messages.t # Dead letter handling
│   └── 040-unhandled-signals.t  # Partial signal handling
│
├── 130-context/          # Context API (6 tests)
│   ├── 010-spawn.t       # Child spawning
│   ├── 020-send.t        # Message sending
│   ├── 030-stop.t        # Actor stopping
│   ├── 040-watch.t       # Actor watching
│   ├── 050-notify.t      # Signal notification
│   └── 060-restart.t     # Manual restart
│
├── 140-ref/              # Ref API (3 tests)
│   ├── 010-basic.t       # PID & stringification
│   ├── 020-send.t        # Message delivery via ref
│   └── 030-context-access.t  # Context access from ref
│
├── 210-supervision/      # Supervisor strategies (4 tests)
│   ├── 010-stop.t        # Stop on error (default)
│   ├── 020-resume.t      # Resume (skip failed message)
│   ├── 030-retry.t       # Retry (re-deliver message)
│   └── 040-restart.t     # Restart actor on error
│
└── 220-lifecycle/        # Parent-child lifecycle (4 tests)
    ├── 010-parent-stops-children.t   # Children stop with parent
    ├── 020-parent-waits-for-children.t  # Parent waits for children
    ├── 030-terminated-signal.t       # Terminated notification
    └── 040-restart-with-children.t   # Children during restart
```

### Test Statistics

**49 tests, 163 assertions, all passing**

```bash
COLUMNS=80 LINES=24 prove -l t/
```

### Other Changes

- Added skip for `t/300-io.t` when `IO::Socket::SSL` is not installed

---

## Session 1: Code Review and Bug Fixes

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

---

## Remaining Work (from TODO.md)

- Behaviors helper function placement
- Context method for adding Selectors
- Async Logger implementation
- Configurable Supervisors with error dispatch tables
- Child supervision improvements
- Error classification (caught vs fatal)
- Signal exporters for Ready/Terminated
- Better shutdown/zombie detection

## Architecture Notes

The core actor system (~750 lines) is now solid:
- **System** - Event loop (timers → mailboxes → IO)
- **Mailbox** - Actor lifecycle state machine
- **Actor** - Base class with attribute dispatch (`@Receive`, `@Signal`)
- **Behavior** - Message/signal routing
- **Context** - Actor API facade
- **Ref** - Actor reference with location transparency
- **Props** - Actor factory configuration

Key design: Signals (lifecycle) are separate from Messages (business logic).
