# Patch and Release Workflow

Loom uses a Paper-style patch workflow. This page explains how to change code without losing the actual source of truth.

## Source of Truth

Authoritative patch directories:

- `loom-server/minecraft-patches/`
- `loom-server/paper-patches/`

Generated worktrees:

- `paper-server/`
- `paper-api/`
- other generated Paper/Paperweight workspaces

The generated trees are where code is convenient to inspect and edit, but patch files are what preserve the changes.

## Standard Development Loop

Apply patches:

```bash
./patch.sh
```

Edit generated source as needed.

Rebuild patch files:

```bash
./rb.sh
```

Run validation gates:

```bash
./gradlew applyAllPatches
./gradlew :loom-server:compileJava
./gradlew build
```

If `applyAllPatches` fails from a clean state, patch integrity is broken.

## What To Edit

For runtime changes, inspect and edit generated sources first because they are easier to reason about:

- `loom-server/src/minecraft/java/...`
- `paper-server/src/main/java/...`

Then rebuild patches with `./rb.sh`.

For documentation, edit the docs directly:

- `README.md`
- `docs/*.md`

Documentation changes do not require patch rebuilding unless they are inside a patch-managed generated tree.

## Safety Rules For Runtime Changes

Do not weaken these for convenience:

- owner-domain checks
- `AsyncCatcher`
- region lease validation
- blocking wait barriers
- compatibility refusal behavior
- plugin diagnostics

If a path fails because it is unsafe, fix the routing. Do not silence the failure.

## Compatibility Rules

Loom has one runtime path. Do not add back runtime modes named `compatibility`, `balanced`, or `performance`.

The compatibility kernel is part of Loom by default. Performance changes must preserve broad Paper/Bukkit compatibility.

When changing plugin-facing behavior, explain:

- which plugin behavior changed
- whether the path is sync, async, event, command, packet, scheduler, or internal
- which owner domain is required
- whether the compatibility apartment, transaction, sync bridge, or refusal behavior changed
- what diagnostics should show

## Performance Change Checklist

Before accepting a performance patch:

- verify tick health on a live server with a representative plugin pack (`/loom tps`)
- confirm no regression in join/command/teleport reliability
- inspect `/loom compatibility`
- inspect strict fallback/refusal changes
- inspect async violation changes
- confirm no safety checks were weakened

Validate on a live server under a realistic workload before and after the change,
and keep the runtime stable across the full runbook below.

## Runtime Verification Runbook

After building and replacing runtime jars:

1. Start server and wait for `Done (...)`.
2. Run `plugins`.
3. Run `/loom tps`.
4. Run `/loom compatibility`.
5. Run `/loom compatibility json` for deeper routing evidence.
6. Exercise plugin paths: commands, GUI/menu actions, placeholders, teleports, join/disconnect, chunk movement.
7. Confirm no unexpected owner-domain violations, async violations, strict fallback explosions, or refusals.
8. Stop server cleanly.

## Evidence Checklist

Capture:

- branch and commit SHA
- exact commands run
- Java version
- server jar paths
- plugin pack
- runtime settings
- pass/fail status per command
- logs for startup, plugin commands, compatibility diagnostics, and shutdown

## Contributor Hygiene

- keep patches focused
- avoid unrelated refactors
- preserve generated-source and patch consistency
- include tests when behavior changes
- include diagnostics when changing compatibility behavior
- treat performance changes without reliability evidence as incomplete
