# Fill-heavy stage profile, 2026-11-02

Descriptive baseline, not a gate. It answers where a fill-heavy durable run
spends its time per fold stage, and how that moved from v0.2.2 through Cut 6
to Cut 7. The macro plan cites it as the WS7/WS8 "before" baseline and as
WS14a review input.

## Workload

The published peer-benchmark headline: `ledgr_sim_bars(500, 1260, seed =
20260530, start = "2020-01-01", instrument_prefix = "P")`, stamped 21:00 UTC,
OHLCV rounded to 8 places; SMA5/SMA10 transition rule, cash 1e7, zero cost,
no risk; durable `ledgr_run()` then `ledgr_results(bt, "fills")` and
`"equity"`. 67,725 fills (about 54 per pulse) and final equity
10728506.707646 in every build.

## Builds

| Build | Commit | Strategy body |
| --- | --- | --- |
| v0.2.2 | `7539be45` (R identical to published benchmark build `891c23c8`) | `old`: `ctx$state_prev`, `state_update` lists |
| Cut 6 head | `14252ffb` | `old` |
| Cut 7 head | `e04786ef` (`codex/cut7-ws5`) | `new`: declared `asset_state`, `ledgr_strategy_result()` |

Each build is installed with `R CMD INSTALL` into its own library.

## Commands

```
Rscript fixture.R <lib> <fixture.rds>
Rscript probe.R <lib> <label> old|new <fixture.rds> <out_dir>
Rscript classify.R <out_dir>/rprof.out <build_source>/R <classified_dir>
Rscript summarize.R <scratch_dir>
```

`probe.R` runs three timed reps and one `Rprof` rep (10 ms). Cut 6 and Cut 7
were run alternately, two processes each. `classify.R` assigns each sample to
the innermost fold stage on its stack (`ledgr_fold_stage_*`), else "run
outside stages" (setup, envelope flush, finalisation) or "results read".
`summarize.R` scales each build's profile shares to its median unprofiled
`run` time; `summarize.R` hard-codes the scratch directory names used on
2026-11-02.

## Result (`evidence/stages.csv`, seconds per run)

| Region | v0.2.2 | Cut 6 | Cut 7 |
| --- | ---: | ---: | ---: |
| E observe/settle | 0.08 | 0.85 | 0.81 |
| P decide | 1.20 | 1.86 | 1.73 |
| P plan | 2.52 | 0.97 | 0.80 |
| P apply | 7.37 | 2.34 | 2.19 |
| P commit | 3.28 | 3.60 | 1.90 |
| Run outside stages | 5.64 | 2.41 | 2.33 |
| Results read (fills) | 3.78 | 1.50 | 1.66 |
| `ledgr_run` median | 20.1 | 12.0 | 9.7 |

Largest remaining costs at Cut 7: per-fill canonical JSON metadata in
`ledgr_fill_event_payload()` (most of P apply), DuckDB writes (per-pulse
`ledgr_store_append()` in P commit and the envelope flush), the fills reader's
FIFO replay, `ledgr_carrier_problem()` validation reached from every stage,
and per-pulse frame construction in P decide.

## Limits

Single host, no power-plan or affinity control, profile shares approximate.
One earlier Cut 6 process ran at about 23 s under unexplained machine load and
is excluded; the alternated runs are retained in `evidence/timings.csv`. The
strategy bodies differ because the state API changed between builds.
