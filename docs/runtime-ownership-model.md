# Runtime Ownership Model

Loom's ownership model is the safety layer underneath plugin compatibility and performance work.

The model exists because "main thread" is too weak as a correctness rule once the server starts routing work through multiple domains. Loom needs to know which state a thread owns.

## Core Invariant

Only the owner domain for mutable state may mutate that state.

This invariant applies even when compatibility behavior is enabled. Compatibility can change how a call is routed, serialized, bridged, or refused. It cannot make off-owner mutation safe.

## Owner Domains

`OwnerDomainExecutor.Domain` defines five domains:

| Domain | Meaning | Typical work |
|---|---|---|
| `GLOBAL_CONTROL` | Global server lifecycle and coordination. | server commands, global scheduler dispatch, compatibility reroutes |
| `REGION` | World/chunk/block/entity mutation for chunk bounds. | block updates, entity ticks, chunk tasks, packet handlers touching local world state |
| `PLAYER` | Player-scoped mutable state. | player-specific routing and state checks |
| `LOGIN` | Login/pre-join flow. | authentication and pre-play setup |
| `ASYNC_IO` | Non-owning background work. | file I/O, HTTP, database, computation |

Source:

- `loom-server/src/minecraft/java/net/minecraft/server/threading/runtime/OwnerDomainExecutor.java`

## Owner Context Stack

Loom stores the current owner context in a thread-local stack.

When code enters an owner:

```text
OwnerDomainExecutor.enter(owner)
-> push owner context on current thread
-> run work
-> close scope
-> restore previous owner context
```

Nested owners are allowed. `isOwner(requestedOwner)` walks the stack and checks whether any active owner contains the requested owner.

Containment matters:

- a large region owner contains smaller region requests inside its bounds
- a player owner contains the same player owner
- global owner contains global work
- different domains do not contain each other

## Region Ownership

Region ownership has two layers:

1. `OwnerDomainExecutor` tracks the owner-domain scope.
2. `TickRegions` tracks the region lease and validates tick-thread access.

When a region context is pushed:

```text
TickRegions.pushRegionContext(world, minX, minZ, maxX, maxZ)
-> claim runtime lease for those bounds
-> enter matching OwnerDomainExecutor region scope
-> set current region context
```

When it is popped:

```text
TickRegions.popContext(context)
-> verify stack balance
-> close owner scope
-> release region lease
```

This is why Loom can reject code that is on a tick thread but does not own the specific chunk or region it is touching.

Source:

- `loom-server/src/minecraft/java/net/minecraft/server/threading/TickRegions.java`

## Handoff Semantics

`OwnerDomainExecutor.execute(owner, task)` follows this rule:

```text
if current thread already owns owner:
    run task immediately
else:
    enqueue task to the owner's runtime path
```

The enqueue path depends on domain:

- `GLOBAL_CONTROL`: `MinecraftServer.execute(...)`
- `REGION`: `TickRegions.sendCrossRegionMessage(...)`
- `PLAYER`: resolve player's current chunk, enqueue to that region, then validate player identity
- `LOGIN`: login executor
- `ASYNC_IO`: non-critical I/O pool

The wrapper enters the requested owner scope before running the task.

## Blocking Rule

Owner-domain threads must not synchronously wait for work that may need an owner domain.

Forbidden:

```text
owner-domain callback
-> call sync method or wait on future
-> block current owner thread
```

Reason:

```text
blocked owner thread may be required to complete the work being waited on
-> deadlock or stalled region/global progress
```

The blocking barrier rejects this:

```text
Owner-domain violation: <operation> cannot block an owner-domain thread
```

Source:

- `loom-server/src/minecraft/java/net/minecraft/server/threading/runtime/ThreadedRegionsBlockingBarrier.java`

## Plugin Sync Calls

Normal sync scheduler calls are still Paper-like:

```java
Bukkit.getScheduler().runTask(plugin, task);
```

Behavior:

```text
task enters CraftScheduler
-> queued for sync execution
-> scheduler heartbeat runs during server tick
-> task may use normal sync Bukkit APIs
```

This is compatibility-friendly but can cost MSPT if many plugins pile work onto the tick path.

Source:

- `paper-server/src/main/java/org/bukkit/craftbukkit/scheduler/CraftScheduler.java`
- `loom-server/src/minecraft/java/net/minecraft/server/MinecraftServer.java`

## Plugin Async Calls

Async scheduler calls run off the tick thread:

```java
Bukkit.getScheduler().runTaskAsynchronously(plugin, task);
```

Correct async work:

- database work
- HTTP requests
- file I/O
- cache computation
- data transformation that does not touch live Bukkit/world state

Unsafe async work:

- reading or mutating live blocks/entities/worlds through Bukkit
- synchronous chunk loads from async context
- player/world operations that require owner context

Loom wraps async scheduler tasks in compatibility context. If unsafe Bukkit access triggers an AsyncCatcher-style `IllegalStateException` beginning with `Asynchronous ...`, Loom tries an async rescue path:

```text
async task starts
-> unsafe Bukkit access throws
-> diagnostics record async violation
-> task is rerouted to global owner strict fallback
-> plugin classification escalates
```

This is a compatibility rescue, not a guarantee. Repeated violations make the plugin slower and stricter.

Sources:

- `paper-server/src/main/java/org/bukkit/craftbukkit/scheduler/CraftAsyncTask.java`
- `paper-server/src/main/java/io/papermc/paper/plugin/manager/compat/CompatibilitySchedulerBridge.java`
- `paper-server/src/main/java/org/spigotmc/AsyncCatcher.java`

## Sync Wait Bridge

Some legacy plugin paths produce a `CompletableFuture` and then wait for it.

Loom can bridge eligible waits only when:

- the current code is inside plugin compatibility context
- the wait is not happening on an owner-domain thread
- the wait is represented as a future-style wait that can be continuation-bridged

The bridge does not apply to:

- owner-domain blocking waits
- lock-bound `Condition.await(...)`
- non-plugin contexts
- paths Loom refuses for safety

Sources:

- `paper-server/src/main/java/io/papermc/paper/plugin/manager/compat/CompatibilitySyncBridge.java`
- `paper-server/src/main/java/io/papermc/paper/plugin/manager/compat/CompatibilityContinuationBridge.java`

## AsyncCatcher In Loom

Paper's AsyncCatcher checks thread safety. Loom extends the idea with owner-domain context checks.

The check can fail because:

1. the current thread is not a tick thread
2. the current thread is a tick/owner thread but does not own the relevant entity, block, chunk, or region

That second case is the important Loom-specific difference.

Example:

```text
thread owns region A
plugin touches block in region B
-> owner mismatch
-> async/owner violation
```

Source:

- `paper-server/src/main/java/org/spigotmc/AsyncCatcher.java`

## Failure Types

| Failure | Meaning | Expected response |
|---|---|---|
| `Asynchronous ...` | Bukkit/world API used from unsafe async context. | Route through sync task or owner-domain path; inspect async violations. |
| `Owner-domain violation ... requires ...` | Code touched state without owning it. | Identify target owner and hand off before mutation. |
| `cannot block an owner-domain thread` | Owner thread attempted a sync wait. | Convert to continuation/handoff flow. |
| `Compatibility sync bridge requires plugin runtime context` | Bridge was attempted outside plugin context. | Do not use plugin bridge from internal/non-plugin code. |
| refusal in `/loom compatibility` | Kernel refused a path for safety. | Inspect plugin behavior and route; do not bypass blindly. |

## Debugging Checklist

1. Read the exception message.
2. Identify the state being touched: global, region, player, login, or async I/O.
3. Identify the current owner context from logs/diagnostics.
4. Check `/loom compatibility` for plugin escalation, barrier waits, async violations, and refusals.
5. Check whether the code is blocking on a future or scheduler result.
6. If the path is plugin-facing, decide whether it should run through compatibility apartment/transaction handling.
7. If the path is server-internal, add an explicit owner-domain handoff instead of using plugin compatibility bridges.

## Practical Rule

Do not ask "is this on the main thread?"

Ask:

```text
Which mutable state does this code touch?
Which owner domain owns that state?
Is the current execution already inside that owner?
If not, can this be handed off, bridged, serialized, or must it be refused?
```
