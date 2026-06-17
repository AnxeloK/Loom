#!/usr/bin/env bash
set -euo pipefail

./gradlew --no-daemon :loom-server:rebuildAllServerPatches "$@"
