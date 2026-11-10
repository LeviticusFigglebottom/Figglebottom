#!/usr/bin/env bash
# Contact sheets for foe attacks: docs/screens/anim_foe_<id>_<attack>_sheet.png
#   tools/anim/foe_sheets.sh rimewalker@swipe oarsman@stroke@100 ...
#   tools/anim/foe_sheets.sh --all        (every clip in the foe clip sets, and the quadrupeds' poses)
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
        # "@<attack>" clips, then the beats answered by game clip name
        # (stagger, death, a Holdfast's intro, hold and release beats)
        for a in cs:
            item = f"{foe}@{a[1:] if a.startswith('@') else a}"
            if item not in out:
                out.append(item)
for q in ("hearthhound", "sledge_dog", "rime_stag"):
    out.append(f"{q}@poses")
print(" ".join(out))
PY
)
fi
BATCH=$(IFS=,; echo "$*")
timeout 900 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . \
  --rendering-driver vulkan --resolution 1280x720 \
  -- --sandbox=pose_sheet --pose-rig=foe "--pose-batch=$BATCH" ${POSE_ARGS:-} 2>&1 \
  | grep -E "\[shot\]|ERROR|SCRIPT ERROR|Parse Error" || true
