# Loom Documentation

This documentation is written as study material for Loom's runtime, not just as release notes.

Loom is a Paper fork with strict owner-domain execution and a compatibility kernel for Paper/Bukkit plugins. The important idea is that Loom tries to keep the plugin-facing model close to Paper while making internal server work obey explicit ownership rules.

## How To Read This

Read in this order if you are learning Loom from zero:

1. [Getting Started](getting-started.md) - build, run, smoke-test, and inspect diagnostics.
2. [Architecture Overview](architecture-overview.md) - the full mental model and source map.
3. [Runtime Ownership Model](runtime-ownership-model.md) - owner domains, region contexts, sync waits, async calls, and failure rules.
4. [Compatibility Kernel](compatibility-kernel.md) - plugin classification, event routing, apartments, transactions, strict fallback, and refusal.
5. [Performance and Tuning](performance.md) - runtime performance characteristics and tuning properties.
6. [Patch and Release Workflow](patch-and-release-workflow.md) - how to change Loom without breaking the patch source of truth.
7. [FAQ](faq.md) - direct answers to common confusion.

## Documentation Model

The pages are separated by purpose:

- **Getting Started** is a how-to guide.
- **Architecture Overview** and **Runtime Ownership Model** are explanations.
- **Compatibility Kernel** is both explanation and reference.
- **Performance and Tuning** covers runtime characteristics and tuning properties.
- **Patch and Release Workflow** is contributor procedure.
- **FAQ** is quick reference.

## The One-Sentence Model

Loom routes mutable work into the owner domain for the state being touched, then uses a compatibility kernel to preserve Paper-style plugin behavior where that can be done without corrupting state or blocking owner-domain threads.

## What To Remember

- There is one Loom runtime path.
- The compatibility kernel is always active.
- Compatibility is not a bypass around ownership rules.
- Sync scheduler calls work like Paper and run during the server tick.
- Async scheduler calls run async, but unsafe Bukkit access may be detected and sometimes rerouted.
- Owner-domain threads are not allowed to block on sync waits.
- A performance win is only valid if plugin compatibility and owner safety remain intact.
