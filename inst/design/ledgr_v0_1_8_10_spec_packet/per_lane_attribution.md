# v0.1.8.10 Per-Lane Attribution

This file is the rolling attribution ledger required by the v0.1.8.10
measurement discipline. Rows are appended as lanes reach review. Final release
claims belong in `v0_1_8_10_release_closeout.md`.

## Ledger Template

Each implementation lane should record:

- ticket ID and status;
- change summary;
- verification commands / test files;
- helper or mechanism benchmark, if applicable;
- workload-grid before/after rows;
- peer-benchmark before/after rows, if applicable;
- parity gates and any accepted caveats;
- interpretation, separating within-run subphase evidence from wall-to-wall
  sanity checks.

## LDG-2518: Ephemeral Subphase Telemetry

Status: in review.

Change summary:

- Added sweep telemetry fields `t_engine`, `t_results`, and
  `t_fills_extract`.
- Wrapped `ledgr_execute_fold()` and ephemeral event-materialization /
  reconstruction summary work in `ledgr_sweep_candidate_execute()`.
- Exposed the sweep subphases through workload-grid `engine_sec`,
  `results_sec`, and `fills_extract_sec` columns. The existing durable
  `t_loop_sec` / `t_residual_sec` columns remain intact; durable rows also
  receive the shared phase-column aliases.

Verification:

- `Rscript -e "pkgload::load_all('.', quiet=TRUE); testthat::test_file('tests/testthat/test-sweep.R', reporter='summary')"`
- `Rscript -e "pkgload::load_all('.', quiet=TRUE); testthat::test_file('tests/testthat/test-sweep-parallel.R', reporter='summary')"`
- Tiny workload-grid sweep probe through `bench_run_sweep_once()` confirmed
  finite `engine_sec`, finite `results_sec`, and `fills_extract_sec = 0`.

Measurement status:

- Large/xlarge ephemeral workload-grid reruns are not recorded yet. They remain
  the post-review attribution gate before `LDG-2518` should be marked
  completed.

Interpretation:

- This lane is measurement infrastructure. The code should not be interpreted
  as a wall-recovery claim; it makes the ephemeral path phase-visible for the
  subsequent substrate/accounting and compiled-hot-frame decisions.
- `t_fills_extract = 0` on ephemeral sweep rows means no standalone
  fills-extraction subphase ran. Fills materialization for ephemeral sweeps is
  included inside `t_results` through `ledgr_sweep_summary_from_ordered_events()`;
  closeout language must not frame this as "fills extraction is free."
- `engine_sec` is not an identical bracket across persistence modes. Durable
  rows alias the existing internal fold-loop telemetry (`t_loop`) while
  ephemeral rows use a wall-clock bracket around `ledgr_execute_fold()`.
  Cross-mode comparisons are useful but should note the boundary difference.
- The benchmark markdown summary now reports `Engine s` and `Results s` instead
  of the previous single `Loop s` column. This is internal report churn, but any
  local parser of the markdown artifact needs the new column shape.

## LDG-2519: Matrix-Canonical Substrate And Accessors

Status: in review.

Change summary:

- Added an execution-spec `id_to_idx` map and validation for the 1-based
  universe-index contract.
- Converted fold-internal `state$positions` to a primitive numeric vector while
  preserving the public `ctx$positions` named pulse-start snapshot.
- Added `ctx$idx(id, missing = c("error", "na"))`, `ctx$vec` OHLCV/positions
  vector views, and `ctx$vec$feature(feature_id)`.
- Preserved scalar helper contracts and updated `signal_return()` /
  `target_rebalance()` to consume `ctx$vec` internally when available.
- Replaced per-fill next-bar data-frame row extraction with matrix-backed
  scalar lookup while preserving fill-proposal execution-bar context.

Verification:

- `Rscript -e "pkgload::load_all('.', quiet=TRUE); testthat::test_file('tests/testthat/test-execution-spec.R', reporter='summary'); testthat::test_file('tests/testthat/test-pulse-context-accessors.R', reporter='summary'); testthat::test_file('tests/testthat/test-fill-model.R', reporter='summary'); testthat::test_file('tests/testthat/test-strategy-reference.R', reporter='summary')"`

Measurement status:

- Large/xlarge workload-grid reruns are not recorded yet. They remain the
  post-review attribution gate before `LDG-2519` should be marked completed.

Interpretation:

- This lane lands the matrix-canonical substrate and accepted accessor RFC
  surface. It should be reviewed as a contract/substrate lane first and a wall
  recovery lane second.
- Public strategy compatibility is intentionally preserved: existing scalar
  helpers remain first-class, and `ctx$positions` remains a named snapshot.
  The primitive representation is internal plus `ctx$vec$positions`.

## LDG-2520: Fold-Owned FIFO Accounting And Inline State Capture

Status: in review.

Change summary:

- Added fold-owned `lot_state` initialized from opening positions/cost basis or
  reconstructed from prior events on resume.
- Applied FIFO lot accounting immediately after fill resolution and before
  output-handler accounting fact emission.
- Preserved materialized event rows and `meta_json` identity; inline
  accounting is emitted through typed memory-handler facts.
- Added memory-handler inline equity and fill facts so fresh ephemeral sweep
  summaries can use fold-owned accounting without the reconstruction pass.
- Kept durable extraction, reconstruction, and readback compatible as verifier
  and fallback paths.

Verification:

- `Rscript -e "pkgload::load_all('.', quiet=TRUE); testthat::test_file('tests/testthat/test-sweep.R', reporter='summary')"`
- `Rscript -e "pkgload::load_all('.', quiet=TRUE); testthat::test_file('tests/testthat/test-fifo-opening-positions.R', reporter='summary'); testthat::test_file('tests/testthat/test-fifo-torture.R', reporter='summary'); testthat::test_file('tests/testthat/test-sweep-parity.R', reporter='summary'); testthat::test_file('tests/testthat/test-backtest-wrapper.R', reporter='summary')"`
- `Rscript -e "pkgload::load_all('.', quiet=TRUE); testthat::test_file('tests/testthat/test-ledger-writer.R', reporter='summary'); testthat::test_file('tests/testthat/test-derived-state.R', reporter='summary'); testthat::test_file('tests/testthat/test-release-coverage-branches.R', reporter='summary')"`

Measurement status:

- Large/xlarge durable and ephemeral workload-grid reruns are not recorded yet.
  They remain the post-review attribution gate before `LDG-2520` should be
  marked completed.

Interpretation:

- This lane is an accounting-ownership substrate lane first. Event rows remain
  canonical; inline accounting facts are a fresh-sweep acceleration surface and
  are not a replacement for durable reconstruction/readback.
- The memory summary bypass is gated by parity tests against reconstruction.
  Closeout language must report both any `t_results` movement and any `t_engine`
  increase from moving FIFO work into the fold.

## LDG-2521: yyjsonr Options Hoist

Status: in review.

Change summary:

- Hoisted fixed `yyjsonr::opts_read_json()` objects for nested and config read
  helpers.
- Hoisted the fixed `yyjsonr::opts_write_json()` object for canonical JSON v2
  writes.
- Preserved helper signatures, canonical byte-format v2, and read-shape
  behavior.

Verification:

- `Rscript -e "pkgload::load_all('.', quiet=TRUE); testthat::test_file('tests/testthat/test-canonical-json-byte-format.R', reporter='summary'); testthat::test_file('tests/testthat/test-config.R', reporter='summary'); testthat::test_file('tests/testthat/test-fingerprint-stability.R', reporter='summary'); testthat::test_file('tests/testthat/test-ledger-writer.R', reporter='summary')"`

Helper benchmark:

- Shape: 50k flat event `meta_json` payloads matching the Spike 7 production
  metadata fixture.
- Old inline `opts_read_json()` construction: 1.100s median, 22.00 us/payload.
- New hoisted `ledgr_json_read_nested()` helper: 0.120s median,
  2.40 us/payload.
- Recovery: 9.17x.

Measurement status:

- This lane does not claim fresh-fold wall recovery. The measured recovery is
  for JSON read/reopen/replay helper surfaces that still parse persisted
  metadata.

Interpretation:

- Batch 4 closes the LDG-2501 yyjsonr read-path caveat by removing avoidable
  options-construction overhead. The canonical JSON v2 migration remains in
  place; this is a helper implementation fix, not an identity-format change.

## LDG-2522: Compiled Hot Frame B2 Gate

Status: pending.

## LDG-2523: Parked Spike Disposition

Status: pending.
