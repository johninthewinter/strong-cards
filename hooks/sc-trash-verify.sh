#!/usr/bin/env bash
# PostToolUse / Bash — mandatory double verification of every sc-trash.sh move.
#
# It does NOT depend on the agent remembering to verify, and it does NOT parse
# the tool's stdout (which an agent could paraphrase or truncate). sc-trash.sh
# appends each entry directory it created to a pending file; this hook drains
# that file and independently re-derives the evidence from disk.
#
#   Check A — re-hash the file now sitting in the trash payload and compare it
#             to the sha256 recorded in MANIFEST.json before the move.
#             Proves the moved bytes are identical to what was recorded.
#   Check B — confirm the original path no longer exists AND that nothing new
#             has appeared at that exact path. Proves it was moved, not copied
#             and left behind, and that nothing raced to refill the slot.
#
# Either check missing or contradicted => exit 2 (blocking feedback to Claude).

set -uo pipefail

PENDING_FILE="${SC_TRASH_PENDING_FILE:-${TMPDIR:-/tmp}/sc-trash-pending-$(id -u).txt}"
[ -s "$PENDING_FILE" ] || exit 0
command -v python3 >/dev/null 2>&1 || exit 0

ENTRIES=$(cat "$PENDING_FILE" 2>/dev/null) || exit 0
: > "$PENDING_FILE" 2>/dev/null || true
[ -n "$ENTRIES" ] || exit 0

# NOTE: the entry list is passed as argv, NOT piped. A heredoc supplying the
# script already occupies stdin, so piping the entries in would silently deliver
# an empty list and the hook would "pass" having verified nothing. Caught by
# tests/test_delete_guard.sh; do not refactor this back into a pipe.
REPORT=$(python3 - "$ENTRIES" <<'PYEOF'
import hashlib, json, os, sys

def fh(f):
    h = hashlib.sha256()
    with open(f, "rb") as fp:
        for c in iter(lambda: fp.read(1 << 20), b""):
            h.update(c)
    return h.hexdigest()

def hash_path(p):
    if os.path.islink(p):
        return "symlink:" + hashlib.sha256(os.readlink(p).encode()).hexdigest()
    if os.path.isdir(p):
        agg = hashlib.sha256()
        for root, dirs, files in os.walk(p):
            dirs.sort()
            for f in sorted(files):
                full = os.path.join(root, f)
                agg.update((fh(full) + "  " + os.path.relpath(full, p) + "\n").encode())
        return "tree:" + agg.hexdigest()
    return fh(p)

lines = [l.strip() for l in sys.argv[1].splitlines() if l.strip()]
if not lines:
    print("SC TRASH VERIFY — no pending trash entries to verify.")
    sys.exit(0)
failed = False
out = []
out.append("SC TRASH VERIFY — independent post-move verification")
out.append("=" * 64)

for entry in lines:
    man_path = os.path.join(entry, "MANIFEST.json")
    out.append("")
    out.append("entry: " + entry)
    if not os.path.isfile(man_path):
        out.append("  FAIL: MANIFEST.json missing — cannot verify this move.")
        failed = True
        continue
    try:
        man = json.load(open(man_path))
    except Exception as e:
        out.append("  FAIL: MANIFEST.json unreadable (%s)." % e)
        failed = True
        continue

    orig = man.get("original_path", "")
    dest = man.get("trashed_path", "")
    recorded = man.get("sha256", "")
    out.append("  original path : " + orig)
    out.append("  trashed path  : " + dest)
    out.append("  manifest sha256: " + recorded)

    # ---------------- Check A: re-hash the trashed payload ----------------
    if not (os.path.exists(dest) or os.path.islink(dest)):
        out.append("  CHECK A: FAIL — trashed payload does not exist at the recorded path.")
        failed = True
    else:
        try:
            actual = hash_path(dest)
        except OSError as e:
            actual = "unreadable: %s" % e
        out.append("  actual sha256  : " + actual)
        if actual == recorded:
            out.append("  CHECK A: PASS — trashed bytes are identical to what was recorded pre-move.")
        else:
            out.append("  CHECK A: FAIL — HASH MISMATCH. The trashed content is NOT what was moved.")
            out.append("           recorded %s" % recorded)
            out.append("           actual   %s" % actual)
            failed = True

    # ------- Check B: original slot empty and not refilled -------
    if os.path.exists(orig) or os.path.islink(orig):
        try:
            kind = "directory" if os.path.isdir(orig) else "file"
            size = os.path.getsize(orig)
        except OSError:
            kind, size = "unknown", "?"
        out.append("  CHECK B: FAIL — something exists at the original path (%s, %s bytes)." % (kind, size))
        out.append("           Either the move copied instead of moving, or the slot was refilled.")
        failed = True
    else:
        out.append("  CHECK B: PASS — original path no longer exists and nothing has taken its place.")

out.append("")
out.append("=" * 64)
out.append("VERDICT: " + ("FAILED — see the checks above." if failed else
                          "both checks passed for every entry."))
print("\n".join(out))
sys.exit(2 if failed else 0)
PYEOF
)
STATUS=$?

printf '%s\n' "$REPORT" >&2

if [ "$STATUS" -ne 0 ]; then
  cat >&2 <<'EOF'

A trash move could not be verified. Do NOT proceed as if the file were safely
stored, and do NOT retry the move. Report the mismatch above to the user with
the exact hashes and paths shown. Nothing here deletes anything: the payload
and manifest are still on disk for inspection.
EOF
  exit 2
fi
exit 0
