#!/usr/bin/env bash
# The per-weapon review (ADR 0014): for every weapon, contact sheets of its
# lights, heavy, sprint strike, guard and carry on the Bearer, 1280x720, as
# docs/screens/weapon_<kit>_<clip>_sheet.png. The bow gets its draw, hold and
# loose. Usage:  tools/anim/weapon_sheets.sh [kit ...]   (default: all)
# Also: tools/anim/weapon_sheets.sh --rack   (every weapon mesh stood on its
# grip, flat and edge-on: docs/screens/weapon_rack.png)
set -euo pipefail
cd "$(dirname "$0")/../.."
run() {
  timeout 1200 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . \
    --rendering-driver vulkan --resolution 1280x720 -- --sandbox=pose_sheet "$@" 2>&1 \
    | grep -E "\[shot\]|SCRIPT ERROR|Parse Error" || true
}
if [ "${1:-}" = "--rack" ]; then
  L=""
  for k in hewing_blade feast_cleaver torch greatblade post_maul turf_spade hedging_bill spear ice_auger sealer_harpoon bow arrow quiver; do
    L="$L,res://assets/models/weapons/$k.glb"
  done
  run "--pose-rack=${L#,}" --pose-out=docs/screens
  exit 0
fi
KITS=("$@")
[ ${#KITS[@]} -eq 0 ] && KITS=(hewing_blade feast_cleaver torch greatblade maul turf_spade hedging_bill spear ice_auger sealer_harpoon bow)
BATCH=""
for k in "${KITS[@]}"; do
  case "$k" in
    bow) CLIPS="bow_draw bow_hold bow_loose idle walk" ;;
    maul|turf_spade|hedging_bill) CLIPS="attack_l1 attack_h attack_sprint block idle walk" ;;   # one light in the moveset
    *) CLIPS="attack_l1 attack_l2 attack_h attack_sprint block idle walk" ;;
  esac
  for c in $CLIPS; do BATCH="$BATCH,$c@$k"; done
done
# side-on enough that a thrust shows its reach and a cut its arc
run --pose-rig=bearer_traveller "--pose-batch=${BATCH#,}" --pose-prefix=weapon --pose-yaw=120 --pose-out=docs/screens
