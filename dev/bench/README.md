# ledgr Local Benchmark Suite

This directory contains the v0.1.8.6 structured benchmark suite. It is a local
development harness, not a public performance dashboard.

Run from the package root:

```powershell
& "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe" dev/bench/run_benchmarks.R --preset smoke --repeats 1 --warmup 1
```

The runner loads current source with `pkgload::load_all(".")` when it is run
from the ledgr source tree and fails rather than silently measuring a stale
installed package. Outputs are written under `dev/bench/results/` by default:

- raw per-iteration CSV;
- scenario summary CSV;
- environment metadata JSON;
- combined JSON result payload;
- compact Markdown summary;
- QuantConnect/LEAN side-by-side CSV when `lean_reference.csv` is present.

The QuantConnect/LEAN comparison is a caveated side-by-side throughput
reference. It is not a parity claim and not a speed ranking. The comparable
headline unit is `security_bars_sec = n_inst * n_pulses / t_wall`; do not
substitute `feature_cells_sec`, which is `n_feat` times larger for feature
payload scenarios.

Named scenarios:

- `baseline_single_run`
- `pulse_loop_empty`
- `wide_panel_no_features`
- `feature_read_score`
- `feature_turnover`
- `indicator_payload`
- `sweep_memory_summary`
- `persistent_replay`
- `peer_sma_crossover` (matched Ziplime/Zipline/Backtrader workload; see Peer Framework Reference)

Use `--preset smoke` for a quick verification run and `--preset record` for the
release-record benchmark shape. The record preset is still local and
machine-dependent; release notes should cite it with environment metadata.

## Peer Framework Reference

`dev/bench/ziplime_reference.csv` holds published throughput numbers for the
interpreted, event-driven Python peer group (Ziplime, Zipline, Backtrader),
scraped by `fetch_ziplime_reference.R`:

```powershell
& "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe" -e 'source("dev/bench/fetch_ziplime_reference.R"); fetch_ziplime_reference()'
```

These are **vendor self-reported** numbers from the Ziplime README (Apple Silicon
M3, methodology unstated, execution time likely includes data load). The local
development host is an Intel Core i9-12900K desktop system: plausibly the same
broad single-core class as M3, but benchmark-dependent and not the same
hardware. Every published peer row is therefore
`comparable = "orientation_only"`: useful for peer *ordering* and
order-of-magnitude context, never a controlled head-to-head, because package
versions, host details, and the execution-time boundary are not controlled by
ledgr. The VectorBT figure that circulates with this table is deliberately
excluded -- it is not in the source and it is a vectorized engine, a category
mismatch with per-bar event engines. Provenance is recorded in
`ziplime_reference.meta.json` (source, retrieved_at, README sha256, exclusions).
This reference is NOT fed into the LEAN side-by-side ratio.

The `peer_sma_crossover` scenario matches that workload (500 assets, 5 years
daily, SMA crossover via `TTR::SMA`, `persist_features = FALSE`) so ledgr can be
measured on the same shape. A defensible comparison still requires running the
peer engines and ledgr on the SAME machine; the published numbers above only fix
the workload, not the host.

## Width Sweep

Batch 4 uses a separate two-mode width sweep:

```powershell
& "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe" dev/bench/run_width_sweep.R --preset smoke --repeats 1 --warmup 1
```

The width sweep writes raw results, summaries, isolated schema-vs-full-long
view timings, and a storage decision record under `dev/bench/results/`.

Modes:

- `read_score`: reads and scores features without fills.
- `turnover`: reads and scores features, generates representative fills, and
  measures persistent replay/read-back.

The isolated view timing is the one to use for schema-only versus full-long
materialization cost. The benchmark `t_residual_sec` column is deliberately a
broad wall-minus-pre-minus-loop residual and includes wrapper/read-back work.
