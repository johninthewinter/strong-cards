#!/usr/bin/env bash
# PostToolUse / Bash — Strong Card post-dispatch checkpoint (RULES §4, §5).
#
# The tool already ran; this hook cannot undo it. What it CAN do is inject an instruction
# into Claude's context via hookSpecificOutput.additionalContext, so the session cannot
# quietly accept a self-report or blind-retry a failure.
#
# It CANNOT invoke the Sonnet judge itself (see hooks/README.md). It forces the session to.

set -uo pipefail

INPUT=$(cat)
command -v jq >/dev/null 2>&1 || exit 0

CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')
[ -n "$CMD" ] || exit 0

case "$CMD" in
  *"opencode run"*|*"opencode2 run"*|*"claude-local -p"*|*"strong-card-runner"*) ;;
  *) exit 0 ;;
esac
case "$CMD" in *" --help"*) exit 0 ;; esac

# Field name for tool results has varied across versions — read both, plus a raw fallback.
OUT=$(printf '%s' "$INPUT" | jq -r '
  (.tool_response // .tool_output // empty) as $t
  | if ($t|type) == "string" then $t
    elif ($t|type) == "object" then (($t.output // $t.stdout // "") | tostring) + " " + (($t.status // "")|tostring)
    else "" end' 2>/dev/null)
[ -n "$OUT" ] || OUT=$(printf '%s' "$INPUT" | tr -d '\000' | tail -c 20000)

LOW=$(printf '%s' "$OUT" | tr '[:upper:]' '[:lower:]')
STATUS=$(printf '%s' "$INPUT" | jq -r '(.tool_response // .tool_output // {}) | if type=="object" then (.status // "") else "" end' 2>/dev/null)

# Key the failure gate on the HARNESS outcome and unambiguous crash strings — NOT on the
# worker's prose. A correct fail-first report legitimately contains "AttributeError",
# "exception", "failing test": matching those produced a false gate on a clean R16-shaped
# report during testing. Prose claims are the SUSPECT gate's job, below.
FAILED=0
[ "$STATUS" = "error" ] && FAILED=1
case "$LOW" in
  *'"status":"error"'*|*"exit status 1"*|*"exit code 1"*|*"command failed"*|*"non-zero exit"*) FAILED=1 ;;
  *"segmentation fault"*|*"killed"*|*"timed out"*|*"connection refused"*|*"panic:"*) FAILED=1 ;;
esac
# pytest summary lines: "3 failed, 490 passed" — but never "0 failed".
printf '%s' "$LOW" | grep -qE '[1-9][0-9]* (failed|failures|errors)' && FAILED=1
# Near-empty output after a dispatch is the silent-clean-crash signature (RULES §11).
CRASH=0
[ "${#OUT}" -lt 120 ] && { CRASH=1; FAILED=1; }

SUSPECT=0
case "$LOW" in *"pre-existing"*|*"preexisting"*|*"unrelated"*|*"--ignore"*|*" -k "*|*"skip"*) SUSPECT=1 ;; esac

# Accumulate every signal that fired, then emit once. Emitting on the first match lets a
# broad indicator mask a more specific one — e.g. a near-empty-output guess hiding a
# "pre-existing" claim, which is the single most dangerous string a worker can return.
CTX=""
add() { CTX="${CTX}${CTX:+

}$1"; }

if [ "$FAILED" = "1" ]; then
  add "STRONG CARD GATE — this dispatch shows failure/stall/crash indicators$( [ "$CRASH" = 1 ] && printf ' (near-empty output: check the silent-clean-crash signature, RULES §11)' ).

MANDATORY before any retry (RULES §4.1 — never blind-retry):
1. Probe first, do not just report elapsed time (RULES §6): model-server health via curl,
   log file mtime, last tool call in the transcript.
2. Run the per-card judge: Agent tool, model=\"sonnet\", low reasoning effort. Give it the
   full card, the failure transcript, the probe evidence, your independent verification,
   and strong-cards RULES.md. See JUDGE-PROTOCOL.md §1.
3. Default hypothesis is THE CARD, not the model: scope too large / missing second defect
   site / ambiguity / stale line refs / context bloat. Only fall back to infra when the
   transcript positively fails to support a card defect.
   Exception, and only this one: the silent-clean-crash signature (zero error, zero partial
   edits, model server healthy, few clean steps) — RULES §11. Confirm the signature; do not
   assume it. 3 occurrences logged; on the 4th, open a real infra investigation.
4. The judge must also answer: does this reveal a NEW general lesson? If yes, write it into
   strong-cards RULES.md and/or hooks/ (JUDGE-PROTOCOL.md §1.5). Fixing one card is half the job.
5. Re-dispatch into a FRESH worktree — never reuse the failed one, it may hold out-of-scope damage."
fi

if [ "$SUSPECT" = "1" ]; then
  add "STRONG CARD GATE — this dispatch's output contains a 'pre-existing / unrelated' claim
and/or test-narrowing flags (--ignore / -k / skip). This is the exact shape of the false
report that hid a destroyed production module on 2026-08-10 (RULES §5.2, §5.3).

DO NOT accept it. Disprove or confirm it yourself:
1. git -C <worktree> status --porcelain   # deletions and untracked files the diff hides
2. git -C <worktree> diff --stat          # WHOLE tree — compare against the card's Touch List
3. Re-run the FULL suite yourself, WITHOUT the worker's added --ignore/-k flags, twice.
4. To verify 'pre-existing': check out the baseline commit and show the same test failing
   there. If you cannot demonstrate it at baseline, it is NOT pre-existing — it is this
   card's breakage.
5. Any file changed outside the Touch List is a finding, even if it looks harmless."
fi

add "STRONG CARD CHECKPOINT — a dispatch just returned. Its self-report is not acceptance
evidence (RULES §5). Before marking anything DONE:
1. git -C <worktree> status --porcelain  and  git -C <worktree> diff --stat  — whole tree,
   compared against the card's Touch List. Deletions are the highest-severity finding.
2. Grep the actual code for the claimed change at the claimed location.
3. Run the tests yourself, twice; record YOUR pass count, not the worker's (a worker's
   '492 passed' was flaky when the stable count was 505).
4. Then commit inside the worktree, merge the card branch, remove the worktree (RULES §2.2, §3.4)."

jq -nc --arg ctx "$CTX" \
  '{hookSpecificOutput:{hookEventName:"PostToolUse", additionalContext:$ctx}}'
exit 0
