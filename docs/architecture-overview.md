# Architecture Overview

This page explains Loom as a system. It is the main study page before reading the lower-level ownership and compatibility pages.

## Problem Loom Is Solving

Traditional Paper has one dominant safety assumption:

```text
sync Bukkit/server work runs on the main server thread
```

That assumption is simple and compatible, but it serializes too much work. Folia moves toward region-threaded execution, but plugin authors must respect a different threading contract.

Loom tries a different target:

```text
keep the Paper-style plugin surface where possible
route internal execution through explicit owner domains
refuse or degrade behavior that cannot be made safe
```

The difficult part is that those goals conflict. More compatibility means more serialization, bridging, and fallback paths. More parallelism means stricter ownership. Loom's architecture is the machinery between those two pressures.

## The Core Rule

Mutable state can only be touched by the owner domain for that state.

Examples:

- global lifecycle and server coordination belong to `GLOBAL_CONTROL`
- a chunk/block/entity mutation belongs to a `REGION`
- player-scoped state belongs to `PLAYER`
- login/pre-join work belongs to `LOGIN`
- background I/O belongs to `ASYNC_IO`

The source of this model is `OwnerDomainExecutor`.

```text
OwnerDomainExecutor.execute(owner, task)
-> if current context already owns owner: run inline
-> otherwise enqueue to global, region, player, login, or async I/O executor
-> wrapped task enters the owner context before running
```

Source:

- `loom-server/src/minecraft/java/net/minecraft/server/threading/runtime/OwnerDomainExecutor.java`

## Runtime Layers

Loom has four major runtime layers.

### 1. Owner-Domain Runtime

The owner-domain runtime identifies the state a task wants to touch and decides whether the task can run immediately.

If the current context already contains the requested owner, Loom runs inline. Otherwise it hands the work to the correct runtime queue:

- global work goes through the server executor
- region work goes through cross-region messages
- player work resolves the player's current region and then runs with player ownership
- login work uses a login executor
- async I/O uses the non-critical I/O pool

This is the lowest-level safety layer.

### 2. Region Lease Runtime

`TickRegions` tracks active region contexts and region ownership leases.

When code pushes a region context, Loom:

1. claims a lease for the world/chunk bounds
2. enters a matching owner-domain region scope
3. records the context in a thread-local stack
4. releases the lease when the context is popped

This lets ownership checks verify not just "am I a tick thread?" but "does this thread own the exact region being touched?"

Source:

- `loom-server/src/minecraft/java/net/minecraft/server/threading/TickRegions.java`

### 3. Compatibility Kernel

The compatibility kernel handles plugin-facing execution.

For event dispatch, it:

1. creates a compatibility transaction
2. resolves event semantics
3. classifies listener/plugin risk
4. chooses an invocation policy
5. invokes the listener through native, apartment, transaction, emergency, strict, or refusal handling
6. records diagnostics

The kernel is not optional. It is Loom's standard plugin execution layer.

Source:

- `paper-server/src/main/java/io/papermc/paper/plugin/manager/compat/CompatibilityKernel.java`
- `paper-server/src/main/java/io/papermc/paper/plugin/manager/PaperEventManager.java`

### 4. Compatibility Bridges

Some legacy plugin behavior expects to block for sync work. Blocking an owner-domain thread is unsafe because the target work might need that same owner to make progress.

Loom bridges eligible plugin-context waits by moving the wait off owner-domain execution:

```text
plugin compatibility context
-> future wait requested
-> bridge checks that current thread is not an owner-domain thread
-> continuation waits off-owner
-> result returns to plugin flow
-> diagnostics record barrier/continuation time
```

If the wait happens on an owner-domain thread, Loom rejects it.

Sources:

- `paper-server/src/main/java/io/papermc/paper/plugin/manager/compat/CompatibilitySyncBridge.java`
- `paper-server/src/main/java/io/papermc/paper/plugin/manager/compat/CompatibilityContinuationBridge.java`
- `loom-server/src/minecraft/java/net/minecraft/server/threading/runtime/ThreadedRegionsBlockingBarrier.java`

## Event Dispatch Flow

For a normal Bukkit event:

```text
PaperEventManager.callEvent(event)
-> reject async event on primary thread or sync event off primary thread
-> collect RegisteredListener[]
-> CompatibilityKernel.beginTransaction(event, listeners)
-> CompatibilityKernel.routingDecision(...)
-> for each listener:
     -> load plugin compatibility classification
     -> build invocation plan
     -> call listener natively, through apartment, through strict fallback, or refuse
     -> record callback cost and transaction state
-> finish transaction
-> record monitor mutations and diagnostics
```

Important files:

- `paper-server/src/main/java/io/papermc/paper/plugin/manager/PaperEventManager.java`
- `paper-server/src/main/java/io/papermc/paper/plugin/manager/compat/EventSemanticIndex.java`
- `paper-server/src/main/java/io/papermc/paper/plugin/manager/compat/CompatibilityTransaction.java`

## Scheduler Flow

Sync scheduler work remains close to Paper:

```text
Bukkit.getScheduler().runTask(plugin, task)
-> CraftScheduler queues task
-> MinecraftServer tick pumps scheduler heartbeat
-> task runs during server tick
```

Async scheduler work:

```text
Bukkit.getScheduler().runTaskAsynchronously(plugin, task)
-> task runs off the tick thread
-> task is wrapped in CompatibilityRuntimeContext
-> unsafe Bukkit access can trip AsyncCatcher
-> Loom may reroute the task to global owner strict fallback
```

This is why "async" does not mean "safe to touch Bukkit." Async-safe work is still I/O, computation, and other non-world operations. World/server mutation still needs ownership.

Sources:

- `paper-server/src/main/java/org/bukkit/craftbukkit/scheduler/CraftScheduler.java`
- `paper-server/src/main/java/org/bukkit/craftbukkit/scheduler/CraftAsyncTask.java`
- `paper-server/src/main/java/io/papermc/paper/plugin/manager/compat/CompatibilitySchedulerBridge.java`

## Packet Flow

Serverbound packets are queued and then drained on the server/tick path.

Current shape:

```text
network thread receives packet
-> PacketProcessor.scheduleIfPossible(...)
-> packet is queued
-> server tick executes queued packets
-> ServerGamePacketListenerImpl packets enter broad player region owner context
-> packet handler runs
```

This is safe, but it can be expensive. The current player packet owner context uses a radius based on view distance and simulation distance, so common packets may claim a larger region than they truly need.

Source:

- `loom-server/src/minecraft/java/net/minecraft/network/PacketProcessor.java`

## Chunk Send Flow

Per-player chunk loading is one of Loom's most important performance paths.

The player chunk loader:

1. updates player view/load/send/tick distance state
2. progresses completed loads
3. schedules new loads
4. processes ticket updates
5. progresses generation
6. progresses ticking tickets
7. post-processes chunks before sending when needed
8. calls plugin watch hooks
9. sends chunk packets

The same tick can do many of those phases. That keeps average throughput high, but can create p95 spikes when chunk sends, post-processing, and packet allocation bunch together.

Sources:

- `loom-server/src/minecraft/java/ca/spottedleaf/moonrise/patches/chunk_system/player/RegionizedPlayerChunkLoader.java`
- `loom-server/src/minecraft/java/net/minecraft/network/Connection.java`

## Why Loom's Tick Can Be Bursty

Loom runs the world simulation tick serially through owner domains. The steady
cost is moderate, but tick time can spike when too much owner/tick-path work
lands in the same tick.

Loom is not fundamentally too slow. It is too bursty.

Likely burst sources:

- unbounded or high-budget packet draining
- broad packet owner regions
- high mailbox/task drain budgets
- chunk post-processing on the owner/tick path
- chunk packet serialization and plugin watch hooks during send
- compatibility waits from plugin behavior

The performance work should smooth those bursts without weakening plugin compatibility.

## Source Map

| Topic | File |
|---|---|
| Owner domains | `OwnerDomainExecutor.java` |
| Region leases and mailbox | `TickRegions.java` |
| Blocking wait rules | `ThreadedRegionsBlockingBarrier.java` |
| Event routing | `CompatibilityKernel.java`, `PaperEventManager.java` |
| Plugin classification | `PluginCompatibilityProfile.java` |
| Event semantics | `EventSemanticIndex.java` |
| Plugin serialization | `CompatibilityApartment.java` |
| Event transaction state | `CompatibilityTransaction.java` |
| Diagnostics | `CompatibilityDiagnostics.java` |
| Async scheduler rescue | `CraftAsyncTask.java` |
| Sync/async scheduler queue | `CraftScheduler.java` |
| Packet handling | `PacketProcessor.java` |
| Player chunk loading/sending | `RegionizedPlayerChunkLoader.java` |
| Network pending writes/backpressure | `Connection.java` |

## Design Principle

Loom should improve performance only by doing the same safe work more intelligently. It should not improve by making plugins responsible for Folia-style region rules, and it should not improve by disabling ownership checks.
