# Loom

Loom is a multithreaded Minecraft server based on [Paper](https://papermc.io).

It runs world work in parallel while keeping mutable state inside the owner domain that is responsible for it. That lets Loom use more of the machine without treating unsafe cross-thread access as normal plugin behaviour.

## Download Loom

Each entry on the [Releases](../../releases) page contains a jar for every supported Minecraft version. Download the file whose `mc` suffix matches your server exactly. For example, a file ending in `-mc26.1.2.jar` is the Minecraft 26.1.2 build.

A jar built for one Minecraft version cannot be used for another.

Loom requires Java 25 or newer. A basic launch command looks like this:

```bash
java -Xms4G -Xmx4G -XX:+UseG1GC -jar loom-X.Y.Z-mcX.Y.Z.jar nogui
```

Choose the heap size for the machine and player load. Leave enough RAM for the operating system, native memory, networking, and the server's direct buffers.

## What to expect

Ordinary Bukkit and Paper plugins should continue to use their normal APIs. Loom automatically selects the safe execution route for each operation. That can mean direct execution, a serialized plugin callback, an owner-domain handoff, or a refusal when the operation cannot be made safe.

The important boundary is simple: a thread may only mutate state that it owns. Loom does not weaken that rule to make an error disappear.

## First checks after startup

Once the server reaches `Done (...)`, check:

```text
/loom tps
/loom compatibility
```

Then exercise the real paths your server depends on: joins, teleports, commands, inventories, plugin menus, chunk movement, deaths, and dimension changes. Inspect the logs before accepting repeated owner-domain errors, async access errors, or refusals as normal.

## Documentation

- [Getting started](docs/getting-started.md) explains installation and a first smoke test.
- [Performance](docs/performance.md) explains how to profile and tune a real workload.
- [Compatibility diagnostics](docs/compatibility-kernel.md) explains `/loom compatibility`.
- [Runtime ownership](docs/runtime-ownership-model.md) explains the safety model for contributors.
- [Patch and release workflow](docs/patch-and-release-workflow.md) explains how to publish supported Minecraft versions.
- [FAQ](docs/faq.md) gives short operational answers.

## Build from source

```bash
./patch.sh
./gradlew :loom-server:compileJava --no-daemon
./gradlew :loom-server:createPaperclipJar --no-daemon
```

Before publishing a runtime change, also verify that a clean generated tree can be recreated:

```bash
./gradlew applyAllPatches --no-daemon
./gradlew :loom-server:compileJava --no-daemon
```

## License

Loom is distributed under the GNU General Public License v3.0. See [LICENSE](LICENSE).
