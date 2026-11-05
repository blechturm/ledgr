# Diagnostic reader validation reuse

The WS25 private gate found exact compact-diagnostic order validation repeated
by public result readers. On the 3.8-million-row Sharadar workload, reader
clocks regressed by 2--20x and process peak memory rose from roughly 2.4 GiB to
4.9 GiB. This public synthetic probe reproduces the same width and duration:
500 instruments by 7,200 sessions, or 3.6 million decision rows.

`build_run.R` creates a public `ledgr_sim_bars()` snapshot and completed hold
run per source tree. `measure_surface.R` opens a fresh handle and records wall
time, process peak working set/private bytes and validator calls/time for
print, summary, point/history explanation, diagnostics and metrics. Each
surface runs in a fresh R process. `check.R` checks shape and completeness;
clocks and memory are evidence, not gates.

The pre-correction record reproduces the issue. The candidate calls the order
validator once for print, diagnostics and metrics and twice for summary and
both explanation surfaces. Validation alone costs about 1.1 seconds per full
call. Candidate peak working set is 2.76--3.16 GiB versus 0.32--2.40 GiB for
the base, while the much larger private-byte figures show DuckDB reservation
and are not resident-memory measurements.

Run from the repository root against unpacked source trees:

```powershell
& "C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe" `
  dev/bench/v0_2_3_diagnostic_reader_reuse/run_probe.R `
  C:/tmp/ledgr-base-0d6c0b11 C:/tmp/ledgr-candidate `
  dev/bench/v0_2_3_diagnostic_reader_reuse/records/pre_correction

& "C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe" `
  dev/bench/v0_2_3_diagnostic_reader_reuse/check.R
```

The base arm is commit `0d6c0b11`; the pre-correction candidate is clean head
`93e4b347`. The committed record contains only aggregate counts, clocks,
memory peaks and source identities. Stores stay outside version control.

## Correction result

Commit `d24b081e` keeps the exact logical-trace integrity check but reuses one
successful validation within an opened run handle while its persisted summary,
database file and write-ahead-log state are unchanged. A public six-surface
sequence (print, summary, point and history explanation, metrics and diagnostic
rows) therefore calls the store-wide validator once, not nine times. Registered
corruption witnesses change the persisted state token and make the next public
read validate and refuse.

The dense 500 by 7,200 post record is in `records/post_correction`. Each
fresh-process surface still performs one cold validation. Summary and both
explanation surfaces fall from two validations to one; the same-handle sequence
records one validation across all six surfaces. Peak working set for the full
diagnostic materialization falls from 2,757 MiB to 2,587 MiB. The remaining
diagnostic result itself is 592 MB in R.

The one-call plan was also checked on a public availability-active fixture with
the same 3.6-million-row logical shape and 600 complete membership sets. Against
the exact pre-correction source (`93e4b347`), the exact corrected source reduces
validator time from 6.84 to 2.85 seconds and peak working set from 4,434 to 2,632
MiB. The cause of the former 4.9 GiB class peak was the exact membership/order
validation query plus DuckDB's default memory reservation, not the logical
decoder. The correction uses vectorized ASOF joins and caps only that query at
1 GiB when the caller's configured limit is higher, restoring the previous
limit on exit. A lower caller limit is never raised.

Clocks are diagnostic rather than gates. The registered gates are the exact
result/corruption tests, the one-validation call-count witness, and source-shape
checks that reject the former correlated per-row membership subqueries and
R-side materialization of the full logical trace.
