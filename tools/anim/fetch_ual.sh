#!/usr/bin/env bash
# Fetch the CC0 source clips for the combat library into raw/anim_src/
# (gitignored): Quaternius "Universal Animation Library" 1 and 2, Standard
# (free) editions, CC0 1.0. The packs are served through itch.io's free
# download flow (no account): game page -> download page -> file URL.
set -euo pipefail
cd "$(dirname "$0")/../.."
OUT=raw/anim_src
mkdir -p "$OUT"
touch raw/.gdignore
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

fetch() {   # <itch game url> <glb name inside the zip>
  local game="$1" glb="$2" jar="$TMP/jar" tok page file id
  curl -sS -m 60 -c "$jar" -L "$game" -o "$TMP/page.html"
  tok=$(grep -oE 'csrf_token" value="[^"]+"' "$TMP/page.html" | head -1 | sed 's/.*value="//;s/"//')
  page=$(curl -sS -m 60 -b "$jar" -c "$jar" -X POST "$game/download_url" \
      -H 'X-Requested-With: XMLHttpRequest' --data-urlencode "csrf_token=$tok" \
      | python3 -c "import sys,json;print(json.load(sys.stdin)['url'])")
  curl -sS -m 60 -b "$jar" -c "$jar" -L "$page" -o "$TMP/dl.html"
  id=$(grep -oE 'data-upload_id="[0-9]+"' "$TMP/dl.html" | head -1 | grep -oE '[0-9]+')
  tok=$(grep -oE 'csrf_token" value="[^"]+"' "$TMP/dl.html" | head -1 | sed 's/.*value="//;s/"//')
  file=$(curl -sS -m 60 -b "$jar" -c "$jar" -X POST "$game/file/$id?source=game_download" \
      -H 'X-Requested-With: XMLHttpRequest' --data-urlencode "csrf_token=$tok" \
      | python3 -c "import sys,json;print(json.load(sys.stdin)['url'])")
  curl -sS -m 600 -L "$file" -o "$TMP/pack.zip"
  mkdir -p "$TMP/x" && (cd "$TMP/x" && unzip -o -q ../pack.zip)
  cp "$(find "$TMP/x" -name "$glb" | head -1)" "$OUT/$glb"
  find "$TMP/x" -name License.txt | head -1 | xargs -I{} cp {} "$OUT/${glb%.glb}_License.txt"
  rm -rf "$TMP/x" "$TMP/pack.zip"
  echo "fetched $OUT/$glb"
}

fetch https://quaternius.itch.io/universal-animation-library UAL1_Standard.glb
fetch https://quaternius.itch.io/universal-animation-library-2 UAL2_Standard.glb
