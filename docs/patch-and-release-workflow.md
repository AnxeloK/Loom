# Patch and release workflow

This page is the operating procedure for changing Loom and publishing a usable jar.

## Source of truth

The authoritative changes are patch files:

- `loom-server/minecraft-patches/`
- `loom-server/paper-patches/`

Generated directories such as `loom-server/src/minecraft/java` and `paper-server/` are where runtime code is edited. Rebuild the matching patches after an edit so a clean checkout can reproduce the same source tree.

## Normal development loop

```bash
./patch.sh
# edit generated source
./rb.sh
./gradlew applyAllPatches --no-daemon
./gradlew :loom-server:compileJava --no-daemon
```

`./rb.sh` rebuilds both Minecraft and Paper-server patches. When iterating on one area, use the matching targeted task instead: `:loom-server:rebuildMinecraftPatches` for generated Minecraft source or `:loom-server:rebuildPaperServerPatches` for Paper server source. Inspect the patch diff before committing. Generated source must be clean after the rebuild.

## Release layout

Publish one GitHub release for each Loom version. That release contains a separate jar for every supported Minecraft version:

```text
Loom 2.0.7
  loom-2.0.7-mc26.1.1.jar
  loom-2.0.7-mc26.1.2.jar
  loom-2.0.7-mc26.2.jar
  SHA256SUMS
```

The exact supported versions are listed in `.github/release-versions.json`.

Each jar still needs its own source tag because every Minecraft version has different upstream source, mappings, patches, and packaging. Source tags use this form:

```text
v<loom-version>-mc<minecraft-version>
```

The public release uses the shorter umbrella tag:

```text
v<loom-version>
```

For example, the three `v2.0.7-mc...` source tags are assembled under the single `v2.0.7` release.

Every runtime release is a complete set. If a fix only changes one Minecraft branch, tag fresh builds for the other supported branches at the same Loom version too. Users can then treat the latest release as the full compatibility list. Documentation-only changes do not require a server release.

## Release checklist

1. Apply or port the change to every affected Minecraft branch.
2. Rebuild patches and verify the generated trees are clean.
3. Run `applyAllPatches`, compile, focused tests, and a smoke test appropriate to the change.
4. Commit the complete patch and test change, then push each branch.
5. Choose the next Loom version and add release notes at `docs/releases/v<loom-version>.md`. Summarize operator-visible changes from the final code diff.
6. Create and push one source tag for every version in `.github/release-versions.json`.
7. On `main`, update `.github/release-versions.json` if support changed. Commit and push the release notes before tagging.
8. Create and push the umbrella `v<loom-version>` tag on the prepared `main` commit.
9. Wait for the `Publish Release` workflow to build every source tag and create the single GitHub release.
10. Download the uploaded jars, compare them with `SHA256SUMS`, and confirm each jar starts on its stated Minecraft version.

For a `2.0.8` release, the tag sequence would be:

```text
v2.0.8-mc26.1.1
v2.0.8-mc26.1.2
v2.0.8-mc26.2
v2.0.8
```

Push the umbrella tag last. The release workflow refuses to publish if release notes are missing, a listed source tag does not exist, a source tag reports the wrong `mcVersion`, or a jar is missing.

## Keep branches aligned

Treat every maintained Minecraft branch as its own source line. Port common runtime fixes deliberately rather than assuming a cherry-pick is safe. Resolve source differences, rebuild that branch's patches, and run the checks on that branch.

Keep a release matrix in the release notes or project tracker with:

- Minecraft version
- branch
- source tag
- commit SHA
- jar filename and checksum
- validation status

This prevents a published tag from pointing at a jar that was only tested on another Minecraft version.
