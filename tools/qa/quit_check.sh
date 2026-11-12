#!/usr/bin/env bash
# The game must exit promptly whatever streaming work is in flight when it
# is asked to quit (ADR 0014, "Quitting"). Runs tools/qa/quit_probe.tscn once
# per case and way of quitting, each as its own process under a timeout, and
# fails if any does not exit within LIMIT_MS of being asked (or at all).
#   cases: preload (a neighbour on a worker), warm (idle cache warming),
#          rebake (a background navmesh re-bake), crossing (in the black)
#   ways:  game (Game.quit), tree (a bare get_tree().quit()), close (the window)
# Usage: tools/qa/quit_check.sh [case ...]      (default: all four)
#   LIMIT_MS=3000 GODOT=godot tools/qa/quit_check.sh
set -uo pipefail
cd "$(dirname "$0")/../.."
GODOT="${GODOT:-godot}"
LIMIT_MS="${LIMIT_MS:-3000}"
CASES=("$@")
[ ${#CASES[@]} -eq 0 ] && CASES=(preload warm rebake crossing)
fail=0
for c in "${CASES[@]}"; do
  for how in game tree close; do
    for after in 150 1500; do
      out="$(timeout 90 "$GODOT" --headless --path . -- --scene=res://tools/qa/quit_probe.tscn \
        "--quit-case=$c" "--quit-how=$how" "--quit-after-ms=$after" "--cache-dir=user://quit_probe/cache" 2>&1)"
      code=$?
      now=$(date +%s%3N)
      asked="$(printf '%s\n' "$out" | sed -n 's/^\[quit\] asked at \([0-9]*\)$/\1/p' | tail -1)"
      if [ "$code" -eq 124 ] || [ -z "$asked" ]; then
        echo "FAIL  $c/$how/${after}ms: did not exit (code $code)"
        printf '%s\n' "$out" | grep -E "ERROR|quit\]" | head -5
        fail=1
        continue
      fi
      ms=$(( now - asked ))
      errs="$(printf '%s\n' "$out" | grep -c "^ERROR\|SCRIPT ERROR")"
      verdict=ok
      if [ "$ms" -gt "$LIMIT_MS" ] || [ "$code" -ne 0 ]; then verdict=FAIL; fail=1; fi
      echo "$verdict  $c/$how/${after}ms: exit $code, $ms ms from the asking to the process gone, $errs errors logged"
    done
  done
done
exit $fail
