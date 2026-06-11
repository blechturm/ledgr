# ledgr v0.1.9.4 Batch Plan

**Status:** Batch 2 ready for Claude review.

This batch plan sequences the v0.1.9.4 walk-forward packet without expanding
scope beyond `v0_1_9_4_spec.md` and the accepted
`rfc_walk_forward_evaluation_v0_1_9_x_synthesis.md`, including Amendment 1,
Amendment 2, and the Section 17 ticket-cut gate matrix. The packet deliberately
separates fold/window mechanics, feature validation, selection identity,
persistence, orchestration, inspection/promotion, print UX, docs, and release
surfaces so review can attribute behavior changes.

## Review Protocol

Each implementation batch stops after local verification and asks for Claude
review. The branch is not committed before review. After review, maintainer
disposition decides whether to patch, commit, and move to the next batch.

If a batch requires a broad diff outside its listed tickets, stop before
expanding scope and write a short disposition note. Small mechanical follow-on
edits are acceptable when directly required by the batch exit criteria.
Stop on any scope-content creep into the deferred areas below, regardless of
diff size.

No batch may add selection-integrity diagnostics, PBO/CSCV/CPCV, DSR,
purging/embargo, randomized or blocked slice protocols, cross-snapshot
walk-forward, walk-forward inside sweep composition, ML-first training hooks,
selection-session archive / evaluation registry, candidate clustering,
benchmark-relative metrics, top-N or all-candidate test retention,
gross-vs-net attribution, signal decay, implementation/cost decay,
PerformanceAnalytics adapters, liquidity/capacity policy, OMS behavior,
paper/live walk-forward, target-construction helper expansion, risk-chain
constraint expansion, crypto-readiness work, or compiled-core architecture
changes.

## Batch 0 - Packet Review And Batch Plan Alignment

Ticket: `LDG-2612`
Status: Completed

Goal: finalize the packet cut and review `v0_1_9_4_spec.md`,
`v0_1_9_4_tickets.md`, `tickets.yml`, `README.md`, and this batch plan as one
aligned planning surface.

Exit criteria:

- Spec, tickets, YAML, README, and batch plan agree on scope, IDs,
  dependencies, statuses, and release gates.
- Claude review findings against the spec amendments, ticket cut, and batch
  plan are patched or explicitly accepted by maintainer decision.
- Every Section 17 packet-open gate has an owning ticket:
  - train-fold scoring correction: `LDG-2614`;
  - `carry_test_state` / `flat_test_state`: `LDG-2619` and `LDG-2623`;
  - fail-closed metric classification: `LDG-2616`;
  - no-default extraction and rationale: `LDG-2622`;
  - operational print contract: `LDG-2623`;
  - feature-windowing determinism and cross-fold train-score stability:
    `LDG-2615`;
  - survivorship-bias vignette sentence: `LDG-2624`;
  - compute-scaling and path-dependency caveats: `LDG-2624`.
- Roadmap, horizon, design index, and AGENTS identify v0.1.9.4 as the active
  packet where appropriate before implementation starts.

Review focus:

- The batch boundaries follow the ticket dependency graph.
- The first implementation batch starts from fold/window value objects and
  direct-window parity, not walk-forward orchestration.
- Section 17 gates are concrete enough for release-gate review.
- The packet does not smuggle in validation diagnostics, evaluation registry,
  candidate clustering, ML-first work, or OMS/paper-live behavior.

Closeout notes:

- Claude packet-alignment review found no blockers and approved committing
  Batch 0.
- `LDG-2612` is completed in both ticket records.
- Roadmap, design index, horizon, and `AGENTS.md` now identify v0.1.9.4 as
  the active packet and v0.1.9.3 as the latest completed packet.
- No runtime implementation started before Claude review closed.

## Batch 1 - Fold Objects And Window Parity Substrate

Tickets: `LDG-2613`, `LDG-2614`
Status: Completed

Goal: add fold constructors, fold-list identity, and the internal window
contract that lets run and sweep execute the same scoring windows.

Exit criteria:

- `ledgr_fold()`, `ledgr_folds_rolling()`, and `ledgr_folds_anchored()` exist
  and validate calendar-time windows.
- `fold_id` and `fold_list_hash` are deterministic and byte-stable.
- `gap = NULL` is the only accepted v1 gap behavior.
- The internal window helper, working name `ledgr_experiment_window()`, is not
  exported.
- Rolling and anchored train-window parity tests assert the full stored train
  window is scored.
- Selected test run parity matches direct windowed `ledgr_run()`.
- Final-bar no-fill behavior remains unchanged at `scoring_end`.
- A structural guard rejects walk-forward-specific pulse-loop logic in the fold
  core.

Review focus:

- Windowing is shared run/sweep machinery, not a walk-forward pulse loop.
- Rolling and anchored folds use the Amendment 1 corrected train scoring
  semantics.
- No market-calendar, purged, embargoed, randomized, blocked, state-aware, or
  cross-snapshot fold behavior is introduced.

Implementation notes:

- Added public fold constructors and deterministic fold-list identity in
  `R/walk-forward-folds.R`, with `gap = NULL` as the only accepted v1 shape.
- Added an internal experiment-window contract plus internal run/sweep window
  entry points without exposing public `window` arguments on `ledgr_run()` or
  `ledgr_sweep()`.
- Added tests for fold identity, rolling/anchored full-train-window semantics,
  selected windowed run/sweep parity, final-bar no-fill behavior at
  `scoring_end`, export locking, and the fold-core structural guard.

Verification:

- `testthat::test_file("tests/testthat/test-walk-forward-folds.R")`
- `testthat::test_file("tests/testthat/test-api-exports.R")`
- `testthat::test_file("tests/testthat/test-sweep.R")`
- `testthat::test_file("tests/testthat/test-sweep-parity.R")`
- `testthat::test_file("tests/testthat/test-experiment-run.R")`

## Batch 2 - Feature Windows And Selection Rules

Tickets: `LDG-2615`, `LDG-2616`
Status: Review Pending

Goal: make fold windows safe for precomputed features and add ledgr-owned
scalar selection rules with fail-closed metric classification.

Exit criteria:

- Precomputed-feature validation covers snapshot hash, feature identities,
  scoring range coverage, and hydration range coverage.
- Feature-windowing determinism and cross-fold train-score stability tests
  exist and pass.
- `ledgr_select_argmax()` and `ledgr_select_argmin()` exist and are exported.
- Selection rules derive deterministic `selection_rule_hash`.
- Missing metric, no finite candidates, and invalid metric class fail with
  classed conditions.
- `total_return` and `n_trades` fail closed as selection metrics.
- A permitted metric such as `sharpe_ratio` can be selected.

Review focus:

- Metric classification lives with metric definitions or an explicitly chosen
  metric metadata substrate, not inside ad hoc selection-rule code.
- If no suitable substrate exists, Batch 2 defines a minimal internal
  classified-metric registry and records the disposition in closeout.
- Selection rules see train-window score rows only.
- Composite selection, override selection, top-N selection, and arbitrary
  function selectors remain deferred.

Implementation notes:

- Extended internal precomputed-feature validation to accept fold-window
  metadata and distinguish exact ordinary sweep ranges from fold-window
  coverage checks.
- Added projection slicing so a broader precomputed feature payload can be
  reused safely against a narrower fold scoring window.
- Added public `ledgr_select_argmax()` and `ledgr_select_argmin()` selection
  rule constructors with deterministic `selection_rule_hash`.
- Added a minimal internal metric-classification registry for v1 selection.
  The registry is intentionally internal in this batch because ledgr does not
  yet expose a general metric-definition metadata substrate.
- Selection rules fail closed on missing metrics, no finite eligible values,
  and invalid metric classes such as `total_return` and `n_trades`.

Verification:

- `testthat::test_file("tests/testthat/test-walk-forward-selection.R")`
- `testthat::test_file("tests/testthat/test-precompute-features.R")`
- `testthat::test_file("tests/testthat/test-api-exports.R")`
- `testthat::test_file("tests/testthat/test-sweep.R")`
- `testthat::test_file("tests/testthat/test-sweep-parity.R")`
- `testthat::test_file("tests/testthat/test-walk-forward-folds.R")`

## Batch 3 - Identity And Persistence Foundation

Tickets: `LDG-2617`, `LDG-2618`
Status: Review Pending

Goal: add walk-forward candidate/session identity, deterministic per-row seeds,
and compact persistence tables before orchestration writes real sessions.

Exit criteria:

- `candidate_key` includes params, feature params, strategy, feature set,
  alias map, metric context, cost model, risk chain, execution seed, and schema
  version.
- `session_id` includes snapshot, experiment, parameter grid, fold list,
  selection rule, metric context, cost model, risk chain, master seed, opening
  state policy, schema version, and ledgr version.
- `experiment_hash` is derived from the normalized config-hash payload family
  after removing separately hashed cost, risk, metric-context, and seed
  components.
- Transient `sweep_id`, row order, display label, and `run_id` are excluded.
- Per-row `execution_seed` is deterministic from `master_seed`, fold sequence,
  train/test window marker, and `candidate_key`.
- `walk_forward_sessions`, `walk_forward_folds`, and `walk_forward_scores`
  schemas exist and validate.
- Selected test runs link through `test_run_id`.
- Cost and risk plan bytes are not duplicated into walk-forward tables;
  reconstruction goes through the linked selected test run config.
- No new accounting, ledger, fill, trade, or equity semantics are introduced.

Review focus:

- Cost identity from v0.1.9.1 and risk identity from v0.1.9.3 are consumed in
  both candidate and session identity.
- Persistence is compact evidence, not a committed run for every candidate.
- Schema writes are transactional at fold/session boundaries.

## Batch 4 - Walk-Forward Orchestrator And Opening State

Ticket: `LDG-2619`
Status: Review Pending

Goal: implement `ledgr_walk_forward()` as the train-sweep, select, test-run
orchestrator with explicit opening-state policy.

Exit criteria:

- Each fold runs `ledgr_sweep()` on the train scoring window.
- Selection uses the current fold's train score rows only.
- The selected candidate runs through `ledgr_run()` on the test scoring
  window.
- Happy-path session metadata, fold metadata, and `DONE` train/test score rows
  are written.
- `opening_state_policy = "carry_test_state"` is the default.
- `opening_state_policy = "flat_test_state"` is explicit opt-in only.
- Flat-test opt-in emits `ledgr_walk_forward_cold_start_warning`.
- Flat-test opt-in records `cold_start_distorted` metadata for print.
- Train sweeps always start from the experiment opening state.
- Running the same session inputs twice reproduces `session_id`, ordered fold
  IDs, selected candidates, per-row seeds, and selected test-run results.

Review focus:

- The orchestrator does not accept full-snapshot sweep input as fold-local
  selection evidence.
- The orchestrator does not accept preselected candidates and report them as
  fold-selected.
- Carry-test-state path dependency is intentional and visible.
- Top-N/all-candidate test retention remains deferred.

Implementation note:

- Added `ledgr_walk_forward()` as a fold-local train-sweep, deterministic
  selection, selected-test-run orchestrator over existing `ledgr_sweep_window()`
  and `ledgr_run_window()` helpers.
- Added an internal-only sweep execution-seed resolver so walk-forward can use
  fold/window/candidate identity seeds without changing public sweep seed
  semantics.
- Persisted happy-path `walk_forward_sessions`, `walk_forward_folds`, and
  `walk_forward_scores` rows; richer failure/partial handling remains in
  Batch 5.

## Batch 5 - Score Rows, Failures, And Partial Sessions

Ticket: `LDG-2620`
Status: Review Pending

Goal: make fold score rows, candidate failures, no-selection failures, test-run
failures, interrupts, and partial sessions inspectable.

Exit criteria:

- The happy-path row writing from Batch 4 is extended with
  `FAILED`/`INTERRUPTED`/`PARTIAL` branches and classed conditions.
- Train score rows are written for all train candidates or train candidate
  failures.
- Test score rows are written only for the selected candidate in v1.
- Candidate failure rows preserve `status`, `error_class`, and `error_msg`.
- Selected test runs that produce no equity row or unusable metrics are marked
  as `FAILED`, not as `DONE` rows with missing metric values.
- If no finite eligible candidate remains, the fold fails with
  `ledgr_walk_forward_no_selection`.
- Test-run failure marks the fold and session failed while preserving train
  rows.
- User interrupt produces `INTERRUPTED` or `PARTIAL` according to the spec's
  discriminator.
- `ledgr_walk_forward()` does not resume partial sessions in v1.

Review focus:

- Failure capture does not hide failed candidates or turn them into implicit
  zero/flat results.
- Partial evidence is inspectable but not represented as a complete session.
- No per-pulse DB writes are added.

Implementation note:

- Extended the Batch 4 walk-forward writer into fold/session terminal states:
  `DONE`, `FAILED`, `INTERRUPTED`, and `PARTIAL`. Train candidate failures
  remain score rows with stored sweep failure classes, no-selection and
  selected test-run failures preserve train evidence before rethrowing, and
  user interrupts persist only completed fold evidence.

## Batch 6 - Inspection, Reopen, Extraction, And Promotion

Tickets: `LDG-2621`, `LDG-2622`
Status: Review Pending

Goal: expose read-only walk-forward inspection helpers and explicit
promotion-ready candidate extraction.

Exit criteria:

- `ledgr_walk_forward_results()`, `ledgr_walk_forward_scores()`, and
  `ledgr_walk_forward_folds()` are read-only.
- Completed and partial sessions can be inspected.
- Reopen verifies snapshot, schema, cost, risk, and metric identity.
- `ledgr_walk_forward_extract_candidate()` requires `fold_seq`.
- `fold_seq = "latest"` requires non-empty `selection_rationale`.
- Missing latest rationale fails with
  `ledgr_walk_forward_latest_without_rationale`.
- Extracted candidates carry session, fold, metric, cost, risk, seed, and
  rationale provenance.
- `ledgr_promote()` respects the extracted candidate's cost and risk identity.

Review focus:

- No helper mutates, recomputes, or re-executes.
- Extraction is explicit enough for audit, especially `"latest"`.
- No `ledgr_promote_walk_forward()`, parameter-path promotion, or
  selection-rule promotion is added.

Implementation note:

- Added read-only persisted-session helpers that require an explicit snapshot
  locator, verify walk-forward schema plus linked test-run cost/risk/metric
  identity, and rebuild completed/partial `ledgr_walk_forward_results` from
  stored rows only. Candidate extraction now returns an ordinary
  `ledgr_sweep_candidate` from a chosen fold, requires rationale for
  `"latest"`, carries walk-forward provenance, and `ledgr_promote()` now lets
  candidate cost identity win alongside risk identity.

## Batch 7 - Degradation UX And User Documentation

Tickets: `LDG-2623`, `LDG-2624`
Status: Review Pending

Goal: make train-vs-test degradation the primary result surface and document
walk-forward honestly.

Exit criteria:

- The degradation table includes all required fields from the spec.
- The degradation table appears before secondary surfaces in default print.
- `short_test_window` and `cold_start_distorted` flags are surfaced.
- Programmatic access returns the degradation table fields.
- Help pages cover fold constructors, selection rules, walk-forward execution,
  inspection, and extraction.
- A walk-forward vignette or article teaches the procedural workflow.
- The required survivorship-bias sentence is present.
- Anchored-fold compute scaling and `carry_test_state` path dependency caveats
  are documented.
- NEWS names the MVP scope and non-scope.

Review focus:

- Print teaches degradation before equity-curve excitement.
- Documentation does not claim PBO/CSCV/DSR, statistical validation,
  benchmark diagnostics, OMS, paper/live behavior, or selection-integrity
  correction.
- Examples are runnable or explicitly design-only.

Implementation note:

- Added a programmatic `degradation` table to live and reopened
  walk-forward results, made it the first default print surface, and surfaced
  `short_test_window` plus `cold_start_distorted` warning flags. Added
  walk-forward help-page caveats, a design-only workflow vignette, pkgdown
  discovery, and NEWS scope/non-scope language.

## Batch 8 - Release Surfaces And Planning Docs

Ticket: `LDG-2625`
Status: Planned

Goal: update version, roadmap, horizon, design index, AGENTS, identity docs,
and generated documentation surfaces before the release gate.

Exit criteria:

- `DESCRIPTION`, `NEWS.md`, design index, roadmap, horizon, and AGENTS are
  updated consistently.
- Roadmap marks v0.1.9.3 complete, v0.1.9.4 active during implementation, and
  v0.1.9.5 next.
- Horizon entries consumed by v0.1.9.4 are closed or carried forward.
- Identity/reference docs name walk-forward `candidate_key` and `session_id`
  where appropriate.
- Generated Rd references are checked after roxygen.

Review focus:

- Release surfaces do not overclaim statistical validation or v0.2.x features.
- Roadmap/horizon transitions are clean enough for v0.1.9.5 scoping.
- Diff size is monitored; stop if release-surface edits become unexpectedly
  broad.

## Batch 9 - Release Gate

Ticket: `LDG-2626`
Status: Planned

Goal: follow the release playbook until v0.1.9.4 is merged and tagged.

Exit criteria:

- `inst/design/release_ci_playbook.md` is read before starting.
- Targeted walk-forward tests pass.
- Full local tests pass.
- Package build and check pass.
- Coverage gate passes.
- Documentation and generated-doc checks pass.
- Release closeout records local commands, remote CI, failures, fixes, and tag.
- Branch is pushed, remote CI is monitored, PR is merged, and tag/release are
  created only after playbook gates pass.

Review focus:

- Release gate follows the playbook exactly.
- If large unexpected diffs are needed to pass the gate, stop and ask before
  continuing.
- Generated local artifacts are not committed.
