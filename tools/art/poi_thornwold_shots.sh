#!/usr/bin/env bash
# Thornwold points of interest, before/after pairs at eye height, 1280x720.
#   tools/art/poi_thornwold_shots.sh before|after [name-filter]
# Also prints the frame stats (draw calls, primitives) for each camera; the
# hedge_veil camera is the look-pass-5 budget view.
set -uo pipefail
cd "$(dirname "$0")/../.."
WHICH="${1:-after}"; FILTER="${2:-}"
shot() {  # name area state cam [extra]
  case "$1" in *"$FILTER"*) ;; *) return ;; esac
  local n="$1" a="$2" s="$3" c="$4"; shift 4
  SHOT_RES=1280x720 tools/shot.sh "docs/screens/poi_thornwold_${n}_${WHICH}.png" "--area=$a" "--state=$s" "--shot-cam=$c" "$@"
}
shot tw_the_notch thornwold thaw 302.6,35.2,-318.8,-100.0,-3.0,70
shot tw_the_notch_rime thornwold rime 302.6,35.2,-318.8,-100.0,-3.0,70
shot tw_linnets_hut thornwold rime 338.6,36.1,-299.6,155.0,-5.0,70
shot tw_linnets_hut_thaw thornwold thaw 338.6,36.1,-299.6,155.0,-5.0,70
shot tw_gate_field thornwold rime 369.3,38.1,-311.7,-166.0,-6.0,70
shot tw_gate_field_thaw thornwold thaw 369.3,38.1,-311.7,-166.0,-6.0,70
shot tw_layers_stiles thornwold rime 433.2,39.3,-298.2,-35.0,-4.0,70
shot tw_layers_stiles_thaw thornwold thaw 433.2,39.3,-298.2,-35.0,-4.0,70
# the look-pass-5 budget camera (stats only matter here)
shot hedge_veil_budget thornwold rime 440.0,39.4,-325.0,78.9,-4.0,70 --shot-nohud
