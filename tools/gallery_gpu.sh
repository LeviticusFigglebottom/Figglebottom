#!/usr/bin/env bash
# Real-GPU gallery: every area viewpoint in docs/screens, in both states, on
# real hardware at quality 2 (Forward+, with SDFGI / SSIL / SSR / volumetric fog).
# The cameras were read back from the pose line each lavapipe shot prints
# (src/ui/hud.gd), so the framings match docs/screens.
# One Godot process per shot, so every view starts converged instead of
# inheriting the last view's GI.
#   GODOT=path/to/godot tools/gallery_gpu.sh [name-filter]
# Lossless PNGs go to $PNG (default build/gallery_gpu/), JPEG copies (q92) to
# $JPG (default docs/gallery_gpu/).
# Same-revision lavapipe pairs from the identical cameras (cloud sessions):
# Other manifests: VIEWS_FILE=path (same line format), e.g. the v2 gallery:
#   python3 tools/gallery_v2_views.py > build/v2.txt
#   VIEWS_FILE=build/v2.txt JPG=docs/gallery_gpu/v2 EXTRA=--shot-nohud tools/gallery_gpu.sh
#   WRAP='xvfb-run -a -s "-screen 0 1920x1080x24"' PNG=build/gallery_lvp \
#     JPG=build/gallery_lvp tools/gallery_gpu.sh
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
FILTER="${1:-}"
PNG="${PNG:-$PWD/build/gallery_gpu}"
JPG="${JPG:-docs/gallery_gpu}"
mkdir -p "$PNG" "$JPG"
cmd=(timeout 900)
if [ -n "${WRAP:-}" ]; then eval "cmd+=($WRAP)"; fi
# name area camera (x,y,z,yaw,pitch,fov) [extra harness args, e.g. world flags]
VIEWS="
cliff_path            saltfell_steading -82.0,28.0,62.0,-66.0,-14.0,62
longhouse_boss        saltfell_steading 0.0,24.6,-21.5,0.0,-9.0,70
ravine                saltfell_steading -30.0,27.0,-52.0,-20.0,-18.0,62
rime_channel          saltfell_steading -14.0,9.0,70.0,150.0,-14.0,60
strand                saltfell_steading -20.0,5.0,80.0,-63.0,-2.0,60
terrain_vista         saltfell_steading 26.0,30.0,-46.0,-6.0,-9.0,62
yard                  saltfell_steading -20.0,25.0,8.0,-45.0,-6.0,58
lowe_bog              lowe_barrows -62.0,47.0,-160.0,-36.0,-14.0,62
lowe_bridge           lowe_barrows -4.0,27.0,-92.0,-180.0,-10.0,62 --flag=lowe_bridge_down
lowe_fell             lowe_barrows 0.0,50.0,-205.0,0.0,8.0,62
lowe_open_barrow      lowe_barrows 46.0,47.0,-170.0,0.0,-12.0,66
lowe_pass             lowe_barrows -89.0,27.5,-96.0,30.0,-4.0,62
lowe_road             lowe_barrows -53.5,34.0,-110.5,26.6,-7.0,62
kettle_breathing_hole kettle_fjord 37.0,9.0,-305.0,52.0,-18.0,75
kettle_boat           kettle_fjord -85.0,5.0,-326.0,0.0,-45.0,75
kettle_fish_houses    kettle_fjord -64.0,4.2,-311.0,-50.0,-8.0,75
kettle_fjord_ice      kettle_fjord -118.0,12.0,-300.0,-80.0,-12.0,75
kettle_north_wall     kettle_fjord -70.0,8.0,-312.0,10.0,4.0,75
"
if [ -n "${VIEWS_FILE:-}" ]; then VIEWS="$(cat "$VIEWS_FILE")"; fi
while read -r name area cam extra; do
  [ -z "$name" ] && continue
  if [ -n "$FILTER" ] && [[ "$name" != *"$FILTER"* ]]; then continue; fi
  for state in ${STATES:-thaw rime}; do
    out="$PNG/${name}_${state}.png"
    echo "=== $name $state"
    # Quality 2 is the auto tier on a real GPU (1 on lavapipe). 2400 frames is
    # about 14 s at 165 Hz: the area title and the seam card that follows it
    # have both faded. The camera is placed 600 frames before capture, so SDFGI
    # and the fog history have settled.
    "${cmd[@]}" "$GODOT" --path . --rendering-driver vulkan --resolution 1920x1080 \
      --windowed -- "--shot=$out" "--area=$area" "--state=$state" "--shot-cam=$cam" \
      --shot-frames=2400 --shot-settle=600 ${extra:-} ${EXTRA:-} </dev/null 2>&1 \
      | grep -E "\[shot\]|SCRIPT ERROR|Parse Error" || true
  done
done <<< "$VIEWS"
python3 - "$PNG" "$JPG" <<'EOF'
import glob, os, sys
from PIL import Image
for p in sorted(glob.glob(os.path.join(sys.argv[1], "*.png"))):
    out = os.path.join(sys.argv[2], os.path.basename(p)[:-4] + ".jpg")
    Image.open(p).convert("RGB").save(out, quality=92, subsampling=0)
EOF
