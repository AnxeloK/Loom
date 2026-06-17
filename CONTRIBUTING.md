# Contributing to Loom

## Development Requirements

- Java toolchain `25`
- Gradle wrapper from this repository

## Read Before You Change Code

- [Getting Started](docs/getting-started.md)
- [Runtime Ownership Model](docs/runtime-ownership-model.md)
- [Patch and Release Workflow](docs/patch-and-release-workflow.md)

## Source of Truth

Patch files are authoritative:

- `loom-server/minecraft-patches/`
- `loom-server/paper-patches/`

Generated trees (`paper-server`, `paper-api`) are intermediate workspaces.

## Required Workflow

1. apply patches:

```bash
./patch.sh
```

2. make code changes in generated source where required
3. rebuild patch files:

```bash
./rb.sh
```

4. run validation gates:

```bash
./gradlew applyAllPatches
./gradlew :loom-server:compileJava
./gradlew build
```

If `applyAllPatches` fails from clean state, patch integrity is considered broken.

## Pull Request Expectations

- keep changes focused and atomic
- include rationale for ownership/compatibility behavior changes
- include tests for behavior changes when feasible
- do not commit generated-source drift without matching patch updates
- keep commit messages descriptive and specific
- do not commit personal/private documentation

## Safety Expectations

- do not weaken ownership checks (`AsyncCatcher`, owner-domain rules, thread-safety checks) for convenience
- do not introduce blocking waits on owner-domain runtime paths
- prefer continuation/handoff semantics for cross-domain work
