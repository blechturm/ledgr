# R cost reference, 2026-11-03

Reference numbers for reviewing hot-path code: what common R operations
cost per call at ledgr's scale, and where `collapse` is faster or slower
than base R. They give the order of magnitude for the rules in
`inst/design/manual/optimization_coding_style.qmd` ("Reference Costs").
This is not a gate and nothing runs it automatically.

- `costs.R`: 138 operations in eight groups (call overhead, time, strings,
  construction, lookup, vector work, serialisation, DuckDB) on vectors of
  500 instruments. `evidence/costs.csv` adds the cost per run if the call
  happens once per pulse at 1,260 pulses.
- `pairs.R`: 53 base/collapse pairs (reductions, matching, search,
  ordering, writes, frames, grouped and matrix work) at 500 and 5,000
  instruments. Every pair is checked to return equal results before it is
  timed; all 106 rows in `evidence/pairs.csv` are equal or in-place writes.

## Method

Each case is a byte-compiled closure timed with `microbenchmark`; the
median is reported. Cases faster than 20 us run 100 times per measurement
and are divided back, so the Windows timer floor (about 0.1 us) does not
dominate. Medians are isolated, warm-cache costs: inside real code,
allocation and garbage collection add to them. Read them as lower bounds
and orders of magnitude.

## Provenance of the committed records

- ledgr rows: build of `ae289ce0` (`release/v0.2.3`, Cut 9 head), installed
  with `R CMD INSTALL` into a scratch library.
- Windows 11, R 4.6.1, collapse 2.1.8 (`set_collapse(nthreads = 1)`),
  yyjsonr 0.1.22, jsonlite 2.0.0, digest 0.6.39, openssl 2.4.2,
  tibble 3.3.1, duckdb 2.0.0 (in-memory database), microbenchmark 1.5.0.
- High performance power plan, process affinity `0xFFFF` (P-cores), no
  other R process running.

## Reproduction

```text
R CMD INSTALL --no-docs --library=<lib> <ledgr source tree>
Rscript dev/bench/v0_2_3_r_cost_reference/costs.R <lib> dev/bench/v0_2_3_r_cost_reference/evidence/costs.csv
Rscript dev/bench/v0_2_3_r_cost_reference/pairs.R dev/bench/v0_2_3_r_cost_reference/evidence/pairs.csv
```

Run each process with P-core affinity and the High performance plan, as in
"Timing Gates On The Maintainer Host" in
`inst/design/manual/benchmark_methodology.qmd`.
