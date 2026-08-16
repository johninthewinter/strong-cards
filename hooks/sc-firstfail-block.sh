#!/usr/bin/env bash
# PreToolUse / Bash — hard-block pytest while a worktree has an unresolved first failure.
# Exit 2 is Claude Code's blocking contract; stderr becomes the tool denial reason.

set -uo pipefail

INPUT=$(cat)
command -v jq >/dev/null 2>&1 || exit 0   # match existing hooks: no jq must not wedge Bash

SCRIPT_DIR=$(CDPATH= cd "$(dirname "$0")" 2>/dev/null && pwd)
[ -r "$SCRIPT_DIR/sc-firstfail-lib.sh" ] || exit 0
# shellcheck source=./sc-firstfail-lib.sh
. "$SCRIPT_DIR/sc-firstfail-lib.sh"

CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')
[ -n "$CMD" ] || exit 0
sc_ff_is_pytest_command "$CMD" || exit 0

HOOK_CWD=$(printf '%s' "$INPUT" | jq -r '.tool_input.cwd // .cwd // empty')
WORKTREE=$(sc_ff_worktree_for_command "$CMD" "$HOOK_CWD" 2>/dev/null || true)
[ -n "$WORKTREE" ] || exit 0
LOCK=$(sc_ff_lock_path "$WORKTREE" 2>/dev/null || true)
[ -n "$LOCK" ] && [ -e "$LOCK" ] || exit 0

CLEAR_CMD=$(sc_ff_clear_command "$WORKTREE")
LOCK_WORKTREE=$(jq -r '.worktree // empty' "$LOCK" 2>/dev/null || true)

printf 'STRONG CARD FIRST-FAIL GUARD — pytest command blocked (RULES §4.1).\n\n' >&2
if [ -z "$LOCK_WORKTREE" ]; then
  printf 'The active lock is unreadable or corrupt: %s\n' "$LOCK" >&2
elif [ "$LOCK_WORKTREE" != "$WORKTREE" ]; then
  printf 'Lock-key collision/path mismatch: requested %s, lock records %s\n' \
    "$WORKTREE" "$LOCK_WORKTREE" >&2
else
  LOCK_FAILED_AT=$(jq -r '.failed_at // "unknown"' "$LOCK" 2>/dev/null)
  LOCK_TEST=$(jq -r '.test // empty' "$LOCK" 2>/dev/null)
  printf 'Worktree: %s\nFirst failure: %s\nFailing test: %s\nLock: %s\n' \
    "$WORKTREE" "$LOCK_FAILED_AT" "${LOCK_TEST:-not parseable}" "$LOCK" >&2
fi

cat >&2 <<EOF

A judge MUST rule before any further pytest/full-suite run against this worktree.
Dispatch the RULES §4 judge now. Do not blind-retry and do not delete the lock manually.

After recording the judge's concrete verdict/card edit or split, clear it with:

  $CLEAR_CMD
EOF
exit 2
