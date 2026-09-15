# Synthesized remediation plan — Strong Card system

**Date:** 2026-09-15
**Inputs:** the 4-model audit in this directory (`fable5.1-high.md`, `opus-medium.md`, `gpt-6-astra-xhigh.md`, `gpt-5.6-high.md`) plus two independent refactor-plan dispatches (Fable 5.1 medium, GPT-6 Astra high) that ran against it.
**Method:** every load-bearing claim below was re-verified against live code before being carried into a card. Where verification changed the finding, the finding is corrected here rather than inherited.
**Out of scope:** `docs/plan/strong-cards/phase3-remediate-strong-card-CARD.md` (now at **v4**, third round of independent NEEDS-FIX reviews, still in flight). It is orthogonal to every card below and is not re-planned, re-scoped, or touched.

---

## 0. What verification changed

Four things moved before any card was written.

| Audit claim | Verified result |
|---|---|
| Receipts lives only on `sc/receipts-gate`, unmerged, uninstalled | **Confirmed.** 5 commits ahead of `main`; `git ls-tree main hooks/` has no receipts file; absent from `~/.claude/hooks/` (24 entries). 545 lines. `hooks/README.md` itself calls it "manual (not a Claude Code hook)" and names the "enforced wiring" as a reviewer checkbox. |
| 3 reviewer-model-identity substitutions | **Refuted** (see §1d). At most 1 ambiguous case, disclosed in-commit. |
| 11/11 cards fail `parse_strong_card()` | **Confirmed, and worse.** Exact causes now known (see SC-04). |
| `process-adoption.json` is stale | **Confirmed firsthand.** Pins Builder `07e885e` / WIP `8f38901`; live HEADs are `9a16678` / `7578be5`. No runtime path checks the pin. |

Three findings surfaced during verification that **no auditor raised**, and they are folded in:

1. **`sc-delete-guard.sh` is not in the canonical repo at all.** It exists only at `~/.claude/hooks/` (243 lines). `git ls-tree -r main` has no match. The doctrine's flagship safety artifact is untracked, unversioned, and unreviewable. → SC-09.
2. **The sandbox guard fails open.** `command -v jq || exit 0` — with no `jq` on PATH, every dispatch passes unchecked. A guard whose absent dependency silently disables it is not a guard. → SC-03.
3. **A review withdrew a defect and flipped a probe exit code.** `cards/SC-BLD-P01/SC-BLD-P01-A1/reviews/r1-terra/review-corrected.json` supersedes `review.json`, withdraws finding `BRK-A1-002`, and changes a probe exit from `1` to `0` — with the reviewer block byte-identical. This is a *content* correction to adversarial evidence, not metadata, and it is a sharper integrity question than the metadata-correction thread the audit chased. → SC-06 gate.

---

## 1. Resolution of the four disputed points

### (a) Receipts: patch or replace? — **REPLACE.**

Fable 5.1 medium proposed five concrete fixes (content-anchor matching, real `B<n>` replay, exit-code binding, replay timeout, PID/label-scoped cleanup). All five are correctly diagnosed; I verified every one against `hooks/sc-receipts.sh` on `sc/receipts-gate@81843f1`:

- Drift check is `grep -qF -- "$loc" "$CARD_ABS"` at `:481` on a literal `file:line` — confirmed.
- `sandbox_cleanup()` at `:222-226` filters on `ancestor=$SANDBOX_IMAGE` with no label; `docker run` at `:204` sets none — confirmed, concurrent runs kill each other.
- No `timeout`, no `--cpus`, no byte cap; replay at `:418` is unbounded in time and bytes — confirmed.
- Replay feed at `:450` filters `$2 ~ /^R[0-9]+$/`, with an in-file comment conceding only `R<n>` is replayed; `B<n>` enforcement at `:494` is `grep -qE '^B[0-9]+[ \t]*\|'` — mere existence — confirmed.
- `RC=$?` at `:419` is captured and only interpolated into a message string at `:443`; pass/fail keys on substring presence — confirmed.

So Fable's patch list is accurate. I still recommend against it, for three reasons.

**1. Four of the five fixes are deleted rather than fixed by the replacement.** The drift check, the container cleanup, the replay timeout and the exit-code binding all exist *because a model-authored Markdown string is being re-executed to see whether it was true*. If the controller runs the probe itself before drafting and stores typed `argv` + exit code + output digest + repo SHA as JSON, there is nothing to replay: the receipt is true by construction, not by re-execution. You do not harden a replay engine you are about to remove. Only the `B<n>` reverse-reachability gap survives the transition, and it survives in easier form — "the controller must actually run the reverse search" is a few lines in the controller, not a sandbox feature.

**2. The usual economics of patch-over-replace do not apply, because there is no installed base.** Patching normally wins when the subsystem is in production and migration is the dominant cost. Here: not on `main`, not installed, never touched a real card (zero `R1 |` lines exist in any card in any tree), and its own README calls the enforcement a checkbox. Migration cost is **zero**. That is the decisive asymmetry, and it is the fact that separates this case from the general rule.

**3. Its current net value is negative, not merely incomplete.** Astra ran four adversarial fixtures — including a reference to a nonexistent receipt and an explicitly-false prerequisite — and **all four returned PASS**. A gate that passes fabricated evidence is worse than no gate, because it converts an acknowledged grounding problem into documented false confidence. Hardening it to "probably sound" and wiring it to freeze inherits that liability; deleting it does not.

GPT-5.6's architectural framing — *Markdown must never become executable input* — is right, and is the actual root cause rather than a stylistic preference. But the replacement needs one correction the prior plans did not make: **if the model proposes free-form shell and the controller merely runs it, the trust problem is unchanged and the sandbox becomes necessary again.** The replacement is only sound if the controller executes from a **fixed typed probe vocabulary** — parameterized read-only operations (`find_callers(symbol)`, `grep(pattern, path)`, `git_show(sha, path)`, `list_entrypoints()`) with typed arguments and no shell. That is what removes the need for a container: there is no untrusted string to contain.

**Disposition:** build SC-05 (controller receipts). Do **not** merge `sc/receipts-gate`; **archive** it — tag the branch and leave it unmerged as reference. The container hardening work (`--network none`, `--cap-drop=ALL`, `--read-only`, argv-not-eval) is genuinely good engineering and should be salvaged verbatim if a future card ever does need to execute untrusted argv. Deleting the branch would throw that away; merging it would install a gate that passes forged evidence. Archive is the correct third option and neither prior plan offered it.

*Argument against my own recommendation, stated honestly:* replacement is a larger, slower card than five bash fixes, and it defers grounding coverage by weeks while the system currently has none. If the schedule cannot absorb SC-05, the correct fallback is **not** to patch and ship Receipts — it is to ship nothing and keep the Haiku dependency-check, because a known-absent gate is safer than a gate believed to work. Never install the patched version as an interim measure; that is how the false-confidence failure mode arrives.

### (b) Astra's new top-level admission gate — **genuinely necessary, but wrongly packaged.**

Not scope creep. Three verified defects are fixed by nothing else in either plan:

- `process-adoption.json` pins revisions that do not match live HEAD (`07e885e`/`8f38901` vs `9a16678`/`7578be5`), and **no runtime path validates the pin against what is executing**. Policy drift is currently undetectable.
- 11 of 11 cards are un-ingestible by the runtime meant to run them — the practiced workflow and the executable system are different systems. All four auditors raised this independently; it is the audit's own headline.
- Freeze is a prose checklist. Every mechanism the audit recommends (receipts, envelopes, reachability) has no place to be *enforced* without an admission point.

A gate is the only artifact that converts these from documentation into an exit code, so it sits inside what the audit asked for, not beyond it.

**But Astra's packaging is wrong, by Astra's own rule.** Bundling card schema + exact repo HEAD + policy revision + receipt digests + forward/reverse reachability into one card is exactly the "slice by observable outcome, not file count" violation Astra's own P1 #4 warns against, and it makes one card depend on four unfinished subsystems. Split it: the gate card (SC-07) should be **thin** — it validates a manifest and fails closed. The manifest's *contents* are produced by SC-04 (schema), SC-05 (receipt digests) and SC-06 (envelope digests). The gate ships last and small; that is what makes it shippable at all.

### (c) Judge-off-vendor and SCI-013 — **both belong. Different weights.**

**Judge-off-vendor: yes, include, and it is the cheapest item in this plan.** Opus's supporting evidence is structural and survives independently of the identity claim I reject in (d): four distinct review roles ran this session — terra and luna as paired BREAK adversaries, sol as card reviewer, astra as judge — and **all four are GPT flavors dispatched through `codex exec`**. That is verifiable from the dispatch route, not from self-reported metadata, so the refutation in (d) does not touch it.

The argument is correlated failure, not fairness. Reviewers sharing a vendor share blind spots; the judge is the single point that collapses three correlated opinions into one verdict, so vendor correlation is most damaging exactly there. It is also a routing rule — no code, no migration — and it is **orthogonal** to reviewer count, which means it composes with risk-tiering instead of competing with it. Highest value per unit of effort in the whole plan. → SC-08.

**SCI-013: yes, but as a rider, not a card.** Verified in `docs/STRONG-CARD-IMPROVEMENTS.md`: a green mutant command rewrote 43 tracked proof logs across fresh worktrees because logs serialized absolute worktree paths. Two things temper it. The controller **did** catch it — "the mutant result was green while the post-command tree was dirty, so the controller blocked re-BREAK before dispatch" — so a partial mitigation exists. But that mitigation is a post-hoc dirty check that only worked because the writes happened to land on tracked files; untracked or in-place-identical writes would pass silently. The principle — *executable gates treat retained proof as immutable input; replay writes only to a controller-provided temp dir; compare tracked **and** untracked state before and after every command, including green ones* — is correct and cheap. It is one invariant on the admission gate, not a standalone card. → folded into SC-07.

Fable was right that both were missing from the original 10-item list. Astra surfacing neither is a real gap in Astra's plan.

### (d) Astra's two critiques — **one upheld, one upheld with a correction.**

**(d1) "3 reviewer-model-identity substitutions" — Astra is right; the finding does not hold.** I ran a forensic sweep of every correction artifact in both repos.

There are exactly **two** `metadata-correction.json` files, both under `cards/SC-BLD-R03/` (the other four paths are byte-identical worktree copies; `strong-cards_wip` has no `cards/` directory at all). One is a pure SHA-256 transposition typo (`bf5f9d5e` → `bf9f5d9e`) with the reviewer field untouched. The other — R03 `r1-terra` — is the only artifact in either repo where a cross-model-family string changed.

It does not support "produced by X, filed under Y":

- **Nothing was patched after the fact.** `git show --stat 31998b5` shows `review-original.json`, `review.json`, `metadata-correction.json` and an explanatory `README.md` were all added in a **single commit**. There is no prior commit where the review stood uncorrected. The original is still tracked today.
- **The correction downgrades a claim rather than asserting authorship.** It replaces an asserted `"model": "gpt-6-astra"` with `"requested_model": "gpt-5.6-terra"` **plus** `"provider_observed_model_effort": "unavailable"`, with the stated reason that observed model "must not be inferred from generic environment identity." The same anti-inference pattern recurs repo-wide (`"observed_telemetry": null`; `"basis": "parent dispatch request; provider execution telemetry unavailable"`).
- **The uncorrected original already pointed at the Terra dispatch** — `"review_id": "SC-BLD-R03-r1-terra-medium"`, `"worktree": "/private/tmp/builder-r03-break-terra-r1"`.
- **The project's own register says so.** SCI-005, verbatim: *"Neither error proves the requested runtime model was substituted."*

The other two cases the count likely drew on are not identity at all: R01 `r1-luna` changed a *requested-effort* value (`low`→`high`) with `model: gpt-5.6-luna` before and after; the P01-A1 case changed review *content*.

So the count is **at most 1, ambiguous, and disclosed**. Calling it provenance falsification is unsupported — and an audit finding that fails its own P6 (never assume; verify before naming a shape) is itself a defect worth recording.

**The honest finding is stronger than the one it replaces, and it is why the card survives:** every reviewer block in this corpus is self-reported by the reviewing model inside its own output. There are no timestamps beyond date-only, no run IDs, no dispatch envelope, no signature anywhere under `cards/`. Model identity is **unverifiable in both directions** — you can neither prove substitution nor disprove it. That is a structural provenance gap, and the remediation is identical either way (SCI-005: the controller, not the model, supplies dispatch metadata). **Keep SC-06; fix its justification.** It is now motivated by undecidability, not by fraud — which also means it should not be sequenced as an emergency.

**(d2) Risk-tiering by file count — Astra is right, but the critique lands on Fable's phrasing, not on the synthesized recommendation.** Astra argues the real axes are isolation / irreversibility / persistence, not category or file count. Correct. But the audit's own recommendation #9 already names a property list — "auth/isolation/concurrency/deletion/migration/irreversible-state" — which is a predicate, not a proxy. And Fable's rec #4 independently proposed the same mechanism: escalate when a card's **Gates** mention `auth, actor, token, ledger-write, or privilege`.

So Fable and Astra actually agree on the mechanism; the only genuinely weak clause is Fable's separate "≥5 files" threshold for the Construction packet. **Resolution:** drop file count entirely as a risk signal. Use the property predicate, and make it **mechanical** — computable from the card's frozen Touch List and Gates text, so escalation is a gate outcome rather than a per-session judgment call. That closes Astra's objection while keeping the one part of the proposal that was already right. → SC-04 (predicate replaces the ≥5-file rule) and SC-08 (predicate drives reviewer count).

---

## 2. The cards

Eleven bounded cards. Every one is independently acceptable and independently revertible.

### Wave 0 — blocking; nothing parallel dispatches until SC-01 lands

**SC-01 · DISPATCH-LIFECYCLE-TRUTH** — *effort M · risk HIGH · Builder*
Replace false settlement with a real state machine: `admitted → launched → running → exited → settled|quarantined`. Persist run ID, PID + start-time identity, log paths; add an exit watcher and restart reconciliation.
*Verified:* `t03_runner.py:369` maps `"launched": "settled"`; `:518-524` writes settlement then returns with the child still running; `:36` holds handles in `_ASYNC_PROCESS_REGISTRY` (in-memory dict, lost on restart); `:471-478` sends stdout **and** stderr to `DEVNULL`.
*Touches:* `builder_runtime/t03_runner.py`, `t12_plan_store.py` (settle API), `tests/runtime/`.
*Why blocking:* this is a false durable-state transition combined with deliberate evidence destruction — two of four auditors named it the single most dangerous unflagged issue. Every "still running… actually orphaned" incident routes through it, and it is the one defect that makes all other telemetry untrustworthy.

**SC-03 · GUARD-COVERAGE-AND-FAIL-CLOSED** — *effort S · risk MED · hooks*
Add `codex exec` to the sandbox guard's pattern list and validate its working tree; **fail closed when `jq` is absent** (currently `command -v jq || exit 0` at `:27`); resolve the `-C` contradiction by deleting one of the two rules; sync the stale repo copy against the global one.
*Verified:* the pattern `case` matches only `opencode run`, `opencode2 run`, `claude-local -p`, `strong-card-runner`, `pi -p|--print`; `codex exec` falls through `*) exit 0`. Repo copy (5,550 B, Aug 11) is 41 diff-lines behind the global copy (Sep 11).
*Touches:* `hooks/sc-dispatch-sandbox-guard.sh` (both copies), `~/.claude/agents/codex-gpt.md`, memory `feedback_codex_gpt_dispatch_unreliable`.
*Note:* the `-C` contradiction must be resolved by **deletion of one rule**, not by documenting both. Two active contradictory hard rules guarantee one is violated on every dispatch.

**SC-02 · DISPATCH-REGISTRY-STOPGAP** — *effort S · risk LOW · hooks*
One-line JSONL append per dispatch (worktree, model, PID, start time) plus a `Stop`-guard listing entries with no exit record. ~15 lines of shell; the realistic bridge until SC-01's durable ledger is live.
*Sequencing:* **after SC-03** — both edit `~/.claude/agents/codex-gpt.md`. Not parallel-safe with SC-03.

### Wave 1 — trust foundation; SC-04/05/06 are mutually parallel-safe

**SC-04 · CARD-SCHEMA-RECONCILIATION** — *effort M · risk MED · Builder + WIP*
Make the authored card and the ingested card one schema. Demote the PB0–PB10 Construction packet from mandatory to opt-in behind the **property predicate** from §1d2 (not a file count).
*Verified mismatch:* `t11_card_ingestion.py:234-237` requires the H1 to contain an em dash (U+2014) splitting into non-empty `card_id — title`; `_section_body` (`:100-106`) matches Touch List by `startswith("touch list")`. **7 of 11** cards fail on the missing em dash (`# Strong Card: PHASE1-DISPATCH-BRIDGE-v2`, `# PHASE2-BUILDER-CLI (v3)`, …); **4 of 11** fail because their headings are `## S — Scope (Touch List)` / `## B — Boundaries (Touch List)` / `## O — Object (Touch List)` — "touch list" is parenthesized at the end, so `startswith` never matches. Zero are ingestible.
*Judgment:* fix **both sides** — relax the parser to accept the em-dash-or-colon and suffix-parenthesized Touch List forms the humans actually write, *and* correct the template. Fixing only the template leaves a parser that rejects reasonable input; fixing only the parser leaves a template nobody follows.
*Touches:* `CARD-TEMPLATE.md`, `builder_runtime/t11_card_ingestion.py`, `tests/runtime/`.

**SC-05 · CONTROLLER-GENERATED-RECEIPTS** — *effort L · risk MED · WIP + Builder*
Per §1a. Controller runs a **typed probe vocabulary** (no shell) before drafting; stores `argv` + exit code + output digest + repo SHA + timestamp as JSON; cards reference receipt IDs by digest. Includes real forward *and* reverse reachability — reverse actually runs a search rather than checking that a `B<n>` line exists. Archive `sc/receipts-gate` under a tag; do not merge. Rewrite RULES §27 to describe the shipped mechanism.
*Retires:* the Haiku dependency-check — but **only after** this demonstrably catches its cases on replay of the three known misses (T03's absent caller, actor-sep's two other callers, repo-identity v1). Two unenforced grounding rules is how coverage reached zero; do not create a third overlap.

**SC-06 · REVIEW-PROVENANCE-AND-PERSISTENCE** — *effort M · risk LOW · Builder + hooks*
Controller stamps the dispatch envelope (requested model, effort, host acknowledgment, card + source hashes, worktree, run ID, timestamps); the envelope is authoritative and a review whose self-reported model disagrees is **refused, not corrected**. Verdicts are `tee`'d mechanically to `docs/reviews/<card-id>/<round>-<model>.json` as part of the dispatch's own call — zero extra model cost.
*Also:* any `review-corrected.json` / superseding review must record what changed and why, and may never silently alter a probe exit code or withdraw a finding without a controller-side replay (finding 3 in §0).
*Motivation corrected per §1d1:* provenance is currently **undecidable**, not falsified. Real, structural, and worth fixing — but not an emergency, which is why it sits in Wave 1 rather than Wave 0.

### Wave 2 — admission

**SC-07 · ADMISSION-GATE (`sc-freeze`)** — *effort L · risk MED · WIP + Builder*
One executable, fail-closed gate. Consumes a manifest and validates: card schema (SC-04), exact repo HEAD against the adoption pin (**verified stale today**), policy/adoption revision, receipt digests (SC-05), envelope digests (SC-06), forward and reverse reachability. Then delete the equivalent manual checklist prose.
*Carries the SCI-013 invariant:* gates treat retained proof as immutable input; replay writes only to a controller-provided temp dir; tracked **and** untracked state are compared before and after **every** command, including green ones; a success exit never overrides an undeclared write.
*Depends on:* SC-04, SC-05, SC-06. Deliberately thin — it validates a manifest others populate.

### Wave 3 — cheap and mutually parallel-safe, except SC-11

**SC-08 · JUDGE-PROTOCOL-CONSOLIDATION** — *effort S · risk LOW*
Collapse the three conflicting judge definitions into one table. Write `INVALID_CARD` into the BREAK lane. Hard rule: **two consecutive non-converging rounds = INVALID_CARD** (would have stopped R03 at r3 and saved four dispatches — its terminal state after five rounds was still double-REMEDIATE, with reviewers moving *away* from consensus). **Judge must be off-vendor** (§1c). Risk tier by mechanical property predicate, never file count (§1d2). Single file: `JUDGE-PROTOCOL.md`.
*Best value-per-effort in the plan.*

**SC-09 · DELETE-GUARD-GIT-HOLE** — *effort S · risk MED*
Cover `git worktree remove --force`, `git branch -D`, `git reset --hard`, `git checkout -- .`, `git stash drop` — verified: the guard's git branch handles **only** `git clean`, and grep for `worktree|branch -D|reset|checkout` returns zero hits. **And commit the guard into the canonical repo** — it currently exists only at `~/.claude/hooks/sc-delete-guard.sh`, untracked anywhere (§0, finding 1). Also fix `enforce-codex-timeout.py` to match `argv[0]` rather than the substring `codex exec` anywhere in a command, which today blocks innocent greps and trains string obfuscation.
*Sharpest framing:* the doctrine's own card close-out step is `git worktree remove`, and `TRASH-README.md` claims nothing on this machine can delete. That combination is the 2026-08-10 incident class, still open.

**SC-10 · DISPATCH-COST-TELEMETRY** — *effort M · risk LOW*
Wire dispatch token/cost into the **existing** global Langfuse at `~/langfuse/` (new project inside the one instance — never a second stack). No comparative efficiency claim in this system is checkable without it, including the claims in this audit and in this plan.

**SC-11 · RULES-TRIM** — *effort S · risk LOW*
2,224 lines / 26,732 words → under 1,200 lines. Move every `> **Why.**` block and every incident narrative to `runs/<id>/RETROSPECTIVE.md`; keep rule text.
*Sequencing:* **last.** Conflicts with SC-05 (rewrites §27) and SC-08 (judge table). Trimming first would guarantee merge pain.

---

## 3. Sequencing and parallelization

```
Wave 0   SC-01 ──────────────┐   (blocking: no parallel dispatch until landed)
         SC-03 ─→ SC-02      │   (SC-03 before SC-02: shared codex-gpt.md)
                             │
Wave 1   SC-04 ─┐            │   (mutually parallel-safe: disjoint files)
         SC-05 ─┤            │
         SC-06 ─┘────────────┤
                             │
Wave 2   SC-07 ←─────────────┘   (thin gate; consumes 04/05/06 outputs)
                             
Wave 3   SC-08 ─┐                (mutually parallel-safe)
         SC-09 ─┤
         SC-10 ─┘
         SC-11                   (last: conflicts with SC-05 and SC-08)
```

**File-collision map — the only unsafe pairs:**

| Pair | Shared file | Resolution |
|---|---|---|
| SC-02 / SC-03 | `~/.claude/agents/codex-gpt.md` | Sequence: SC-03 first |
| SC-05 / SC-11 | `RULES.md` (§27) | SC-11 last |
| SC-08 / SC-11 | `JUDGE-PROTOCOL.md`, `RULES.md` | SC-11 last |
| SC-04 / SC-05 | `CARD-TEMPLATE.md` (receipt section) | Minor; SC-04 owns the file, SC-05 appends after |

Everything else is disjoint. SC-01 (Builder runtime) and SC-03 (hooks) are in different repositories and safe to run concurrently despite both being Wave 0.

**Effort/risk summary**

| Card | Effort | Risk | Repo |
|---|---|---|---|
| SC-01 Dispatch lifecycle truth | M | **High** | Builder |
| SC-02 Dispatch registry stopgap | S | Low | hooks |
| SC-03 Guard coverage / fail-closed | S | Med | hooks + WIP |
| SC-04 Card schema reconciliation | M | Med | Builder + WIP |
| SC-05 Controller-generated receipts | **L** | Med | WIP + Builder |
| SC-06 Review provenance + persistence | M | Low | Builder + hooks |
| SC-07 Admission gate | **L** | Med | WIP + Builder |
| SC-08 Judge-protocol consolidation | S | Low | WIP |
| SC-09 Delete-guard git hole | S | Med | hooks + WIP |
| SC-10 Dispatch cost telemetry | M | Low | Builder |
| SC-11 RULES trim | S | Low | WIP |

---

## 4. The one thing this plan is really about

All four auditors converged on the same diagnosis and it survives verification: **the bottleneck is adoption, not rigor.** Five of thirteen SCI proposals adopted. Receipts built, green, unmerged, uninstalled, never used on a card. REMEDIATE card frozen and unshipped while REMEDIATE is 75% of all verdicts. The delete-guard untracked. The adoption pin stale against live HEAD with nothing checking it.

The review layer is doing real work and should be kept — every round checked found genuine defects. The enforcement layer is largely narrative for the routes actually in use. The grounding layer exists twice on paper and zero times in practice.

That is why SC-07 exists and why it is thin. An admission gate is the only artifact that makes adoption *mechanical* rather than remembered — the single place where "we built it" becomes "it runs, or nothing freezes." Every other card in this plan is either unblocking that gate or is a cheap fix that should not wait for it.

**Do not start here.** Start with SC-01, because until dispatch state stops lying, none of the evidence any later gate consumes can be trusted.
