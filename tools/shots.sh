#!/bin/sh
# usage: tools/shots.sh "<spot> <name> [frames] [hour]" ...  -> shots/<name>.png
# Local box: renders inside a headless Weston compositor. Cloud box (no Weston): xvfb-run
# with Mesa lavapipe (Vulkan) — falls back to opengl3/llvmpipe if Vulkan fails.
cd "$(dirname "$0")/../game" || exit 2
GODOT=${GODOT:-$(command -v godot || echo ../.tools/godot)}
mkdir -p ../shots
run_shot() {
  if command -v weston >/dev/null 2>&1; then
    if [ ! -S "$XDG_RUNTIME_DIR/wayland-9" ]; then
      (weston --backend=headless --renderer=gl --socket=wayland-9 --width=1280 --height=720 --idle-time=0 >/dev/null 2>&1 &)
      sleep 2
    fi
    WAYLAND_DISPLAY=wayland-9 timeout 180 "$GODOT" --display-driver wayland --resolution 1280x720 "$@"
  else
    timeout 600 xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --display-driver x11 --resolution 1280x720 "$@"
  fi
}
for spec in "$@"; do
  set -- $spec
  out="../shots/$2.png"
  run_shot --rendering-driver vulkan res://tools/shot.tscn -- "$1" "$out" "${3:-90}" $4 2>&1 | grep -E "SHOT|GRASS|SCRIPT ERROR|ERROR" | grep -v "shader_rd\|XKB\|xkbcommon"
  if [ ! -s "$out" ]; then
    echo "vulkan failed for $2, retrying opengl3"
    run_shot --rendering-driver opengl3 --rendering-method gl_compatibility res://tools/shot.tscn -- "$1" "$out" "${3:-90}" $4 2>&1 | grep -E "SHOT|GRASS|SCRIPT ERROR|ERROR"
  fi
  echo "shot $2"
done
