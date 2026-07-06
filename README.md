# Loom

Loom is a Minecraft server — a fork of [Paper](https://papermc.io) — that spreads the game's work across multiple CPU cores while keeping your existing plugins running unchanged.

Most Minecraft servers do nearly all of their work on a single thread. That keeps plugins simple and safe, but it also means one busy world can't make use of the rest of your CPU. Loom changes the engine underneath so work can run on many cores at once — without asking plugin developers to rewrite anything.

## What Loom gives you

- **More of your CPU, automatically.** World, chunk, and entity work is spread across cores instead of being pinned to one thread.
- **Your plugins keep working.** Commands, events, scheduler tasks, permissions, GUIs, placeholders, and most gameplay plugins behave the way they do on Paper.
- **One path, no setup required.** There are no modes to pick between — Loom runs a single path and keeps it safe by default.

Loom is honest about its limits. It is compatibility-first, not a promise that every plugin ever written will work perfectly: well-behaved plugins should just work, common legacy mistakes are handled where it is safe to, and genuinely unsafe patterns are rejected rather than allowed to corrupt your world or deadlock the server.

## The one idea behind Loom

> A thread is safe only when it owns the state it is touching.

On an ordinary server, being "on the main thread" is treated as safe. Loom replaces that with ownership: before any code touches a world, region, player, or global state, the runtime checks that the current thread actually owns it. That single rule is what lets Loom run work in parallel without plugins noticing.

Everything else — the region system, the compatibility layer that keeps plugins working, and the chunk loader — exists to enforce that rule efficiently. The [documentation](docs/README.md) explains how each piece fits together.

## Requirements

- **Java 25.** Loom is built and run on Java 25 — use a Java 25 (or newer) JDK to build and a Java 25 JRE to run. On an older Java the server won't start (`UnsupportedClassVersionError`).
- **Your own JVM flags.** Loom does not set your heap size or garbage collector — like any Java server, those come from your launch command. Starting with just `-jar server.jar` gives you the JVM's small default heap and default GC, which perform poorly; use a proper startup line (see [Performance and Tuning](docs/performance.md)). Loom's own parallelism — the region and worker thread counts — scales to your CPU automatically, so that part needs no tuning.

## Build from source

```bash
./patch.sh
./gradlew :loom-server:build
```

Before treating a build as releasable, run the validation gates:

```bash
./gradlew applyAllPatches
./gradlew :loom-server:compileJava
./gradlew build
```

If `applyAllPatches` fails from a clean state, the patch sources and the generated tree have drifted and need to be reconciled first.

## Quick smoke check

Start a test server with the built jar, wait for `Done (...)`, then:

1. Run `plugins` and confirm your plugins load.
2. Run `/loom tps` and `/loom compatibility` (add `json` when debugging plugin routing).
3. Exercise real plugin paths: commands, GUIs, placeholders, teleports, joins, disconnects, and moving around to load chunks.
4. Stop the server cleanly.

Any owner-domain violation, async access error, or repeated fallback for an ordinary plugin should be understood before you trust the build.

## Performance tuning

Loom ticks worlds, chunks, and entities in parallel, so it benefits from hardware and JVM settings that a serial server would waste.

- **Region threads.** The parallel pool defaults to half the CPU cores (`-Dpaper.threadedregions.parallelScheduler.threads=N`). On a dedicated machine with 12 or more cores, setting it to `cores - 2` gives the tick pool more width on entity-heavy loads. Leave the default on shared hosts or small machines.
- **Garbage collection.** Use the widely adopted tuned G1 flag set ("Aikar's flags") and give the heap room to breathe; an undersized heap makes G1's concurrent work compete with tick threads for CPU. In our testing the tuned flags mainly reduce tail latency (p99 tick spikes) rather than the average.
- **Memory sizing.** Leave 2-3 GB for the JVM's native overhead and the OS beyond `-Xmx`. A pre-touched fixed heap (`-Xms` = `-Xmx` with `-XX:+AlwaysPreTouch`) avoids growth stalls, but only when the machine actually has the memory.
- `/loom tps` shows CPU cores in use next to MSPT, which tells you whether you are compute-bound (add cores or reduce load) or have headroom.

## Learn how it works

Start with [docs/README.md](docs/README.md). A good reading order:

1. [Getting Started](docs/getting-started.md)
2. [Architecture Overview](docs/architecture-overview.md)
3. [Runtime Ownership Model](docs/runtime-ownership-model.md)
4. [Compatibility Kernel](docs/compatibility-kernel.md)
5. [Performance and Tuning](docs/performance.md)
6. [Patch and Release Workflow](docs/patch-and-release-workflow.md)
7. [FAQ](docs/faq.md)

## What Loom does not promise

- That every plugin works 100%.
- That unsafe access to the server from async threads is always made safe.
- That performance wins are kept if they come at the cost of plugin compatibility or safety.

## License

Loom is a fork of [Paper](https://papermc.io) and is licensed under the **GNU General Public License v3.0**. See [LICENSE](LICENSE).
