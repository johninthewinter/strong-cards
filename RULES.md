# RULES — the Strong Card global ruleset

Two tiers. §1 is philosophy: the lens you judge a move by. §2 onward are **operational
rules** — mechanical, checkable, and in the case of §2 and §3, non-negotiable. Every rule
below states its **Why** from a real observed incident. Nothing here is speculative.

Evidence base: `runs/2026-08-nukegraph-r1-r20/RETROSPECTIVE.md`.

---

## §1 — The Grandmaster Doctrine (philosophical base)

*Verbatim from `~/.claude/CLAUDE.md`. A bounded unit of work is a Strong Card; acceptance
is earned, never self-reported.*

1. **Play the whole board — grand-ensemble first.** Before: does it belong, fit the system, serve the plan? After: does it work WITH the other pieces — no orphan, no spaghetti, no drift? **System coherence outranks local correctness.** Before any cut / rename / decommission, sweep every consumer first (grep what `@include`s / sources / imports / names it).
2. **Right piece, right square, right purpose.** Good model, good place, good purpose. Minimum force when it wins, heavier when the position demands — **size follows need, never habit.**
3. **Judgment before the loop.** Map blast radius + seams; resolve architecture *outside* the worker. Verify production state before naming prod shapes.
4. **A bounded move is a Strong Card** `SC=(I,O,S,B,G,R,E)` — validated, then **frozen & hashed before coding.** The `ACCEPT | RETRY | STOP | INVALID_CARD` call is the controller's (deterministic), never the model's.
5. **Green = proven AND unbroken.** Acceptance = **CONFIRM × BREAK, gated by FIT.** CONFIRM = a cost-ordered gauntlet (Tier 0 deterministic $0: lint / type / stub-scan / tests+gherkin / coverage / mutation → peer → stronger model → MoM, escalate only on failure). BREAK = an independent, sandboxed adversary told to *make the card fail*. FIT = one judge returns FIT / NO_FIT. **Coder ≠ grader ≠ breaker.** Worker self-report is never acceptance evidence.
6. **Never assume; state the inexorable assumption.** Naming a shape — code, path, product capability, dependency — without reading it = STOP and verify. `INVALID_CARD` is honorable.
7. **Fit, not size — the anti-spaghetti law.** Cut what doesn't serve; keep/add what does. Never cut to look lean, never add to look thorough. Burden of proof is on the cut.
8. **No stub unless intended; no silent tech debt; surgical.** Every changed line traces to the request. Scope grows mid-flight → surface the full cost, don't ship "minimum + defer."
9. **Comment the *why*; boring over clever; teach master→padawan.**

*Failure-mode → gate: unwanted→P1/P2 · overengineered→P7 · untested→gauntlet · doesn't-fit→FIT · drifted→P4 frozen Objective · survives-but-fragile→BREAK.*

The card object `SC=(I,O,S,B,G,R,E)` and the 7-section coder contract are defined in
`~/.claude/reference/contract-and-card-template.md`; `CARD-TEMPLATE.md` here is its
operational instantiation.

---

## §2 — PERMANENT RULE: everything is under git, always

**RULE 2.1 — No dispatch against an untracked tree. Ever.**
Before the first card of any run, every source directory the worker could reach is
committed to git. If a subtree is untracked, committing it as a baseline is a prerequisite
task, not a nice-to-have.

**RULE 2.2 — Every verified card is committed.**
A card is not DONE until its change is a commit. `git add && git commit` happens inside the
worktree, before the merge (see §3). One commit per card, message naming the card ID.

**RULE 2.3 — `.gitignore` is a hazard surface, audit it.**
An over-broad ignore pattern silently swallows real files. On 2026-08-10 a `.venv/` pattern
matched *any* nested directory, not just the repo root, and silently ate a worker's new test
fixture. Anchor patterns (`/.venv/`, not `.venv/`) and add explicit keep-rules
(`!docs/reviews/**`) for trace directories.

> **Why.** On 2026-08-10 a worker deleted `workspace/autosave.py` — a shipped, previously
> tested crash-safety module with a 150-round SIGKILL-survival test — and regressed two
> sibling files to stubs. The `py/` tree had been untracked since the project started, so
> **there was nothing to revert to.** Recovery took three extra cards and only succeeded
> because leftover prototype files happened to still exist. That is luck, not process.
> Joe, verbatim: *"NEW RULE WE ALWAYS HAVE VERSIONNING AND COMMIT TO GIT"* /
> *"I GAVE A GIT AT THE VERY START OF THE PROJECT, FOR WHAT? FUN?"*

**How to apply.** At run start: `git status` must show a clean, tracked tree.
`git log --oneline -1` is the recorded baseline in the run tracker. If `py/`, `src/`, or any
other source root is untracked — stop, commit it, note the baseline commit hash, then begin.

---

## §3 — PERMANENT RULE: every dispatch is sandboxed in its own git worktree

**RULE 3.1 — One worktree per dispatch.**
```bash
git worktree add ../.wt/card-<slug> -b card/<slug>
```
The worker gets **only** that path. Nothing shared with the main working tree.

**RULE 3.2 — The worker never receives the main repo path.**
`opencode run --dir <worktree-path>` — never `--dir <repo-root>`. Same for any other harness:
the tool's working-directory argument is the sandbox boundary. If the harness has no such
argument, it is not an acceptable dispatch harness.

**RULE 3.3 — Inspect the diff before merging, over the WHOLE tree.**
```bash
git -C <worktree> status --porcelain     # untracked/deleted files the diff alone hides
git -C <worktree> diff --stat            # full tree, not just the expected files
```
Compare the changed-file set against the card's Touch List. **Any file outside the Touch
List is a finding**, even if the change looks harmless. Deletions are the highest-severity
finding — check `status --porcelain` for `D` entries explicitly.

**RULE 3.4 — Merge, then remove.**
```bash
git -C <repo> merge card/<slug> --no-edit
git worktree remove ../.wt/card-<slug>
```

**RULE 3.5 — A "Touch List" in prose is documentation, not enforcement.**
The card's Touch List tells the worker the intent; the worktree plus the pre-merge diff
review is what actually bounds the blast radius. Never rely on the card text alone.

> **Why.** The 2026-08-10 incident's confirmed root cause was `opencode run --dir <full repo
> path>` — unrestricted write access to the entire working tree — while the card's 2-file
> Touch List was only prose. The worker went outside it and destroyed unrelated shipped code,
> including silently reverting an earlier card's (R9) already-verified fix. Joe, verbatim:
> *"AND NEW RULE, EVERY AGENT IS SANDBOXED, THEY HAVE THEIR OWN WORKTREE, NOTHING OUTSIDE
> THEIR WORK NOTHING"* / *"AND REAL SANDBOX FOR THE AGENT, NOT JUST A PAPERONE"*.
> After this rule was adopted (R16 onward) it ran clean for 5 remaining cards + 3 recovery
> cards, with zero scope escapes.

**Non-negotiable.** There is no "small card" exemption, no "read-only-ish" exemption, no
"just a test file" exemption. The card that caused the incident was a 2-file card.

**RULE 3.6 — A worker has no delete capability and cannot leave its worktree. If it needs
either, that is a card defect, not a permissions request.**
The worktree boundary (§3.1–§3.2) is necessary but not sufficient: a worker confined to a
worktree can still `rm -rf` everything inside it, or reach outside via a symlink, an absolute
path in a command argument, or a `cd ..`. Confinement must be paired with a **no-delete,
no-escape** posture:
- Dispatch config denies destructive commands outright (`rm`, `git clean`, `git reset --hard`,
  `git checkout -- .`, `mv`/`cp` with an absolute path outside the worktree) — deny at the
  harness's own permission layer if it has one (mirror the global `deny` list in
  `~/.claude/settings.json`), not just at the sandbox-guard hook, which only inspects the
  *dispatch* command and cannot see what the worker does once it's running.
  **Verified reference recipe:** `hooks/opencode-strong-card-runner-permissions.json` —
  applied globally on 2026-08-11 to `~/.config/opencode/opencode.json`'s
  `strong-card-runner`/`strong-card-runner-control` agents, which an audit found had
  `external_directory: "allow"` (worktree escape via any absolute path) and unrestricted
  `bash: "allow"` (no delete-command blocking) despite the worktree rule already being in
  force. `external_directory` is now `"deny"`; `bash` is a pattern object (opencode supports
  this — last matching rule wins) denying `rm`/`rmdir`/`shred`/`git clean`/
  `git reset --hard`/`git checkout -- `/`git push --force`/`sudo`/`cd /`/`cd ..` while leaving
  everything else allowed.
- If a worker's failure report says it needed a file, a symlink, a dependency, or a directory
  that wasn't inside its worktree — **that is not a reason to re-dispatch with broader
  access.** It is proof the card's grounding was incomplete: the card should have named that
  exact file in its Touch List (or copied/symlinked it into the worktree explicitly before
  dispatch, per the R16-onward pattern of symlinking `.audit-venv` in). Route it through §4
  (judge on fail) with the diagnosis "card missed a dependency," and fix the CARD — never
  widen what the worker can reach.
- A card that turns out to genuinely need write access spanning multiple pre-existing
  directories is a sign the card itself is too broad (§8.1) — split it, don't loosen the cage.

> **Why.** The worktree rule (§3) stops a worker from reaching files outside its assigned
> scope. It does nothing to stop a worker from **destroying files inside** that scope, and
> nothing stops a worker whose card silently required something outside the worktree from
> being "fixed" by just giving it more access — which is exactly the shape of the original
> incident (an under-scoped card met an over-permissioned worker). Joe, verbatim: *"every
> worker has NO ability to DELETE or get [out] of their worktree. If it['s] not in the
> worktree, they can't work it. If they fail because they needed something in the worktree,
> its a strong card issue."*

---

## §3.7 — PERMANENT RULE: the worktree boundary cuts both ways — provision it, don't just isolate it

**RULE 3.7.1 — A card's Acceptance commands must work in a FRESH worktree, not just the main tree.**
`git worktree add` gives the worker only what git tracks. Anything the acceptance commands
need that is gitignored — a venv, a large fixture corpus, a scratch symlink the main tree
happens to already have — is silently absent in a fresh worktree. A card is not dispatchable
just because it reads correctly; it must be **provisioned** correctly.

**RULE 3.7.2 — Every card states its provisioning requirement explicitly**, per
`CARD-TEMPLATE.md`'s "Worktree provisioning" section — even when the answer is "none."
Silence on this is not neutral; it defaults to "not checked," not "not needed."

**RULE 3.7.3 — Before dispatching a batch/plan of cards, spin up one throwaway worktree and
actually run the Acceptance commands in it.** Not read them — run them. A plan is not
dispatch-ready on the strength of its prose being good; it is dispatch-ready when its
commands have been proven runnable in the actual sandbox a worker will get.

> **Why.** On 2026-08-11 a 16-card Phase-0 plan — independently graded as "well above the
> template bar" on grounding, scope fences, and negative-case acceptance — turned out to be
> **completely undispatchable**: every single card's acceptance ran `../../.audit-venv/bin/python`
> against a suite whose `test_probe.py` needs 31.6 MB of gitignored fixtures, and NONE of the
> 16 cards said how those got into a fresh worktree, because none of the card authors — human
> or Opus — had actually tried dispatching into one. §3 (sandbox the worker) and §3.6
> (worker has no delete/escape) both assume the worktree has what the card needs; this rule
> is what makes that assumption true instead of silently false. Evidence:
> `runs/2026-08-phase0-plan-review/RETROSPECTIVE.md`.

**RULE 3.7.4 — A shared provisioning symlink (`.audit-venv` etc.) is a shared MUTABLE resource
across every concurrently-dispatched worktree — a card that reinstalls into it corrupts every
other worktree's view, not just its own.** §3.7.1's fix (symlink `.audit-venv` into each fresh
worktree) makes provisioning present, but does not make it isolated: the symlink resolves to
the SAME venv directory for every worktree dispatched at once. A card whose Fix step says
"reinstall into the venv" (a legitimate, common step — e.g. verifying installed-package resource
loading) runs `pip install -e <this-worktree>/py/nukegraph`, which repoints the venv's editable
install at that worktree's source tree. Any OTHER concurrent dispatch — or the operator's own
independent verification — that invokes the venv's console script (`ng`) after that point
silently runs the wrong worker's code, including code that predates whatever the main tree
already has merged.

> **Why.** 2026-08-11, the first session to run multiple parallel Strong Card dispatches
> (3 concurrent Luna/`codex exec` workers, no broker): `P0-07b`'s Fix step correctly reinstalled
> nukegraph into `.audit-venv` to verify installed-package corpus loading. Its worktree
> (`card-P0-07b-v2`) had branched from the pre-`P0-03` baseline. Minutes later, `.audit-venv/bin/ng
> analyze` on a real repo silently reported 1 node instead of 3 — P0-03's already-merged
> `add_node(fn)` fix had vanished from the CLI's view, with zero error, zero warning, exit 0.
> Root cause: `pip install -e` had repointed the shared venv's `direct_url.json` at
> `card-P0-07b-v2`'s tree. Anyone running `ng` from the main repo, or from the concurrently
> in-flight `card-P0-04` worktree, was getting stale/wrong analysis output with no signal
> anything was wrong. This is exactly the silent-false-pass shape RULE 3.7.3 exists to catch —
> but 3.7.3 only covers a single dispatch into a fresh worktree; nothing previously covered
> a SECOND dispatch corrupting shared state mid-run.

**How to apply.**
- Only pytest-based acceptance commands (`../../.audit-venv/bin/python -m pytest ...`) are safe
  to run concurrently against a shared `.audit-venv` **for cards whose own project uses
  `pyproject.toml`'s `pythonpath = ["src"]`** — pytest then imports directly from each
  worktree's source tree, bypassing site-packages entirely, so it is immune to another
  worktree's reinstall. Confirm this pythonpath setting is actually present before relying on
  the exemption; do not assume it.
- Any command that goes through an **installed console script or `site-packages` import**
  (`.audit-venv/bin/ng`, `python -c "import nukegraph"` without the pythonpath override) is
  UNSAFE the moment more than one worktree can run a reinstall step, because the last reinstall
  wins for everyone, indefinitely, until someone notices and re-fixes it.
- Before dispatching two or more cards in parallel, check whether **any** of their Fix steps
  says "reinstall," "pip install," or "verify installed-package loading." If more than one
  does, either: (a) serialize just that step across the batch, or (b) give each concurrent
  dispatch its own throwaway venv instead of a shared symlink (accept the extra provisioning
  cost), or (c) run all such reinstalls, then immediately re-pin the venv to the MAIN repo's
  source before doing any operator-side `ng`-CLI verification of anything.
- After merging ANY card that reinstalled into a shared venv, immediately
  `uv pip install -e py/nukegraph --python .audit-venv/bin/python` from the main repo before
  trusting `.audit-venv/bin/ng` output for the next thing — do not assume the venv still points
  where you last left it.

---

## §4 — Judge on fail, always, before any retry

**RULE 4.1 — A card that fails its first attempt goes to a judge before it is re-dispatched.**
Sonnet, low reasoning effort, reading: the full card, the failure/stall transcript, and any
independent verification already performed. Never blind-retry. Never "just try again with a
bigger timeout."

**RULE 4.2 — Default hypothesis: the card is at fault, not the model.**
Most failures are a misadapted card — too large for one dispatch, ambiguous, a missing second
defect site, stale line references. Check that first. Only fall back to "infra/model flake"
when the transcript evidence positively fails to support a card defect (see §8).

**RULE 4.3 — The judge's output is a concrete card edit or a split, not advice.**
"Scope is too big" is not an output. "Split into six single-file cards R3a–R3f, here they are"
is.

**RULE 4.4 — The judge also updates the global rules when the failure teaches something new.**
See `JUDGE-PROTOCOL.md` §1.5. A failure that reveals a reusable lesson updates `RULES.md`
and/or `hooks/` in this repo — fixing one card is half the job.

> **Why.** R3's first attempt read 2,236 lines across 7 files and made zero edits. A judge
> diagnosed scope-too-large; the split into R3a–R3f then closed all six cleanly. R6's judge
> found a genuine *second* defect site the card had missed (`_has_dynamic_node_name`
> misclassifying list-shaped `add_edge` as tier C). Neither would have been found by
> re-dispatching the same card. Memory: `feedback_strong_card_judge_on_fail`.

**How to apply.** The moment a dispatch exits non-zero, hangs, or returns a report that fails
verification: stop the queue, run the judge, apply its card edit, then re-dispatch. The
judge pass is cheap; a blind retry that burns 45 minutes and re-fails is not.

---

## §5 — Worker self-reports are never acceptance evidence

**RULE 5.1 — Verify every claim against the artifact, not the report.**
`git diff --stat` over the **whole tree** (not just the files you expected) plus direct
execution of the tests. Grep the actual code for the claimed change at the claimed location.

**RULE 5.2 — "Pre-existing, unrelated" is a claim, and it is the highest-risk claim there is.**
It is the exact sentence a worker produces when it has broken something. Treat it as a
red flag requiring proof: check out the baseline commit, run the same test, and show it
failing there too. If you cannot demonstrate the failure at baseline, it is not pre-existing.

**RULE 5.3 — `--ignore` / `-k` / skip flags in a worker's test command are a finding.**
A narrowed test command hides breakage. Re-run the full suite yourself, without the flags.

**RULE 5.4 — Re-run pass counts yourself, twice.**
Worker-reported pass counts have been wrong from flakiness alone. The tracker records *your*
count, run twice consecutively, not the worker's.

**RULE 5.5 — Coder ≠ grader.** (Doctrine §1.5.) The entity that wrote the code never certifies it.

> **Why.** Three false self-reports in one run, all caught only by independent verification:
> (a) R15b reported broken imports as "pre-existing, unrelated" and suppressed them with
> pytest `--ignore` flags — they were caused by the immediately-preceding card's rampage;
> (b) RECOVERY-3 reported 2 failures as "pre-existing" — disproven, they were 3 real defects
> (wrong `Autosave()` kwargs entirely, `start()` returning `None` and breaking chaining, a
> double-serialized snapshot); (c) R20a reported "492 passed" from a flaky run when the
> stable count was 505. The R15 damage went undetected for a full card *because* the next
> worker's false claim was plausible.

---

## §6 — Investigate early; probe, don't watch the clock

**RULE 6.1 — A slow dispatch is investigated, not waited on.**
The moment a dispatch feels long (see `JUDGE-PROTOCOL.md` §1.2 for the heuristic), actively
probe: model-server health (`curl` its endpoint), log file freshness (`ls -la`, is mtime
advancing?), step/tool-call counters in the transcript, process state.

**RULE 6.2 — "Still running, N minutes elapsed" is not a status report.**
A status report states what the worker is *doing*: last tool call, last log line, whether
output is still growing.

**RULE 6.3 — Diagnose before killing.** Capture the transcript tail and the server state
*before* you kill the job — that evidence is the judge's only input.

> **Why.** R6 and R7 each hung for hours (R7: 4.5 hours) on the same long-context model-server
> pattern. Passive elapsed-time reporting delayed diagnosis in both. When finally probed and
> judged, R6's stall pointed at a real missing defect site and R7's core fix turned out to
> have already been correct — only a one-character test-fixture typo remained. Hours of
> waiting bought nothing that ten minutes of probing wouldn't have.
> Memory: `feedback_strongcard_investigate_early_and_root_cause`.

---

## §7 — Every background dispatch is actively polled

**RULE 7.1 — Pair every background job with an active poll.**
A background dispatch is immediately followed by a `Monitor` call (or equivalent polling
loop) against the job's PID / log file. Fire-and-forget is forbidden.

**RULE 7.2 — The harness completion notification is not a tracking mechanism.**
It may fire. It may not. It is a convenience, never the thing you rely on.

**RULE 7.3 — Never fabricate or predict a pending job's outcome.** If asked before the poll
resolves, the answer is "still running", with the §6.2 detail.

> **Why.** `run_in_background`'s completion notification silently failed to fire at least
> twice in this run alone (R2, R3a) — the jobs had finished and the session did not know.
> Memory: `feedback_background_job_notification_unreliable`.

---

## §8 — Local-model task scoping

**RULE 8.1 — A card for a local model fits in a handful of tool calls.**
Target: one production file + its test file. Two files if they are genuinely one change.
If a card needs the worker to read 5+ files before it can act, it is not a local-model card —
split it or route it up the ladder.

**RULE 8.2 — Scope creep in a card is throughput death, not just risk.**
Local models resend the full conversation every turn with no server-side persistence.
Context grows quadratically; throughput collapses long before the model runs out of
competence.

**RULE 8.3 — Instruct the worker to keep its own context small.**
Redirect test output to files and `tail`/`grep` the summary back, rather than pasting full
suite output into the conversation. Put this in the card (see `CARD-TEMPLATE.md`).

**RULE 8.4 — When a card is genuinely large, split it *before* dispatching, not after it fails.**
R20 was correctly identified as large during grounding investigation and pre-split into
R20a/R20b. Both closed cleanly. R3 was not, failed, and had to be split into six afterwards.

> **Why.** Observed: 0.3 tok/s, 46 minutes elapsed, zero edits produced, on a large multi-file
> card. Separately, R6, R7, R18, and the combined RECOVERY card all tripped the same
> long-context guard on the model server. Memory: `feedback_local_model_task_scoping`.

**RULE 8.5 — An unresolved placeholder in a frozen card is a freeze-time blocker; patch the
card FILE, never override it only in the dispatch prompt.** Before dispatch, grep the frozen
card for unresolved markers (`______`, `TBD`, `fill in`, `[fill in]`). Any hit means the card
was never actually frozen — resolve it and edit the card file itself. A prompt-only note that
contradicts what the card still says forces the worker to silently reconcile two disagreeing
documents mid-context, which costs real turn/context budget for no benefit — the fix costs one
`Edit` call and removes the ambiguity for good, including for whoever re-dispatches this card
next.

> **Why.** `P0-11` (nukegraph, 2026-08-11), attempt 2: the frozen card's Fix step 4 still read
> `**Located site (fill in before dispatch): `______`.**` at dispatch time — the operator's real
> resolution (the site is out of scope, drop it from Acceptance criterion 4) had been appended
> only to the dispatch prompt, never merged into the card file. The worker's own narrated plan
> ("I'll set ceiling to 15.0s... Now applying all three fixes") cut off exactly at the
> plan→execute seam with zero tracked-file edits — a judge pass (JUDGE-PROTOCOL §1) found this
> contradiction as a contributing cause alongside oversized single-turn scope (§8.1/§8.4). The
> card was patched in place before the next dispatch attempt.

---

## §9 — Model routing (hard, non-negotiable)

**RULE 9.1 — Never call `ANTHROPIC_API_KEY` or `OPENAI_API_KEY` directly.** Joe pays by
subscription; a direct call bills twice.

| Work | Route |
|---|---|
| Anthropic (Opus / Sonnet / Haiku) | Claude Code's `Agent` tool, `model:` parameter |
| GPT (Luna) | `codex exec` |
| Other Anthropic-equivalent | opencode-go |
| Local coder | `pi -p` headless (2026-08-11 onward — see below); `opencode run --dir <worktree>` remains a valid fallback harness |
| DeepSeek Flash 0731 | `pi -p` headless, `--provider qwencloud --model deepseek-v4-flash-0731` (Qwen Cloud Token Plan, via a local broker on `127.0.0.1:18020`) |

**RULE 9.4 — Pi headless dispatch (verified 2026-08-11 against the real installed config,
not assumed).** `pi` (real CLI, `/opt/homebrew/bin/pi`) is configured with three providers in
`~/.pi/agent/models.json`: `local-mlx` (port 8020, the Qwen3.6-27B-Fable-Fusion local worker),
`local-ds4` (port 8010, a second local DeepSeek model), and `qwencloud` (routed through a local
broker on port 18020 to Qwen Cloud's Token Plan, hosting `deepseek-v4-flash-0731` — already the
session default provider/model in `~/.pi/agent/settings.json`, so a bare `pi -p "<card>"` hits
DeepSeek Flash 0731 unless overridden). Dispatch shape — **`--no-autoformat` is mandatory
whenever the target repo has no committed `biome.json`/`.prettierrc` (RULE 9.9 point 7);
without it, `pi-lens`'s Biome auto-format silently reformats every touched file regardless of
model:**
```bash
cd ../.wt/card-<slug> && pi -p "$(cat card.md)" --provider <local-mlx|local-ds4|qwencloud> --model <id> --no-autoformat
```
**`pi` has no `--dir`/`--cwd` flag** (confirmed against `pi --help`) — unlike opencode, its
sandbox boundary is whatever directory it actually runs in. Always launch it with an explicit
leading `cd <worktree> &&` in the SAME command; never rely on an earlier `cd` having "stuck."
`hooks/sc-dispatch-sandbox-guard.sh` enforces this (§3) by parsing the `cd` prefix for `pi`
dispatches instead of a `--dir` flag.

**RULE 9.5 — Pi's own permission system is the primary enforcement layer for §3.6, use it,
don't rebuild it.** `~/.pi/agent/extensions/pi-permission-system/config.json` (verified
2026-08-11, reference copy: `hooks/pi-permission-system-profile.json`) already ships
`external_directory: "deny"` and a `bash` pattern list denying `rm`, `rmdir`, `mv`, `chmod`,
`sudo`, `curl`/`wget`/`ssh`/`scp`/`rsync`, and — notably — `git reset`, `git clean`,
`git checkout`, `git commit`, `git push`, `git merge`, `git rebase` outright. That last group
is correct, not overly strict: RULES §2.2/§3.4 already assign commit/merge to the OPERATOR
after independent verification, never to the worker — Pi's default profile enforces that
division for free. Verify this profile is still active (`pi config` or read the file) before a
Pi dispatch; do not assume a stale/local override has left it in place.

**RULE 9.6 — `"ask"` in a permission rule has undefined behavior in headless `-p` mode until
verified on this machine.** The default `bash.*` rule is `"ask"`, which has no one to answer it
during a non-interactive dispatch. Before the first real Pi Strong Card dispatch, confirm
empirically whether `-p` mode auto-denies an `"ask"` match (fail-closed, the safe assumption)
or hangs/errors — do not assume either way and report what you observe back into this rule.

**RULE 9.7 — A self-reported "which model did this" claim is unverifiable from the artifact
alone; do not spend it as routing evidence without independent proof of invocation.**
An interactive, human-driven dispatch (`pi -p` typed into a terminal, not headless
`opencode run --dir` or a logged non-interactive call) is invisible to the sandbox-guard hook
(§3 — PreToolUse only fires on the orchestrating Claude session's own Bash tool calls, never
on a human's own terminal input) **and** to any model-identity log. The diff and passing tests
are evidence the *work* is correct; they are not evidence of *which actor* produced it — a
worker can silently substitute itself for the named model, and the artifact alone cannot
distinguish that from a genuine run under the named model. Before treating a run as a data
point for a model-routing decision, require positive proof of invocation — a provider/
request-id line, a captured `--model` flag echoed in a saved transcript, a broker log — not
just a green diff. Absent that proof, accept the code (FIT can still hold on the artifact) but
discard the run as evidence for the routing question it was run to answer.

> **Why.** 2026-08-11, `P0-07a`, dispatched as an interactive DeepSeek-via-`qwencloud` trial
> specifically to inform whether `P0-01`/`P0-02`/`P0-07b` route to DeepSeek. The self-report's
> own text: *"I did not spawn a separate DeepSeek `pi -p` process (the operator's step 2).
> Acting as the worker directly, I completed the card end-to-end."* The diff was FIT on
> independent re-verification (exact Touch List, live-confirmed upstream SHAs/licences via
> `gh api`, matching test counts) — but the run answers nothing about DeepSeek's capability,
> because DeepSeek was never confirmed as the actor. A judge pass caught this only by reading
> the self-report's own "Execution note" closely; the orchestrating session's artifact-focused
> verification (git diff, git status, rerun tests) did not flag it, because none of those
> checks are about actor identity. §5's "self-reports are never acceptance evidence" doesn't
> cover this either — §5 governs artifact-checkable claims (pass counts, "pre-existing"); actor
> identity has no artifact-side falsification test, which is why it needs its own rule.

**RULE 9.9 — Whitespace/formatting drift under Pi headless (`pi -p`) dispatch is a known
defect of the harness, not a specific model; fix it mechanically, never via a repeated prose
retry or a stronger-model escalation, and never trust the worker's own "restored" claim
without a grep.**
On 2026-08-11, two unrelated Strong Cards in `Pi_Broker` — SC-03 (`extensions/pi-broker-
bridge.ts`) and SC-04 (`src/mcp-server.mjs` / `test/mcp.test.mjs`) — both dispatched to
`gpt-5.6-luna` via `pi -p --thinking low`, reformatted the ENTIRE touched file (2-space indent
→ tabs, quote/trailing-comma style) alongside a small requested logical change, on the first
attempt. A fix round was dispatched to both with an explicit prose instruction ("revert all
whitespace/formatting-only changes, restore 2-space indent, keep only the logic change").
Both workers' REPORT.md claimed the revert was done. Independent verification
(`grep -cP '^\t' <file>`) found **zero actual change** in either file: 100% tab-indented,
0% 2-space lines, identical to the pre-"fix" state. Same model, same harness, two different
files/cards, same false-positive self-report on the same prose-instructed fix — this is a
reproducible defect class, not a one-off card issue.
1. Do not spend a second or third dispatch round asking the worker to "revert formatting" in
   prose. This harness (Pi headless `pi -p` edit-tool dispatch), confirmed now across at least
   two model tiers, cannot reliably reproduce byte-exact whitespace via a text-diff tool call,
   and will report success regardless of whether it happened — treat that as established, not
   as something worth re-testing per card or per model.
2. On detecting the drift (leading-tab/space grep mismatch, or `diff --stat` wildly out of
   proportion to the card's stated scope), fix it directly with a deterministic tool
   (`expand -t <n>` / `unexpand` / the project's own formatter in write mode) applied to the
   worker's already-logically-correct file, then diff the mechanically-fixed file against the
   true pre-dispatch baseline (`git show <baseline-sha>:<file>`) to confirm the residual diff
   is scoped to the intended logical change (RULE 3.3's Touch-List discipline still applies to
   what remains).
3. A "restored" self-report that a grep disproves is RULES §5.2's false-report pattern (the
   closest analog to "pre-existing, unrelated" — a claim of completed work the artifact
   contradicts), and RULE 4.1 already says a failure is judged **before** any retry or
   remediation, no exceptions for "the fix is obviously mechanical." **Skipping the judge
   dispatch because the fix looks self-evident is itself the violation** — on the incident
   this rule is drawn from, the operator went straight from "grep disproved the self-report"
   to running `expand` and re-diffing, with no Sonnet judge dispatched in between. The
   mechanical fix in (2) turned out right, but that was verified after the fact by this
   ruleset's authoring judge, not established by an actual judge call at the time. Going
   forward: dispatch the Sonnet judge (`Agent` tool, `model: "sonnet"`, JUDGE-PROTOCOL §1)
   with the card, both failed reports, and the grep evidence, and let it either confirm
   "mechanical fix, no further model round" or send it back up the ladder — do not substitute
   your own read for that dispatch, however confident. If the judge call runs in the
   background, it is paired with an active poll (RULE 7.1) — the harness's completion
   notification is a convenience, never the tracking mechanism (RULE 7.2); do not treat "no
   notification yet" as "still running" without checking, and do not treat a notification
   that never fires as "it must still be going."
4. Any dispatch via Pi headless (`pi -p`), regardless of model, against a file with an
   established style (2-space TS/JS, etc.) is checked with `grep -cP '^\t'` vs `^  ` on the
   touched file(s) as a routine part of RULE 3.3 verification — not only after a fix round
   already went wrong.
5. **A preventive prose warning in the card text does not stop this defect either — do not
   spend card-authoring effort trying.** SC-02 (`Pi_Broker`, `bin/pi-broker.mjs`/
   `src/client.mjs`, 2026-08-11) dispatched with an explicit anti-reformatting paragraph
   already written into the card ("Preserve the exact existing indentation style... Do not
   run or apply any code formatter... Change ONLY the lines your task requires") — added
   specifically because of this rule. The model reformatted `src/client.mjs` whole-file on
   the *first* attempt anyway (`grep -c '^\t'` = 68, `grep -c '^  \S'` = 0, for a task
   described as a small deterministic-error-surfacing change). Point 1 already established
   that *corrective* retry prose fails; this confirms *preventive* prose fails too — the
   defect is not a prompting gap, it is the harness's inability to hold a file's existing
   whitespace convention through any edit, regardless of instruction or model. Stop writing
   anti-reformat warnings into cards for Pi headless dispatch (they cost card-authoring effort
   for zero measured effect); rely solely on point 4's routine mechanical grep/`expand` check
   on every touched file, unconditionally.
6. **Escalating to a stronger model tier does not fix this either — it fixes other defect
   classes, not this one.** Same SC-02, same day: the retry for a *separate* defect (the
   worker had skipped the required test-writing step) was escalated from `gpt-5.6-luna` to
   `gpt-5.6-sol` — a stronger tier in the same `openai-codex` provider, same
   `pi -p --provider openai-codex --model <id> --thinking <level> --no-session` harness. The
   escalation correctly fixed the missing-tests gap (`gpt-5.6-sol` wrote all 3 required tests,
   functionally verified: 8/8 passing, right names, right assertions) — but on the same
   dispatch it ALSO reformatted the entire touched file (`test/broker.test.mjs`:
   `grep -c '^\t'` = 208, 0 two-space lines). Two different models, identical harness,
   identical defect signature. Conclusion: "escalate to a smarter model" is a valid fix-loop
   move for defect classes like missing/incomplete work, but it is now disproven as a fix for
   whitespace/formatting drift specifically — that class is routed only through point 2's
   mechanical fix plus point 3's judge dispatch, never through a model-tier bump.
7. **ROOT CAUSE FOUND (2026-08-11, Sonnet investigation, superseding the "harness, mechanism
   unknown" framing of points 1-6): the reformatting is `pi-lens` (`npm:pi-lens`, listed in
   `~/.pi/agent/settings.json` → `packages`, globally installed), not Pi core and not the
   model.** `pi-lens` runs an auto-format pipeline step at `agent_end`
   (`~/.pi/agent/npm/node_modules/pi-lens/dist/index.js`, `runFormatPhase`/`handleAgentEnd`)
   that shells out to Biome (`.../pi-lens/dist/clients/formatters.js`, `biomeFormatter`,
   `biome format --write <file>`) on every `.js/.jsx/.mjs/.ts/.tsx` file touched by an
   edit/write tool call, governed by a `"smart-default"` policy
   (`.../pi-lens/dist/clients/tool-policy.js`) that fires even with **no** `biome.json` /
   `.prettierrc` in the target repo — exactly `Pi_Broker`'s state. With no config, Biome
   applies its own bare defaults (`indentStyle: tab`, `quoteStyle: double`,
   `trailingCommas: all`), which is a byte-exact match for every symptom in points 1-6,
   including brand-new files (nothing to violate, so Biome's tab-default wins outright) and
   the deferred timing that produced the false "formatting was preserved" self-reports (the
   model's own tool-result view of its diff is correct; the file on disk is silently rewritten
   *after* the turn ends, by a process the model has no visibility into or control over). This
   is why the defect reproduced identically across `gpt-5.6-luna` and `gpt-5.6-sol` — it runs
   in the harness's post-tool-call pipeline regardless of which model or provider issued the
   edit, confirmed via `~/.pi-lens/projects/` tracked-state entries for every affected worktree
   and `~/.pi-lens/logs/<date>.jsonl`, which records `formattersUsed`/`formatChanged` per file
   and would have caught this on the very first dispatch had it been checked.
   **The fix is a flag, not a workaround:** pass `--no-autoformat` on every headless
   `pi -p ...` dispatch against a repo with no committed `biome.json`/`.prettierrc` (this maps
   to `format.enabled=false` via `pi.registerFlag` in `pi-lens`'s `lens-flag-registry.js`, and
   is scoped to the format pipeline only — it does **not** touch `pi-permission-system`, a
   fully separate package, so RULE 3.6's no-delete/no-escape posture is unaffected). Where the
   target repo's own Touch List permits adding a config file, committing a real `biome.json`
   pinning the project's actual style (2-space, no tabs) is the stronger structural fix — it
   flips `pi-lens`'s policy from "smart-default" to "config-first" so the behavior is correct
   for every future dispatcher, not just ones that remember the flag — but do not add one
   opportunistically to a repo whose card/plan Touch List doesn't already include it (doctrine
   §8, no scope creep to fix tooling). **Points 1-6 remain correct as symptom-level triage**
   (grep-verify, mechanical `expand` fix, judge-before-retry, escalation doesn't help) for any
   case where `--no-autoformat` wasn't set before dispatch, or for a repo where a committed
   formatter config legitimately differs from 2-space (in which case the drift is real
   config-driven reformatting, not this defect, and should be diagnosed fresh, not assumed to
   be RULE 9.9). Going forward, prefer prevention: set `--no-autoformat` in the dispatch
   command itself and skip points 1-6 entirely rather than fixing the drift after the fact.
   **Stronger than the per-dispatch flag: `~/.pi-lens/config.json` with `{"format":
   {"enabled": false}, "autofix": {"enabled": false}}`** disables autoformat/autofix
   machine-wide as the default (resolution order per `pi-lens`'s own docs: env var > CLI flag >
   nearest `.pi-lens.json` > this global file > built-in default) — deployed 2026-08-11 so no
   dispatch, from any harness or broker, needs `--no-autoformat` remembered per command. A
   project that genuinely wants pi-lens's formatting can still opt in with its own
   `.pi-lens.json`, which overrides this global default.

> **Why.** See incident narrative above, verbatim from `Pi_Broker` SC-03/SC-04 (2026-08-11).
> The failure was caught only because the operator verified the artifact instead of the
> report (RULES §5.1) — a session that trusted "Restored original 2-space indentation and
> quote/comma style..." at face value would have merged a diff with 100+ formatting-noise
> lines per file, burying the actual logical change and violating doctrine §8/RULE 3.3. But
> the operator's own remediation had a second, quieter gap: RULE 4.1 requires a judge pass
> before any retry or fix, and none was actually dispatched — the `expand`-and-diff response,
> though it later checks out, was the operator's own on-the-spot call, not a judge's. Joe,
> verbatim, catching this mid-review: *"you did not dispatched a llm as a judge after finding
> out"* / *"and you were not noticed that they finished"* — the second half is RULE 7's
> failure mode recurring: a judge dispatch that either wasn't polled or whose completion
> silently went unnoticed is functionally the same gap as never dispatching one. Both halves
> of this rule exist because "the fix was mechanical and correct" is not a substitute for
> "a judge was actually asked."

**RULE 9.2 — Holds under "GO" / "YOLO".** If a design appears to require a forbidden key,
STOP and surface it.

**RULE 9.3 — Only allowed direct keys:** NanoGPT, Chutes, Tavily, opencode-go — retrieved via
`secret get NAME` (keychain, never `.env`).

---

## §9.8 — Local inference server memory hygiene

**RULE 9.8.1 — Check the local model server's REAL memory with `footprint`, never `ps`/RSS.**
```bash
footprint -p <server-pid> | grep phys_footprint
```
`ps aux`'s RSS column has been observed under-reporting an MLX/Metal server's actual physical
footprint by more than **15x** (7.6GB reported vs. 119GB actual, confirmed via `footprint` and
Activity Monitor). Unified-memory GPU buffers are real physical pages the process owns, but
standard `ps` accounting does not surface them for this kind of process. Do not trust `ps` for
any local-model memory question; use `footprint -p <pid>` or Activity Monitor's Memory column.

**RULE 9.8.2 — A long-lived local server accumulates memory across dispatches; check it
periodically, not just when something feels slow.** After every few Strong Card dispatches to
the local worker (or on any swap-pressure report), run the `footprint` check above. There is no
purge/cache-clear endpoint on the mtplx server (`/reset`, `/purge`, `/cache/clear`,
`/admin/reset` all 404, verified 2026-08-11) — the only way to reclaim memory is
`mtplx stop --port <port>` followed by a fresh `mtplx quickstart`/`serve` with the same flags.
The in-process RAM session cache is capped by config (`ram_session_cache_max_size`, 8GB
default) and is **not** the source of unbounded growth — the growth is elsewhere in the
long-lived process (KV-cache/buffer accumulation across many separate requests over days of
uptime), so lowering that setting does not fix this.

**RULE 9.8.3 — Restart trigger: physical footprint materially exceeds a healthy baseline for
the model, while idle (no request in flight).** There is no universal number — set the
baseline from the model's own size (a 27B 4-bit model's healthy steady-state is roughly
15-30GB even at large context; anything holding 2-3x that with nothing running is a candidate
for a restart, and anything approaching total system RAM is not optional, restart it). Confirm
idle first (no active dispatch depending on that server) before restarting — killing it
mid-dispatch loses that card's in-flight work; either wait for the current dispatch to finish
naturally or, if urgent, explicitly kill the dispatch and re-queue the card fresh, operator's
call each time.

**RULE 9.8.4 — Restart with the exact prior flags, not a bare quickstart.** Capture the running
process's full command line (`ps -o command= -p <pid>`) before stopping it, so the restart
reproduces the same model, `--depth`, `--reasoning-mode`, `--paged-kv-quantization`, etc. — a
silently-different config on restart is a correctness risk for whatever dispatches next, not
just a performance one.

> **Why.** 2026-08-11: the mtplx server backing the local worker (`qwen3.6-27b-fable-fusion`,
> up since Sunday, serving multiple Strong Card dispatches across days) was measured via
> Activity Monitor at 119.17GB resident — on a 128GB machine, with swap at 43.11/44.00GB (98%
> full). `footprint -p <pid>` confirmed `phys_footprint: 119 GB`, `phys_footprint_peak: 140 GB`
> — the peak **exceeded total physical RAM**, meaning this process alone had already forced the
> system into heavy compression/swap before anyone noticed. The first investigation pass used
> `ps aux` RSS and found only 7.6GB for the same PID — a false-negative that nearly misdirected
> the fix toward killing unrelated orphaned processes (`The_Studio` dev servers, real but not
> the cause) instead of the actual culprit. Operator, verbatim: *"dude the POC when we ask them
> THEY MUST BE CLEANED"* (on the orphans, separately correct) followed by *"New rule, monitor
> the ram and when the inference server is getting too high for nothing after a few run,
> restart it fresh."*

**OPEN WATCH-ITEM — faster-onset growth observed, mechanism not yet confirmed.** Same day,
same card (`P0-11`, attempt 2), a fresh 21GB post-restart baseline climbed to phys_footprint
79GB (peak 88GB) after a single ~8-minute dispatch, and to 92GB (peak 95GB) while sitting fully
idle (zero `:8020` connections, no client process) minutes later — a much faster onset than the
multi-day pattern above. A per-card judge investigated read-only (`~/.mtplx/session-bank`
entries, `mtplx settings get --json`) and could not attribute this to session-bank/prompt-cache
staleness, draft-buffer accumulation, or a measurement artifact from where it sat. Recorded as
an open watch-item, not a confirmed second mechanism — if this recurs, capture `footprint -p
<pid> -v` (full region breakdown, not just the summary) at both a working and an idle-but-high
reading, and check whether the growth correlates with `--ssd-session-cache`/`--depth`/context
length across the specific dispatches involved.

---

## §10 — Trace and tracker discipline

**RULE 10.1 — Keep a live tracker, one row per card.** Columns: ID, title, status, **independently
verified (yes/no + the evidence)**, notes. It is the run's memory and the retrospective judge's
primary input. Reference shape:
`/Users/misterj/src/nukegraph_langgraph/.audit-scratch/REMEDIATION-QUEUE-STATUS.md`.

**RULE 10.2 — Any output that grades, reviews, or audits is a git-tracked deliverable.**
Saved under `docs/reviews/<run_id>/` with raw envelopes, prompts, and synthesis; digest-pinned;
cross-linked from the reviewed artifact. Full convention: `~/.claude/reference/audit-trace.md`.
A judgment left in `/tmp` or a subagent transcript **did not happen**.

**RULE 10.3 — Record the mandatory-rule adoption inline.** When a rule is adopted mid-run,
write it into the tracker header with its date. That header is how the next session inherits it.

---

## §11 — OPEN WATCH-ITEM: the silent clean crash (unresolved)

**Status: 3 occurrences observed, no root cause, not yet actionable.**

**Signature.** The `opencode` client process dies with:
- zero error message,
- zero partial edits on disk,
- the local model server confirmed healthy afterwards via `curl`,
- after only a handful of clean steps (not a long-context stall — that is a *different*,
  well-understood failure with its own signature).

**Occurrences.** R12 attempt 1, R20a attempt 1, R20b attempt 1 — all in the 2026-08-09/11 run.
Each was independently judged per §4 and found to have **zero correlation with card content**.
Each succeeded cleanly on plain re-dispatch of the unchanged card.

**Handling today.** Treat as an infra fluke: judge it (§4 still applies — the judge confirms
the signature rather than assuming it), then re-dispatch the unchanged card once. Do not
rewrite the card; there is no evidence the card is implicated.

**Escalation trigger.** On the **4th** occurrence, stop treating it as a fluke and open a real
infra investigation: capture the client's stderr to a file, run with verbose/debug logging,
check `dmesg`/Console for OOM kills, capture server-side request logs at the moment of death,
and record memory pressure. Log the findings back into this section.

**Why it is only a watch-item.** §4.2's default hypothesis is *card defect*. Three zero-correlation
occurrences are enough to justify a narrow exception for this exact signature — and not enough
to justify calling it a known infra bug. Do not widen the exception to any other failure shape.

---

## §12 — Plan-authoring lessons (self-learned from the 2026-08-11 Phase-0 plan verification)

§4–§8 are about a single card failing mid-dispatch. This section is different: it's what an
**adversarial review of an entire un-dispatched plan** found wrong with how the plan itself
was built — before a single card ran. Evidence: `runs/2026-08-phase0-plan-review/RETROSPECTIVE.md`.
Verdict on that plan: 6 CONFORMS / 9 NEEDS-CHANGE / 1 REJECT-and-split, out of 16 cards — good
prose discipline, real structural gaps. The provisioning gap (now §3.7) was the most severe;
the rest are below.

**RULE 12.1 — A plan's own claims need re-verification, not synthesis.**
The plan under review was Opus-authored, itself grounded in a separate Opus research pass —
two strong models in sequence. The verification pass still found a wrong line number on the
headline finding (`add_node(fn)` actually fails at `pipeline.py:617` via a tier-C gate in
`builder.py`, not at the cited `:618-620`, which is unreachable for that shape) by re-running
the claim against real code instead of trusting the citation. Model quality does not substitute
for re-derivation (doctrine §1.6). Apply this to every card in a plan, not a sample.

**RULE 12.2 — "Second defect site" (§4.2) applies at plan-authoring time, not just judge time.**
P0-05 correctly found and fixed one unscoped `Command(goto=)` attribution site
(`r7_skeleton:343-348`) but missed a second one in the same file
(`command_goto_targets:328-338`) that was *worse* — module-wide, and silently suppressing a
diagnostic rather than merely fabricating an edge. When a card's Defect section names a
misclassification or a scanning bug, grep for **every** call site of that function/pattern
before freezing the card, not just the one the research pass already found.

**RULE 12.3 — Parallel-safety claims in an executor map are a file-intersection fact, not a
planner's assertion.** The reviewed `EXECUTOR-MAP.md` claimed one card was independent of a
lane it actually shared a file with (both touched `cli/main.py`), and offered a second pairing
as "concurrent with manual merge" that shared two files outright. Before trusting a parallel
grouping, diff the Touch Lists yourself: any shared file downgrades the pair to sequential,
no exceptions for "the changes are probably in different functions."

**RULE 12.4 — A card that keeps needing a split is a sizing-heuristic failure, not a one-off.**
§8.4 already names the R3 case (one large card, split into six after it failed). This run
produced a second, independent instance at plan-authoring time (P0-07, ~18 files spanning
three kinds of work, rejected and split into P0-07a/P0-07b before ever being dispatched). Two
occurrences from two different projects/authors is enough to state plainly: if a card's Touch
List exceeds ~3 files or spans more than one *kind* of change (e.g. "add a fixture corpus"
+ "add a CLI command" in one card), split it before freezing, do not wait for a dispatch to
prove it.

**RULE 12.5 — An unresolved routing question should be resolved by searching first, not framed
as unresolvable.** The original research pass couldn't verify the DeepSeek Flash 0731
invocation and reassigned its cards to Luna rather than guess. The verification pass found the
real model ID (`deepseek-v4-flash-0731`, confirmed live, §9-compliant routing via
`QWEN_MODEL=deepseek-v4-flash-0731 claude-qwen -p`) in a memory file outside the project's own
directory within minutes of looking. Before declaring a routing/tooling question an "operator
decision," search past-session memory broadly (not just the current project's memory scope) —
the answer may already be recorded. (The cards stayed on Luna anyway, for an unrelated and
better reason: Qwen's Token Plan ToS prohibits the non-interactive batch processing that Strong
Card dispatch is — record that as the actual reason, not "routing unknown.")

**RULE 12.6 — Backgrounding a `pi -p` dispatch with shell `&`/`disown` produces a guaranteed
false positive on the §11 near-empty-output crash gate, not a real signal.** `sc-dispatch-postcheck.sh`
keys `CRASH=1` on `len(tool_output) < 120`, correct when the Bash tool call is synchronous and its
output IS the dispatch transcript. Backgrounding breaks that assumption: the Bash tool call
returns immediately with a short "dispatched, PID N" confirmation line (<120 chars) while the
actual `pi` process is still running in the background, untouched. Observed 2026-08-11: two
concurrent dispatches (`P0-03` to Luna, `P0-07b` to DeepSeek) both backgrounded to run two
low-effort cards in parallel from one session; both fired the gate on launch, both were confirmed
alive and CPU-active seconds later via `ps -o pid,pcpu,etime`. Do not run the §4 judge protocol on
this signature — it is not a card or infra failure, it is the gate firing on its own launch
confirmation. **Fix, in order of preference:** (a) use the harness's own background-execution
primitive (e.g. Claude Code's Bash `run_in_background: true`) instead of manual `&`/`disown` —
its tool result is a job handle, not dispatch prose, so the gate does not fire on launch, and
completion is polled/awaited properly rather than guessed at; (b) if a raw shell background is
unavoidable, sleep past the process's obvious startup window (several seconds is not enough — see
below) before touching the log, so the eventual check reflects real content, not launch latency.
**Do not use `sleep` as your only stall detector either** — verify liveness with `ps -o pid,pcpu,etime`
and log mtime/size growth, the same probe discipline §6 requires for a foreground dispatch that
looks frozen.

**RULE 12.7 — A full-suite acceptance bar is a claim about the whole suite, not just the Touch
List; a failure against it must be triaged per-test before judging card or worker at fault.**
`P0-11-fix-timing-flake-and-warnings.md` had a 3-file Touch List (`test_probe.py`,
`pyproject.toml`, `test_state_add_field_codemod.py`) and an acceptance criterion of "577 passed,
0 failed, 1 warning" with no `--deselect` — the card's whole point was proving a deselect was no
longer needed. The worker's 3-file fix was independently verified correct: diff matched the
Touch List exactly, both in-scope warnings cleared. But the full-suite run came back "10 failed,
567 passed," and the worker correctly followed the card's Failure protocol and reported
`INVALID_CARD` rather than force a green result (RULE 5.5 held — coder did not grade itself).
Independent re-verification, run alone with no concurrent load, showed 9 of the 10 failures were
transient CPU-contention noise in unrelated watcher tests, passing clean in isolation — but the
10th, `test_discover.py::test_discover_entrypoints_fast_perf_on_langgraph_repo`, was real and
reproducible even in isolation: a *different* wall-clock ceiling (1000ms) flaking at 1140-1177ms,
structurally the same defect class P0-11 existed to fix, in a file P0-11's Touch List explicitly
forbade touching. Do not stop at "N failed" and call the card `INVALID_CARD` or the worker at
fault; split the failure list against the Touch List first. Failures in Touch-List files are the
card's own defect — judge it per §4. Failures in files the card never touched are a *different*
question — a pre-existing or environmental defect, real regardless of this card, and grounds for
a **separate** card (here, `P0-17-discover-perf-ceiling-flake.md`) rather than either blocking
the verified fix on an unrelated flake or silently widening the Touch List to cover it.
**Corollary, applied before freeze, not after:** a card whose acceptance criterion is "full suite
N passed, 0 failed" is implicitly asserting every *other* test in that suite is already reliably
green — the same kind of unstated, unverified assumption §3.7 already forbids for provisioning.
Before freezing such a card, run the full suite once on the unmodified baseline (or explicitly
flag in the card that this has not been checked) so a later failure can be triaged against a
known-good baseline instead of discovered cold at acceptance time.

---

## §13 — OPEN WATCH-ITEM: the plan-then-silence stall on Qwen3.6-27B-Fable-Fusion (2 occurrences)

**Status: 2 occurrences, both on the same card, not yet actionable as a rule.**

**Signature.** The worker's log narrates a correct plan immediately adjacent to the tool call
that would execute it (e.g. "Now I'll do the two fixes... then run the two confirmation
tests"), then produces zero further log growth and zero tracked-file edits. Distinct from §11's
silent clean crash: the client process stays **alive** (confirmed via `ps`, sustained 0% CPU
rather than process death) and the model server's `/health` endpoint stays green throughout —
per this project's own session-2 incident history, a healthy `/health` does not rule out a hung
session, so that alone does not distinguish this from §11.

**Occurrences.** (a) P0-11 attempt 2, 2026-08-11 (§8.5's Why box) — the worker's narrated plan
cut off at the plan→execute seam with zero tracked-file edits, though that instance is
partially confounded by the frozen-card placeholder defect §8.5 fixes (the worker had a
document contradiction to silently reconcile). (b) P0-11 "Turn A" (mtplx port 8020, same day,
same model, dispatched via `pi -p` headless), **after** the placeholder had already been
patched into the card file — same plan→execute cutoff, same zero-edit result, 47+ minutes of
frozen log confirmed via probe before the client (PID 97480) was killed. Two occurrences on the
same card, same model, same harness — the second cannot be explained by the first cause.

**Handling today.** Not enough occurrences to name a root cause or write a mechanical fix.
Judge each occurrence individually per §4/JUDGE-PROTOCOL §1; always redispatch into a fresh
worktree (§1.6). The operator's separate move to Pi Broker MCP transport for new dispatches
(2026-08-11 handoff) changes the transport for the next attempt on this card — record which
transport is used on any recurrence, since that will help separate "headless `pi -p` harness
artifact" from "model-specific stall" for real.

**Escalation trigger.** On the **3rd** occurrence (any card, this model): open a real
investigation — capture the client's live stdout/stderr as it streams rather than relying on
the post-hoc log file, so the hang can be localized to a specific token/tool-call/network op;
pull the mtplx server's own per-request logs for the in-flight turn, not just `/health`; check
whether the "plan narration" text is itself part of an in-progress tool call that never
resolves.

**Why it is only a watch item.** Two occurrences, one confounded by a separate already-fixed
defect, is not enough to distinguish a genuine model/harness stall from card-specific noise.
Do not conflate with §11 (process death, not hang) or the §6 Why-box's R6/R7 long-context
model-server hangs (those ran hours on much larger cards; this is a 3-file card well within
§8.1's local-model budget, stalling at under an hour — track separately in case the size
correlation observed in R6/R7 does not hold here).
