# Game of Life - Yakt Example

A Conway's Game of Life implementation using the Yakt actor system, where each cell is an independent actor.

## Running

```bash
perl examples/game-of-life.pl [width] [height] [pattern] [speed]

# Examples
perl examples/game-of-life.pl 40 20 glider 0.1      # Simple glider
perl examples/game-of-life.pl 80 40 r_pentomino 0.05  # Chaotic pattern
perl examples/game-of-life.pl 100 50 rabbits 0.02   # 5000 actors stress test
```

## Patterns

| Pattern | Starting Cells | Behavior |
|---------|---------------|----------|
| `glider` | 5 | Classic diagonal spaceship |
| `blinker` | 3 | Period-2 oscillator |
| `pulsar` | 48 | Period-3 oscillator, visually striking |
| `spaceship` | 9 | Lightweight spaceship (LWSS) |
| `glider_gun` | 36 | Gosper gun, produces gliders forever |
| `r_pentomino` | 5 | Chaotic, runs 1103 generations |
| `acorn` | 7 | Runs 5206 generations before stabilizing |
| `diehard` | 7 | Vanishes after exactly 130 generations |
| `rabbits` | 9 | Exponential growth, fills the grid |
| `lidka` | 13 | Runs 29,053 generations (needs 150x150 grid) |
| `infinite1` | 10 | Grows forever |
| `infinite2` | 13 | Grows forever |
| `random` | ~30% | Random initial state |

## Architecture

### Actors

- **World** (1 actor): Coordinates simulation, manages display, handles timing
- **Cell** (width × height actors): Each cell maintains its own alive/dead state and age

### Messages

```
Tick              World -> World (timer-driven)
QueryState        World -> Cell  (request current state)
ReportState       Cell  -> World (respond with x, y, alive, age)
ComputeNextState  World -> Cell  (tell cell its neighbor count)
SetNeighbors      World -> Cell  (initial setup, provides neighbor refs)
```

### Flow Per Generation

1. World sends `Tick` to itself (via timer)
2. World sends `QueryState` to all cells
3. Each cell replies with `ReportState`
4. When all reports received, World:
   - Renders the grid
   - Computes neighbor counts
   - Sends `ComputeNextState` to each cell
5. Each cell updates its alive/age state
6. World schedules next `Tick`

## Observations

### What This Example Demonstrates

1. **Massive Actor Counts**: A 100x50 grid creates 5,001 actors (5000 cells + 1 world). The system handles this without issue.

2. **Message Throughput**: Each generation involves:
   - N `QueryState` messages (World → Cells)
   - N `ReportState` messages (Cells → World)
   - N `ComputeNextState` messages (World → Cells)
   - Total: 3N messages per generation
   - At 100x50 with 0.02s ticks, that's ~750,000 messages/second

3. **Timer Integration**: The simulation is driven by `$context->schedule()`, showing how timers integrate naturally with actor messaging.

4. **Graceful Shutdown**: Ctrl+C triggers `$system->shutdown`, which properly stops all actors and cleans up the terminal state.

5. **State Encapsulation**: Each Cell actor encapsulates its own state (alive, age, neighbors). No shared mutable state between actors.

### Design Decisions

**Why World computes neighbor counts (not Cells)?**

We could have each Cell query its 8 neighbors directly. However:
- That would be 8N additional messages per generation
- Cells would need to coordinate "all neighbors responded" logic
- The current approach is simpler: World already has all states after `ReportState` collection

**Why not use become/unbecome for Cell states?**

Cell states (alive/dead) are simple boolean flags. `become/unbecome` would be overkill here. It's better suited for complex behavioral state machines (e.g., an Actor that switches between "listening", "processing", "cooldown" modes).

**Age tracking for colors**

Each cell tracks how many consecutive generations it has been alive. This creates the green→yellow→orange→red gradient that makes the visualization more interesting. Newborn cells are bright green; ancient survivors turn red.

### Performance Notes

- **Grid Size vs Speed**: Larger grids need longer tick intervals
  - 40x20 (800 cells): 0.05s works well
  - 100x50 (5000 cells): 0.02-0.03s minimum
  - 100x100 (10000 cells): 0.05s+ recommended

- **Bottleneck**: The World actor's `report_state` handler does O(N) work to:
  - Collect all reports
  - Build the grid for rendering
  - Compute all neighbor counts
  - Send N messages

- **Not parallelized**: All cells process sequentially in the event loop. True parallelism would require threading or async I/O, which Yakt doesn't currently implement.

### Potential Improvements

1. **Chunked rendering**: Only redraw cells that changed
2. **Sparse representation**: For patterns with few live cells, track only live cells instead of full grid
3. **Cell-to-cell messaging**: Have cells query neighbors directly (more "actor-like" but higher message count)
4. **Multiple worlds**: Run several independent simulations in parallel

## Code Statistics

- ~500 lines total
- 6 message classes
- 3 main classes (Display, Cell, World)
- Uses: timers, spawn, send, signals (Started, Stopping)
