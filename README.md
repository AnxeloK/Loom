# Loom

Loom is an experimental Paper fork that keeps the Paper/Bukkit plugin surface as the default target while adding a stricter threaded runtime underneath it.

The short version:

- Paper assumes most mutable server state is protected by one main thread.
- Folia exposes region-threaded rules directly to plugins.
- Loom tries a harder target: preserve normal Paper-style plugin behavior where it can be preserved safely, while internally routing work through explicit owner domains.

Loom is not a promise that every plugin ever written will work perfectly. It is a compatibility-first threaded runtime: ordinary Paper plugins should keep working, broken legacy behavior is rescued when Loom can do so without corrupting state or deadlocking, and unsafe patterns remain strict.

## What Loom Is Optimizing For

Loom has two goals that pull against each other:

1. **Plugin compatibility.** Commands, events, sync scheduler tasks, async scheduler tasks, permissions, placeholder plugins, GUI plugins, protocol plugins, and gameplay plugins should see behavior close to Paper unless their code depends on unsafe internals.
2. **Threaded performance.** Mutable world/player/server work must run in the correct owner domain so the runtime can safely exploit parallelism and avoid one global serialization point.

The central design rule is:

> A thread is safe only when it owns the state it is touching.

Being on "the server thread" is not enough in Loom. The runtime checks whether the current execution owns the relevant global state, region, player, login flow, or async I/O context.

## Current Runtime Shape

Loom has one runtime path. There are no runtime modes named `compatibility`, `balanced`, or `performance`.

The compatibility kernel is always part of Loom. It is not a selectable configuration and it is not a safety bypass. It is the standard Loom execution layer that routes plugin work through safe lanes, records diagnostics, and escalates risky plugins into stricter handling when needed.

## Core Systems

| System | Purpose | Main source |
|---|---|---|
| Owner-domain runtime | Tracks and enforces ownership of global, region, player, login, and async I/O work. | `loom-server/src/minecraft/java/net/minecraft/server/threading/runtime/OwnerDomainExecutor.java` |
| Region lease runtime | Maintains region ownership contexts and cross-region mailbox delivery. | `loom-server/src/minecraft/java/net/minecraft/server/threading/TickRegions.java` |
| Compatibility kernel | Classifies plugin/event paths and selects native, apartment, transaction, emergency, or refusal lanes. | `paper-server/src/main/java/io/papermc/paper/plugin/manager/compat/CompatibilityKernel.java` |
| Compatibility apartment | Serializes legacy plugin callbacks per plugin when Loom cannot prove the path is natively safe. | `paper-server/src/main/java/io/papermc/paper/plugin/manager/compat/CompatibilityApartment.java` |
| Compatibility transaction | Tracks event semantics, cancellation, monitor-lane mutation, overlays, and commit/abort state. | `paper-server/src/main/java/io/papermc/paper/plugin/manager/compat/CompatibilityTransaction.java` |
| Sync bridge | Lets eligible plugin-context waits resume off owner threads instead of blocking owner-domain execution. | `paper-server/src/main/java/io/papermc/paper/plugin/manager/compat/CompatibilitySyncBridge.java` |
| Async rescue path | Reroutes some async scheduler tasks after AsyncCatcher-style Bukkit access failures. | `paper-server/src/main/java/org/bukkit/craftbukkit/scheduler/CraftAsyncTask.java` |
| Packet owner context | Runs serverbound packet handlers inside a player/region owner context. | `loom-server/src/minecraft/java/net/minecraft/network/PacketProcessor.java` |
| Player chunk loader | Manages per-player chunk load, generation, ticking, post-processing, and send queues. | `loom-server/src/minecraft/java/ca/spottedleaf/moonrise/patches/chunk_system/player/RegionizedPlayerChunkLoader.java` |

## Performance Characteristics

Loom is compatibility-first. Ordinary Paper plugins keep familiar main-thread
semantics, while mutable world, entity, player, login, and global work is routed
through explicit owner domains so the runtime can move chunk loading, generation,
I/O, and scheduled work off the main tick.

Design tradeoffs to be aware of:

- The world simulation tick (entities, blocks, chunks) runs serially so plugin
  callbacks keep Paper's single-main-thread guarantees. Chunk system, networking,
  and scheduled work run on separate threads.
- Per-tick drain budgets bound chunk-task drains, packet bursts, and
  mailbox/scheduler work to keep worst-case tick spikes low.
- Worker and region-scheduler thread counts scale with the host's CPU count.

Performance is not allowed to come at the cost of compatibility or owner safety:
a faster path only counts if Paper-style plugin behavior remains the default
target. Tune the runtime with the `-DLoom.*` and `-Dpaper.threadedregions.*`
system properties; see [Performance and Tuning](docs/performance.md).

## Quick Build

```bash
./patch.sh
./gradlew :loom-server:build
```

Required gates before release or merge:

```bash
./gradlew applyAllPatches
./gradlew :loom-server:compileJava
./gradlew build
```

## Runtime Smoke Check

After replacing runtime jars and starting a test server:

1. Wait for `Done (...)`.
2. Run `plugins`.
3. Run `/loom tps`.
4. Run `/loom compatibility`.
5. Run `/loom compatibility json` when debugging plugin routing.
6. Exercise plugin-heavy paths: commands, GUI/menu actions, placeholders, teleports, joins, disconnects, and chunk movement.
7. Stop the server cleanly.

Any owner-domain violation, async Bukkit violation, refusal, or strict fallback should be understood before treating the build as stable.

## Documentation

Start with [docs/README.md](docs/README.md).

Recommended study order:

1. [Getting Started](docs/getting-started.md)
2. [Architecture Overview](docs/architecture-overview.md)
3. [Runtime Ownership Model](docs/runtime-ownership-model.md)
4. [Compatibility Kernel](docs/compatibility-kernel.md)
5. [Performance and Tuning](docs/performance.md)
6. [Patch and Release Workflow](docs/patch-and-release-workflow.md)
7. [FAQ](docs/faq.md)

## Non-Goals

- Loom does not guarantee that every plugin works 100%.
- Loom does not make unsafe async Bukkit access safe in all cases.
- Loom does not allow owner-domain threads to block on sync waits.
- Loom does not expose Folia-style responsibility to ordinary plugin authors as the default compatibility model.
- Loom does not treat performance wins as valid if they come from weakening compatibility or owner safety.
