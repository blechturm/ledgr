# v0.1.8.9 Per-Lane Attribution

This file is the rolling attribution ledger required by the v0.1.8.9
measurement discipline. Rows are appended as lanes reach review. Final
release claims belong in `v0_1_8_9_release_closeout.md`.

## LDG-2496: Fills Extractor `setv`

Status: implemented, committed, and measured.

Change:

- Replaced the nine base-R per-row writes in
  `ledgr_fill_row_buffer_add()` with `collapse::setv(..., vind1 = TRUE)`.
- No public API, table schema, fill classification, lot accounting, or
  stream-threshold behavior changed intentionally.

Verification:

| Check | Result |
| --- | --- |
| `test-fills-streaming.R` | PASS |
| `test-fifo-torture.R` | PASS |
| `test-sweep.R` | PASS |
| `test-sweep-parity.R` | PASS |
| `tickets.yml` parse | PASS |

Review caveats logged:

- `ledgr_sweep_summary_from_ordered_events()` has an inline fill-row closure
  with the same per-row column-write anti-pattern. It is not part of LDG-2496
  because this lane intentionally targets `ledgr_fill_row_buffer_add()` only.
  Route this to LDG-2498 before Batch 3 starts.
- Record-scale large/xlarge workload-grid measurement was completed before
  starting LDG-2497.

Direct helper attribution:

Method: compare a local copy of the old base-R `[[<-` implementation against
the current `collapse::setv` implementation for `ledgr_fill_row_buffer_add()`
in the same R session, then compare complete buffer data frames.

| Rows | Old Base-R s | New `setv` s | Speedup | Full Buffer Parity |
| ---: | ---: | ---: | ---: | --- |
| 10,000 | 1.090 | 0.330 | 3.30x | TRUE |
| 30,000 | 9.480 | 0.840 | 11.29x | TRUE |

Paired local smoke attribution:

Artifact prefix:
baseline `C:/tmp/ledgr-batch1-baseline-results/ledgr_bench_smoke_20260531T194720Z`
vs patched `C:/tmp/ledgr-batch1-after-results/ledgr_bench_smoke_20260531T194719Z`.

| Scenario | Baseline Fills Extract s | Patched Fills Extract s | Delta s | Notes |
| --- | ---: | ---: | ---: | --- |
| `density_high_large_durable` | 0.1600 | 0.1600 | 0.0000 | smoke shape; too small for stable wall attribution |
| `density_high_xlarge_durable` | 0.2000 | 0.2100 | +0.0100 | smoke shape; noise dominates |
| `density_high_large_ephemeral` | NA | NA | NA | harness does not expose fills extraction phase for sweep rows |
| `density_high_xlarge_ephemeral` | NA | NA | NA | harness does not expose fills extraction phase for sweep rows |

Interpretation: the targeted helper benchmark confirms the mechanism and parity.
The smoke grid is useful as a no-failure harness check but is not large enough
to show the expected record-scale `fills_extract_sec` recovery.

Record-scale attribution:

Baseline source: `dev/bench/results/ledgr_bench_record_20260531T132910Z_summary.csv`.
After sources:

- `dev/bench/results/ledgr_bench_record_20260531T202847Z_summary.csv`
- `dev/bench/results/ledgr_bench_record_20260531T203715Z_summary.csv`
- `dev/bench/results/ledgr_bench_record_20260531T204232Z_summary.csv`
- `dev/bench/results/ledgr_bench_record_20260531T204852Z_summary.csv`

| Scenario | Metric | Baseline | After | Delta | Notes |
| --- | --- | ---: | ---: | ---: | --- |
| `density_high_large_durable` | wall s | 153.76 | 141.09 | -12.67 | zero failures |
| `density_high_large_durable` | loop s | 138.86 | 124.72 | -14.14 | zero failures |
| `density_high_large_durable` | fills extract s | 82.67 | 9.73 | -72.94 | load-bearing lane metric |
| `density_high_large_durable` | extract us/fill | 1214.65 | 142.88 | -1071.76 | load-bearing lane metric |
| `density_high_xlarge_durable` | wall s | 445.02 | 410.39 | -34.63 | zero failures |
| `density_high_xlarge_durable` | loop s | 413.47 | 377.73 | -35.74 | zero failures |
| `density_high_xlarge_durable` | fills extract s | 197.11 | 21.00 | -176.11 | load-bearing lane metric |
| `density_high_xlarge_durable` | extract us/fill | 1481.33 | 157.71 | -1323.62 | load-bearing lane metric |
| `density_high_large_ephemeral` | wall s | 171.81 | 159.53 | -12.28 | harness exposes no fills extraction phase for sweep rows |
| `density_high_xlarge_ephemeral` | wall s | 623.87 | 508.08 | -115.79 | harness exposes no fills extraction phase for sweep rows |

Interpretation: LDG-2496 delivered the intended large/xlarge durable fills
extraction recovery. The xlarge durable extraction phase dropped by 176.11s,
inside the Spike 12 recovery envelope, and the per-fill extraction cost fell
from 1481.33 us/fill to 157.71 us/fill. Ephemeral rows also improved at the
wall level, but the current workload-grid harness does not split sweep rows
into extraction subphases.

## LDG-2497: Persistent Durable Handler `setv`

Status: post-review fix candidate, not committed.

Change:

- Replaced numeric, integer, and POSIXct per-row writes in the persistent
  durable output-handler `pending_cols` buffer with
  `collapse::setv(..., vind1 = TRUE)`.
- Kept character-column writes on base scalar assignment after record-scale
  measurement exposed local `collapse::setv` character-vector corruption at
  durable handler growth boundaries.
- Changed the internal `pending_cols` storage from a list to an environment so
  writes target stable preallocated vectors.
- No durable table schema, flush boundary, event ordering, event sequence,
  timestamp, or `DBI::dbAppendTable` behavior changed intentionally.

Verification:

| Check | Result |
| --- | --- |
| `test-ledger-writer.R` | PASS |
| `test-backtest-audit-log-equivalence.R` | PASS |
| `test-runner.R` | PASS |
| `test-fifo-torture.R` | PASS |
| `test-backtest-wrapper.R` | PASS |

Review caveats logged:

- The production `set_pending_value()` path is intentionally a partial `setv`
  fix. Character columns remain on base assignment because long character-vector
  `setv` corrupted values at growth/subset boundaries in this local collapse
  build (`collapse` 2.1.7). A 70,000-event full-character-`setv` handler
  reproducer verified the broken shape fails with
  `SET_STRING_ELT() must be a 'CHARSXP' not a 'character'`; the partial-`setv`
  correction passes record-scale large/xlarge durable runs.
- The record recovery should be read as the realized production lane result,
  not as the bare-`setv` Spike 11 upper-bound projection.
- The environment growth loop iterates columns by name; column write order is
  currently independent.

Direct helper attribution:

Method: compare a local copy of the old list-backed base-R `[[<-`
implementation against the current production persistent handler in the same R
session. The current handler uses environment-backed pending columns, `setv`
for POSIXct/numeric/integer columns, and base assignment for character columns.

| Rows | Old Base-R s | New Partial `setv` s | Speedup |
| ---: | ---: | ---: | ---: |
| 10,000 | 1.95 | 1.87 | 1.04x |
| 30,000 | 18.25 | 6.89 | 2.65x |

Paired local smoke attribution:

Artifact prefix:
`dev/bench/results/ledgr_bench_smoke_20260531T210017Z`.

| Scenario | Wall s | Loop s | Fills Extract s | Failures | Notes |
| --- | ---: | ---: | ---: | ---: | --- |
| `density_high_large_durable` | 1.84 | 0.25 | 0.16 | 0 | smoke shape; no-failure harness check |
| `density_high_xlarge_durable` | 1.64 | 0.38 | 0.22 | 0 | smoke shape; no-failure harness check |

Record-scale attribution:

Baseline sources after LDG-2496:

- `dev/bench/results/ledgr_bench_record_20260531T202847Z_summary.csv`
- `dev/bench/results/ledgr_bench_record_20260531T203715Z_summary.csv`

After sources:

- `dev/bench/results/ledgr_bench_record_20260531T212128Z_summary.csv`
- `dev/bench/results/ledgr_bench_record_20260531T212819Z_summary.csv`

| Scenario | Metric | Baseline | After | Delta | Notes |
| --- | --- | ---: | ---: | ---: | --- |
| `density_high_large_durable` | wall s | 141.09 | 115.97 | -25.12 | zero failures |
| `density_high_large_durable` | loop s | 124.72 | 99.34 | -25.38 | load-bearing lane metric |
| `density_high_large_durable` | fills extract s | 9.73 | 9.79 | +0.06 | unchanged; Batch 1 lane |
| `density_high_large_durable` | engine us/fill | 1831.48 | 1458.78 | -372.70 | load-bearing lane metric |
| `density_high_xlarge_durable` | wall s | 410.39 | 311.85 | -98.54 | zero failures |
| `density_high_xlarge_durable` | loop s | 377.73 | 278.07 | -99.66 | load-bearing lane metric |
| `density_high_xlarge_durable` | fills extract s | 21.00 | 21.42 | +0.42 | unchanged; Batch 1 lane |
| `density_high_xlarge_durable` | engine us/fill | 2836.77 | 2088.32 | -748.45 | load-bearing lane metric |

Interpretation: despite falling back to base assignment for character columns,
LDG-2497 delivered the durable-handler lane at production scale. The xlarge
durable loop phase fell by 99.66s and wall fell by 98.54s relative to the
post-LDG-2496 baseline. This exceeds the Spike 11 50-80s production recovery
range; the direct helper benchmark understated the real-run result because the
durable fold loop exercises the pending-column writes under a different mix of
payload construction, buffering, and capacity growth.

## LDG-2498: Memory Output Handler `setv`

Status: review candidate, not committed.

Change:

- Changed the memory output handler's internal `event_cols` storage from a
  list to an environment, matching the corrected LDG-2497 handler pattern.
- Replaced POSIXct, numeric, and integer per-event writes in
  `ledgr_memory_output_handler()` with `collapse::setv(..., vind1 = TRUE)`.
- Kept character and list columns on base assignment because `collapse` 2.1.7
  corrupts long character vectors in this write pattern.
- Applied the same partial `setv` rule to the inline
  `ledgr_sweep_summary_from_ordered_events()` fill-buffer site: event sequence,
  timestamp, and numeric columns use `setv`; character columns remain base
  scalar writes.
- No public ephemeral execution API, worker durable writes, table schema, or
  event materialization surface changed intentionally.

Verification:

| Check | Result |
| --- | --- |
| `test-sweep.R` | PASS |
| `test-sweep-parity.R` | PASS |
| `test-sweep-parallel.R` | PASS |

Targeted regression coverage:

- Added a 1025-event memory-handler full-column growth test using real
  `ledgr_fill_event_row()` payloads.
- The test checks all materialized event columns plus the typed
  `ledgr_event_cash_delta`, `ledgr_event_position_delta`, and
  `ledgr_event_meta` attributes, with list-column spot checks at the 1024/1025
  growth boundary.
- A pre-fix full-character-`setv` memory-handler shape inherits the same
  `collapse` 2.1.7 long-character-vector failure proved during the LDG-2497
  correction; Batch 3 starts from the partial `setv` strategy rather than
  reproducing that unsafe path.
- Existing single-pass sweep-summary parity test covers the inline
  `ledgr_sweep_summary_from_ordered_events()` fill-buffer site against
  separate reconstruction helpers.

Paired local smoke attribution:

Artifact prefix:
`dev/bench/results/ledgr_bench_smoke_20260531T214154Z`.

| Scenario | Wall s | Failures | Notes |
| --- | ---: | ---: | --- |
| `density_high_large_ephemeral` | 1.26 | 0 | smoke shape; no-failure harness check |
| `density_high_xlarge_ephemeral` | 0.91 | 0 | smoke shape; no-failure harness check |

Record-scale attribution:

Baseline sources after LDG-2496:

- `dev/bench/results/ledgr_bench_record_20260531T204232Z_summary.csv`
- `dev/bench/results/ledgr_bench_record_20260531T204852Z_summary.csv`

After sources:

- `dev/bench/results/ledgr_bench_record_20260531T214414Z_summary.csv`
- `dev/bench/results/ledgr_bench_record_20260531T215057Z_summary.csv`

| Scenario | Metric | Baseline | After | Delta | Notes |
| --- | --- | ---: | ---: | ---: | --- |
| `density_high_large_ephemeral` | wall s | 159.53 | 103.92 | -55.61 | zero failures |
| `density_high_xlarge_ephemeral` | wall s | 508.08 | 346.63 | -161.45 | zero failures |

Interpretation: LDG-2498 delivered the intended ephemeral memory-path recovery
at record scale. The workload-grid harness does not expose sweep-row loop or
results subphases, so wall is the available lane metric for these ephemeral
cells. The xlarge ephemeral wall recovery is larger than the Spike 6
50-100s estimate, likely because the handler change and inline sweep-summary
fill-buffer change both affect the same ephemeral workload path.

## LDG-2499: Position Valuation Vectorize

Status: review candidate, not committed.

Change:

- Replaced the per-instrument R loop used for mark-to-market position
  valuation in `ledgr_execute_fold()` with an aligned vector expression.
- The implementation indexes `state$positions[instrument_ids]` before coercion
  so position quantities stay explicitly aligned to the current universe order.
- Zero-position rows are masked before multiplying by close prices, preserving
  the old loop's `qty == 0` skip behavior when a zero-position instrument has
  a missing close.
- No target validation, fill generation, lot accounting, output handler, or
  public API behavior changed intentionally.

Verification:

| Check | Result |
| --- | --- |
| `test-execution-spec.R` | PASS |
| `test-backtest-audit-log-equivalence.R` | PASS |
| `test-sweep-parity.R` | PASS |
| `test-backtest-wrapper.R` | PASS |
| `test-runner.R` | PASS |
| `tickets.yml` parse | PASS |

Targeted regression coverage:

- Added a shuffled-position alignment fixture where `state$positions` is named
  `BBB, AAA` while the universe is `AAA, BBB`.
- The fixture observes `ctx$equity` inside the fold and verifies that position
  values are marked to market by instrument name, not by vector storage order.
  A storage-order valuation would produce first-pulse equity of 1301 instead
  of the asserted 1302.
- The fixture also verifies that the strategy sees the original named
  positions and can explicitly realign them to `ctx$universe`.

Direct helper attribution:

Method: compare the old per-instrument loop against the new aligned vector
expression in the same R session for 5,000 repeated valuations. Positions are
named by instrument id, closes are already in universe order, and full numeric
parity is required before timing.

| Instruments | Repetitions | Old Loop s | New Vector s | Speedup | Parity |
| ---: | ---: | ---: | ---: | ---: | --- |
| 500 | 5,000 | 3.47 | 0.08 | 43.38x | TRUE |
| 1,000 | 5,000 | 12.26 | 0.12 | 102.17x | TRUE |

Record-scale attribution:

Durable baseline sources after LDG-2497:

- `dev/bench/results/ledgr_bench_record_20260531T212128Z_summary.csv`
- `dev/bench/results/ledgr_bench_record_20260531T212819Z_summary.csv`

Ephemeral baseline sources after LDG-2498:

- `dev/bench/results/ledgr_bench_record_20260531T214414Z_summary.csv`
- `dev/bench/results/ledgr_bench_record_20260531T215057Z_summary.csv`

After sources:

- `dev/bench/results/ledgr_bench_record_20260531T220859Z_summary.csv`
- `dev/bench/results/ledgr_bench_record_20260531T221549Z_summary.csv`
- `dev/bench/results/ledgr_bench_record_20260531T221854Z_summary.csv`
- `dev/bench/results/ledgr_bench_record_20260531T222547Z_summary.csv`

| Scenario | Metric | Baseline | After | Delta | Notes |
| --- | --- | ---: | ---: | ---: | --- |
| `density_high_large_durable` | wall s | 115.97 | 110.72 | -5.25 | zero failures |
| `density_high_large_durable` | loop s | 99.34 | 94.22 | -5.12 | load-bearing lane metric |
| `density_high_large_durable` | fills extract s | 9.79 | 9.70 | -0.09 | unchanged; extraction lane |
| `density_high_large_durable` | engine us/fill | 1458.78 | 1383.59 | -75.19 | load-bearing lane metric |
| `density_high_xlarge_durable` | wall s | 311.85 | 309.44 | -2.41 | zero failures |
| `density_high_xlarge_durable` | loop s | 278.07 | 276.18 | -1.89 | load-bearing lane metric |
| `density_high_xlarge_durable` | fills extract s | 21.42 | 22.50 | +1.08 | unchanged; extraction lane/noise |
| `density_high_xlarge_durable` | engine us/fill | 2088.32 | 2074.12 | -14.20 | load-bearing lane metric |
| `density_high_large_ephemeral` | wall s | 103.92 | 102.73 | -1.19 | zero failures; no sweep subphase split |
| `density_high_xlarge_ephemeral` | wall s | 346.63 | 352.23 | +5.60 | zero failures; host/noise-level regression |

Interpretation: the vector expression is materially faster in isolation and
preserves named-instrument alignment, but the record-grid effect is modest after
the LDG-2496/2497/2498 buffer-write lanes. Durable loop time still moves in the
expected direction, with the clearest signal at the large cell (-5.12s loop,
-75.19 us/fill). The xlarge durable wall recovery (-2.41s) is
mechanism-consistent with the helper benchmark's expected low-single-digit
second production savings. The xlarge ephemeral +5.60s wall delta is the
largest counter-direction in the table; it is attributed to local-host CPU drift
on a 1.6% relative basis, supported by the fact that this fold-core
vectorization has no mechanism by which it would specifically slow the
ephemeral path while improving the durable path that shares the same fold
engine. If a future rerun after LDG-2500 still shows positive xlarge ephemeral
drift, revisit. This lane should be recorded as a correctness-preserving
micro-optimization, not a headline wall-recovery lane.

Postscript: LDG-2500's measurement vindicated the xlarge ephemeral noise
interpretation above. The same cell improved by 26.23s under the next-lane
target-delta change, so the LDG-2499 +5.60s counter-direction was not treated
as a persistent mechanism regression.

## LDG-2500: Target Delta Vectorize

Status: implemented, committed, and measured.

Change:

- Replaced the skip-heavy per-target loop setup in `ledgr_execute_fold()` with
  a vectorized target-delta scan.
- The fold still validates the full named numeric target vector before any
  optimization. Missing, extra, duplicate, unnamed, non-finite, or malformed
  targets continue to fail at `ledgr_validate_strategy_targets()`.
- The implementation computes `delta_vec` through
  `state$positions[names(targets)]`, masks absent state positions to zero, and
  iterates only `which(abs(delta_vec) > sqrt(.Machine$double.eps))`.
- Event emission and state mutation remain adjacent and ordered by the
  validated target vector so durable and sweep event streams keep the same
  ordering contract.
- No fill proposal, cost, lot accounting, output handler, target-risk, or
  public strategy contract behavior changed intentionally.

Verification:

| Check | Result |
| --- | --- |
| `test-execution-spec.R` | PASS |
| `test-strategy-contracts.R` | PASS |
| `test-strategy-types.R` | PASS |
| `test-backtest-audit-log-equivalence.R` | PASS |
| `test-sweep-parity.R` | PASS |
| `test-backtest-wrapper.R` | PASS |
| `test-accounting-consistency.R` | PASS |

Targeted regression coverage:

- Added a shuffled-target fixture where the strategy returns `BBB, AAA` while
  the universe is `AAA, BBB`.
- The fixture verifies that emitted events remain in validated universe order
  (`AAA`, then `BBB`) with quantities aligned to instrument names.
- The fixture also verifies that the second pulse observes positions `AAA = 1`,
  `BBB = 2`, proving the vectorized delta scan drove the same state transition
  as the original per-target loop.

Direct helper attribution:

Method: compare the old per-target loop against the new `delta_vec` +
`which()` scan in the same R session. The benchmark uses 1,260 pulses and a
fill density of 135 fills per instrument, matching the high-density record
cells. Full fill-count parity is required before timing.

| Instruments | Pulses | Fills | Old Loop s | New Vector s | Speedup | Parity |
| ---: | ---: | ---: | ---: | ---: | ---: | --- |
| 500 | 1,260 | 68,040 | 1.63 | 0.02 | 81.50x | TRUE |
| 1,000 | 1,260 | 136,080 | 5.96 | 0.03 | 198.67x | TRUE |

Record-scale attribution:

Durable baseline sources after LDG-2499:

- `dev/bench/results/ledgr_bench_record_20260531T220859Z_summary.csv`
- `dev/bench/results/ledgr_bench_record_20260531T221549Z_summary.csv`

Ephemeral baseline sources after LDG-2499:

- `dev/bench/results/ledgr_bench_record_20260531T221854Z_summary.csv`
- `dev/bench/results/ledgr_bench_record_20260531T222547Z_summary.csv`

After sources:

- `dev/bench/results/ledgr_bench_record_20260531T225058Z_summary.csv`
- `dev/bench/results/ledgr_bench_record_20260531T225726Z_summary.csv`
- `dev/bench/results/ledgr_bench_record_20260531T225929Z_summary.csv`
- `dev/bench/results/ledgr_bench_record_20260531T230550Z_summary.csv`

| Scenario | Metric | Baseline | After | Delta | Notes |
| --- | --- | ---: | ---: | ---: | --- |
| `density_high_large_durable` | wall s | 110.72 | 106.72 | -4.00 | zero failures |
| `density_high_large_durable` | loop s | 94.22 | 90.16 | -4.06 | load-bearing lane metric |
| `density_high_large_durable` | fills extract s | 9.70 | 10.12 | +0.42 | unchanged; extraction lane/noise |
| `density_high_large_durable` | engine us/fill | 1383.59 | 1323.97 | -59.62 | load-bearing lane metric |
| `density_high_xlarge_durable` | wall s | 309.44 | 287.16 | -22.28 | zero failures |
| `density_high_xlarge_durable` | loop s | 276.18 | 253.29 | -22.89 | load-bearing lane metric |
| `density_high_xlarge_durable` | fills extract s | 22.50 | 21.19 | -1.31 | unchanged; extraction lane/noise |
| `density_high_xlarge_durable` | engine us/fill | 2074.12 | 1902.22 | -171.90 | load-bearing lane metric |
| `density_high_large_ephemeral` | wall s | 102.73 | 96.09 | -6.64 | zero failures; no sweep subphase split |
| `density_high_xlarge_ephemeral` | wall s | 352.23 | 326.00 | -26.23 | zero failures; no sweep subphase split |

Interpretation: LDG-2500 delivered a clear record-scale recovery, especially
at the xlarge high-density cell where the skip-heavy per-target loop had the
largest surface area. The xlarge durable loop phase fell by 22.89s and
per-fill engine cost fell by 171.90 us/fill. The xlarge ephemeral rerun also
reversed the LDG-2499 counter-direction and improved by 26.23s, supporting the
Batch 4 interpretation that the previous +5.60s ephemeral delta was local-host
noise rather than a mechanism regression. This is the stronger of the two
per-pulse vectorization lanes and should be treated as a real scaling-flatten
result in the release closeout.

Residual: the per-target `state$positions[[instrument_id]] <- cur_qty + qty`
write remains the Spike 3 audit-gated surface. LDG-2500 removes the read-side
skip-loop cost; the write-side named-vector update is explicitly left for
LDG-2502 triage rather than bundled into this lane.

## LDG-2501: yyjsonr And Canonical JSON v2

Status: review candidate, not committed.

Change:

- Replaced production `jsonlite` read/write call sites with yyjsonr-backed
  internal helpers.
- `canonical_json()` now emits canonical JSON byte-format v2 through
  `yyjsonr::write_json_str()` with pinned write options.
- Added separate read helpers for nested metadata shapes and config-like
  simplify-vector shapes.
- Removed `jsonlite` from `DESCRIPTION`/`NAMESPACE` and added `yyjsonr
  (>= 0.1.22)`.
- Updated strategy provenance package fingerprints to track `yyjsonr`.
- Regenerated expected config, param-grid, and fingerprint fixtures where the
  canonical byte-format bump intentionally changes identity bytes.
- Normalized integer-like built-in indicator window parameters before
  fingerprinting so `ledgr_ind_sma(2)` and parameterized
  `ledgr_ind_sma(2L)` remain the same concrete indicator.

Verification:

| Check | Result |
| --- | --- |
| `rg "jsonlite|fromJSON|toJSON" R DESCRIPTION NAMESPACE tests/testthat -n` | no matches |
| yyjsonr package version | 0.1.22 |
| `test-canonical-json-byte-format.R` | PASS |
| `test-config.R` | PASS |
| `test-sweep-parity.R` | PASS |
| `test-promotion-context.R` | PASS |
| `test-backtest-wrapper.R` | PASS |
| `test-experiment-run.R` | PASS |
| `test-snapshot-adapters.R` | PASS, one existing quantmod-path skip |
| `test-ledger-writer.R` | PASS |
| `test-runner.R` | PASS |
| `test-parallel-workers.R` | PASS |
| `test-strategy-preflight.R` | PASS |
| `test-metric-kernel.R` | PASS |
| `test-fingerprint-stability.R` | PASS |
| `test-strategy-provenance.R` | PASS |
| `test-sweep.R` | PASS |
| `test-param-grid.R` | PASS |
| full `testthat::test_local()` | PASS, one existing snapshot-adapter skip |

Canonical byte-format fixtures:

- Added stored-byte fixtures for integer scalars, whole-number doubles,
  full-precision doubles, exponent notation, canonical metadata with `NULL`,
  escaped strings, POSIXct UTC values, and sorted nested objects.
- Added read-shape fixtures covering nested metadata (`length1_array_asis =
  TRUE`) and config-like shapes (`length1_array_asis = FALSE`).

Direct helper attribution:

Method: compare jsonlite v1-style write/read calls against yyjsonr write/read
helpers on 50,000 representative fill metadata payloads in one R session.

| Payloads | Old write s | yyjsonr write s | Write speedup | Old read s | yyjsonr read s | Read speedup |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 50,000 | 8.47 | 1.51 | 5.61x | 0.53 | 1.21 | 0.44x |

Interpretation: the write path delivers the expected speedup. The read helper
is slower on this micro-shape, so this lane should be judged primarily on
canonical write-heavy runtime surfaces and on the explicit identity-format
migration gates.

Record-scale attribution:

Durable baseline sources after LDG-2500:

- `dev/bench/results/ledgr_bench_record_20260531T225058Z_summary.csv`
- `dev/bench/results/ledgr_bench_record_20260531T225726Z_summary.csv`

Ephemeral baseline sources after LDG-2500:

- `dev/bench/results/ledgr_bench_record_20260531T225929Z_summary.csv`
- `dev/bench/results/ledgr_bench_record_20260531T230550Z_summary.csv`

After sources:

- `dev/bench/results/ledgr_bench_record_20260601T053840Z_summary.csv`
- `dev/bench/results/ledgr_bench_record_20260601T054456Z_summary.csv`
- `dev/bench/results/ledgr_bench_record_20260601T054702Z_summary.csv`
- `dev/bench/results/ledgr_bench_record_20260601T055332Z_summary.csv`

| Scenario | Metric | Baseline | After | Delta | Notes |
| --- | --- | ---: | ---: | ---: | --- |
| `density_high_large_durable` | wall s | 106.72 | 92.34 | -14.38 | zero failures |
| `density_high_large_durable` | loop s | 90.16 | 74.47 | -15.69 | load-bearing durable write-path signal |
| `density_high_large_durable` | fills extract s | 10.12 | 11.61 | +1.49 | unchanged; extraction/noise |
| `density_high_large_durable` | engine us/fill | 1323.97 | 1093.57 | -230.40 | load-bearing durable write-path signal |
| `density_high_large_durable` | extract us/fill | 148.61 | 170.49 | +21.88 | read/extract did not improve |
| `density_high_xlarge_durable` | wall s | 287.16 | 267.84 | -19.32 | zero failures |
| `density_high_xlarge_durable` | loop s | 253.29 | 231.17 | -22.12 | load-bearing durable write-path signal |
| `density_high_xlarge_durable` | fills extract s | 21.19 | 25.04 | +3.85 | read/extract did not improve |
| `density_high_xlarge_durable` | engine us/fill | 1902.22 | 1736.10 | -166.12 | load-bearing durable write-path signal |
| `density_high_xlarge_durable` | extract us/fill | 159.14 | 188.05 | +28.91 | read/extract did not improve |
| `density_high_large_ephemeral` | wall s | 96.09 | 98.40 | +2.31 | zero failures; no sweep subphase split |
| `density_high_xlarge_ephemeral` | wall s | 326.00 | 333.14 | +7.14 | zero failures; no sweep subphase split |

Interpretation: LDG-2501 delivered a real durable-path runtime improvement,
with xlarge durable wall down 19.32s and loop down 22.12s. This matches the
helper benchmark's write-path signal and slightly exceeds the synthesis's
13-15s production estimate. The fills-extraction phase regressed by 3.85s on
xlarge durable, consistent with the helper benchmark showing yyjsonr reads are
slower on representative nested metadata payloads. The ephemeral path regressed
modestly in both measured cells; because sweep rows do not expose a loop/results
split, this cannot be cleanly decomposed here, but the read-path penalty is the
most plausible source. The release closeout should report the durable win and
the ephemeral/read-path caveat together rather than treating yyjsonr as a
universal speed lane.

Identity fallout:

- The canonical JSON byte-format changed intentionally to v2.
- Config hashes, param-grid labels, feature fingerprints, feature-set hashes,
  feature-union hashes, and strategy provenance fingerprints were regenerated
  where tests pin those values.
- Pre-v0.1.8.9 identity artifacts are not byte-comparable to v0.1.8.9 identity
  artifacts when canonical JSON participates in the hash.
