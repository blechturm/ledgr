# Availability Hot-Path Representation - Diagnostic Block Charter v2 Review

**Status:** Second and final pre-execution structural review.
**Reviewer:** Codex; not the Charter author or prospective spike executor.

## Reviewed source state

- Branch `v0.2.0.1`; HEAD
  `b0fe6b8fb8c44981ad9fc6f8692ce076be72e764`.
- Charter v2 is a new historical successor. Charter v1 and Review v1 remain
  present and unchanged.
- Charter v2 is exactly 150 lines, ASCII-only, LF-terminated, has one question
  mark, two arms, and one kill/recharter clause. It passes
  `git diff --no-index --check`.
- The v1-to-v2 diff contains only the four requested corrections, the disclosed
  exception-row clarification, and budget-preserving trims. No spike code or
  comparative evidence was executed in this review.

## Verdict

**PASS_WITH_LOW_OBSERVATIONS. Spike execution is unlocked.** Charter v2 closes
all four first-round findings without changing the product contract, adding an
arm, or weakening the evidence boundary. It is the operative execution
authority for this spike.

## Review v1 findings

| Finding | Result | Deciding evidence |
| --- | --- | --- |
| B1: sampled share treated as elapsed wall | CLOSED | Lines 102-108 use the 102.58-second fold and 43.67/0.30-second prerequisite clocks only as an explicitly optimistic substitution. The 60-second threshold is now an aggressive near-floor decision boundary with no noise allowance; profiler shares license no forecast. |
| M1: under-specified run identity | CLOSED | Lines 83-87 and 115-117 require separate copied stores, one shared run ID, and exactly three exclusions: top-level creation time and two embedded store locators. Both run-ID locations and `archived_at_utc` are compared; extra normalization is forbidden. |
| M2: global `setv()` trace | CLOSED | Lines 92-95 attribute calls by stack and let only calls originating in the diagnostic block path decide the arm. Existing package calls are separated, while character/list writes remain forbidden in the new path. |
| L1: categories mislabeled as stages | CLOSED | Lines 72-77 bind actual `stage`, `outcome`, `reason_code`, and `runs.status` values rather than inventing stage tokens. |

## Final structural review

- **Question and prerequisite:** PASS. One representation question follows the
  executed `PULSE_BLOCK_REQUIRED` prerequisite; the micro-probe remains a
  mechanism floor rather than full-fold evidence.
- **Runnable fork:** PASS. One fold-side seam selects the current scalar append
  or one typed pulse block. The existing prepared provider, bounded chunk
  writer, transaction owner, persistence schema, sequence assignment, and
  public readers remain fixed.
- **Two arms and one kill condition:** PASS. Semantic failure is RED; a valid
  alternative breaching any wall, relative-spread, or memory component closes
  and recharters; inseparable measurement is INCONCLUSIVE. The profile chooses
  only the next lane, not whether the condition fires.
- **Semantic reach:** PASS. Exact rows and types, sequence, bounded flushes,
  decision/restriction/risk/execution/reconciliation/error evidence,
  interruption, resume, rollback, completion, reopen, explanation, and
  persisted full-population parity are all falsifiable.
- **Identity comparison:** PASS. The shared-ID pair makes top-level and embedded
  IDs directly comparable, excludes only unavoidable local timestamps and
  store locators, and carries forward the prior review's requirement to compare
  archive metadata.
- **Mechanism attestation:** PASS. Mode stamps and constructor counts reject a
  silent fallback before value equality can pass. The bounded post-rollback
  one-row constructor is correctly outside the per-pulse block mechanism and
  outside both traced constructor counts.
- **Measurement:** PASS. Each arm gets a warm-up and three measured 757-pulse
  folds on copied sealed stores, with raw values and medians, external working
  set sampling, and one separately profiled alternative. Cold sealing is
  reported but excluded from the declared reusable-snapshot warm clock.
- **Protocol and containment:** PASS. Ten evidence categories, at most ten
  failure-derived cases, exactly runner/checker/inventory, a 1,500-line R
  budget, a 500-line correction stop, one required gut, and no provenance
  machinery or public benchmark claim.

## Low observations for execution

### L1 - Retain the opening-halt no-fill in recorded semantic coverage

Charter v1 named a halted-at-opening no-fill; v2 maps the taxonomy correctly
but no longer names `trading_halted` as an execution `no_fill` token. This does
not require another Charter round because the mandatory
`test-availability-economics.R` regression net already asserts the exact
execution diagnostic, including ordered combination with
`execution_bar_missing`. Record that test's actual alternative-arm outcome and,
if the semantic fixture produces it, include the token in the coverage CSV. Do
not manufacture a literal row solely to satisfy the inventory.

### L2 - Freeze the relative-spread calculation before timing

The prior provider evidence used `diff(range(raw_wall_seconds))` for run-to-run
spread. Use that same formula in the runner and checker before the first
measurement, emit the three raw current walls, and let the checker recompute it.
This removes the remaining discretion in the relative wall criterion without
changing the registered 60-second envelope.

## Decision

Charter v2 is ready for execution. Preserve both Charter versions and both
structural reviews. The executor may implement the smallest diagnostic-block
fork, let failures generate no more than ten cases, run the registered protocol,
and produce only the runner, checker, inventory, and evidence CSVs.

After execution, Codex performs the independent Section 7 evidence review:
rerun, gut one path, and diff the evidence. No production adoption, synthesis,
RFC-index change, commit, push, release placement, or public performance claim
is authorized by this review.

CHARTER_REVIEW_DISPOSITION: READY_FOR_EXECUTION
