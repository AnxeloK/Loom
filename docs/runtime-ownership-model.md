# Runtime ownership

This page is for contributors fixing code that touches server state.

## The rule

Mutable state must be read or changed inside the owner domain responsible for it. A thread being busy, synchronous, or part of a tick is not enough by itself.

Before changing a path, answer three questions:

1. What state will this code touch?
2. Which owner domain owns that state?
3. Is this code already executing inside that owner?

If the answer to the last question is no, schedule a continuation. Do not weaken the check or block the current owner while waiting.

## The owner domains

| Domain | Examples |
| --- | --- |
| `GLOBAL_CONTROL` | Server lifecycle, global coordination, global tasks |
| `REGION` | Chunk, block, entity, and world state in a bounded area |
| `PLAYER` | Player-specific mutable state |
| `LOGIN` | Login and pre-play work |
| `ASYNC_IO` | I/O and computation that do not touch live game state |

`OwnerDomainExecutor` is the routing boundary. It runs a task inline only when the current owner already contains the requested owner. Otherwise it queues the task for the correct executor.

## Correct handoff shape

```text
need destination world or region state
  -> request the destination chunk asynchronously if it is needed
  -> resume after it is ready
  -> enter the destination owner domain
  -> perform the mutation there
```

The important part is that both chunk readiness and the mutable operation are owned by the destination. Do not turn a normal load or generation path into a missing-chunk failure just to avoid a continuation.

## Never block an owner domain

This shape is unsafe:

```text
owner-domain task
  -> schedule work for another owner
  -> wait with join, get, await, or a synchronous helper
```

The work being awaited may need the blocked owner to progress. That creates a stall or deadlock. Use a continuation, callback, or off-owner bridge instead.

## Async plugin work

Async tasks are appropriate for I/O, databases, HTTP, file access, and pure computation. They are not automatically allowed to read or mutate live Bukkit, player, entity, world, or chunk state.

When an async path must affect live state, calculate or fetch data asynchronously, then hand off only the state-changing step to the correct owner domain.

## How to interpret failures

| Message or symptom | Fix direction |
| --- | --- |
| `Asynchronous ...` | Keep Bukkit and world access out of the async callback, or hand off the access to its owner. |
| `Owner-domain violation` | Identify the target state and run the operation in its owner domain. |
| `cannot block an owner-domain thread` | Replace the wait with a continuation or a non-owner bridge. |
| Repeated fallback or refusal for a plugin | Inspect the named plugin path before changing runtime safety rules. |

## Tests to run

Changes to ownership routing should be tested with the operation that crosses the boundary. Depending on the path, that can include chunk generation, teleports, portals, respawn, login, commands, plugin callbacks, and clean shutdown.

Compile first, then test on a server with logs visible. A fix is incomplete if it only removes an exception but changes vanilla behaviour or moves mutation to the wrong owner.
