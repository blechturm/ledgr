# ledgr v0.2.0.0 Tickets

Version: v0.2.0.0
Date: 2026-09-09
Total Tickets: 32

## Ticket Organization

v0.2.0.0 first corrects and extracts the existing API/run coordinator, then
implements the first point-in-time asset-availability path on the shared fold.
The maintainer accepted the spec and its explicit quarantine and active
short-exposure amendments on 2026-09-09.

Ticket IDs begin at LDG-2672 after the v0.1.9.7 packet.

The release spine is:

```text
LDG-2672 packet alignment
  -> LDG-2673..2676 hardening corrections
  -> LDG-2677..2678 inspection and workflow
  -> LDG-2679..2680 ownership split and coordinator stages 1-2
  -> LDG-2681..2684 failure and boundary corrections
  -> LDG-2685..2686 coordinator stages 3-4
  -> LDG-2687..2689 facts, calendar, schema, hash, quarantine
  -> LDG-2690..2692 activation, provider, state, strict features
  -> LDG-2693..2696 shared-fold economics and controlled stops
  -> LDG-2697..2700 terminal and cross-path evidence
  -> LDG-2701..2702 teaching and release surfaces
  -> LDG-2703 release gate
```

Ticket dependencies are the hard readiness gate. Batch order is the default
review sequence. Coordinator stages remain separate bounded commits, and the
Batch 8 and Batch 9 independent review stops are mandatory.

## Priority Levels

- P0: release-blocking correctness, identity, persistence, or execution work.
- P1: required public API, workflow, documentation, or maintainability work.
- P2: optional polish that may defer without changing the release contract.

## Dependency DAG

```text
2672 -> {2673,2674,2675,2676}
{2673,2674,2675,2676} -> {2677,2678}
{2677,2678} -> 2679 -> 2680
2680 -> {2681,2682,2683}; {2682,2683} -> 2684
{2681,2682,2683,2684} -> 2685 -> 2686
2686 -> {2687,2688}; {2687,2688} -> 2689
2689 -> 2690 -> 2691 -> 2692
2692 -> {2693,2694}; {2693,2694} -> 2695
{2693,2694,2695} -> 2696 -> 2697 -> 2698 -> 2699
{2697,2698,2699} -> 2700 -> 2701 -> 2702 -> 2703
```

## Gate Ownership

| Gates | Owning tickets |
| --- | --- |
| H1 | LDG-2673 |
| H2 | LDG-2673 |
| H3 | LDG-2674 |
| H4 | LDG-2675 |
| H5 | LDG-2676 |
| H6 | LDG-2677 |
| H7 | LDG-2678, LDG-2683 |
| H8 | LDG-2678, LDG-2701 |
| H9 | LDG-2682 |
| H10 | LDG-2683, LDG-2684 |
| H11 | LDG-2679, LDG-2680, LDG-2685, LDG-2686 |
| H12 | LDG-2681, retained by LDG-2685 and LDG-2686 |
| U1 | LDG-2700 |
| U2 | LDG-2691, LDG-2692 |
| U3 | LDG-2692 |
| U4 | LDG-2690, LDG-2691, LDG-2700 |
| U5 | LDG-2693 |
| U6 | LDG-2691 |
| U7 | LDG-2694 |
| U8 | LDG-2693 |
| U9 | LDG-2698, LDG-2699 |
| U10 | LDG-2689, LDG-2691 |
| U11 | LDG-2698, LDG-2699, LDG-2700 |
| U12 | LDG-2700, LDG-2701 |
| U13 | LDG-2695 |
| U14 | LDG-2687 |
| U15 | LDG-2687 |
| U16 | LDG-2687, LDG-2689 |
| U17 | LDG-2693 |
| U18 | LDG-2695 |
| U19 | LDG-2694, LDG-2696, LDG-2697 |
| U20 | LDG-2690, LDG-2693 |
| U21 | LDG-2687, LDG-2694 |
| U22 | LDG-2696, LDG-2697 |
| U23 | LDG-2691, LDG-2699 |
| U24 | LDG-2688, LDG-2692, LDG-2694 |
| First-review short/quarantine/exception/idempotency/exposure rows | LDG-2693/2695, LDG-2689, LDG-2681/2696, LDG-2697, LDG-2694/2696 |

## LDG-2672 - Packet Alignment And Ticket Cut

Priority: P0
Effort: M
Dependencies: None
Status: Complete After Review

### Description

Accept the reviewed v0.2.0.0 spec, create synchronized execution artifacts,
and promote the packet into active governance without claiming implementation.

### Tasks

- Record the maintainer's acceptance of all spec-cut decisions and amendments.
- Allocate LDG-2672 through LDG-2703 and bind the dependency DAG.
- Create packet README, Markdown tickets, YAML tickets, and batch plan.
- Record the ticket-cut baseline: `048b925e5411b7c1a7500d4163163aed72039062`,
  R 4.5.2 ucrt on `x86_64-w64-mingw32`, duckdb 1.4.3, and dplyr 1.1.4.
- Record that no named maintainer-owned store inventory was supplied at cut
  and hand the required pre-edit inventory explicitly to LDG-2684.
- Align design index, roadmap, horizon, RFC index, AGENTS, NEWS, and their
  documentation-contract assertions.
- Apply the two non-blocking final-review wording corrections.

### Acceptance Criteria

- Every spec scope item, H1-H12 gate, U1-U24 gate, and first-review regression
  has a ticket owner.
- Markdown/YAML IDs, status, dependency, and batch mappings agree.
- Active governance points to v0.2.0.0 and v0.1.9.7 is historical.
- Baseline environment evidence and the LDG-2684 store-inventory handoff are
  visible in the packet.
- No runtime behavior, package export, or test result is introduced or claimed.

### Verification

- YAML parse and graph validation.
- Cross-artifact ID/status/dependency comparison.
- Local R/platform/package-version query and store-inventory handoff review.
- Documentation-contract tests.
- `git diff --check` and ASCII scan.

### Implementation Notes

- Packet artifacts and active governance were committed in `fa31c11` after
  independent review accepted the ticket cut.
- A Batch 1 package-check follow-up made the packet documentation-contract test
  skip cleanly when source-only packet files are unavailable from an installed
  package test context; source-tree execution still asserts the full contract.

### Source Reference

- `v0_2_0_0_spec.md` Sections 5-9
- Both accepted RFC syntheses named by the spec

### Classification

```yaml
type: planning
surface: design-packet
scope: packet-alignment
```

## LDG-2673 - Reversal Fee Projection Correction

Priority: P0
Effort: M
Dependencies: LDG-2672
Status: Complete After Review

### Description

Allocate each source fill fee pro rata across its derived CLOSE/OPEN rows while
preserving event-level economics.

### Tasks

- Add independent conservation and unequal-leg allocation assertions first.
- Match derived rows to their source `event_seq` and allocate by absolute
  executed quantity.
- Preserve price, quantity, event order, cash, lot basis, realized PnL, and
  trade metrics.

### Acceptance Criteria

- H1 and H2 pass in both reversal directions.
- Derived fees sum to each independently specified source fee.
- No shorting or financing behavior is inferred from the algebraic fixture.

### Verification

- `test-fifo-torture.R`
- `test-accounting-consistency.R`
- Targeted fills/trades/result regressions

### Implementation Notes

- Added independent two-direction unequal-leg allocation and event-level fee
  conservation assertions before correcting the projection.
- One internal pro-rata helper now supplies derived fees to the durable reader,
  event reconstruction, memory-backed sweep, and compiled spot-FIFO paths.
- Cash, terminal position and basis, realized PnL, and trade metrics retain
  independently asserted values.
- Review follow-up added absolute reversal-fee and event-total assertions for
  memory-backed and reconstructed output on both R and compiled fold paths,
  and bound the projection rule in the Result Contract and NEWS.

### Source Reference

- Spec Section 2.1 and gates H1-H2
- H Section 3, "Fills and fees"

### Classification

```yaml
type: correctness
surface: fills-accounting
scope: pro-rata-reversal-fees
```

## LDG-2674 - Eager Fills API Simplification

Priority: P1
Effort: M
Dependencies: LDG-2672
Status: Complete After Review

### Description

Make `ledgr_run_fills(bt)` an eager, schema-stable reader and remove the cursor,
`lazy`, and `stream_threshold` surface without aliases.

### Tasks

- Add the populated/empty H3 assertions before removing code.
- Remove cursor classes, methods, threshold switching, and old arguments.
- Return the existing full-schema tibble for empty and populated runs.
- Update generated help, NAMESPACE/S3 registrations, and callers.

### Acceptance Criteria

- The public function has exactly the `bt` formal.
- Removed arguments fail through ordinary argument matching before reads.
- Return type no longer depends on result size.

### Verification

- `test-fills-streaming.R`
- API export/S3 review
- `tools::checkRd()`

### Implementation Notes

- Reduced the public API to the single `bt` formal and removed cursor,
  threshold-switching, and lazy-result code without aliases.
- Empty, populated, borrowed-connection, and 220-row reads now return the same
  eager full-schema tibble shape; removed arguments fail before reads.
- Updated generated help, README source/render, and the experiment-store
  vignette source/render to remove the deleted cursor contract.
- Source build without vignette rebuilding and installed-package check pass;
  the check reports only the existing vignette-output warnings and long-path
  note.
- Review follow-up bound the one-formal eager-reader contract and recorded the
  user-facing removal in NEWS.

### Source Reference

- Spec Section 2.1 and gate H3
- H Section 3, "Fills and fees"

### Classification

```yaml
type: api
surface: run-fills
scope: eager-reader
```

## LDG-2675 - Sweep Review Lineage Correction

Priority: P0
Effort: M
Dependencies: LDG-2672
Status: Complete After Review

### Description

Restore sweep/candidate provenance on `review$ranked` so explicit candidate
extraction and promotion retain source lineage.

### Tasks

- Add the reopened nondefault-risk review-to-promotion regression first.
- Restore the `ledgr_sweep_results` class and applicable parent metadata on
  `ranked` without mutating the input artifact.
- Preserve explicit ranking order and issue reporting.
- Keep `top` presentation-only and reject candidate use without its payload.

### Acceptance Criteria

- H4 preserves sweep ID, candidate identity, risk identity, and selection order.
- Plain compatible tables receive no invented parent lineage.
- No automatic selection or promotion is introduced.

### Verification

- `test-promotion-context.R`
- Targeted sweep-review/candidate/promotion tests

### Implementation Notes

- Restored `review$ranked` from classed sweep inputs at the existing sweep-view
  restoration boundary while leaving compatible plain tables unclassed.
- Added a reopened nondefault-risk review-to-promotion journey that asserts
  source sweep ID, candidate identity, risk identity, ranking order, unchanged
  input bytes, and rejection of candidate extraction from `top`.
- Review follow-up made `review$top` explicitly lineage-free and added
  detecting assertions for its source and risk attributes.

### Source Reference

- Spec Section 2.1 and gate H4
- H Section 3, "Review lineage"

### Classification

```yaml
type: correctness
surface: sweep-review
scope: ranked-lineage
```

## LDG-2676 - Sweep Risk Restoration Correction

Priority: P0
Effort: S
Dependencies: LDG-2672
Status: Complete After Review

### Description

Restore both risk provenance fields explicitly when retained/saved sweep views
are reconstructed or subset.

### Tasks

- Add a fixture that removes output-side risk attributes before restoration.
- Restore risk hash and plan fields at the owning boundary.
- Verify base `[` subsetting and downstream candidate identity without a
  package-dependent skip.

### Acceptance Criteria

- H5 detects either omitted field.
- Historical absence remains unknown rather than a fabricated no-op plan.
- Persistence and candidate identity are unchanged except for corrected
  restoration.

### Verification

- `test-sweep-persistence-roundtrip.R`
- Reopened-sweep and candidate identity tests

### Implementation Notes

- Added `risk_chain_hash` and `risk_plan_json` to explicit sweep-result
  restoration.
- The detecting fixture strips both output-side attributes before restoration,
  then checks direct restoration, base and dplyr subsets, reopened evidence,
  and downstream candidate metadata under a nondefault risk chain.
- Review follow-up bound present and historically absent risk provenance in the
  Result Contract.

### Source Reference

- Spec Section 2.1 and gate H5
- H Section 6, T-3

### Classification

```yaml
type: correctness
surface: sweep-persistence
scope: risk-provenance-restoration
```

## LDG-2677 - Recorded Run Risk Identity Inspection

Priority: P1
Effort: S
Dependencies: LDG-2673, LDG-2674, LDG-2675, LDG-2676
Status: Complete After Review

### Description

Expose the committed run's `risk_chain_hash` through `ledgr_run_info()` without
adding another reader or writing during inspection.

### Tasks

- Read the field from committed run/config identity.
- Cover direct, promoted, no-op, and legacy-absence cases.
- Keep `risk_plan_json` and current-experiment substitutions out of the reader.

### Acceptance Criteria

- H6 matches the recorded hash for direct and promoted runs.
- Legacy absence returns `NA_character_`.
- Inspection writes no persistent row and executes no recovered strategy.

### Verification

- `test-runner.R`
- Fresh-connection read-only full-table-content check
- `tools::checkRd()`

### Implementation Notes

- Added a read-time `risk_chain_hash` projection from the committed run config
  to `ledgr_run_info()` and its curated print surface.
- H6 covers direct, promoted, no-op, and historical-absence records, verifies
  no top-level plan field is added, and checks fresh-connection table contents
  and strategy calls across inspection.

### Source Reference

- Spec Section 2.1 and gate H6
- H Section 3, "Run risk identity"

### Classification

```yaml
type: api
surface: run-info
scope: risk-chain-hash
```

## LDG-2678 - Durable Run-Handle Lifecycle And Workflow Teaching

Priority: P1
Effort: M
Dependencies: LDG-2673, LDG-2674, LDG-2675, LDG-2676
Status: Complete After Review

### Description

Lock the run handle as a durable locator, teach names-preserving target access,
and repair the public review/promotion/new-session workflow.

### Tasks

- Test explicit close, later reads, owned-resource cleanup, and new-session
  opening without persistent writes.
- Teach `target[[id]]` and `c(target)`; do not add `ledgr_target_values()`.
- Teach candidate extraction from `review$ranked`, not `top`.
- Verify and repair only concrete stale examples and useful doc locks.

### Acceptance Criteria

- H7-H8 pass through public APIs and documented fields.
- `close(bt)` releases resources but not durable evidence or locator identity.
- New-session inspection executes no strategy and recomputes no fills.

### Verification

- `test-backtest-lifecycle.R`
- `test-documentation-contracts.R`
- `tools/check-readme-example.R`
- Affected vignette/example checks

### Implementation Notes

- H7 now treats `ledgr_backtest` as a stable `run_id` plus `db_path` locator:
  explicit close releases owned resources while later reads and a fresh
  snapshot/run reopen return unchanged evidence without writes or strategy
  execution.
- README source/render and the installed-package checker execute ordinary
  target access, ranked-review candidate extraction, explicit promotion, and
  new-session reopen. The strategy-authoring surface and target help use the
  same names-preserving vector operations.
- Review follow-up strengthened the no-write check to compare complete ordered
  table contents, prints the extracted target vector in the vignette, and
  locks the complete `target[[id]]` expression in the documentation contract.

### Source Reference

- Spec Sections 2.1 and 4; gates H7-H8
- H Sections 3-4

### Classification

```yaml
type: documentation
surface: run-workflow
scope: locator-and-target-teaching
```

## LDG-2679 - Mechanical Backtest Ownership Split

Priority: P0
Effort: L
Dependencies: LDG-2677, LDG-2678
Status: Complete After Review

### Description

Split `R/backtest.R` along accepted config, handle, fills, and result ownership
without changing behavior, formals, effects, or public names.

### Tasks

- Move exact bodies into `backtest-config.R`, `backtest-handle.R`,
  `backtest-fills.R`, and `backtest-results.R` in bounded commits.
- Keep public construction/orchestration thin.
- Review NAMESPACE/S3/source-order consequences after every move.
- Do not split `R/sweep.R`, modularize `R/fold-engine.R`, or introduce a file
  registry.

### Acceptance Criteria

- H11 passes after every mechanical move.
- Function bodies/formals and observable effects are unchanged.
- No correction is hidden inside the move.

### Verification

- Full local suite after each commit
- API/S3/NAMESPACE comparison
- `git diff --check`

### Implementation Notes

- Moved the config, handle, fills, and result ownership groups into the four
  accepted files while leaving public construction and orchestration in
  `R/backtest.R`.
- Parsed-expression comparison against the pre-batch `R/backtest.R` confirms
  all 56 relocated assignments are unchanged. `ledgr_run_config()` is the sole
  deliberate caller change required by LDG-2680.
- H11 passed after the ownership move. NAMESPACE, DESCRIPTION, public exports,
  S3 registrations, and generated Rd files are unchanged.
- Review follow-up corrected the relocation count, removed inherited trailing
  whitespace from the moved result source, and updated the manual's obsolete
  wrapper call path without expanding into its LDG-2702 line-anchor audit.

### Source Reference

- Spec Sections 2.1 and 3; gate H11
- H Section 5 module boundaries

### Classification

```yaml
type: refactor
surface: backtest-modules
scope: ownership-split
```

## LDG-2680 - Coordinator Stages 1 And 2 Extraction

Priority: P0
Effort: L
Dependencies: LDG-2679
Status: Complete After Review

### Description

Extract preparation/config/control and snapshot guard/hash/calendar records as
the first two coordinator stages without rescheduling effects.

### Tasks

- Delete the two internal backtest-run wrappers and retarget callers.
- Extract stage 1 with explicit inputs/outputs; leave `set.seed()`, clock, and
  RUNNING writes at their existing call sites.
- Extract stage 2 without hoisting calendar work or weakening snapshot guards.
- Commit and verify each stage separately.

### Acceptance Criteria

- H11 passes after each stage.
- Store cleanup remains coordinator-scoped and handlers remain available where
  resume requires them.
- No shared mutable coordinator environment or second execution path appears.

### Verification

- Full local suite after each stage
- `test-runner.R`
- `test-runner-snapshots.R`
- `test-acceptance-v0.1.1.R`

### Implementation Notes

- Deleted `ledgr_backtest_run()` and `ledgr_backtest_run_internal()` and
  retargeted package and test callers without changing the public entry point.
- Stage 1 returns named config, engine, control, and telemetry records from
  `R/run-prepare.R`; clock, seed, RUNNING status, and telemetry-validation
  effects remain at their prior coordinator positions.
- Stage 2 returns the verified snapshot hash and pulse calendar from
  `R/run-snapshot.R`; guard and TEMP-view work stays after handler creation,
  and calendar work stays after strategy preflight.
- Coordinator-owned cleanup and explicit connection/handler dependencies are
  unchanged. Focused runner, snapshot, API, wrapper, experiment, and acceptance
  tests pass, and H11 passed after each stage.

### Source Reference

- Spec Sections 2.1, 3, and 5; gate H11
- H Section 5 stages 1-2

### Classification

```yaml
type: refactor
surface: run-coordinator
scope: prepare-and-snapshot-stages
```

## LDG-2681 - Finalization Failure And Recovery Correction

Priority: P0
Effort: L
Dependencies: LDG-2680
Status: Complete After Review

### Description

Add the real post-fold failure fixture and correct finalization failure to
record FAILED while preserving committed fold/features for clean recovery.

### Tasks

- Inject once after the feature transaction and before equity/DONE using the
  specified transaction-expression seam.
- Record FAILED and the original error without masking it.
- Preserve committed fold/state/features and resume the same identity without
  duplicate events or rows.
- Keep fold transaction, partial-run, seed, and status placement unchanged.

### Acceptance Criteria

- H12's three fresh-connection assertions pass.
- The clean and failed-then-resumed stores agree on ordered economic evidence.
- No public fault hook or mocked success path is introduced.

### Verification

- `test-runner.R`
- Existing partial-run/resume tests
- Full local suite before coordinator stages 3-4

### Implementation Notes

- Finalization errors are trapped after the fold boundary, recorded as FAILED
  without masking the original condition, and leave committed fold evidence
  intact.
- The H12 transaction-seam fixture proves fresh-connection failure evidence and
  finalization-only resume equality against a clean run without duplicate rows.
- Review follow-up wraps best-effort FAILED telemetry and injects a telemetry
  failure in H12, proving it cannot replace the original finalization error.

### Source Reference

- Spec Section 2.2 and gate H12
- H Section 6 finalization fixture

### Classification

```yaml
type: correctness
surface: run-finalization
scope: post-fold-failure-recovery
```

## LDG-2682 - Feature Causality Regression Gate

Priority: P0
Effort: M
Dependencies: LDG-2680
Status: Complete After Review

### Description

Turn the existing no-lookahead diagnostic into a detecting causal/leaking
feature regression with a future-only perturbation control.

### Tasks

- Add causal and leaking `series_fn` fixtures.
- Assert the leaking path raises `ledgr_feature_lookahead_detected`.
- Gut the checker in the test harness and prove the negative assertion fails.
- Compare only prefixes whose information sets and execution bars are
  unchanged under future-data perturbation.

### Acceptance Criteria

- H9 detects a disabled or bypassed checker.
- Eligible earlier outputs remain unchanged under future-only perturbation.
- No imputer or claim about arbitrary R-code causality is introduced.

### Verification

- `test-features.R`
- `test-precompute-features.R`
- Targeted cache/fingerprint tests

### Implementation Notes

- H9 now pairs a causal and deliberately leaking `series_fn`, and its gutted
  checker control fails when detection is bypassed.
- A future-only bar perturbation changes snapshot identity and the affected
  feature tail while preserving the eligible earlier prefix.

### Source Reference

- Spec Section 2.1 and gate H9
- H Section 6, T-2

### Classification

```yaml
type: correctness
surface: features
scope: lookahead-detection
```

## LDG-2683 - RNG Lifecycle And Documentation Boundary Hygiene

Priority: P1
Effort: M
Dependencies: LDG-2680
Status: Complete After Review

### Description

Close the scoped RNG, resource-cleanup, warning, and brittle documentation-lock
findings without broad test or CI redesign.

### Tasks

- Preserve caller RNG state and next draw through ingestion and nonempty reads,
  including initially absent `.Random.seed`.
- Add explicit close/cleanup and expected-warning assertions to named fixtures.
- Retain API/schema/disclosure documentation checks and retire only identified
  editorial locks.
- Record any unrelated audit lead as deferred rather than absorbing it.

### Acceptance Criteria

- H7/H10 tests detect RNG or cleanup regressions.
- No generic test framework, registry, or coverage reduction is introduced.
- Installed examples remain executable.

### Verification

- `test-rng.R`
- `test-walk-forward-orchestrator.R`
- `test-backtest-audit-log-equivalence.R`
- `test-backtest-lifecycle.R`
- `test-documentation-contracts.R`

### Implementation Notes

- Snapshot ingestion and nonempty eager fill reads preserve caller RNG state,
  the next draw, and an initially absent `.Random.seed`.
- The named walk-forward and audit-log fixtures close owned resources and the
  audit-log parity fixture muffles only `LEDGR_LAST_BAR_NO_FILL`.
- Only the audited Mermaid-label and historical-roadmap editorial locks were
  removed; API, schema, disclosure, and installed-example locks remain.

### Source Reference

- Spec Section 2.1 and gates H7/H10
- H Section 6, RNG/T-4/T-5 rows

### Classification

```yaml
type: correctness
surface: integration-boundaries
scope: rng-cleanup-doc-locks
```

## LDG-2684 - Reversible Wide-Projection Name Escaping

Priority: P0
Effort: M
Dependencies: LDG-2682, LDG-2683
Status: Complete After Review

### Description

Prevent candidate IDs from colliding with structural wide-table columns while
preserving source-neutral candidate identity.

### Tasks

- Inventory named maintainer-owned stores and affected wide artifacts before
  editing; record compatibility, migration, or explicit non-migration for each.
- Implement Section 2.1's prefix-plus-lowercase-hex UTF-8 escaping and
  intrinsic reverse mapping; do not introduce a persistent mapping registry.
- Protect structural timestamp/value columns from candidate-name overwrite.
- Preserve original IDs in long/matrix views and candidate extraction.
- Apply this last among artifact-shape corrections.

### Acceptance Criteria

- H10 catches a candidate named `ts_utc` and other reserved collisions.
- Wide names map reversibly to unchanged original candidate IDs and values.
- The store/artifact inventory is recorded before the first shape edit, and no
  migration is promised for an unnamed artifact.
- No generic name registry is added.

### Verification

- `test-sweep-retention.R`
- Return-panel projection tests
- Reopened-sweep/candidate identity tests

### Implementation Notes

- The required pre-edit inventory is recorded in
  `wide_projection_store_inventory.md`; no tracked or named maintainer store
  requires migration, and the five ignored benchmark stores contain no sweep
  tables.
- Reserved IDs use the bound prefix plus lowercase UTF-8 hex encoding. Tests
  cover structural `ts_utc`, reserved-prefix, UTF-8, invalid encoding, reopen,
  and unchanged long/matrix/candidate identities without a mapping registry.
- The full 112-file local suite is green with one expected optional
  adapter-path skip, and all 142 Rd files pass `tools::checkRd()`.

### Source Reference

- Spec Section 2.1's bound prefix-plus-hex rule and Section 5; gate H10
- H Section 11 collision question

### Classification

```yaml
type: correctness
surface: sweep-retention
scope: wide-name-collisions
```

## LDG-2685 - Coordinator Stage 3 Finalization Extraction

Priority: P0
Effort: L
Dependencies: LDG-2681, LDG-2682, LDG-2683, LDG-2684
Status: Review Pending

### Description

Extract coordinator finalization, including the second FIFO lot pass and
separate projection/status transactions, after the corrected failure gate.

### Tasks

- Move finalization into `R/run-finalize.R` with explicit records.
- Preserve the second lot pass, transaction boundaries, telemetry ordering,
  and corrected error contract.
- Commit this stage independently before registration/resume extraction.

### Acceptance Criteria

- H11 and H12 pass unchanged after extraction.
- Clean/resumed equality and event sequencing remain intact.
- No fold or feature transaction is moved.

### Verification

- Full local suite
- `test-runner.R`
- `test-acceptance-v0.1.0.R`
- Accounting/fills regressions

### Implementation Notes

- The complete finalization block moved to `R/run-finalize.R` behind explicit
  run, calendar, projection, and fold records. The second FIFO lot pass and
  separate feature and equity/DONE transactions retain their runtime order.
- H12 and the focused runner, acceptance, accounting, FIFO, and fills nets
  pass unchanged. H11 then passed across all 112 local test files with one
  expected optional adapter-path skip before Stage 4 began.

### Source Reference

- Spec Sections 2.1, 2.2, and 3; gates H11-H12
- H Section 5 stage 3

### Classification

```yaml
type: refactor
surface: run-coordinator
scope: finalization-stage
```

## LDG-2686 - Coordinator Stage 4 Registration And Resume Extraction

Priority: P0
Effort: L
Dependencies: LDG-2685
Status: Review Pending

### Description

Extract registration, lookup, identity checks, DONE shortcut, and resume-tail
cleanup without changing runtime order or handler dependencies.

### Tasks

- Create explicit registration/resume helper records.
- Pass the existing handler and store connection explicitly.
- Preserve identity guards, status transitions, tail deletion, opening events,
  and coordinator-owned cleanup.
- Commit stage 4 separately.

### Acceptance Criteria

- H11-H12 and all existing resume/DONE cases pass.
- A returning helper cannot lose connection cleanup.
- No shared mutable environment or new execution entry point is added.

### Verification

- Full local suite
- `test-runner.R`
- `test-runner-snapshots.R`
- Partial-run/clean-resumed acceptance tests

### Implementation Notes

- Registration, lookup, identity checks, insert verification, and the DONE
  shortcut moved to `R/run-registration.R`. Provenance receives the existing
  connection and persistent handler explicitly at its original runtime point.
- Resume preflight, tail cleanup, finalization-only recovery detection, event
  sequencing, and opening events moved to `R/run-resume.R`. The coordinator
  still owns store opening and function-scoped cleanup.
- Focused runner, snapshot, partial/resume, fresh-connection, and metadata nets
  pass. H11 passed across all 112 local test files with one expected optional
  adapter-path skip after extraction.

### Source Reference

- Spec Sections 2.1 and 3; gates H11-H12
- H Section 5 stage 4

### Classification

```yaml
type: refactor
surface: run-coordinator
scope: registration-resume-stage
```

## LDG-2687 - Point-In-Time Fact Constructors And Validation Report

Priority: P0
Effort: L
Dependencies: LDG-2686
Status: Pending

### Description

Implement the classed membership, status, lifetime, session, and fact-bundle
inputs plus a source-aware pre-seal validation report.

### Tasks

- Add the six family/bundle constructors and `ledgr_facts_validate()`.
- Bind half-open effective intervals, knowledge time, provenance, completeness,
  precedence, supersession, and canonical omission.
- Distinguish accepted facts, retained runtime conflicts, rejected facts,
  quarantine candidates, and audit-only facts.
- Keep tied valid status assertions for conservative runtime resolution.

### Acceptance Criteria

- U14-U16 and U21 fact semantics pass.
- Complete omission, partial omission, unknown, conflict, and structural error
  remain distinct.
- Dry-run validation writes nothing and fabricates no evidence.

### Verification

- `test-availability-facts.R`
- Constructor/hash canonicalization tests
- `tools::checkRd()` and export review

### Source Reference

- Spec Sections 2.3-2.4; gates U14-U16/U21
- U Sections 3-4 and 10

### Classification

```yaml
type: feature
surface: availability-facts
scope: constructors-and-validation
```

## LDG-2688 - Complete Session Calendar And EOD Mapping

Priority: P0
Effort: M
Dependencies: LDG-2686
Status: Pending

### Description

Implement a complete, knowledge-bounded venue-session clock independent of
observed bars and map EOD vendor labels explicitly to session closes.

### Tasks

- Validate one open/closed row for every civil date over declared coverage.
- Normalize IANA timezone, opening/closing times, and knowledge requirements.
- Drive decision pulses from open-session closes and execution opportunities
  from the next open-session opening.
- Reject missing/late coverage and never infer holidays or terminal sessions.

### Acceptance Criteria

- U24 retains whole-feed-outage pulses and exposes feature/valuation gaps.
- Bar timestamps never stand in for the expected-session clock in active mode.
- Dense timestamp behavior remains unchanged.

### Verification

- `test-availability-facts.R`
- `test-availability-features.R`
- `test-availability-valuation.R`
- Calendar timezone/coverage fixtures

### Source Reference

- Spec Sections 2.3-2.4; gate U24
- U Sections 3-4 and 10

### Classification

```yaml
type: feature
surface: availability-calendar
scope: expected-session-clock
```

## LDG-2689 - Availability Snapshot Schema Hash And Quarantine

Priority: P0
Effort: L
Dependencies: LDG-2687, LDG-2688
Status: Pending

### Description

Persist fact families and acknowledged invalid-observation quarantine under
transactional schema migration and deterministic snapshot hash rule 2.

### Tasks

- Add normalized fact/quarantine tables, indexes, writers, and validators.
- Implement store schema 113 and saved-sweep schema 4 with marker-last
  transactional migration and legacy read compatibility.
- Preserve exact hash rule 1 for fact-free snapshots; hash all fact headers,
  rows, assumptions, and quarantine evidence under rule 2.
- Keep `invalid_observations = "error"` as default; implement explicit
  dataframe-only quarantine with declared sessions.

### Acceptance Criteria

- Default invalid input creates no SEALED hash.
- Explicit quarantine seals/reopens valid bars and excluded originals, and
  tampering fails verification.
- U10's identity half and U16's retained-conflict/reopen half pass through the
  persisted snapshot path.
- Malformed facts, duplicate valid keys, invalid instrument masters, and empty
  post-exclusion bars still block sealing.
- Existing sealed snapshots are never resealed or hash-migrated.

### Verification

- `test-availability-facts.R`
- `test-schema.R` and `test-schema-snapshots.R`
- `test-schema-validator-side-effects.R`
- `test-persistence-fresh-connection.R`
- U10 identity and U16 conflict/reopen cases
- First-review quarantine fixture

### Source Reference

- Spec Sections 2.4-2.5; gates U10/U16 and quarantine regression row
- U Sections 4.4, 9, and 10.3 as amended

### Classification

```yaml
type: persistence
surface: snapshot-store
scope: facts-hash-quarantine-migration
```

## LDG-2690 - Availability Activation And Public Policy Surface

Priority: P0
Effort: L
Dependencies: LDG-2689
Status: Pending

### Description

Add presence-driven availability activation, public universe/valuation policy
constructors, snapshot fact ingestion, and effective-plan disclosure.

### Tasks

- Add `facts = NULL` snapshot input and the accepted family-first constructors.
- Add `ledgr_universe_members()`, `ledgr_valuation_stale()`, and experiment
  validation with no mode flag or default stale horizon.
- Require complete sessions and valuation policy whenever availability is
  active.
- Expose declared, omitted, assumption-backed, and disabled checks through
  `ledgr_experiment_plan()`.

### Acceptance Criteria

- Canonical omission retains the dense path and payload shape.
- A fixed basket may consume status/session/lifetime facts without becoming a
  membership rule.
- U4/U20 public construction and helper preconditions pass.

### Verification

- `test-availability-workflow.R`
- Experiment/config/hash tests
- API exports and `tools::checkRd()`

### Source Reference

- Spec Sections 2.3 and 2.5; gates U4/U20
- U Sections 3 and 10

### Classification

```yaml
type: api
surface: availability-policy
scope: activation-universe-valuation-plan
```

## LDG-2691 - Availability Provider Pulse Axis And Stable-Key State

Priority: P0
Effort: L
Dependencies: LDG-2690
Status: Pending

### Description

Implement the single internal availability provider, dynamic decision axis,
context planes, and stable-ID asset-state lifecycle without economic policy.

### Tasks

- Implement `facts`, `decision_view`, `execution_view`, `history`, and
  `identity` operations.
- Build the public axis as ordered members followed by held nonmembers in
  C-locale stable-ID order.
- Add accepted context fields and deterministic restriction-reason ordering.
- Normalize `ctx$state_prev$asset_state`, clean exited IDs, initialize re-entry,
  and preserve portfolio-level state.
- Reject explicit compiled availability before execution.

### Acceptance Criteria

- U2, U4, U6, U10, and U23 provider/state obligations pass.
- Future facts cannot alter earlier contexts, errors, or telemetry.
- The empty axis invokes the strategy and accepts a named zero-length target.
- No economics or second fold is implemented in the provider.

### Verification

- `test-availability-causality.R`
- `test-availability-state.R`
- `test-availability-workflow.R`
- Dense context/axis parity tests

### Source Reference

- Spec Section 2.6; gates U2/U4/U6/U10/U23
- U Sections 5-6

### Classification

```yaml
type: feature
surface: availability-provider
scope: axis-context-state
```

## LDG-2692 - Strict Expected-Session Feature Semantics

Priority: P0
Effort: L
Dependencies: LDG-2691
Status: Pending

### Description

Add strict finite-window gap semantics and cutoff-causal cache identity for
availability-aware indicators.

### Tasks

- Add normalized `gap_contract = "strict_window"` declarations on the existing
  indicator path while omitting them from dense identity.
- Count finite windows over expected sessions; any missing required observation
  yields NA and no valuation mark enters features.
- Certify SMA and returns first through scalar/series/window parity.
- Reject unsupported recursive/carry/imputing indicators before strategy use.
- Include actual active semantics in the feature-engine fingerprint.

### Acceptance Criteria

- U3 passes across scalar, series, and cache paths.
- U24 whole-feed outages break affected windows.
- Future-known history cannot rewrite cached earlier results.
- No generalized imputation or cross-sectional cache is added.

### Verification

- `test-features.R`
- `test-precompute-features.R`
- `test-availability-features.R`
- Cache identity and future-perturbation tests

### Source Reference

- Spec Sections 2.5-2.6; gates U2-U3/U24
- U Sections 8-9

### Classification

```yaml
type: feature
surface: availability-features
scope: strict-gap-cache
```

## LDG-2693 - Availability Target Restrictions And Helper Safety

Priority: P0
Effort: L
Dependencies: LDG-2692
Status: Pending

### Description

Enforce the accepted member/restricted/nonmember target contract, helper
behavior, post-risk closure, and availability-only short-exposure guard.

### Tasks

- Validate literal zero, hold, reduction-only nonmember, and restriction rules
  with classed reason-bearing errors.
- Make zero-default constructors preserve held nonmembers by default while raw
  full named vectors remain literal.
- Make active rebalance sizing fail on unavailable current prices; preserve the
  dense warn-and-zero path.
- Enforce `q >= min(q_held, 0)` after risk and at resolved-fill quantity.

### Acceptance Criteria

- U5, U8, U17, and U20 pass.
- Active execution cannot open, enlarge, or reverse into a short; no rejected
  short proposal funds another purchase.
- Existing short holdings may hold/cover and explicit `long_only` clipping may
  reach zero; dense behavior and risk identity remain unchanged.

### Verification

- `test-strategy-contracts.R`
- `test-availability-fold.R`
- `test-availability-workflow.R`
- First-review short-financing fixture

### Source Reference

- Spec Section 2.7 and short-financing regression row
- U Section 6.3 as amended

### Classification

```yaml
type: correctness
surface: strategy-targets
scope: active-admissibility-short-guard
```

## LDG-2694 - Stale Valuation Risk Marks And Affected Exposure

Priority: P0
Effort: L
Dependencies: LDG-2692
Status: Pending

### Description

Separate observed closes, valuation/risk marks, and execution prices; age
stale marks on venue sessions and compute the bound diagnostic gross exposure.

### Tasks

- Implement fresh/current and policy-permitted stale mark selection with
  source timestamp, age, and reason evidence.
- Stop new positive targets lacking a permissible risk mark before proposals.
- Age held marks through venue-open sessions including known inactivity.
- Compute affected gross exposure from held quantities and latest accepted
  observations knowable at the stop cutoff, including expired diagnostic-only
  references and explicit missing-reference behavior.

### Acceptance Criteria

- U7, U19, and U21 valuation assertions pass.
- U24's valuation-clock behavior passes through a whole-feed outage.
- Stale marks never price execution or silently create NA equity.
- Independent gross fixture yields 1200 rather than net 800 and covers missing,
  duplicate, zero-quantity, expired, and later-known cases.

### Verification

- `test-availability-valuation.R`
- `test-availability-parity.R`
- U24 whole-feed-outage valuation assertions
- Risk-hash invariance and fresh-connection checks

### Source Reference

- Spec Section 2.7; gates U7/U19/U21/U24 and affected-exposure regression row
- U Sections 7.3-7.4

### Classification

```yaml
type: correctness
surface: valuation
scope: stale-marks-and-exposure
```

## LDG-2695 - Bounded Affordability And Execution Reconciliation

Priority: P0
Effort: L
Dependencies: LDG-2693, LDG-2694
Status: Pending

### Description

Add the active-mode virtual cash ledger after costs and proposals, preserving
axis-order events and final-pulse reconciliation.

### Tasks

- Reserve marked absolute exposure of held nonmembers during helper sizing.
- Freeze membership at decision and recheck status, lifetime, execution price,
  and affordability at execution.
- Credit accepted cash-generating reductions first, then evaluate consuming
  fills in stable-ID order against `cash_tolerance = 1e-8`.
- Apply accepted fills in axis order; never scale, floor, defer, or credit a
  rejected sale.
- Reconcile virtual and recorded cash plus intended/post-risk/actual exposure.

### Acceptance Criteria

- U13 and U18 pass under target-order permutations and exact-boundary cases.
- No opening short or unaccepted sale generates spendable cash.
- Final cash matches the virtual ledger or stops with the typed reconciliation
  reason.

### Verification

- `test-availability-affordability.R`
- `test-availability-fold.R`
- Cost/risk/accounting regression tests

### Source Reference

- Spec Section 2.7; gates U13/U18 and short regression
- U Sections 7.1-7.2

### Classification

```yaml
type: correctness
surface: execution-affordability
scope: virtual-ledger-policy
```

## LDG-2696 - Controlled Stops Completion And Direct Diagnostics

Priority: P0
Effort: L
Dependencies: LDG-2693, LDG-2694, LDG-2695
Status: Pending

### Description

Represent expected valuation/settlement stops as committed INCOMPLETE prefixes
with durable completion and ordered diagnostic evidence on direct runs.

### Tasks

- Return typed terminal fold results through the normal transaction return path.
- Stage pulse work until feasibility/reconciliation succeeds and discard only
  unaccepted current-pulse work.
- Add `run_completion` and `run_diagnostics` schemas/writers with intended and
  achieved bounds, stop reason, gross exposure, and deterministic sequences.
- Preserve last-valued and last-executed timestamps separately.
- Keep fold exceptions FAILED with rollback of the current fold transaction.

### Acceptance Criteria

- Expected exhaustion/unsupported settlement finalizes INCOMPLETE, never DONE.
- Earlier accepted events and valid prefix evidence persist; fabricated
  settlement and partial current-pulse economics do not.
- Direct diagnostic rows and completion payload validate through a fresh
  connection.

### Verification

- `test-availability-valuation.R`
- `test-availability-fold.R`
- `test-availability-parity.R`
- First-review exception-phase and affected-exposure fixtures

### Source Reference

- Spec Section 2.7; gates U19/U22 and first-review regression rows
- U Sections 7.4 and 9.3

### Classification

```yaml
type: persistence
surface: run-completion
scope: incomplete-prefix-diagnostics
```

## LDG-2697 - Terminal Finalization Reopen And Idempotent Recovery

Priority: P0
Effort: L
Dependencies: LDG-2696
Status: Pending

### Description

Finalize and reopen DONE/INCOMPLETE outcomes safely, with a zero-execution
shortcut for achieved terminals and finalization-only recovery after failure.

### Tasks

- Persist terminal intent and prefix bounds with the committed fold result.
- Make RUNNING/FAILED rows with valid terminal completion evidence rebuild
  projections only, then commit the intended terminal status once.
- Return achieved INCOMPLETE handles idempotently after identity verification.
- Extend `ledgr_run_open()` to inspect DONE or INCOMPLETE without strategy code.
- Fail closed on missing/inconsistent terminal evidence.

### Acceptance Criteria

- Same-ID achieved INCOMPLETE invokes no callback, cleanup, status change, or
  projection rewrite.
- Injected DONE and INCOMPLETE finalization failures recover without replay or
  duplicate rows.
- U19 and U22 terminal recovery/reopen assertions pass.
- Mismatched identity and malformed completion bounds fail closed.

### Verification

- `test-runner.R`
- `test-persistence-fresh-connection.R`
- `test-availability-parity.R`
- U19 valuation-horizon and U22 terminal-settlement recovery cases
- First-review terminal-idempotency fixture

### Source Reference

- Spec Sections 2.2 and 2.7; gates U19/U22 and terminal-idempotency regression row
- U Section 7.4

### Classification

```yaml
type: correctness
surface: run-recovery
scope: terminal-incomplete-finalization
```

## LDG-2698 - Sweep And Parallel Incomplete-Evidence Propagation

Priority: P0
Effort: L
Dependencies: LDG-2697
Status: Pending

### Description

Carry compact completion/stop evidence through memory sweeps, saved sweeps,
and parallel candidates while excluding incomplete performance from selection.

### Tasks

- Add INCOMPLETE and canonical `completion_json` support to sweep candidates.
- Persist/reopen saved-sweep schema 4 without full per-candidate ledgers.
- Return compact worker evidence to the parent for persistence.
- Exclude incomplete candidates from panels, candidate selection, and
  promotion even through `allow_failed` paths.

### Acceptance Criteria

- U9 and the sweep/parallel portions of U11 pass.
- Direct, sequential, parallel, and reopened completion evidence agree.
- Incomplete retained series are visibly labelled and never treated as
  complete performance.

### Verification

- `test-sweep-persistence-roundtrip.R`
- `test-sweep-parallel.R`
- `test-availability-parity.R`
- Candidate/promotion rejection tests

### Source Reference

- Spec Section 2.7; gates U9/U11
- U Sections 7.4 and 9.3

### Classification

```yaml
type: feature
surface: sweep-parallel
scope: incomplete-evidence
```

## LDG-2699 - Walk-Forward Incomplete-Evidence Propagation

Priority: P0
Effort: L
Dependencies: LDG-2698
Status: Pending

### Description

Propagate incomplete candidate/fold evidence through walk-forward evaluation
without inventing selection eligibility or later opening state.

### Tasks

- Admit INCOMPLETE and canonical completion payloads on score rows.
- Exclude incomplete training candidates and explain the exclusion.
- Stop a carry-state chain with existing PARTIAL fold/session semantics when a
  test run becomes incomplete.
- Preserve candidate/session identity formats and prior opening state.

### Acceptance Criteria

- U9 and walk-forward U11 pass.
- U23 walk-forward state/history continuity passes across the incomplete
  carry-state boundary.
- No incomplete candidate is selected or promoted.
- No later fold is fabricated after an incomplete carry-state boundary.

### Verification

- `test-walk-forward-orchestrator.R`
- `test-availability-parity.R`
- U23 walk-forward asset-state lifecycle assertions
- Saved/reopened walk-forward tests

### Source Reference

- Spec Section 2.7; gates U9/U11/U23
- U Sections 7.4 and 9.3

### Classification

```yaml
type: feature
surface: walk-forward
scope: incomplete-fold-propagation
```

## LDG-2700 - Durable Explanation Views And Cross-Path Parity

Priority: P0
Effort: L
Dependencies: LDG-2697, LDG-2698, LDG-2699
Status: Pending

### Description

Expose durable availability/diagnostic result tables and `ledgr_run_explain()`
over recorded evidence, then verify dense and active behavior across all paths.

### Tasks

- Add `as_tibble(bt, what = "diagnostics"|"availability")` and delegate
  `ledgr_results()` through the same path.
- Implement `ledgr_run_explain()` without strategy execution or target
  reconstruction.
- Reconstruct availability planes only from sealed facts, effective plan, and
  ledger holdings; use committed decision traces for actual targets.
- Compare direct, reopened, sweep, parallel, and walk-forward completion and
  economic evidence under equal versions.

### Acceptance Criteria

- U1, U4, U11, and U12 pass.
- Dense hashes, axes, events, and metrics remain version-qualified identical.
- Reopened explanations equal live ones and inspection writes nothing.
- Missing retained trace fails explicitly rather than inventing an answer.

### Verification

- `test-availability-parity.R`
- `test-availability-workflow.R`
- U4 same-strategy dense/active parity
- Result delegation and fresh-connection tests
- `tools::checkRd()` and export review

### Source Reference

- Spec Sections 2.3, 2.7, and 4; gates U1/U4/U11/U12
- U Sections 9-10

### Classification

```yaml
type: api
surface: availability-results
scope: explain-reopen-parity
```

## LDG-2701 - Survivorship-Bias Article And Connected Workflow

Priority: P1
Effort: L
Dependencies: LDG-2700
Status: Pending

### Description

Teach the point-in-time universe problem and ledgr's first implementation with
one executable public ingest-run-explain-close-reopen journey.

### Tasks

- Add `vignettes/survivorship-bias.qmd` using the approved synthetic
  vendor-shaped fixture and explicit session calendar.
- Show membership entry/removal, a retained holding, blocked and retried exit,
  valuation age, completion state, and reopened explanation.
- Show strict invalid-observation rejection before explicit quarantine and the
  resulting missing session.
- Teach assumptions, omitted checks, incomplete evidence, and unsupported
  terminal economics without overclaiming point-in-time completeness.

### Acceptance Criteria

- H8 and U12's connected journey execute entirely through public APIs.
- No private provider fields, hand-built planes, internal SQL, or strategy
  replay appears in the teaching path.
- The article follows the styleguide and uses real references.

### Verification

- Execute all vignette chunks
- Render QMD and Markdown mirror
- `test-documentation-contracts.R`
- Local pkgdown article inspection
- Overclaim and stale-API scan

### Source Reference

- Spec Section 4; gates H8/U12
- U Sections 10.4 and 13
- `inst/design/vignette_styleguide.md`

### Classification

```yaml
type: documentation
surface: availability-teaching
scope: survivorship-bias-workflow
```

## LDG-2702 - Reference Surfaces Audit Dispositions And Closeout

Priority: P1
Effort: L
Dependencies: LDG-2701
Status: Pending

### Description

Complete generated/reference documentation, contract and maintainer traces,
release surfaces, and explicit audit/horizon dispositions for implemented work.

### Tasks

- Update `contracts.md`, NEWS, README, generated help/NAMESPACE, `_pkgdown.yml`,
  affected vignettes, and maintainer manual implementation traces.
- Publish the reason-code table with stage/action mappings.
- Update identity reference for schema/hash/availability choices.
- Record every scoped audit outcome and preserve all explicit deferrals.
- Remove active-pointer claims only when implementation/release status warrants.

### Acceptance Criteria

- Release surfaces accurately describe shipped behavior and limitations.
- No surface claims short financing, settlement, arbitrary PIT completeness,
  performance superiority, or a second execution engine.
- Audit and horizon entries are closed or routed with reasons.

### Verification

- Documentation-contract tests
- `tools::checkRd()`
- NAMESPACE/API/reference index review
- Full pkgdown build
- Manual audit/deferral ledger review

### Source Reference

- Spec Sections 4 and 7-8
- H/U documentation and future-obligation sections

### Classification

```yaml
type: documentation
surface: release-surfaces
scope: help-manual-audit-deferrals
```

## LDG-2703 - v0.2.0.0 Release Gate

Priority: P0
Effort: L
Dependencies: LDG-2672, LDG-2673, LDG-2674, LDG-2675, LDG-2676, LDG-2677, LDG-2678, LDG-2679, LDG-2680, LDG-2681, LDG-2682, LDG-2683, LDG-2684, LDG-2685, LDG-2686, LDG-2687, LDG-2688, LDG-2689, LDG-2690, LDG-2691, LDG-2692, LDG-2693, LDG-2694, LDG-2695, LDG-2696, LDG-2697, LDG-2698, LDG-2699, LDG-2700, LDG-2701, LDG-2702
Status: Pending

### Description

Follow the release playbook, close the packet, and prepare the branch for
remote CI, merge, and tag without conflating those evidence stages.

### Tasks

- Read `inst/design/release_ci_playbook.md` before execution.
- Run full tests, installed README, source build/check, coverage, pkgdown, and
  Linux persistence/executable-documentation gates.
- Suppress DuckDB temporary-home startup chatter across every rendered
  vignette without globally hiding ledgr warnings, errors, or meaningful
  example output.
- Record versions, commands, skips, failures, reruns, and exact commits.
- Confirm every ticket is complete after review or explicitly deferred by a
  dated maintainer amendment.
- Remove generated local artifacts and write the release closeout.

### Acceptance Criteria

- Full release verification passes or each exception is documented and
  accepted.
- Coverage remains at least 80 percent and ordinary parallel tests run outside
  covr.
- Contracts, schemas, identities, NEWS, docs, and packet records agree.
- Rendered vignettes contain no repeated DuckDB temporary-directory startup
  notices, while intended diagnostic and example output remains visible.
- Branch is ready for remote branch CI; main and tag CI remain later evidence.

### Verification

- Release CI playbook
- Full local suite
- Installed README check
- `R CMD build` and `R CMD check --no-manual --no-build-vignettes`
- Coverage, pkgdown, and Linux gates
- Rendered-HTML scan for DuckDB temporary-home startup messages
- Git status/generated-artifact review

### Source Reference

- Spec Section 7
- `inst/design/release_ci_playbook.md`

### Classification

```yaml
type: release
surface: release-gate
scope: v0.2.0.0-closeout
```
