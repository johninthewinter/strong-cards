#!/usr/bin/env bash
# sc-trash.sh <path> [<path>...]
#
# The ONLY sanctioned way for an agent to remove something from its working
# location on this machine. It never deletes: it MOVES.
#
# Layout of one trash entry (one entry per path argument):
#
#   ~/.claude/trash/<YYYY-MM-DD>/<HHMMSS>-<pid>-<basename>/
#       MANIFEST.json        provenance + sha256 + size + mtime + agent identity
#       payload/<full original absolute path without leading slash>
#
# The payload keeps the complete original path structure, so:
#   /Users/misterj/src/foo/bar.py
# lands at:
#   ~/.claude/trash/2026-09-15/143022-4711-bar.py/payload/Users/misterj/src/foo/bar.py
#
# Why that scheme: the <HHMMSS>-<pid>-<basename> entry name makes entries
# human-scannable and collision-free even for two files with the same basename
# trashed in the same second by different processes, and the full path echoed
# inside payload/ makes restoration mechanical (copy payload/<path> back to /).
#
# NOTHING HERE EVER DELETES. Emptying the trash is a manual, human-only action.
# See TRASH-README.md. Do not add an expiry/auto-empty codepath to this file.

set -uo pipefail

TRASH_ROOT="${SC_TRASH_ROOT:-$HOME/.claude/trash}"
PENDING_FILE="${SC_TRASH_PENDING_FILE:-${TMPDIR:-/tmp}/sc-trash-pending-$(id -u).txt}"

usage() {
  printf 'usage: sc-trash.sh <path> [<path>...]\n' >&2
  printf '  Moves each path into %s/<date>/<time>-<pid>-<name>/ with a sha256 manifest.\n' "$TRASH_ROOT" >&2
}

[ "$#" -ge 1 ] || { usage; exit 64; }
case "$1" in -h|--help) usage; exit 0 ;; esac

command -v python3 >/dev/null 2>&1 || {
  printf 'sc-trash.sh: python3 is required (manifest hashing).\n' >&2; exit 69; }

hash_path() {
  # sha256 of a file, or of a directory's sorted "hash  relpath" listing.
  python3 - "$1" <<'PYEOF'
import hashlib, os, sys
p = sys.argv[1]
def fh(f):
    h = hashlib.sha256()
    with open(f, "rb") as fp:
        for c in iter(lambda: fp.read(1 << 20), b""):
            h.update(c)
    return h.hexdigest()
if os.path.islink(p):
    print("symlink:" + hashlib.sha256(os.readlink(p).encode()).hexdigest())
elif os.path.isdir(p):
    agg = hashlib.sha256()
    for root, dirs, files in os.walk(p):
        dirs.sort()
        for f in sorted(files):
            full = os.path.join(root, f)
            rel = os.path.relpath(full, p)
            try:
                agg.update((fh(full) + "  " + rel + "\n").encode())
            except OSError as e:
                print("ERROR: unreadable %s: %s" % (full, e), file=sys.stderr)
                sys.exit(1)
    print("tree:" + agg.hexdigest())
else:
    print(fh(p))
PYEOF
}

AGENT_ID="${CLAUDE_AGENT_ID:-${CLAUDE_SESSION_ID:-unknown}}"
# `tty` prints "not a tty" AND fails in a hook context; strip newlines so the
# manifest field stays a single clean line.
if [ "$AGENT_ID" = "unknown" ]; then
  AGENT_TTY=$(tty 2>/dev/null | tr -d '\n' || true)
  [ -n "$AGENT_TTY" ] || AGENT_TTY="none"
  AGENT_ID="pid:$$ user:$(id -un) tty:$AGENT_TTY"
fi

DATE_DIR=$(date +%Y-%m-%d)
RC=0

for TARGET in "$@"; do
  # ---- resolve to an absolute path without following the final symlink ----
  case "$TARGET" in
    /*) ABS=$TARGET ;;
    *)  ABS=$PWD/$TARGET ;;
  esac
  PARENT=$(CDPATH= cd "$(dirname "$ABS")" 2>/dev/null && pwd -P)
  if [ -z "$PARENT" ]; then
    printf 'sc-trash.sh: FAIL %s — parent directory does not exist or is unreadable.\n' "$TARGET" >&2
    RC=1; continue
  fi
  BASE=$(basename "$ABS")
  ABS="$PARENT/$BASE"

  if [ ! -e "$ABS" ] && [ ! -L "$ABS" ]; then
    printf 'sc-trash.sh: FAIL %s — path does not exist.\n' "$ABS" >&2
    RC=1; continue
  fi

  # ---- refuse to trash the trash (would corrupt provenance) ----
  TRASH_REAL=$(CDPATH= cd "$TRASH_ROOT" 2>/dev/null && pwd -P || printf '%s' "$TRASH_ROOT")
  case "$ABS/" in
    "$TRASH_REAL"/*|"$TRASH_REAL"/)
      printf 'sc-trash.sh: FAIL %s — already inside the trash. Only the user empties the trash.\n' "$ABS" >&2
      RC=1; continue ;;
  esac

  if [ ! -w "$PARENT" ]; then
    printf 'sc-trash.sh: FAIL %s — parent directory %s is not writable; the move would fail.\n' "$ABS" "$PARENT" >&2
    RC=1; continue
  fi

  # ---- record provenance BEFORE moving ----
  HASH=$(hash_path "$ABS") || { printf 'sc-trash.sh: FAIL %s — could not hash.\n' "$ABS" >&2; RC=1; continue; }
  SIZE=$(python3 -c 'import os,sys; p=sys.argv[1]; print(sum(os.path.getsize(os.path.join(r,f)) for r,_,fs in os.walk(p) for f in fs) if os.path.isdir(p) else os.path.getsize(p))' "$ABS" 2>/dev/null || echo 0)
  MTIME=$(python3 -c 'import os,sys,datetime; print(datetime.datetime.fromtimestamp(os.path.getmtime(sys.argv[1])).isoformat())' "$ABS" 2>/dev/null || echo unknown)

  ENTRY="$TRASH_ROOT/$DATE_DIR/$(date +%H%M%S)-$$-$BASE"
  if ! mkdir -p "$ENTRY/payload$(dirname "$ABS")"; then
    printf 'sc-trash.sh: FAIL %s — could not create trash entry %s.\n' "$ABS" "$ENTRY" >&2
    RC=1; continue
  fi
  DEST="$ENTRY/payload$ABS"

  if ! mv "$ABS" "$DEST"; then
    printf 'sc-trash.sh: FAIL %s — move failed (permissions? cross-device?). Nothing was removed.\n' "$ABS" >&2
    RC=1; continue
  fi

  python3 - "$ENTRY/MANIFEST.json" "$ABS" "$DEST" "$HASH" "$SIZE" "$MTIME" "$AGENT_ID" <<'PYEOF'
import json, sys, datetime
out, orig, dest, h, size, mtime, agent = sys.argv[1:8]
json.dump({
    "original_path": orig,
    "trashed_path": dest,
    "sha256": h,
    "size_bytes": int(size),
    "original_mtime": mtime,
    "moved_by_agent": agent,
    "moved_at": datetime.datetime.now().astimezone().isoformat(),
    "tool": "sc-trash.sh",
    "note": "Never deleted. Only the user empties ~/.claude/trash, by hand.",
}, open(out, "w"), indent=2)
PYEOF

  printf '%s\n' "$ENTRY" >> "$PENDING_FILE" 2>/dev/null || true
  printf 'SC-TRASH-ENTRY: %s\n' "$ENTRY"
  printf '  original: %s\n  sha256:   %s\n  size:     %s bytes\n' "$ABS" "$HASH" "$SIZE"
done

exit $RC
