## Summary

Describe the change in 1-3 sentences.

## Motivation

Why is this change needed?

## Scope

- [ ] runtime ownership behavior
- [ ] compatibility kernel behavior
- [ ] patch workflow/build tooling
- [ ] documentation only

## Validation

List what you ran and the result.

- [ ] `./gradlew applyAllPatches`
- [ ] `./gradlew :loom-server:compileJava`
- [ ] `./gradlew :loom-server:build`

## Risk Notes

Call out ownership, synchronization, or compatibility risks introduced by this PR.
