#!/usr/bin/env bash
# Rebuild the Forest hero LODs after blender_process.py (docs/art/LOOK_PASS.md).
# Trees: <name>_far.glb at 1.5k tris / 512 px. Hedge sections are repeated
# hundreds of times, so their near mesh is cut to 3k tris first, then a 600-tri far.
#   BPY=$S/bpyenv/bin/python tools/art/forest_lods.sh
set -euo pipefail
cd "$(dirname "$0")/../.."
D=assets/models/forest
for n in tr_pine_a tr_pine_b tr_birch_a2 tr_birch_b tr_grave_pine tr_snag; do
  [ -f $D/$n.glb ] && "$BPY" tools/art/forest_lod.py -- $D/$n.glb 1500 512
done
for n in hd_laid2 hd_thorn2; do
  [ -f $D/$n.glb ] || continue
  "$BPY" tools/art/forest_lod.py -- $D/$n.glb 3000 1024
  mv $D/${n}_far.glb $D/$n.glb
  "$BPY" tools/art/forest_lod.py -- $D/$n.glb 600 512
done
