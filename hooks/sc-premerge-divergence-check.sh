#!/usr/bin/env bash
# Controller-run pre-merge divergence check (RULES §3.9).
#
# NOT a Claude Code hook — this is a standalone script the controller runs deliberately
# before merging a card branch into an integration branch. `git merge`/`git checkout` are
# used for far more than card integration; blocking them generically at the PreToolUse
# layer would be broad enough to break unrelated work (RULES §8.1's minimum-force
# principle applies to hooks too). Structural verification belongs here instead.
#
# Why: 2026-08-16, nukegraph "The Write Path", P1-F and P1-B. Both cards were branched from
# the integration branch BEFORE the immediately-prior card had actually merged into it. A
# naive fast-forward or checkout-based merge of either branch would have silently REVERTED
# the prior card's already-merged work — the new branch's history simply didn't contain it.
# Caught both times only because the controller happened to use `git merge <sha> --no-edit`
# (a real three-way merge) and manually diffed afterward — nothing forced that discipline.
#
# Usage:
#   sc-premerge-divergence-check.sh <repo> <integration-branch> <card-branch> [--dry-run-merge]
#
# Exit 0: card branch's merge-base with the integration branch equals the integration
#         branch's CURRENT tip — i.e. the card branch is not behind and a merge cannot
#         silently drop already-integrated work.
# Exit 1: divergence detected — the integration branch has commits since the card branch
#         was cut that a naive merge could revert. Do NOT fast-forward or checkout-merge;
#         inspect with `git log --oneline <card-branch>..<integration-branch>` first, and
#         merge with `git merge <card-branch> --no-edit` (real three-way), then diff.
# Exit 2: usage/argument error.

set -uo pipefail

REPO=${1:-}
INTEGRATION=${2:-}
CARD_BRANCH=${3:-}
DRY_RUN=0
[ "${4:-}" = "--dry-run-merge" ] && DRY_RUN=1

if [ -z "$REPO" ] || [ -z "$INTEGRATION" ] || [ -z "$CARD_BRANCH" ]; then
  printf 'usage: %s <repo> <integration-branch> <card-branch> [--dry-run-merge]\n' "$0" >&2
  exit 2
fi

git -C "$REPO" rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  printf 'not a git repository: %s\n' "$REPO" >&2
  exit 2
}

INTEG_TIP=$(git -C "$REPO" rev-parse "$INTEGRATION" 2>/dev/null) || {
  printf 'unknown integration branch/ref: %s\n' "$INTEGRATION" >&2
  exit 2
}
CARD_TIP=$(git -C "$REPO" rev-parse "$CARD_BRANCH" 2>/dev/null) || {
  printf 'unknown card branch/ref: %s\n' "$CARD_BRANCH" >&2
  exit 2
}

MERGE_BASE=$(git -C "$REPO" merge-base "$INTEGRATION" "$CARD_BRANCH" 2>/dev/null) || {
  printf 'could not compute merge-base between %s and %s\n' "$INTEGRATION" "$CARD_BRANCH" >&2
  exit 2
}

if [ "$MERGE_BASE" = "$INTEG_TIP" ]; then
  printf 'OK: %s (tip %s) is an ancestor of %s (merge-base matches integration tip).\n' \
    "$INTEGRATION" "$INTEG_TIP" "$CARD_BRANCH"
  printf 'A merge of %s into %s cannot revert prior work — safe to proceed with\n' \
    "$CARD_BRANCH" "$INTEGRATION"
  printf '  git -C %s merge %s --no-edit\n' "$REPO" "$CARD_BRANCH"
  printf 'then diff the result against the card'"'"'s Touch List before committing.\n'
  exit 0
fi

BEHIND_COUNT=$(git -C "$REPO" rev-list --count "$MERGE_BASE..$INTEG_TIP" 2>/dev/null || echo '?')
printf 'DIVERGENCE: %s has advanced %s commit(s) past the point %s branched from.\n' \
  "$INTEGRATION" "$BEHIND_COUNT" "$CARD_BRANCH" >&2
printf 'A fast-forward or checkout-based merge of %s could SILENTLY REVERT that work.\n' \
  "$CARD_BRANCH" >&2
printf '\nInspect what would be dropped:\n' >&2
printf '  git -C %s log --oneline %s..%s\n\n' "$REPO" "$MERGE_BASE" "$INTEG_TIP" >&2
printf 'Merge with a real three-way merge, never fast-forward:\n' >&2
printf '  git -C %s merge %s --no-edit\n\n' "$REPO" "$CARD_BRANCH" >&2
printf 'Then diff the whole tree against the card'"'"'s Touch List AND re-confirm every prior\n' >&2
printf 'card'"'"'s files are still present as expected before committing (RULES §3.9).\n' >&2

if [ "$DRY_RUN" = "1" ]; then
  printf '\n--dry-run-merge requested: simulating the merge (no commit, no fast-forward)...\n' >&2
  TMP_WT=$(mktemp -d)
  if git -C "$REPO" worktree add --detach "$TMP_WT" "$INTEG_TIP" >/dev/null 2>&1; then
    if git -C "$TMP_WT" merge "$CARD_TIP" --no-commit --no-ff >/dev/null 2>&1; then
      printf 'Simulated merge succeeded cleanly. Files that would change:\n' >&2
      git -C "$TMP_WT" diff --stat "$INTEG_TIP" >&2
    else
      printf 'Simulated merge produced conflicts — resolve them for real, not via checkout.\n' >&2
    fi
    git -C "$REPO" worktree remove --force "$TMP_WT" >/dev/null 2>&1
  else
    printf 'could not create a scratch worktree for the dry-run merge\n' >&2
    rm -rf "$TMP_WT"
  fi
fi

exit 1
