# hooks — making the Strong Card rules structural

The rules in `RULES.md` fail the moment a session forgets them. These hooks make two of them
mechanical: the sandbox rule is genuinely **enforced** (blocked at the tool call), and the
verify/judge rules are **forced into the session's context** at the moment they apply.

## Install

```bash
mkdir -p <project>/.claude/hooks
cp hooks/sc-*.sh <project>/.claude/hooks/
chmod +x <project>/.claude/hooks/sc-*.sh
# merge the "hooks" key from hooks/settings.hooks.json into <project>/.claude/settings.json
```

Requires `jq` and `git` on `PATH`. Every script fails **open** if `jq` is missing — a hook
must never wedge a session. Restart Claude Code (or `/hooks`) after editing settings;
hook config is snapshotted at startup.

## What each hook does

| Hook | Event | Enforces | Mechanism |
|---|---|---|---|
| `sc-dispatch-sandbox-guard.sh` | `PreToolUse` / `Bash` | RULES §2, §3 | **Blocks** (exit 2) any `opencode run` / `claude-local -p` dispatch whose `--dir` is missing, not in a git repo, points at the primary working tree, or is dirty. |
| `sc-dispatch-postcheck.sh` | `PostToolUse` / `Bash` | RULES §4, §5 | Injects the verification checklist after every dispatch; escalates the wording when the output shows failure indicators, or contains a "pre-existing / unrelated" claim or added `--ignore` flags. |
| `sc-stop-guard.sh` | `Stop` | RULES §2.2, §3.4 | Injects a finding when the turn ends with uncommitted changes, dangling dispatch worktrees, or untracked source directories. |
| inline `echo` | `SessionStart` | all | Loads the rules summary into context at session start. |

## What a hook CAN do

- **Block a tool call.** `PreToolUse` + exit code 2 prevents the call; stderr is fed back to
  Claude as the reason. This is real enforcement, not a reminder — the sandbox guard uses it,
  and it is the only rule in this repo that a hook can genuinely make impossible to violate.
- **Inject text into Claude's context.** Exit 0 with JSON on stdout:
  ```json
  {"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"…"}}
  ```
  The text becomes a system reminder the session reads and acts on. `additionalContext` must
  be **nested inside `hookSpecificOutput`** — at the top level it is silently ignored.
  `SessionStart` is simpler: plain stdout text goes straight into context.
- **Run any shell logic** — `git status`, `git diff`, log freshness, curl a health endpoint.
  The `PreToolUse`/`PostToolUse` payload arrives as JSON on stdin (`tool_name`, `tool_input`,
  `cwd`, `session_id`, `transcript_path`, …).

## What a hook CANNOT do — read this before trusting it

1. **A `command` hook cannot invoke the Sonnet judge.** It is a shell command. It cannot start
   an LLM turn, cannot call the `Agent` tool, cannot run a slash command. Everything the
   post-dispatch and stop hooks emit is an *instruction to the running Claude Code session*.
   The judge pass in `JUDGE-PROTOCOL.md` §1 still requires that session to act on it.
   **The achievable goal is not autonomy — it is that the session structurally cannot fail to
   notice.** That is a large improvement over a rule someone has to remember, and it is not
   the same thing as automation. Do not describe these hooks as "the judge runs automatically."
   - Caveat for the curious: current docs also list `"type": "prompt"` and `"type": "agent"`
     hooks that *do* invoke a model. They are constrained (single-turn / short timeouts, a
     `{"ok":…, "reason":…}` return shape) and were **not verified on this machine**. They
     cannot run the full judge protocol — reading a card plus a long transcript and writing
     back an edited card and a rules amendment is well past their envelope. If you want to
     experiment, treat it as a bonus signal, never as the judge.
2. **`matcher` filters on tool NAME only, not on the command string.** `"matcher": "Bash"`
   fires on every Bash call; deciding "is this a Strong Card dispatch?" happens inside the
   script (each one greps `.tool_input.command` and exits 0 immediately if it does not match).
   Docs also describe an `if:` field taking permission-rule syntax (`"Bash(git *)"`) for
   pre-filtering — unverified here; the scripts do not depend on it.
3. **`PostToolUse` cannot undo the tool call.** The dispatch already ran. Exit 2 there only
   surfaces an error into the transcript. The only thing that prevents damage is the
   `PreToolUse` sandbox guard, which is why that one is the hook that matters most.
4. **A hook cannot detect a stall on its own.** Hooks fire on events, not on a timer. Nothing
   here notices that a background dispatch has been silent for 40 minutes — that is why
   RULES §7 requires an active `Monitor` poll paired with every background dispatch, and why
   `JUDGE-PROTOCOL.md` §1.2 is a judgment heuristic for the operator rather than a hook.
5. **Field-name drift.** The tool-result field has appeared as both `tool_response` and
   `tool_output` across versions; `sc-dispatch-postcheck.sh` reads both plus a raw fallback.
   If a hook goes quiet after an upgrade, check that first — run `claude --debug` and look at
   the hook's stderr.

## Detection heuristics — and why they are split the way they are

`sc-dispatch-postcheck.sh` runs three independent gates and emits every one that fires
(emitting on the first match let a broad signal mask a narrower one during testing):

- **Failure gate** keys on the *harness outcome* — `tool_response.status == "error"`,
  non-zero exit strings, `killed` / `timed out` / `connection refused`, and a pytest summary
  matching `[1-9][0-9]* (failed|failures|errors)`. It deliberately does **not** match the
  worker's prose. An early version matched bare `error`/`exception` and false-fired on a
  perfectly clean report, because correct fail-first evidence *is* an `AttributeError`.
- **Suspect gate** keys on prose, and only on the phrases that hid real damage on 2026-08-10:
  `pre-existing`, `unrelated`, `--ignore`, `-k`, `skip`.
- **Checkpoint** always fires on a dispatch. Even a flawless-looking report gets the
  verify-before-DONE list, because a flawless-looking report is what a false self-report
  looks like.

Tests for all five scenarios are in the "Test them" snippet's spirit; re-run them after
editing the patterns.

## Tuning

- **Other harnesses**: add your dispatch command's signature to the `case` patterns at the top
  of the sandbox guard and the postcheck. Both currently match `opencode run`, `opencode2 run`,
  `claude-local -p`, and `strong-card-runner`.
- **Worktree location**: the guard does not care where worktrees live — it asks git
  (`--absolute-git-dir` vs `--git-common-dir`) whether the path is a *linked* worktree. Any
  layout works; `../.wt/card-<slug>` is just the convention.
- **False block?** The guard blocks on a dirty worktree because a dirty tree makes the
  post-dispatch diff unreadable. Commit or stash — do not loosen the guard.

## Test them

```bash
echo '{"tool_name":"Bash","cwd":"'"$PWD"'","tool_input":{"command":"opencode run --dir . -f card.md"}}' \
  | .claude/hooks/sc-dispatch-sandbox-guard.sh; echo "exit=$?"   # expect exit=2 in a primary tree
echo '{"hook_event_name":"Stop","cwd":"'"$PWD"'"}' \
  | .claude/hooks/sc-stop-guard.sh; echo "exit=$?"               # expect exit=0 + JSON if dirty
```
