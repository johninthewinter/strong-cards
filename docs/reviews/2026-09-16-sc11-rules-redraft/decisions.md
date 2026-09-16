# SC-11 current-main trim decisions

## Baseline and method

Worktree branch: `sc-11-rules-trim-v2`. Starting HEAD and local main both resolved to
`9fd394ddbc342851e2a953b272131b0d75adab43`; initial tracked and untracked status was clean.
The complete current `RULES.md` was read before editing. Both historical diffs were read:
`cc5d3d2..7315e66` (Batch A+B) and `7315e66..bfb220f` (Batch C).

The supplied history description did not match the actual file contents: current HEAD and
`cc5d3d2` both contain RULES blob `5020416a4140b0d346fe8c34bd7e7c91dd2f7203`, exactly
2,236 lines. The historical baseline is a root snapshot already containing sections 7-26,
the construction amendments and SC-08 judge consolidation. The intervening main history
does exist, but its net RULES content equals that snapshot. Every original source passage
therefore still exists verbatim; the decisions below depend on present semantics and
consumers, not an assumed stale-content mismatch.

Edits were freshly authored against the current file. No merge, cherry-pick, old-patch
application or replacement with an old commit's file was used. Repository-wide searches
found no other tracked file referencing the supplemental section numbers being renamed.
The current RULES references and authoritative judge protocol were checked explicitly.
Historical technical claims were retained as documented incidents, not re-certified as
current runtime behavior. The older plan's under-1,200-line target is superseded by this
task's conservative approximately 7% target; no wholesale incident extraction was attempted.

## Batch A+B decisions

APPLIED (adapted) means the original intent survives, with the stated correction needed
to preserve current meaning. SKIPPED means the original operation was not replayed.

| Item | Disposition | Reason |
|---|---|---|
| AB01: RULE 3.9a, `14.x` to `14.2` | APPLIED | RULE 14.2 is the existing structural/causal-evidence principle actually cited. |
| AB02: RULE 3.7.5 alternatives rationale | APPLIED (adapted) | Condensed the repeated explanation while retaining the complete merge sentence and options (b)/(c), which the tracked-card fallback still cites. |
| AB03: RULE 5.6 P0-10 second-occurrence narrative | APPLIED (adapted) | RULE 5.4 already owns clean-shell verification; kept both counts, same-command/worktree evidence, date, incident ID and known baseline failure. |
| AB04: RULE 5.7 blockquote removal | APPLIED | Promoted the rule to normal body text without changing its wording or the content-check extension immediately before it. |
| AB05: RULE 5.10 sibling incident | APPLIED (adapted) | Kept issued-but-unconfirmed edit, unchanged-file proof and verification requirement; removed repeated narration of the same failure. |
| AB06: RULE 7.6 scratch listener path | APPLIED (adapted) | No tracked `scratchpad/broker-listener.mjs` exists; describe the passive Pi Broker connection without the old replacement's broken parentheses or an invented new path. |
| AB07: RULE 7.7 uncommitted-status paragraph deletion | SKIPPED | RULE 7.12 explicitly cites this paragraph's shared-tool commit precedent; kept the dated context rather than orphan that dependency. |
| AB08: RULE 7.9 memory procedure deduplication | APPLIED (adapted) | Refer to section 9A's footprint/idle/exact-flags procedure, but retain host-pressure assessment, post-restart health check and before/after logging absent from the old one-line replacement. |
| AB09: RULE 8.2b quickstart warning | APPLIED (adapted) | RULE 7.10 already states the launch restriction and interpreter failure; keep the sustained-profile command and session-recovery instructions. |
| AB10: move RULE 9.2 beside RULE 9.1 | APPLIED | Move verbatim; forbidden-key override remains adjacent to the prohibition. |
| AB11: move RULE 9.3 beside RULE 9.2 | APPLIED | Move verbatim; allowed keys and keychain requirement remain intact. |
| AB12: separator before section 18 | APPLIED | Match existing top-level section boundaries; preserve all section text. |
| AB13: separator before section 19 | APPLIED | Same formatting-only change; preserve the concurrent-worktree rule. |
| AB14: separator before section 20 | APPLIED | Same formatting-only change; preserve the comments rule. |
| AB15: separator before section 21 | APPLIED | Same formatting-only change; preserve executable preflight and construction ledger amendments. |
| AB16: separator before section 22 | APPLIED | Same formatting-only change; preserve boundary counts and split escalation. |
| AB17: separator before section 23 | APPLIED | Same formatting-only change; preserve baseline-delta and ownership gates. |
| AB18: separator before section 24 | APPLIED | Same formatting-only change; preserve composite reachability and census escalation. |
| AB19: separator before section 25 | APPLIED | Same formatting-only change; preserve atomic activation and migration-map addendum. |
| AB20: separator before section 26 | APPLIED | Same formatting-only change; preserve executable API and exactness addendum. |

## Batch C decisions

| Item | Disposition | Reason |
|---|---|---|
| C01: repair truncated RULE 3.7.5 sentence | SKIPPED | Current main is intact; Batch A+B itself introduced the truncation. AB02 avoids it and retains both alternatives instead of creating then repairing corruption. |
| C02: RULE 7.9 pointer, section 9.8 to 9A | APPLIED | The freshly condensed procedure points to the renamed memory section. |
| C03: RULE 9.4 `RULE 9.9 point 7` pointer | APPLIED | Points to RULE 9.8 after the formatter rule is reorganized; obsolete point 7 no longer exists. |
| C04: formatting RULE 9.9 to RULE 9.8 | APPLIED | Frees the collision with the repetition section; supplemental sections move to unused 9A-9E labels. |
| C05: formatting point 1, prose-retry prohibition | APPLIED (adapted) | Keep the prohibition once beside prevention and evidence; remove obsolete broad claims about the model/tool's inability. |
| C06: formatting point 2, mechanical fix and baseline diff | APPLIED (adapted) | Retain deterministic repair and Touch List check, ordered after judge approval. |
| C07: formatting point 3, judge and polling | APPLIED (adapted) | Keep mandatory pre-fix judgment, evidence packet and active polling; reference current JUDGE-PROTOCOL eligibility instead of re-hardcoding an unconditional model. |
| C08: formatting point 4, routine whitespace check | APPLIED | Retain routine artifact verification for every touched file with an established style. |
| C09: formatting point 5, preventive prose failure | APPLIED (adapted) | Condense repeated reasoning but retain the SC-02 preventive-warning failure and its 68-tab/zero-space evidence. |
| C10: formatting point 6, model escalation failure | APPLIED (adapted) | Retain Luna-to-Sol failure, 208-tab/zero-space evidence, and successful missing-test repair to keep defect classes distinct. |
| C11: formatting point 7, promote root cause/prevention | APPLIED (adapted) | Lead with pi-lens/Biome diagnosis, configuration and logs; retain flag, sandbox independence, config priority, scope fence and legitimate-style exception. |
| C12: formatting self-reference/fallback rewrite | APPLIED (adapted) | Remove obsolete numbered self-references; prevention skips repair, never routine verification required by RULE 3.3 and section 5. |
| C13: section 9.8 to 9A | APPLIED | Same memory topic and four rules remain; label was unoccupied, with no external tracked consumer. |
| C14: section 9.9 to 9B | APPLIED | Same repetition topic, including 9B.1a and both internal sampling references; no external tracked consumer. |
| C15: section 9.10 to 9C | APPLIED | Same untracked-scratch topic and two rules; label was unoccupied, with no external tracked consumer. |
| C16: section 9.11 to 9D | APPLIED | Same port topic and all three rules, including multi-proxy validation; no external tracked consumer. |
| C17: section 9.12 to 9E | APPLIED | Same hard-denial topic and both rules, retaining limits on controller commits; no external tracked consumer. |

## Scope and verification

The requested outputs are `RULES.md` and this decision record. No executable, hook, template,
judge protocol, construction protocol or historical review artifact was changed.
The original two batches reduced 2,236 to 2,153 lines (83 lines, 3.71%), not 7%.
This redraft reduces 2,236 to 2,151 lines (85 lines, 3.80%). No additional policy cuts were
made merely to reach 7%; all numbered rules and the current construction amendments remain.

Validation completed against the final artifact:

- `git diff --check`: passed; only RULES and this new record are in scope.
- Pandoc GFM-to-JSON parsing: passed; all eight fenced code blocks match the baseline;
  RULE 5.7 is a top-level paragraph rather than part of the preceding blockquote.
- Section/rule inventory: all 34 sections and 104 numbered rules retained, with no duplicate
  rule IDs. All 22 references to the renamed supplemental sections/rules resolve.
- Preservation comparison: 23 untouched sections are byte-identical after removing boundary
  separators; the five renamed supplemental sections differ only in their IDs. Sections
  18-26 retain every incident, requirement and addendum. RULE 9.2/9.3 moved verbatim.
- Consumer/dependency sweep: no other pre-existing tracked file references the changed IDs;
  RULE 7.12 still has its RULE 7.7 precedent, and RULE 3.7.5 still defines its option (c).
  All 37 decisions are accounted for: 35 applied/adapted, two skipped.

The initial Markdown declaration check also matched RULE 5.8's reference to RULE 5.7;
restricting it to paragraph starts confirmed the actual declaration without changing the file.
This is a single-run editorial review as requested, not independent model acceptance or runtime
testing. No code changed, so unrelated hook/application suites were not run.
