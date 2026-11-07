#!/usr/bin/env bash
# Headless screenshot wrapper. Usage:
#   tools/shot.sh OUT.png [extra godot user args...]
# Example:
#   tools/shot.sh docs/museum.png --sandbox=museum --shot-cam=15,20,40,0,-25
set -euo pipefail
OUT="$1"; shift
cd "$(dirname "$0")/.."
timeout 600 xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . \
  --rendering-driver vulkan --resolution 1920x1080 \
  -- "--shot=$OUT" "$@" 2>&1 | grep -E "\[shot\]|ERROR|SCRIPT ERROR|Parse Error" || true
