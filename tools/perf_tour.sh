#!/usr/bin/env bash
# Real-GPU performance tour: every area x state x quality tier, one Godot
# process each, through src/debug/perf_tour.gd. Needs a real display + GPU
# (not lavapipe). Raw JSON goes to $OUT (gitignored build/), then:
#   python3 tools/perf_report.py build/perf/<tag>
# Env:
#   GODOT=path/to/godot   TAG=dgpu   QUALS="0 1 2"   STATES="thaw rime"
#   AREAS="saltfell_steading lowe_barrows kettle_fjord"
#   GPU_INDEX=1 (pick a second adapter)   SECS=5   CAP=120   SHOTS=1
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
TAG="${TAG:-dgpu}"
QUALS="${QUALS:-0 1 2}"
STATES="${STATES:-thaw rime}"
AREAS="${AREAS:-saltfell_steading lowe_barrows kettle_fjord}"
SECS="${SECS:-5}"
CAP="${CAP:-120}"
OUT="${OUT:-$PWD/build/perf/$TAG}"
mkdir -p "$OUT"
gpu=()
[ -n "${GPU_INDEX:-}" ] && gpu=(--gpu-index "$GPU_INDEX")
for area in $AREAS; do
  for state in $STATES; do
    for q in $QUALS; do
      shots=()
      [ "${SHOTS:-1}" = "1" ] && shots=("--perf-shots=$OUT/shots")
      echo "=== $TAG $area $state q$q"
      timeout 900 "$GODOT" --path . "${gpu[@]}" --rendering-driver vulkan \
        --resolution 1920x1080 --windowed -- --sandbox=perf_tour \
        "--area=$area" "--state=$state" "--perf-quality=$q" \
        "--perf-out=$OUT/${area}_${state}_q${q}.json" "${shots[@]}" \
        "--perf-secs=$SECS" "--perf-cap=$CAP" 2>&1 \
        | grep -E "\[perf\]|SCRIPT ERROR|Parse Error" || true
    done
  done
done
