#!/bin/sh
# usage: [ENV=...] tools/climbsweep.sh [lead...]   (default leads 1.9 1.95 2.0 2.05 2.1)
# The `climb` bot's arm reads come from ONE climb and are chaotic: nudging CLIMB_HOLD_LEAD by 0.05
# with no code change moves "a wrist over the head" from 33 % to 11-29 %. Judge a climb change over
# this sweep (runs the bot once per lead, in parallel) and compare the means, not one run.
# (11-19 06:00) the bot now also pools the arm reads over 12 climbs of the keep's tall faces
# ("pooled arm reads" line, gated); its spread over the 5 leads is 15.7-17.6 % / 0.254-0.272 m,
# so one pooled run is already a fair judge. The sweep prints both.
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
  po=$(grep "^BOT climb: pooled" "$f" | sed -E 's/.*head ([0-9.]+)% of the time, highest wrist ([0-9.]+) m.*wrist ([0-9.]+) m out.*/pooled over% \1 hi \2 low \3/')
  echo "lead $l over_head% ${o:-?} low_out_mean,least ${lo:-? ?} pass $pass | ${po:-pooled ?}"
done | tee "$tmp/sum"
awk '{o+=$4; m+=$6; if($7<lo||NR==1)lo=$7; po+=$13; ph+=$15; pl+=$17; n++} END{printf "MEAN over %d runs: wrist over the head %.1f %%, low wrist out %.3f m (least %.3f) | pooled: over %.1f %%, hi %.3f m, low %.3f m\n", n, o/n, m/n, lo, po/n, ph/n, pl/n}' "$tmp/sum"
rm -rf "$tmp"
