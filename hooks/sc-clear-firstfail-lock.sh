#!/usr/bin/env bash
# Explicit, audited resolution path for a Strong Card first-failure lock.
# This records controller-supplied judge evidence before removing the active lock.

set -uo pipefail

command -v jq >/dev/null 2>&1 || {
  printf 'sc-clear-firstfail-lock: jq is required\n' >&2
  exit 1
}

SCRIPT_DIR=$(CDPATH= cd "$(dirname "$0")" 2>/dev/null && pwd)
[ -r "$SCRIPT_DIR/sc-firstfail-lib.sh" ] || {
  printf 'sc-clear-firstfail-lock: missing sc-firstfail-lib.sh\n' >&2
  exit 1
}
# shellcheck source=./sc-firstfail-lib.sh
. "$SCRIPT_DIR/sc-firstfail-lib.sh"

usage() {
  cat >&2 <<'EOF'
Usage:
  sc-clear-firstfail-lock.sh \
    --judge-verdict '<verdict and concrete card edit/split>' \
    --judge-evidence '<judge transcript/session ID/path>' \
    <worktree>

This helper does not dispatch the judge. Run it only after the RULES §4 judge has ruled.
EOF
  exit 2
}

VERDICT=""
EVIDENCE=""
WORKTREE_INPUT=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --judge-verdict)
      [ "$#" -ge 2 ] || usage
      VERDICT=$2
      shift 2
      ;;
    --judge-evidence)
      [ "$#" -ge 2 ] || usage
      EVIDENCE=$2
      shift 2
      ;;
    --)
      shift
      [ "$#" -eq 1 ] || usage
      WORKTREE_INPUT=$1
      shift
      ;;
    -*) usage ;;
    *)
      [ -z "$WORKTREE_INPUT" ] || usage
      WORKTREE_INPUT=$1
      shift
      ;;
  esac
done

[ -n "$VERDICT" ] && [ -n "$EVIDENCE" ] && [ -n "$WORKTREE_INPUT" ] || usage

if [ -d "$WORKTREE_INPUT" ]; then
  WORKTREE=$(sc_ff_canonical_path "$WORKTREE_INPUT" "$PWD" 2>/dev/null || true)
else
  # A failed disposable worktree may have been removed too early. Permit only the exact
  # absolute path formerly recorded in the lock; the JSON equality check below still gates it.
  case "$WORKTREE_INPUT" in
    /*) WORKTREE=$WORKTREE_INPUT ;;
    *) printf 'sc-clear-firstfail-lock: nonexistent relative worktree: %s\n' "$WORKTREE_INPUT" >&2; exit 1 ;;
  esac
fi
[ -n "$WORKTREE" ] || {
  printf 'sc-clear-firstfail-lock: cannot resolve worktree: %s\n' "$WORKTREE_INPUT" >&2
  exit 1
}

LOCK=$(sc_ff_lock_path "$WORKTREE" 2>/dev/null || true)
[ -n "$LOCK" ] && [ -f "$LOCK" ] || {
  printf 'sc-clear-firstfail-lock: no active lock for %s\n' "$WORKTREE" >&2
  exit 1
}

LOCK_JSON=$(cat "$LOCK")
printf '%s' "$LOCK_JSON" | jq -e --arg worktree "$WORKTREE" \
  '.worktree == $worktree' >/dev/null 2>&1 || {
  printf 'sc-clear-firstfail-lock: lock is corrupt or records a different worktree: %s\n' "$LOCK" >&2
  exit 1
}

AUDIT_LOG=${SC_FIRSTFAIL_AUDIT_LOG:-"$HOME/.claude/logs/sc-firstfail-audit.jsonl"}
AUDIT_DIR=$(dirname "$AUDIT_LOG")
if [ -L "$AUDIT_LOG" ]; then
  printf 'sc-clear-firstfail-lock: refusing symlink audit log: %s\n' "$AUDIT_LOG" >&2
  exit 1
fi
(umask 077; mkdir -p "$AUDIT_DIR") || {
  printf 'sc-clear-firstfail-lock: cannot create audit directory: %s\n' "$AUDIT_DIR" >&2
  exit 1
}
chmod 700 "$AUDIT_DIR" 2>/dev/null || true

CLEARED_AT=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
AUDIT_RECORD=$(jq -nc \
  --arg cleared_at "$CLEARED_AT" \
  --arg verdict "$VERDICT" \
  --arg evidence "$EVIDENCE" \
  --argjson failure "$LOCK_JSON" \
  '{cleared_at:$cleared_at, judge_verdict:$verdict, judge_evidence:$evidence, failure:$failure}') || exit 1

(umask 077; printf '%s\n' "$AUDIT_RECORD" >> "$AUDIT_LOG") || {
  printf 'sc-clear-firstfail-lock: audit append failed; lock was NOT removed\n' >&2
  exit 1
}
chmod 600 "$AUDIT_LOG" 2>/dev/null || true

rm -f "$LOCK" || {
  printf 'sc-clear-firstfail-lock: audit recorded, but lock removal failed: %s\n' "$LOCK" >&2
  exit 1
}

printf 'STRONG CARD FIRST-FAIL LOCK CLEARED\nWorktree: %s\nAudit: %s\n' \
  "$WORKTREE" "$AUDIT_LOG"
exit 0
