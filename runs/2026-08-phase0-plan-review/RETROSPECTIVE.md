# Retrospective — Phase-0 exit-gate plan verification (2026-08-11)

## What this run was

Not a card-execution run. An **adversarial verification of an entire un-dispatched plan**:
16 Strong Cards (P0-00–P0-15), produced by an Opus research+planning pass for
nukegraph_langgraph's remaining Phase-0 backend gaps, reviewed by a second, independent Opus
instance against this repo's own `RULES.md`/`CARD-TEMPLATE.md`/`JUDGE-PROTOCOL.md` before a
single card was dispatched to any worker.

Full artifacts: `nukegraph_langgraph` repo,
`docs/reviews/phase0-exit-gate-2026-08-11/{RESEARCH.md,PLAN.md,EXECUTOR-MAP.md,VERIFICATION.md,cards/}`.

## Verdict

**6 CONFORMS / 9 NEEDS-CHANGE / 1 REJECT-and-split**, out of 16. Overall plan quality: "well
above the CARD-TEMPLATE bar" on grounding, scope fences, and negative-case acceptance — but
**not dispatch-ready** for a structural reason common to all 16 cards, not a quality problem
with any individual one.

## The systemic finding: none of the 16 cards were provisioned for a fresh worktree

Proven, not asserted: the reviewer spun up a real throwaway worktree from the plan's baseline
commit and confirmed it had no `.audit-venv`, no `.audit-scratch/`, no
`.audit-cases-20260808/` — all gitignored. Every card's Acceptance section ran
`../../.audit-venv/bin/python` against a suite whose `test_probe.py` needs 31.6 MB of
gitignored fixtures. **Every card, as written, would fail on dispatch for a reason that has
nothing to do with the defect it targets.** This produced RULES.md §3.7 and a mandatory
"Worktree provisioning" section in `CARD-TEMPLATE.md`.

## Per-card findings that generalized into rules (§12)

- **Headline finding re-verified by execution, one citation corrected** (§12.1): `add_node(fn)`
  genuinely drops the node, but at `pipeline.py:617` via `builder.py:271`'s tier-C gate, not at
  the cited `pipeline.py:618-620` (unreachable for that call shape). `builder.py` was missing
  from P0-03's Touch List.
- **A second, worse defect site missed** (§12.2): P0-05 fixed one `Command(goto=)`
  unscoped-attribution site (`r7_skeleton:343-348`) but missed a second
  (`command_goto_targets:328-338`) that silently suppresses a diagnostic rather than merely
  fabricating an edge — the more dangerous failure mode of the two.
- **A false parallel-safety claim in the executor map** (§12.3): two cards claimed independent
  both actually shared a Touch List file (`cli/main.py`); a second pair shared two files
  outright under an offered "concurrent + manual merge" plan, declined.
- **A card too large to have been frozen as one** (§12.4): P0-07 spanned ~18 files across
  three distinct kinds of work; rejected and split into P0-07a/P0-07b before dispatch — a
  second real-world instance of the R3 sizing lesson (§8.4), this time caught before a
  dispatch failure rather than after.
- **An "unresolvable" routing question resolved by searching harder** (§12.5): the DeepSeek
  Flash 0731 model ID and its ToS-compliant routing (`claude-qwen` + `QWEN_MODEL=`) existed in
  memory outside the project's own scope. Found in minutes. The cards stayed on Luna anyway —
  Qwen's Token Plan ToS prohibits the non-interactive batch processing Strong Card dispatch is,
  an operator decision on firmer ground than "routing unknown."

## What changed in this repo as a result

- `RULES.md` — new §3.7 (worktree provisioning is mandatory and must be proven by a real
  throwaway-worktree run, not asserted) and new §12 (five plan-authoring lessons above).
- `CARD-TEMPLATE.md` — new mandatory "Worktree provisioning" section per card, and two new
  reviewer-checklist items (provisioning stated + tested; every Defect claim re-derived by the
  dispatcher, not trusted from an upstream plan document).

## Why this matters beyond one plan

§4–§8 harden a card against failing **during** dispatch. This run is the first evidence that
the same discipline — verify, don't trust; re-derive, don't cite; check file-overlap
mechanically, not by assertion — has to apply to the **plan that produces the cards**, before
any dispatch happens at all. A perfectly-written card that cannot run in its own sandbox is not
a partial success; it is a plan that has not yet been tested against reality.
