# Post-v0.2.0.1 Test-Suite Audit

**Date:** 2026-09-21

**Branch:** `v0.2.0.2`

**Measured code baseline:** `9f26164`

**Audit closeout baseline:** `df8741f`

The two intervening commits changed only `AGENTS.md`, the roadmap, and the RFC
index. `R/`, `src/`, and `tests/` are identical across the two baselines.

The attached block inventory is
`post_v0_2_0_1_test_suite_audit_blocks.csv`. It is the controlling audit
table. Each of its 930 rows records measured time, the dominant oracle, the
claim or defect protected, the condition that would make the block fail, the
nearest description-level overlap, a proposed lane and disposition, CRAN
constraints, and mutation evidence. An overlap suggested by description
similarity is a merge candidate, not proof that two tests are equivalent.

## Answer

The suite protects a large amount of real behavior, but it makes every kind of
evidence pay the same invocation cost. The correct cleanup is not to make the
suite less strict. It is to stop running review evidence, stress protocols,
historical prose locks, and full workflow witnesses on every ordinary check.

The proposed fast developer and CRAN lane contains 461 blocks from 105 files,
2,825 executed expectations, and all eleven claim families in the inventory.
Those blocks consumed 70.80 seconds in the full run. This is below the
90-second ceiling with 19.20 seconds of measured headroom. It is a candidate
lane, not yet an implemented or independently timed runner.

The proposed review lane contains 277 blocks and consumed 329.20 seconds. The
separately invoked heavy-protocol lane contains 192 blocks and consumed 548.02
seconds. No detecting evidence is proposed for deletion merely because it is
slow.

## Measurement And Counting

The full run used R 4.6.1 on Windows x86-64, testthat 3.3.2, DuckDB 1.5.2,
and collapse 2.1.8. A custom testthat reporter timed every `test_that()` block
while allowing the run to continue after a failure.

| Measure | Result |
| --- | ---: |
| Test files | 134 |
| Physical lines in those files | 40,067 |
| `test_that()` blocks | 930 |
| Full-run wall time | 951.73 s |
| Sum of attributed block times | 948.02 s |
| Runtime expectation results | 9,720 |
| Direct expectation calls inside blocks | 6,601 |
| Lexical expectation calls in test files, including helpers | 6,644 |
| Failures / warnings / skips | 23 / 0 / 1 |

The three assertion totals are deliberately separate. An expectation inside a
loop is one source call and many runtime results; an expectation in a helper
can be outside a `test_that()` expression. The pre-audit figure of 6,338 did
not reproduce under any of these defined units.

Two supplied census claims do reproduce exactly: there are zero
`skip_on_cran()` calls, and the 1,662 lexical `expect_match()` calls are within
25 of the 1,687 `expect_identical()` calls.

The other supplied categories were useful hypotheses but not safe deletion
units. At block granularity:

- `test-documentation-contracts.R` has 75 blocks, 2,513 runtime expectations,
  and 4.69 seconds of file time. Its burden is drift, not runtime.
- Fifteen blocks primarily pin implementation source shape. They produced 87
  runtime expectations, not 2,443. Blocks which happen to contain a source
  hash often also test a real identity contract; counting their whole file as
  source-shape evidence conflates the two.
- No block contains only `expect_silent()`, `expect_no_error()`, or
  `expect_no_warning()`. Eighteen blocks contain one of those expectations,
  but every one also has a more discriminating oracle. The proposed 584
  run-only assertions therefore cannot support a deletion proposal.
- A block-level full-stack heuristic, requiring snapshot construction and a
  product execution call in the same block, finds 183 blocks in 53 files,
  1,473 executed expectations, and 379.74 seconds. This does not reproduce the
  file-level 42-file / 3,702-assertion claim because helpers and mixed blocks
  make file-level attribution non-local. The attached table supplies the
  reviewable boundary instead.

The slowness is broad rather than one pathological tail. The slowest 30 blocks
consume 250.01 seconds, only 26.4% of attributed time. The slowest 160 consume
614.52 seconds, or 64.8%. Shrinking repeated setup and routing evidence to
lanes matters more than deleting a few conspicuous tests.

## What Failed In The Audit Run

The permissive timing run found 23 failures in nine blocks. A focused rerun at
the closeout baseline reproduced all 23.

- `test-availability-fold-witnesses.R:74` has one version-only mismatch:
  current `identity.engine_version` is `0.2.0.2`; the reviewed fixture pins
  `0.2.0.1`. The other persisted surfaces still match. This is a frozen
  witness coupled to a release label rather than an economic regression.
- Eight blocks in `test-documentation-contracts.R` account for the other 22
  failures. They pin v0.1.9.1, v0.1.9.6, v0.1.9.7, v0.2.0.0, v0.2.0.1, or
  post-v0.2.0.1 planning prose that the accepted governance transition has
  changed.

These failures do not show a product defect. They are direct evidence that
version-stamped fixtures and historical prose are unsuitable ordinary-suite
oracles.

The audit also found two cleanup problems that a green assertion count would
miss:

- The blocks at `test-plot.R:1`, `test-plot.R:20`,
  `test-integration-full.R:1`, and `test-run-store.R:199` exercise graphics
  without an explicitly temporary device. In a writable working directory,
  focused runs leave `tests/testthat/Rplots.pdf`; the audit removed that
  generated file. A focused rerun of the run-store block in a read-only working
  directory instead failed at `grid.newpage()` because it could not open that
  file. This is a real non-temporary-write dependency, not housekeeping only.
- Fresh-process runs of `test-walk-forward-orchestrator.R` and
  `test-backtest-audit-log-equivalence.R` passed, but process exit emitted an
  auto-checkpoint/finalizer advisory for a durable walk-forward run. Running
  the failure and interrupt blocks separately did not reproduce it, so the
  owning block is not attributed speculatively. The cleanup ticket must first
  localize it.

The cadence-warning block at
`test-walk-forward-orchestrator.R:163` still muffles every warning after
recording only the expected class. Its pass and the full run's zero-warning
count therefore do not prove that unexpected warnings are absent.

## Oracle Findings

The dominant-oracle classification is a routing aid, not a claim that a block
contains only one assertion style.

| Dominant oracle | Blocks | Time (s) | Interpretation |
| --- | ---: | ---: | --- |
| Behavioral assertion | 357 | 327.81 | Usually valid; expensive cases repeat setup |
| Negative witness | 353 | 330.84 | Strong when the rejected defect is explicit |
| Persistence/state invariant | 63 | 130.17 | Expensive but user-visible and generally valuable |
| Cross-path parity | 41 | 122.24 | Essential where implementations can diverge |
| Independent calculation | 22 | 28.33 | High-value economic/methodological evidence |
| External reference | 4 | 3.13 | Useful optional corroboration |
| Documentation surface pin | 49 | 2.62 | Merge around public journeys |
| Governance text pin | 26 | 1.83 | Replace, then delete historical sentence locks |
| Source-shape pin | 15 | 1.05 | Replace with behavior or explicit reachability guards |

The table proposes 588 blocks unchanged, 134 fixture reductions, 35 lane-only
moves, 126 merges, 21 oracle repairs, and 26 deletions after replacement.
Those are ticket inputs, not edits authorized by this audit.

## Lanes Derived From The Table

### Fast developer and CRAN lane

The candidate is every unconstrained substantive block measured at 0.80
seconds or less, plus the cheapest representative required to keep each claim
family present. It totals 70.80 seconds. It excludes prose pins, source-shape
guards, known graphics leakage, optional-dependency blocks, and subprocess or
parallel-backend blocks.

No test currently calls `skip_on_cran()`, so this lane does not exist in the
package today. Its first implementation run must prove the whole lane under 90
seconds in a clean process; the sum of timings is not a substitute for that
gate.

No network call was found in the test sources. Fifty-one blocks depend on an
optional package or an isolated missing-package condition. Twelve exercise a
subprocess or optional parallel backend. The four graphics blocks named above
write outside a temporary device. All are identified row by row in the CSV.

The sole skip was `test-snapshot-adapters.R:236`: because quantmod is installed,
the missing-quantmod error path was not exercised. It needs an isolated library
in the review lane. No DuckDB teardown error or warning occurred, but the
walk-forward finalizer advisory prevents a clean-teardown claim.

### Review lane

The review lane is the ordinary pre-merge evidence for changed behavior. It
contains slower contract tests, persistence witnesses, public documentation
checks, optional-package parity, and source/reachability guards until their
oracles are repaired. Its measured total is 329.20 seconds.

The **canonical-R differential overlay** is a named subset of this testing
architecture. Its owner is the maintainer accepting a compiled-accounting
change. It must invoke at least:

- `test-execution-spec.R:490`, compiled output versus canonical R fold;
- `test-execution-spec.R:542`, multi-instrument batch parity; and
- `test-sweep-persistence-parity.R:209`, persisted reconstruction parity.

The first two are also cheap enough for the fast lane. The third remains a
heavy witness. Canonical R therefore remains runnable and authoritative without
requiring every compiled-path scenario in every developer run.

### Heavy protocol lane

The heavy lane contains the 2,000-case randomized validator proof, forced-GC
write-barrier evidence, full persisted-surface witnesses, expensive metric
oracles, parallel/fresh-process checks, and full workflow parity. It totals
548.02 seconds and is invoked separately by the named protocol owner. Moving a
block here does not weaken or delete its detecting evidence.

## Mutation And Prior-Audit Results

The prior audit's layered-oracle conclusion is confirmed. It was wrong only
where later work has already closed a gap:

- T-1 is closed by `test-accounting-consistency.R:52`; reversal fees conserve
  source economics in both directions.
- T-2 is closed by `test-features.R:402`. The block proves a causal control,
  catches a leaking series, and then substitutes a no-op checker and observes
  the witness fail.
- T-3's then-latent risk metadata concern is covered by the current persistence,
  reconstruction, stripped-attribute, and promotion cases in
  `test-sweep-persistence-roundtrip.R:300-496`.
- T-4 is only partly closed. Explicit cleanup was added to the named files, but
  the cadence handler still hides unrelated warnings; the isolated run also
  exposed the finalizer advisory and graphics leakage described above.
- T-5 is confirmed more strongly: the documentation file is cheap but produced
  22 failures from accepted wording and status changes.

All six probes left open by the prior audit now have measured dispositions:

| Probe | Current result |
| --- | --- |
| Disabled no-lookahead checker | Detecting mutation is embedded and passed at `test-features.R:402` |
| Caller RNG | Present and absent `.Random.seed` plus next draw pass at `test-rng.R:33` |
| `ts_utc` wide name / thresholds | Reserved-name round trip passes at `test-sweep-retention.R:575`; the old threshold API was removed and the reader is now locked as one-argument eager |
| Future-data perturbation | Earlier decision state stays identical while hashes differ at `test-availability-causality.R:76` |
| Interrupted persistence | Resume and rollback witnesses pass, including `test-availability-economics.R:816` and `:870` |
| Cleanup | Isolated files pass, but the finalizer advisory, unconditional warning muffling, and `Rplots.pdf` leak remain findings |

The randomized validator block is a second strong mutation-style oracle: 2,000
generated cases compare the optimized sweep against the retained pairwise
reference. The current stale-version witness also demonstrates the opposite
lesson: a test can be highly sensitive while detecting the wrong change.

## Proposed Tickets

These are proposals only. No test is changed by this audit.

1. **DELETE-01 - retire historical governance prose pins after replacement.**
   Replace the 26 blocks with one current-state artifact consistency check and
   link/path validation. Then delete sentence-level assertions about completed
   historical packet states. Historical Git objects remain the history.
2. **MERGE-01 - consolidate duplicated public-surface and cheap behavior
   assertions.** Review the 126 candidates, beginning with the 49 documentation
   surface blocks. Preserve executable public journeys and class/API promises;
   merge only after the claimed overlap is demonstrated, not from the CSV's
   description score alone.
3. **MOVE-01 - implement the three lane manifests and CRAN runner.** Route the
   35 explicit lane-only candidates and the other table-assigned blocks. Prove
   the 461-block fast/CRAN lane below 90 seconds in a clean process. Give the
   canonical-R differential overlay and every heavy protocol an owner and an
   invocation point.
4. **SHRINK-01 - reduce repeated full-stack fixtures without shared mutable
   databases.** Start with the 134 candidates, especially sweep parity,
   experiment run, walk-forward orchestration, parallel sweep, and backtest
   wrapper. Keep the same failure condition and independent oracle; reduce rows,
   pulses, candidates, or duplicate setup only.
5. **ORACLE-01 - repair the 21 weak or misleading oracles.** Remove the engine
   version from the availability economic witness or compare it separately;
   stop muffling unrelated warnings; use temporary graphics devices; localize
   the walk-forward finalizer; replace fifteen source-shape pins with behavior,
   mutation, or narrow reachability evidence. Keep source checks only where the
   architecture itself is the explicit contract.

The order is ORACLE-01, MOVE-01, SHRINK-01, MERGE-01, DELETE-01. This prevents
the lane split or deletions from laundering already-red oracles.

## Rule Against Regrowth

A new test must name, before it is added: the user-visible contract or past
defect it protects; an oracle independent of the production calculation where
practical; the smallest deliberate change that makes the assertion fail; the
cheapest lane that can carry it; and the existing block, if any, that already
protects the claim. A full snapshot/run/sweep fixture needs an explicit reason
that a smaller layer cannot expose the defect. If no claim or defect can be
named, do not add the test. If the evidence is a benchmark, stress proof,
historical record, or source-architecture guard, route it to review or a named
heavy protocol instead of the fast/CRAN lane.

This rule addresses how the suite grew: release packets added prose locks,
integration fixtures became the easiest universal setup, and review evidence
was promoted into an always-on test without deciding who needed it or when.
The answer is explicit ownership and routing, not weaker assertions.

## Containment

The audit ran tests and read source. It did not edit, delete, or refactor any
test, package code, specification, or governance document. The generated
`Rplots.pdf` was removed. The pre-existing modifications to `DESCRIPTION` and
`NEWS.md`, the untracked `dev/spikes/asset_availability_pit/` directory, and
the two untracked `src/*.gcda` files are unrelated and excluded from this
audit commit.
