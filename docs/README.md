# Loom documentation

Use the page that matches the job you are doing.

| If you need to... | Read... |
| --- | --- |
| Install a jar, start it, or run a first smoke test | [Getting started](getting-started.md) |
| Diagnose high tick time or choose thread settings | [Performance](performance.md) |
| Understand a plugin warning or `/loom compatibility` | [Compatibility diagnostics](compatibility-kernel.md) |
| Fix owner-domain errors in the runtime | [Runtime ownership](runtime-ownership-model.md) |
| Navigate the implementation | [Architecture overview](architecture-overview.md) |
| Change patches or publish a release | [Patch and release workflow](patch-and-release-workflow.md) |
| Find a short answer | [FAQ](faq.md) |

The core rule is that mutable state must be handled by the owner domain responsible for it. Compatibility routing can move or serialize work, but it never makes off-owner mutation safe.
