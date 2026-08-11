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

## Non-goals (≥ 2, explicit)
- <capability deliberately not built>
- <refactor deliberately not done>

## Acceptance criteria — FAIL-FIRST MANDATORY
1. **Write the failing test FIRST and capture its output before the fix exists.** Save it
   (e.g. `<ID>-failfirst-before-fix.txt`) and paste it in your report. A test written after
   the fix proves nothing about the defect.
   - For a GREENFIELD card where the method doesn't exist yet, the fail-first evidence is
     the `AttributeError` / `ImportError` — say so explicitly, that IS the gap.
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
- [ ] Fail-first is explicitly mandatory and the "what if it's greenfield" case is answered.
- [ ] The baseline suite count is stated as a number, not "current baseline".
- [ ] The report checklist (a)–(h) is enumerated, not "report what you did".
- [ ] The card is frozen. The worktree exists. The tree is committed (RULES §2, §3).
