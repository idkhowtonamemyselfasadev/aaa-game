#!/bin/sh
# Audio level sweep (owner priority 0b-d): true peak (dBTP) and integrated loudness (LUFS)
# of every .ogg under game/audio. Fails (exit 1) if any file peaks above -1 dBTP.
# Usage: tools/audio_peaks.sh [dir]   (default game/audio)
set -u
cd "$(dirname "$0")/.." || exit 2
DIR=${1:-game/audio}
LIMIT=-1.0
bad=0; n=0
for f in $(find "$DIR" -name '*.ogg' | sort); do
  out=$(ffmpeg -hide_banner -nostats -i "$f" -af ebur128=peak=true -f null - 2>&1)
  lufs=$(printf '%s\n' "$out" | awk '/Integrated loudness:/{getline; print $2}')
  tp=$(printf '%s\n' "$out" | awk '/True peak:/{getline; print $2}')
  n=$((n + 1))
  flag=""
  if awk "BEGIN{exit !($tp > $LIMIT)}"; then flag="  << CLIPS (> $LIMIT dBTP)"; bad=$((bad + 1)); fi
  printf '%7s dBTP %7s LUFS  %s%s\n' "$tp" "$lufs" "${f#$DIR/}" "$flag"
done
echo "== $n files, $bad above $LIMIT dBTP"
[ "$bad" -eq 0 ]
