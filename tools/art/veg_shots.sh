#!/usr/bin/env bash
# The region plants at eye height, HUD off, THAW and RIME from one camera
# each: docs/screens/veg_<region>_{thaw,rime}.png (1280x720).
#   tools/art/veg_shots.sh [region-filter]
set -uo pipefail
cd "$(dirname "$0")/../.."
FILTER="${1:-}"
shot() {  # region area cam
  case "$1" in *"$FILTER"*) ;; *) return ;; esac
  for st in thaw rime; do
    SHOT_RES=1280x720 SHOT_TIMEOUT=900 tools/shot.sh "docs/screens/veg_$1_$st.png" "--area=$2" "--state=$st" "--shot-cam=$3" --shot-nohud
  done
}
shot thornwold thornwold 369.3,38.1,-311.7,-166.0,-6.0,70
shot saltfell saltfell_steading -30.0,23.8,18.0,150.0,-8.0,70
shot lowe lowe_barrows -6.0,46.7,-190.0,90.0,-8.0,70
shot kettle kettle_fjord -92.0,3.2,-311.0,-55.0,-10.0,70
shot tarnhall tarnhall 130.0,25.7,-337.0,-75.0,-8.0,70
shot reach shepherds_reach 640.0,74.1,-360.0,-56.0,-8.0,70
shot coldwell coldwell 914.0,158.6,-472.0,-53.0,-10.0,70
