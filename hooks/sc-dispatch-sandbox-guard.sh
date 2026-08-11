#!/usr/bin/env bash
# PreToolUse / Bash — Strong Card sandbox guard (RULES §3, §2).
#
# BLOCKS a coder dispatch whose working directory is not a dedicated git worktree.
# This is the one hook that enforces rather than reminds: exit 2 on a PreToolUse hook
# prevents the tool call from running at all, and stderr is fed back to Claude as the reason.
#
# Why: on 2026-08-10 `opencode run --dir <repo-root>` gave a local coder write access to the
# entire working tree. It left its 2-file touch list and deleted a shipped, SIGKILL-tested
# production module. Nothing was revertable — the tree was untracked.

set -uo pipefail

INPUT=$(cat)
command -v jq >/dev/null 2>&1 || exit 0   # no jq: fail open, never wedge the session

CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')
[ -n "$CMD" ] || exit 0

# Is this a coder dispatch? Extend this pattern for other harnesses.
case "$CMD" in
  *"opencode run"*|*"opencode2 run"*|*"claude-local -p"*|*"strong-card-runner"*) ;;
  *) exit 0 ;;
esac

# Read-only / help invocations are not dispatches.
case "$CMD" in *" --help"*|*" -h "*) exit 0 ;; esac

block() {
  printf 'STRONG CARD SANDBOX GUARD — dispatch blocked (RULES §3).\n\n%s\n\n' "$1" >&2
  cat >&2 <<'EOF'
Required shape:

  git -C <repo> worktree add ../.wt/card-<slug> -b card/<slug>
  opencode run --dir ../.wt/card-<slug> ... -f <card-file>

Then BEFORE merging, review the whole tree, not just the expected files:

  git -C ../.wt/card-<slug> status --porcelain   # deletions + untracked
  git -C ../.wt/card-<slug> diff --stat          # compare against the card's Touch List

Then: commit inside the worktree, `git merge card/<slug> --no-edit`, `git worktree remove`.

If the tree is not under git yet, commit a baseline FIRST (RULES §2.1) — recovery from an
out-of-scope worker without git history is luck, not process.
EOF
  exit 2
}

# Extract --dir / --cwd value (supports `--dir X` and `--dir=X`).
DIR=$(printf '%s' "$CMD" \
  | grep -oE -- '--(dir|cwd)[= ]+("[^"]+"|'"'"'[^'"'"']+'"'"'|[^[:space:]]+)' \
  | head -n1 | sed -E 's/^--(dir|cwd)[= ]+//' | tr -d "\"'")

[ -n "$DIR" ] || block "This dispatch declares no --dir, so the worker inherits the session's
working directory — i.e. the main repo. Unbounded write access."

# Resolve relative to the tool call's cwd.
HOOK_CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty')
case "$DIR" in
  /*) ABS="$DIR" ;;
  *)  ABS="${HOOK_CWD:-$PWD}/$DIR" ;;
esac
ABS=$(cd "$ABS" 2>/dev/null && pwd) || block "--dir path does not exist: $DIR"

git -C "$ABS" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  || block "--dir is not inside a git repository: $ABS
An untracked tree has no revert path (RULES §2.1)."

# A linked worktree's .git is a FILE ('gitdir: ...'), and its git-dir differs from the
# common git-dir. The primary working tree fails both — which is exactly what we block.
GITDIR=$(git -C "$ABS" rev-parse --absolute-git-dir 2>/dev/null)
COMMON=$(git -C "$ABS" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)

if [ -z "$GITDIR" ] || [ "$GITDIR" = "$COMMON" ]; then
  block "--dir points at the PRIMARY working tree, not a dedicated worktree:
  $ABS
A worker pointed here can modify, stub, or delete ANY file in the repo, regardless of what
the card's Touch List says. The Touch List is prose; the worktree is the boundary."
fi

# Dirty worktree at dispatch time makes the post-run diff unreadable — you cannot tell the
# worker's changes from what was already there.
if [ -n "$(git -C "$ABS" status --porcelain 2>/dev/null)" ]; then
  printf 'STRONG CARD: worktree %s is dirty at dispatch time. Commit or stash first — otherwise the post-dispatch `git diff --stat` cannot distinguish the worker'"'"'s changes from pre-existing ones, and RULES §3.3 verification is meaningless.\n' "$ABS" >&2
  exit 2
fi

exit 0
