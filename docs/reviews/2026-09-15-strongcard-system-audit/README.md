# Strong Card system audit — 2026-09-15

4-model panel requested by Joe: "audit the strongcard system, see the past failures, see where its strong, where its weak and give REAL recommendations on how to streamline it, how to improve it, how to make it run cheaper and better."

## Panel — all 4 complete

| Reviewer | File |
|---|---|
| Fable5.1 high | `fable5.1-high.md` |
| Opus medium | `opus-medium.md` (addendum after a card-history sweep) |
| GPT-6 Astra xhigh | `gpt-6-astra-xhigh.md` |
| GPT-5.6 high | `gpt-5.6-high.md` |

## Headline convergent finding (all 4 agree, independently)

The system's biggest problem is **adoption, not rigor**: grounding/enforcement mechanisms get built, verified, and then don't ship or don't get used — and worse, two of the four independently *tested* the mechanisms and found them not to work as claimed even where they exist.

- **Opus:** `T08Lifecycle.run_phase` raises `T08UnsupportedCardKind` for Strong Card REMEDIATE — and REMEDIATE is 75% of all historical verdicts (21 of 28 recorded cards). The card fixing this (REMEDIATE v2) is itself sitting unshipped, and (as of this audit) failing its own re-review 2-of-3.
- **Fable5.1 high:** the one hook meant to genuinely block risky dispatches (`sc-dispatch-sandbox-guard.sh`) doesn't cover the `codex-gpt`/Agent route used all session — worktree safety there ran on convention (an agent instruction file), not enforcement. GPT-5.6 high independently confirmed this by directly testing it: a simulated `codex exec` dispatch was silently ignored by both the installed and canonical guard copies, while the equivalent OpenCode dispatch into the primary tree was correctly blocked.
- **Astra (the sharpest version of this):** actually ran the Receipts validator against 4 adversarial fixtures (Docker mocked) — **all 4 invalid receipts returned PASS**, including a nonexistent receipt reference and an explicitly-false prerequisite claim. Astra also ran all 11 real session cards through Builder's actual `parse_strong_card()` — **zero were ingestible** (title-format and Touch-List-heading mismatches). GPT-5.6 high reached the same verdict independently: "do not let Receipts gate freeze in its current form."
- **Opus:** only 5 of 13 self-identified improvement proposals (`docs/STRONG-CARD-IMPROVEMENTS.md`) have been adopted.

**This directly answers Joe's earlier question ("do we have something for how we present the card to the agent, how we make them?")** — yes, `CARD-TEMPLATE.md`/`RULES.md`/`JUDGE-PROTOCOL.md`/`CONSTRUCTION-PROTOCOL.md` are that thing, but the template that's actually being handed to agents produces cards Builder's own parser can't ingest, and mandates a heavy Construction-packet section (PB0–PB10) that every shipped card this session ignored.

## Other major findings

- **Reviewer identity is unprovable.** Opus found 3 recorded cases where a review filed under one model's name (e.g. "Terra") was actually produced by a different model (astra), patched after the fact by a `metadata-correction.json`. Undermines "coder ≠ grader ≠ breaker" at its root.
- **Gates are provably defeatable.** A demonstrated mutant inferred delivery from phase names and passed all 7 gates on one card; another green mutant run rewrote 43 tracked proof logs (absolute-path serialization bug) — a gate run can silently mutate the evidence it's judged against.
- **Actor separation is process discipline, not a real security boundary** (GPT-5.6 high, Astra both independently confirmed): the mechanism is caller-supplied string inequality — the card itself admits the same process can fabricate a distinct actor name, and the daemon's `finish_attempt` RPC accepts JSON without authenticating the peer at all. Astra's live in-memory probe reproduced this: accepted an attempt under a different actor with no judge verdict, then let the original coder overwrite it via `retry` with an arbitrary verdict.
- **A background dispatch is marked "settled" before the process exits** (GPT-5.6 high and Astra both flag this as the single most dangerous unflagged issue): `t03_runner.py` writes `"launched"→"settled"` at launch time, not at exit; process handles live only in an in-memory dict (lost on controller restart); stdout/stderr go to `DEVNULL`. This is a false durable-state transition combined with evidence destruction — the exact mechanism behind this session's "still running... actually orphaned" incidents. **Flagged as a blocking repair before the next parallel Builder dispatch.**
- **No cost/token telemetry exists anywhere** — comparative cost/efficiency claims (including these audits' own) are unproven without wiring dispatch cost into the already-running global Langfuse instance.
- **Receipts fragility (Fable5.1 high, Astra, GPT-5.6 high all independently found overlapping issues):** cries wolf on any commit shifting line numbers (matches `file:line`, not content); only `R<n>` claim-receipts are actually replayed — `B<n>` reverse-reachability receipts (the exact mechanism meant to catch the daemon bypass) pass on mere line-existence; cleanup force-removes *every* container on the shared image, so concurrent receipt checks can kill each other; no per-command timeout in the sandboxed replay, and output goes to a host temp file with no byte cap.
- **The delete-guard has a git-shaped hole:** `git worktree remove --force`, `git branch -D`, `git reset --hard` all bypass it — the doctrine's own card close-out step can destroy uncommitted work while the README claims nothing can delete.
- **`INVALID_CARD` is used asymmetrically** — freely and productively in the `docs/plan/` lane (Sol), missing as a documented exit in the `cards/` BREAK lane, where `SC-BLD-R03` oscillated across 5 review rounds to a terminal double-REMEDIATE instead of being invalidated early.
- **Active policy is stale vs. what's actually running:** `docs/process-adoption.json` pins commits that don't match the audited HEADs; Receipts isn't even on canonical `main` — it's branch-only.

## Where it's genuinely strong (all 4 agree)

Independent review finds real, reproducible defects every round checked (fork/bare-repo identity collisions, the actor-separation daemon bypass, false grounding claims, TOCTOU races) — this is not rubber-stamping. `INVALID_CARD` is honored rather than fought when a false premise is found. The core acceptance philosophy (worker self-report is never evidence, CONFIRM×BREAK×FIT, coder≠grader≠breaker) is sound in principle — the gap is between the philosophy and what's mechanically enforced today.

## Final prioritized recommendations (synthesized across all 4)

1. **Ship the REMEDIATE Strong Card** — 75% of all verdicts hit an unimplemented path. Currently 2-of-3 NEEDS-FIX on re-review (see `../2026-09-15-remediate-v2-rereview/`); fix those gaps first (all 4 reviewers converge: fold the contract-revision + evidence write into one transaction).
2. **Fix the background-dispatch false-settlement bug in `t03_runner.py`** before running any more parallel Builder dispatches — this is the root cause class behind lost/orphaned agent handles this session.
3. **Do not trust Receipts as a freeze gate yet.** Fix concretely proven gaps first: require resolvable receipt references and real prerequisite validation (not text pattern match), bind exit-code to pass/fail, add per-command timeout + output cap, scope container cleanup to the invoking PID/label, and make `B<n>` reverse-reachability actually replay a search rather than checking line-existence. Then merge/install it — and only then consider dropping the Haiku dependency-check.
4. **Extend `sc-dispatch-sandbox-guard.sh` to cover `codex exec`/Agent dispatches, or stop calling it enforcement** — confirmed non-functional against the route actually used all session by two independent live tests.
5. **Fix the template/parser mismatch.** All 11 real session cards fail Builder's own `parse_strong_card()`. Either fix the template to match the parser's expected format, or fix the parser — but stop authoring cards that can't be ingested by the system meant to run them. Demote the mandatory Construction-packet (PB0–PB10) section to opt-in for ≥5-file/security-boundary cards; every shipped card ignored it.
6. **Controller-stamped dispatch envelopes** — 3 recorded cases of reviewer model identity being wrong/faked; the controller, not the model, must supply dispatch metadata.
7. **Make actor separation an actual boundary, not string comparison** — daemon must authenticate the peer; the ledger accepts a fabricated distinct actor name today.
8. **Write `INVALID_CARD` into `JUDGE-PROTOCOL.md` for the BREAK lane** with a rule that 2 consecutive non-converging rounds = INVALID_CARD.
9. **Make review risk-tiered, not uniform.** One independent breaker by default; require two only for auth/isolation/concurrency/deletion/migration/irreversible-state work — that's the only place mixed-model review paid off this session.
10. **Wire dispatch token/cost into the existing global Langfuse** and **persist review verdicts mechanically** (`tee` to `docs/reviews/<card-id>/`) — right now every verdict in this very audit exists only because it was manually saved after the fact.
11. Trim `RULES.md` below ~8,000 words / 1,200 lines; move incident narratives to retrospectives.

Full reports in this directory.
