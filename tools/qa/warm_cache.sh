#!/usr/bin/env bash
# Fill the area-streaming cache for every area (terrain arrays, ground cover,
# a new journey's navmeshes), so a first visit computes nothing at a seam.
# docs/qa/STREAMING.md "Warming the cache"; the tool is tools/qa/warm_cache.gd.
# Usage: tools/qa/warm_cache.sh [--cache-dir=PATH] [--warm-areas=a,b] [--warm-no-nav]
#   GODOT=/path/to/binary tools/qa/warm_cache.sh ...   (default: godot on PATH)
set -uo pipefail
cd "$(dirname "$0")/../.."
"${GODOT:-godot}" --headless --path . -- --scene=res://tools/qa/warm_cache.tscn "$@" 2>&1 \
  | grep -vE 'ALSA|snd_|libpulse|dummy driver|^\s*$'
exit "${PIPESTATUS[0]}"
