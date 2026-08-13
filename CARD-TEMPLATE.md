# Strong Card template

Copy this per card into `.audit-scratch/cards/<ID>-<slug>.md`. The shape below is the one
that closed 20 base cards + 11 sub/recovery cards in the 2026-08 nukegraph run — it is not
a proposal, it is the shape that worked.

**Before you write the card, do the grounding investigation.** Read the real code. Every
`Defect` claim below must quote current code at a current line number. A card written from
the plan document alone, without reading the file, is how you get "stale line refs" — the
single most common judge finding (RULES §4.2).

**Freeze the card before dispatching** (doctrine §1.4). Edits after dispatch are a new
attempt, not the same attempt.

---

```markdown
# <ID> — <one-line imperative title>

## Source
Where this card comes from: plan document + section, audit finding, or parent card it was
split from. Name the exact file(s) it targets.

State explicitly whether this is a FIX to existing broken code or a GREENFIELD addition —
and say how you confirmed it (e.g. "confirmed via repo-wide grep, `is_healthy()` does not
exist anywhere today"). This determines what "fail-first" can even mean (see Acceptance).

## Defect / gap
Verified directly against the CURRENT state of the code. Quote it:

```python
# path/to/file.py:98-129
def _watch_loop(self) -> None:
    ...
        except Exception as exc:
            logger.error(...)
            return   # line 129 — thread silently terminates here
```

Then explain, concretely, what goes wrong and what observable consequence it has. Name every
attribute/flag involved and its real current semantics.

If there is a SECOND defect site, name it here — a missed second site is the #1 cause of a
card failing and needing a judge (RULES §4.2). If a nearby surface looks related but is
deliberately out of scope, say so explicitly and say why.

Pre-empt the obvious wrong fix: "if `is_healthy()` were implemented as `return self._running`
it would be WRONG, because `_running` is a start/stop *intent* flag, not liveness."

**Test coverage confirmed absent/present**: state how you checked (which files, which greps).

## Fix
Numbered steps. Each step says what to do AND what not to do around it.

1. <concrete change, with the file and the reason>
2. <...>
3. Where a decision is genuinely ambiguous, say so and give the tiebreaker — do not leave
   the worker to guess: "if genuinely ambiguous, implement the minimal version, because
   <concrete reason>."

### Do NOT touch (scope fences)
Explicit, itemized. Name the mechanisms by their card ID where they came from another card —
this is what stops a worker from "helpfully" reverting a verified fix.

- Do NOT change <X>'s exception-handling behavior — this card is about DETECTING, not recovering.
- Do NOT touch <Y> — different mechanism, out of scope.
- Do NOT touch R<n>'s <mechanism>, R<m>'s <mechanism> — separate, already-correct, already-verified.
- Do NOT add auto-restart / retry / caching / any capability not listed in Fix. If tempted,
  note it in your report and do not do it — that is scope creep.

## Touch List (only these files)
- `path/to/production_file.py`
- `path/to/other.py`  ← only if <condition>; read it fully first to confirm the change is safe
- `tests/test_thing.py`

> Enforcement note: this list is intent. The actual boundary is the dedicated git worktree
> and the pre-merge `git diff --stat` / `git status --porcelain` review (RULES §3).

## Worktree provisioning (RULES §3.7 — mandatory, do not skip)
A fresh `git worktree add` gets ONLY what git tracks. Any dependency the Acceptance
commands need that is gitignored — a `.venv`/interpreter, a large fixture corpus, a symlinked
scratch dir — is **silently absent** unless this card says exactly how it gets into the
worktree before dispatch. State this explicitly, even when the answer is "nothing extra
needed":
- `<none — this card's acceptance commands need only what git tracks>`, OR
- `ln -s <shared-resource-abs-path> <worktree>/<name>` (one line per resource), run
  BEFORE dispatch, as part of the operator's worktree-setup step, not the worker's job.

Before dispatching ANY card in a batch/plan (not just this one), spin up one throwaway
worktree from the plan's baseline commit and actually run this card's Acceptance §5 command
in it. If it fails for a missing-resource reason, the card's provisioning line is wrong —
fix the card, not the worktree ad hoc. See RULES §3.7 for why this is mandatory, not optional.

**If a `.audit-venv` (or any other shared, symlinked interpreter) is one of the provisioned
resources, this card's worker instructions MUST state RULE 3.7.4 explicitly, verbatim or
equivalent:** a symlinked venv's editable package install is a MUTABLE SHARED RESOURCE — it
resolves to whichever copy of the source was last `pip install -e`'d into it, almost always
the main repo, NOT this worktree's own edits. Plain `.audit-venv/bin/python -m ...` or
`.audit-venv/bin/ng ...` will silently test the WRONG code and produce confusing,
inconsistent results with no error. The worker must instead either:
- run `PYTHONPATH="$WT/<path-to-src>" .audit-venv/bin/python -m <entry module> ...` to force
  Python to import from the worktree's own source ahead of the installed package, or
- use `.audit-venv/bin/python -c "import sys; sys.path.insert(0, '$WT/<path-to-src>'); ...`
  to the same effect,

and must NEVER run `pip install -e` / `uv pip install -e` against the shared `.audit-venv`
itself — that would repoint the venv at this worktree's source for every OTHER concurrent
dispatch too, corrupting their results with zero error signal. A worker whose report shows
confusing exit-code or behavior mismatches after touching source files that should have
changed observable behavior almost always means it forgot this and is silently testing stale
main-repo code — that is the first thing to check before concluding INVALID_CARD or a model
capability problem.

**The same pitfall applies to any test the worker AUTHORS that itself spawns the CLI as a
subprocess** (e.g. `subprocess.run([sys.executable, "-m", "<entry module>", ...])` to test
`--json` output, exit codes, or stdout/stderr shape end-to-end) — not just the worker's own
manual invocations. `pytest`'s `pythonpath = [...]` config setting (pyproject.toml) only
affects `pytest`'s own import resolution; it is NOT inherited by a child process spawned via
`subprocess.run` unless the test explicitly passes it through. A `subprocess.run(...)` call
with no `env=` argument inherits the *calling* environment, which usually has no PYTHONPATH
set either, so the subprocess resolves the CLI against `.audit-venv`'s stale editable install
— exactly the same silent-wrong-code failure mode as a manual invocation, but inside a test
the worker itself wrote and therefore harder to blame on "forgetting" the mitigation. Any
card whose acceptance criteria require a subprocess-based CLI test must say so explicitly:
the test's `subprocess.run` call must pass `env={**os.environ, "PYTHONPATH": str(<worktree
src path>)}` (or equivalent) so it is self-contained and correct regardless of who invokes
pytest or how. Confirmed 2026-08-12 (nukegraph_langgraph, P0-23): a worker's own schema-
conformance test showed the full pre-fix failure count even though the underlying fix was
verified correct by direct invocation, because its `subprocess.run` call to exercise the
real CLI had no `env=` and silently tested the shared venv's stale install.

## Non-goals (≥ 2, explicit)
- <capability deliberately not built>
- <refactor deliberately not done>

## Behavioral spec (Gherkin — mandatory, RULES §5.11)
Every card states its behavior as Given/When/Then BEFORE the worker writes any test. This is
the bridge between `Defect` (what's wrong) and the fail-first test (proof it's fixed) — it
forces the acceptance criteria to be phrased as observable behavior, not implementation detail.

One scenario per behavioral assertion in Acceptance criteria below (happy path + every edge
case named there — do not write only the happy path):

```gherkin
Scenario: <short name matching Acceptance criterion #2>
  Given <concrete starting state — real fixture/file/call, not "some input">
  When <the action that exercises the defect/gap>
  Then <the observable, assertable outcome — matches an actual test assertion>

Scenario: <edge/negative case matching Acceptance criterion #3>
  Given <...>
  When <...>
  Then <...>
```

The worker's fail-first test (Acceptance §1) and each subsequent test must map 1:1 to a
scenario here — name the test after the scenario (e.g. `test_watcher_updates_ir_on_py_change`
↔ "Scenario: external edit triggers re-analysis within 300ms"). A test with no matching
scenario, or a scenario with no matching test, is a card gap — flag it in the report per (h).

## Acceptance criteria — FAIL-FIRST MANDATORY
1. **Write the failing test FIRST and capture its output before the fix exists.** Save it
   (e.g. `<ID>-failfirst-before-fix.txt`) and paste it in your report. A test written after
   the fix proves nothing about the defect.
   - For a GREENFIELD card where the method doesn't exist yet, the fail-first evidence is
     the `AttributeError` / `ImportError` — say so explicitly, that IS the gap.
   - **The write is a deliverable, not a side effect — verify it landed before doing
     anything else.** Confirmed 4/4 on local-Qwen dispatches via the Pi Broker
     (RULES §5.6: P0-18, P0-10, P0-19, P0-20, 2026-08-12, nukegraph_langgraph): the worker
     ran the pre-fix red test, saw the failure in its own tool output, narrated in its final
     report that it had "captured" that output to `<ID>-failfirst-before-fix.txt` — and the
     file did not exist anywhere in the worktree. In every case the code fix itself was
     correct; only the evidence FILE was never actually written. Seeing the failing output in
     a bash tool call's own transcript is not the same as having redirected it to disk. To
     close this gap, the card's instructions to the worker (verbatim or equivalent, and
     mandatory for any local-model dispatch — optional but recommended for frontier
     dispatches too):
     ```
     1. Run the fail-first command with output redirected to the exact required filename:
        <command> > <ID>-failfirst-before-fix.txt 2>&1
     2. Immediately `cat <ID>-failfirst-before-fix.txt` (or `wc -l`) to confirm the file
        exists on disk and is non-empty, and paste that confirmation in your report.
     3. Only THEN proceed to the fix. Do not treat step 1's on-screen output as sufficient —
        the operator will `ls` the file directly (RULE 5.6) and a missing file fails
        acceptance regardless of how correct the underlying fix is.
     ```
   - **A "pre-existing / environment issue" claim requires literal proof pasted in the
     report, not a narrated diagnosis — treat an unproven one as false by default.**
     Confirmed 2/2, local-Qwen-specific (RULES §5.2: P0-18, P0-22, 2026-08-12,
     nukegraph_langgraph): the worker claimed, near-verbatim both times on unrelated cards,
     that INV-4 failures were a "pre-existing environment issue (langgraph not installed)"
     and used that to justify narrowing its own verification — both times false; the
     operator ran `python -c "import <thing>"` directly in the same venv and it imported
     cleanly, and the full test target passed with 0 failures when run unnarrowed. Before
     ANY worker (not just local-model dispatches) may claim a failure is pre-existing or an
     environment issue, it MUST run and paste the literal output of a direct verification
     command proving the claim (e.g. `python -c "import <module>"` for a missing-dependency
     claim, or a baseline-checkout re-run for a "pre-existing" claim generally) — not a
     description of having checked, the actual command and its actual output. A
     "pre-existing" claim with no pasted verification output is to be treated as false and
     the finding investigated as a real regression, per RULES §5.2.
2. <behavioural assertion 1 — specific, with the mechanism to trigger it; if a background
   thread is involved, say "poll/wait for termination before asserting, do not assert
   immediately — that is racy">
3. <behavioural assertion 2 — the negative/edge cases, not just the happy path>
4. Confirm ALL existing tests in the touched test file(s) still pass unchanged. Run the file
   directly and paste the pass count.
5. Run the full suite **twice in a row**:
   ```
   cd <dir> && timeout 240 <python> -m pytest -q <known-flake exclusions, if any>
   ```
   Both runs green, at or above the current baseline count of **<N>**. Investigate if
   materially different — do not report a lower number as "fine".
   - **Do not add new `--ignore` / `-k` / skip flags** beyond the documented known-flake
     exclusions above. Narrowing the suite to make it green is a card failure (RULES §5.3).
6. Keep your own context small: redirect test output to files and `tail`/`grep` the summary
   back. Prior cards in this queue hung the local model server on context bloat (RULES §8.3).

## State explicitly in your final report
Verification must not depend on the worker choosing what to mention. Enumerate it:

(a) the fail-first evidence — the test output from BEFORE the fix;
(b) <assertion 1>'s pass status and its evidence;
(c) <assertion 2>'s pass status;
(d) whether the optional/conditional change was made, and why or why not;
(e) confirmation that all existing tests in the touched files pass unchanged, with counts;
(f) the two full-suite run results, with pass counts, verbatim from the summary line;
(g) the complete list of files you created, modified, or deleted — including anything
    outside the Touch List, and why;
(h) anything you were tempted to change and did not.

## Failure protocol
If blocked, ambiguous, or the code does not match this card's `Defect` section: STOP and say
so in your report (`INVALID_CARD` is honorable — doctrine §1.6). Do not improvise a different
fix, do not widen scope to make something pass, do not delete a failing test.
```

---

## Reviewer checklist before dispatch

- [ ] Every `Defect` claim quotes real current code at a real current line.
- [ ] Touch List ≤ 3 files (local model) — if more, split first (RULES §8.4).
- [ ] Every other card's mechanism that lives in these same files is named in `Do NOT touch`.
- [ ] Scope-fence dependency sweep complete (RULES §12.8): for every `Do NOT touch`
      file/test and every Fix behavior being removed or changed, grep/trace for dependency,
      run each plausible dependent test on baseline, and record the resolution in the card.
      No fenced test may depend on behavior this card is required to delete or alter.
- [ ] Fail-first is explicitly mandatory and the "what if it's greenfield" case is answered.
- [ ] For a local-model dispatch: the write-then-`cat`-to-confirm instruction for every
      required evidence file is present verbatim (RULES §5.6, 4/4 local-Qwen pattern).
- [ ] The baseline suite count is stated as a number, not "current baseline".
- [ ] The report checklist (a)–(h) is enumerated, not "report what you did".
- [ ] The card is frozen. The worktree exists. The tree is committed (RULES §2, §3).
- [ ] Worktree provisioning is stated explicitly (RULES §3.7) — and was actually test-run in
      a throwaway worktree, not just asserted.
- [ ] Every `Defect` claim was re-derived by execution/grep against CURRENT code by whoever is
      dispatching, not trusted from an upstream plan/research document — even an Opus-authored
      one (RULES §12.2).
- [ ] Behavioral spec (Gherkin) is present, one scenario per Acceptance criterion, including
      edge/negative cases — not just the happy path (RULES §5.11).
