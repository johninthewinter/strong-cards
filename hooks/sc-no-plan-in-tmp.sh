#!/usr/bin/env bash
# PreToolUse / Write|Edit — no plan/card artifacts in tmp (RULES — durability).
#
# BLOCKS writing a plan/master-plan/roadmap/card-spec file (.md/.html) into any tmp
# directory: /tmp, $TMPDIR, ~/.claude/jobs/*/tmp/, or any path component literally
# named "tmp". Job tmp dirs are deleted when the job is deleted — a plan that only
# ever lived there is one `job delete` away from gone. On 2026-08-16 a day's worth of
# Strong Card master-plan + phase card specs sat for hours in
# ~/.claude/jobs/<id>/tmp/ before being rescued by hand.
#
# Plans belong in the repo (docs/plan/, CARD-*.md at repo root, or a dedicated
# worktree) where git is the durability mechanism, not a job's scratch space.

set -uo pipefail

INPUT=$(cat)
command -v jq >/dev/null 2>&1 || exit 0   # no jq: fail open, never wedge the session

FILE=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty')
[ -n "$FILE" ] || exit 0

# Only care about tmp-ish paths.
case "$FILE" in
  */tmp/*|*/.claude/jobs/*/tmp/*|/tmp/*) ;;
  *) exit 0 ;;
esac

# Only care about plan-shaped artifacts (.md or .html, plan/card/roadmap-flavored name).
BASENAME=$(basename "$FILE")
LOWER=$(printf '%s' "$BASENAME" | tr '[:upper:]' '[:lower:]')
case "$LOWER" in
  *.md|*.html) ;;
  *) exit 0 ;;
esac
case "$LOWER" in
  *plan*|*roadmap*|card-*|*-cards*|cards-*) ;;
  *) exit 0 ;;
esac

printf 'STRONG CARD: refusing to write a plan/card artifact into a tmp path.\n\n' >&2
printf '  %s\n\n' "$FILE" >&2
cat >&2 <<'EOF'
Job tmp dirs (~/.claude/jobs/<id>/tmp/, /tmp) are deleted with the job. A plan that
only lives there has no durability — git is the safety net, and tmp isn't tracked.

Write it into the repo instead:
  docs/plan/...                  (durable planning docs)
  CARD-<id>.md at repo root      (Strong Card specs, per RULES.md convention)
  a dedicated worktree           (if this is dispatch-scoped work)

If you genuinely need a scratch copy while iterating, write the real one to the repo
path first, then symlink or copy INTO tmp if a subprocess needs it there — never the
other way around.
EOF
exit 2
