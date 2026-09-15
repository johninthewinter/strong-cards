# Fable 5.1 high — Strong Card system audit

Sanity check before reporting: re-read the five questions in the ask; every claim below cites a file, commit, or transcript count read directly (RULES.md, CARD-TEMPLATE.md, JUDGE-PROTOCOL.md, CONSTRUCTION-PROTOCOL.md, all hook scripts on both the canonical repo and `~/.claude/hooks`, the `sc/receipts-gate` branch, the 11 session cards in `docs/plan/strong-cards/`, the session commit log, and marker counts from the 51 MB session transcript). Nothing here is inferred from the docs' own claims about themselves.

## The single most important finding

**The enforcement layer does not cover the dispatch path this session actually used.** The doctrine's one genuinely blocking mechanism — `sc-dispatch-sandbox-guard.sh` (exit 2, PreToolUse/Bash) — pattern-matches only `opencode run`, `opencode2 run`, `claude-local -p`, `strong-card-runner`, `pi -p`, and (global copy only) `sbx exec`. This session's coding and review traffic was 62 `codex-gpt` Agent dispatches (419 `codex exec` mentions in the transcript) plus 46 Sonnet / 24 Opus / 25 fork Agent dispatches. **Zero of those pass through the guard**: the Agent tool is not a Bash call, and `codex exec` is not in the pattern. Worktree isolation this session was upheld by convention (161 `EnterWorktree` calls and the `codex-gpt.md` "Always `-C` a clean worktree" rule), not by the hook the CLAUDE.md describes as "genuinely blocks."

Worse, the two conventions contradict each other: `~/.claude/agents/codex-gpt.md` says "**Always** `-C <absolute path>`... no exceptions"; memory `feedback_codex_gpt_dispatch_unreliable` (same session family, 09-12) says **never** pass `-C`, rely on inherited cwd. Both are labeled hard rules. Whichever one an agent follows, the other is violated, and no hook checks either. The 2026-08-10 incident class (sandboxless dispatch deleting a shipped module) is therefore not mechanically closed for the routes in actual use — it is closed by the agent remembering.

Files: `strong-cards_wip/hooks/sc-dispatch-sandbox-guard.sh:29-33`, `~/.claude/agents/codex-gpt.md` ("Hard rules"), `~/.claude/projects/-Users-misterj-src-The-Builder/memory/feedback_codex_gpt_dispatch_unreliable.md`.

## 1. Where the system is genuinely strong

**Multi-round review found real defects every round I could verify — this is not rubber-stamping.**
- `phase2-builderd-lifecycle` v1→v2 (Sol): two false grounding claims, an unserialized cross-process TOCTOU on `start()`, PID-reuse signalling an unrelated process, non-atomic PID-file write, and a scope/gate contradiction. Round 3→v3.1: child orphaned if the PID-file write raises after `Popen`. All real.
- `phase2a-repo-identity-resolver` v1→v3: bare-repo `path:` collision, SCP-style remotes never host-folded (SSH vs HTTPS forms of the same remote → different identities), `--all` vs `HEAD` root instability, non-`origin` remotes silently ignored, permission-denied misclassified as `nongit:`. All real, all with live probes.
- `phase2-actor-separation` v1: Sol round 1 caught that `finish_dispatch_attempt` is also the runner's and daemon's automatic-settlement path, so requiring `finishing_actor` would either break them or force a fake sentinel actor ("falsifies provenance"). Real.

**Coder ≠ grader ≠ breaker is real in practice, but by instance not by model.** Most reviews were GPT-5.6-sol reviewing a Sol-drafted card (T12-ENV-SCOPING: "2 Sol review rounds"; BUILDER-CLI: "3 Sol review rounds"). The fresh context is doing the work, not model diversity. The one place model diversity earned its keep is the actor-separation daemon bypass: Sonnet passed it, a second Sol review found it. Keep the mixed-model second review for security/invariant cards specifically.

**`INVALID_CARD` is honored, not fought.** 192 transcript mentions; cards were redrafted (repo-identity split 3-way, T03 re-scoped, actor-sep v2) rather than forced through. The commit log shows `docs: draft card v1` → amend → freeze → feat → merge as a consistent pattern for 8 cards.

**The Receipts gate is well-engineered as a bash artifact.** Argv execution (no `eval`), tokenized allowlist, per-token deny of exec/write flags (`find -exec`, `rg --pre`, `git grep -O`, `--output=`), container with `--network none --cap-drop=ALL --read-only`, mount-is-real probe, fail-closed with no host fallback, a 20-case self-test. §27.4 (reverse reachability from protected state) is the correct generalization of the daemon-bypass incident — it names the exact question the actor-sep author never asked.

**The delete-guard is argv-based, not substring-based**, with a PostToolUse verifier that re-hashes from disk. That is the right design and it is stricter than the spec asked for (all `rm`, not just `rm -rf`).

**Amendment logs inside the cards** (repo-identity, lifecycle, plan-ingest) are a usable audit trail of what each review round found and how it was resolved.

## 2. Where it is weak — from this session's actual failures

**a. The Haiku dependency check is a rule that was written and not run.** Memory `feedback_dependency_check_haiku` mandates a Haiku pass on *every* card before Sonnet/Opus sign-off, with PHASE1-DISPATCH-BRIDGE (wrong `actor_kind` enum, wrong test path) as the motivating incident. The transcript shows **3** Haiku dispatches in a 51 MB session that produced 11 cards. T03 (function exists but real call site never supplies the store), actor-sep v1 (same method has two other callers), and repo-identity v1 were all dependency/premise failures a grep would have caught. The rule existed; the workflow skipped it because nothing enforces it and it sits in a memory file, not in the dispatch path.

**b. Receipts (§27) — the replacement for (a) — has never touched a real card.** Zero cards in `docs/plan/strong-cards/`, `.audit-scratch/cards/`, or `cards/` contain an `R1 |` receipt line. The hook, the template section, and the §27 rule live on branch `sc/receipts-gate` (worktree `.claude/worktrees/sc-receipts`), unmerged to `main`, not installed in `~/.claude/hooks/`. The memory note already says "the Haiku pass shrinks now that Receipts shipped" — Receipts has not shipped; it has been built. Two grounding mechanisms now exist on paper and neither runs.

**c. Frozen-card violation absorbed silently on actor-separation.** The card froze at v2; the daemon bypass was found post-implementation; the fix (`57975c7`: 9 files, +212/-27, including `builderd/client.py`, `server.py`, `runner.py`, `test_builderd.py` +94) roughly doubled the card's footprint, and the card's Gates section was rewritten after the fact ("The owner-authorized daemon-bypass repair supersedes Scope v2's unsafe status mapping"). Doctrine §1.4: edits after dispatch are a new attempt. In practice it was merged under the same card ID. The rule is right; the process bent it because re-freezing costs another round.

**d. Review verdicts are not persisted — the audit-trace rule was not followed for any card this session.** `docs/reviews/` has nothing newer than 09-12. The REMEDIATE card ("passed 1 of 3 reviews, 2 found gaps") shows only `v1: initial draft — frozen before coding` and no review record anywhere in git. The only review artifacts saved were the two T12-ENV-SCOPING *prompts* (not results). Every verdict cited in this audit's brief exists only in the chat transcript. CLAUDE.md: "subagent/panel reviews are kept, never ephemeral."

**e. Lost/orphaned dispatch handles have no doctrine at all.** 66 `TaskStop` calls and 338 "still running" mentions in the transcript. RULES §6/§7 ("probe, don't watch the clock"; "every background dispatch is actively polled") are written for Pi Broker local models with a broker log and a `.jsonl` transcript path. A `codex-gpt` dispatch is a Sonnet subagent wrapping a `timeout N codex exec` — two opaque layers; when the outer handle is lost, the inner process keeps running with no PID registry, no worktree→process map, and no rule saying how to find or reap it. The_Builder's T12 dispatch-attempt ledger is literally the missing registry — and per `docs/bootstrap/2026-09-13-orchestrator-drift-diagnosis.md`, Builder cannot dispatch Strong Cards yet.

**f. Hook drift between canonical and installed.** `~/.claude/hooks/sc-dispatch-sandbox-guard.sh` has `sbx exec` support that `strong-cards_wip/hooks/` lacks. The canonical repo is behind the running copy. `strong-cards_wip` also has an untracked `.claude/` and a prunable worktree at `/private/tmp/builder-p01-fetch-wip`. Two dangling worktrees remain in The_Builder (`plan-v2-t10-triage` on an already-merged branch).

**g. Three overlapping judge/reviewer definitions.** JUDGE-PROTOCOL: per-card judge is Sonnet low. CONSTRUCTION-PROTOCOL: process judge is GPT-6 Astra high, BREAK A/B are Luna high + Terra medium. Session practice: Sol reviews Sol. Three documents, three answers; each session picks.

## 3. Cost: working as designed, or structural inefficiency?

**Both, and the split is clean.** The rounds are catching real defects (see §1), so cutting reviews would lower quality. But look at *what* they catch: false grounding claims, missed second call sites, TOCTOU races, non-atomic writes, orphaned children. The first two categories are grep-shaped and belong before drafting (that is Receipts' whole thesis). The last three are design-shaped and are being caught by reviewing *prose* — the lifecycle card is 21 KB for a start/stop/status helper, and by v3.1 the card is the implementation written in English, reviewed four times. TDD in code would have found the PID-file-after-Popen edge in one failing test at a fraction of the round-trip cost.

Per card this session: 1 draft + 2–4 Sol reviews + 1 implementation + 1–2 Sonnet judges + Joe reading each round. For 100–200 line changes that is 5–8 model runs and, more expensively, 3–5 synchronous decision points for Joe. **The token cost is tolerable; the human-hours cost is in the round-trips, and the round-trips exist because drafting is cheap and ungrounded.** The pattern "draft fast, review expensive, repeat" is inverted from where the leverage is.

The strongest cost signal is that **the system's own consumer routed around its heavy protocol.** `cards/SC-BLD-P01/` (511 files: r1–r4 revisions, mutant logs, controller-preflight JSON, per-reviewer probe dirs) is the CONSTRUCTION-PROTOCOL PB0–PB10 shape. Every card that shipped this session used the ~5–10 KB I/O/S/B/G/R/E form in `docs/plan/strong-cards/` and ignored the "Construction packet required before drafting" section that CARD-TEMPLATE.md now mandates at the top. The heavy protocol was abandoned in practice within days of being adopted; the template still requires it.

## 4. Prioritized recommendations — what to cut, merge, or automate

1. **Extend the sandbox guard to the routes actually used, or stop calling it enforcement.** Add `codex exec` to the pattern and validate its `-C` (or, for the Agent route, put a worktree check inside `codex-gpt.md`'s single Bash call that refuses the primary tree). Resolve the `-C` vs no-`-C` contradiction by deleting one of the two rules — the memory note is the more recent evidence; if `-C` triggers classifier flapping, `codex-gpt.md`'s "Always `-C`" is wrong and should say "EnterWorktree first, then bare `codex exec`, and verify `git rev-parse --git-common-dir != --absolute-git-dir` before running."

2. **Merge `sc/receipts-gate`, install it, and make it the *only* pre-freeze grounding step.** Delete the Haiku dependency-check memory rule outright — not "shrink it." Two rules aimed at the same failure, both unenforced, is how you get zero coverage. One mechanical gate with an exit code beats a model pass that gets skipped. Fix the two fragilities in §5 first.

3. **Cut the Construction packet section from CARD-TEMPLATE.md and demote CONSTRUCTION-PROTOCOL to "opt-in for cards touching ≥5 files or a security boundary."** Every card that shipped ignored it. A mandate nobody follows trains everyone that the template is advisory, which then weakens the parts that matter (Gherkin, fail-first, Touch List).

4. **Collapse three judge definitions into one table.** Per-card judge on fail: Sonnet low (cheap, already the hook's instruction). Pre-freeze review: one Sol pass. Second independent review *only* for cards whose Gates mention auth, actor, token, ledger-write, or privilege — that is where the mixed-model review paid off this session, and nowhere else. Everything else gets one review.

5. **Persist review verdicts mechanically or stop claiming audit trace.** Minimum viable: the `codex-gpt` agent's report gets `tee`'d to `docs/reviews/<card-id>/<round>-<model>.md` as part of its one Bash call. Zero extra model cost; closes finding 2d.

6. **Replace multi-round prose review of design edge cases with a fail-first test list.** For any card where round 2+ finds a race/atomicity/orphan edge, the judge's output should be a *test name* added to Gates, not a paragraph added to Scope. Lifecycle's 21 KB card should have been 4 KB plus 8 test names.

7. **Make re-freeze after a post-dispatch scope change a mechanical rename**, not a judgment call: if the merged diff touches a file not in the frozen Touch List, the merge commit must reference `<card>-v<n+1>`. The stop guard already reads `git status`; add a Touch-List diff to `sc-dispatch-postcheck.sh` and it becomes automatic.

8. **Add a dispatch registry now, before Builder ships one.** A one-line append to `~/.claude/logs/sc-dispatches.jsonl` (worktree, model, PID, start time) from `codex-gpt.md`'s Bash call, plus a `Stop`-guard line listing entries with no exit record. This is the only realistic fix for lost handles until T12 is live, and it is ~15 lines of shell.

9. **Sync `strong-cards_wip/hooks/` from `~/.claude/hooks/`** and add a CI-free check: the stop guard already runs in every session; have it `diff -q` the two directories and report drift.

10. **Trim RULES.md.** 26,700 words, 102 numbered rules, 20 "PERMANENT," 20 incident narratives. No model reads it at dispatch; the SessionStart hook loads a summary. Move every `> **Why.**` block and every 2026-08 nukegraph incident into `runs/<id>/RETROSPECTIVE.md` and keep the rule text. Target: under 8,000 words. Rules that cite an incident nobody will re-read are not stronger for the citation.

## 5. Dangerous or fragile, not yet flagged

**a. `sc-receipts.sh` will cry wolf on every unrelated commit.** Check 2 tags hits by matching the literal `file:line` string in the card (`grep -qF -- "$loc" "$CARD_ABS"`, line 481), and the template's own examples record `rg -n` output with line numbers. Any commit that shifts a line above a tagged hit makes the drift check BLOCK. On a repo committing 20+ times a day, every receipted card is stale by dispatch time. The predictable adaptation is re-tagging mechanically or reaching for `--no-sandbox` — the gate trains its own bypass. Fix: match on `file` + a content anchor (the matched line's text), not line numbers; strip `-n` line prefixes before comparing recorded `out`.

**b. `sandbox_cleanup` kills other sessions' replays.** Line 224: `docker ps -aq --filter ancestor=$SANDBOX_IMAGE --filter status=running` then `docker rm -f`. Any concurrent `sc-receipts.sh` run — the norm under parallel dispatch — has its container killed by the first one to exit. Label containers with the script's PID and filter on the label.

**c. No timeout on replay.** `run_replay` has `--memory 1g --pids-limit 256` but no `timeout` around `docker run` and no `--cpus`. Only `tail -f` was considered as a hang. A receipt of `git log` with no bound, or `find` on a large tree, hangs the freeze path indefinitely. Wrap in `timeout 60`.

**d. The delete-guard's "only the user deletes" invariant has a git-shaped hole.** `sc-delete-guard.sh` blocks `git clean` only (line 190–194). `git worktree remove --force`, `git branch -D`, `git reset --hard`, `git checkout -- .`, `git stash drop` all pass, and the doctrine's own card close-out step is `git worktree remove`. Either state this in TRASH-README.md's "Known limits" (it is absent) or route `worktree remove` through a trash-the-worktree-first wrapper. As written, an agent can destroy an entire worktree of uncommitted work through the sanctioned close-out command while the README says nothing on this machine can delete.

**e. `enforce-codex-timeout.py` matches the substring `codex exec` anywhere in a command**, including inside quoted grep patterns — it blocked my own transcript grep during this audit. Harmless here; but it means any `grep`/`echo`/`git log --grep` mentioning the phrase is blocked, and an agent's natural workaround is to obfuscate the string, which is exactly the habit you do not want trained. Match on argv[0] like the delete guard does.

**f. Actor-separation ships a string-inequality check under the commit title "enforce separate accepting actor."** The card's own honesty note says a fabricated distinct string defeats it. The ledger's core invariant — the thing the whole T12 accept path rests on — is currently `actor_a != actor_b` on caller-supplied strings. This is documented, which is good; what is not documented is that every downstream card (REMEDIATE, judge CLI, BREAK) is now being built on top of it as if it held. The doctrine has no "known-weak invariant" register; it should, and this should be its first entry.

**g. The template's mandatory sections are now themselves ungrounded.** CARD-TEMPLATE.md requires PB0–PB10 receipts, a Langfuse trace pull (JUDGE-PROTOCOL §1.3a, project `nukegraph-strongcard`), Pi Broker transcript paths, and `.audit-venv` provisioning rules — none of which exist for The_Builder's codex-route cards. A template that mandates evidence sources the consumer cannot produce is how "the packet is within 16k / 24k" gets ticked without being measured. Per-project template overlays, or a template that says which sections apply per harness, would fix this.

---

**Bottom line:** the review layer is doing real work and should be kept; the enforcement layer is mostly narrative for the routes in actual use; the grounding layer exists twice on paper and zero times in practice; and the human cost is concentrated in round-trips that a merged, line-number-insensitive Receipts gate plus a fail-first-test-shaped judge output would remove without lowering the bar.
