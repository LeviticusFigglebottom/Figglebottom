#!/usr/bin/env bash
# Look pass 5 before/after pairs, from the docs/gallery_gpu/v2 cameras
# (tools/gallery_v2_views.py), 1280x720. Usage:
#   tools/art/look5_shots.sh before|after [name-filter]
set -uo pipefail
cd "$(dirname "$0")/../.."
WHICH="${1:-after}"; FILTER="${2:-}"
shot() {  # name area state cam
  case "$1" in *"$FILTER"*) ;; *) return ;; esac
  SHOT_RES=1280x720 tools/shot.sh "docs/screens/look5_${WHICH}_$1.png" "--area=$2" "--state=$3" "--shot-cam=$4" --shot-nohud
}
shot thornwold_drove_road_rime thornwold rime 318.0,35.6,-315.0,-67.7,-4.0,70
shot thornwold_hedge_veil_rime thornwold rime 440.0,39.4,-325.0,78.9,-4.0,70
shot thornwold_outer_ring_rime thornwold rime 462.1,39.3,-297.3,65.2,-4.0,70
shot saltfell_hall_veil_rime saltfell_steading rime 0.0,23.7,-20.0,159.4,-4.0,70
shot kettle_veil_rime kettle_fjord rime 22.0,1.8,-302.2,90.1,-4.0,70
shot lowe_veil_rime lowe_barrows rime 46.0,47.3,-177.5,93.5,-4.0,70
shot tarnhall_veil_rime tarnhall rime 218.0,26.0,-329.0,-89.0,-4.0,70
shot reach_fold_veil_rime shepherds_reach rime 650.8,78.5,-362.8,115.3,-4.0,70
shot coldwell_veil_rime coldwell rime 912.0,158.8,-478.0,101.1,-4.0,70
shot tarnhall_causeway_thaw tarnhall thaw 124.0,25.4,-331.0,-96.1,-4.0,70
shot tarnhall_long_table_thaw tarnhall thaw 197.0,26.0,-327.4,89.2,-4.0,70
shot saltfell_boat_shed_thaw saltfell_steading thaw 23.0,4.9,55.5,46.9,-4.0,70
shot reach_sheilings_thaw shepherds_reach thaw 604.0,69.5,-306.0,18.4,-4.0,70
shot coldwell_upwater_thaw coldwell thaw 724.2,87.7,-399.1,-57.5,-4.0,70
