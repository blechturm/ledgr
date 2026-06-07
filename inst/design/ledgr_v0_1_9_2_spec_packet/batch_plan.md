# ledgr v0.1.9.2 Batch Plan

**Status:** Batch 5 implementation ready for Claude review.

This batch plan sequences the v0.1.9.2 sweep artifact persistence packet
without expanding scope beyond `v0_1_9_2_spec.md` and the accepted
`rfc_sweep_artifact_persistence_v0_1_9_x_synthesis.md`. Saved sweeps,
retained net equity/return series, candidate identity cleanup, reopened-sweep
compatibility, and release-gate storage evidence are reviewed in separate
units so behavior changes stay attributable.

## Review Protocol

Each implementation batch stops after local verification and asks for Claude
review. The branch is not committed before review. After review, maintainer
disposition decides whether to patch, commit, and move to the next batch.

If a batch requires a broad diff outside its listed tickets, stop before
expanding scope and write a short disposition note. Small mechanical follow-on
edits are acceptable when they are directly required by the batch exit
criteria.

## Batch 0 - Packet Review And Batch Plan Alignment

Ticket: `LDG-2581`
Status: Completed

Goal: finalize the packet cut after RFC acceptance and review
`v0_1_9_2_spec.md`, `v0_1_9_2_tickets.md`, `tickets.yml`, `README.md`, and
this batch plan as one aligned planning surface.

Exit criteria:

- Spec, tickets, YAML, README, and batch plan agree on scope, IDs,
  dependencies, statuses, and release gates.
- Claude review findings against the ticket cut and batch plan are patched or
  explicitly accepted by maintainer decision.
- Roadmap, horizon, design index, and AGENTS identify v0.1.9.2 as the active
  packet.
- No ranking helpers, named selection views, automatic winner selection,
  benchmark-relative diagnostics, signal decay, walk-forward integration,
  schema migration machinery, or full per-candidate run artifacts are
  introduced.

Review focus:

- The batch boundaries follow the ticket dependency graph.
- The first implementation batch starts from retention identity, not
  persistence.
- The release gate names the storage smoke measurement and stale-claim
  searches before release work begins.

Review note:

- Claude packet-cut review was received on 2026-06-07.
- Minor observation 1 was applied by adding `LDG-2586` as a declared
  dependency of `LDG-2584` in both ticket files and documenting the shared
  dependency in the ticket-map diagrams.
- Minor observation 2 was already satisfied: `tickets.yml` includes
  `batch_plan_review` for `LDG-2581`.
- Batch 0 was committed in `5d7663b` after positive review.

## Batch 1 - Retention Surface And Identity Floor

Tickets: `LDG-2582`, `LDG-2583`
Status: Completed

Goal: add the public retention constructor and `ledgr_sweep()` argument while
proving that retention is non-identity before any retained rows or saved-sweep
tables exist.

Exit criteria:

- `ledgr_sweep_retention(returns = c("none", "completed"))` validates and
  serializes as a stable retention object.
- `ledgr_sweep(retain = ledgr_sweep_retention())` preserves current
  scalar-only behavior by default.
- Retention metadata is inspectable as `attr(sweep, "sweep_retention")`.
- Retention policy is absent from `config_hash_payload()`,
  `execution_assumptions`, and candidate reproduction keys.
- Scalar-only and retained sweeps over the same inputs produce identical
  scalar results and identity surfaces.

Review focus:

- Retention changes output retention only; they do not alter execution,
  strategy context, feature identity, metric context, cost identity, seed
  derivation, or candidate scoring.
- Invalid retention values fail before candidate dispatch.
- No persistence API is introduced in this batch.

Implementation note:

- Added `ledgr_sweep_retention()` and `retain = ledgr_sweep_retention()` on
  `ledgr_sweep()`.
- Attached `attr(out, "sweep_retention")` to sweep results.
- Defensively excluded sweep retention metadata from `config_hash_payload()`.
- Verified scalar rows, execution assumptions, and candidate reproduction keys
  are unchanged modulo sweep id for `returns = "none"` versus
  `returns = "completed"`.
- No retained return/equity series capture and no persistence API were added.
- Batch 1 was committed in `75d80f5` after positive Claude review.

## Batch 2 - Candidate Identity Rename And Row Key

Ticket: `LDG-2586`
Status: Completed

Goal: rename public sweep candidate identifiers from candidate-row `run_id` to
`candidate_id` and bind `candidate_row` before persistence schema work depends
on those names.

Exit criteria:

- Sweep result rows expose `candidate_id`, not candidate-row `run_id`.
- Committed runs and promoted runs continue to use `run_id`.
- `candidate_row` is present where needed as the 1-indexed original sweep row
  position.
- `ledgr_candidate()` works with filtered, sorted, and sliced sweep results.
- Promotion context records the selected candidate using the public
  `candidate_id` contract.

Review focus:

- The pre-CRAN rename is limited to sweep candidate rows.
- Committed-run identity and existing run-store APIs do not drift.
- dplyr survivability is preserved for candidate extraction.

Implementation note:

- Renamed public sweep result rows from `run_id` to `candidate_id`.
- Added `candidate_row` as the 1-indexed original grid row carried through
  candidate extraction, reproduction keys, and promotion context.
- Kept committed-run `run_id` semantics and internal event/run handlers
  unchanged.
- Updated focused tests, sweep-facing examples, NEWS, and candidate help text.
- Verified `test-sweep.R`, `test-sweep-retention.R`,
  `test-promotion-context.R`, and `test-sweep-parallel.R`.
- Batch 2 was committed in `ca780cf` after positive Claude review.

## Batch 3 - In-Memory Retained Series And Accessors

Tickets: `LDG-2584`, `LDG-2585`
Status: Completed

Goal: capture pulse-aligned net portfolio equity and adjacent-period returns
for completed in-memory sweep candidates, then expose long and wide accessors
before durable persistence is wired.

Exit criteria:

- `returns = "completed"` retains one row per scoring pulse for completed
  candidates only.
- Failed candidates remain in scalar summary rows and have no retained return
  rows.
- `period_return` has a leading `NA_real_` per candidate.
- Final-bar no-fill keeps the final scoring-pulse equity row; the warning
  remains on the candidate summary row.
- `ledgr_sweep_returns()` and `ledgr_sweep_returns_wide()` work for in-memory
  sweeps and expose classed errors for unretained, missing, and failed
  candidates.
- In-memory accessor output uses `attr(sweep, "sweep_id")` for the `sweep_id`
  column.

Review focus:

- Retained series are net portfolio equity/returns only.
- The implementation reuses the existing sweep summary / fold-core output
  path and does not introduce a second execution engine.
- Wide accessors materialize in memory only; no lazy or pushed-down pivot is
  introduced.

Implementation note:

- Captured retained net equity and adjacent-period return rows for completed
  candidates when `retain = ledgr_sweep_retention("completed")`.
- Stored retained rows as sweep metadata and kept scalar candidate rows
  unchanged.
- Added `ledgr_sweep_returns()` and `ledgr_sweep_returns_wide()`.
- Added classed errors for unretained sweeps, missing candidates, and failed
  candidates.
- Verified leading `NA_real_` returns, final-bar no-fill final equity row
  retention, failed-candidate absence from retained rows, and R versus compiled
  spot-FIFO retained-series parity on the focused fixture.
- Reopened-sweep accessor parity remains gated by the saved-sweep API batches;
  Batch 3 reviews the in-memory accessor surface only.
- Verified `test-sweep-retention.R`, `test-sweep.R`,
  `test-sweep-parallel.R`, and `test-api-exports.R`.
- Batch 3 was committed in `15bbcc5` after positive Claude review.

## Batch 4 - Saved Sweep Schema And Canonical JSON

Ticket: `LDG-2587`
Status: Completed

Goal: add the compact saved-sweep DuckDB schema and canonical JSON storage
contract before public save/open APIs depend on it.

Exit criteria:

- `sweeps`, `sweep_candidates`, and `sweep_returns` tables exist with
  synthesis Section 6 columns and nullability.
- All `*_json` fields on `sweeps` and `sweep_candidates` use
  `canonical_json()`.
- `cost_model_hash` and `cost_plan_json` are stored on `sweeps`.
- Candidate-level denormalized `feature_set_hash`, `metric_context_hash`, and
  `cost_model_hash` are validated against authoritative parent/provenance
  fields.
- `sweep_returns` uses `(sweep_id, candidate_row, pulse_index)` as primary
  key.
- DuckDB NULL in `period_return` round-trips to R `NA_real_`.

Review focus:

- Storage shape remains compact and does not store full ledgers, fills, trades,
  or per-instrument artifacts.
- Whole-second UTC timestamp semantics match the existing POSIXct / DuckDB
  TIMESTAMP convention.
- Schema versioning is fail-closed; no migration machinery is introduced.

Implementation note:

- Added `sweeps`, `sweep_candidates`, and `sweep_returns` to the
  experiment-store schema and bumped the experiment-store schema version to
  109.
- Added compact saved-sweep storage projection helpers that produce canonical
  JSON for bound `*_json` fields without adding public save/open APIs.
- Validated denormalized candidate feature, cost, and metric identity before
  producing storage candidate rows.
- Bound `sweep_returns` to `(sweep_id, candidate_row, pulse_index)` and added
  the timestamp scan index.
- Kept public `candidate_id` separate from committed-run `run_id`; the saved
  candidate schema has no `run_id` column.
- Verified `test-sweep-persistence-schema.R`, `test-schema.R`,
  `test-experiment-store-schema.R`, and `test-sweep-retention.R`.
- Batch 4 was committed after positive Claude review; non-blocking follow-up
  observations were routed to the save/open and round-trip batches.

## Batch 5 - Save/Open/List/Info APIs And Validation

Tickets: `LDG-2588`, `LDG-2590`
Status: Review Pending

Goal: add public saved-sweep APIs and validation rules on top of the bound
schema, including reopened object metadata and classed failure modes.

Exit criteria:

- `ledgr_sweep_save()`, `ledgr_sweep_open()`, `ledgr_sweep_list()`, and
  `ledgr_sweep_info()` are implemented.
- `ledgr_sweep_save()` writes scalar rows and retained returns when present.
- `sweep_id = NULL` persists under the in-session sweep id.
- Explicit `sweep_id` save/open works without mutating the caller's in-memory
  object.
- `note` validates as `NULL` or a length-one character scalar.
- Reopened saved-sweep objects print with sweep id, candidate counts,
  retention status, and identity summary.
- Invalid id, duplicate id, snapshot absence, snapshot hash mismatch, and
  incompatible schema failures raise documented classed conditions.

Review focus:

- Save/open/list/info APIs operate on saved sweeps, not committed runs.
- `ledgr_sweep_info()` accepts objects and rejects bare ids.
- Validation fails before partial writes where applicable.

Implementation note:

- Added `ledgr_sweep_save()`, `ledgr_sweep_open()`, `ledgr_sweep_list()`,
  and `ledgr_sweep_info()`.
- Saved sweeps write compact scalar candidate rows and retained returns when
  present; no ledgers, fills, trades, or committed-run artifacts are written.
- Reopened saved sweeps materialize eagerly as `ledgr_sweep_results`-
  compatible objects and carry saved-artifact metadata.
- Added classed validation for invalid ids, duplicate ids, snapshot absence,
  snapshot hash mismatch, and incompatible saved-sweep schemas.
- `ledgr_sweep_info()` accepts in-memory/reopened sweep objects and rejects
  bare ids.
- Reopened candidate extraction, promotion, and dplyr survivability remain
  gated by Batch 6.
- Verified `test-sweep-persistence-api.R`, `test-api-exports.R`,
  `test-sweep-retention.R`, `test-sweep-persistence-schema.R`, and
  `test-schema.R`.

## Batch 6 - Reopened Sweep Compatibility And Round-Trip Survivability

Tickets: `LDG-2589`, `LDG-2593`
Status: Planned

Goal: make reopened saved sweeps behave like eager
`ledgr_sweep_results`-compatible objects for candidate extraction, promotion
readiness, retained-series access, info inspection, and dplyr/base subsetting.

Exit criteria:

- Reopened sweeps preserve reproduction metadata, feature identity, metric
  context, cost identity, retention metadata, and selection-view metadata.
- `ledgr_candidate()` works after filter, arrange, slice, and supported base
  subsetting.
- Promotion from reopened sweeps re-executes from the reproduction key.
- No code path commits saved scalar rows or retained returns as a run.
- Scalar rows, attributes, identity fields, retained equity, and retained
  returns round-trip under canonical ordering.
- `candidate_row` equals the 1-indexed original sweep row position after
  save/open and after dplyr operations.
- Reopened accessor output uses the durable saved sweep id for the `sweep_id`
  column.

Review focus:

- Reopened-only audit metadata is not compared as identity parity.
- dplyr survivability covers candidate extraction, returns, and info
  inspection.
- Promotion semantics remain reproduction-key based.

## Batch 7 - Retained-Series Parity And Storage Evidence

Tickets: `LDG-2591`, `LDG-2592`
Status: Planned

Goal: complete the retained-series release-gate matrix and record the accepted
storage smoke measurement before documentation and release surfaces describe
the feature as shipped.

Exit criteria:

- Retained series match inline-memory summary on R accounting.
- Retained series match inline-memory summary on compiled spot FIFO when the
  compiled path is available.
- Retained series match ordered-event reconstruction on R accounting.
- Retained series match ordered-event reconstruction on compiled spot FIFO
  when available.
- Final-bar no-fill and failed-candidate retained-series cases are covered.
- `sweep_retention_storage_smoke.md` records `expected_bytes`,
  `retained_db_delta_bytes`, and `ratio`.
- Storage gate passes with `ratio <= 2.0` or records maintainer sign-off.

Review focus:

- Events remain canonical evidence; retained series are derived artifacts.
- Compiled spot-FIFO tests use the existing availability guard.
- The storage smoke measurement is a sanity gate, not a public benchmark.

## Batch 8 - Documentation And Release Surfaces

Tickets: `LDG-2594`, `LDG-2595`
Status: Planned

Goal: document the saved-sweep workflow and update release/planning surfaces
after implementation and test evidence exists.

Exit criteria:

- Sweep vignette teaches scalar-only screening, in-session retained returns,
  durable saved sweeps, retained-series access, and evidence tiers.
- Help pages cover new public functions and classed conditions with runnable
  examples where appropriate.
- Docs state retained returns are net strategy returns only.
- Docs state promotion re-executes from the reproduction key.
- Docs show dropping leading `NA_real_` before external metric-package use.
- NEWS names saved sweeps, retained returns, `candidate_id`, and non-scope.
- Roadmap, horizon, design index, RFC index, and AGENTS reflect the
  implementation state without marking future packets as shipped.

Review focus:

- No docs imply ranking helpers, automatic selection, benchmark-relative
  diagnostics, signal decay, gross-vs-net attribution, schema migration,
  PerformanceAnalytics adapter, or walk-forward integration.
- Future obligations remain parked and non-authorizing.
- Documentation follows `inst/design/vignette_styleguide.md`.

## Batch 9 - Release Gate

Ticket: `LDG-2596`
Status: Planned

Goal: verify and close v0.1.9.2 after all implementation, documentation,
measurement, and release-surface tickets are complete.

Exit criteria:

- All prior tickets are complete or explicitly re-routed.
- Targeted saved-sweep, retained-series, schema, validation, candidate, and
  documentation checks pass.
- Full testthat suite passes or has maintainer-approved disposition.
- Package build/check passes per `release_ci_playbook.md` or has
  maintainer-approved disposition.
- Storage smoke measurement is recorded and passes or has maintainer sign-off.
- Generated docs, NEWS, and planning surfaces are reviewed.
- Stale-claim searches are anchored to synthesis Section 1 non-scope terms:
  `ranking`, `selection view`, `top.?n`, `winner`, `benchmark-relative`,
  `\balpha\b`, `\bbeta\b`, `gross-vs-net`, `signal decay`,
  `walk-forward integration`, `schema migration`, and
  `PerformanceAnalytics adapter`.
- Release closeout cites the accepted synthesis, this spec packet, and gate
  evidence.

Review focus:

- Do not merge or tag if a broad release-gate diff appears that has not been
  reviewed in an earlier implementation or documentation batch.
- The release gate verifies shipped behavior; it does not become a hidden
  implementation batch.
- The release playbook is read into context before package-gate work begins.
