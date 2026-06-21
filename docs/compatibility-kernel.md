# Compatibility Kernel

The compatibility kernel is Loom's plugin execution layer. It exists because ordinary Paper plugins expect a simpler synchronous world than Loom's runtime can safely provide directly.

The kernel does not make unsafe behavior safe by ignoring the rules. It routes, serializes, bridges, escalates, or refuses work so plugin compatibility and owner-domain safety can coexist.

## What Compatibility Means In Loom

Compatibility means:

- preserve Paper-style plugin behavior where Loom can do so safely
- keep sync scheduler tasks useful for ordinary plugins
- run async scheduler tasks as async work while detecting unsafe Bukkit access
- serialize legacy plugin callbacks when needed
- bridge eligible plugin-context future waits off owner threads
- record enough diagnostics to explain why a plugin is fast, degraded, strict, or refused

Compatibility does not mean:

- every plugin works 100%
- async Bukkit/world access is always rescued
- owner-domain threads may block
- reflection/NMS/protocol-heavy plugins are guaranteed to behave identically to Paper
- safety checks can be bypassed to improve performance numbers

## Main Classes

| Class | Role |
|---|---|
| `CompatibilityKernel` | Selects routing decision and invocation plan. |
| `PluginCompatibilityProfile` | Tracks internal plugin classification, path state, escalations, and costs. |
| `EventSemanticIndex` | Summarizes listener priority, cancellation, monitor, ordered, and observer semantics. |
| `CompatibilityApartment` | Provides per-plugin serialization and strict fallback executor. |
| `CompatibilityTransaction` | Tracks event transaction state, listener passes, monitor mutation, overlays, commit/abort. |
| `CompatibilityRuntimeContext` | Thread-local plugin/transaction/path context used by bridges and diagnostics. |
| `CompatibilitySyncBridge` | Bridges eligible plugin future waits. |
| `CompatibilityContinuationBridge` | Moves waits off owner-domain execution. |
| `CompatibilityDiagnostics` | Records plugin/event/barrier/refusal/fallback statistics and renders commands/JSON. |

Source directory:

- `paper-server/src/main/java/io/papermc/paper/plugin/manager/compat/`

## Plugin Classification

Internally, each plugin has a compatibility classification.

The source currently calls this a `PluginCompatibilityProfile`. In user-facing language, think of it as the plugin's compatibility state.

Internal modes:

| Mode | Meaning |
|---|---|
| `NATIVE_LOOM_AWARE` | Plugin appears Loom-aware and can use native fast paths when the event route is safe. |
| `LEGACY_NORMAL` | Default for ordinary plugins. |
| `LEGACY_ORDERED` | Plugin needs stricter ordered behavior. |
| `LEGACY_INTERNAL` | Plugin appears to use internals such as protocol, packet, NMS, reflection, anticheat, NPC, or unsafe patterns. |
| `LEGACY_STRICT` | Plugin has escalated into strict fallback behavior. |
| `REFUSED` | Plugin/path is refused for safety. |

Internal path states:

| State | Meaning |
|---|---|
| `NATIVE_FAST_PATH` | Path is eligible for native fast handling. |
| `LEGACY_OBSERVED_SAFE` | Legacy path has no known reason for stricter treatment. |
| `LEGACY_DEGRADED` | Path showed risky behavior. |
| `FORCED_MAX_COMPAT` | Path requires maximum compatibility handling. |
| `REFUSED` | Path is refused. |

Escalation reasons include:

- static internal hints
- ordered event lane requirements
- monitor mutation
- async Bukkit access
- owner blocking wait
- apartment contention
- unsafe internal access
- strict fallback
- refusal

Source:

- `paper-server/src/main/java/io/papermc/paper/plugin/manager/compat/PluginCompatibilityProfile.java`

## Event Dispatch Routing

For each event dispatch, the kernel builds a `CompatibilityTransaction` and resolves event semantics.

Semantics include:

- event name
- whether the event is cancellable
- whether listener ordering matters
- whether `MONITOR` listeners are present
- whether the dispatch is observer-only

Routing decisions:

| Route | Meaning |
|---|---|
| `NATIVE_FAST_PATH` | No legacy risk detected for this listener set and event semantics. |
| `SNAPSHOT_OBSERVER` | Legacy observer listeners only; state can be observed without mutation transaction behavior. |
| `ORDERED_DECISION` | Ordered/cancellable semantics matter. |
| `MUTATION_TRANSACTION` | Monitor lane is present and mutation tracking matters. |
| `UNSAFE_INTERNAL` | Internal/risky plugin state is present. |
| `STRICT_REFUSAL` | Strict or refused plugin/path state is present. |

Invocation policies:

| Policy | Meaning |
|---|---|
| `NATIVE` | Call listener directly in native fast lane. |
| `APARTMENT` | Call through the plugin's compatibility apartment. |
| `EMERGENCY_COMPATIBILITY` | Use stricter compatibility for degraded/max-compat paths. |
| `STRICT_FALLBACK` | Force strict fallback handling. |
| `REFUSE` | Do not invoke the path. |

Execution lanes:

| Lane | Meaning |
|---|---|
| `FAST_LANE` | Native fast execution. |
| `APARTMENT_LANE` | Serialized legacy plugin apartment. |
| `TRANSACTION_LANE` | Ordered or mutation-sensitive event transaction. |
| `EMERGENCY_COMPATIBILITY_LANE` | Degraded/max-compat route. |
| `REFUSAL_LANE` | Refused route. |

Source:

- `paper-server/src/main/java/io/papermc/paper/plugin/manager/compat/CompatibilityKernel.java`
- `paper-server/src/main/java/io/papermc/paper/plugin/manager/compat/EventSemanticIndex.java`

## Compatibility Apartment

An apartment is a per-plugin serialization guard.

It prevents legacy plugin callbacks from running concurrently when Loom cannot prove that concurrent execution is safe for that plugin/path.

Apartment enter results:

| Result | Meaning |
|---|---|
| `ACQUIRED` | This thread acquired the plugin apartment. |
| `REENTRANT` | Same thread/transaction entered again. |
| `BUSY` | Another thread/transaction owns the apartment. |

If the apartment is busy:

- Loom records contention.
- If the current thread is an owner-domain thread, Loom refuses the handoff instead of blocking.
- If not on an owner-domain thread, Loom may use the strict fallback executor.

Source:

- `paper-server/src/main/java/io/papermc/paper/plugin/manager/compat/CompatibilityApartment.java`

## Compatibility Transaction

Transactions give event dispatches a structured record.

They track:

- transaction ID
- parent transaction ID
- event name
- cancellation state
- listener pass timing
- monitor-lane mutation
- overlay writes
- commit or abort

`MONITOR` mutation matters because Bukkit convention treats `MONITOR` as observation, not mutation. Loom detects field/cancel-state changes around monitor listeners and escalates the plugin if it mutates there.

Source:

- `paper-server/src/main/java/io/papermc/paper/plugin/manager/compat/CompatibilityTransaction.java`

## Sync Bridge

The sync bridge handles a narrow class of legacy waits.

Eligible:

- plugin is inside `CompatibilityRuntimeContext`
- wait is future-style
- current execution is not an owner-domain thread

Not eligible:

- owner-domain thread blocking
- `Condition.await(...)` style lock-bound waits
- non-plugin context
- refused path

Bridge flow:

```text
CompatibilitySyncBridge.awaitFuture(...)
-> require current plugin context
-> CompatibilityContinuationBridge.callOffOwner(...)
-> reject if current thread can run synchronous owner callbacks
-> wait on virtual thread or continuation
-> record barrier and continuation diagnostics
```

Sources:

- `paper-server/src/main/java/io/papermc/paper/plugin/manager/compat/CompatibilitySyncBridge.java`
- `paper-server/src/main/java/io/papermc/paper/plugin/manager/compat/CompatibilityContinuationBridge.java`

## Async Scheduler Rescue

Async scheduler tasks are wrapped in plugin compatibility context.

When an async task trips an AsyncCatcher-style error:

```text
IllegalStateException message starts with "Asynchronous "
```

Loom attempts to reroute the task:

```text
record strict fallback
-> submit to GLOBAL_CONTROL owner
-> rerun task in strict fallback compatibility context
-> await from non-owner path
```

This is meant to rescue common bad legacy behavior. It is not guaranteed for all async misuse and it makes the plugin stricter/slower.

Source:

- `paper-server/src/main/java/org/bukkit/craftbukkit/scheduler/CraftAsyncTask.java`

## Diagnostics

Use:

```text
/loom compatibility
/loom compatibility json
/loom tps
```

Important diagnostic concepts:

| Field | Meaning |
|---|---|
| `transactions` | event transactions observed |
| `monitorMutations` | monitor lane mutation attempts |
| `snapshotDeliveries` | observer-only snapshot route use |
| `mutationTransactions` | transactions with pending mutation/overlay work |
| `strictFallbacks` | strict compatibility routes |
| `refusals` | refused paths |
| `asyncViolations` | async Bukkit access violations |
| `ownerRpcWait` | time spent waiting for owner-routed compatibility work |
| `barrierWait` | time spent in compatibility bridge waits |
| `lanes` | per-plugin lane usage |
| `hotEvents` | highest-cost events per plugin |

Source:

- `paper-server/src/main/java/io/papermc/paper/plugin/manager/compat/CompatibilityDiagnostics.java`

## How To Interpret Plugin Behavior

| Observation | Interpretation |
|---|---|
| high callback time | plugin code itself is expensive |
| high barrier time | plugin is waiting on bridged sync-style operations |
| high owner RPC time | plugin causes owner-domain handoffs/waits |
| repeated async violations | plugin is touching Bukkit/world state from async paths |
| monitor mutations | plugin is mutating from observer priority |
| strict fallback | Loom is protecting a risky path |
| refusal | Loom cannot safely execute that path |

## Compatibility Target

The honest target is:

> Paper-level compatibility for well-behaved plugins, broad rescue behavior for many legacy mistakes, and explicit refusal for patterns that would deadlock or corrupt state.

Loom should not require ordinary plugin authors to become region-threading experts just to get basic compatibility.
