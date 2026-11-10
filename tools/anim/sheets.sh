#!/usr/bin/env bash
# Contact sheets for the combat clips: 8 frames across each swing, 1280x720,
# into docs/screens/anim_<set>_<clip>_sheet.png. Usage:
#   tools/anim/sheets.sh attack_l1@hewing_blade attack_h@greatblade ...
#   POSE_ARGS="--pose-whole --pose-out=/tmp/x" tools/anim/sheets.sh src_roll
set -euo pipefail
cd "$(dirname "$0")/../.."
BATCH=$(IFS=,; echo "$*")
timeout 900 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . \
  --rendering-driver vulkan --resolution 1280x720 \
  -- --sandbox=pose_sheet --pose-rig=bearer_traveller "--pose-batch=$BATCH" ${POSE_ARGS:-} 2>&1 \
  | grep -E "\[shot\]|ERROR|SCRIPT ERROR|Parse Error" || true
