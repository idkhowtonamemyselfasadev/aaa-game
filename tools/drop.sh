#!/bin/sh
# Upload big files that must survive this box (they are too big for git) to the owner's
# off-site store. Files land in a drop box and are moved to long-term storage (500 GB cap)
# every night; they leave the drop box once fetched, so nothing can be read back from it.
#
#   tools/drop.sh <file-or-dir>...
#
# Needs two environment variables (set by the owner in the cloud environment, never in git):
#   AAA_DROP_KEY   the private ssh key (full text)
#   AAA_DROP_HOST  user@host of the drop box
# Without them it prints a note and exits 0, so sessions never fail because of it.
# Directories are packed into a .tar first. Drop box limit: 50 GB until the next nightly fetch.
set -u
if [ -z "${AAA_DROP_KEY:-}" ] || [ -z "${AAA_DROP_HOST:-}" ]; then
  echo "drop.sh: AAA_DROP_KEY / AAA_DROP_HOST not set, skipping upload"; exit 0
fi
[ $# -ge 1 ] || { echo "usage: tools/drop.sh <file-or-dir>..."; exit 2; }
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
case "$AAA_DROP_KEY" in   # full key text, or the same as one line of base64
  -----*) printf '%s\n' "$AAA_DROP_KEY" > "$tmp/key" ;;
  *)      printf '%s' "$AAA_DROP_KEY" | base64 -d > "$tmp/key" 2>/dev/null ;;
esac
chmod 600 "$tmp/key"
sftpb() { sftp -q -b - -i "$tmp/key" -o BatchMode=yes -o ConnectTimeout=20 \
               -o StrictHostKeyChecking=accept-new "$AAA_DROP_HOST"; }
rc=0
for src in "$@"; do
  [ -e "$src" ] || { echo "drop.sh: $src not found"; rc=1; continue; }
  base=$(basename "$src" | tr -c 'A-Za-z0-9._+\n-' '_')
  if [ -d "$src" ]; then
    name="$(date +%Y%m%d-%H%M)_${base}.tar"
    tar -C "$(dirname "$src")" -cf "$tmp/$name" "$(basename "$src")"; file="$tmp/$name"
  else
    name="$(date +%Y%m%d-%H%M)_${base}"; file=$src
  fi
  # upload as .part, rename when complete, so the nightly fetch never takes half a file
  if printf 'put "%s" "%s.part"\nrename "%s.part" "%s"\n' "$file" "$name" "$name" "$name" | sftpb >/dev/null; then
    echo "drop.sh: uploaded $name ($(du -h "$file" | cut -f1))"
  else
    echo "drop.sh: upload of $src failed (drop box full or unreachable)"; rc=1
  fi
  [ -d "$src" ] && rm -f "$tmp/$name"
done
exit $rc
