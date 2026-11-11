#!/usr/bin/env bash
# The whole game as one chained run, start to credits: the slice walk from
# the front door, then each region's walk from the save the one before ends
# on (rewriting tools/test/fixtures/fullgame_after_*.json as it goes), then
# both endings from the Coldwell's save. Stops at the first walk that fails.
# About two and a half hours headless.
# Usage: tools/qa/fullgame_chain.sh [first-region]   (resume the chain there)
set -uo pipefail
cd "$(dirname "$0")/../.."
REGIONS=(lowe kettle tarnhall thornwold reach coldwell)
FROM="${1:-saltfell}"
FILTER='ALSA|snd_|libpulse|dummy driver|edge error|rasteriz|Consider |toggled under|nav_map_builder|logical error|^\s*$'
run() {
  echo "=== chain: $1"
  local log
  log="$(mktemp)"
  timeout 2700 godot --headless --path . -- "--test=$1" "${@:2}" 2>&1 | grep -vE "$FILTER" | tee "$log"
  local code="${PIPESTATUS[0]}"
  # the walk's own last word decides, not the exit code alone: some godot
  # launchers return 0 whatever the game quit with, and the chain then went
  # on from a save a failed walk had no business writing
  local result
  result="$(grep -E '^RESULT: [0-9]+ checks, [0-9]+ failures' "$log" | tail -1)"
  rm -f "$log"
  if [ -z "$result" ]; then
    echo "!!! chain: $1 never reported a RESULT (exit $code): stopping; every walk after it is not run"
    return 1
  fi
  if [ "$code" -ne 0 ] || ! echo "$result" | grep -q ', 0 failures$'; then
    echo "!!! chain: $1 failed ($result, exit $code): stopping; every walk after it is not run"
    return 1
  fi
  return 0
}
timeout 900 godot --headless --path . --import >/dev/null 2>&1
started=0
if [ "$FROM" = "saltfell" ]; then
  started=1
  run fullslice "--keep-save=$PWD/tools/test/fixtures/fullgame_after_saltfell.json" || exit 1
fi
for r in "${REGIONS[@]}"; do
  [ "$r" = "$FROM" ] && started=1
  [ "$started" = 1 ] || continue
  run "fullgame_$r" --fullgame-write-fixture || exit 1
done
run fullgame_ending_outsong || exit 1
run fullgame_ending_kept || exit 1
echo "=== chain: the whole game walked, start to credits"
