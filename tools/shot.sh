#!/usr/bin/env bash
# Headless screenshot wrapper. Usage:
#   [SHOT_RES=1280x720] tools/shot.sh OUT.png [extra godot user args...]
# Example:
#   tools/shot.sh docs/museum.png --sandbox=museum --shot-cam=15,20,40,0,-25
set -euo pipefail
OUT="$1"; shift
cd "$(dirname "$0")/.."
RES="${SHOT_RES:-1920x1080}"   # SHOT_RES=1280x720 tools/shot.sh ... for the docs/screens size
timeout "${SHOT_TIMEOUT:-600}" xvfb-run -a -s "-screen 0 ${RES}x24" godot --path . \
  --rendering-driver vulkan --resolution "$RES" \
  -- "--shot=$OUT" "$@" 2>&1 | grep -E "\[shot\]|ERROR|SCRIPT ERROR|Parse Error" || true
