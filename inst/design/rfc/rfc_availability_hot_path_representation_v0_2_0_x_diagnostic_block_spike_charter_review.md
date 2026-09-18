# Availability Hot-Path Representation - Diagnostic Block Charter Review v1

**Status:** First pre-execution structural review.
**Reviewer:** Codex; not the Charter author or prospective spike executor.

## Reviewed source state

- Branch `v0.2.0.1`; HEAD
  `b0fe6b8fb8c44981ad9fc6f8692ce076be72e764`.
- Charter v1 is untracked, exactly 150 lines, ASCII-only, LF-terminated, has
  one question mark and one kill/recharter clause, and passes
  `git diff --no-index --check`.
- The prerequisite artifacts were inspected directly. Their six measurements
  reproduce the stated 43.67-second and 0.30-second medians and 383,042-row
  shape; this review did not rerun them or execute the spike.
- The cited fold anchors, writer seam, contracts, provider evidence, and run
  identity paths were inspected. Pre-existing worktree changes were untouched.

## Verdict

**CHANGES_REQUIRED.** The Charter passes the protocol's shape and scope tests,
but one clock error affects its terminal envelope and two evidence instructions
are ambiguous against current source. Write Charter v2 as a historical
successor and return it for the second and final structural review.

## Findings

### B1 - The 60-second rationale turns profiler share into elapsed wall

Lines 100-104 multiply the alternative's 85.3% share of *captured in-loop
samples* by its 93.47-second `t_loop`, yielding about 78 seconds of diagnostics
and a roughly 30-second forecast. That conversion is not licensed by the
evidence. `lanes_757.csv` contains only 60.18 classified seconds inside the
loop; the cycle has already recorded that Windows `Rprof()` did not sample the
whole loop. Seed v2 lines 88-91 explicitly prohibit treating those shares as an
exact wall partition.

The independent prerequisite gives a useful but different bound: replacing its
43.67-second control with its 0.30-second block inside the 102.58-second fold is
an optimistic arithmetic result near 59.2 seconds, not 30 seconds. It does not
show that 60 seconds admits two times the expected wall for assembly and noise.

Required correction: retain or change the 60-second envelope deliberately, but
state its basis with compatible clocks. If retained, call it an aggressive
near-floor decision boundary and do not claim a 30-second full-fold forecast or
noise allowance from sampled shares. Keep 25-40 seconds an aspiration only.

### M1 - The parity pair's run identity normalization is under-specified

Claim 6 excludes top-level `run_id`, creation time, and config store locators,
while line 116 assigns a run ID per fold run. `runs.config_json` also embeds
`run_id`; the preceding provider spike normalized
`config_json.run_id`, `config_json.db_path`, and
`config_json.data.snapshot_db_path` explicitly. The present wording allows an
executor either to use one shared ID in separate stores or to use different IDs
and silently add an exclusion. Those produce different identity checks.

Required correction: pre-register one rule. Prefer the already exercised shape:
use the same run ID for the non-measured pair in separate copied stores, list
every top-level and embedded exclusion exactly, and compare
`archived_at_utc`. If IDs differ, explicitly exclude embedded `config_json.run_id`
as well. The checker must reject any extra normalization.

### M2 - The `setv()` trace is broader than the mechanism it governs

Claim 10 says the semantic-scenario trace records every `collapse::setv()`
target and permits no character or list target. Existing, unchanged production
code already uses character `setv()` calls in the fill reconstruction buffer
(`R/fold-reconstruction.R:221-227`). A scenario that reaches that path would
fail for work outside the diagnostic-block seam; a scenario that does not reach
it would not prove the intended call attribution.

Required correction: scope the prohibition and recorded target types to calls
originating in the new diagnostic block constructor or `append_block()` call
stack. Unchanged package calls may be recorded separately but cannot decide the
arm. Preserve the rule that the new path uses base replacement for character
and list columns.

### L1 - Claim 3 labels semantic categories as literal stages

`restriction`, `no-fill`, `fill`, and `completion` are not all values of the
persisted diagnostic `stage` column. Restrictions are `decision` rows with
restriction reason codes; fill/no-fill are `execution` outcomes; completion is
stored separately. Rename this to semantic coverage and bind each item to its
actual stage, outcome, reason, or completion status so the checker cannot look
for nonexistent stage tokens.

## Verified non-findings

- There is one operative question, one answered prerequisite, two arms, one
  seam, one kill/recharter condition, and no pre-authored expected rows.
- The alternative preserves all ordinary diagnostics and the existing bounded
  writer, transaction owner, chunk boundary, schema, ordering, and public
  readers. The prepared provider is held constant in both arms.
- The 757-pulse fixture, three measured repetitions per arm, external peak
  sampling, cold/warm clock split, arm attestation, gut requirement, and
  persisted multiset comparison make the performance claim falsifiable.
- Ten contract-level evidence categories do not exceed the ten-case cap. The
  runner/checker/inventory boundary, 1,500-line harness budget, 500-line
  correction stop, and no-provenance-machinery rule match the protocol.
- The post-rollback exception path may remain scalar and outside the in-loop
  block mechanism; the arm trace should distinguish that existing path rather
  than silently count it as fallback.

## Required next step

Claude should write
`rfc_availability_hot_path_representation_v0_2_0_x_diagnostic_block_spike_charter_v2.md`,
changing only B1, M1, M2, and L1 while preserving Charter v1 and this review.
Keep one question, two arms, one kill condition, ASCII, and at most 150 lines.
Do not implement, execute, update the RFC index, stage, commit, or push. Return
v2 for the second and final pre-execution structural review.

CHARTER_REVIEW_DISPOSITION: CHANGES_REQUIRED
