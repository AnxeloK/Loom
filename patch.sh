#!/usr/bin/env bash
set -euo pipefail

./gradlew --no-daemon applyAllPatches "$@"
