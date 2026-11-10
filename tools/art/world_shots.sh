#!/usr/bin/env bash
# World-fidelity before/after cameras (docs/art/WORLD_FIDELITY.md).
# Usage: tools/art/world_shots.sh PREFIX [filter]
#   PREFIX  "before" or "after": files land in docs/screens/world_<PREFIX>_<name>.png
#   filter  optional grep pattern on "<area>/<state>" to render a subset
# Every camera stands at eye height (about 1.6 m over the ground). 1280x720,
# software Vulkan (lavapipe), one engine boot per area and state.
set -euo pipefail
PREFIX="$1"; FILTER="${2:-.}"
cd "$(dirname "$0")/../.."
OUT="docs/screens"

# area|state|name@x,y,z,yaw,pitch,fov;name@...
SETS=(
"saltfell_steading|thaw|yard_thaw@5,23.6,-11,25,-2,62;door_thaw@1.6,23.6,-16.6,22,-2,62;wall_thaw@-8.3,23.6,-30,-90,-2,62;longhouse_in_thaw@0,23.6,-22.5,0,-3,70;longhouse_in2_thaw@-2.5,23.6,-47,-155,-4,70;byre_thaw@-17.5,23.6,-12,80,0,62;boatshed_thaw@25,4.8,66,0,2,66"
"saltfell_steading|rime|yard_rime@5,23.6,-11,25,-2,62;wall_rime@-8.3,23.6,-30,-90,-2,62;longhouse_in_rime@0,23.6,-22.5,0,-3,70;longhouse_in2_rime@-2.5,23.6,-47,-155,-4,70"
"kettle_fjord|thaw|fishhouse_thaw@-46.5,3.7,-314.5,12,0,62;fishhouse_in_thaw@-48,3.7,-323.2,0,-4,75"
"kettle_fjord|rime|fishhouse_rime@-46.5,3.7,-314.5,12,0,62"
"tarnhall|thaw|hall_in_thaw@183.5,25.9,-330,-90,-2,70;hall_out_thaw@190,25.9,-312,-160,3,66"
"tarnhall|rime|hall_in_rime@183.5,25.9,-330,-90,-2,70"
"lowe_barrows|thaw|barrow_thaw@-56.4,33.2,-115.8,26.57,-2,62"
"lowe_barrows|rime|barrow_rime@-56.4,33.2,-115.8,26.57,-2,62"
"thornwold|thaw|clearing_thaw@334,37.3,-298,-56,-10,75"
"coldwell|thaw|wellhouse_thaw@893,176.2,-489,-128,0,62"
)

for set in "${SETS[@]}"; do
  IFS='|' read -r area state cams <<<"$set"
  echo "$area/$state" | grep -Eq "$FILTER" || continue
  multi=""
  IFS=';' read -ra list <<<"$cams"
  for c in "${list[@]}"; do
    multi+="${OUT}/world_${PREFIX}_${c%%@*}.png@${c#*@};"
  done
  timeout 1500 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . \
    --rendering-driver vulkan --resolution 1280x720 \
    -- "--area=$area" "--state=$state" --shot-nohud --shot-frames=40 "--shot-multi=${multi%;}" 2>&1 \
    | grep -E "\[shot\]|SCRIPT ERROR|Parse Error" || true
done
