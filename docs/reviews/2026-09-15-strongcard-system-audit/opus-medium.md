# Opus medium — Strong Card system audit (addendum after card-history sweep)

The card-history sweep returned and it materially sharpens the audit — including two findings that outrank parts of the initial report. This file is the addendum as delivered (the initial report referenced by "§" numbers below was not separately retained verbatim in this session's context — only this addendum's full text was).

## New finding that rivals the lead: the system's most common verdict is a code path that does not exist

Across all 28 review/verdict JSONs under `cards/`: **21 `REMEDIATE`, 7 `PASS`.** REMEDIATE is 75% of outcomes — the normal case, not the exception.

Now read `phase3-remediate-strong-card-CARD.md`: `T08Lifecycle.run_phase` **raises `T08UnsupportedCardKind` for `CardKind.STRONG_CARD` on REMEDIATE** (`t08_lifecycle.py:355`). Any Strong Card whose adversarial reviewer does its job is permanently stuck and can never reach FREEZE. That card is frozen at **v1, never reviewed, never coded** — no `tests/runtime/test_t08_lifecycle_strong_card_remediate.py` exists.

So the runtime implements the 25% path and not the 75% path, and the card to fix it is itself sitting unshipped. This is the same disease as the lead finding — **built-and-parked** — but one layer deeper: it means the automated lifecycle cannot be the thing executing cards, and every REMEDIATE this session was resolved by a human-driven controller loop instead. That is where Joe's hours actually went, and no amount of review tuning touches it.

That card's own reasoning is the best work seen in this repo, incidentally: it argues that *unblocking alone would be worse than the current failure*, because `_break` short-circuits on stored evidence (`t08_lifecycle.py:321`) under `UNIQUE(card_id, phase)` — a remediated card returning to BREAK_A would find the **old** card's evidence row, skip dispatching a reviewer, and walk to FREEZE carrying a verdict rendered against a card that no longer exists. A false green. Hence the paired `card_revision` dimension. **Ship this card next.** It is correct, it is fenced, and it unblocks three-quarters of all outcomes.

(Status as of this audit: this is the REMEDIATE v2 card now in re-review — see `docs/reviews/2026-09-15-remediate-v2-rereview/` in the t12-consolidated worktree. 2 of 3 re-reviewers returned NEEDS-FIX.)

## Second new finding: reviewer identity is not provable — three recorded substitutions

`cards/SC-BLD-R03/reviews/r1-terra/review-original.json` records `"model": "gpt-6-astra"` against `"requested_profile": "Terra/medium"`, patched after the fact by a `metadata-correction.json`. The same pattern appears in `r2-luna/` and `SC-BLD-R01/reviews/r1-luna/` — **three occurrences.**

This is worse than same-vendor review: **you cannot prove which model reviewed at all.** A review filed under `r1-terra` was produced by astra. If reviewer independence is the load-bearing claim of the whole acceptance model — and it is, it is Principle 5 — then an unverifiable reviewer identity invalidates the evidence, not just weakens it. `docs/STRONG-CARD-IMPROVEMENTS.md` SCI-005 already names the cause (Luna self-reported effort `low` on an accepted `high` dispatch; Terra truncated a baseline commit by one character; Luna transposed two groups of a pinned SHA-256 while claiming every immutable input matched) and prescribes the fix: **the controller, not the model, supplies dispatch metadata.** It is one of the five adopted proposals. It is evidently not yet enforced. Make the controller stamp the envelope and refuse any review whose self-reported model disagrees.

## Third: the gates are provably defeatable, and this was already demonstrated

SCI-006: Luna built a **receipt-blind mutant that inferred delivery from phase names and passed all seven R01 r2 gates.** R03's gate accepted a receipt claiming *revision 999* for a revision-1 card. R02's gates accepted **dropping both unique ownership indexes**. A mutant attributed process-judge job 7 to a later coding job 8. And one green mutant command **rewrote 43 tracked proof logs** because logs serialized absolute paths (SCI-013).

That last one is the dangerous one: **a card's own gate run can silently mutate the retained evidence it is being judged against.** Retained proof that a gate can rewrite is not proof.

## Corrections and sharpening to the initial report

**Role structure is worse than same-vendor round 1/2.** Four distinct review roles ran this session — terra + luna as paired BREAK adversaries in `cards/`, **sol** as card reviewer for `docs/plan/strong-cards/`, **astra** as judge (`judgments/astra-r1`, `astra-r2`). All four are GPT flavors through `codex exec`. So it is not merely that round 1 and round 2 share a vendor — **coder-adjacent review, adversarial BREAK, and the FIT judge are all the same vendor.** P5's "coder ≠ grader ≠ breaker" is satisfied by *name* at every position and by *independence* at none. The **judge** in particular must be off-vendor, since it is the single point that converts three correlated opinions into one verdict.

**"5-round oscillation" was generous. R03 never converged at all.** The sequence: r1 PASS/PASS → r2 luna PASS / terra REMEDIATE → r3 luna REMEDIATE / terra PASS → r4 both REMEDIATE → r5 both REMEDIATE. Five revisions, five review pairs, **ten dispatches, and the terminal state is still double-REMEDIATE.** The reviewers moved *away* from consensus as rounds accumulated. That is not a card converging under scrutiny; that is a card whose scope was wrong, and the missing `INVALID_CARD` exit is precisely what should have fired at r2 instead of buying three more rounds.

**Sol's dominant verdict is `INVALID_CARD` — which complicates the oscillation finding and partly vindicates the process.** Sol rejected v1 of at least four cards outright (builderd-lifecycle, actor-separation, repo-identity-resolver, T03). `phase2-builderd-lifecycle-CARD.md` is the heaviest: `v1→v2 (Sol, INVALID_CARD)` fixing 5 defects, `v2→v3 (Sol round 2, INVALID_CARD)`, then **v3.1 at Sol round 3.** So the `docs/plan/` lane *does* use INVALID_CARD freely and productively; it is the `cards/` lane (terra/luna/astra) that lacks the exit and oscillates. **Codify the asymmetry:** the `INVALID_CARD` verdict exists in practice and needs to be written into `JUDGE-PROTOCOL.md` so the BREAK lane can use it too.

**Cost analysis needs an honesty correction.** `docs/STRONG-CARD-IMPROVEMENTS.md` states twice that **no provider token or cost telemetry is retained anywhere** — "Comparative efficiency claims remain unproven until tracing supplies matched measurements." It also retracts its own earlier "150k-token context" theory as unproven. So no auditor can put a dollar figure on this system without fabricating it. The only grounded numbers are counts and wall-clock, and the project's own is the sharpest available: **SC-BLD-R01 changed three production files at a cost of three card revisions, six review dispatches, two coding attempts and 64.9 minutes of controller wall-clock** (SCI-007). Meanwhile `SC-BLD-P01-A1` accumulated **149 files / 1.66 MB — half the entire cards tree — and still ended r1 double-REMEDIATE en route to CARD-r4.** Given Langfuse is already running globally at `~/langfuse/`, **wiring dispatch token/cost into it is a prerequisite for any future optimization claim**, including the ones in this audit.

**A real gap missed initially: cards revised without any review.** `SC-BLD-P01-B`, `-C`, `-D` each carry `CARD.md` + `CARD-r2.md` and **zero `reviews/` directories.** Something drove an r2 revision with no recorded adversarial input. Either the review happened and was not retained — a direct violation of the audit-trace rule — or an r2 was cut on unreviewed judgment. Both are worth knowing which. Similarly `SC-BLD-P01-A2` and `-E` hold a `design-packet-r1.json` each and were never drafted into cards at all.

**Lead finding confirmed as a systemic pattern, not a one-off.** `STRONG-CARD-IMPROVEMENTS.md` carries 13 proposals (SCI-001…013), every one derived from a real escape with linked `cards/` evidence. Owner-authorized on 2026-09-08: **SCI-003, 005, 006, 007, 009 — five of thirteen.** Eight remain unadopted, including SCI-013 (gate runs rewriting retained evidence) and SCI-010 (a fetch packet truncated its Astra schema excerpt at line 333 while mandatory definitions ran to line 468, letting **five contract-widening mutations** through with six unmapped parent obligations). So: 13 proposals → 5 adopted; Receipts → built, green, unmerged; REMEDIATE card → frozen, unshipped. **The bottleneck is uniformly the adoption step, across three independent mechanisms.**

**One place the doctrine already diagnosed itself correctly:** SCI-009 — *"a synthesizer should not receive an accumulating repository history as one large context"*; the drafter should pull bounded facts through cheap read-only fetchers behind a deterministic reducer. Arrived at independently via a recommendation to make the Haiku dependency-check mandatory and have it emit Receipts blocks directly. It is one of the five adopted proposals and is consolidated into `docs/CONSTRUCTION-PROTOCOL.md`. Convergence between an outside auditor and the project's own retrospective is the strongest signal available that this is the right next move.

## Revised priority order

1. **Ship `phase3-remediate-strong-card-CARD.md`.** 75% of verdicts hit an unimplemented path. Nothing else matters as much.
2. **Merge and install `sc-receipts.sh`.**
3. **Controller-stamped dispatch envelopes** — three recorded model substitutions mean reviewer identity is currently unprovable, which undermines the acceptance model at its root.
4. **Wire dispatch token/cost into the existing global Langfuse** — no optimization claim, including this one, is checkable without it.
5. **Write `INVALID_CARD` into `JUDGE-PROTOCOL.md`** and give the BREAK lane the exit the plan lane already uses; add a hard rule that **two consecutive rounds without convergence = INVALID_CARD**, which would have stopped R03 at r3 and saved four dispatches.
6. Reviewer vendor-diversity, with the **judge** off-vendor first; cut round 1 to a single reviewer.
7. Shrink RULES.md below 1,200 lines; fix the delete-guard tokenizer.

**Addendum (e): a gate run can rewrite the evidence it is judged against.** SCI-013 — a green mutant command rewrote 43 tracked proof logs across fresh worktrees because logs serialized absolute paths. Unadopted. Retained proof that the gate can mutate is not proof, and this is the failure mode least likely to announce itself.
