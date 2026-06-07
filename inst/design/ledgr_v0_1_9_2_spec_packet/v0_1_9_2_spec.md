# ledgr v0.1.9.2 Spec

**Status:** Planning packet drafted 2026-06-07; Batch 5 saved-sweep API
implementation ready for Claude review.
**Target Branch:** `v0.1.9.2`.
**Scope:** Second packet in the v0.1.9.x four-tick arc. Ship durable sweep
artifact persistence plus optional retained net portfolio equity/return series
for completed sweep candidates. Preserve `ledgr_sweep()` as an execution
surface over the shared fold core; saved sweeps are compact evidence objects,
not committed runs.
**Ticket state:** Tickets are cut in `v0_1_9_2_tickets.md` and `tickets.yml`.
`LDG-2581`, `LDG-2582`, `LDG-2583`, `LDG-2584`, `LDG-2585`, and
`LDG-2586`, and `LDG-2587` are completed. `LDG-2588` and `LDG-2590` are
review pending. Reopened-sweep candidate/promotion parity and dplyr
survivability remain gated by the round-trip batches. Later implementation
tickets remain planned.
**Non-scope for this pass:** Ranking helpers, named selection views,
winner-picking, automatic promotion, full ledger/fill/trade/per-instrument
artifacts for every candidate, benchmark-relative diagnostics, signal decay,
implementation/cost decay, gross-vs-net attribution, liquidity, TCA, OMS,
taxes, financing, broker reconciliation, walk-forward integration, per-fold
retention dimensions, schema migration machinery, PerformanceAnalytics
adapter, and lazy/pushed-down wide pivots.

---

## 0. Source Inputs

Authoritative inputs:

- `inst/design/contracts.md`
- `inst/design/README.md`
- `inst/design/ledgr_roadmap.md`
- `inst/design/horizon.md`
- `inst/design/rfc_cycle.md`
- `inst/design/vignette_styleguide.md`
- `inst/design/release_ci_playbook.md`

Active packet scaffold:

- `inst/design/ledgr_v0_1_9_2_spec_packet/README.md`

Accepted RFC cycle:

- `inst/design/rfc/rfc_sweep_artifact_persistence_v0_1_9_x_seed.md`
- `inst/design/rfc/rfc_sweep_artifact_persistence_v0_1_9_x_response.md`
- `inst/design/rfc/rfc_sweep_artifact_persistence_v0_1_9_x_seed_v2.md`
- `inst/design/rfc/rfc_sweep_artifact_persistence_v0_1_9_x_synthesis.md`

Forward dependencies and cross-cycle context:

- `inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md`
- `inst/design/rfc/rfc_walk_forward_evaluation_v0_1_9_x_synthesis.md`
- `inst/design/rfc/rfc_chainable_risk_oms_policy_boundary_synthesis.md`
- `inst/design/manual/identity_contract.qmd`
- `inst/design/manual/sweep.qmd`
- `inst/design/manual/execution_fold_core.qmd`

Completed packet inputs:

- `inst/design/ledgr_v0_1_8_8_spec_packet/`
- `inst/design/ledgr_v0_1_8_9_spec_packet/`
- `inst/design/ledgr_v0_1_8_10_spec_packet/`
- `inst/design/ledgr_v0_1_8_11_spec_packet/`
- `inst/design/ledgr_v0_1_9_1_spec_packet/`

---

## 1. Thesis

`ledgr_sweep()` currently gives users a scalar candidate table that is good
for fast exploratory ranking, but weak as an audit artifact. Once the R session
ends, the candidate rows and warnings can disappear unless the user promotes a
candidate into a full committed run. That forces a false choice:

```text
cheap ephemeral sweep evidence
  or
full durable committed-run evidence for selected candidates
```

v0.1.9.2 adds the middle layer:

```text
compact saved sweep artifact
  = candidate rows + identity/provenance + optional net equity/return series
```

The packet makes expensive sweeps reopenable and auditable without storing full
ledgers, fills, trades, or per-instrument artifacts for every candidate. It also
creates the compact return-series substrate that later walk-forward and
selection-integrity work can consume, while keeping those later layers out of
scope.

The core design stance is:

- retention is non-identity;
- sweep persistence is not a second execution engine;
- saved sweeps are compact evidence, not committed runs;
- promotion still re-executes the selected candidate from its reproduction key;
- retained returns are net strategy returns, not benchmark-relative or
  gross-vs-net attribution.

---

## 2. Release Goals

v0.1.9.2 has seven planning goals.

### Sweep Retention Surface

1. Add `ledgr_sweep_retention(returns = c("none", "completed"))` and
   `retain = ledgr_sweep_retention()` on `ledgr_sweep()`. The default preserves
   current scalar-only sweep behavior. Retention policy is stored as metadata
   but excluded from execution identity, candidate identity, `config_hash`, and
   execution assumptions.

2. When `returns = "completed"`, retain pulse-aligned net portfolio equity and
   adjacent-period returns for completed candidates only. Failed candidates
   remain in the scalar summary table but have no retained return rows.

### Saved Sweep Artifact Surface

3. Add saved-sweep persistence APIs:

```r
ledgr_sweep_save(sweep, snapshot, sweep_id = NULL, note = NULL)
ledgr_sweep_open(snapshot, sweep_id)
ledgr_sweep_list(snapshot)
ledgr_sweep_info(x)
```

Saved sweeps live in the same experiment store as snapshots and runs. Open is
a promote-ready operation and requires the matching snapshot.

4. Add retained-series accessors:

```r
ledgr_sweep_returns(x, candidates = NULL)
ledgr_sweep_returns_wide(x, candidates = NULL, value = c("returns", "equity"))
```

The long accessor returns `sweep_id`, `candidate_id`, `ts_utc`, `equity`, and
`period_return`. The wide accessor returns one wide tibble per call.

### Identity, Schema, And Reopened UX

5. Persist compact DuckDB tables `sweeps`, `sweep_candidates`, and
   `sweep_returns` with canonical JSON fields, schema-version handling,
   snapshot verification, cost identity from v0.1.9.1, feature and metric
   context identity, candidate row order, and fail-closed incompatibility
   behavior.

6. Rename public sweep candidate identifiers from candidate-row `run_id` to
   `candidate_id` across sweep results, candidate extraction, persistence,
   docs, and NEWS. Committed runs still use `run_id`.

7. Reopened saved sweeps must behave like in-session `ledgr_sweep_results`
   objects for filtering, arranging, slicing, candidate extraction, promotion
   readiness, info inspection, and retained-series access.

---

## 3. Binding Boundaries

### 3.1 Synthesis Authority

`rfc_sweep_artifact_persistence_v0_1_9_x_synthesis.md` is binding for this
packet. If this spec and the synthesis conflict, the synthesis wins unless a
maintainer decision explicitly amends it before implementation starts.

### 3.2 Retention Is Non-Identity

`retain = ledgr_sweep_retention(returns = "none")` and
`retain = ledgr_sweep_retention(returns = "completed")` must produce identical
execution identity and scalar candidate results for the same candidate inputs.
The implementation must defensively exclude retention policy from
`config_hash_payload()` and candidate reproduction keys. Retention metadata is
storage/inspection state only.

### 3.3 Saved Sweeps Are Not Runs

Saved sweeps do not store full ledgers, fills, trades, or durable run equity
artifacts per candidate. `ledgr_promote()` from a reopened sweep re-executes the
selected candidate from the reproduction key against the sealed snapshot. It
does not commit stored scalar rows or retained return series as a run.

### 3.4 Candidate Rows And IDs

`candidate_row` is the compact durable candidate key. It is 1-indexed in the
original `ledgr_sweep_results` order, preserved by save/open, and does not
reorder under dplyr operations. `candidate_id` is the public sweep candidate
identifier. Current candidate-row `run_id` is renamed to `candidate_id`
pre-CRAN; committed runs retain `run_id`.

### 3.5 Reopened Sweeps Must Survive dplyr

Reopened sweeps are eager materialized `ledgr_sweep_results`-compatible
objects, not lazy database handles. Base subsetting and `dplyr::filter()`,
`dplyr::arrange()`, and `dplyr::slice()` must preserve the metadata required by
`ledgr_candidate()`, `ledgr_sweep_returns()`, `ledgr_sweep_info()`, and
promotion.

### 3.6 Classed Conditions

The packet introduces or binds these condition classes:

- `ledgr_sweep_returns_unretained`;
- `ledgr_sweep_returns_candidate_not_completed`;
- `ledgr_sweep_returns_candidate_not_found`;
- `ledgr_invalid_sweep_id`;
- `ledgr_sweep_id_exists`;
- `ledgr_sweep_snapshot_not_found`;
- `ledgr_sweep_snapshot_hash_mismatch`;
- `ledgr_sweep_schema_incompatible`.

### 3.7 Pre-CRAN Schema Posture

Saved-sweep schema versioning is fail-closed. v0.1.9.2 does not implement
schema migration machinery. Stored schema versions greater than the current
supported version, missing saved-sweep tables, or missing required columns raise
`ledgr_sweep_schema_incompatible`.

---

## 4. Bound Storage Shape

The schema has three tables:

- `sweeps`;
- `sweep_candidates`;
- `sweep_returns`.

The detailed field list lives in synthesis Section 6. Ticket implementations
must preserve these load-bearing details:

- all `*_json` fields on `sweeps` and `sweep_candidates` use
  `canonical_json()`;
- `sweeps.cost_model_hash` and `sweeps.cost_plan_json` are authoritative
  persisted cost identity for v0.1.9.2;
- `sweep_candidates.feature_set_hash`, `sweep_candidates.metric_context_hash`,
  and `sweep_candidates.cost_model_hash` are denormalized for scanability and
  validated against authoritative parent/provenance fields;
- `sweep_returns` uses `(sweep_id, candidate_row, pulse_index)` as primary key;
- `sweep_returns.period_return` is nullable and round-trips DuckDB NULL to
  `NA_real_`;
- `sweep_returns.ts_utc` uses the existing whole-second UTC `POSIXct` /
  DuckDB `TIMESTAMP` convention, not `TIMESTAMPTZ`.

---

## 5. Required Test Matrix

The release gate must include the synthesis Section 7 fixture families:

- identity orthogonality;
- canonical-series parity against inline-memory summary on R accounting;
- canonical-series parity against inline-memory summary on compiled spot FIFO;
- canonical-series parity against ordered-event reconstruction on R accounting;
- canonical-series parity against ordered-event reconstruction on compiled spot
  FIFO;
- final-bar no-fill retained final equity row;
- failed-candidate absence from retained return rows;
- persistence inspection and validation;
- round-trip scalar, attribute, identity, and retained-series parity;
- reopened-object dplyr survivability;
- unsaved in-memory sweep id behavior;
- wide accessor shape and classed-condition parity;
- storage smoke measurement with the accepted ratio.

Compiled spot-FIFO parity tests may use the existing compiled-availability
guard. The fixture row remains part of the release-gate matrix.

---

## 6. Documentation And Release Surface

The packet updates:

- `vignettes/sweeps.qmd`;
- generated installed sweep docs through the normal build path;
- roxygen help for all new public functions and classed conditions;
- `NEWS.md`;
- roadmap, horizon, design index, RFC index, and agent context as needed.

The sweep vignette must teach:

- scalar-only screening;
- in-session retained returns;
- durable saved sweep with retained returns;
- evidence tiers: scalar row, retained return/equity series, promoted run;
- why retained returns are net strategy returns only;
- why candidate return series are not full runs;
- why promotion re-executes from the reproduction key;
- why failed candidates have no retained return rows;
- why final-bar no-fill keeps the final equity row;
- how to drop leading `NA_real_` before passing returns to external packages;
- that PerformanceAnalytics-style metrics may differ from ledgr metrics.

Docs must not imply ranking helpers, automatic selection, benchmark-relative
diagnostics, signal decay, gross-vs-net cost attribution, or walk-forward
integration.

---

## 7. Storage Smoke Gate

The packet creates
`inst/design/ledgr_v0_1_9_2_spec_packet/sweep_retention_storage_smoke.md`
during implementation. The accepted formula is:

```text
expected_bytes = n_completed * n_pulses * 64
ratio = retained_db_delta_bytes / expected_bytes
```

`retained_db_delta_bytes` is the byte delta of the `sweep_returns` table only
between the `returns = "completed"` save and the `returns = "none"` baseline.
The release gate passes when `ratio <= 2.0`, or maintainer sign-off records why
the packet ships despite exceeding the ratio. This is a storage sanity gate, not
a public benchmark.

---

## 8. Ticket Map

Tickets are cut as `LDG-2581` through `LDG-2596`.

```text
LDG-2581 Packet Alignment And v0.1.9.2 Ticket Cut
  |-- LDG-2582 Sweep Retention Constructor And Argument
  |     |-- LDG-2583 Retention Identity Exclusion
  |     `-- LDG-2584 Retained Series Capture
  |           |-- LDG-2585 Retained Return Accessors
  |           |-- LDG-2591 Retained-Series Parity Matrix
  |           `-- LDG-2592 Storage Smoke Measurement
  |-- LDG-2586 Candidate ID Rename And Row Identity
  |     `-- LDG-2589 Reopened Sweep Candidate Compatibility
  |-- LDG-2587 Saved Sweep Schema And Canonical JSON
  |     |-- LDG-2588 Save Open List Info APIs
  |     |     `-- LDG-2590 Saved Sweep Validation And Conditions
  |     `-- LDG-2593 Round-Trip Persistence And dplyr Survivability
  |-- LDG-2594 Documentation And Examples
  |-- LDG-2595 Release Surfaces And Planning Docs
  `-- LDG-2596 v0.1.9.2 Release Gate
```

`LDG-2584` also depends on `LDG-2586` because retained long series expose the
post-rename `candidate_id` column. The tree above draws it under the retention
branch to keep the shape readable; the declared dependency list in the ticket
files is authoritative.

`LDG-2595` depends on the implementation, test, and documentation tickets so
NEWS and planning surfaces describe shipped behavior rather than planned
behavior. `LDG-2596` depends on all implementation, test, documentation, and
release-surface tickets.

---

## 9. Review Questions

Claude review should answer:

1. Does this spec preserve the accepted synthesis scope without pulling future
   obligations into v0.1.9.2?
2. Are any synthesis Section 7 release-gate tests missing from the ticket map?
3. Are the ticket dependencies sufficient to avoid implementing persistence
   before retention identity and schema decisions are in place?
4. Does the packet keep sweep persistence separate from ranking, selection,
   walk-forward, and committed-run promotion semantics?
5. Is the storage smoke gate specific enough for implementation and release
   review?

---

## 10. Release Gate

The v0.1.9.2 release gate must include:

- review-accepted spec and ticket packet;
- targeted tests for every new public API and condition;
- full testthat suite;
- package build/check per release playbook;
- storage smoke measurement;
- documentation render/build path;
- stale-claim searches for non-scope leakage;
- generated-doc review;
- roadmap/horizon/design-index/AGENTS consistency check;
- release closeout citing the accepted synthesis and this packet.

The release cannot close with silent omissions from the synthesis Section 16
gate matrix.
