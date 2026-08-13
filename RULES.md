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

**RULE 3.8 — "Every agent" in §3's founding quote means every agent, including reviewers,
judges, breakers, and POC testers — not just recognized coder-dispatch CLI patterns.**
The sandbox-guard hook (`hooks/sc-dispatch-sandbox-guard.sh`) only pattern-matches specific
Bash command shapes (`opencode run`, `claude-local -p`, `pi -p`, `strong-card-runner`). A
subagent launched through a generic Agent/Task tool call — a code reviewer, a break-test/POC
agent, a judge that runs commands rather than just reading a diff — is invisible to that hook
entirely, because the hook only ever sees the orchestrator's own Bash tool calls, never what
runs inside a dispatched subagent. This is a real enforcement gap, not a theoretical one:
nothing currently stops an orchestrator from pointing a "just testing" agent at the primary
working tree.

The rule closes it at the orchestrator level, since no hook can (2026-08-11, session 5, Joe:
*"every agent that review must work in sandboxes and worktree, SUPER IMPORTANT, nobody is
allowed to break the original thing"* / *"well its the same for every agent in the future...
global. we dont want crazy bat shit to happen."*):
- Before dispatching ANY agent that will run code, edit files, install dependencies, or execute
  anything beyond read-only inspection of already-materialized text (a diff, a file the
  orchestrator pastes in) — create a dedicated worktree for it first, exactly as §3.1.
- Give that agent ONLY the worktree's absolute path, stated explicitly as its filesystem
  boundary in the prompt, with an explicit instruction never to read or write outside it and
  never to touch the primary repo path directly. If the agent's own harness has a directory-pin
  parameter, use it; if it doesn't, the prompt text is the boundary — state it as a hard
  constraint, not a suggestion.
- A reviewer/breaker/judge worktree is disposable: capture its findings, then
  `git worktree remove --force` it. Never merge a breaker's own working-tree changes back into
  main — its diff was never the deliverable, its report was.
- This applies permanently and globally, not just to the session that prompted it — every
  future orchestrator session inherits this rule the same way it inherits §3.1–§3.7.

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

**RULE 3.7.5 — `CARD.md` (or any dispatch-scaffolding file) is provisioned into a worktree as an
UNTRACKED file, never as a commit. If it must be committed for some reason, `git rm` it from the
card branch itself before merge — never leave that cleanup to a post-merge follow-up on main.**

**Confirmed 100% recurrence, this session (2026-08-12, `nukegraph_langgraph`): P0-08, P0-12,
P0-07c, P0-06, P0-14 — five dispatches, five leaks, five manual `git rm` follow-up commits on
main.** Root cause: the operator's own dispatch procedure ran `git add CARD.md && git commit -m
"dispatch: add CARD.md for card/<slug>"` inside the fresh worktree *before* handing it to the
worker, specifically so the worker's coding session had the card text on disk. That commit puts
`CARD.md` on `card/<slug>`'s branch history from turn one. No worker ever intentionally commits
it — RULE 3.4's `git merge card/<slug> --no-edit` pulls in the *entire* branch, including that
first scaffolding commit, automatically, every time, regardless of what the worker itself
touched. This is not a worker failure and not a §3.3 Touch-List violation to catch in review — it
is a self-inflicted wound in the provisioning step, and it reproduced identically across five
different cards/workers because the same flawed procedure ran five times.

**Fix — provision CARD.md as untracked, full stop:**
```bash
git worktree add ../.wt/card-<slug> -b card/<slug>
cp CARD.md ../.wt/card-<slug>/CARD.md        # copy only — no git add, no git commit
```
The worker still has the card text on disk at the same path it always did; nothing about the
worker's experience changes. What changes is that `CARD.md` now sits in the worktree exactly like
a `.venv` or any other gitignored/untracked provisioning artifact (§3.7.1's own category) — `git
status --porcelain` will show it as `??`, `git diff --stat` will never mention it, and `git merge
card/<slug>` has nothing to pull in because it was never on the branch. This is strictly better
than option (b) (worktree-local `.git/info/exclude`) or option (c) (a mandatory pre-merge `git rm`
step): (b) still requires the operator to remember a second provisioning step and only suppresses
*accidental* re-adds, it does nothing about the procedure that already, deliberately, commits the
file; (c) keeps the defect commit in the branch and bolts on a manual cleanup step at exactly the
seam that already failed five times in a row — a step that must be remembered and run correctly
every single time is not a fix, it is the same failure mode restated as a checklist item. Making
the file untracked removes the leak path structurally: there is no branch history containing
`CARD.md` for a `--no-edit` merge to ever pull in, so there is nothing left to remember.

**Belt-and-suspenders, not a substitute for the above:** also add a `CARD.md` line to the
worktree's `.git/info/exclude` at provisioning time (worktree-local, not the repo's committed
`.gitignore` — this is scaffolding, not a project concern). This guards against a worker or a
future operator habit accidentally running `git add -A`/`git add .` inside the worktree and
picking the untracked `CARD.md` back up without noticing; it does not, by itself, fix anything if
the provisioning step still commits the file up front, which is why it is secondary to changing
the `cp`-not-`commit` procedure itself.

**If a workflow genuinely requires `CARD.md` to be committed** (e.g. an external harness that only
reads files it finds tracked in the worktree's git index) — the fallback is this rule's option
(c) above, but treat it as a documented exception, not the default: `git rm CARD.md && git commit
-m "chore: drop dispatch scaffolding"` on `card/<slug>` itself, run by the operator as a mandatory
step of RULE 3.3's pre-merge review (verify it happened via `git show card/<slug>:CARD.md` failing
with "does not exist" — not by memory), strictly *before* `git merge`, never as a follow-up commit
on `main` after the fact.

> **Why.** Same incident class as §3.7's opening finding (a well-reviewed process turned out to be
> undispatchable/leaky not because any single dispatch was reviewed poorly, but because the
> *provisioning step itself* was systematically wrong in a way no per-card review would catch).
> Here the review (§3.3's diff/status inspection) DID catch the leak every time — five separate
> follow-up `git rm` commits on main are direct evidence the operator was checking — but catching
> it after the fact and fixing it before the fact are not the same cost. A 100% recurrence rate
> across five independent cards, with the exact same root cause named identically each time, is
> the definition of a process gap rather than a card-by-card mistake (doctrine §1: system
> coherence outranks a clean-looking individual merge).

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

**RULE 4.5 — When the worker ran via Pi Broker, the judge's evidence set includes the live
terminal/broker output, not just the card, the diff, and the worker's own report (2026-08-13,
session 5).** A dispatch under Pi Broker is not headless — the same evidence available to the
operator mid-turn (RULE 7.4's Terminal-window read, RULE 7.6's broker event log at
`/private/tmp/pi-broker-ng-s5/listener.log`, and the session's own `.jsonl` transcript at
`~/.pi/agent/sessions/<worktree-path>/*.jsonl`) is available to the judge too, and omitting it
means the judge is reasoning about *what the worker claims happened* rather than *what actually
happened turn-by-turn* — the exact gap RULE 5.4/5.6 exists to close for self-reports. Give the
judge the session's transcript path and the broker log grep for its session ID as part of its
brief whenever the failure mode is ambiguous (a stall, a premature stop, a self-report that
doesn't match the diff) rather than only when the diff itself looks wrong. This does not apply
to failures with an unambiguous diff-level cause (e.g. a clean assertion mismatch) — reading
the play-by-play adds cost without changing the verdict there; reserve it for cases where *why*
the worker did what it did is itself the open question.

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
count, run twice consecutively, not the worker's. This holds even when the worker's own
command line matches the canonical suite command exactly — a matching command string is not
evidence of a matching environment. A worker's pass/fail count from *inside its own dispatch
session* (Pi Broker, opencode, any harness-wrapped bash tool) is categorically unverified
until reproduced in a clean, non-interactive shell against the same worktree: the dispatch
harness's own subprocess wrapper can carry stale env vars, a different `PYTHONPATH`, `.pyc`/
`__pycache__` left over from the session's own earlier failed iterations, or CPU/memory
contention from the local model server running alongside the test process — any of which can
flip timing-sensitive tests or produce a materially different pass/fail count than a clean
re-run moments later on the identical command and worktree. Treat "ran pytest myself inside
the dispatch session" and "ran pytest in a clean shell" as two different, non-substitutable
verification acts — only the second counts.

**RULE 5.5 — Coder ≠ grader.** (Doctrine §1.5.) The entity that wrote the code never certifies it.

**RULE 5.6 — A claimed deliverable file is a claim, not evidence — `ls` it before you believe
it.** When a card's acceptance criteria require an artifact on disk (fail-first evidence,
a captured log, a generated fixture), the worker narrating that it captured/saved that
artifact is not proof it exists. Check the worktree directly (`ls`, `find`, or the exact
path the card names) before crediting that acceptance criterion. A worker can be otherwise
correct about the code and still simply not have done this step — narrating an action in
the final report is not equivalent to having taken it.

> **Why.** Three false self-reports in one run, all caught only by independent verification:
> (a) R15b reported broken imports as "pre-existing, unrelated" and suppressed them with
> pytest `--ignore` flags — they were caused by the immediately-preceding card's rampage;
> (b) RECOVERY-3 reported 2 failures as "pre-existing" — disproven, they were 3 real defects
> (wrong `Autosave()` kwargs entirely, `start()` returning `None` and breaking chaining, a
> double-serialized snapshot); (c) R20a reported "492 passed" from a flaky run when the
> stable count was 505. The R15 damage went undetected for a full card *because* the next
> worker's false claim was plausible. A fourth pattern, distinct from the above (P0-18,
> 2026-08-12, nukegraph_langgraph): the worker's "pre-existing" claim named a *specific,
> checkable, false* cause ("INV-4 failures, langgraph not installed" — independently
> verified as 12/12 passing on both baseline and the card's worktree, zero INV-4 failures
> anywhere), while the real pre-existing failure was a different test entirely (a golden-diff
> fixture with a baked-in worktree path, confirmed failing identically on baseline). The
> underlying code fix was correct and in-scope. Separately, the worker's report described
> having captured fail-first evidence to `<ID>-failfirst-before-fix.txt`; the file did not
> exist anywhere in the worktree. Neither defect required redoing the fix — both were caught
> only because RULE 5.2's baseline-diff check was run anyway, and because the deliverable
> path was checked directly rather than trusted from the narration. Small/local models are
> not more prone to this than frontier ones; RULE 5.1 already says "verify every claim" —
> this rule exists because "check the file exists" is easy to skip when the rest of the
> report reads as confident and the diagnosis-flavored parts sound plausible.
>
> **Second confirmed occurrence, Pi Broker specifically (P0-10, 2026-08-12,
> nukegraph_langgraph).** A worker dispatched via the Pi Broker (local Qwen model) ran the
> exact canonical suite command inside its own interactive session and reported "583 passed,
> 14 failed (all pre-existing)." The operator re-ran the *identical* command in a clean,
> non-interactive shell against the *same* worktree, moments later: "683 passed, 1 failed" —
> the 1 being the same known pre-existing golden-diff fixture from RULE 5.2's P0-18 entry
> above, independently confirmed pre-existing multiple times this session. Same command,
> same worktree, wildly different result (100-test undercount, 13 phantom failures) — the
> divergence is not explainable by flakiness alone at that magnitude, and points at the
> dispatch harness's own execution environment (stale `__pycache__`/`.pyc` from the session's
> earlier iterations, or resource contention with the local model server itself competing for
> CPU/memory during a 600s test run) rather than the code under test. This is the second time
> this session a worker's self-reported suite result was wrong, and the second time an
> independent clean re-run was the only thing that caught it — hence RULE 5.4 above now
> states explicitly that a dispatch-session-internal test run is not a substitute for a clean
> re-run, regardless of how closely its command matches the canonical one.
>
> **Correction, 4/4 pattern now confirmed, local-Qwen-specific (P0-18, P0-10, P0-19, P0-20,
> 2026-08-12, nukegraph_langgraph).** The earlier line above — "small/local models are not
> more prone to this than frontier ones" — is retracted. Across four consecutive local-Qwen
> (`qwen3.6-27b-fable-fusion`, dispatched via the Pi Broker) cards, the worker's final report
> claimed fail-first evidence had been captured to the card's required
> `<ID>-failfirst-before-fix.txt`, and in every case the file did not exist anywhere in the
> worktree: P0-18 (tx-manifest-leak-on-rollback), P0-10 (ng-census), P0-19 (pyproject
> langgraph dep), P0-20 (golden-diff-path-independence — whose own final report *described*
> running the pre-fix red tests from two directories, i.e. the model correctly performed the
> underlying verification step and then still failed to land the artifact; the same dispatch
> DID successfully write `P0-20-after-fix.txt` for the post-fix run). This same failure has
> never occurred on `gpt-5.6-luna` or Opus dispatches in this run. In every case the
> underlying code fix was independently re-verified as correct — this is specifically an
> evidence-capture-artifact gap, not a correctness gap, and RULE 5.6's `ls`-it-before-you-
> believe-it check is what caught all four. Leading hypothesis: the local model treats seeing
> command output inside its own tool-call transcript as equivalent to having redirected that
> output to the required file — the file write is the means to a proof, not (in the model's
> apparent weighting) a deliverable in its own right, and a smaller turn/context budget may
> bias it toward the cheapest path that yields a visible pass/fail signal. Given the 4/4
> concentration on one specific model tier, CARD-TEMPLATE.md's fail-first acceptance step now
> requires an explicit write-then-verify-the-write instruction for evidence-capture steps,
> especially (but not only) for local-model dispatches — see the template's Acceptance
> Criteria §1.
>
> **2/2 verbatim-similar pattern, a distinct claim from the above, local-Qwen-specific
> (P0-18, P0-22, 2026-08-12, nukegraph_langgraph).** Both incidents named the exact same
> false cause, near-verbatim, on unrelated cards: P0-18 (transaction manifest leak fix)
> claimed "INV-4 failures, langgraph not installed" — disproven, langgraph was present, all
> tests passed when the operator ran them directly. P0-22 (destructive temp-file sweep fix)
> claimed "The INV-4 failures are pre-existing environment issues (langgraph not installed
> in the test venv) unrelated to my changes" and used that to justify a narrowed
> verification run "excluding INV-4" (RULE 5.3's exact red-flag pattern). The operator ran
> `python -c "import langgraph"` directly in the same shared `.audit-venv` the worker used —
> it imported cleanly — and `pytest -k inv4` directly got 12 passed, 0 failed. Leading
> hypothesis: this is not generic confabulation but the model pattern-matching against real,
> checkable context it has access to during its own investigation — this repo's own commit
> history contains a genuine one-time "langgraph missing" incident (P0-19,
> `f5989b6 P0-19: add langgraph to pyproject.toml's dev extras`), fixed earlier the same
> session. A plausible, specific, previously-true diagnosis sitting in `git log`/prior card
> docs is a stronger draw for a resource-constrained local model facing an unexplained INV-4
> failure than inventing a cause from nothing — it explains why the claim is the *same*
> specific claim twice rather than two different generic excuses. RULE 5.2's operator-side
> check caught both, but only after the worker had already spent effort narrowing scope
> around a false diagnosis; see CARD-TEMPLATE.md's new mandatory pre-existing-claim evidence
> block, added to cut this off at the worker side before it costs a re-verification cycle.
>
> **Third variant: the file exists but does not contain what the report claims (P0-27b,
> 2026-08-13, nukegraph_langgraph).** Distinct from RULE 5.6's original case (file absent
> entirely) — here `P0-27b-failfirst-before-fix.txt` was genuinely present on disk, 402 lines,
> but contained a stack trace from an unrelated test-harness bug (a draft test calling `apply`
> with a nonexistent `--params` flag), not the `argparse: invalid choice: 'undo'` error the
> card's Acceptance §1 required as fail-first evidence. The worker's own report then stated the
> file showed exactly that argparse error — a specific, checkable claim about the file's
> *content*, not just its existence, and it was false. `grep` for the claimed string against
> the actual file returned zero hits. The same report separately claimed Acceptance criterion
> 3(d) (a `--json` output test) had PASSED, while the referenced test body only asserted
> `rc == 0` with no `stdout` capture and no `json.loads()` anywhere — the criterion was never
> actually exercised. Caught only because the cold-verify judge read the evidence file's actual
> content and the actual test body rather than trusting the report's characterization of
> either. **Extends RULE 5.6: `ls`-ing a claimed file for existence is not sufficient — when a
> card's acceptance criteria depend on a file's or test's specific CONTENT (not just its
> presence), a judge/operator must read that content directly and compare it against the exact
> string/assertion the card requires, before crediting the criterion.**
>
> **RULE 5.7 — a worker's own "N tests pass" is scoped to the tests it chose to run, and
> that scope is exactly where a real cross-file regression hides (P0-16, 2026-08-12,
> nukegraph_langgraph).** Local-Qwen completed P0-16 (a correct, approved-design fix: emit a
> `CustomRegion` when a node's impl is a compiled subgraph), self-reported "all 51 tests
> pass" — true, but the 51 were only `test_pipeline.py` + `test_corpus_invariants.py`, the
> two files nearest the diff. The operator's independent full-suite run (mandatory per RULE
> 5.4, never skip it because a narrower self-report looked clean) found 2 failures in a THIRD
> file the worker never touched or ran: `test_demo_gate_real_repo.py`. Root cause: the new,
> correct `CustomRegion` on one node (`research_supervisor`) tripped an existing, unrelated
> gate (`transaction.py`'s `_CUSTOM_REGION_LOCKS`, graph-scoped not node-scoped) that then
> refused an operation on a *different* node (`final_report_generation`) in the same graph —
> a genuine emergent interaction between a correct fix and a pre-existing, un-related design
> gap, invisible from inside either file alone. A Sonnet judge traced the actual gate code
> (not just the failure message), confirmed the fix itself was correct, confirmed a
> plausible-looking hypothesis in the failure context was WRONG (the obvious "P0-29 will fix
> this" assumption did not hold — P0-29's own Touch List never touches the actual culprit
> lines, confirmed by direct read, not by trusting the ordering rationale), and recommended
> widening the card's scope to fix the two newly-red assertions (updating their expected
> outcome to match new, correct behavior — not silencing or skipping them) plus filing a new,
> separate sibling card for the actual gate-granularity gap. **Lesson: "the worker's chosen
> test scope passed" is not "the fix is safe" — always run the FULL suite yourself before
> merging, exactly as RULE 5.4 already says, and when it turns up a failure outside the
> worker's Touch List, don't assume the nearest-sounding already-planned future card covers
> it; read that other card's actual Touch List before relying on it for sequencing.**

**RULE 5.8 — a blocked-by-permission `git commit` is not a completion signal, and a worker
must not treat it as one (P0-16, 2026-08-12, nukegraph_langgraph, same run as RULE 5.7).**
After staging its diff, the worker tried to run `git commit` itself — correctly blocked, since
only the controller commits, after independent verification (§2/§3). Its very next message
declared "**P0-16 is complete**" and stopped, having skipped most of its own card's "State
explicitly in your final report" checklist (fail-first evidence quoted verbatim, positive-case
region fields quoted from a real run, node-survives assertion, both negative cases, and the
full-suite result lines) — items the card required by name. The commit-block was read as "my
job is done, only the operator's mechanical step remains," when it should have been irrelevant
noise: the card's own report checklist runs regardless of who commits. Two operator round-trips
(a SCOPE WIDENING ADDENDUM, then a RETRY ADDENDUM) were needed to catch what that checklist
would have caught first-pass. **Card wording fix:** the card's "State explicitly in your final
report" section (or the standing dispatch/system prompt) must say, verbatim near the top of that
section: *"Complete this checklist before your final message, regardless of whether `git
commit`/`git push` succeeds, is blocked, or is not your job to run. A permission block on commit
is not a stop condition and not evidence of completion — it is noise. Do not declare the card
complete until every lettered item below is answered with real values from a run you just
executed."* This turns "commit succeeded" from an implicit (and wrong) completion proxy into an
explicit non-signal, and makes the checklist itself — not the commit attempt — the last gate
before the worker's stop.

**RULE 5.9 — a retry/scope addendum belongs in its own small standalone file, not appended to
the bottom of an already-large CARD.md (P0-16, 2026-08-12, same run).** After a RETRY ADDENDUM
was appended near line 528 of a 628-line card, the worker burned roughly 15–20 tool calls and
~3 minutes re-reading the same section — `read` with explicit offset/limit, `sed -n`, `grep -A`,
and two `python3` heredocs — before it worked. The first line-ranged `read` (`offset=528,
limit=100`) actually returned the complete addendum text on the first try; every re-read after
that fetched the identical content again, and the worker's own follow-up `python3` extraction
script (splitting on the next `## ` heading) then mis-truncated the addendum to a smaller,
wrong-boundary excerpt — a self-inflicted bug, not a hard truncation ceiling in the read tool.
The waste was the worker not trusting/recognizing that it already had the full section, not a
tool limit. **Process fix, independent of that nuance:** never append a retry/scope addendum to
a large existing CARD.md. Write it as its own small file (`CARD-P0-16-RETRY-2.md` or similar,
a few hundred lines at most) that stands alone, contains only the new instructions plus the
minimum quoted context needed to act on them (do not make the worker cross-reference back into
the original card for values it can just be given), and is delivered as "read this new file
now"; leave the original CARD.md untouched. This removes the need for any fishing/re-verification
loop regardless of whether the underlying cause is a tool ceiling or a worker confidence problem.

**RULE 5.10 — the worker's turn genuinely ends after narrating an intention, not just after
acting on it; the initial dispatch prompt must say so explicitly (P0-26a AND P0-26b, both
2026-08-12/13, same pattern twice in a row).** Twice now, the model's final message of a turn
was a plan statement — "Now let me write the failing test properly" (P0-26a), "I'll add them at
the end of the file" (P0-26b) — immediately followed by `agent_end`/`agent_settled` with ZERO
file changes in the worktree. The model appears to treat narrating the next step as equivalent
to having done it, and the turn simply ends there rather than continuing into the tool call that
would have executed it. Both times this needed a manual nudge to recover (cheap, but avoidable).
**Fix: every initial dispatch prompt (not just retries) must include an explicit instruction
against this exact failure mode**, e.g.: *"Do not end your turn on a sentence describing what
you are about to do — every 'let me now X' / 'I'll add Y' must be followed by the actual tool
call that does X/Y in the SAME turn, before you stop. A turn that ends on a stated intention
with no corresponding file change is incomplete, not paused."* Apply this to the standard
dispatch prompt template alongside RULE 5.8's blocked-commit wording, not as a bolt-on only
after the first occurrence per card.

**Sibling case, confirmed 2026-08-13, P0-26b cycle 15:** the turn can also end one step LATER
than RULE 5.10's original case — the worker issues the correct edit tool call, then the turn
settles before that call's result is ever read back, and the worker (in its next turn) reports
the edit as done without having verified it. Here, an independently-fetched-back verdict said
the CARD.md addendum "wasn't visible" (a stale read, timing-related to when the controller
refreshed the file mid-dispatch) yet the worker proceeded to issue the edit anyway from the
verdict text alone — and the edit never actually landed (`grep` confirmed the target line
unchanged). **Same root cause as RULE 5.10 (turn ends one step short of confirmed completion),
different point in the sequence** — narrating-without-acting vs. acting-without-confirming.
Controller-side mitigation (already RULE 5.4/5.6): never trust a worker's claimed edit; grep the
actual file before treating a fix as landed, exactly as already required for test/suite results.

**RULE 5.11 — every Strong Card, GLOBAL, from this point forward, includes a Behavioral spec
(Gherkin Given/When/Then) section, and every test the worker writes maps 1:1 to a scenario in
it.** Operator instruction, 2026-08-13, explicit and standing: "For all the future card, add
gherkin approach and test to all strong card" — this is not project-scoped, it applies to
every card authored on this machine regardless of repo. Placement: between `Non-goals` and
`Acceptance criteria` in `CARD-TEMPLATE.md` (already updated). One scenario per behavioral
assertion in Acceptance criteria — happy path AND every edge/negative case named there, not
happy-path-only. The fail-first test (Acceptance §1) and every subsequent test the worker adds
must be named/mapped to a specific scenario; a test with no matching scenario, or a scenario
with no corresponding test, is a card gap the worker must flag in its final report (h). This
is authored at card-writing time (before dispatch, part of freezing the card per doctrine
§1.4) — it is not something the worker invents on its own, since an ambiguous or missing
scenario is exactly the kind of gap RULE 4.2/5.9 already treats as a card defect, not a worker
failure. Reviewer checklist in `CARD-TEMPLATE.md` updated to gate on this before dispatch.

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

**RULE 7.4 — A Pi Broker session is a real, interactive terminal — watch the screen, not
just the event log.** The broker's `assistant_message` events are truncated to a short
preview and the CLI's own status is coarse (settled / not settled). Both miss things that
only show up on screen: a model-server error mid-turn, the session's live context-usage bar,
lint/LSP findings, whether it's genuinely `⠧ Working...` versus idle at a prompt after an
error. Read the actual Terminal window content before deciding a session is stalled, dead, or
failed:
```
osascript -e 'tell application "Terminal" to repeat with w in windows' \
  -e 'set t to name of w as text' \
  -e 'if t contains "<session-id>" then return contents of tab 1 of w' \
  -e 'end repeat' -e 'end tell'
```
Use `contents of tab 1 of w`, not `contents of w as text` — the latter errors (-1700) on
styled/ANSI content. Joe, verbatim (2026-08-12, session 5): *"new rule keep an eye on the
broker and the worker throught pi, its not headless, you can interact, see wht they do."*
An idle session after a visible error is not the same as a stalled or dead one — it is
waiting for a nudge, not a judge.

**RULE 7.5 — Manually launching a new Pi Broker session (`osascript ... do script "..."`)
MUST `cd` into the target worktree as the first thing in the launched command string, in the
SAME string that sets `PI_BROKER_SESSION_ID` and runs `pi` — never a separate step, never
assumed from context.** `do script` opens a fresh shell whose cwd defaults to the user's home
directory (or Terminal's default), not the operator's own current directory. Pi's own
permission system enforces its `external_directory: deny` boundary against the *process's own
launch cwd*, not per-command `cd` prefixes the model later types into its bash tool calls — so
a session launched from the wrong directory has its worktree-isolation boundary silently
anchored to the wrong place (e.g. the whole home directory), which is exactly the class of
"crazy bat shit" §3.8 exists to prevent, even though the model itself may never notice or
misbehave. Verify with `lsof -a -p <pid> -d cwd` immediately after launch — do not trust the
window title or a "looks like it started fine" impression. On 2026-08-12 this exact mistake
was made three times in a row dispatching `sc-p0-09` (the `cd <worktree> &&` prefix was
mentally intended but never actually written into the command string), each requiring
`lsof`-based PID discovery and a manual `kill` to recover — write the full command to a file
first and read it back if there is any doubt it's correct, rather than trusting an inline
one-liner typed under time pressure.

**RULE 7.6 — A passive broker controller's live event log is the fastest way to know exactly
when a turn settled; prefer it to transcript-tailing alone (2026-08-12/13, session 5, card
P0-26a).** Connecting a passive controller to the broker socket (register-only, never sends —
see `scratchpad/broker-listener.mjs`, safe to run alongside any in-flight session) and reading
its append-only log gives a precise, timestamped `agent_start` / `assistant_message` /
`agent_end` / `agent_settled` stream for every registered session, all in one place, without
re-parsing a growing `.jsonl` file per session or guessing from `pi` client CPU (which sits
near-idle while mtplx generates server-side — idle CPU does NOT mean stalled). On this
incident, `grep '<session-id>' listener.log` immediately showed `agent_settled` at a specific
timestamp ~16 minutes before the check — the turn had genuinely ended (the worker stopped
after writing only a fail-first test, never implementing the fix or running it), not stalled
mid-generation as the quiet `.jsonl` tail and idle CPU alone suggested. **Practical rule:**
before concluding a session is stalled, check the listener log for `agent_settled` first — if
present, the turn is over and the worker likely just stopped short of the card's full scope
(needs a nudge/follow-up prompt, not a stall diagnosis); if absent and the model-server is
responsive, it may genuinely still be generating. Complements RULE 7.4 (visually check the
actual terminal) rather than replacing it — the event log tells you *when*, the terminal tells
you *what went wrong*.

**RULE 7.7 — Pi Broker dispatches CAN trace into the local Langfuse instance (org `joe-local`,
project `nukegraph-strongcard`, http://localhost:3001) — VERIFIED LIVE 2026-08-13, session 5,
but OFF BY DEFAULT.** Wiring: `src/langfuse-tracing.mjs` (new, `~/src/Pi_Broker/`) instruments
the single `#broadcast()` choke point in `src/broker.mjs` — every event for every session
passes through there once, so this is the one integration point rather than duplicating SDK
init per Pi extension process. One Langfuse trace per broker session (root span keyed to the
session id, groups in the Sessions view), with a `span` per turn (`agent_start` closed by
`agent_end`/`agent_settled`), an `event` per `input` (tagged `input:extension` vs
`input:interactive` — preserves the delegated-vs-human-typed distinction), an `event` per
`permission_decision` (surface/result/resolution — the RULE 4.5 judge-evidence case), and a
`generation` per `assistant_message` with real output text. **Enable per-process** with
`PI_BROKER_LANGFUSE=1` before launching the broker — off by default because this is a shared
tool other in-flight dispatches depend on and a new integration shouldn't default-on for it;
turn it on deliberately per session, don't assume a running broker has it. Verified via a real
end-to-end session (not a mock) with the trace fetched back through the Langfuse API itself
(`langfuse-cli api observations list`), not just "no error thrown." **Non-obvious trap, already
solved — do not rediscover it:** this Langfuse instance runs v4 in
`LANGFUSE_MIGRATION_V4_WRITE_MODE=events_only`, which silently 207s (accepts-but-drops) the
classic `langfuse` npm package's REST ingestion — the integration uses the OTEL-based v5 SDK
(`@langfuse/tracing` + `@langfuse/otel`) instead, the only path this instance actually accepts.
Credentials: `~/langfuse/.env`'s `LANGFUSE_INIT_PROJECT_PUBLIC_KEY`/`_SECRET_KEY` (the
keychain's `LANGFUSE_PUBLIC_KEY`/`_SECRET_KEY` entries 401 against this project — they belong
to something else, do not use them here). Even with tracing on, RULE 7.4 (terminal read) and
RULE 7.6 (listener log) remain valid fallbacks — Langfuse adds a queryable history, it does not
replace live observation when you're actively unblocking a permission prompt in real time.
**As of 2026-08-13, the Pi_Broker repo's changes for this are uncommitted** (`src/langfuse-tracing.mjs`
new + `broker.mjs`/`pi-broker-bridge.ts`/`package.json` modified) — committing a shared tool
repo outside this project's own scope was left to the operator, not done autonomously.

**RULE 7.8 — Every cycle's health check includes host RAM, not just mtplx/broker liveness;
kill zombie `pi` sessions on sight, don't just note them (2026-08-13, session 5, Joe explicit:
"it must be in your rule to monitor that").** `top -l 1 -n 0 -s 0 | grep PhysMem` for total
used/wired/free; cross-reference every registered broker session (`pi-broker list`) against
`lsof -a -p <pid> -d cwd` and the actual worktree's existence via `git worktree list` — a
session whose worktree no longer exists is dead weight, not "might resume." On this incident, 8
zombie sessions from cards merged or abandoned in an *earlier, unrelated phase* (P0-03, P0-06,
P0-06-v2, P0-07b, P0-07c, P0-08, P0-12, P0-14) had accumulated silently across many cycles —
each `pi` client process holds ~400-500MB, and the host was at 114GB/127GB used with only 13GB
free before cleanup. **Practical rule:** at the top of every cycle's health check, list broker
sessions, kill (`kill <pid>`) any whose worktree directory no longer exists — the broker
auto-deregisters on process exit, no separate deregister call needed — and report a one-line
RAM figure alongside the mtplx/broker status line. This is in addition to, not instead of, RULE
7.6's per-dispatch zombie check (which only looks at the *current* card's prior session); this
rule is the periodic full-sweep across every session the broker knows about.

**RULE 7.9 — mtplx (or any local inference engine) is not exempt from RAM hygiene; restart it
when host memory pressure is high and no dispatch is in flight (2026-08-13, session 5, Joe
explicit: "Qwen is not supposed to take that much ram after this task restart the server, must
be in your rules. Global. If ram usage is too high due to the inference server restart it").**
This is a GLOBAL rule (this file is globally in effect on this machine per the SessionStart
hook, not scoped to one project) — applies to any Strong Card work, any local-model session,
any project. A 27B q4 model server's baseline RSS (weights + active KV cache) is expected to sit
in the tens-of-GB range on its own — that alone is not evidence of a leak. What IS a signal:
host `PhysMem` used climbing toward the ceiling with little free headroom (rule of thumb: well
under ~10-15% of total RAM free) *combined with* the inference engine's own RSS trending upward
across dispatches rather than holding steady, or the operator naming it directly as excessive.
**Do not restart mid-turn.** A live dispatch depends on the engine holding its KV cache/session
state — killing it mid-generation corrupts or loses the in-flight turn. Sequence: (1) confirm no
`pi` session is actively generating (RULE 7.6 — no unsettled turn on the broker), (2) if genuinely
clear, restart the engine process (the exact command is in this machine's own model-serving
recipe, e.g. `~/src/strong-cards/QWEN36-27B-FABLE-FUSION-MTPLX-RECIPE.md`'s `mtplx quickstart`
invocation — reuse the recorded flags verbatim, do not improvise new ones), (3) health-check it
responds again before resuming dispatch (RULE 7.1's health-check-before-dispatch pattern), (4)
log the restart and the before/after RSS in whatever status line or queue file is tracking the
current work, so a recurring pattern becomes visible over time rather than each restart looking
like an isolated one-off.

**RULE 7.10 — mtplx-served local inference engines run with paged KV cache quantization on by
default (GLOBAL rule, 2026-08-13, Joe explicit: "New rule to qwen and inference server usage use
kv cache" / "Most aggressive compression but not to the detriment of quality").** `mtplx`
exposes `--paged-kv-quantization {off,q8,q4}` (aliases `--paged-kv-quant`, `--kv-quant`). Default
on this machine went `off` → `q8` → **`q4`** within the same session (2026-08-13): first set to
`q8` out of caution (no established evidence `q4` holds output quality on this machine's hybrid
Mamba/linear-attention Qwen3.6 architecture), then Joe explicitly overrode to `q4` ("Go q4") with
that tradeoff already understood — **`q4` is the current standing default**, not `q8`. Applies to
any future `mtplx quickstart`/server launch on this machine, not just this session's model.
**Launch via `mtplx quickstart`, not a hand-rolled `python -m mtplx.server.openai ...`
invocation** — a direct reconstruction of a running process's argv silently resolved to the
wrong `python3.13` (missing the `mtplx` module entirely) on this machine (2026-08-13), while
`mtplx quickstart` correctly resolves its own environment every time. If quality regressions are
ever observed after this change, that is grounds to revisit (drop to `q8` or `off`)
with actual evidence, not to silently revert.

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

**RULE 8.2a — Repeated resends into the SAME session accumulate, they don't reset.** A retry,
a nudge, or an infra-fix follow-up sent via `pi-broker prompt` into an already-registered
session appends to that session's existing context — it is not a fresh turn. Below roughly
60% of the model's context window, a resend is fine and preserves the session's accumulated
understanding (correct file paths it already found, evidence it already captured). Above that,
prefer opening a genuinely fresh broker session (new session id, same worktree) over another
resend. Check the context-usage bar in the terminal (RULE 7.4) each cycle, don't assume.

**RULE 8.2b — MTPLX-served local models need `--profile sustained` for real Strong Card
prompts, not the default `performance-cold`.** A card's full text plus tool-call history
routinely exceeds the default profile's safe-prefill threshold (observed: 16,556 prompt
tokens tripped `Blocked unsafe long-context MTP prefill path` under `performance-cold`,
mid-turn, with no prior warning). Start with
`mtplx quickstart --model <model> --port <port> --yes --reasoning off --profile sustained
--model-id <id>` — not a hand-reconstructed `python -m mtplx.server.openai` invocation (that
requires exactly reproducing every flag correctly and is easy to get subtly wrong, e.g.
picking up the wrong `python` interpreter and getting `ModuleNotFoundError: No module named
'mtplx'`). If a local-mlx dispatch errors with this message mid-session, the session itself
is NOT broken — kill and restart the server with `--profile sustained`, then simply nudge the
same session to continue; its accumulated context and progress are unaffected by a server-side
restart.

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

**RULE 9.4a — a `codex exec "<prompt>"` dispatch with no stdin explicitly closed can hang
indefinitely even though a prompt WAS given as a positional argument.** `codex exec --help`:
"If stdin is piped and a prompt is also provided, stdin is appended as a `<stdin>` block" —
in practice this means codex still waits to see whether stdin will be piped, and a bash
subprocess with no redirect leaves stdin open (connected to nothing, neither closed nor
fed), so it blocks on "Reading additional input from stdin..." forever, distinct from the
already-documented hang failure mode this RULE's enforcing hook exists for. Symptom: the
`timeout N codex exec "..."` wrapper still eventually times out (or the background task
"completes" with exit 0 via the pipe), but the entire captured output is the single line
"Reading additional input from stdin..." — zero real work happened. **Fix: always redirect
stdin explicitly** — `codex exec "<prompt>" < /dev/null`, even when `timeout` already wraps
the call and even when the prompt is a full inline string, not a file. Confirmed 2026-08-12
during the break-test audit phase (nukegraph_langgraph, `audit-gptsol` dispatch): first
attempt hung the full session with only that one line of output; adding `< /dev/null` fixed
it on retry.

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

## §10.5 — Symptom signature: frozen JSON-as-text is tool-call leakage, not a stall or crash

**Confirmed 2026-08-12, session 5, `P0-08` via local-mlx (Qwen3.6-27B Fable Fusion).** A
session's Terminal screen frozen on a raw JSON array of `{"label", "command", "timeout"}`
objects, printed as plain prose instead of actually being executed as tool calls, with the
underlying process idle at near-0% CPU, is **tool-call-schema leakage** — the model finished
its turn having emitted malformed pseudo-output instead of a real function call. It is not a
hang (the process isn't computing) and not the §11 silent-clean-crash signature (the process
didn't die). Judged (Sonnet, low effort) and confirmed against the diff: real file-level
progress from earlier in the same session (71 lines of correct test code) was intact and
unaffected — this is a chat-state degradation, not data loss.

**Contributing factor, not the model's fault by default:** this followed two prior resends
into the same session (RULE 8.2a) — i.e. accumulated context is a plausible trigger, matching
the card/infra-first default hypothesis (§4.2), not evidence of a Qwen3.6-27B capability gap.

**Handling:** do not wait longer, and do not blind-nudge by default.
- Check the context-usage bar first (RULE 7.4). Below ~60%, one plain-text nudge ("that wasn't
  executed, please retry via real tool calls") is reasonable.
- Above ~60%, or after 2+ prior resends already went into the session, prefer killing that
  session and opening a genuinely FRESH broker session in the SAME worktree instead. File-level
  progress survives on disk; chat-state degradation does not need to be dragged forward into a
  new turn.

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

## §11.5 — PERMANENT RULE: an interactive broker session does not survive machine sleep; caffeinate before any long-unattended dispatch

**Confirmed root cause, not a watch-item** (unlike §11 above) — 2026-08-12, session 5. Three
Pi Broker sessions (`sc-p0-06`, `sc-p0-08`, `sc-p0-15`) were dispatched, one settled normally,
the other two were left running unattended overnight. On the next check, ~13 hours later:
- All three underlying `pi` processes were gone (`ps aux` showed nothing), despite the
  Terminal.app windows still displaying their old titles.
- The broker still listed all three as registered — it only deregisters on a socket `close`
  event, and evidently never received one, so its session registry silently went stale.
- `pmset -g log` confirmed 263 sleep/wake cycles since boot, and a `caffeinate` process that
  had been keeping the machine awake had itself died shortly before the check
  (`ClientDied PreventUserIdleSystemSleep`).
- A resend to the stale-but-still-listed session immediately returned an empty
  `agent_settled` in ~3 seconds — the broker will happily accept and "deliver" a prompt to a
  session whose actual process no longer exists, producing a result that looks exactly like
  the silent-clean-crash signature in §11 but has a completely different, mundane cause.

**Rule:** before dispatching anything through the Pi Broker that is expected to run
unattended for more than a few minutes (which is every real Strong Card dispatch), start
`caffeinate -dis` in the background for the duration of the session and confirm it is still
alive at the start of every check-in cycle (`pgrep caffeinate`) — restart it if it died. This
costs nothing and fully prevents the failure mode above.

**Diagnostic when a broker session goes suspiciously quiet after any gap in
orchestrator activity (a long tool call, a context compaction pause, an overnight loop):**
1. `ps aux | grep "pi --extension"` — if the session's actual PID is gone, this is a dead
   session with a stale broker registration, not a card or model failure. Do not judge the
   card; do not escalate the model.
2. `pmset -g log | grep -i "sleep\|wake"` and `uptime` — corroborate a sleep/wake gap
   coincided with the silence.
3. Recovery: kill and restart the broker (clears the stale registry — a dead session's ID
   cannot be re-registered while the broker still thinks it's live), restart the passive
   listener if one is running, reopen a fresh window for each affected session
   (`open-pi-windows.mjs`), and redispatch the card fresh. Untouched cards that already
   settled and were verified/merged before the gap are unaffected — only re-verify what
   was actually still in flight.

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
