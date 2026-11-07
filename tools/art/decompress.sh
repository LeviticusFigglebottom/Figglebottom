#!/usr/bin/env bash
# Decompress a Tripo GLB (EXT_meshopt_compression) so Blender can import it.
# usage: tools/art/decompress.sh in.glb [out.glb]   (default out: <in>_dec.glb)
set -euo pipefail
in="$1"; out="${2:-${1%.glb}_dec.glb}"
npx -y @gltf-transform/cli@4 copy "$in" "$out" >/dev/null
echo "$out"
