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
shot coldwell_upwater_rime coldwell rime 724.2,87.7,-399.1,-57.5,-4.0,70
# the veils from where the Bearer meets them (7 m out, 22 deg off the axis)
# and three from nearly edge-on; the gallery cameras stand inside the veil
shot veil_saltfell_front saltfell_steading rime 2.6,23.70,-13.5,22.0,4.0,65
shot veil_lowe_front lowe_barrows rime 48.6,47.30,-171.0,22.0,4.0,65
shot veil_kettle_front kettle_fjord rime 18.9,1.75,-296.4,-28.0,4.0,65
shot veil_kettle_side kettle_fjord rime 27.9,1.75,-300.9,78.0,4.0,65
shot veil_tarnhall_front tarnhall rime 224.5,26.00,-331.6,112.0,4.0,65
shot veil_thornwold_front thornwold rime 435.4,39.38,-322.4,-60.5,6.0,70
shot veil_thornwold_side thornwold rime 438.8,39.38,-319.1,-12.0,4.0,65
shot veil_reach_front shepherds_reach rime 648.1,78.45,-356.4,-23.0,4.0,65
shot veil_reach_side shepherds_reach rime 654.1,78.45,-357.8,33.0,4.0,65
shot veil_coldwell_front coldwell rime 905.5,158.76,-475.4,-68.0,4.0,65
# look pass 5 subjects the gallery cameras miss
shot coldwell_spring_thaw coldwell thaw 915.5,160.4,-474.5,-61.7,-24.0,60
shot coldwell_spring_rime coldwell rime 915.5,160.4,-474.5,-61.7,-24.0,60
shot saltfell_salt_house_thaw saltfell_steading thaw -26.0,23.8,23.5,-72.3,-4.0,70
shot kettle_fish_houses_thaw kettle_fjord thaw -64,4.2,-311,-50,-8,75
shot coldwell_river_dead_rime coldwell rime 757.9,97.5,-397.0,32.1,-6.0,60
