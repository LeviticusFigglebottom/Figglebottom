#!/usr/bin/env bash
# Collision audit: what is drawn against what is solid, in every area, both
# states and after each release (docs/qa/COLLISION_AUDIT.md).
#   tools/audit_collision.sh                      all areas, the report on stdout
#   tools/audit_collision.sh --areas=tarnhall     one area (or a,b)
#   tools/audit_collision.sh --collision-out=/abs/out.json   every offender as JSON
#   tools/audit_collision.sh --update-baseline    accept today's offenders as known
set -uo pipefail
cd "$(dirname "$0")/.."
timeout 1500 godot --headless --path . -- --test=collision_audit "$@" 2>&1 \
  | grep -E "^==|^  --|ok  -|FAIL|SCRIPT|ERROR: .*collision_audit|RESULT|NEW |known x|gone \(|^  [a-z_]+ +[a-z+]+ +\{|audit time|baseline written"
exit "${PIPESTATUS[0]}"
