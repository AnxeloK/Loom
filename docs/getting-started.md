# Getting Started

This page is the practical entry point. It explains how to build Loom, run the basic checks, and inspect the runtime once it starts.

## Prerequisites

- Java `25` — a Java 25 JDK to build, and a Java 25 JRE to run the server
- Bash or a compatible shell for `patch.sh` and `rb.sh`
- The Gradle wrapper from this repository
- Enough memory for a Paper-style server build

The repository uses a patch workflow. The patch directories are the source of truth:

- `loom-server/minecraft-patches/`
- `loom-server/paper-patches/`

Generated trees such as `paper-server/` and `paper-api/` are worktrees produced from those patches.

## Build From Source

Apply patches:

```bash
./patch.sh
```

Build the Loom server:

```bash
./gradlew :loom-server:build
```

Run the required validation gates before treating the build as releasable:

```bash
./gradlew applyAllPatches
./gradlew :loom-server:compileJava
./gradlew build
```

`applyAllPatches` is important. If patches cannot apply from a clean state, the generated tree and the patch source of truth have drifted.

## First Runtime Check

Start a test server with the built jar — launch it on Java 25 with a real heap and garbage collector (see [Performance and Tuning](performance.md)), not a bare `-jar`. Wait for:

```text
Done (...)
```

Then run:

```text
plugins
/loom tps
/loom compatibility
```

When debugging plugin routing, also run:

```text
/loom compatibility json
```

The human-readable command is good for a quick read. The JSON command is better for comparing runs or feeding diagnostics into tooling.

## What A Clean Smoke Test Looks Like

A minimal smoke pass should show:

- server reaches `Done (...)`
- expected plugins load
- commands execute
- `/loom tps` responds
- `/loom compatibility` responds
- no unexpected `Owner-domain violation`
- no unexpected `Asynchronous ...` errors
- no repeated strict fallback or refusal for ordinary plugin paths
- clean shutdown

Some diagnostics are not automatically failures. For example, a plugin may be escalated because it uses protocol or reflection-heavy internals. That may be expected for a protocol plugin. The rule is to understand the reason before accepting the run.

## How To Read Compatibility Output

Important fields:

- `mode`: internal plugin compatibility classification.
- `callback`: total time spent in that plugin's callbacks.
- `ownerRpc`: time spent waiting for owner-routed compatibility work.
- `barrier`: time spent in sync-bridge waits.
- `ordered`: ordered/cancellable event transactions.
- `monitor`: attempts to mutate from `MONITOR` event priority.
- `async`: async Bukkit access violations.
- `strictFallbacks`: paths forced into stricter compatibility handling.
- `refusals`: paths Loom refused to execute for safety.
- `lanes`: which compatibility lanes were used.
- `hotEvents`: event names consuming the most callback time.

High `callback` means the plugin itself is expensive. High `ownerRpc` or `barrier` means the plugin is leaning on compatibility waits. High `async`, `strictFallbacks`, or `refusals` means the plugin is doing something Loom considers risky.

## Basic Runtime Vocabulary

- **Owner domain:** the execution context allowed to touch a target state.
- **Global owner:** lifecycle/global server state.
- **Region owner:** chunk, block, entity, and world state for a chunk range.
- **Player owner:** player-scoped mutable state.
- **Compatibility apartment:** per-plugin serialization guard for legacy callbacks.
- **Compatibility transaction:** event dispatch record that tracks ordering, cancellation, monitor mutation, and overlays.
- **Strict fallback:** safer but slower compatibility path.
- **Refusal:** a path Loom will not execute because it cannot be made safe.

## Next Reading

Read [Architecture Overview](architecture-overview.md) next. It explains why these checks exist and how the pieces fit together.
