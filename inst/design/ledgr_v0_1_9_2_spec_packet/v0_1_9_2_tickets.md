# ledgr v0.1.9.2 Tickets

Version: v0.1.9.2
Date: 2026-06-07
Total Tickets: 16

## Ticket Organization

This packet implements the scoped v0.1.9.2 plan from `v0_1_9_2_spec.md`:
durable sweep artifact persistence, optional retained net portfolio
equity/return series for completed candidates, reopened-sweep candidate
compatibility, compact saved-sweep schemas, and release-gate storage evidence.

Ticket IDs start at `LDG-2581` because `LDG-2547` through `LDG-2580` were used
by the v0.1.9.1 packet.

The release spine is:

```text
packet alignment
  -> retention surface and non-identity
     -> retained series capture and accessors
        -> saved-sweep schema
           -> save/open/list/info
              -> validation and round-trip tests
                 -> docs and release surfaces
                    -> release gate
```

## Dependency DAG

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
branch to keep the shape readable; the declared dependency list is
authoritative.

`LDG-2596` depends on every prior implementation, test, documentation, and
release-surface ticket in this packet.

## Priority Levels

- P0: packet alignment, public API, identity correctness, persistence schema,
  release-gate tests, or release gate.
- P1: documentation, examples, storage measurement, or planning surface
  updates required by the synthesis.
- P2: small polish that improves reviewability without changing scope.

---

## LDG-2581: Packet Alignment And v0.1.9.2 Ticket Cut

Priority: P0
Effort: S
Dependencies: none
Status: Completed

### Description

Finalize the v0.1.9.2 planning packet after accepted RFC closure and cut the
spec, human ticket list, and machine-readable ticket YAML before implementation
starts.

### Tasks

- Keep `v0_1_9_2_spec.md`, `v0_1_9_2_tickets.md`, `tickets.yml`,
  `batch_plan.md`, and `README.md` synchronized.
- Confirm the packet opens from
  `rfc_sweep_artifact_persistence_v0_1_9_x_synthesis.md`.
- Confirm roadmap, horizon, design index, and AGENTS all mark v0.1.9.2 as the
  active packet.
- Submit the packet cut for Claude review before Batch 1 starts.
- Apply Claude's minor packet-cut observations before Batch 1 starts.

### Acceptance Criteria

- Spec, ticket markdown, YAML, batch plan, and packet README agree on IDs,
  dependencies, priorities, statuses, and scope.
- No ticket authorizes ranking helpers, named selection views, benchmark
  diagnostics, signal decay, walk-forward integration, or full per-candidate
  run artifacts.
- Review prompt is written and sent before implementation begins.

### Verification

Manual packet review, YAML review, ASCII check, stale-reference `rg` checks,
and Claude packet-cut review.

### Source Reference

- `v0_1_9_2_spec.md`
- `inst/design/rfc/rfc_sweep_artifact_persistence_v0_1_9_x_synthesis.md`
- `inst/design/ledgr_roadmap.md`
- `inst/design/horizon.md`

### Classification

```yaml
type: governance
surface: design_packet
scope: v0.1.9.2
```

---

## LDG-2582: Sweep Retention Constructor And Argument

Priority: P0
Effort: M
Dependencies: LDG-2581
Status: Review Pending

### Description

Implement `ledgr_sweep_retention()` and add `retain` to `ledgr_sweep()` with a
default that preserves current scalar-only behavior.

### Tasks

- Implement `ledgr_sweep_retention(returns = c("none", "completed"))`.
- Validate retention enum values with classed, actionable errors.
- Add `retain = ledgr_sweep_retention()` to `ledgr_sweep()`.
- Attach a `sweep_retention` attribute to in-memory sweep results.
- Ensure `returns = "none"` produces the current scalar-only result shape.

### Acceptance Criteria

- Default `ledgr_sweep()` output remains scalar-only and backward-compatible
  except for the accepted `candidate_id` rename handled in LDG-2586.
- `returns = "completed"` is accepted and represented as a stable serializable
  retention object.
- Invalid retention values fail before candidate dispatch.
- Retention metadata is inspectable from the sweep result object.

### Verification

Constructor tests, invalid-input tests, default-behavior regression tests, and
attribute tests.

### Source Reference

- `v0_1_9_2_spec.md`
- Synthesis Sections 1, 3, and 5

### Classification

```yaml
type: public_api
surface: sweep_retention
scope: retention_constructor_and_argument
```

---

## LDG-2583: Retention Identity Exclusion

Priority: P0
Effort: M
Dependencies: LDG-2582
Status: Review Pending

### Description

Prove and enforce that retention policy is non-identity. Retaining candidate
return series must not alter execution identity, scalar candidate rows,
candidate reproduction keys, or `config_hash`.

### Tasks

- Defensively exclude sweep retention metadata from `config_hash_payload()`.
- Keep retention policy out of `execution_assumptions`.
- Keep retention policy out of candidate reproduction keys.
- Add tests comparing scalar-only and retained sweeps over the same inputs.

### Acceptance Criteria

- Same inputs with `returns = "none"` and `returns = "completed"` produce the
  same `config_hash`, cost identity, scalar metrics, execution seeds, and
  candidate reproduction keys.
- `attr(sweep, "execution_assumptions")$sweep_retention` is absent.
- Retention metadata remains available as `attr(sweep, "sweep_retention")`.

### Verification

Identity orthogonality tests, config-hash tests, scalar metric parity tests,
and reproduction-key comparisons.

### Source Reference

- Synthesis Section 4
- `R/config-hash.R`
- `R/sweep.R`

### Classification

```yaml
type: identity
surface: sweep_retention
scope: non_identity_retention_policy
```

---

## LDG-2584: Retained Series Capture

Priority: P0
Effort: L
Dependencies: LDG-2582, LDG-2583, LDG-2586
Status: Planned

### Description

Capture pulse-aligned net portfolio equity and adjacent-period returns for
completed candidates when `returns = "completed"`.

### Tasks

- Reuse the existing sweep summary equity path rather than introducing a new
  execution engine.
- Retain one row per scoring pulse for each completed candidate.
- Compute `period_return` with a leading `NA_real_` per candidate.
- Store no retained return rows for failed candidates.
- Preserve the final equity row when final-bar no-fill warnings occur.
- Keep R accounting and compiled spot-FIFO support behind the same fold-core
  output-handler path.

### Acceptance Criteria

- Retained long series has columns `sweep_id`, `candidate_id`, `ts_utc`,
  `equity`, and `period_return`.
- Completed candidates have exactly one retained row per scoring pulse.
- Failed candidates have no retained return rows.
- Retained equity preserves the row at the final scoring pulse for completed
  candidates even when `LEDGR_LAST_BAR_NO_FILL` is emitted; the warning lives
  on the candidate summary row, not the retained-series row.
- Retained series are net portfolio equity/returns only.

### Verification

Retained-series tests, final-bar no-fill tests, failed-candidate tests, and
manual parity inspection against summary equity.

### Source Reference

- Synthesis Sections 2 and 7
- `R/sweep.R`
- `R/fold-engine.R`
- `R/fold-reconstruction.R`

### Classification

```yaml
type: execution_output
surface: ledgr_sweep
scope: retained_equity_return_series
```

---

## LDG-2585: Retained Return Accessors

Priority: P0
Effort: M
Dependencies: LDG-2584
Status: Planned

### Description

Implement `ledgr_sweep_returns()` and `ledgr_sweep_returns_wide()` for
in-memory and reopened sweeps.

### Tasks

- Implement `ledgr_sweep_returns(x, candidates = NULL)`.
- Implement `ledgr_sweep_returns_wide(x, candidates = NULL, value =
  c("returns", "equity"))`.
- Support candidate filters by public `candidate_id`.
- Make long and wide helpers raise the same classed conditions before pivoting.
- Preserve leading `NA_real_` in return matrices.

### Acceptance Criteria

- Accessors operate identically on in-memory and reopened sweeps.
- Missing candidates raise `ledgr_sweep_returns_candidate_not_found`.
- Failed candidates raise `ledgr_sweep_returns_candidate_not_completed` when
  explicitly requested.
- Unretained sweeps raise `ledgr_sweep_returns_unretained`.
- In-memory retained-series accessors populate the `sweep_id` column from
  `attr(sweep, "sweep_id")`.
- Reopened-sweep retained-series accessors populate `sweep_id` from the durable
  saved sweep id.
- Wide returns and wide equity share the same timestamp spine and candidate
  columns.

### Verification

Accessor tests, wide-shape tests, classed-condition tests, and reopened-sweep
accessor parity tests.

### Source Reference

- Synthesis Section 3

### Classification

```yaml
type: public_api
surface: retained_sweep_returns
scope: long_and_wide_accessors
```

---

## LDG-2586: Candidate ID Rename And Row Identity

Priority: P0
Effort: M
Dependencies: LDG-2581
Status: Planned

### Description

Rename public sweep candidate identifiers from candidate-row `run_id` to
`candidate_id` and bind durable `candidate_row` semantics.

### Tasks

- Rename sweep candidate result column `run_id` to `candidate_id`.
- Preserve committed-run `run_id` semantics.
- Add `candidate_row` as the 1-indexed original sweep row position where
  needed for persistence.
- Update `ledgr_candidate()` and promotion context to consume `candidate_id`.
- Update docs, examples, and NEWS for the pre-CRAN rename.

### Acceptance Criteria

- Sweep result rows expose `candidate_id`, not candidate-row `run_id`.
- Committed runs and promoted runs still expose `run_id`.
- `candidate_row` is stable across save/open and dplyr operations.
- `ledgr_candidate()` works with filtered, sorted, and sliced sweep results.

### Verification

Candidate extraction tests, promotion-context tests, dplyr order tests,
documentation checks, and stale `run_id` sweep-row searches.

### Source Reference

- Synthesis Sections 3 and 6
- `R/sweep.R`
- `R/promotion-context.R`

### Classification

```yaml
type: public_contract
surface: sweep_candidate_identity
scope: candidate_id_rename
```

---

## LDG-2587: Saved Sweep Schema And Canonical JSON

Priority: P0
Effort: L
Dependencies: LDG-2581, LDG-2583, LDG-2586
Status: Planned

### Description

Create the saved-sweep DuckDB schema and canonical JSON serialization contract
for compact sweep artifacts.

### Tasks

- Add `sweeps`, `sweep_candidates`, and `sweep_returns` tables.
- Store all synthesis Section 6 required fields.
- Use `canonical_json()` for all `*_json` fields on `sweeps` and
  `sweep_candidates`.
- Store `cost_model_hash` and `cost_plan_json` on `sweeps`.
- Validate denormalized candidate `feature_set_hash`, `metric_context_hash`,
  and `cost_model_hash`.
- Add indexes needed for retained return lookup and timestamp scans.

### Acceptance Criteria

- Schema contains all synthesis Section 6 required columns with nullability
  matching the synthesis.
- `feature_params_json` is non-null and stores canonical JSON.
- Saved artifacts store schema version and engine version.
- Stored JSON round-trips byte-equivalent against ledgr canonical JSON.
- `sweep_returns` uses `(sweep_id, candidate_row, pulse_index)` as primary key.

### Verification

Schema tests, canonical JSON tests, DB round-trip tests, nullability tests, and
manual schema inspection.

### Source Reference

- Synthesis Section 6
- `R/config-canonical-json.R`

### Classification

```yaml
type: persistence
surface: saved_sweep_schema
scope: duckdb_tables_and_json
```

---

## LDG-2588: Save Open List Info APIs

Priority: P0
Effort: L
Dependencies: LDG-2585, LDG-2587
Status: Planned

### Description

Implement the public saved-sweep APIs: save, open, list, and info.

### Tasks

- Implement `ledgr_sweep_save(sweep, snapshot, sweep_id = NULL, note = NULL)`.
- Implement `ledgr_sweep_open(snapshot, sweep_id)`.
- Implement `ledgr_sweep_list(snapshot)`.
- Implement `ledgr_sweep_info(x)`.
- Preserve eager reopened `ledgr_sweep_results` compatibility.
- Keep `ledgr_sweep_save()` non-mutating for the caller's in-memory object.
- Provide or verify a print method on reopened saved-sweep objects that matches
  the in-session `ledgr_sweep_results` print contract: sweep id, candidate
  counts, retention status, and identity summary.
- Validate `note` as `NULL` or a length-one character scalar; reject other
  shapes with a classed input-validation error.

### Acceptance Criteria

- `ledgr_sweep_save()` writes scalar rows and retained return rows when present.
- `sweep_id = NULL` persists under the in-session sweep id.
- Explicit `sweep_id` persists and reopens under the explicit id without
  mutating the caller's object.
- `ledgr_sweep_list()` returns required columns in descending `created_at_utc`
  order.
- `ledgr_sweep_info()` accepts in-memory and reopened sweep objects, rejects
  bare ids, and reports identity, retention, grid, counts, and audit metadata.

### Verification

Save/open/list/info tests, non-mutating explicit-id tests, ordering tests, and
manual print review.

### Source Reference

- Synthesis Section 3
- Synthesis Section 7

### Classification

```yaml
type: public_api
surface: saved_sweeps
scope: save_open_list_info
```

---

## LDG-2589: Reopened Sweep Candidate Compatibility

Priority: P0
Effort: M
Dependencies: LDG-2586, LDG-2588
Status: Planned

### Description

Ensure reopened saved sweeps remain candidate-compatible and promotion-ready
without treating saved scalar or retained return rows as committed-run
artifacts.

### Tasks

- Reconstruct reopened sweeps as `ledgr_sweep_results`-compatible objects.
- Preserve reproduction metadata, feature identity, metric context, cost
  identity, retention metadata, and selection-view metadata.
- Keep `ledgr_candidate()` working after filter, arrange, and slice.
- Ensure `ledgr_promote()` re-executes from reproduction key.

### Acceptance Criteria

- `ledgr_candidate()` works on reopened sweeps and captures filtered/sorted
  `selection_view` metadata.
- Reopened sweeps retain metadata needed for promotion and return accessors.
- Promotion from reopened sweeps produces committed-run artifacts by
  re-execution.
- No code path commits stored sweep scalar rows or retained returns as a run.

### Verification

Candidate extraction tests, reopened promotion tests, selection-view tests, and
promotion provenance inspection.

### Source Reference

- Synthesis Sections 3 and 7
- `R/sweep.R`
- `R/promotion-context.R`

### Classification

```yaml
type: public_contract
surface: reopened_sweeps
scope: candidate_and_promotion_compatibility
```

---

## LDG-2590: Saved Sweep Validation And Conditions

Priority: P0
Effort: M
Dependencies: LDG-2587, LDG-2588
Status: Planned

### Description

Implement saved-sweep validation rules and classed conditions.

### Tasks

- Validate `sweep_id` as a non-empty, non-whitespace ASCII character scalar of
  at most 256 characters.
- Raise `ledgr_invalid_sweep_id` for invalid ids.
- Reject duplicate ids with `ledgr_sweep_id_exists`.
- Raise `ledgr_sweep_snapshot_not_found` when the saved snapshot id is absent.
- Raise `ledgr_sweep_snapshot_hash_mismatch` when the id exists but hash
  differs.
- Raise `ledgr_sweep_schema_incompatible` for unsupported future schema
  versions or missing required tables/columns.

### Acceptance Criteria

- All classed conditions named in the synthesis are implemented and documented.
- Validation fails before partial writes.
- Snapshot id absence and hash mismatch have distinct classes.
- Schema compatibility uses integer comparison against the current supported
  saved-sweep schema version.

### Verification

Invalid-id tests, duplicate-id tests, snapshot mismatch tests, incompatible
schema fixtures, and classed condition help-page checks.

### Source Reference

- Synthesis Sections 3, 5, and 6

### Classification

```yaml
type: validation
surface: saved_sweeps
scope: classed_conditions
```

---

## LDG-2591: Retained-Series Parity Matrix

Priority: P0
Effort: L
Dependencies: LDG-2584, LDG-2585, LDG-2587
Status: Planned

### Description

Add the release-gate retained-series parity matrix across R accounting,
compiled spot FIFO, inline summary, and ordered-event reconstruction paths.

### Tasks

- Add inline-memory summary parity test on R accounting.
- Add inline-memory summary parity test on compiled spot FIFO.
- Add ordered-event reconstruction parity test on R accounting.
- Add ordered-event reconstruction parity test on compiled spot FIFO.
- Keep compiled tests behind the existing compiled-availability guard.
- Add final-bar no-fill and failed-candidate retained-series tests.

### Acceptance Criteria

- Retained series match inline summary and ordered-event reconstruction under
  canonical ordering.
- Final-bar no-fill keeps the final equity row and summary warning.
- Failed candidates remain in summary rows and are absent from retained return
  rows.
- Compiled spot-FIFO coverage is present and guarded when unavailable.

### Verification

`tests/testthat/test-sweep-persistence-parity.R` and retained-series tests from
`tests/testthat/test-sweep-persistence-returns.R`.

### Source Reference

- Synthesis Section 7
- `R/fold-engine.R`
- `R/fold-reconstruction.R`

### Classification

```yaml
type: tests
surface: retained_sweep_returns
scope: parity_matrix
```

---

## LDG-2592: Storage Smoke Measurement

Priority: P1
Effort: M
Dependencies: LDG-2584, LDG-2587, LDG-2588
Status: Planned

### Description

Run and record the accepted storage smoke measurement for retained
candidate-return storage.

### Tasks

- Create `sweep_retention_storage_smoke.md`.
- Use the synthesis Section 7 fixture recipe.
- Measure `returns = "none"` baseline and `returns = "completed"` retained
  save.
- Compute `expected_bytes`, `retained_db_delta_bytes`, and `ratio`.
- Record DuckDB compressed table sizes by table and, where available, column
  family.

### Acceptance Criteria

- `ratio <= 2.0`, or maintainer sign-off records why the packet ships anyway.
- `retained_db_delta_bytes` is limited to the `sweep_returns` table delta.
- The smoke document states this is a storage sanity gate, not a public
  benchmark.

### Verification

Storage smoke script/output review, smoke document review, and release-gate
ratio check.

### Source Reference

- Synthesis Section 7

### Classification

```yaml
type: measurement
surface: storage_smoke
scope: retained_returns_table_size
```

---

## LDG-2593: Round-Trip Persistence And dplyr Survivability

Priority: P0
Effort: L
Dependencies: LDG-2587, LDG-2588, LDG-2589, LDG-2590
Status: Planned

### Description

Add round-trip tests for scalar rows, attributes, identity, retained returns,
and dplyr/base subsetting survivability.

### Tasks

- Add save/open round-trip tests for scalar rows and attributes.
- Add retained return/equity exact round-trip tests under canonical ordering.
- Verify reopened-only audit metadata separately from parity fields.
- Add dplyr `filter()`, `arrange()`, and `slice()` metadata survivability
  tests.
- Assert `candidate_row` equals the 1-indexed original `ledgr_sweep_results`
  row position after save/open and after dplyr `filter()`, `arrange()`, and
  `slice()`; assert reopened values match in-session values.
- Add base row-subsetting restoration tests if implementation supports a base
  method.

### Acceptance Criteria

- Reopened sweeps are eager `ledgr_sweep_results`-compatible objects.
- Bound identity surfaces match between in-memory and reopened sweeps.
- Reopened-only audit fields are not falsely compared as identity parity.
- dplyr operations preserve metadata needed for candidate extraction, return
  accessors, and info inspection.

### Verification

`tests/testthat/test-sweep-persistence-roundtrip.R`, dplyr survivability tests,
and metadata inspection.

### Source Reference

- Synthesis Section 7

### Classification

```yaml
type: tests
surface: saved_sweeps
scope: roundtrip_and_dplyr_survivability
```

---

## LDG-2594: Documentation And Examples

Priority: P1
Effort: L
Dependencies: LDG-2582, LDG-2585, LDG-2588, LDG-2590, LDG-2591
Status: Planned

### Description

Document the saved-sweep and retained-series workflow without implying future
selection, benchmark, attribution, or walk-forward features.

### Tasks

- Update `vignettes/sweeps.qmd` with synthesis Section 14 sections.
- Add roxygen help for new public functions.
- Add help pages for new classed conditions.
- Add runnable examples for scalar-only screening, in-session retained returns,
  saved/reopened sweeps, and retained-series access.
- State that retained returns are net strategy returns only.
- State that PerformanceAnalytics-style metrics may differ from ledgr metrics.

### Acceptance Criteria

- Vignette teaches the three evidence tiers: scalar row, retained series,
  promoted run.
- Docs state promotion re-executes from the reproduction key.
- Docs show dropping leading `NA_real_` before external metric-package use.
- No docs imply ranking helpers, automatic selection, benchmark-relative
  diagnostics, signal decay, gross-vs-net attribution, or walk-forward
  integration.

### Verification

Roxygen example checks, vignette render/build, stale-claim `rg` checks, and
manual docs review against `inst/design/vignette_styleguide.md`.

### Source Reference

- Synthesis Sections 13 and 14
- `inst/design/vignette_styleguide.md`

### Classification

```yaml
type: documentation
surface: sweep_workflow
scope: saved_sweeps_and_retained_returns
```

---

## LDG-2595: Release Surfaces And Planning Docs

Priority: P1
Effort: M
Dependencies: LDG-2582, LDG-2583, LDG-2584, LDG-2585, LDG-2586, LDG-2587, LDG-2588, LDG-2589, LDG-2590, LDG-2591, LDG-2592, LDG-2593, LDG-2594
Status: Planned

### Description

Update NEWS and planning surfaces after implementation, preserving the accepted
scope and future-obligation routing.

### Tasks

- Add NEWS entry from synthesis Section 13.
- Update roadmap and horizon at release close.
- Update design README, RFC index, and AGENTS if implementation changes active
  context.
- Confirm post-synthesis future obligations remain parked and non-authorizing.
- Confirm v0.1.9.3 and v0.1.9.4 forward dependencies still read correctly.

### Acceptance Criteria

- NEWS names saved sweeps, retained returns, `candidate_id`, and non-scope.
- Roadmap/horizon/design index/AGENTS agree on packet state.
- No stale "RFC pending" or "planned" text remains for v0.1.9.2 at release
  close.
- Future obligations remain out of implementation scope.

### Verification

Planning-doc diff review, stale-reference searches, NEWS review, RFC index
review, and release-closeout review.

### Source Reference

- Synthesis Sections 11, 13, 15, and 16
- `inst/design/ledgr_roadmap.md`
- `inst/design/horizon.md`

### Classification

```yaml
type: release_surface
surface: planning_docs
scope: news_and_design_memory
```

---

## LDG-2596: v0.1.9.2 Release Gate

Priority: P0
Effort: L
Dependencies: LDG-2581, LDG-2582, LDG-2583, LDG-2584, LDG-2585, LDG-2586, LDG-2587, LDG-2588, LDG-2589, LDG-2590, LDG-2591, LDG-2592, LDG-2593, LDG-2594, LDG-2595
Status: Planned

### Description

Run the v0.1.9.2 release gate, collect evidence, and prepare release closeout.

### Tasks

- Run targeted saved-sweep, retained-series, schema, validation, candidate,
  and documentation tests.
- Run full testthat suite.
- Run package build/check per `release_ci_playbook.md`.
- Run storage smoke measurement and record result.
- Review generated docs and NEWS.
- Run stale-claim searches for non-scope leakage.
- Anchor stale-claim searches to synthesis Section 1 non-scope terms:
  `ranking`, `selection view`, `top.?n`, `winner`, `benchmark-relative`,
  `\balpha\b`, `\bbeta\b`, `gross-vs-net`, `signal decay`,
  `walk-forward integration`, `schema migration`, and
  `PerformanceAnalytics adapter`.
- Confirm release gate matrix from synthesis Section 16.
- Write release closeout when all gates pass.

### Acceptance Criteria

- All Section 7 release-gate tests pass or have maintainer-approved
  disposition.
- Storage smoke ratio passes or has maintainer sign-off.
- Package check passes or has maintainer-approved disposition.
- Docs and generated artifacts are consistent with the release surface.
- Release closeout cites the accepted synthesis, this spec packet, and gate
  evidence.

### Verification

Targeted tests, full tests, R CMD build/check, storage smoke document,
documentation render, release playbook checklist, and closeout review.

### Source Reference

- `v0_1_9_2_spec.md`
- `inst/design/rfc/rfc_sweep_artifact_persistence_v0_1_9_x_synthesis.md`
- `inst/design/release_ci_playbook.md`

### Classification

```yaml
type: release_gate
surface: package_release
scope: v0.1.9.2
```
