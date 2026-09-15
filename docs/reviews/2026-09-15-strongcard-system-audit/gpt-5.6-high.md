# GPT-5.6 high — Strong Card system audit

model=gpt-5.6-sol effort=high timeout=1800s cwd=/tmp/audit-scw (paired with /tmp/audit-builder, dedicated detached-HEAD worktrees off strong-cards_wip@f2f5fa8 and The_Builder t12-consolidated@da2c9f2)

**Decision to take now:** treat independent review as the working safety system; do not treat card construction, Receipts, or freeze as mechanically trustworthy yet.

Central finding: **reviewers repeatedly saved the system from defects that the Strong Card compiler was supposed to eliminate before dispatch.** Quality is real, but it is currently purchased through expensive downstream rediscovery.

## 1. What genuinely worked

| Mechanism | Evidence | Verdict |
|---|---|---|
| Independent BREAK/review | Repo identity reached v3 only after reviewers found fork collapse, bare-repo collisions, remote normalization errors, unstable `--all`, ignored non-`origin` remotes, permission-error misclassification. `phase2a-repo-identity-resolver-CARD.md:13` | Strong and substantive, not ceremonial. |
| Multiple independent perspectives | Actor separation passed one review, then another found the live daemon bypass. Commit `57975c7` added distinct settlement events and daemon-path regression tests after `abf1d97`. | Essential for security-sensitive cards; one reviewer was demonstrably insufficient. |
| Honesty around INVALID_CARD | Amended T03 card admits `b828809` added optional capability but never wired the real T08 caller, so production recorded zero rows. `t03-live-dispatch-ledger-wiring-amended-CARD.md:5` | Excellent failure semantics. |
| Dependency check | Found the existing `builder` CLI entry point, command-name collision, incompatible DB-addressing assumptions before implementation. `phase2-builder-cli-CARD.md:22` | Real value — but should be deterministic, not an LLM job. |
| Core doctrine | "Worker self-report is never acceptance evidence," whole-tree thinking, CONFIRM×BREAK×FIT, explicit INVALID_CARD. `RULES.md:22` | Keep — explains why bad changes did not survive. |

Qualification: the repo proves the dependency check *happened*, not that Haiku specifically performed it — attribution depends on session memory, not tracked evidence.

## 2. Where it actually failed this session

1. **Grounding failed before implementation.** `b828809` tested `bootstrap_run()` by injecting a `T12PlanStore` directly; never proved the real lifecycle supplied one. The repair (`4c458d4`) touched nine files plus a new end-to-end test — exactly the failure Receipts was built mid-session to prevent.
2. **Actor separation is process discipline, not a security boundary.** Mechanism is caller-supplied string inequality: `finish_dispatch_attempt` (`t12_plan_store.py:454`) accepts any different `finishing_actor` string; the card itself concedes the same process can fabricate another name (`phase2-actor-separation-CARD.md:89`); the daemon accepts JSON `finish_attempt` requests without authenticating the peer (`builderd/server.py:97`). Unix-socket filesystem permission ≠ identity binding.
3. **Review evidence for this session is not durable enough to audit from the repos alone.** RULES §10.2 (`RULES.md:1664`) requires raw envelopes/prompts/synthesis/digests tracked under `docs/reviews/`, or "the judgment did not happen." For repo-identity, T03, actor-separation, and REMEDIATE, narrative review history exists inside cards/commits but not matching run-specific raw artifacts. The REMEDIATE 1-of-3 result is session testimony, not independently reconstructible from these checkouts.
4. **Active policy is stale and partly aspirational.** `docs/process-adoption.json` pins Builder `07e885e`/WIP `8f38901`; audited heads are `da2c9f2`/`f2f5fa8`. No runtime admission path enforces the pin matches execution. Receipts is further removed: canonical `main` HEAD (`f2f5fa8`) has no `hooks/sc-receipts.sh` at all — it lives only on branch `sc/receipts-gate` (`81843f1`). Candidate control, not active.
5. **Cards actually used were lighter than the doctrine claims.** CARD-TEMPLATE demands PB0–PB10, receipts, provisioning, ledgers. Several Phase 2 cards are compact prose without the full construction packet. The practical system was "write a plausible card, review repeatedly, amend until acceptable" — not the deterministic compiler the doctrine describes.

## 3. Receipts: correct diagnosis, overbuilt/undertrusted implementation

Correct product insight, wrong trust architecture. 1,017 new lines across 5 commits (`07cb57d` de-eval → `7d99bf0` block more exec/write paths → `9937c58` move replay into Docker → `81843f1` drop caps/no-new-privs/read-only rootfs) — a real security subsystem built just to verify Markdown-authored claims are true. Remaining gaps: only `R<n>` receipts are actually replayed — `B<n>` reverse-reachability receipts (the exact mechanism meant to catch the daemon bypass) pass on mere line-existence (`sc-receipts.sh:446-495`); nonzero exit can still "pass" if recorded substrings appear in output; forward-reachability matching is a naive backticked-identifier/file:line string hit with no symbol-binding check; no per-command timeout inside sandboxed replay; cleanup force-removes every container on the shared image, so concurrent receipt checks can kill each other (`sc-receipts.sh:221-225`); README admits there is no automated freeze wiring yet — it's a manual checklist. **Do not let it gate freeze in its current form.**

## 4. Cost read: both — but outside security-sensitive work, structurally inefficient

Reviews worked as designed — without them, fork collisions, a dead ledger integration, a daemon-auth bypass, and REMEDIATE gaps would have shipped. But the repetition rate is too consistent to be normal adversarial hardening: daemon lifecycle 4 rounds, Builder CLI 3, plan ingest 2, repo identity 3, environment scoping 2, Receipts itself 4 hardening commits. When basic entry-point/reachability/CLI-inventory discovery needs multiple flagship-model rounds, review has become the primary design-and-discovery phase — contradicting RULES' own "judgment before the loop" (`RULES.md:24`). Two independent reviewers are justified for auth/isolation/concurrency/deletion/migration/irreversible-state; not cost-effective as the unconditional default for every small slice. The mandatory Sonnet judge on every first-attempt failure also stacks another model onto findings that sometimes need no adjudication (`JUDGE-PROTOCOL.md:20`).

## 5. Prioritized recommendations

1. **Replace Markdown-command execution with controller-generated receipt artifacts.** Controller runs grounding commands before drafting, stores typed argv/exit-code/output-digest/repo-SHA/timestamp as JSON; cards reference receipt IDs by digest. Delete the Docker replay subsystem and most of its 1,017 lines — Markdown must never become executable input.
2. **Build one real `sc-freeze` gate that fails closed** unless card schema, exact repo HEAD, policy/adoption revision, receipt digests, and forward/reverse reachability all validate — then delete the equivalent manual checklist prose.
3. **Make review risk-tiered, not uniform.** One independent breaker by default; require two only for security/authority/concurrency/deletion/migration/irreversible-state, or on any finding/reviewer-disagreement/suspicious-zero-finding. Reserve the Sonnet judge for ambiguous card-vs-environment failures, not deterministic evidence with an obvious repair.
4. **Automate dependency/reachability discovery.** Replace the Haiku dependency-check for static questions (entry points, imports, registrations, callers, RPC strings, schema consumers, tests) with a deterministic preflight, plus a hard rule requiring one test that enters through the named production entry point — that single rule alone would have rejected `b828809`.
5. **Shorten the active doctrine; batch expensive validation.** Move historical incident narratives out of the 2,224-line `RULES.md` into retrospectives; keep a compact executable policy. Run focused affected-tests per card, one full suite at integration — reserve repeated full-suite runs for timing/concurrency/flake risk.

## Most dangerous unflagged issue

The T03 background dispatch path marks a process **"settled" immediately on launch, before it exits**: `"launched": "settled"` (`t03_runner.py:369`), settlement written pre-exit (`t03_runner.py:518`), process handles live only in an in-memory dict so a controller restart loses reap capability (`t03_runner.py:303`), stdout/stderr both go to `DEVNULL` (`t03_runner.py:471`). This is the exact mechanism behind the "reported running/settled, tracker shows nothing, silently stalls" incident class described this session — a false durable-state transition combined with deliberate evidence destruction, not a mere handle-tracking inconvenience. Correct lifecycle needed: `admitted → launched → running → exited → settled/quarantined`, with persistent run ID, PID/start-time identity, log paths, heartbeat, exit watcher, restart reconciliation. **Treat this as a blocking repair before the next parallel Builder dispatch.**

The global delete-guard/trash system was not present in either audited checkout (both are pre-that-work snapshots) — reduces deletion blast radius independently but does nothing for grounding, forged actors, false settlement, missing logs, or lost dispatch identities.

Files cited: `strong-cards_wip/RULES.md`, `strong-cards_wip/JUDGE-PROTOCOL.md`, `strong-cards_wip/CARD-TEMPLATE.md`, `hooks/sc-receipts.sh` on branch `sc/receipts-gate` (`81843f1`), `The_Builder/builder_runtime/t03_runner.py`, `builder_runtime/t12_plan_store.py`, `builder_runtime/builderd/server.py`, `docs/plan/strong-cards/phase2a-repo-identity-resolver-CARD.md`, `docs/plan/strong-cards/phase2-actor-separation-CARD.md`, `docs/plan/strong-cards/t03-live-dispatch-ledger-wiring-amended-CARD.md`, `docs/process-adoption.json`.
