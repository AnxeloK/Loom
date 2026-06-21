# Performance and Tuning

Loom spreads the server's heaviest work across CPU cores by default. World, chunk,
and entity ticking run in parallel across a region scheduler pool, while the
effects plugins can observe (block changes, events, spawns) are committed in a
safe, ordered way so ordinary plugins still see Paper-like single-thread behavior.
Chunk loading, generation, I/O, networking, and scheduled tasks also run off the
main path.

## What runs where

- **World simulation** (chunk ticking, block/fluid ticks, entity ticking) runs in
  parallel across the region scheduler pool. Writes that a plugin could observe are
  staged during the parallel phase and replayed in order afterward, so plugin
  callbacks keep Paper's main-thread guarantees.
- **Chunk system** (load, generate, post-process, send) runs on a worker pool.
- **Networking** runs on Netty I/O threads, with serverbound packet handlers
  resumed inside the correct owner domain.
- **Scheduled tasks and cross-region messages** drain on the region scheduler pool.

## Design tradeoffs

- Keeping plugins compatible is not free: observable writes are replayed in order
  rather than committed in place, and per-world work is coordinated so plugins never
  see partial state. Loom accepts that overhead in exchange for running unmodified
  plugins across multiple cores.
- Per-tick **drain budgets** bound chunk-task drains, packet bursts, and
  mailbox/scheduler work to keep worst-case tick spikes low.
- Region-scheduler and worker thread counts scale with the host's CPU count.
- A faster path is only acceptable if it preserves vanilla behavior and owner
  safety. Performance is never bought by weakening compatibility.

## Recommended startup

A 3–6 GB heap is a sensible starting point; size it to your player count and
available RAM, leaving headroom for the OS. The runtime benefits from G1 tuning —
for example:

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

All of the following are JVM system properties (`-Dname=value`). They do not
require a rebuild, and the defaults target a typical modern multi-core host.

### Region scheduler

| Property | Default | Effect |
|---|---|---|
| `paper.threadedregions.parallelScheduler.threads` | `cores / 2` | Threads in the pool that runs parallel world/chunk/entity ticking. |
| `paper.threadedregions.parallelScheduler.bucketShift` | `3` | How large the region cells are that work is split into; larger is coarser. |
| `loom.regionTaskBufferChunks` | `1` | Safety gap, in chunks, kept between cells that run in parallel. |

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

Raising the chunk pipeline budgets favors throughput; lowering them favors smoother
per-tick latency. Tune to your workload and validate on a live server before
committing to non-default values.
