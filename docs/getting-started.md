# Getting started

This is the shortest safe path from a release jar to a useful test.

## 1. Pick the right jar

Use the Loom release built for the exact Minecraft version you are running. Keep your existing world, plugins, and normal server files, but make a backup before replacing a production jar.

Loom needs Java 25 or newer:

```bash
java -version
```

If the reported version is older, install Java 25 before launching the server.

## 2. Start with an explicit heap

This is a reasonable first command for a machine that can spare 4 GB to the JVM:

```bash
java -Xms4G -Xmx4G -XX:+UseG1GC -jar loom-vX.Y.Z-mcX.Y.Z.jar nogui
```

Do not copy the heap value blindly. Leave memory available for the operating system and native Java allocations. See [Performance](performance.md) before changing thread settings.

## 3. Check the running server

Wait for the startup message that begins with `Done`. Then run:

```text
/loom tps
/loom compatibility
```

The first command gives a quick view of tick health. The second identifies plugin callbacks, owner-domain handoffs, fallback work, and refused paths. Use `/loom compatibility json` when you need to compare runs or attach evidence to a bug report.

## 4. Perform a real smoke test

Test the behaviour your players use, not only the console:

1. Join with more than one player.
2. Move through unexplored terrain and use portals.
3. Break and place blocks, use inventories, and run plugin commands.
4. Test death, beds, respawn, and dimension changes.
5. Stop the server cleanly and inspect the final log.

Treat repeated `Owner-domain violation`, `Asynchronous`, blocking-wait, or refusal messages as an investigation item. A successful startup does not prove a plugin path is safe.

## Build a jar locally

Use this when you are working from source rather than a release:

```bash
./patch.sh
./gradlew :loom-server:compileJava --no-daemon
./gradlew :loom-server:createPaperclipJar --no-daemon
```

Before publishing the result, confirm the patch source can be applied again:

```bash
./gradlew applyAllPatches --no-daemon
./gradlew :loom-server:compileJava --no-daemon
```

## What the diagnostics mean

| Signal | What to check |
| --- | --- |
| High callback time | The plugin's own listener work may be expensive. |
| High owner handoff or barrier time | The plugin is forcing work to wait for another owner domain. |
| Repeated async violations | The plugin is touching Bukkit or world state from async work. |
| Repeated fallback work | A plugin path needs extra serialization or routing. |
| Refusal | Loom could not execute the path without breaking its safety rules. |

For the full explanation, read [Compatibility diagnostics](compatibility-kernel.md).
