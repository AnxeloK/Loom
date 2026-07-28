# Performance

Tune Loom from a representative profile, not from a thread count alone. Player spread, chunk generation, plugins, view distance, packets, and garbage collection can all become the limiting factor.

## Start with a baseline

Before changing settings, record:

- player count and the activity being tested
- view distance and simulation distance
- heap size and Java version
- `/loom tps` output
- `/loom compatibility` output
- a profiler capture or JFR recording during the problem

Repeat the same activity after each change. One change at a time makes the result interpretable.

## CPU and containers

Loom uses the processors visible to the JVM. On a dedicated host, that is usually the number of logical processors. In a container, CPU quota, cpuset limits, and the panel's allocation determine what Java sees.

Logical processors are not the same as physical cores. Simultaneous multithreading can expose two logical processors per core, but those siblings share core resources. Treat the JVM's processor count as a scheduling limit, then validate it with a profile.

## Memory and garbage collection

Set an explicit heap and leave headroom outside it. A simple starting point is:

```bash
java -Xms4G -Xmx4G -XX:+UseG1GC -jar server.jar nogui
```

Use the same `-Xms` and `-Xmx` only when the machine has enough spare memory. Increasing the heap can reduce allocation pressure, but it cannot fix CPU-bound tick work or a slow plugin.

## Thread settings

Leave automatic values in place for the first profile:

```yaml
chunk-system:
  io-threads: -1
  worker-threads: -1
```

`-1` lets the chunk system choose a value from the processors available to the JVM. Raising worker counts can improve generation throughput in some workloads, but it can also take CPU time from ticking, networking, and garbage collection. Make an override only when a profile shows the chunk worker pool is the bottleneck and the host has real CPU headroom.

The same rule applies to `paper.threadedregions.parallelScheduler.threads`. More scheduler threads do not create more physical CPU. Start from Loom's automatic choice and test changes against the same player activity.

## What to inspect first

| Symptom | Likely next check |
| --- | --- |
| Tick time rises with players in one area | Entity count, block activity, plugin callbacks, and a profiler flame graph. |
| Tick time rises when players spread out | Chunk generation, disk I/O, send queues, and worker saturation. |
| Players rubber-band or see delayed movement | Packet handling, owner-domain handoffs, network latency, and tick spikes. |
| High CPU but acceptable memory | CPU profile and runnable thread count. Do not raise the heap first. |
| Long garbage collection pauses | Heap pressure, allocation sources, native memory headroom, and JVM flags. |
| Frequent fallback or refusal diagnostics | The named plugin path. More worker threads will not fix unsafe plugin access. |

## A practical tuning loop

1. Reproduce the problem with normal players or a realistic load test.
2. Capture a profile for the same interval.
3. Identify the largest cost in the profile.
4. Change one setting or remove one source of work.
5. Repeat the capture and compare it with the baseline.

Keep profiler collection available on active servers. A profile taken while players are actually exploring, fighting, generating chunks, or using plugins is far more useful than an idle capture.
