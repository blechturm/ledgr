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
