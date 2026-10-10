#!/bin/sh
# One nightly build session: run Claude on the next milestone, sweep, then publish.
cd "$(dirname "$0")/.." || exit 2
log="logs/$(date +%Y-%m-%d_%H%M).log"
echo "=== session start $(date)" > "$log"
timeout 4h claude -p --dangerously-skip-permissions --model claude-fable-5-1 \
  "Read CLAUDE.md and PROGRESS.md. Do the next item of the current milestone, following every rule. Run shots and bots, look at the screenshots, update PROGRESS.md, commit. Stop after about 3 hours of work." \
  >> "$log" 2>&1
echo "=== claude exit $? $(date)" >> "$log"

# Safety net before anything leaves the machine. Generic pattern here; a stricter
# private pattern can live OUTSIDE the repo in ~/.config/aaa-game/pat (one regex).
pat='[A-Za-z0-9._%+-]+@(gmx|gmail|outlook|yahoo|web|proton)\.[a-z]+|/home/[a-z]+'
[ -r "$HOME/.config/aaa-game/pat" ] && pat="$pat|$(cat "$HOME/.config/aaa-game/pat")"
if git grep -IinE "$pat" $(git rev-list origin/main..HEAD) -- . ':!CLAUDE.md' >> "$log" 2>&1 \
   || git log -i -E --grep="$pat" --format='MSG %h %s' origin/main..HEAD | grep . >> "$log"; then
  echo "=== PERSONAL DATA HIT - not publishing" >> "$log"; exit 1
fi
if git log --format='%an <%ae>' origin/main..HEAD | sort -u | grep -v '^browser <browser@users.noreply.github.com>$'; then
  echo "=== bad author - not publishing" >> "$log"; exit 1
fi
git push -q origin main >> "$log" 2>&1
echo "=== published $(date)" >> "$log"
