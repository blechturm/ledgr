# LDG-3280 census: tests, helpers and detectors the switch affects

Step 1 of LDG-3280 (Cut 27 decision 8): the census and the inventory only.
No patch was written. `tests/` and every tracked file are unchanged. The
suite and the parity harness were not run.

## Inputs

- Pin tests: `C:/Users/maxth/ledgr-wt/pin-src-7f65733f/tests/testthat`
  (233 files, 1,366 `test_that` blocks), plus `tests/claims.yml` and the
  `tools/*.R` scripts that tests source.
- Probe seed: `dev/spikes/switch_probe/e_suite_classification.csv`
  (41 failing blocks) and `b_suite_lean_tests.csv` (status for all
  1,366 blocks).
- What goes and what stays: `c_reachability.csv` (33 functions reachable only
  through the old fold, plus `ledgr_fold_envelope`) and `c_fold_files_kept.csv`.
- Authorities:
  - the deletion-readiness seed v2 (Sections 4-5);
  - the rules ledger (LR-12, LR-13, LR-15/LR-26, LR-16 to LR-20, LR-25);
  - pulse plumbing Sections 4, 5 and 7 and its D3, compiled-selector and
    overflow amendments;
  - the lean fold core synthesis Q3;
  - tickets.yml LDG-3280 and Cut 27 decision 8.
- Lean targets: `C:/Users/maxth/ledgr-wt/cut27-dev/dev/lean_core`. Its
  working tree carries the uncommitted clarity pass, with named stage
  closures `lean_e_advance`, `lean_p1_value` ... `lean_p5_commit`,
  `lean_loop_publish` and `lean_loop_expand`. Line numbers moved while this
  census ran, so treat cited `loop.R:N` as approximate on 2026-11-27. The
  function names are the reference.

## Method

1. **Blocks.** `census_blocks.R` parses every test and helper file with
   `getParseData()`. It finds every `test_that` / `testthat::test_that`
   call with its exact title and line range: 1,366 blocks, all 1,366
   matched to the probe's status table, and all 41 seed rows found. For
   each block it counts the lines that match each pattern family below.
   Output: `census_hits.csv`, one row per block.
2. **Indirect reach.** `census_indirect.R` collects every top-level function
   defined in a helper file or a test file (98 of them reach a family).
   It propagates hits through calls between helpers (a transitive closure;
   helpers are global, file functions are file-local). It then marks each
   block that calls such a function (`indirect`, `via_helpers`). It also
   extracts the binding names a block mocks with
   `with_mocked_bindings` / `local_mocked_bindings` (`mocked`). Output:
   `census_helper_defs.csv`, plus extra columns in `census_hits.csv`.
3. **Candidates.** A block is a candidate if:
   - a family other than mock, source text or handler hits it directly or
     through a helper; or
   - it is in the seed; or
   - it mocks a name on the fold path (`fold`, `execute`,
     `output_handler`, `lot_`, `fill_`, `event_buffer`, `diagnostic`,
     `carrier`, `pulse`, `risk`, `strategy_state`, `valuation`, `seed`,
     `worker`, `parallel`, `telemetry`, `equity`, `write_fill`).

   This gives 370 candidate blocks (`census_candidates.csv`).
4. **Reading.** Every candidate was read, along with the R/ functions it
   relies on, in five slices:
   - the parent: fold-phase contract, risk fold, execution spec, fill
     model, codebase contracts, cross-asset, one execution path, tools;
   - test-ws4a-carrier.R;
   - retired controls and the identity/format pins;
   - the handler, write path and diagnostics;
   - strategy, context, feature, seed and schedule, plus the
     merged-function call sites.

   Each block is either affected (a row in `inventory.csv`) or excluded
   with a reason. A block whose only dependence is a helper that needs a
   mechanical change gets no row of its own: the helper row lists it.
   No row was classified from a failure message alone.
5. **Targeted greps that the families do not cover:**
   - `identity_rule_version` with `5L`, `\b125L?\b`,
     `ledgr_store_format_json`, `ledgr_experiment_store_schema_version`,
     config-hash literals, and `fixtures/` CSVs that name `execution_mode`
     or schema 125 (controls slice);
   - every deletion-readiness merge/delete name (strategy slice and
     parent);
   - `tools/` paths read by tests: check-fold-phase-contract.R (4 refs),
     codebase-structure.R (2), check-codebase-contracts.R (3),
     governance-report.R (12), check-coverage.R (3), check-test-gate.R (2),
     run-test-profile.R (1). Only the first two reach fold code.
   - `tests/claims.yml`: every claim whose `detecting_blocks` contain an
     inventoried LTB id is listed in `claims_registry_affected.csv`
     (53 entries).
6. **Merge.** `merge_inventory.R`:
   - fills `in_seed` and `probe_status` from the census;
   - merges a block split across two slices into one row (LTB-0550: the
     schema pin plus the trusted-write half);
   - checks seed coverage (41 of 41).

### Pattern families (regex; matched per source line inside a block)

| family | pattern (abridged) |
|---|---|
| old_fold | the 33 "old fold only" names plus `ledgr_fold_envelope`, as whole words |
| fold_internal | `ledgr_fold_stage_`, `ledgr_carrier_*`, `ledgr_fold_(equity\|diagnostic\|staging\|state\|stop\|reconciliation\|positions\|plan_event\|target_changed\|scheduled\|apply\|flush\|fill_candidate\|build\|...)`, `ledgr_plan_(groups\|resolve\|refuse\|epoch\|side\|kind\|reason)`, `ledgr_execute_fold`, `ledgr_run_fold`, fold file names |
| mock | `with_mocked_bindings`, `local_mocked_bindings`, `trace(`, `untrace(`, `assignInNamespace`, `unlockBinding` |
| source_text | `readLines`, `parse(file`/`parse(text`, `deparse(`, `body(`, `check-fold-phase`, `tools/check`, `file.path(.."R"` |
| mode | `execution_mode`, `db_live`, `checkpoint_every`, `event_mode` |
| debug_class | `ledgr_internal_error`, `ledgr_invalid_fold_execution`, `ledgr_invalid_post_risk_targets`, `ledgr_invalid_pulse_plan`, `ledgr_invalid_state`, `ledgr_invalid_fill_intent`, `ledgr_invalid_fill_input`, `ledgr_invalid_accounting_event`, `ledgr_invalid_ledger_meta`, `ledgr_ledger_write_result`, `ledgr_event_buffer_capacity_exceeded`, `ledgr_invalid_lot_fill`, `ledgr_lot_state_invariant`, `ledgr_diagnostic_resource_exhausted`, `ledgr_invalid_event_order`, `ledgr_risk_application_error` |
| flush | `flush` |
| compiled | `spot_fifo`, `compiled_accounting_model`, `ledgr_compiled` |
| ctx_method | `$.ledgr_pulse_context`, `t_pulse`, `fold_telemetry`, `telemetry_samples` |
| seed | `pulse_seed` |
| merged | the deletion-readiness merge/delete names (`ledgr_validate_strategy_targets`, `ledgr_unwrap_strategy_target`, `ledgr_validate_sizing_evidence`, `ledgr_apply_risk_plan`/`_step*`, `ledgr_risk_context_*`, `ledgr_cost_model_resolve`, `ledgr_strategy_state_apply_values`/`_field`/`_validate_value`, `ledgr_validate_post_risk_quantities`, `ledgr_unsupported_risk_step`, `ledgr_plan_resolve`) |
| handler | `write_fill_events`, `run_transaction`, `ledgr_output_handler`, `output_handler$` |
| worker | `ledgr_parallel_worker_setup`, `ledgr_sweep_eval_candidate_tasks_parallel`, `worker_load`, `load_expr` |

### Counts per family

| family | blocks (direct) | hit lines | blocks (direct or via helper) | files (direct) |
|---|---:|---:|---:|---:|
| old_fold | 59 | 224 | 97 | 18 |
| fold_internal | 105 | 347 | 147 | 34 |
| mock | 130 | 171 | 159 | 70 |
| source_text | 131 | 344 | 179 | 68 |
| mode | 41 | 67 | 131 | 21 |
| debug_class | 43 | 98 | 51 | 17 |
| flush | 18 | 44 | 22 | 5 |
| compiled | 25 | 71 | 43 | 12 |
| ctx_method | 12 | 23 | 12 | 12 |
| seed | 26 | 91 | 53 | 9 |
| merged | 16 | 38 | 42 | 9 |
| handler | 59 | 142 | 64 | 17 |
| worker | 6 | 12 | 7 | 3 |

417 blocks hit some family directly or indirectly; 370 are candidates.

Noise families:
- `ctx_method` matched `first_pulse` and `next_pulse`.
- `seed` reaches 53 blocks only because `ledgr_test_modernize_config` stamps
  `pulse_seed_rule`.
- `mock` and `source_text` are dominated by snapshot-hash, documentation
  and governance tests.
- `ledgr_fold_list` / `ledgr_fold()` are walk-forward folds and also hit
  `fold_internal`.

Direct hits per file (families old_fold, fold_internal, mode, debug_class,
flush, compiled, merged):
- 50: test-ws4a-carrier.R
- 16: test-risk-fold.R
- 15: test-ledger-writer.R
- 13: test-execution-spec.R
- 7: test-fill-model.R, test-sweep.R
- 4: test-diagnostic-decoder.R, test-pulse-seed-v2.R
- 3: test-position-facts-context.R, test-rng-isolation.R
- 2 or fewer: 58 more files (full list in `census_hits.csv`)

Top-level hits outside blocks (helpers and file functions):
- helper-fixtures.R: old_fold 1, fold_internal 7, mode 3, seed 1, merged 1
- helper-rng-isolation.R: old_fold 1, mock 2, source_text 7, seed 3
- helper-history-fixtures.R: source_text 2, mode 1
- helper-availability-v0-2-0-1-witnesses.R: fold_internal 2, mock 2
- helper-stage-l-optimization-oracles.R: debug_class 1 (a snapshot-hash
  class, noise)
- test-ws4a-carrier.R: old_fold 58, fold_internal 82, plus others
- test-execution-spec.R, test-fill-model.R, test-risk-fold.R,
  test-strategy-context-*.R, test-pulse-seed-v2.R and
  test-output-handler-sinks.R: their file helpers.

## Result

`inventory.csv` has 196 rows: 173 test blocks, 21 helpers, 1 maintained
detector and 1 claims-registry row.

| handling | blocks | all rows |
|---|---:|---:|
| a lean injection or observation | 26 | 27 |
| b mechanical remap | 71 | 83 |
| c authorized semantic disposition | 63 | 72 |
| d resolved by the switch | 1 | 1 |
| e fixed in this cut (LDG-3276) | 1 | 1 |
| f unclear, needs the maintainer | 11 | 12 |

- **Seed:** all 41 seed blocks have a row.
- **Census:** 132 blocks, all passing in the probe. None of the affected
  blocks is skipped. The suite's one skipped block is not affected.
- **Helper users:** blocks that reach a change only through a helper have
  no own row. Counts are in `part_controls_helper_users.txt`:
  - `ledgr_test_run`: 55 blocks in 29 files
  - `ledgr_test_snapshot_backed_config`: 10
  - `ledgr_test_modernize_config`: 12
  - `ws42_with_schedule`: 7
  - `ledgr_test_current_config`: 9
  - `ledgr_test_next_open_fill`: 41 call sites in 7 files
  - `ledgr_test_dense_plan`: 4 blocks
  - the execution-spec and risk-fold spec helpers: about 15 blocks

### Files written

- `inventory.csv`: the inventory, with the requested columns.
- `census_hits.csv`: every block with its family counts, indirect reach,
  mocked names and probe status.
- `census_candidates.csv`, `census_helper_defs.csv`.
- `claims_registry_affected.csv`: the 53 claims.yml entries whose
  detecting blocks are inventoried, with each block's handling.
- Slice sources:
  - `part_parent.csv`, `part_ws4a.csv`, `part_controls.csv`,
    `part_handler.csv`, `part_strategy.csv`;
  - their `part_*_excluded.txt` files (excluded blocks with reasons);
  - `part_controls_helper_users.txt`.
- Scripts: `census_blocks.R`, `census_indirect.R`, `parent_rows.R`,
  `merge_inventory.R`. The slice generators are in the session scratchpad.

## Excluded hit blocks

Every excluded block and its reason is in the four `part_*_excluded.txt`
files and the list below. They fall into these groups.

**Direct tests of kept functions that assert nothing the switch changes.**
- The package lot kernel, replay, `ledgr_carrier_import_state`,
  `ledgr_carrier_provider_view`, `ledgr_fold_target_changed` (LTB-0526),
  `ledgr_cpp_spot_fifo_batch` (execution-spec "pops fractional dust lots"
  and "validates scalar state argument types"), and read-side validators.
  LR-15 keeps stored-ledger reads validating: LTB-0020, LTB-0209, and
  derived-state "rebuild failure".
- **Conditional:** if the WS4a D7 question is answered "fifo.R replaces
  R/lot-accounting.R", WS4a D15, D17, D18 and test-lot-accounting.R
  "fails closed on invalid fill input" become affected.

**Kept fold entry points.** These blocks call or wrap `ledgr_execute_fold`
or `ledgr_run_fold`. Both stay, though `ledgr_run_fold` loses its restart
check, and the asserted outcomes are public:
- LTB-0015, LTB-0155, LTB-0054, LTB-0036, LTB-0264's fold part;
- precompute-features (2 blocks), walk-forward-folds, availability-features
  LTB-0073/0074;
- acceptance AT8, runner resume, the position-facts restart blocks, and
  the experiment-run pulse_seed/restart blocks.

**Test-file blocks of the parent slice.**
- test-risk-fold.R:
  - covered by their helper row: "no-op feasibility hook", "compiled
    risk plan transforms targets", "long-only risk step maps negative
    targets", "max-weight caps", "risk chains apply built-in steps";
  - public-path or not fold-related: "public run applies long-only",
    "public sweep applies parameterized max-weight", "risk failures are
    captured", "risk plan parameter references resolve once" (a different
    refusal from deletion-readiness Q3), "private pulse-plan helpers are
    not exported" (absent names stay absent).
- test-execution-spec.R, covered by their helper rows: "execution specs
  validate before fold entry", "availability execution specs require
  aligned opening opportunities", "serializable worker payloads", and the
  three shuffled or primitive position blocks.
- test-fill-model.R: the blocks that depend only on
  `ledgr_test_next_open_fill` or `ledgr_test_dense_plan` (lines 44, 71, 96,
  292, 309, 349, 375, 385).
- test-codebase-contracts.R LTB-0270, LTB-0271 and LTB-0272.
- test-api-exports.R. Every listed internal boundary survives. Exception:
  if the telemetry f row retires `telemetry_stride`, then
  `ledgr_run_prepare_telemetry_stride` in its `internal_boundaries` becomes
  a b row.
- test-availability-workflow.R (a run-setup spot_fifo refusal),
  test-documentation-contracts.R and test-sweep-parallel.R (risk plan
  compile).

**rng-isolation tracer.** "rng-relevant sites run only under a wrapped
export" and helper-rng-isolation.R are excluded on one condition: Cut 28
keeps the binding name `ledgr_fold_envelope` for the lean envelope. If it
renames the binding, both become a b row (site-name remap).

**Controls slice** (part_controls_excluded.txt):
- DuckDB auto-checkpoint tests;
- the `runs.status` DDL test;
- the unmarked-old-store test;
- LTB-0107, LTB-0259, LTB-0269, LTB-0509 and LTB-0528;
- symbolic uses of `ledgr_identity_rule_version` and the schema-version
  binding;
- claims LCL-0088, LCL-0089 and LCL-0527, where "execution modes" means
  dense/availability or worker counts.

**Handler slice** (part_handler_excluded.txt):
- memory-handler growth and GC tests;
- LTB-0188, LTB-0520, LTB-0555 and LTB-0561 to LTB-0565;
- the "two-boundary interface" block;
- the finalization-prefix and post-fold failure blocks (LTB-0007), which
  mock runner-side kept functions.

## Cross-cutting findings for Cut 28 and the maintainer

1. **Injection seams.** The lean stages are closures inside
   `lean_fold_envelope_plain`, so `local_mocked_bindings` cannot reach
   them. Every a row needs one of these at Cut 28:
   - test seams at the named lean functions;
   - stage functions at package level;
   - injection through a package function the stage calls (`lean_plan_pulse`,
     `lean_lot_fill`, `ledgr_fold_plan_event_kinds`, the cost resolver, the
     output handler at the terminal transfer).

   The harness hook seams retire at the switch (decision 4), so any seam a
   test keeps must be designed, not inherited.
2. **Blocks that pass now but would pass vacuously after Cut 28 if left
   unchanged:**
   - LTB-0279: `ledgr_fold_phase_check()` finds no stage functions or
     `fold_state` writes, so it reports nothing.
   - risk-fold "pulse plan resolves same-pulse fills before emitting
     events": every handler write is now terminal.
   - LTB-0006, LTB-0013, LTB-0014, LTB-0017, the two compiled sweep blocks
     and LTB-0498's sweep half: under LR-25 both arms run fifo.R.
   - WS4a O3.28 and LTB-0302: their mocks bind nothing.
   - LTB-0282: its fault fires only through the debug comparison.
   - availability-state "canonical valuation-state service": passes only
     through the debug comparison.
   - experiment-store-schema CHECK blocks: their `expect_error` half passes
     vacuously once the column is gone.
3. **Suite debug-on.** The ticket's suite run uses lean debug enabled. So
   blocks that assert a debug-only class (LR-13, LR-16, LR-17, LR-18) keep
   passing. Their c rows say which production refusal they no longer
   witness, and production refusal checks rest on the debug-off parity
   witnesses.
4. **Cut 28 gates.** Every row touching `execution_mode`, `db_live`,
   `event_mode`, `checkpoint_every`, the identity rule or the schema
   number can only be proven against Cut 28's actual API and format
   removal. Each such row names that gate in `target_or_authority`.
5. **LTB-0519 (d).** The cause found from the code:
   - The test's observer is appended to `ledgr_parallel_ledgr_load_expr()`.
   - The harness worker boot (`lean_worker_setup` -> `lean_core_load` ->
     `pkgload::load_all()` on the source archive) reloads the namespace
     and discards the observer.

   After the switch there is no lean worker boot. The ticket's
   demonstration still has to be run: the test passing without the reload.
6. **Pre-existing weaknesses** (not switch differences):
   - `ledgr_test_run` accepts `checkpoint_every` but never passes it on, so
     rng-isolation's "store checkpoints" comparison has always compared two
     identical runs.
   - The two pulse-seed-v2 blocks that pass `checkpoint_every = 1L` run on
     the pin today, refused by the lean adapter and rerun by the harness.
     They get lean coverage only after the Cut 28 remap.
