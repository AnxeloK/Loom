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

## What gets a release

Publish a release for every supported Minecraft line affected by a runtime change. A new Minecraft version has different upstream code, mappings, and packaging, so one jar does not cover all `26.x` versions.

For example, if a fix applies to all maintained branches, port it to each branch, validate each build, and publish one jar and tag per line. Use a tag in this form:

```text
v<loom-version>-mc<minecraft-version>
```

Examples:

```text
v2.0.7-mc26.1.1
v2.0.7-mc26.1.2
v2.0.7-mc26.2
```

If a change is only documentation, no new server jar is required. If a runtime change affects only one version line, release only that line.

## Release checklist

1. Apply the change to the relevant version branch.
2. Rebuild patches and verify the generated trees are clean.
3. Run `applyAllPatches`, compile, focused tests, and a smoke test appropriate to the change.
4. Commit the complete patch and test change, then push the branch.
5. Create and push the version tag.
6. Wait for the tag workflow to build and upload the release jar.
7. Download the uploaded jar, verify its version and checksum, then publish concise release notes.

The release workflow is triggered by `v*` tags. It packages the paperclip jar and attaches it to the matching GitHub release.

## Keep branches aligned

Treat every maintained Minecraft branch as its own release line. Port common runtime fixes deliberately rather than assuming a cherry-pick is safe. Resolve source differences, rebuild that branch's patches, and run the checks on that branch.

Keep a release matrix in the release notes or project tracker with:

- Minecraft version
- branch
- Loom tag
- commit SHA
- jar filename and checksum
- validation status

This prevents a published tag from pointing at a jar that was only tested on another Minecraft version.
