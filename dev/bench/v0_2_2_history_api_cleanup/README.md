# Direct causal-history matrix record

This is the registered Workstream 55 record for LDG-3099. It uses public
snapshot, experiment and pulse-inspection APIs to prepare one vendor-neutral
500-instrument by 252-session availability history. It then alternates three
20-read direct arms with three 20-read frame-plus-adapter arms on the same
prepared context. Elapsed time is reported per read.

Run from the package root:

```powershell
& "C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe" `
  dev/bench/v0_2_2_history_api_cleanup/run.R
```

`history_matrix.csv` records elapsed time and incremental R heap peak for each
arm. The heap peak is `gc()`'s maximum-used cells after resetting that counter
immediately before the read; the adapter keeps both the frame and matrix alive
until after the measurement. `retained_bytes` is `object.size()` of those live
results. `summary.csv` holds arm medians. The gate is the ticket's deliberately
loose no-regression boundary: the direct elapsed median must be no more than
1.05 times the adapter median. Values, dimensions, names and recorded metadata
must be identical; the direct result retains no cell-evidence plane or source
frame.

This record measures only the prepared history read. Snapshot construction and
P1/P2 pulse preparation happen before either arm and are intentionally outside
the clocks.

## Recorded result

Recorded on 2026-10-24 on the local Windows development host. The direct arm's
median was 0.0190 seconds per read versus 0.0320 for the frame adapter, a ratio
of 0.594. Median incremental heap peaks were 97.2 and 97.1 MB respectively;
that counter is dominated by the reusable R heap and is disclosed rather than
claimed as a peak-memory saving. The retained result sizes show the material
difference: 1,164,664 bytes for the direct matrix versus 10,554,672 bytes while
the adapter's frame and matrix are both live. All arms returned 252 by 500
matrices, included all 500 instruments and passed the recorded requirements.
