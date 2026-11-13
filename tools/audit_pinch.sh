#!/usr/bin/env bash
# Pinch-gap audit: solid bodies closer than the Bearer's capsule (0.68 m) but not touching, every area, THAW and
# RIME (tools/pinch_audit.gd). ROUTE marks the ones within reach of the navmesh and near a path to a hearth,
# portal, pickup or gate.
#   tools/audit_pinch.sh                         all areas, the list on stdout
#   tools/audit_pinch.sh --areas=tarnhall        one area (or a,b)
#   tools/audit_pinch.sh --out=/abs/gaps.json    every gap as JSON
set -uo pipefail
cd "$(dirname "$0")/.."
timeout 3000 godot --headless --path . -- --scene=res://tools/pinch_audit.tscn "$@" 2>&1 \
  | grep -E "^GAP|^PINCH|^NAV|SCRIPT ERROR|Parse Error"
exit "${PIPESTATUS[0]}"
