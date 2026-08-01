# Patch and release workflow

The default `ver/<minecraft-minor>.x` branch is the source of truth for the latest stable Minecraft line. Older releases and their frozen minor-line branches remain available, but routine fixes, builds, and releases target only the default branch.

The exact Minecraft version comes from `mcVersion` in `gradle.properties`. When a new stable line arrives, create its `ver/<new-minor>.x` branch and make it the repository default. Do not keep a separate branch for an exact patch version.

## Development loop

The authoritative changes are stored in `loom-server/minecraft-patches/` and `loom-server/paper-patches/`. Generated source is edited locally and then rebuilt into those patches.

```bash
./patch.sh
# edit generated source
./rb.sh
./gradlew applyAllPatches --no-daemon
./gradlew :loom-server:compileJava --no-daemon
```

Use the targeted rebuild task while iterating. Before committing, confirm that regenerated source is clean and inspect the resulting patch diff.

## Release layout

Each Loom release contains one server jar for the Minecraft version on the default branch:

```text
Loom X.Y.Z
  loom-X.Y.Z-mcM.N.P.jar
  SHA256SUMS
```

Use one SemVer tag, `v<loom-version>`. Do not create per-Minecraft source tags or rebuild frozen branches for a current release.

Normal batches of runtime improvements use a minor version. Reserve patch versions for urgent regressions, security fixes, or explicitly requested backports. Use a major version for intentional breaking changes.

## Release checklist

1. Finish the release batch on the default version branch and rebuild its patches.
2. Run `applyAllPatches`, compilation, focused tests, and an appropriate live smoke test.
3. Add concise notes at `docs/releases/v<loom-version>.md`.
4. Commit and push the validated source and notes to the default version branch.
5. Tag that commit as `v<loom-version>` and push the tag.
6. Let `Publish Release` build and upload the single jar and `SHA256SUMS`.
7. Download the published jar, verify its checksum, and confirm that it starts on the stated Minecraft version.

The workflow rejects malformed version tags, tags outside the default branch, missing notes, invalid `mcVersion` values, and ambiguous paperclip output.
