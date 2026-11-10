#!/usr/bin/env bash
# Contact sheets for foe attacks: docs/screens/anim_foe_<id>_<attack>_sheet.png
#   tools/anim/foe_sheets.sh rimewalker@swipe oarsman@stroke@100 ...
#   tools/anim/foe_sheets.sh --all        (every attack in tools/anim/foe_clips.py, plus stagger and death)
set -euo pipefail
cd "$(dirname "$0")/../.."
if [ "${1:-}" = "--all" ]; then
  set -- $(python3 - <<'PY'
import json
m = json.load(open("data/anim/clip_meta.json"))
out = []
for k, cs in m["clip_sets"].items():
    if k.startswith("foe_"):
        foe = k[4:]
        out += [f"{foe}@{a[1:]}" for a in cs if a.startswith("@")]
        if "stagger" in cs:
            out.append(f"{foe}@stagger")
        if "death" in cs:
            out.append(f"{foe}@death")
print(" ".join(out))
PY
)
fi
BATCH=$(IFS=,; echo "$*")
timeout 900 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . \
  --rendering-driver vulkan --resolution 1280x720 \
  -- --sandbox=pose_sheet --pose-rig=foe "--pose-batch=$BATCH" ${POSE_ARGS:-} 2>&1 \
  | grep -E "\[shot\]|ERROR|SCRIPT ERROR|Parse Error" || true
