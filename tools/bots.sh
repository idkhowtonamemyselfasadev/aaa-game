#!/bin/sh
# usage: tools/bots.sh [route...]   (default: all routes). Headless; exit 1 if any bot fails.
cd "$(dirname "$0")/../game" || exit 2
GODOT=${GODOT:-$(command -v godot || echo ../.tools/godot)}
[ $# -eq 0 ] && set -- walk ridge
rc=0
for r in "$@"; do
  timeout 300 "$GODOT" --headless res://tools/bot.tscn -- "$r" 2>&1 | grep -E "^BOT|SCRIPT ERROR|ERROR" 
  st=$?
  # grep's status masks godot's; re-check via the PASS line
  "$GODOT" --headless res://tools/bot.tscn -- "$r" >/dev/null 2>&1 || rc=1
done
exit $rc
