#!/bin/sh
# usage: tools/shots.sh "<scene_or_spot> <name> [frames] [extra]" ...  -> shots/<name>.png
# Renders inside a headless Weston compositor (wayland-9) so nothing appears on the desktop.
cd "$(dirname "$0")/../game" || exit 2
if [ ! -S "$XDG_RUNTIME_DIR/wayland-9" ]; then
  (weston --backend=headless --renderer=gl --socket=wayland-9 --width=1280 --height=720 --idle-time=0 >/dev/null 2>&1 &)
  sleep 2
fi
for spec in "$@"; do
  set -- $spec
  WAYLAND_DISPLAY=wayland-9 timeout 120 godot --display-driver wayland --resolution 1280x720 \
    res://tools/shot.tscn -- "$1" "../shots/$2.png" "${3:-90}" $4 2>&1 | grep -E "SCRIPT ERROR|ERROR"
  echo "shot $2"
done
