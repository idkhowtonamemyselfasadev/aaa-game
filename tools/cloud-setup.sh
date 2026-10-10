#!/bin/sh
# Cloud sandbox setup (fresh box every session). Idempotent.
# - downloads Godot 4.7.2 stable Linux x86_64 editor into .tools/godot (gitignored)
# - tries to install xvfb + Mesa software renderers so screenshots can be taken with
#   `xvfb-run` (lavapipe for Vulkan, llvmpipe for GL). If that fails, headless bot runs
#   (godot --headless) still work; screenshots are skipped for the session.
set -u
cd "$(dirname "$0")/.." || exit 2
ROOT=$(pwd)
TOOLS="$ROOT/.tools"
mkdir -p "$TOOLS"
GODOT_VER=4.7.2
ZIP="Godot_v${GODOT_VER}-stable_linux.x86_64.zip"
URL="https://github.com/godotengine/godot/releases/download/${GODOT_VER}-stable/${ZIP}"

if [ ! -x "$TOOLS/godot" ]; then
  echo "== downloading Godot $GODOT_VER"
  if curl -fsSL --retry 3 -o "$TOOLS/$ZIP" "$URL"; then
    (cd "$TOOLS" && unzip -oq "$ZIP" && mv -f "Godot_v${GODOT_VER}-stable_linux.x86_64" godot && rm -f "$ZIP")
    chmod +x "$TOOLS/godot"
  else
    echo "!! Godot download failed (network?)"; echo "GODOT_DOWNLOAD_FAILED" > "$TOOLS/status"; exit 1
  fi
fi
echo "== godot: $("$TOOLS/godot" --version 2>/dev/null | head -1)"

# Software renderer for screenshots.
if ! command -v xvfb-run >/dev/null 2>&1 || ! ls /usr/share/vulkan/icd.d/lvp_icd*.json >/dev/null 2>&1; then
  echo "== installing xvfb + mesa"
  if command -v apt-get >/dev/null 2>&1; then
    (apt-get update -qq && apt-get install -y -qq xvfb mesa-vulkan-drivers mesa-utils libgl1-mesa-dri libvulkan1 vulkan-tools \
       libxcursor1 libxinerama1 libxrandr2 libxi6 libasound2t64 libpulse0 fontconfig) >/dev/null 2>&1 \
      || (apt-get install -y -qq xvfb mesa-vulkan-drivers mesa-utils libgl1-mesa-dri libvulkan1 libxcursor1 libxinerama1 libxrandr2 libxi6 libasound2 fontconfig) >/dev/null 2>&1 \
      || echo "!! apt install failed"
  elif command -v dnf >/dev/null 2>&1; then
    dnf install -y -q xorg-x11-server-Xvfb mesa-vulkan-drivers mesa-dri-drivers vulkan-loader >/dev/null 2>&1 || echo "!! dnf install failed"
  fi
fi
if command -v xvfb-run >/dev/null 2>&1; then
  echo "SHOTS_OK" > "$TOOLS/status"; echo "== xvfb available: screenshots possible"
else
  echo "SHOTS_UNAVAILABLE" > "$TOOLS/status"; echo "== no xvfb: screenshots skipped this session"
fi
