#!/usr/bin/env bash
# Fails if any banned term (tools/banned_terms.txt) appears in a tracked file.
# docs/transposition/ is exempt (it must name the source to forbid it).
# Usage: tools/check_originality.sh [--all]   (--all scans untracked files too)
set -euo pipefail
cd "$(dirname "$0")/.."
pat=$(mktemp); trap 'rm -f "$pat"' EXIT
grep -vE '^\s*(#|$)' tools/banned_terms.txt | sed 's/[[:space:]]*$//' > "$pat"
if [[ "${1:-}" == "--all" ]]; then
  files=$(git ls-files -co --exclude-standard)
else
  files=$(git ls-files)
fi
hits=$(printf '%s\n' "$files" \
  | grep -vE '^(docs/transposition/|tools/banned_terms\.txt$|tools/check_originality\.sh$)' \
  | grep -vE '\.(png|jpg|jpeg|webp|glb|fbx|ogg|wav|mp3|ttf|otf|res|scn|exr)$' \
  | while IFS= read -r f; do [[ -f "$f" ]] && printf '%s\0' "$f"; done \
  | xargs -0 -r grep -nIiwF -f "$pat" -- 2>/dev/null || true)
if [[ -n "$hits" ]]; then
  echo "ORIGINALITY CHECK FAILED — banned terms found:"; echo "$hits"; exit 1
fi
echo "originality: OK"
