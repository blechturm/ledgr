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
