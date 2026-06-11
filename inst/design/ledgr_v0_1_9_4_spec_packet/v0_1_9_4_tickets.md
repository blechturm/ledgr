# ledgr v0.1.9.4 Tickets

Version: v0.1.9.4
Date: 2026-06-10
Total Tickets: 15

## Ticket Organization

This packet implements the scoped v0.1.9.4 plan from `v0_1_9_4_spec.md`:
the first walk-forward evaluation surface. The release is a wrapper over
`ledgr_sweep()` and `ledgr_run()`, not a second execution engine. It adds
calendar-time fold definitions, an internal window contract, fold-local train
sweeps, scalar train-score selection rules, selected-candidate test runs,
walk-forward session identity, compact persistence, inspection helpers, and
promotion-ready candidate extraction.

Ticket IDs start at `LDG-2612` because `LDG-2597` through `LDG-2611` were used
by the v0.1.9.3 packet.

The release spine is:

```text
packet alignment
  -> fold objects and window contract
     -> feature-window validation
        -> selection rules and metric classification
           -> identity and persistence
              -> walk-forward orchestration
                 -> score/failure/interrupt semantics
                    -> inspection, extraction, and promotion provenance
                       -> degradation-table UX and docs
                          -> release gate
```

## Dependency DAG

```text
LDG-2612 Packet Alignment And v0.1.9.4 Ticket Cut
  |-- LDG-2613 Fold Constructors And Fold-List Identity
  |     `-- LDG-2614 Experiment Window Contract And Run/Sweep Parity
  |           `-- LDG-2615 Window-Aware Feature Precompute Validation
  |-- LDG-2616 Selection Rules And Metric Classification
  |-- LDG-2617 Walk-Forward Candidate, Session, And Seed Identity
  |     ^ depends conceptually on LDG-2613 and LDG-2616 before full tests
  |     `-- LDG-2618 Walk-Forward Persistence Schema
  |           `-- LDG-2620 Score Rows, Failures, And Partial Sessions
  |                 `-- LDG-2621 Results, Scores, Folds, And Reopen Helpers
  |                       `-- LDG-2622 Candidate Extraction And Promotion Provenance
  |                             `-- LDG-2623 Degradation Table And Print UX
  |-- LDG-2619 Walk-Forward Orchestrator And Opening-State Policy
  |     ^ depends on LDG-2614, LDG-2615, LDG-2616, LDG-2617, and LDG-2618
  |-- LDG-2624 Documentation, Examples, And NEWS
  |-- LDG-2625 Release Surfaces And Planning Docs
  `-- LDG-2626 v0.1.9.4 Release Gate
```

`LDG-2619` is the integration ticket and should not start until fold/window,
feature-window, selection, identity, and persistence foundations are in place.
`LDG-2626` depends on every prior implementation, test, documentation, and
release-surface ticket.

## Priority Levels

- P0: packet alignment, public API, run/sweep parity, fold identity, session
  identity, Section 17 gates, persistence, promotion provenance, or release
  gate.
- P1: documentation, examples, release-surface updates, and user-facing
  teaching required by the spec.
- P2: small polish that improves reviewability without changing scope.

---

## LDG-2612: Packet Alignment And v0.1.9.4 Ticket Cut

Priority: P0
Effort: S
Dependencies: none
Status: Completed

### Description

Finalize the v0.1.9.4 planning packet after spec review and cut the human
ticket list, machine-readable ticket YAML, and batch plan before implementation
starts.

### Tasks

- Keep `v0_1_9_4_spec.md`, `v0_1_9_4_tickets.md`, `tickets.yml`,
  `batch_plan.md`, and `README.md` synchronized.
- Confirm the packet opens from
  `rfc_walk_forward_evaluation_v0_1_9_x_synthesis.md`, including Amendment 1,
  Amendment 2, and Section 17.
- Confirm every Section 17 packet-open row is represented in the ticket cut.
- Confirm the predecessor handoffs are named in ticket scope:
  `cost_model_hash`, `cost_plan_json`, sweep persistence machinery,
  `risk_chain_hash`, and `risk_plan_json`.
- Submit the packet cut and batch plan for Claude review before Batch 1 starts.

### Acceptance Criteria

- Spec, ticket markdown, YAML, README, and batch plan agree on IDs,
  dependencies, priorities, statuses, and scope.
- No ticket authorizes selection-integrity diagnostics, PBO/CSCV/CPCV, DSR,
  evaluation registry, ML-first tooling, candidate clustering, OMS behavior,
  paper/live walk-forward, top-N/all-candidate test retention, or compiled-core
  architecture work.
- Section 17 packet-open gates are traceable to specific tickets.
- Review prompt is written and sent before implementation begins.

### Verification

Manual packet review, YAML review, batch-plan review, ASCII check,
Section 17 trace check, stale reference `rg` checks, and Claude packet-cut
review.

Batch 0 closeout note: Claude packet-alignment review found no blockers. The
packet cut is aligned with the roadmap, design index, horizon, and `AGENTS.md`
as the active v0.1.9.4 packet. No runtime implementation started before this
review closed.

### Source Reference

- `v0_1_9_4_spec.md`
- `inst/design/rfc/rfc_walk_forward_evaluation_v0_1_9_x_synthesis.md`
- `inst/design/ledgr_roadmap.md`
- `inst/design/horizon.md`

### Classification

```yaml
type: governance
surface: design_packet
scope: v0.1.9.4
```

---

## LDG-2613: Fold Constructors And Fold-List Identity

Priority: P0
Effort: L
Dependencies: LDG-2612
Status: Completed

### Description

Add immutable walk-forward fold objects, rolling and anchored fold-list
constructors, deterministic `fold_id`, and deterministic `fold_list_hash`.

### Tasks

- Implement `ledgr_fold()`.
- Implement `ledgr_folds_rolling()`.
- Implement `ledgr_folds_anchored()`.
- Convert fold boundaries to UTC POSIXct values.
- Validate fold ordering, train/test overlap, undersized windows, and
  unsupported non-NULL gap values.
- Derive `fold_id` from the canonical JSON fields listed in the spec.
- Derive `fold_list_hash` from ordered fold IDs, constructor metadata, and
  schema version.
- Add exports, constructor tests, invalid-window tests, and hash-stability
  tests.

### Acceptance Criteria

- Fold objects are immutable value objects with the logical fields named in
  the spec.
- Rolling folds score the full stored fixed-width train window.
- Anchored folds score the full stored expanding train window.
- `gap = NULL` is the only accepted v1 behavior.
- Deterministic `fold_id` and `fold_list_hash` values are stable across
  reconstruction and sensitive to fold order.
- Calendar-aware, state-aware, randomized, blocked, purged, embargoed, and
  cross-snapshot folds are not implemented.

### Verification

Constructor tests, invalid-input tests, deterministic hash tests,
round-trip reconstruction tests, export tests, and ASCII documentation checks.

Implementation note:

Batch 1 added `ledgr_fold()`, `ledgr_folds_rolling()`,
`ledgr_folds_anchored()`, deterministic `fold_id`, deterministic
`fold_list_hash`, public exports, Rd coverage, and fold identity tests.
`gap = NULL` is the only accepted v1 gap shape; non-NULL gaps fail closed.

### Source Reference

- `v0_1_9_4_spec.md` Sections 4, 5, and 7
- Walk-forward synthesis Sections 3, 4, 7, 14.1, and 16.1

### Classification

```yaml
type: public_api
surface: walk_forward_folds
scope: fold_constructors_and_identity
```

---

## LDG-2614: Experiment Window Contract And Run/Sweep Parity

Priority: P0
Effort: XL
Dependencies: LDG-2613
Status: Completed

### Description

Add the internal experiment-window contract and make `ledgr_run()` and
`ledgr_sweep()` execute over explicit scoring windows without changing fold-core
semantics.

### Tasks

- Add an internal helper, working name `ledgr_experiment_window()`.
- Carry `hydration_start`, `scoring_start`, `scoring_end`, `execution_start`,
  and `opening_state_policy`.
- Ensure run and sweep paths can consume equivalent windows.
- Preserve existing final-bar no-fill behavior at `scoring_end`.
- Add rolling and anchored parity fixtures proving fold-local execution equals
  direct windowed run/sweep execution.
- Add a structural guard against walk-forward-specific pulse-loop logic in the
  fold core.

### Acceptance Criteria

- `fold_train_sweep(fold_n) == ledgr_sweep(window = c(train_start_utc, train_end_utc))`
  over the full stored train window for rolling folds.
- The same parity holds for anchored folds.
- Selected fold test execution equals direct windowed `ledgr_run()` with the
  same snapshot, params, feature params, metric context, cost model, risk chain,
  and seed.
- The internal window helper is not exported in v1.
- No second execution engine or walk-forward pulse loop is introduced.

### Verification

Rolling parity tests, anchored parity tests, selected test-run parity tests,
final-bar no-fill tests, config identity tests, structural code-search guard,
and run/sweep parity tests.

Implementation note:

Batch 1 added the internal `ledgr_experiment_window()` contract and internal
run/sweep window entry points. Public `ledgr_run()` and `ledgr_sweep()` do not
gain public window arguments. Tests cover rolling and anchored full train-window
scoring, selected windowed run/sweep parity, unchanged final-bar no-fill
behavior at `scoring_end`, and the fold-core structural guard.

### Source Reference

- `v0_1_9_4_spec.md` Sections 2, 3, 5, 8, 12, and 13
- Walk-forward synthesis Sections 3, 14.1, 16.1, and 17.1

### Classification

```yaml
type: execution
surface: run_sweep_window_contract
scope: walk_forward_window_parity
```

---

## LDG-2615: Window-Aware Feature Precompute Validation

Priority: P0
Effort: L
Dependencies: LDG-2614
Status: Review Pending

### Description

Make precomputed-feature validation fold-window-aware so train and test
execution can validate snapshot hash, feature identity, scoring range, and
hydration range coverage.

### Tasks

- Extend precomputed-feature validation to accept fold window metadata.
- Validate snapshot hash against the fold's snapshot.
- Validate feature identities and fingerprints against requested features.
- Validate scoring range coverage for the fold's scoring window.
- Validate hydration range coverage needed for warmup.
- Add feature-windowing determinism tests.
- Add cross-fold train-score stability tests.

### Acceptance Criteria

- Fold-local train sweeps cannot consume precomputed features that lack scoring
  or hydration coverage.
- Validation distinguishes scoring range from hydration range.
- Feature-windowing determinism and cross-fold train-score stability tests are
  release blockers.
- No public precomputed-feature API expansion is introduced unless directly
  required by the internal window contract.

### Verification

Precomputed-feature validation tests, missing-coverage tests, hydration/scoring
range tests, feature-windowing determinism tests, cross-fold train-score
stability tests, and direct window parity tests.

Implementation note:

Batch 2 extended internal precomputed-feature validation with fold-window
metadata, retained exact range checks for ordinary sweeps, added fold-window
coverage checks for scoring and hydration ranges, and slices broader
precomputed runtime projections onto the requested fold pulses before
execution.

### Source Reference

- `v0_1_9_4_spec.md` Sections 5, 12, and 13
- Walk-forward synthesis Sections 3, 8, 14.4, and 17.1

### Classification

```yaml
type: execution
surface: feature_precompute
scope: fold_window_validation
```

---

## LDG-2616: Selection Rules And Metric Classification

Priority: P0
Effort: L
Dependencies: LDG-2612
Status: Review Pending

### Description

Add ledgr-owned scalar selection rules and the metric-classification substrate
needed to fail closed on level or count metrics.

### Tasks

- Implement `ledgr_select_argmax(metric)`.
- Implement `ledgr_select_argmin(metric)`.
- Add deterministic `selection_rule_hash`.
- Add metric classification to the metric definition substrate.
- If ledgr does not currently expose a metric-definition substrate that
  supports per-metric metadata, define a minimal classified-metric registry
  sufficient for fail-closed selection. The substrate need not be public in
  v0.1.9.4 and may be internal-only. Document the choice in ticket closeout.
- Fail closed for metrics not classified as `rate`, `annualized`, `ratio`, or
  `length_invariant`.
- Drop `NA`, `NaN`, and infinite candidate values from selection eligibility.
- Break ties by ascending `candidate_key`.
- Add classed conditions for missing metric, invalid metric class, and no
  eligible selection.

### Acceptance Criteria

- Selection rules see only train-window rows for the current fold.
- Missing metric raises `ledgr_walk_forward_metric_missing`.
- No finite eligible candidate raises `ledgr_walk_forward_no_selection`.
- Selecting `total_return` fails with
  `ledgr_walk_forward_metric_class_invalid`.
- Selecting `n_trades` fails with `ledgr_walk_forward_metric_class_invalid`.
- A permitted metric such as `sharpe_ratio` can be selected.
- No composite, override, stability-region, top-N, or arbitrary-function
  selection rule is implemented.

### Verification

Constructor tests, selection-rule hash tests, missing-metric tests,
invalid-class tests, no-selection tests, tie-break tests, finite-filter tests,
export tests, and metric-classification substrate disposition note in ticket
closeout.

Implementation note:

Batch 2 added `ledgr_select_argmax()` and `ledgr_select_argmin()` as public
selection-rule value-object constructors with deterministic
`selection_rule_hash`. The metric-classification substrate is a minimal
internal registry for v1 because ledgr does not yet expose a general
metric-definition metadata substrate. It classifies `sharpe_ratio` as
selectable and fails closed on `total_return`, `n_trades`, missing metrics, and
non-finite candidate values.

### Source Reference

- `v0_1_9_4_spec.md` Sections 4, 9, 12, 13, and 16
- Walk-forward synthesis Sections 3, 11, 16.3, and 17.1

### Classification

```yaml
type: public_api
surface: walk_forward_selection
scope: scalar_selection_rules
```

---

## LDG-2617: Walk-Forward Candidate, Session, And Seed Identity

Priority: P0
Effort: L
Dependencies: LDG-2613, LDG-2616
Status: Review Pending

### Description

Implement deterministic `candidate_key`, `session_id`, and per-row
`execution_seed` derivation for walk-forward sessions.

### Tasks

- Derive `candidate_key` from params, feature params, strategy, feature set,
  alias map, metric context, cost model, risk chain, execution seed, and schema
  version.
- Derive `session_id` from snapshot, experiment, parameter grid, fold list,
  selection rule, metric context, cost model, risk chain, master seed, opening
  state policy, schema version, and ledgr version.
- Exclude `run_id`, row order, display label, and transient `sweep_id`.
- Define `experiment_hash` explicitly. V1 derives it from the same normalized
  payload family as `config_hash_payload(config)`, with the same store-local
  exclusions, then removes cost identity, risk identity, metric-context
  identity, and execution-seed fields because `session_id` carries those
  components independently. The derivation rule lives beside the existing
  identity helpers.
- Reuse the existing sweep candidate-seed derivation rule for per-row
  execution seeds, extended with fold sequence and train/test window marker.
- Add unseeded-session behavior with `NA_integer_` execution seeds.
- Add canonical JSON and reconstruction tests.

### Acceptance Criteria

- `candidate_key` and `session_id` are deterministic across reconstruction.
- Cost identity from v0.1.9.1 and risk identity from v0.1.9.3 participate in
  both candidate and session identity.
- Changing cost model, risk chain, metric context, fold list, selection rule,
  or master seed changes `session_id`.
- Changing row order, display label, run ID, or sweep ID does not change
  `candidate_key`.
- Per-row seeds reproduce exactly for the same inputs.
- `experiment_hash` is deterministic and changes only when the base experiment
  payload changes outside the separately hashed cost, risk, metric-context, and
  seed components.

### Verification

Canonical JSON tests, hash-stability tests, identity-sensitivity tests,
identity-orthogonality tests, seed-derivation tests, no-seed tests, and
reconstruction tests, and experiment-hash derivation tests.

### Source Reference

- `v0_1_9_4_spec.md` Sections 6, 7, 12, and 13
- Walk-forward synthesis Sections 4 and 7
- Cost-model post-direction horizon entry

### Classification

```yaml
type: identity
surface: walk_forward
scope: candidate_session_seed_identity
```

---

## LDG-2618: Walk-Forward Persistence Schema

Priority: P0
Effort: L
Dependencies: LDG-2617
Status: Review Pending

### Description

Add compact walk-forward persistence tables for sessions, folds, and score
rows without adding new accounting, ledger, fill, trade, or equity semantics.

### Tasks

- Add `walk_forward_sessions`.
- Add `walk_forward_folds`.
- Add `walk_forward_scores`.
- Store canonical JSON metadata where needed.
- Link selected test runs by `test_run_id`.
- Store `cost_model_hash`, `risk_chain_hash`, `metric_context_hash`,
  `candidate_key`, and `session_id` consistently.
- Add schema validation and fail-closed incompatible-schema handling.

### Acceptance Criteria

- Walk-forward artifacts are compact evidence, not committed runs for every
  candidate.
- Selected test runs remain ordinary `ledgr_run()` artifacts.
- No new accounting-event, ledger, fill, trade, or equity-table semantics are
  introduced.
- Walk-forward sessions store identity hashes only; cost and risk plan JSON
  reconstruction goes through the linked test run's stored config. Plan bytes
  are not duplicated into walk-forward tables. Reopen verifies the linked test
  run is readable and its config is schema-compatible before completing
  reconstruction.
- Reopened sessions verify snapshot, cost, risk, metric, and schema identity
  before inspection.
- Partial writes fail transactionally at fold/session boundaries.

### Verification

Schema tests, DB round-trip tests, canonical JSON tests, linked-run tests,
transactionality tests, schema-validation tests, and incompatible-schema tests.

### Source Reference

- `v0_1_9_4_spec.md` Sections 6, 7, 8, and 13
- Walk-forward synthesis Sections 4, 5, 6, and 7

### Classification

```yaml
type: persistence
surface: walk_forward_schema
scope: sessions_folds_scores
```

---

## LDG-2619: Walk-Forward Orchestrator And Opening-State Policy

Priority: P0
Effort: XL
Dependencies: LDG-2614, LDG-2615, LDG-2616, LDG-2617, LDG-2618
Status: Review Pending

### Description

Implement `ledgr_walk_forward()` as the orchestrator over fold-local train
sweeps, scalar selection rules, and selected-candidate test runs.

### Tasks

- Implement `ledgr_walk_forward()`.
- Run train-window `ledgr_sweep()` for each fold.
- Select exactly one candidate using the fold's train score rows.
- Run selected-candidate test-window `ledgr_run()`.
- Write fold session, fold metadata, and `DONE`-status train/test score rows
  for the happy path; rich failure, interrupt, and partial-session handling
  lands in `LDG-2620`.
- Implement `opening_state_policy = "carry_test_state"` as the default.
- Implement `opening_state_policy = "flat_test_state"` as explicit opt-in.
- Emit `ledgr_walk_forward_cold_start_warning` for flat-test opt-in.
- Set `cold_start_distorted` metadata for affected folds.
- Preserve train sweeps from experiment opening state in every fold.

### Acceptance Criteria

- Walk-forward never selects from a full-snapshot sweep result.
- Walk-forward never accepts a preselected candidate and reports it as
  fold-local selection.
- `carry_test_state` carries test fold terminal cash, positions, and lot state
  into the next test fold.
- `flat_test_state` starts each test fold flat, emits the classed warning, and
  records cold-start distortion.
- Train sweeps always start from the experiment opening state.
- Re-running the same session inputs reproduces the same `session_id`, ordered
  `fold_id`s, selected candidates per fold, per-row seeds, and selected
  test-run results.
- No OMS, paper/live, order lifecycle, top-N test retention, or all-candidate
  test retention is implemented.

### Verification

Walk-forward integration tests, train-sweep isolation tests, selected-test-run
tests, carry-state tests, flat-state warning tests, cold-start flag tests,
state-reconstruction tests, deterministic-session-replay tests, and
no-full-snapshot-selection tests.

Implementation note:

- Implemented the first happy-path orchestrator surface with fold-local train
  sweeps, scalar selection, selected-candidate test runs, explicit opening-state
  policy, and persisted DONE score rows. Rich failure, interrupt, and partial
  session semantics remain delegated to LDG-2620.

### Source Reference

- `v0_1_9_4_spec.md` Sections 2, 3, 5, 8, 12, and 16
- Walk-forward synthesis Sections 3, 5, 16.2, and 17.1

### Classification

```yaml
type: orchestration
surface: ledgr_walk_forward
scope: train_select_test_lifecycle
```

---

## LDG-2620: Score Rows, Failures, And Partial Sessions

Priority: P0
Effort: L
Dependencies: LDG-2618, LDG-2619
Status: Planned

### Description

Persist train/test score rows, candidate failures, fold failures, interrupts,
and partial-session evidence with classed conditions.

### Tasks

- Write train score rows for all train candidates or train candidate failures.
- Write test score rows only for the selected candidate in v1.
- Extend the happy-path row writing from `LDG-2619` with
  `FAILED`/`INTERRUPTED`/`PARTIAL` branches and classed conditions.
- Capture train candidate failure status, error class, and error message.
- Capture no-selection fold failure.
- Capture selected test-run failure.
- Extend `ledgr_walk_forward_test_score_wide()` so a selected test run that
  yields no equity row or unusable metrics is surfaced as `FAILED` rather than
  as a `DONE` score row with only missing values.
- Implement session/fold statuses `DONE`, `FAILED`, `INTERRUPTED`, and
  `PARTIAL`.
- Implement interrupt handling with inspectable partial artifacts when at least
  one fold completed the train-selection-test write sequence.

### Acceptance Criteria

- Failed train candidates remain inspectable score rows and do not poison
  surviving candidates.
- If no finite eligible candidate remains, the fold fails with
  `ledgr_walk_forward_no_selection`.
- Test-run failure marks the fold and session failed while preserving train
  rows.
- User interruption discards no completed fold evidence but does not claim a
  complete session.
- `PARTIAL` is used only when at least one fold has complete train rows,
  selected-candidate test rows, and fold metadata.

### Verification

Failure-capture tests, no-selection tests, test-run-failure tests,
interrupt tests, partial-session tests, transactionality tests, and status
transition tests.

### Source Reference

- `v0_1_9_4_spec.md` Sections 6, 8, 12, 13, and 16
- Walk-forward synthesis Sections 5 and 8

### Classification

```yaml
type: persistence
surface: walk_forward_scores
scope: failures_and_partial_sessions
```

---

## LDG-2621: Results, Scores, Folds, And Reopen Helpers

Priority: P0
Effort: M
Dependencies: LDG-2620
Status: Planned

### Description

Add read-only inspection helpers for completed and partial walk-forward
sessions.

### Tasks

- Implement `ledgr_walk_forward_results(session_id)`.
- Implement `ledgr_walk_forward_scores(session_id)`.
- Implement `ledgr_walk_forward_folds(session_id)`.
- Support reopened sessions from the experiment store.
- Verify matching snapshot and schema identity.
- Return plain inspectable data frames / lists, not print-only objects.

### Acceptance Criteria

- Inspection helpers are read-only and never mutate, recompute, or re-execute.
- Completed and partial sessions can be inspected.
- Reopened helper output preserves session, fold, score, cost, risk, and metric
  identity.
- Corrupted or incompatible stored walk-forward artifacts fail closed.
- Helpers do not implement cross-session comparison.

### Verification

Read-only tests, reopen tests, schema mismatch tests, identity mismatch tests,
partial-session inspection tests, and output-shape tests.

### Source Reference

- `v0_1_9_4_spec.md` Sections 4, 6, 8, and 13
- Walk-forward synthesis Sections 4, 5, and 7

### Classification

```yaml
type: public_api
surface: walk_forward_inspection
scope: results_scores_folds
```

---

## LDG-2622: Candidate Extraction And Promotion Provenance

Priority: P0
Effort: L
Dependencies: LDG-2621
Status: Planned

### Description

Add explicit candidate extraction from walk-forward sessions and make extracted
candidates promotion-ready without adding walk-forward-specific promotion.

### Tasks

- Implement `ledgr_walk_forward_extract_candidate(session_id, fold_seq,
  selection_rationale = NULL)`.
- Require `fold_seq`; no implicit default.
- Support integer `fold_seq`.
- Support explicit `fold_seq = "latest"` sentinel.
- Require non-empty `selection_rationale` for `"latest"`.
- Fail with `ledgr_walk_forward_latest_without_rationale` when required
  rationale is missing.
- Capture session, fold, selected metric, test metric, cost identity, risk
  identity, execution seed, and rationale in candidate provenance.
- Ensure `ledgr_promote()` respects the extracted candidate's cost and risk
  identity.

### Acceptance Criteria

- Extraction fails when `fold_seq` is omitted.
- Extraction fails when `fold_seq = "latest"` lacks rationale.
- Extraction with integer fold sequence does not require a rationale.
- Extracted candidates carry enough reproduction identity to call
  `ledgr_promote()`.
- Candidate cost and risk identity win over mismatching target experiment cost
  or risk objects during promotion.
- No `ledgr_promote_walk_forward()`, parameter-path promotion, or
  selection-rule promotion is added.

### Verification

Extraction tests, missing-argument tests, latest-without-rationale tests,
provenance JSON tests, promotion tests, cost/risk mismatch tests, and reopened
session extraction tests.

### Source Reference

- `v0_1_9_4_spec.md` Sections 4, 7, 11, 12, and 16
- Walk-forward synthesis Sections 5, 11, 16.4, and 17.1

### Classification

```yaml
type: promotion
surface: walk_forward_candidate_extraction
scope: explicit_extraction_and_promotion_provenance
```

---

## LDG-2623: Degradation Table And Print UX

Priority: P0
Effort: M
Dependencies: LDG-2622
Status: Planned

### Description

Make train-vs-test degradation the first-class default walk-forward print and
summary surface.

### Tasks

- Build the per-fold degradation table.
- Include `fold_seq`, `train_window`, `test_window`, `selected_candidate`,
  `selection_metric`, `train_metric_value`, `test_metric_value`,
  `metric_diff_abs`, `metric_diff_pct`, and `warning_flags`.
- Enforce same-scale train/test metric values.
- Add `short_test_window` warning flag for test windows shorter than 90
  calendar days.
- Add `cold_start_distorted` warning flag for flat-test opt-in.
- Render the degradation table before any secondary print surfaces.
- Provide programmatic access to the degradation table even when print output
  is compressed.

### Acceptance Criteria

- Every required degradation-table field is present.
- The degradation table precedes secondary surfaces in default print order.
- Secondary surfaces do not visually dominate the degradation table.
- Short-test-window and cold-start-distorted flags are surfaced per affected
  row.
- Programmatic access returns the same fields used by print.

### Verification

Print tests, degradation-table field tests, warning-flag tests,
same-scale tests, short-window tests, cold-start flag tests, and print-order
structural tests.

### Source Reference

- `v0_1_9_4_spec.md` Sections 10, 12, 13, 14, and 16
- Walk-forward synthesis Sections 16.5 and 17.1

### Classification

```yaml
type: ux
surface: walk_forward_results
scope: degradation_table_print
```

---

## LDG-2624: Documentation, Examples, And NEWS

Priority: P1
Effort: L
Dependencies: LDG-2619, LDG-2622, LDG-2623
Status: Planned

### Description

Document the walk-forward MVP, including the required survivorship,
compute-scaling, path-dependency, and selection-integrity caveats.

### Tasks

- Add help pages for fold constructors, selection rules, `ledgr_walk_forward()`,
  inspection helpers, and extraction helper.
- Add a walk-forward vignette or article.
- Include the binding survivorship sentence or maintainer-approved equivalent:
  "Walk-forward evidence is only as survivorship-safe as the sealed snapshot
  and universe semantics it evaluates."
- Document anchored-fold compute scaling.
- Document `carry_test_state` path dependency and non-independence of per-fold
  test metrics.
- Document that scalar v1 scores are not PBO/CSCV/CPCV/DSR.
- Document explicit extraction and promotion workflow.
- Add NEWS entry naming scope and non-scope.

### Acceptance Criteria

- Documentation teaches `train sweep -> scalar selection -> test run ->
  explicit candidate extraction`.
- Docs state reproducibility and selection integrity are orthogonal.
- Required survivorship, compute-scaling, and path-dependency caveats are
  present.
- Docs do not imply statistical validation, benchmark diagnostics, OMS,
  paper/live behavior, or selection-integrity correction.
- Examples are runnable under package examples or explicitly marked as
  design-only where needed.

### Verification

Documentation tests, example tests, vignette/article checks, NEWS review,
stale-reference checks, and Section 17 caveat trace checks.

### Source Reference

- `v0_1_9_4_spec.md` Sections 12 and 14
- Walk-forward synthesis Sections 14.4, 14.5, 16.6, and 17.1

### Classification

```yaml
type: documentation
surface: walk_forward_docs
scope: examples_news_vignette
```

---

## LDG-2625: Release Surfaces And Planning Docs

Priority: P1
Effort: M
Dependencies: LDG-2624
Status: Planned

### Description

Update package and design surfaces so v0.1.9.4 is discoverable and the roadmap
hands off to v0.1.9.5 cleanly.

### Tasks

- Update `DESCRIPTION` version metadata when release gate begins.
- Update `NEWS.md`.
- Update `inst/design/README.md`.
- Update `inst/design/ledgr_roadmap.md`.
- Update `inst/design/horizon.md` closeout / carry-forward entries.
- Update `AGENTS.md` active packet context.
- Update identity/reference docs if walk-forward identity fields are surfaced.
- Check generated Rd references after roxygen.

### Acceptance Criteria

- Public release surfaces identify v0.1.9.4 walk-forward scope accurately.
- Roadmap marks v0.1.9.3 complete, v0.1.9.4 active during implementation, and
  v0.1.9.5 as the next planned entropy-management packet.
- Horizon entries consumed by v0.1.9.4 are closed or explicitly carried
  forward.
- No planning doc claims selection-integrity diagnostics or v0.2.x features
  shipped in v0.1.9.4.

### Verification

Documentation-contract tests, stale-reference `rg` checks, version checks,
NEWS review, roadmap/horizon review, AGENTS review, and generated-doc checks.

### Source Reference

- `v0_1_9_4_spec.md` Sections 14, 15, and 17
- `inst/design/release_ci_playbook.md`
- `inst/design/ledgr_roadmap.md`
- `inst/design/horizon.md`

### Classification

```yaml
type: release_surface
surface: planning_docs
scope: v0.1.9.4_release_surfaces
```

---

## LDG-2626: v0.1.9.4 Release Gate

Priority: P0
Effort: M
Dependencies: LDG-2612, LDG-2613, LDG-2614, LDG-2615, LDG-2616, LDG-2617, LDG-2618, LDG-2619, LDG-2620, LDG-2621, LDG-2622, LDG-2623, LDG-2624, LDG-2625
Status: Planned

### Description

Run the v0.1.9.4 release gate under the release CI playbook, record closeout
evidence, and prepare the branch for merge/tag.

### Tasks

- Read `inst/design/release_ci_playbook.md` before starting the gate.
- Run targeted walk-forward tests.
- Run full local test suite.
- Run package build and check.
- Run coverage gate.
- Run documentation and generated-doc checks.
- Check diff size before broad release-surface edits; stop if large unexpected
  diffs appear.
- Push branch and monitor remote CI.
- Merge, tag, and publish release only after playbook gates pass.
- Write `v0_1_9_4_release_closeout.md`.

### Acceptance Criteria

- All Section 17 release-gate criteria are either complete or explicitly
  carried forward with maintainer-approved override and named target.
- Local and remote release gates pass.
- Release closeout records local commands, remote CI, failures, fixes, and tag.
- No generated local artifacts are committed.
- v0.1.9.4 is merged and tagged only after the playbook is followed.

### Verification

Targeted tests, full tests, R CMD build, R CMD check, coverage gate, docs
checks, release-playbook checklist, GitHub Actions checks, release closeout,
merge verification, and tag verification.

### Source Reference

- `v0_1_9_4_spec.md` Section 17
- `inst/design/release_ci_playbook.md`

### Classification

```yaml
type: release_gate
surface: release_process
scope: v0.1.9.4
```
