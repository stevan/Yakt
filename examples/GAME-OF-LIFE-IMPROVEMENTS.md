# Game of Life Improvements

## Task: Enhanced Statistics Display

Improve the status bar in `examples/game-of-life.pl` to show more useful metrics.

### Current Status Bar
```
Generation: 42  |  Live: 156  |  Speed: 0.05s  |  Ctrl+C to quit
```

### Desired Status Bar
```
Gen: 42 | Live: 156 | Actors: 5001 | Msgs: 15000 | FPS: 18.5 (target: 20) | Ctrl+C to quit
```

## Implementation Details

### 1. Actual FPS Calculation

Track time between renders to calculate real FPS:

```perl
# In World actor, add fields:
field $last_render_time;
field $current_fps = 0;

# In report_state handler, before rendering:
use Time::HiRes qw(time);

my $now = time;
if (defined $last_render_time) {
    my $elapsed = $now - $last_render_time;
    $current_fps = $elapsed > 0 ? 1 / $elapsed : 0;
}
$last_render_time = $now;
```

Consider smoothing FPS with a rolling average to avoid jitter.

### 2. Actor Count

The actor count is deterministic: `width * height + 1` (cells + world).

Pass to display or calculate in render:
```perl
my $actor_count = ($width * $height) + 1;
```

### 3. Message Count

Track messages sent. Options:

**Option A: Track in World actor**
```perl
field $message_count = 0;

# Increment when sending messages
$message_count += $expected_reports;  # QueryState messages
$message_count += $expected_reports;  # ComputeNextState messages

# Each ReportState received also counts
$message_count++;  # in report_state handler
```

**Option B: Track in Yakt::System (if accessible)**
Would require adding instrumentation to the framework itself. More accurate but invasive.

Recommend Option A for simplicity.

### 4. Update Display::render signature

```perl
method render ($grid, $ages, $stats) {
    # $stats is a hashref:
    # {
    #     generation  => $generation,
    #     live_count  => $live_count,
    #     actor_count => $actor_count,
    #     msg_count   => $message_count,
    #     fps         => $current_fps,
    #     target_fps  => 1 / $tick_interval,
    # }
}
```

### 5. Format the Status Line

```perl
my $status = sprintf(
    "Gen: %d | Live: %d | Actors: %d | Msgs: %d | FPS: %.1f (target: %.0f)",
    $stats->{generation},
    $stats->{live_count},
    $stats->{actor_count},
    $stats->{msg_count},
    $stats->{fps},
    $stats->{target_fps},
);
```

Keep "Ctrl+C to quit" on second line to avoid overflow on narrow terminals.

## Messages Per Generation

For reference, each generation involves:
- N `QueryState` (World → Cells)
- N `ReportState` (Cells → World)
- N `ComputeNextState` (World → Cells)
- 1 `Tick` (World → World, via timer callback)

Total: `3N + 1` messages per generation, where N = width × height.

At 100x50 grid: 15,001 messages per generation.

## Testing

After implementation, verify:
1. FPS roughly matches `1/speed` under light load
2. FPS drops below target under heavy load (large grids, fast speed)
3. Message count increments by ~3N each generation
4. Actor count is constant throughout run

```bash
# Should show ~20 target FPS, actual will vary
perl examples/game-of-life.pl 50 25 r_pentomino 0.05

# Should show FPS dropping below target due to load
perl examples/game-of-life.pl 100 50 rabbits 0.02
```
