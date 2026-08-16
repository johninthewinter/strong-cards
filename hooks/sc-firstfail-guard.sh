#!/usr/bin/env bash
# PostToolUse / Bash — set the Strong Card first-failure lock (RULES §4).
#
# Unlike sc-dispatch-postcheck.sh, this inspects direct controller-run pytest commands
# and pytest-shaped output from any Bash command. It is additive: the established dispatch
# FAILED/SUSPECT/CHECKPOINT messages remain owned by sc-dispatch-postcheck.sh.

set -uo pipefail

INPUT=$(cat)
command -v jq >/dev/null 2>&1 || exit 0

SCRIPT_DIR=$(CDPATH= cd "$(dirname "$0")" 2>/dev/null && pwd)
[ -r "$SCRIPT_DIR/sc-firstfail-lib.sh" ] || exit 0
# shellcheck source=./sc-firstfail-lib.sh
. "$SCRIPT_DIR/sc-firstfail-lib.sh"

CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')
[ -n "$CMD" ] || exit 0

# Field names for tool results have varied across Claude Code versions. Keep the same
# response/output fallback as the existing dispatch postcheck, with stderr/content added.
OUT=$(printf '%s' "$INPUT" | jq -r '
  (.tool_response // .tool_output // empty) as $t
  | if ($t|type) == "string" then $t
    elif ($t|type) == "object" then
      (($t.output // $t.stdout // $t.content // "") | tostring) + "\n" +
      (($t.stderr // "") | tostring) + "\n" +
      (($t.status // "") | tostring)
    else "" end' 2>/dev/null)
[ -n "$OUT" ] || OUT=$(printf '%s' "$INPUT" | tr -d '\000' | tail -c 20000)

# An explicit pytest command is inspectable even if it crashed before printing a summary.
# Otherwise, a pytest summary in output is sufficient regardless of the producing command —
# UNLESS the command is a pure read/inspection command (ls/cat/tail/grep/...), which cannot
# itself have executed a test suite no matter what failure-shaped text its output contains.
# RULES §14.1: this exact gap set the lock on routine `ls`/`tail`/`cat` investigation twice,
# 2026-08-16, nukegraph "The Write Path" — including once on this very hook's own source.
if sc_ff_is_pytest_command "$CMD"; then
  :
elif sc_ff_is_readonly_inspection_command "$CMD"; then
  exit 0
elif sc_ff_has_pytest_summary "$OUT"; then
  :
else
  exit 0
fi

LOW=$(printf '%s' "$OUT" | tr '[:upper:]' '[:lower:]')
STATUS=$(printf '%s' "$INPUT" | jq -r '
  (.tool_response // .tool_output // {})
  | if type == "object" then (.status // "") else "" end' 2>/dev/null \
  | tr '[:upper:]' '[:lower:]')
EXIT_CODE=$(printf '%s' "$INPUT" | jq -r '
  (.tool_response // .tool_output // {})
  | if type == "object" then (.exit_code // .exitCode // empty) else empty end' 2>/dev/null)

# Reuse and widen the established postcheck's objective signals. Do not infer failure from
# worker prose. In particular, "failing test" in a report is not itself a harness result.
FAILED=0
case "$STATUS" in error|failed|failure) FAILED=1 ;; esac
case "$EXIT_CODE" in
  ''|0) ;;
  *[!0-9]*) ;;
  *) FAILED=1 ;;
esac
case "$LOW" in
  *'"status":"error"'*|*'"status": "error"'*|*"command failed"*|*"non-zero exit"*) FAILED=1 ;;
  *"segmentation fault"*|*"killed"*|*"timed out"*|*"connection refused"*|*"panic:"*) FAILED=1 ;;
esac
printf '%s' "$LOW" | grep -qE 'exit (status|code)[[:space:]]+[1-9][0-9]*' && FAILED=1
# pytest summary lines: "3 failed, 490 passed" and "1 error" — never "0 failed".
printf '%s' "$LOW" \
  | grep -qE '(^|[^0-9])[1-9][0-9]*[[:space:]]+(failed|failures|errors?)([^[:alpha:]]|$)' \
  && FAILED=1

[ "$FAILED" = "1" ] || exit 0

HOOK_CWD=$(printf '%s' "$INPUT" | jq -r '.tool_input.cwd // .cwd // empty')
WORKTREE=$(sc_ff_worktree_for_command "$CMD" "$HOOK_CWD" 2>/dev/null || true)
if [ -z "$WORKTREE" ]; then
  WORKTREE=$(sc_ff_canonical_path "${HOOK_CWD:-$PWD}" "$PWD" 2>/dev/null || printf '%s' "${HOOK_CWD:-$PWD}")
fi

FAILED_AT=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
TEST_NAME=$(printf '%s\n' "$OUT" | grep -E '^(FAILED|ERROR)[[:space:]]+' \
  | head -n1 | sed -E 's/^(FAILED|ERROR)[[:space:]]+([^[:space:]]+).*/\2/' || true)
SUMMARY=$(printf '%s\n' "$OUT" \
  | grep -Ei '(^|[^0-9])[0-9]+[[:space:]]+(failed|passed|failures|errors?|skipped|deselected|xfailed|xpassed)' \
  | tail -n1 || true)

LOCK=$(sc_ff_lock_path "$WORKTREE" 2>/dev/null || true)
if [ -z "$LOCK" ]; then
  CTX="STRONG CARD FIRST-FAIL ENFORCEMENT ERROR — a failed pytest-shaped run was detected for:
$WORKTREE

The hook could not create its protected state directory, so it could not set the mandatory
first-failure lock. STOP: do not run the suite again. Dispatch the RULES §4 judge and repair
the hook state before continuing."
  jq -nc --arg ctx "$CTX" \
    '{hookSpecificOutput:{hookEventName:"PostToolUse", additionalContext:$ctx}}'
  exit 0
fi

LOCK_JSON=$(jq -nc \
  --arg failed_at "$FAILED_AT" \
  --arg worktree "$WORKTREE" \
  --arg test "$TEST_NAME" \
  --arg command "$CMD" \
  --arg summary "$SUMMARY" \
  '{failed_at:$failed_at, worktree:$worktree, test:$test, command:$command, summary:$summary}')
TMP_LOCK="$LOCK.tmp.$$"
(umask 077; printf '%s\n' "$LOCK_JSON" > "$TMP_LOCK") || exit 0

CREATED=0
if ln "$TMP_LOCK" "$LOCK" 2>/dev/null; then
  CREATED=1
fi
rm -f "$TMP_LOCK"

CLEAR_CMD=$(sc_ff_clear_command "$WORKTREE")
if [ "$CREATED" = "1" ]; then
  CTX="STRONG CARD FIRST-FAIL LOCK SET — the FIRST failed pytest-shaped run for this worktree
has activated a hard lock (RULES §4.1):

  worktree: $WORKTREE
  failing test: ${TEST_NAME:-not parseable from output}
  summary: ${SUMMARY:-not parseable from output}
  lock: $LOCK

A JUDGE MUST BE DISPATCHED NOW, before any further pytest/full-suite run against this worktree.
Do not retry, remediate, increase the timeout, or delete the lock manually. After the judge has
ruled and its concrete card edit/split is recorded, clear the lock with exactly:

  $CLEAR_CMD

Both arguments are mandatory and the helper appends the resolution to the audit log before it
removes the lock."
else
  CTX="STRONG CARD FIRST-FAIL LOCK ALREADY ACTIVE — another pytest-shaped command returned
failure for this locked worktree:

  worktree: $WORKTREE
  lock: $LOCK

This command should not have been retried. STOP and dispatch the RULES §4 judge. Only after the
judge has ruled and its concrete card edit/split is recorded may you run:

  $CLEAR_CMD"
fi

jq -nc --arg ctx "$CTX" \
  '{hookSpecificOutput:{hookEventName:"PostToolUse", additionalContext:$ctx}}'
exit 0
