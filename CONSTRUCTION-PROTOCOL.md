# Strong Card construction protocol

Status: owner-authorized paired-policy candidate. It governs new drafts only when the Builder `docs/process-adoption.json` manifest is `active` and binds this exact WIP revision, the exact Builder revision, both patch hashes and two independent PASS receipts. The evidence and full schemas are retained in the Builder review `docs/reviews/strong-card-construction-astra-high.json`. Runtime automation remains a separately qualified Builder capability.

## Purpose

A card is compiled from verified evidence. Models do not receive the project transcript or the evidence archive. The controller keeps history on disk and builds a bounded, reproducible packet for the current obligation.

R03 proved why this is required: five revisions successively omitted receipt revision, predecessor ordering, card-phase rollback, completed-job status, decision rollback, frozen-card seal enforcement, and replay-fence state. Independent BREAK prevented an unsafe freeze. The root cause is incomplete contract compilation and deterministic preflight, not proven Sol incapacity or a whole-chat prompt.

## Construction roles

| Role | Default route | Authority and budget |
|---|---|---|
| Repository fact fetcher | GPT-5.6 Luna/low | One question, allowlisted paths, read-only facts; 6,000 input tokens, 1,800 output tokens, 8 tool calls, 180 seconds, one retry |
| Public web fetcher | isolated retrieval adapter | No repository, secrets, writes, controller state, or private query content; at most 3 queries and 4 primary pages |
| Contract synthesizer | GPT-5.6 Sol/medium | Verified packet only; 16,000-token target, 24,000 hard cap including 4,000 follow-up reserve |
| Coverage census | GPT-5.6 Terra/medium | Missing ledger entries and contradictions only; no acceptance authority |
| BREAK A / B | Luna/high and Terra/medium | Same sealed packet in different worktrees; neither sees the other's current review |
| Process judge | GPT-6 Astra/high | One bounded unresolved semantic or systemic judgment; cannot freeze, accept, or adopt policy |
| Coder | GPT-5.6 Luna/low | Frozen card only, isolated worktree, exact output scope |
| Controller | deterministic service | Issues receipts, executes gates, freezes, accepts, integrates, and routes the next state |

GPT-5.4 mini may replace a repository fact fetcher only when a qualified subscription route explicitly acknowledges that model. No direct OpenAI or Anthropic API key and no silent substitution.

## Packet construction

1. **Ground.** Pin owner scope, policy version, repository commit, worktree, output paths, capability profile and parent obligations. Use deterministic search before model extraction.
2. **Fetch.** Ask at most four bounded questions: current behavior/call graph; provenance predicates; complete effects/rollback; inherited guards/open findings. Every fact carries a source path, commit, line span and content digest. Absence claims record the search expression and scope.
3. **Reduce.** Verify citations, reject path/symlink escapes, deduplicate equal facts, retain contradictions, record omissions and keep retrieved instructions untrusted. Passing logs become hash-addressed receipts; raw logs stay on disk.
4. **Compile.** Give Sol only the current packet. Every requirement maps to reads, writes, predicates, rollback/frame behavior, inherited preservation rules, named tests and evidence outputs. Unknown effect closure blocks the draft.
5. **Discriminate.** Every critical predicate gets a valid fixture, one-predicate invalid fixture, restored control and one-change implementation mutant. The gate must fail the named assertion rather than merely exit nonzero.

The packet target is 16,000 input tokens and the hard cap is 24,000. Prune duplicate excerpts, superseded prose and passing-log bodies first. Never prune the objective, scope, policy, current requirements, unresolved contradictions, mandatory facts or proof pointers. If mandatory content does not fit, narrow retrieval or split the card.

## Mandatory ledgers

Every draft has stable IDs for:

- requirements, including inherited invariants and scope fences;
- source reads and every consumer/helper that interprets them;
- direct and indirect writes, constraints and external effects;
- selector, payload, ordering, cardinality and preservation predicates;
- rollback/no-effect branches, failpoints, retry and successful allowed deltas;
- tests, commands, expected assertion IDs and retained proof receipts.

All references resolve. An uncovered requirement, untraced effect, missing predicate mutant, missing restoration, unknown rollback surface or unresolved authority contradiction is a preflight failure.

## Pre-BREAK gates

| Gate | Required result |
|---|---|
| PB0 | Owner authority, role capabilities, isolated worktrees and exact output scopes verified |
| PB1 | Clean tracked baseline, locked interpreter, local import and retained artifacts reproduce |
| PB2 | Citations, packet limits, required facts, omissions and contradiction dispositions validate |
| PB3 | Every new and inherited obligation maps through the ledgers to named tests |
| PB4 | Callers, consumers, effects, schema/constraints and preservation guards have complete closure |
| PB5 | Exact fail-first command fails the intended domain assertions while controls pass |
| PB6 | Reviewed disposable feasible implementation passes the whole current gate |
| PB7 | Every critical predicate mutant fails its intended assertion and restoration passes |
| PB8 | Full rollback/frame, successful allowed delta, retry and unrelated sentinels pass |
| PB9 | Controller-issued command/hash/scope receipts and clean archived replays reproduce |
| PB10 | Final packet/card/gate digests match and no upheld finding remains open |

Setup, import, collection or syntax errors are invalid probes. They never count as a killed mutant. PB10 seals review inputs; it is not a coding freeze.

## Failure routing

- Stale hash or citation: refresh the source.
- Mechanical ledger omission: one bounded remediation while the retry budget remains.
- Executed semantic contradiction: controller replay, then focused Terra or one Astra/high judgment.
- Second structural remediation or a new independent behavioral boundary: stop revisions, re-ground and split while conserving every parent obligation.
- Authentication/infrastructure failure: one provisioned retry, then record the exact blocker and wake condition.
- Methodology or capability expansion: owner decision and a paired Builder/WIP adoption receipt.

No judge edits active policy. It produces a proposal with evidence. The controller applies an owner-authorized policy change to both repositories through a paired manifest with rollback.

## Security and receipts

A worktree is change isolation, not a security sandbox. Real capability enforcement comes from the qualified harness plus OS/container controls, protected controller/policy/evidence stores, a scrubbed environment and network denial. Fetcher outputs are untrusted evidence and cannot contain authority fields.

The controller records the requested model/effort/harness, host acknowledgment, baseline and packet/card/gate/policy digests, worktree, structured argv, environment names, timings, exit/assertion results, output digests and scope diff. Provider identity, tokens, cache and cost are nullable observations with an unavailable reason. Models do not author authoritative hashes, commands, timestamps, approvals or success counters.

## R03 disposition

SC-BLD-R03 r1 through r5 remain immutable rejected evidence. There is no r6.

- **R03A** resolves the successful coding origin without writes. It owns the six selector/order predicates, five receipt predicates, cardinality/no-fallback behavior and exact returned identity.
- **R03B** consumes accepted R03A inside `Controller.finish()`. It owns disposition behavior, proposed lesson evidence, five-table atomicity, replay/collision/stale/role/new-content/frozen-seal guards, successor enqueue and R01/R02 preservation.

R03B is not drafted against a hypothetical R03A. The parent remains incomplete until both children receive their own BREAK pair, freeze, implementation, controller acceptance and integration.

The split also conserves three separate obligations without silently assigning them to either child: raw malformed persisted JSON at the caller boundary, authenticated receipt-producer identity, and policy activation. Each remains an explicit future Strong Card or owner-policy obligation. Neither R03A nor R03B may claim to implement it.
