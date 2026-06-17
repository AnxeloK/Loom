# Performance and Tuning

Loom is a compatibility-first runtime. It keeps ordinary Paper plugins on
familiar single-main-thread semantics while routing mutable world, entity,
player, login, and global work through explicit owner domains. That lets Loom
move chunk loading, generation, I/O, and scheduled work off the main tick
without exposing region-threaded responsibilities to plugin authors.

## What runs where

- **World simulation tick** (entity ticking, block/fluid ticks, chunk ticking)
  runs serially so plugin callbacks keep Paper's single-thread guarantees.
- **Chunk system** (load, generate, post-process, send) runs on a worker pool.
- **Networking** runs on Netty I/O threads, with serverbound packet handlers
  resumed inside the correct owner domain.
- **Scheduled tasks and cross-region messages** drain on the region scheduler
  pool.

## Design tradeoffs

- Because the simulation tick is serial, Loom trades raw multi-threaded
  throughput for plugin compatibility. Per-tick **drain budgets** bound chunk
  task drains, packet bursts, and mailbox/scheduler work to keep worst-case tick
  spikes low.
- Worker and region-scheduler thread counts scale with the host CPU count.
- A faster path is only acceptable if it preserves vanilla behavior and owner
  safety; performance is never bought by weakening compatibility.

## Recommended startup

A 3–6 GB heap is a sensible starting point; size it to your player count and
available RAM, leaving headroom for the OS. The runtime benefits from G1
tuning — for example:

```bash
java -Xms4G -Xmx4G \
  -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 \
  -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC \
  -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 -XX:G1HeapRegionSize=8M \
  -XX:G1ReservePercent=20 -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 \
  -XX:InitiatingHeapOccupancyPercent=15 -XX:SurvivorRatio=32 \
  -XX:MaxTenuringThreshold=1 \
  -jar server.jar nogui
```

Scale `-Xms`/`-Xmx` together and adjust to your hardware.

## Tuning properties

All of the following are JVM system properties (`-Dname=value`); the defaults
target a typical modern multi-core host. They do not require a rebuild.

### Threads

| Property | Default | Effect |
|---|---|---|
| `Loom.WorkerThreadCount` | auto (scales with cores) | Chunk-system worker threads. |
| `paper.threadedregions.parallelScheduler.threads` | `cores / 2` | Region scheduler threads. |

### Per-tick drain budgets (worst-case spike control)

| Property | Default | Effect |
|---|---|---|
| `Loom.TickStartChunkTaskMaxTasks` | `2` | Max chunk tasks drained at tick start. |
| `Loom.TickStartChunkTaskBudgetNanos` | `1000000` | Time budget for the tick-start chunk drain. |
| `Loom.PacketTickStartMaxPackets` | `2048` | Max packets drained at tick start. |
| `Loom.PacketTickStartBudgetNanos` | `2000000` | Time budget for the tick-start packet drain. |
| `paper.threadedregions.drain.targetSlackMillis` | `8` | Reduce drain budgets when close to the next tick. |

### Player chunk pipeline

| Property | Default | Effect |
|---|---|---|
| `Loom.PlayerChunkSendMaxPerTick` | `4` | Max chunks sent per player per tick. |
| `Loom.PlayerChunkSendBudgetMillis` | `3` | Time budget for chunk sends. |
| `Loom.PlayerChunkGenerationAdmissionBudgetMillis` | `2` | Time budget for admitting chunk generation. |
| `Loom.PlayerChunkLoadScheduleBudgetMillis` | `2` | Time budget for scheduling chunk loads. |
| `Loom.PlayerChunkPostProcessBudgetMillis` | `2` | Time budget for chunk post-processing. |

Raising the chunk pipeline budgets favors throughput; lowering them favors
smoother per-tick latency. Tune to your workload and validate with a live
server before committing to non-default values.
