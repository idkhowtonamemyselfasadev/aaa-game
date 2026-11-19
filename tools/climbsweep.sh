#!/bin/sh
# usage: [ENV=...] tools/climbsweep.sh [lead...]   (default leads 1.9 1.95 2.0 2.05 2.1)
# The `climb` bot's arm reads come from ONE climb and are chaotic: nudging CLIMB_HOLD_LEAD by 0.05
# with no code change moves "a wrist over the head" from 33 % to 11-29 %. Judge a climb change over
# this sweep (runs the bot once per lead, in parallel) and compare the means, not one run.
cd "$(dirname "$0")/../game" || exit 2
GODOT=${GODOT:-$(command -v godot || echo ../.tools/godot)}
[ $# -eq 0 ] && set -- 1.9 1.95 2.0 2.05 2.1
tmp=$(mktemp -d)
for l in "$@"; do
  CLIMB_HOLD_LEAD=$l timeout ${BOT_TIMEOUT:-500} "$GODOT" --headless --audio-driver Dummy res://tools/bot.tscn -- climb > "$tmp/$l.txt" 2>&1 &
done
wait
for l in "$@"; do
  f="$tmp/$l.txt"
  o=$(grep "^BOT climb: overhead" "$f" | sed -E 's/.*head \(> 0.25 m\) ([0-9]+)%.*/\1/')
  lo=$(grep "^BOT climb: the low hand" "$f" | sed -E 's/.*shoulder ([0-9.]+) m out.*least ([0-9.]+),.*/\1 \2/')
  pass=$(grep -c "^BOT PASS" "$f")
  echo "lead $l over_head% ${o:-?} low_out_mean,least ${lo:-? ?} pass $pass"
done | tee "$tmp/sum"
awk '{o+=$4; m+=$6; if($7<lo||NR==1)lo=$7; n++} END{printf "MEAN over %d runs: wrist over the head %.1f %%, low wrist out %.3f m (least %.3f)\n", n, o/n, m/n, lo}' "$tmp/sum"
rm -rf "$tmp"
