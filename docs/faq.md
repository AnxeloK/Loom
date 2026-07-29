# FAQ

## Which release jar should I use?

Open [Releases](../../releases), choose the latest Loom release, and download the jar whose `mc` suffix exactly matches your Minecraft version. One Loom release contains all currently supported jars, but the jars themselves are not interchangeable. See [the release workflow](patch-and-release-workflow.md) for the version layout.

## Do ordinary plugins need changes?

Usually not. Standard Bukkit and Paper usage should continue to work. Plugins that use unsafe async Bukkit access, blocking waits, reflection, NMS internals, packet internals, or timing assumptions need closer testing.

## How does Loom choose a plugin route?

It inspects the work being requested and routes it automatically. A safe callback can run directly; a legacy callback can be serialized; an unsafe path can be handed off or refused.

## Can I disable owner-domain checks?

No. An owner-domain error means code touched mutable state from the wrong execution context. Hiding that error risks corruption, races, and deadlocks.

## Why does a player rubber-band or see delayed movement?

Check server tick time, packet handling, network latency, owner-domain diagnostics, and a profile captured during the problem. Do not assume the network is the only cause when the server is under load.

## Why does chunk exploration become slow when players spread out?

Exploration can be limited by generation, disk I/O, chunk send work, worker saturation, or the player chunk pipeline. Capture a profile while players are exploring before changing worker counts.

## What should I inspect after a crash?

Keep the first stack trace, the surrounding server log, the active jar version, Java version, plugin list, and the action that triggered it. Add `/loom compatibility json` and a profiler capture when the issue is performance-related.

## Why is a plugin shown with fallback work or a refusal?

Loom found a path that needs extra serialization or cannot run safely. The named plugin, event, and log message are the starting point. Raising CPU limits or worker threads will not fix unsafe plugin behaviour.

## Can an async task change a block or player state?

Not directly. Do the async data work first, then hand off the live state change to the owner domain that owns the block or player.

## Is a larger heap always faster?

No. A larger heap can help allocation pressure, but it does not solve CPU saturation, slow plugins, disk I/O, or bad chunk settings. Leave memory headroom and compare changes with the same workload.
