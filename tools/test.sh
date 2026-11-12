#!/usr/bin/env bash
# Headless test runner. Runs every in-game test (tools/test/*_test.tscn)
# through the real boot path so autoloads and physics are live.
set -uo pipefail
cd "$(dirname "$0")/.."
FILTER="${1:-}"
overall=0
# static geometry audits: classed edges + placement anomalies (no engine)
if [ -z "$FILTER" ]; then
  echo "=== audit: edges"
  python3 tools/audit_edges.py || overall=1
  echo "=== audit: placement anomalies"
  python3 tools/audit_areas.py || overall=1
fi
# refresh imports + global class cache (new class_name scripts)
timeout 300 godot --headless --path . --import >/dev/null 2>&1
for scene in tools/test/*_test.tscn; do
  name="$(basename "$scene" _test.tscn)"
  if [ -n "$FILTER" ] && [ "$name" != "$FILTER" ]; then continue; fi
  # the full-game region walks run about a quarter of an hour each: only
  # when asked for by name (CI runs them as their own parallel jobs)
  case "$name" in fullgame_*) [ -z "$FILTER" ] && continue ;; esac
  echo "=== test: $name"
  # the full-slice walk plays the whole 20-minute slice in real time
  limit=300
  [ "$name" = "fullslice" ] && limit=2700
  # the streaming suite builds three areas from an empty cache, twice over
  [ "$name" = "streaming" ] && limit=900
  # the progression gates: six regions built several times over, a capsule
  # steered at every metre of each neck in both states
  [ "$name" = "gates" ] && limit=1800
  # the leftovers count fights every foe three times over: slow on a busy box
  case "$name" in leftovers*) limit=600 ;; esac
  # the collision audit builds every area five times over (about 5 minutes)
  [ "$name" = "collision_audit" ] && limit=900
  [ "$name" = "intro" ] && limit=900   # sits through the opening once
  # the full-game region walks (fullgame_<region>) each play a whole region
  case "$name" in fullgame_*) limit=2700 ;; esac
  timeout "$limit" godot --headless --path . -- "--test=$name" 2>&1 \
    | grep -vE "ALSA|snd_|libpulse|Condition \"status|dummy driver|Godot Engine|^\s*$" \
    | grep -vE "at: (init_output_device|push_warning)"
  code=${PIPESTATUS[0]}
  if [ "$code" -ne 0 ]; then
    echo "!!! $name exited $code"
    overall=1
  fi
done
exit $overall
