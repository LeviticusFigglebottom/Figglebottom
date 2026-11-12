#!/usr/bin/env bash
# Each card of the opening, held and captured from the intro's own camera
# (docs/screens/intro_NN_<id>.png, 1280x720).
# Usage: tools/qa/intro_shots.sh [SHOTS_DIR]
set -uo pipefail
cd "$(dirname "$0")/../.."
SHOTS="${1:-docs/screens}"
mkdir -p "$SHOTS"
timeout 3000 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . \
  --rendering-driver vulkan --resolution 1280x720 \
  -- --test=intro "--intro-shots=$(realpath "$SHOTS")" 2>&1 \
  | grep --line-buffered -vE "ALSA|snd_|libpulse|dummy driver|edge error|rasteriz|Consider |toggled under|nav_map_builder|logical error|^\s*$"
exit "${PIPESTATUS[0]}"
