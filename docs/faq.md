# FAQ

## Is Loom just Paper with extra threads?

No. Loom changes the runtime safety model. Mutable work must run in the correct owner domain. Paper's simple "main thread is safe" rule is not enough for Loom.

## Is Loom the same as Folia?

No. Folia exposes a region-threaded model to plugins. Loom's goal is different: keep broad Paper/Bukkit plugin compatibility as the default while routing execution through owner domains internally.

## Are there runtime modes?

No. Loom has one runtime path.

Old references to `compatibility`, `balanced`, or `performance` runtime modes are historical artifacts. Loom is just Loom now.

## Is the compatibility kernel a bypass?

No. The compatibility kernel routes, serializes, bridges, escalates, or refuses work. It does not disable owner-domain safety.

## Does every plugin work 100%?

No. That would not be honest.

Expected to work:

- normal Bukkit/Paper API usage
- sync events
- sync scheduler tasks
- async tasks doing async-safe work
- commands
- permissions
- placeholders
- GUI/menu plugins
- many gameplay plugins

Risky:

- Bukkit/world access from async threads
- blocking owner-domain waits
- reflection/NMS internals
- protocol/entity/chunk internals
- plugins depending on exact Paper timing quirks
- plugins with race conditions hidden by single-thread Paper

Loom should rescue many legacy mistakes, but it cannot safely rescue every possible plugin behavior.

## What happens if a plugin schedules a sync task?

`Bukkit.getScheduler().runTask(...)` queues work through the normal sync scheduler. The scheduler heartbeat runs during the server tick, so the task can use normal sync Bukkit APIs.

This is compatible, but too many sync tasks can still raise MSPT.

## What happens if a plugin schedules an async task?

`Bukkit.getScheduler().runTaskAsynchronously(...)` runs off the tick thread and is wrapped in plugin compatibility context.

If the task does async-safe work, it runs normally.

If it touches unsafe Bukkit/world APIs, `AsyncCatcher` can throw. Loom may then attempt an async rescue reroute through global owner strict fallback. Repeated violations escalate the plugin into stricter/slower handling.

## Can an async plugin wait for sync work?

Sometimes.

A future-style wait inside plugin compatibility context can be bridged when the current thread is not an owner-domain thread.

An owner-domain thread cannot block waiting for sync work. Loom refuses that because it can deadlock.

## What is an owner-domain violation?

It means code touched state without owning the required domain.

Example:

```text
thread owns region A
code touches region B
-> owner-domain violation
```

The fix is to route the work to the correct owner domain, not to silence the check.

## What is p95 MSPT?

`p95` means 95th percentile.

For MSPT:

```text
95% of sampled ticks were at or below that value
5% were worse
```

Average MSPT tells you the average cost. p95 MSPT tells you how bad the common spikes are.

## Why can Loom's tick be bursty?

Loom runs the world simulation tick serially through owner domains, so tick time
can spike when too much owner/tick-path work lands in the same tick. Common burst
sources:

- packet draining
- broad packet owner contexts
- mailbox/task drains
- chunk send/post-processing
- plugin compatibility waits

The per-tick drain budgets exist to smooth these bursts.

## Why not just increase worker threads?

Blunt worker increases can worsen tick time and reliability rather than help.
Loom's bottleneck is often bursty owner/tick-path work, not simply a lack of
workers.

## Why not remove compatibility to go faster?

Because that would fail Loom's real goal: strong performance while keeping
Paper-style plugin compatibility as the default. A speedup that breaks normal
plugins is not a Loom win.

## What should I inspect when a plugin fails?

Start with:

```text
/loom compatibility
/loom compatibility json
/loom tps
```

Then check logs for:

- `Asynchronous ...`
- `Owner-domain violation`
- `strict_fallback`
- `refusal`
- `owner_domain_wait_violation`
- `barrier_wait`

## Where should I start learning the code?

Read:

1. [Architecture Overview](architecture-overview.md)
2. [Runtime Ownership Model](runtime-ownership-model.md)
3. [Compatibility Kernel](compatibility-kernel.md)
4. [Performance and Tuning](performance.md)
