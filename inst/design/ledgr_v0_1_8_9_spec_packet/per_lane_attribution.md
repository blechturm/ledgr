# v0.1.8.9 Per-Lane Attribution

This file is the rolling attribution ledger required by the v0.1.8.9
measurement discipline. Rows are appended as lanes reach review. Final
release claims belong in `v0_1_8_9_release_closeout.md`.

## LDG-2496: Fills Extractor `setv`

Status: review candidate, not committed.

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
- Record-scale large/xlarge workload-grid measurement remains required before
  LDG-2497 starts.

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
to show the expected record-scale `fills_extract_sec` recovery. Record-scale
large/xlarge reruns are intentionally left for the post-review measurement pass
because Batch 1 should be reviewed before committing.
