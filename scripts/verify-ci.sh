#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd -- "$repo_root"

workers="${LOOM_BUILD_WORKERS:-2}"
paper_ref="$(sed -n 's/^paperRef=//p' gradle.properties)"
baseline_dir="${PAPER_ABI_BASELINE_DIR:-$(git config --path --get loom.ciBaselineDir || true)}"
baseline_dir="${baseline_dir:-$repo_root/.gradle/loom-ci/paper-abi-baseline}"
if ! [[ "$workers" =~ ^[1-9][0-9]*$ && "$paper_ref" =~ ^[0-9a-f]{40}$ ]]; then
  echo "Expected a positive LOOM_BUILD_WORKERS value and a full paperRef commit." >&2
  exit 1
fi

./gradlew applyAllPatches --stacktrace --no-daemon --max-workers="$workers"

if [[ ! -d "$baseline_dir/.git" ]]; then
  mkdir -p -- "$(dirname -- "$baseline_dir")"
  git clone --shared .gradle/caches/paperweight/upstreams/paper "$baseline_dir"
fi
if [[ "$(git -C "$baseline_dir" rev-parse HEAD)" != "$paper_ref" ]]; then
  echo "The Paper ABI baseline does not match paperRef. Select a matching PAPER_ABI_BASELINE_DIR." >&2
  exit 1
fi

(
  cd -- "$baseline_dir"
  unset BUILD_NUMBER BUILD_STARTED_AT LOOM_VERSION
  bash ./gradlew :paper-server:applyPatches --stacktrace --no-daemon --max-workers="$workers"
  bash ./gradlew :paper-api:jar :paper-server:jar --stacktrace --no-daemon --max-workers="$workers"
)

./gradlew build :loom-server:createPaperclipJar \
  -PpaperAbiBaselineDir="$baseline_dir" --stacktrace --no-daemon --max-workers="$workers"
