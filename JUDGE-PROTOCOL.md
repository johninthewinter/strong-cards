# JUDGE-PROTOCOL

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

### 1.3 The judge's input packet

Give the Sonnet judge, verbatim:
1. The full card file.
2. The full failure or stall transcript (the tail at minimum; the whole log preferred).
3. The probe evidence from §1.2 (server health, log freshness, step count).
4. Any independent verification already performed — `git diff --stat` of the worktree,
   `git status --porcelain`, test output you ran yourself.
5. `RULES.md` (this repo) — so it can recognise a new general lesson.

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

### 1.5 The judge ALSO updates the global rules — mandatory

This is the part that makes the run compound instead of repeating itself.

After diagnosing the one card, the judge answers one more question:

> **Does this failure reveal a general lesson not already in `RULES.md`?**

- **No** → say so explicitly ("covered by RULES §8.1"), and stop. Do not pad the ruleset.
  Doctrine §1.7: never add to look thorough.
- **Yes** → write it. Either:
  - a new/amended numbered rule in `RULES.md`, with its **Why** grounded in *this* failure
    (quote the transcript), and a **How to apply**; and/or
  - a change to `hooks/` in this repo, if the lesson can be made structural rather than
    remembered.

Rules added this way get committed to this repo, and the run tracker's header records the
adoption date (RULES §10.3) so the *current* run inherits it immediately, not just future ones.

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
