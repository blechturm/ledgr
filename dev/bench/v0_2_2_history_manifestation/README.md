# v0.2.2 ordinary history manifestation record

This is the binding LDG-3105 reference-host record. It measures the complete
public matrix and wide-frame reads from the same prepared availability-aware
context, including estimator admission and retained compact metadata.

The timed boundary begins after the context owner has prepared the immutable
history substrate and its mask summaries. This is the package's
prepare-once/reuse boundary, not a benchmark warm-up: the runner verifies that
`base_masks` exists before the first public read, makes that first read the
allocation witness, and requires the owner memo to remain unchanged across all
first and repeated public reads.

Run an installed candidate on the registered Windows host with the High
performance power plan and processor affinity `0xFFFF`:

```powershell
$env:LEDGR_PRODUCT_COMMIT = '<commit>'
$env:LEDGR_BENCH_LIBRARY = '<candidate-library>'
& 'C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe' `
  dev/bench/v0_2_2_history_manifestation/run_record.R <record-directory>
& 'C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe' `
  dev/bench/v0_2_2_history_manifestation/check_record.R <record-directory>
```

The checker binds the accepted amendment's three-record median at 500 by 252,
allocation, zero-digest, two-axis growth, fixed-window source-history
sensitivity and matrix/wide/long parity gates. `payload_copies` counts the
returned numeric payload once and every additional
allocation at least 90 percent of its size. `allocated_ratio` separately
discloses all smaller allocation overhead recorded by `Rprofmem()`.

Instrument growth is measured at 500, 1,166 and 2,332 instruments over 252
sessions; session growth is measured at 252, 504 and 1,260 sessions over 500
instruments. Each instrument-growth fixture has a decision universe of the
same size, because the compact selection table intentionally covers the full
decision axis. The 2,332-instrument synthetic stress point keeps the growth fit
out of the small-call fixed-cost region. The focal 500 by 252 shape remains an
observed point on both axes rather than an interpolated clock.
