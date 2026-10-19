#!/bin/sh
# usage: tools/bots.sh [route...]   (default: all routes). Headless; exit 1 if any bot fails.
cd "$(dirname "$0")/../game" || exit 2
GODOT=${GODOT:-$(command -v godot || echo ../.tools/godot)}
[ $# -eq 0 ] && set -- walk ridge combat dodge soldier lockon heavy sweep insects butterflies flinch death weather roost ruin understory trample herd bed moss shrine facelight sound foley mix gfx keeper talk hearth fox cottage stonehouse whitehouse leanto waterbutt drywall yardwall hens yardpath
rc=0
for r in "$@"; do
  out=$(timeout 300 "$GODOT" --headless --audio-driver Dummy res://tools/bot.tscn -- "$r" 2>&1)
  echo "$out" | grep -E "^BOT|SCRIPT ERROR|Parse Error|ERROR" | grep -v "shader_rd"
  echo "$out" | grep -q "^BOT PASS" || rc=1
  echo "$out" | grep -q "SCRIPT ERROR" && { echo "BOT FAIL: script errors"; rc=1; }
done
exit $rc
