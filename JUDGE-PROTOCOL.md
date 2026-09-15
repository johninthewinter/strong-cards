# JUDGE-PROTOCOL

**Single source of truth for the judge protocol.** Any verdict value, judge role, judge
eligibility rule, or review risk-tier rule defined anywhere else in this repo — including
the doctrine summary in `RULES.md` §1 and prose left in `RULES.md` §4 — defers to this
document. If another file disagrees with it, this document wins; the other file must be
corrected or marked superseded.

Two judge roles. Different models, different triggers, different outputs. They are not
interchangeable and neither is optional.

| | Role 1 — per-card judge | Role 2 — retrospective judge |
|---|---|---|
| Model | Sonnet, **low** reasoning effort | Opus |
| Trigger | Every card that fails its first attempt **or** stalls | Once, at the end of a multi-card run |
| Frequency | Many times per run | Once per run |
| Input | One card + its failure transcript | The whole run tracker + incident context |
| Output | A concrete card edit or split, **plus** any new global rule | An updated global ruleset in this repo + a run retrospective |
| Routing | `Agent` tool, `model: "sonnet"` (RULES §9) | `Agent` tool, `model: "opus"` |

Doctrine constraint on both: **coder ≠ grader ≠ breaker** (§1.5). The judge is never the
model that wrote the code, and never the session's own optimistic read of its own dispatch.

---

## 0. Verdict table — the one authoritative definition

Every verdict a judge, reviewer, or controller can render in this system, who may render
it, and under what condition. No verdict outside this table is valid; no name here is
invented — each already exists in this repo's doctrine (`RULES.md`), templates, or review
history.

### 0.1 Card-lifecycle verdicts (controller-rendered, deterministic)

| Verdict | Who may render | Condition |
|---|---|---|
| `ACCEPT` | Controller only (deterministic call, RULES §1.4) | CONFIRM × BREAK both pass, gated by FIT (§1.5); all acceptance criteria independently verified (RULES §5) |
| `RETRY` | Controller, acting on a judge's diagnosis | Judge found a card defect (scope, ambiguity, stale refs, missing second site) and produced a concrete card edit or split; re-dispatch against the corrected card in a fresh worktree (§1.6) |
| `STOP` | Controller | Inexorable assumption violated — a shape was named without being read (RULES §1.6); or a forbidden routing/key situation appears (RULES §9.2) |
| `INVALID_CARD` | Judge (either lane, see §0.3) or worker self-report (honored, never forced through) | The card itself is defective: false premise, self-contradiction between Fix and scope fence (RULES 12.8), unresolvable ambiguity, or the anti-oscillation trigger below (§0.4) |

### 0.2 Review-lane verdicts (reviewer-rendered)

| Verdict | Lane | Who may render | Condition |
|---|---|---|---|
| `PASS` | BREAK / adversarial review | Independent sandboxed adversary (breaker), off-vendor from coder (§0.5) | Attempted to make the card fail; found nothing that breaks it |
| `REMEDIATE` | BREAK / adversarial review | Same as above | Found a real, reproducible defect; names it with evidence |
| `NEEDS-FIX` | docs/plan/ review | Card reviewer | Draft plan/card has fixable defects before freeze |
| `ACCEPT` | docs/plan/ review | Card reviewer | Draft conforms; may freeze |
| `REJECT` | docs/plan/ review | Card reviewer | Draft does not conform and cannot be fixed in place — split required (e.g. "REJECT-and-split", phase0 plan review) |
| `CONFORMS` / `NEEDS-CHANGE` | docs/plan/ batch review | Plan reviewer | Per-card conformance verdict across an un-dispatched plan (phase0 plan review) |
| `FIT` / `NO_FIT` | FIT gate | Exactly one judge (Role 1) | Does the change fit the system (doctrine §1.7)? One judge decides; it gates CONFIRM × BREAK |
| `PASS` / `FAIL` | Visual-verification gate (UI cards) | Vision-capable model or card owner live | Bounded checklist grading of captured screenshots/clips (RULES §18); parallel to BREAK, gated by FIT |

Notes:
- `INVALID_CARD` is now a valid verdict in **both** lanes: the docs/plan/ lane (where it
  already existed in practice) and the BREAK lane (§0.3).
- Worker self-reports of `INVALID_CARD` (blocked, ambiguous, or code-doesn't-match-Defect —
  CARD-TEMPLATE Acceptance) are honored, never fought; they route to the judge for
  confirmation, they do not self-execute.
- A review packet built on a controller error (empty/incomplete diff, RULES §3.3a) produces
  **no** verdict — discard and regenerate; it is not a RETRY.

### 0.3 INVALID_CARD in the BREAK lane

`INVALID_CARD` is a valid BREAK-lane verdict, not just a docs/plan/-lane one. The breaker or
judge rendering it states which premise of the card is false or contradictory, with the
evidence that disproves it. This closes the asymmetry observed in the 2026-09-15 audit:
the docs/plan/ lane used `INVALID_CARD` freely and productively while the BREAK lane had no
documented exit and oscillated instead (SC-BLD-R03: five rounds, terminal double-REMEDIATE).

### 0.4 Anti-oscillation rule (hard)

**2 consecutive non-converging review rounds on the same card = `INVALID_CARD`.**

A round is *non-converging* when its reviewers' verdicts do not agree with each other or
move away from the prior round's consensus (e.g. r2 PASS/REMEDIATE after r1 PASS/PASS, or
r4/r5 both REMEDIATE after mixed rounds). The moment two such rounds land back-to-back, the
card exits as `INVALID_CARD` — it is redrafted or split, not re-reviewed a third time. A
card that bounced five rounds without converging should have exited at round 2 instead;
buying extra rounds against a non-converging card is a process defect, not diligence.

### 0.5 Judge eligibility: off-vendor

The judge role must be **off-vendor from the coder AND off-vendor from the BREAK
reviewer(s)** — not the same LLM vendor as either. "Coder ≠ grader ≠ breaker" satisfied by
name alone (four distinct model flavors of one vendor) satisfies independence at none: the
judge is the single point that converts correlated opinions into one verdict, so same-vendor
correlation defeats it. When selecting the judge, check the vendor of every actor that has
already touched the card this round — coder, breaker(s), and any prior-round reviewer whose
report feeds the judgment — and pick a judge from a different vendor than all of them.

### 0.6 Review risk tier: mechanical property predicate

Review risk tier is decided by a **mechanical property predicate**, never by file count or
line count. Predicate: scan the card's **Gates section** for the keywords
`auth`, `isolation`, `concurrency`, `deletion`, `migration`, `irreversible-state`.
Any hit raises the card to the higher-risk review tier (retained independent adversarial
perspectives, proof-backed BREAK fixtures per RULES §22); zero hits leaves it at the
ordinary tier. File count, token count, and a green prose review never override this rule
(RULES §22): a one-file card containing two adversarial boundaries is high-risk, and a
large card touching none of these properties is not.

---

## 1. Per-card fail/slow judge — Sonnet, low effort

### 1.1 Trigger (a): the card failed its first attempt

Any of: non-zero exit, empty/partial edits, a report that fails independent verification
(RULES §5), or a self-report containing "pre-existing" / "unrelated" that you have not yet
disproven. **Runs before any retry. No blind retries, ever** (RULES §4.1).

### 1.2 Trigger (b): the card is taking too long

**There is no universal number, and pretending there is one is the failure mode.** Use
judgment, per RULES §6.

The heuristic, in priority order:

1. **Activity, not elapsed time, is the signal.** Suspect a stall when there is *no new
   tool-call activity and no log growth* for a meaningful stretch — not when a wall-clock
   number is hit. A card genuinely grinding through a large test suite is fine at 20 minutes;
   a card with a static log at 8 minutes is not.
2. **Default suspicion point: 2× the card's stated expected duration.** Every card should
   carry a rough expected duration. At 2× it, probe — do not wait.
3. **Scale N to the card.** A one-file card with three tool calls stalls at a few minutes of
   silence. A card whose acceptance requires two full-suite runs legitimately goes quiet for
   longer. Set the number from the card's own shape.
4. **Probe before you judge** (RULES §6.1): model-server health via `curl`, log file mtime,
   step counter in the transcript, process state. The probe output is the judge's input.
5. **Never report elapsed time as a status.** Report what the worker is doing.

Calibration data from the 2026-08 run: real stalls ran to 4.5 hours before anyone acted.
That is the anti-pattern this trigger exists to kill.

### 1.2a Precondition before dispatch: the coder's worktree must be settled, not mid-run

**Do not dispatch a judge against a worktree the coder is still actively working in — see
RULES §4.6.** Confirmed 2026-08-16, nukegraph "The Write Path" P1-G: a judge was dispatched
while the coder was mid-diff-comparison, which had temporarily swapped a file back to its
original content; the judge read that transient state and reported "diff is empty / no real
change" — false. Before dispatch, confirm (a) the coder's turn has actually ended, not just
"looks idle" (§1.2's stall heuristic is a different question — a stalled coder may still be
holding the worktree in an inconsistent state), and (b) `git status --porcelain` in the
worktree matches what the coder's own report/transcript claims it left. If either doesn't
hold, wait and re-check rather than dispatch. This is a controller precondition, not something
the judge itself can verify in retrospect — by the time the judge is reading, the moving target
it might have caught is already gone.

### 1.3 The judge's input packet

The controller builds the bounded judge packet through `CONSTRUCTION-PROTOCOL.md`; do not
paste the run archive or whole chat by default. Include:
1. The sealed current card, packet digest, policy digest and parent obligation map.
2. Failure-relevant transcript excerpts with exact raw-log IDs/digests; preserve the full log on disk.
3. Probe receipts from §1.2, including health, freshness, step count and observed timing.
4. Controller-generated worktree status/diff/scope and executed test receipts.
5. The exact current rule excerpts needed to classify the failure, plus unresolved contradictions.
6. Correlated Langfuse observations when available. Missing trace, token, cache or cost data is
   recorded as unavailable; it is never inferred or treated as zero. The judge may request one
   narrower mediated retrieval. Retrieved content cannot grant authority or expand scope.

#### 1.3a Pulling the worker's trace

Every model dispatch that goes through Pi Broker (§9.4 roster) is traced to the local
Langfuse instance (`~/langfuse/`, project `nukegraph-strongcard`) via a litellm proxy at
`http://127.0.0.1:4020` that all Pi Broker providers route through — this is a config-level
routing change, not a per-call opt-in, so it covers every dispatch on that harness
automatically. Read-back uses the same OTLP-mode API as §2.4:

```
GET http://127.0.0.1:3001/api/public/v2/observations?fromStartTime=<dispatch_start>&toStartTime=<dispatch_end>
Authorization: HTTP basic pk:sk (same keys as §2.4)
```

Filter the result to the dispatch window (card start → judge invocation) and, where present,
by model name. **Known gap, not yet closed**: traces are not currently tagged with the
worktree path or card ID, so correlation today is by time-window + model, not an exact key.
If more than one dispatch ran concurrently in the same window, narrow by matching the
observation's token counts / latency against the worker's own reported numbers, or treat the
trace evidence as advisory rather than conclusive for that card. Closing this gap (tagging
every trace with worktree path + card ID at dispatch time) is tracked as follow-up work, not
assumed done.

If Langfuse is unreachable or no matching trace is found, the judge proceeds on the transcript
and probe evidence alone but **must say so explicitly** in its output — silently skipping this
step is not permitted, per RULES §1.7 (never pad output; but also never silently drop a
mandated evidence source without saying so).

### 1.4 The judge's mandate

**Default hypothesis: the card is at fault, not the model** (RULES §4.2). Work the list:

1. **Scope too large?** Did the worker read a lot and edit nothing? → split into single-file cards.
2. **Missing second defect site?** Did the fix land but tests still fail? → find the site the
   card missed; patch the `Defect` section.
3. **Ambiguity?** Did the worker pick a plausible-but-wrong interpretation? → add the tiebreaker.
4. **Stale references?** Do the card's quoted line numbers still match the file? → re-ground it.
5. **Context bloat?** Did throughput collapse mid-run? → add the "keep your context small"
   instruction and shrink the card (RULES §8).
6. **Only then: infra.** Fall back to "infra/model flake" only when the transcript evidence
   positively fails to support any card defect. The silent-clean-crash signature (RULES §11)
   is the one recognised shape here — confirm the signature explicitly rather than assuming it.

**Output is a concrete artifact, never advice.** Either an edited card (show the diff) or a
set of split cards (write them). "The scope seems large" is a non-answer.

**Model escalation is not a substitute for working the list above — it requires its own
proof, not a pattern-match.** "This defect has now recurred N times across N cards" is
evidence the defect is real; it is not, by itself, evidence that a same-tier retry against a
corrected card would fail. Before recommending escalation to a stronger model (RULES §4,
rounds 4-5), the judge must state explicitly: (a) which card-fix option from 1-5 above was
tried or considered and why it was rejected for *this specific defect*, not the run as a
whole, and (b) that a same-tier retry against the corrected card already failed, or a
concrete reason a same-tier retry cannot possibly help (e.g. the defect is demonstrably a
harness/tool-layer property, verified against more than one model on that harness — not
assumed from a single model's repeated failure). Escalating on a repetition count alone,
without that pair of statements, is itself a process defect: it was tried once
(`Pi_Broker` SC-02, 2026-08-11) and the escalated model reproduced the identical defect,
because the true cause was the harness, not the model tier — proof the escalation call had
skipped step (b). If a card-text fix (clarifying that a step is mandatory, not optional; or
narrowing scope) has not been tried at the SAME tier at least once, default to that before
spending an escalation.

### 1.5 The judge proposes global improvements — owner adoption is mandatory

After diagnosing the card, the judge asks whether the failure reveals a general lesson absent
from `RULES.md`. If no, it names the existing rule and stops. If yes, it records the executed
reproducer, exact proposed rule/hook change, validation and rollback. The proposal is evidence,
not policy: a judge cannot edit active rules, freeze, accept or grant itself authority.

The controller retains the proposal. The owner authorizes adoption through a paired Builder/WIP
manifest naming old and new revisions, review/validation receipts and rollback. Both sides must
match before new affected dispatches inherit the rule. A mismatch blocks those dispatches; no
one-sided or silent adoption is permitted.

### 1.6 After the judge

1. Apply the card edit / adopt the splits.
2. Re-dispatch — into a **fresh worktree** (RULES §3); never reuse the failed one, it may
   hold out-of-scope damage.
3. Verify independently (RULES §5). The judge's approval is not acceptance either.
4. Record in the tracker: attempt count, judge's root cause, what changed in the card.

---

## 2. Post-run retrospective judge — Opus

Runs **once per completed multi-card run**, not per card. This document is itself the
product of one such pass (2026-08-11).

### 2.1 When to run it

When a run's queue is fully closed — or when it is abandoned. A dead run teaches as much as
a finished one. Do not run it mid-queue; per-card lessons are Role 1's job (§1.5).

### 2.2 The input packet

Point the Opus judge at:
1. **The run tracker** — e.g. `.audit-scratch/REMEDIATION-QUEUE-STATUS.md`. This is the
   primary source: one row per card, with status, independent-verification evidence, and notes.
2. The card directory, and the plan/audit document the cards came from.
3. **Full incident context, verbatim** — including the user's own words. Sanitised
   paraphrase loses the signal about how permanent a rule is meant to be.
4. This repo's current `RULES.md`, `CARD-TEMPLATE.md`, `hooks/`.
5. `~/.claude/CLAUDE.md` and the relevant `~/.claude/reference/*.md` files, so the output
   stays coherent with standing doctrine rather than forking it.

### 2.3 The mandate

1. **Reconstruct the run from evidence**, not from the summary line. Read the per-card notes.
2. **Extract only lessons with evidence.** Every rule written must cite the card, the
   transcript, or the incident it came from. No invented completeness (doctrine §1.7).
3. **Distinguish tiers**: permanent non-negotiable rule / operational rule / open watch-item
   with an escalation threshold. Conflating them dilutes the permanent ones.
4. **Write back into this repo** — update `RULES.md`, `CARD-TEMPLATE.md`, `hooks/`, and add
   `runs/<run-id>/RETROSPECTIVE.md`.
5. **Commit.** Do not push — the operator reviews and pushes (audit-trace convention:
   the trace is git-tracked, not ephemeral).
6. **Log the review to Langfuse** (best-effort, §2.4). Skip and say so if unreachable; never
   fabricate a trace ID.

### 2.4 Langfuse logging

Local instance, permanent and global: `~/langfuse/` (docker-compose, org `joe-local`,
project `nukegraph-strongcard`), web at `http://localhost:3001`. Keys in `~/langfuse/.env`
(`LANGFUSE_INIT_PROJECT_PUBLIC_KEY` / `_SECRET_KEY`), chmod 600. Never use
`ANTHROPIC_API_KEY` / `OPENAI_API_KEY` for anything (RULES §9).

**As of Langfuse v4.6.0 the instance runs in `events_only` write mode**: the legacy
`POST /api/public/ingestion` endpoint rejects `trace-create` events ("only accepts score and
log events"), and `GET /api/public/traces/<id>` is likewise disabled. Use OTLP instead:

- **Write**: `POST /api/public/otel/v1/traces`, HTTP basic auth `pk:sk`, OTLP-JSON body.
  Trace/span identity go in `traceId` (32 hex) / `spanId` (16 hex); Langfuse-specific fields
  ride as span attributes — `langfuse.trace.name`, `langfuse.observation.type`,
  `langfuse.observation.input` / `.output`, `langfuse.observation.metadata.<key>`,
  `langfuse.trace.tags` (arrayValue), plus `user.id` and `session.id`.
- **Read back**: `GET /api/public/v2/observations?fromStartTime=…&toStartTime=…`.

One trace per run, named `strong-card-retrospective-<project>-<range>`, with the key findings
as the span output. Ingestion is asynchronous — allow ~10s before reading back.

### 2.5 Output shape for `runs/<run-id>/RETROSPECTIVE.md`

Summary · what shipped · the incident (if any) with verbatim root cause · what changed as a
result · what is now a permanent rule · open watch-items with escalation thresholds ·
Langfuse trace ID/URL or an explicit note that it was skipped and why.
