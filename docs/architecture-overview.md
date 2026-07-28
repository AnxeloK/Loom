# Architecture overview

Loom keeps mutable game state inside explicit owner domains, then runs independent work in parallel where those owners do not overlap.

## The execution model

```text
incoming work
  -> identify the state it will touch
  -> find that state’s owner domain
  -> run there, or schedule a continuation there
  -> record diagnostics when a plugin path needs extra handling
```

The key distinction is ownership, not whether a thread happens to be called the main thread.

## Owner domains

| Domain | Owns | Typical work |
| --- | --- | --- |
| `GLOBAL_CONTROL` | Server-wide lifecycle and coordination | Global tasks, lifecycle actions, server commands |
| `REGION` | A bounded area of world state | Blocks, entities, chunk work, local packet handling |
| `PLAYER` | Player-scoped mutable state | Player routing and state transitions |
| `LOGIN` | Pre-play login state | Login and initial player setup |
| `ASYNC_IO` | Background work without world ownership | File I/O, databases, HTTP, computation |

When the current owner already contains the requested owner, Loom can run the work inline. Otherwise it schedules a continuation on the correct owner domain.

## Plugin-facing work

Plugins still use familiar Bukkit and Paper entry points. Loom's compatibility layer decides how a particular callback should run:

- direct execution when the route is already safe
- a serialized plugin callback when legacy state needs protection
- an owner-domain continuation when the destination state is elsewhere
- a refusal when the path would block or mutate state unsafely

This decision is automatic and recorded by `/loom compatibility`.

## Event flow

```text
Bukkit event
  -> inspect listeners and event semantics
  -> create a transaction for ordering and cancellation state
  -> select a safe route for each listener
  -> run callbacks and record their cost
  -> finish the transaction and report unusual behaviour
```

The event transaction is what allows Loom to preserve event ordering and cancellation behaviour while not exposing unsafe concurrent mutation to plugins.

## Chunk and network flow

Chunk loading, generation, I/O, post-processing, and sending are separate stages. A busy server can be limited by any one of them, so a higher worker count is not automatically faster.

Network threads receive packets, but world-sensitive packet handling is resumed in the owner domain that owns the target state. This is why packet bursts and tick spikes should be profiled together when movement feels delayed.

## Useful source locations

| Area | Location |
| --- | --- |
| Owner dispatch | `loom-server/src/minecraft/java/net/minecraft/server/threading/runtime/OwnerDomainExecutor.java` |
| Region leases | `loom-server/src/minecraft/java/net/minecraft/server/threading/TickRegions.java` |
| Event routing | `paper-server/src/main/java/io/papermc/paper/plugin/manager/PaperEventManager.java` |
| Plugin diagnostics | `paper-server/src/main/java/io/papermc/paper/plugin/manager/compat/` |
| Player chunk pipeline | `loom-server/src/minecraft/java/ca/spottedleaf/moonrise/patches/chunk_system/player/RegionizedPlayerChunkLoader.java` |

For implementation rules, read [Runtime ownership](runtime-ownership-model.md). For operator diagnostics, read [Compatibility diagnostics](compatibility-kernel.md).
