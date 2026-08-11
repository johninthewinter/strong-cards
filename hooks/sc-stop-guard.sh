#!/usr/bin/env bash
# Stop — Strong Card end-of-turn guard (RULES §2.2, §3.4).
#
# Catches the two states that must never survive a turn: verified work left uncommitted,
# and dispatch worktrees left dangling. Injects the finding into Claude's context.
#
# Deliberately NON-blocking (exit 0 + additionalContext, not exit 2). A Stop hook that
# blocks can trap a session in a loop; the stop_hook_active field exists precisely because
# that happens. Notify, don't wedge.

set -uo pipefail

INPUT=$(cat)
command -v jq >/dev/null 2>&1 || exit 0
command -v git >/dev/null 2>&1 || exit 0

# Already re-entered from a previous Stop hook — do not compound.
[ "$(printf '%s' "$INPUT" | jq -r '.stop_hook_active // false')" = "true" ] && exit 0

CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty')
[ -n "$CWD" ] || CWD="$PWD"
git -C "$CWD" rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

FINDINGS=""

DIRTY=$(git -C "$CWD" status --porcelain 2>/dev/null | head -n 40)
if [ -n "$DIRTY" ]; then
  COUNT=$(git -C "$CWD" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  DELETED=$(git -C "$CWD" status --porcelain 2>/dev/null | grep -cE '^( D|D |AD)' || true)
  FINDINGS="${FINDINGS}
- Uncommitted changes: ${COUNT} path(s) (RULES §2.2 — every verified card is committed).
  Deleted/removed paths in that set: ${DELETED}. Any deletion you did not deliberately
  intend is the 2026-08-10 incident happening again — check it before you stop.
  First entries:
$(printf '%s' "$DIRTY" | sed 's/^/    /')"
fi

# Dangling dispatch worktrees: created, never merged/removed.
WTS=$(git -C "$CWD" worktree list --porcelain 2>/dev/null | awk '/^worktree /{print $2}' | tail -n +2)
if [ -n "$WTS" ]; then
  FINDINGS="${FINDINGS}
- Dispatch worktree(s) still present (RULES §3.4 — merge the card branch, then
  \`git worktree remove\`). A leftover worktree means a card was never closed out, or its
  diff was never reviewed against the Touch List:
$(printf '%s' "$WTS" | sed 's/^/    /')"
fi

# Untracked source roots — the precondition that made the incident unrecoverable.
UNTRACKED_DIRS=$(git -C "$CWD" status --porcelain 2>/dev/null \
  | awk '/^\?\? /{print $2}' | grep -E '/$' \
  | grep -viE '(node_modules|__pycache__|\.venv|venv|\.pytest_cache|dist|build|\.audit|\.pilot|\.DS_Store)' \
  | head -n 5)
if [ -n "$UNTRACKED_DIRS" ]; then
  FINDINGS="${FINDINGS}
- Untracked director(ies) that look like source (RULES §2.1 — no dispatch against an
  untracked tree; there is no revert path):
$(printf '%s' "$UNTRACKED_DIRS" | sed 's/^/    /')"
fi

[ -n "$FINDINGS" ] || exit 0

jq -nc --arg ctx "STRONG CARD STOP GUARD — git state findings before this turn ends:
${FINDINGS}

Resolve or explicitly justify each item. Do not end a Strong Card turn with verified work
uncommitted: on 2026-08-10 an out-of-scope worker deleted a shipped, SIGKILL-tested module
and there was no history to revert to. Committing is the entire safety net." \
  '{hookSpecificOutput:{hookEventName:"Stop", additionalContext:$ctx}}'
exit 0
