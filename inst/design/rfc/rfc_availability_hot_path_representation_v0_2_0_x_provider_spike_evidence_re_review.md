# Availability Hot-Path Representation - Provider Spike Evidence Re-Review

**Status:** Second and final post-execution review under
`spike_protocol.md` Section 7.
**Reviewer:** Codex; Seed v2 author and Charter reviewer, but not the spike
executor or provider-Charter author.

## Reviewed source state

- Branch `v0.2.0.1`; HEAD
  `b0fe6b8fb8c44981ad9fc6f8692ce076be72e764`.
- Reviewed the corrected uncommitted runner, checker, inventory, eleven
  evidence CSVs, provider seam, and prepared provider.
- Nothing was staged or pushed, and the RFC index remained untouched.
- The R harness totals 1,458 lines, inside the 1,500-line Charter budget.

## Verdict

**PASS_WITH_LOW_OBSERVATION.** Both first-round findings are closed. The
evidence supports the Charter's **GREEN** answer: the prepared provider
preserves the registered semantics, meets all three envelope components, and
removes provider resolution as the leading in-loop lane. This verdict closes
the provider-preparation question only. It neither adopts the spike seam nor
completes the RFC.

## First-round findings

### M1 - Closed: optional test state is represented honestly

`regression_tests.csv` contains 85 deterministic tests per arm, with no
failure, error, or skip. The mirai-dependent parallel-worker test is absent
from that file and appears once per arm in `regression_optional.csv`. On this
host mirai was unavailable, so both rows record `ran = FALSE`,
`skipped = TRUE`, and zero passes. The checker enforces the relationship
between availability, execution, skipping, and passes; it does not convert a
skip into a pass.

### M2 - Closed: full-population persisted parity is direct

An explicitly non-measured 757-pulse pair keeps both stores long enough for
DuckDB `EXCEPT ALL` comparisons. `fold_757_parity.csv` records equality for
the normalized `runs` row, completion, 383,042 diagnostics, zero ledger
events, 757 equity rows, and 757 strategy-state rows. Both runs completed and
both observed the selected arm. This is direct fold-output evidence rather
than an inference from provider-view parity.

## Section 7 actions

1. **Rerun and diff.** The independent checker completed in 900.1 seconds
   under R 4.5.2 and collapse 2.1.8. It regenerated all five deterministic
   CSVs byte-for-byte and passed all 54 checks. Two earlier invocations ended
   before semantic execution because the sandboxed R process could not read
   Git's safe-directory configuration; setting `GIT_CONFIG_GLOBAL` to the
   existing user Git configuration resolved that review-environment issue.
2. **Gut optional accounting.** In an isolated evidence copy I changed the
   prepared optional-test row to claim neither execution nor skipping. The
   checker rejected the optional-test claim and revoked GREEN.
3. **Gut persisted parity.** In a second isolated copy I introduced one
   current-only diagnostic row into `fold_757_parity.csv`. The checker
   rejected persisted parity and revoked GREEN.
4. **Inspect the measurements.** The corrected round did not alter provider
   implementations or performance evidence. Prepared fold wall remains a
   102.58-second median, measured peaks remain 815.7/866.5/838.7 MiB, and the
   eventful provider-only pass remains 0.28 seconds. Diagnostics is now the
   largest profiled lane at 85.3%; provider resolution is 0.26%.
5. **Containment.** The checker accepts only the small provider-build seam,
   the added prepared implementation and RFC artifacts, and the separately
   identified pre-existing planning edits. Review scratch stores were removed
   after the gut tests. `git diff --check` is clean and the index is empty.

## Low observation

The 757-pulse `runs` comparison excludes `archived_at_utc` in addition to the
documented local run ID, creation time, and config store locators. Both fresh
DONE runs are unarchived, so this cannot change the present result. If the seam
is promoted, the production parity test should compare that field or explain
why archive metadata is outside run identity rather than silently excluding
it.

## Handoff

The spike provides strong evidence for carrying prepared availability facts
into synthesis. The approximately 103-second warm fold is still dominated by
diagnostic construction and append work, so the RFC needs the next bounded
diagnostic question before synthesis can claim the optimization arc is
complete. Preserve the separate package finding that reopening an
interrupted-then-resumed INCOMPLETE run fails terminal-evidence validation in
both arms.

PROVIDER_SPIKE_EVIDENCE_RE_REVIEW_DISPOSITION: PASS_WITH_LOW_OBSERVATION
