#!/usr/bin/env bash
# The full-slice route with a renderer: player-camera screenshots along the
# way (docs/screens/slice_*.png) and a per-leg frame-time log (PERF JSON).
# Usage: tools/qa/fullslice_shots.sh [SHOTS_DIR] [PERF_JSON]
set -uo pipefail
cd "$(dirname "$0")/../.."
SHOTS="${1:-docs/screens}"
PERF="${2:-docs/qa/perf_route.json}"
mkdir -p "$SHOTS" "$(dirname "$PERF")"
timeout 3600 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . \
  --rendering-driver vulkan --resolution 1280x720 \
  -- --test=fullslice "--fullslice-shots=$(realpath "$SHOTS")" "--perf=$(realpath -m "$PERF")" 2>&1 \
  | grep --line-buffered -vE "ALSA|snd_|libpulse|dummy driver|^\s*$"
exit "${PIPESTATUS[0]}"
