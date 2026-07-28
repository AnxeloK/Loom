# Compatibility diagnostics

Loom uses a compatibility layer to route plugin work without dropping owner-domain safety. It is automatic. Operators use its output to understand a plugin path, not to choose a server setting.

## Commands

```text
/loom compatibility
/loom compatibility json
/loom tps
```

Use the normal output while investigating a server. Use JSON when you need to compare captures, attach evidence to an issue, or retain structured diagnostics.

## What Loom records

| Signal | Interpretation |
| --- | --- |
| Callback time | Time spent running a plugin's listener code. |
| Owner handoff time | Time spent waiting for work to reach the owner domain that can run it. |
| Barrier time | Time spent in an eligible compatibility bridge. |
| Ordered or transaction work | Events that need ordering, cancellation, or mutation tracking. |
| Async violations | Bukkit or world access attempted from an unsafe async path. |
| Fallback work | A path that needs extra serialization or a stricter route. |
| Refusals | A path Loom cannot safely execute. |
| Hot events | The event names consuming the most callback time. |

High callback time usually points to plugin work. High handoff or barrier time points to cross-owner coordination. Repeated async violations or refusals point to a plugin behaviour that needs investigation.

## How event callbacks are handled

For an event, Loom inspects listener ordering, cancellation behaviour, observer listeners, and known plugin risk. It then chooses one of these actions:

- run the callback directly when it is already safe
- serialize the callback through that plugin's apartment
- use an ordered transaction when event semantics require it
- route a degraded path through a stricter fallback
- refuse the path when running it would violate ownership or blocking rules

The plugin apartment prevents callbacks for one plugin from racing each other when Loom cannot prove concurrent access is safe. It is not a global server lock.

## What to do when you see a problem

1. Record the plugin name, event name, and diagnostic counters.
2. Reproduce the action with a profile or JFR capture running.
3. Check the server log for the first owner-domain or async error around the same time.
4. Determine whether the plugin is doing expensive work, unsafe async access, or a blocking wait.
5. Fix the routing or the plugin behaviour. Do not suppress the diagnostic by weakening ownership checks.

## Notes for plugin authors

The safest plugin design is still simple:

- use synchronous Bukkit APIs for live world and player state
- keep async tasks limited to data fetching and computation
- return to the server thread or the relevant owner route before changing game state
- avoid blocking a server callback for a result that needs the server to progress
- avoid reflection and internals unless the plugin has a maintained version-specific path

## Source map

The implementation is under:

```text
paper-server/src/main/java/io/papermc/paper/plugin/manager/compat/
```

`CompatibilityKernel` selects a route, `PluginCompatibilityProfile` records history and costs, `CompatibilityApartment` serializes legacy callbacks, and `CompatibilityDiagnostics` produces the command output.
