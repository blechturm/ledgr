# Diagnostic decision-order validation shape

This bounded public-data probe exercises the exact release-width shape that
exposed the former R-side validation scan: 500 instruments by 1,260 sessions,
or 630,000 certified implicit decision rows. It records a full validation and
a one-instrument, one-pulse validation.

The production query decomposes the integer order token, reconstructs the
expected context order in DuckDB and returns at most one offending run. The
R boundary receives no logical diagnostic plane. `record.csv` therefore pins
both clean results at zero rows crossing DBI; `LTB-0558` pins the query shape
and the corruption cases. Elapsed times are descriptive, not a timing gate.
On the registered Windows/R 4.6.1 run, the full check took 0.36 seconds and
the filtered check 0.11 seconds, versus the review's 3.44 and 3.32 seconds for
the former R materialization.

Run from the repository root:

```powershell
& "C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe" `
  dev/bench/v0_2_3_diagnostic_order_validation/probe.R
```

