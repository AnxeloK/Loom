# Contributing to Loom

Loom changes Paper's runtime, so a small code change can affect thread ownership, plugin behaviour, or patch reproducibility. Keep changes narrow and explain the runtime contract they preserve.

## Before editing

- Use Java 25.
- Read [runtime ownership](docs/runtime-ownership-model.md) and [the patch workflow](docs/patch-and-release-workflow.md).
- Start from a clean generated tree or run `./patch.sh` before editing generated source.

## Where changes belong

The patch directories are the source of truth:

- `loom-server/minecraft-patches/`
- `loom-server/paper-patches/`

Edit generated source when working on the runtime, then rebuild the matching patches. Minecraft internals live under `loom-server/src/minecraft/java`. Paper internals live under `paper-server/src/main/java`.

## Required checks

For a runtime change, run:

```bash
./gradlew applyAllPatches --no-daemon
./gradlew :loom-server:compileJava --no-daemon
```

Run focused tests for the behaviour you changed. Use a live smoke test only after the code compiles. Test joins, commands, plugins, dimension changes, respawn, chunk movement, and a clean shutdown when the change affects those paths.

## Runtime rules

- Do not weaken owner-domain checks, `AsyncCatcher`, or thread checks to silence an error.
- Do not add a blocking wait to an owner-domain path.
- Load and generate chunks asynchronously, then continue inside the destination owner domain.
- Preserve vanilla behaviour. Move work to the correct owner rather than removing it or adding a plugin-specific exception.
- Keep plugin-facing APIs compatible with Paper where that is safe.

## Commits and patches

Keep each commit focused and buildable. Rebuild patches after changing generated source, inspect the resulting patch diff, and include tests with behavioural changes. Push validated commits promptly so the branch and release history stay usable.

Do not include private server details, credentials, benchmark results, or unrelated generated files.
