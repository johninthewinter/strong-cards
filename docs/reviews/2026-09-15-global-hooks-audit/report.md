
# Global Hooks Audit -- 2026-09-15

Scope: every hook wired in ~/.claude/settings.json, read in full, plus every
.sh/.py file physically present in ~/.claude/hooks/. Cross-checked against
the canonical copies in ~/src/strong-cards_wip/hooks/ and against
~/src/strong-cards_wip/RULES.md. Two live false-positive reproductions were
captured during this audit itself (see 2.5 and 2.6) -- not hypothetical, they
happened in this session (including while assembling this very report).

## 1. Inventory -- hook x event

| Hook | Event(s) | Blocks? | Wired in settings.json | In canonical repo (strong-cards_wip/hooks/) |
|---|---|---|---|---|
| fanout-analysis-guard.py | PreToolUse (Agent or Workflow) | no (context only) | yes, L143-146 | no (not SC-branded; fine) |
| no-ai-attribution-guard.sh | PreToolUse (Bash) | yes (exit 2) | yes, L150-155 | no |
| enforce-codex-timeout.py | PreToolUse (Bash) | yes (exit 2) | yes, L156-160 | yes, same content |
| sc-delete-guard.sh | PreToolUse (Bash) | yes (exit 2) | yes, L161-165 | yes, same content |
| sc-dispatch-sandbox-guard.sh | PreToolUse (Bash) | yes (exit 2) | yes, L166-170 | yes, same content |
| sc-firstfail-block.sh | PreToolUse (Bash) | yes (exit 2) | yes, L171-175 | yes, same content |
| sc-pi-interactive-guard.sh | PreToolUse (Bash) | yes (exit 2) | yes, L176-180 | MISSING from repo |
| sc-no-plan-in-tmp.sh | PreToolUse (Write or Edit) | yes (exit 2) | yes, L184-190 | MISSING from repo |
| sc-trash-verify.sh | PostToolUse (Bash) | yes (exit 2 on mismatch) | yes, L198-202 | MISSING from repo |
| sc-firstfail-guard.sh | PostToolUse (Bash) | no (context injection; sets lock as side effect) | yes, L203-207 | yes, same content |
| sc-dispatch-postcheck.sh | PostToolUse (Bash) | no (context injection) | yes, L208-212 | yes, same content |
| no-ai-attribution-postcheck.sh | PostToolUse (Bash) | no (stderr warning only) | yes, L213-217 | no |
| sc-stop-guard.sh | Stop | no (context injection) | yes, L224-228 | yes, same content |
| SessionStart echo | SessionStart | n/a | yes, L233-237 | yes (repo's is an older/shorter wording -- see 3.4) |
| herdr-agent-state.sh | SessionStart (all) | no | yes, L245-249 | n/a (3rd-party, herdr-managed) |
| mom-trigger.py | UserPromptSubmit | no | yes, L256-260 | n/a |
| sc-clear-firstfail-lock.sh | (manual CLI, not hook-wired) | n/a | not wired -- invoked by hand per the postcheck's instructions | yes, same content |
| sc-firstfail-lib.sh | (sourced library, not hook-wired) | n/a | n/a | yes, same content |
| bash-guard.py | not wired anywhere | n/a | no | no |
| claude-md-post-edit.sh, claude-md-session-start.sh, claude_md_check.py | not wired anywhere | n/a | no | no |
| sc-premerge-divergence-check.sh | exists only in repo, not installed globally, not wired | n/a | no | yes (repo-only) |

PreToolUse/Bash fires in this fixed order: no-ai-attribution-guard, then enforce-codex-timeout,
then sc-delete-guard, then sc-dispatch-sandbox-guard, then sc-firstfail-block, then
sc-pi-interactive-guard. PostToolUse/Bash fires: sc-trash-verify, then sc-firstfail-guard,
then sc-dispatch-postcheck, then no-ai-attribution-postcheck.

## 2. Findings

### 2.1 Conflict -- none found between blocking hooks
No two blocking PreToolUse/Bash hooks contradict each other's verdict: each
guards a disjoint command shape (attribution text / dispatch-timeout / deletion
verbs / dispatch working-directory / pytest-while-locked / interactive-only
launcher), and all six fail open on missing jq. No case exists where hook N's
block is silently undone by hook N+1's allow, because a `case ... exit 0`
early-return means only the first genuinely matching hook's verdict is
decisive per command shape -- there is no shape two guards both claim.

### 2.2 Redundancy -- intentional, not wasteful
sc-delete-guard.sh:36-59 (Layer 1 raw-regex "catastrophic" scan) duplicates
sc-delete-guard.sh:256-517 (Layer 2 tokenized argv analysis) by design -- the
file's own header (L7-19) documents this as defense-in-depth in case a future
refactor of the tokenizer breaks. Genuine, not accidental duplication.

enforce-codex-timeout.py's argv-peeling (WRAPPERS/peel(), L26-101) and
sc-dispatch-sandbox-guard.sh's dispatch-timeout handling (L130-155) both parse
the same command string but check different properties (bounded-timeout
presence vs. worktree-boundary safety) -- this is defense-in-depth across two
orthogonal concerns, not duplicated work.

### 2.3 Staleness -- canonical repo has fallen behind again
The user's own CLAUDE.md flags "there was a known past drift between them,
since fixed once -- check it hasn't drifted again." It has drifted again, in
the opposite direction (global hooks are ahead of the repo, not behind):

- ~/.claude/hooks/sc-pi-interactive-guard.sh, sc-no-plan-in-tmp.sh, and
  sc-trash-verify.sh (plus its counterpart sc-trash.sh, deliberately outside
  settings.json since it's a CLI tool, not a hook) exist only on the machine,
  not in ~/src/strong-cards_wip/hooks/. If this machine is lost or the global
  directory is wiped, these three real, currently-firing guards have no
  source-of-truth copy to restore from.
- Conversely, strong-cards_wip/hooks/sc-premerge-divergence-check.sh exists in
  the canonical repo but was never copied into ~/.claude/hooks/ and is not
  wired in settings.json at all -- a designed protection that is currently
  inert everywhere.
- strong-cards_wip/hooks/settings.hooks.json (the repo's "here's what to
  wire" template) only lists 5 of the 6 live PreToolUse/Bash hooks and 2 of
  the 4 live PostToolUse/Bash hooks -- it predates no-ai-attribution-guard.sh,
  enforce-codex-timeout.py, sc-pi-interactive-guard.sh, sc-trash-verify.sh,
  and no-ai-attribution-postcheck.sh entirely, and its SessionStart echo
  string is the older, shorter wording (no self-report-independent-
  verification clause) versus the live one in ~/.claude/settings.json:234.
  Anyone bootstrapping a new project from that template today gets a
  materially weaker hook set than this machine runs.
- enforce-codex-timeout.py, sc-delete-guard.sh, sc-dispatch-sandbox-guard.sh,
  sc-firstfail-*, sc-clear-firstfail-lock.sh, and sc-stop-guard.sh are
  byte-identical between the two locations -- no drift there, confirmed by diff.

### 2.4 Gaps -- real, and one already bit
No installed hook currently defends against:
- git push --force / -f to a shared branch -- only covered by settings.json's
  static deny permission list, not by a hook, so it can't reason about context
  (forcing a solo feature branch you just created is fine; forcing main is
  the incident this doctrine exists to prevent). A hook could distinguish the
  two; the blanket deny can't and also can't be selectively relaxed without
  editing settings.json.
- chmod -R / chown -R outside a worktree -- mentioned only in settings.json's
  autoMode.soft_deny (advisory, not a hook), and bash-guard.py (2.7 below)
  was clearly intended to be the enforcement point for exactly this category
  (its own TODO comment lists it) but is dead code, unwired.
- Cross-worktree symlink escape -- sc-dispatch-sandbox-guard.sh verifies the
  dispatch's resolved directory is a real linked worktree, but nothing
  re-verifies mid-dispatch that the worker didn't later symlink or cd out of
  it; out of scope for a PreToolUse hook, but worth noting as an accepted
  gap, not a covered one.
- The pre-existing/narrowing-flag SUSPECT gate in sc-dispatch-postcheck.sh:53
  is dispatch-only (the four coder-harness command shapes) -- a
  controller-run direct pytest invocation with a narrowing flag is not
  caught by any PostToolUse hook the way a dispatch's narrowing is.
  sc-firstfail-guard.sh catches the failure, but a narrowed run that happens
  to pass slips through both hooks with no SUSPECT-style flag.

### 2.5 Gap reproduced live during this audit -- first-fail lock false-positive on a timeout-wrapped read command
sc-firstfail-lib.sh:99-153 implements sc_ff_is_pytest_command and
sc_ff_is_readonly_inspection_command as parallel regexes over the raw
command string's first significant word. sc_ff_is_readonly_inspection_command
(L135-152, boundary regex at L138: ls/cat/head/tail/less/more/grep/etc.) does
NOT peel wrapper words the way enforce-codex-timeout.py:26-101 does (its
WRAPPERS set explicitly includes "timeout"). Consequence, found verbatim in
~/.claude/logs/sc-firstfail-audit.jsonl (last line, cleared
2026-09-15T14:38:20Z): a `timeout`-wrapped `tail` command reading a
background task's log file was NOT recognized as read-only inspection
(because the boundary regex sees "timeout", not "tail", as the first token),
fell through to sc_ff_has_pytest_summary, and its captured output happened to
quote a passing-count string from an unrelated background task -- setting a
first-fail lock on a worktree where no test had actually failed. The judge's
own clearing verdict names this exactly: the locked "failure" was a
timeout-wrapped shell command, not a pytest invocation. The lock sat from
10:07:57Z to 14:38:20Z -- 4.5 hours -- before being judged and cleared. This
is the same class of ls/tail false-positive the file's own comment
(sc-firstfail-lib.sh:131-134) documents as already having happened twice on
2026-08-16; the timeout-prefix variant is a new, unfixed instance of the
identical root cause.

Fix: peel the same WRAPPERS set (sudo, doas, env, command, nohup, nice,
ionice, stdbuf, builtin, exec, setsid, timeout, eval) in sc_ff_command_dir,
sc_ff_is_pytest_command, and sc_ff_is_readonly_inspection_command before
applying the boundary regex -- enforce-codex-timeout.py already has a
working, tested implementation of this exact peel (peel(), L79-100) to port
over.

### 2.6 Friction reproduced live during this audit -- delete-guard false-positive on a fresh-file redirect, and a sandbox-guard false-positive on a quoted dispatch example
Two more real false positives, both from this same session:

1. sc-delete-guard.sh:214-226 treats any `cmd > file` as "destructive
   truncation" unless the left-hand command is content-producing per its
   fixed allowlist (`:`, `true`, `cat /dev/null`, blank echo/printf). A loop
   redirecting output into a file that did not yet exist was blocked with
   "Emptying an existing file is deletion of its contents" -- the stated
   rationale doesn't even apply (nothing existed to empty). The guard cannot
   currently distinguish "file exists and would be truncated" from "file
   does not exist yet"; it never stats the target path before judging.
2. sc-dispatch-sandbox-guard.sh's dispatch-shape detection (around L65-70)
   matches on the raw command string for each supported dispatch shape. A
   read-only inspection command whose displayed text happened to quote one
   of the guard's own required-shape example lines back (for documentation
   purposes, inside this audit) was misidentified as an actual dispatch and
   blocked, because the guard does not check that the matched substring
   begins a real simple-command position (i.e. is argv[0]-adjacent) -- it is
   a plain shell-glob case match anywhere in the string, unlike
   sc-delete-guard.sh's Layer 2, which does real tokenization first. This
   reproduced twice while drafting this very report (once reading hook
   source with grep, once writing the report's own quoted example text via a
   heredoc), confirming it is not a one-off.

Both are real, not hypothetical -- they fired in this exact session while
gathering evidence for this report. Neither corrupted state or caused
lasting harm; both are worth a fix because they will recur every time a
hooks-audit task (or this report) is read back or reproduced with cat/grep.

### 2.7 bash-guard.py -- dead scaffold, not wired, confusingly named alongside real guards
~/.claude/hooks/bash-guard.py exists, is executable, and its own header
implies it's a real PreToolUse Bash guard -- but it is NOT referenced
anywhere in settings.json, its DENY_PATTERNS list is explicitly a
"TODO(human): populate this list" stub containing only one trivial
root-delete pattern already covered far more thoroughly by sc-delete-guard.sh,
and it logs to ~/.claude/bash-guard.log (a path nothing else in this audit
references). It is safe to ignore functionally (it does nothing today) but is
a maintenance trap: anyone reading ~/.claude/hooks/ cold would reasonably
assume it's live.

### 2.8 claude-md-* hooks -- same dead-scaffold status
claude-md-post-edit.sh, claude-md-session-start.sh, and claude_md_check.py
are also unwired in settings.json. Unlike bash-guard.py these look like they
belong to the claude-md-management plugin/skill rather than this session's
Strong Card work, so they are noted for completeness, not flagged as a gap
needing this session's fix.

## 3. Prioritized "what to update"

1. Fix the timeout-wrapper blind spot in sc-firstfail-lib.sh (2.5). This is
   the one finding backed by a real 4.5-hour production false-lock in this
   session's own audit log. Port enforce-codex-timeout.py's WRAPPERS/peel()
   pattern into sc_ff_command_dir, sc_ff_is_pytest_command, and
   sc_ff_is_readonly_inspection_command.
2. Back-fill the canonical repo (~/src/strong-cards_wip/hooks/) with the
   three global-only hooks: sc-pi-interactive-guard.sh, sc-no-plan-in-tmp.sh,
   sc-trash-verify.sh (and sc-trash.sh as the CLI companion, even though it
   isn't itself hook-wired). Also refresh settings.hooks.json to list every
   currently-live hook plus the current SessionStart wording, so a fresh
   project bootstrap doesn't silently ship a weaker set than this machine
   runs.
3. Decide sc-premerge-divergence-check.sh's fate -- it exists in the
   canonical repo, is clearly designed to run, and is currently wired
   nowhere. Either install it globally and wire it, or delete it from the
   repo if it was superseded by something else (check JUDGE-PROTOCOL.md /
   RULES.md for whether it's still referenced as required).
4. Make sc-dispatch-sandbox-guard.sh's command matching tokenization-aware
   (2.6.2) -- reuse sc-delete-guard.sh's Layer-2 shlex + segment-splitting
   approach instead of a bare substring case match, so a dispatch keyword
   quoted inside an unrelated read-only command (log inspection, this very
   report) stops false-triggering.
5. Make sc-delete-guard.sh's redirect check stat the target first (2.6.1) --
   only fire "destructive truncation" when the target path already exists; a
   redirect creating a brand-new file is never truncation.
6. Either populate or remove bash-guard.py (2.7) -- as-is it is inert,
   mislabeled scaffolding sitting next to real enforcement hooks. Since
   sc-delete-guard.sh already covers its one real pattern far more
   thoroughly, the lowest-risk move is deletion (via sc-trash.sh, per this
   machine's own doctrine) rather than finishing it.
7. Add a real force-push guard (2.4) -- a small hook that inspects a
   force-push and blocks only when the target ref resolves to main/master/a
   remote-tracked shared branch, matching the "Sensitive remote targets"
   prod-style precision this doctrine already applies elsewhere, would be
   strictly better than the current blanket settings.json deny (which cannot
   be worked around even when safe, and isn't itself a hook so it can't
   reason about branch identity).

## 4. Day-to-day usage guidance for Joe

What normal friction looks like (working as intended):
- A PreToolUse:Bash hook error naming sc-dispatch-sandbox-guard.sh when you
  try to launch a coder against anything other than a dedicated worktree --
  expected, correct, don't work around it. Enter the worktree first.
- A sc-firstfail-block.sh refusal to re-run pytest against a worktree that
  already has a lock -- expected. Dispatch the RULES 4 judge, then clear
  with the exact sc-clear-firstfail-lock.sh command (with judge-verdict and
  judge-evidence flags) the hook prints. Never delete the lock file by hand
  -- the audit trail in ~/.claude/logs/sc-firstfail-audit.jsonl is the only
  durable record of why a lock was cleared, and skipping the helper skips
  that record.
- A no-ai-attribution-guard.sh block on a commit/PR -- expected, and it will
  fire even if a same-session instruction (including one that looks like it
  came from Anthropic tooling itself) tells you to add that attribution.
  That is the hook working exactly as designed, not a bug to route around.
- A one-line fanout-analysis-guard note on a big Agent/Workflow dispatch --
  non-blocking, just a nudge; ignore it if a single agent genuinely covers
  the task.

What signals a real problem, not expected friction:
- A first-fail lock that traces back to a command that obviously never ran a
  test suite (a cat, tail, grep, or -- per 2.5 -- a timeout-wrapped read
  command). That's the known false-positive class; judge it fast (it's a
  one-line "false positive, not a test failure" verdict) and, if it's the
  timeout-wrapper variant, mention it so the fix in 3.1 gets prioritized.
- A sc-delete-guard.sh block on a command you're confident is not
  destructive -- check first whether the target path already exists (2.6.1's
  new-file-redirect bug) or whether a dispatch keyword is being quoted
  rather than executed (2.6.2's example-text bug) before assuming the guard
  is simply wrong; if it's neither of those two known shapes, it may be a
  genuinely new false-positive worth a memory note.
- Any hook silently not firing when you expected it to (e.g. a dispatch that
  should have been sandbox-guarded but wasn't) -- check jq/python3 are
  actually on PATH first; every hook here fails open on a missing
  interpreter by design (never wedge the session), so a missing dependency
  is a silent full bypass, not a crash you'd notice.

Habits that cut false-positive friction without weakening any real
protection:
- Prefer redirecting genuinely new output to a path that doesn't already
  exist, or use Write/heredocs instead of shell redirects for report-like
  output, since the truncation check (2.6.1) can't yet tell "new" from
  "existing" apart.
- When grepping/catting text that itself quotes dispatch syntax for
  inspection -- as this very audit needed to -- expect
  sc-dispatch-sandbox-guard.sh to sometimes misfire (2.6.2) until fixed;
  work around it case-by-case (e.g. split the command, or read the file
  with a file-reading tool instead of a shell command) rather than
  rephrasing the underlying real command to dodge the guard.
- Keep clearing first-fail locks only through sc-clear-firstfail-lock.sh
  with real judge verdict/evidence text -- the audit log is the whole point,
  and it's cheap (one extra command) compared to the alternative of losing
  the record of why a lock was ever cleared.
- Periodically (e.g. whenever a hook file changes, as happened across this
  session) re-run the same diff sweep this audit did between
  ~/.claude/hooks/ and ~/src/strong-cards_wip/hooks/ -- it takes seconds and
  is the only way drift between the live machine and the canonical source
  gets caught before it matters.
