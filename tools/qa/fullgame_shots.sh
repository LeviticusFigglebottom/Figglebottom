#!/usr/bin/env bash
# A full-game region walk with a renderer: player-camera screenshots along
# the route (docs/screens/qa_<region>_NN_<name>.png).
# Usage: tools/qa/fullgame_shots.sh <lowe|kettle|tarnhall|thornwold> [SHOTS_DIR]
set -uo pipefail
cd "$(dirname "$0")/../.."
REGION="${1:?region}"
SHOTS="${2:-docs/screens}"
mkdir -p "$SHOTS"
timeout 9000 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . \
  --rendering-driver vulkan --resolution 1280x720 \
  -- "--test=fullgame_$REGION" "--fullgame-shots=$(realpath "$SHOTS")" 2>&1 \
  | grep --line-buffered -vE "ALSA|snd_|libpulse|dummy driver|^\s*$"
exit "${PIPESTATUS[0]}"
