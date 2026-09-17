# ledgr Peer Parity And Performance Benchmark Report


This tracked report records the v0.2.0.1 internal same-host peer
workload. Parity is interpreted before timing. The report preserves
phase boundaries, unavailable engines, and classified divergences
without turning one host and one fixture into a public engine ranking.

The exact closeout command was:

``` powershell
& "C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe" dev/bench/peer_benchmark/peer_benchmark.R --preset record --release v0.2.0.1 --engine-set all --n-inst 500 --n-days 1260 --fast 5 --slow 10 --seed 20260530
```

The exact ignored local prefix is
`dev/bench/results/peer_benchmark_record_20260917T104909Z`. The record
was produced from `6b09a1b57ff42293091130d2dca565f224a29aea` under R
4.6.1 ucrt on Windows build 26200 with TTR 0.24.4. Backtrader and
zipline-reloaded completed through pinned `uv` environments. Quantstrat
was unavailable because its R packages were absent; local LEAN was
unavailable because its CLI root uses an obsolete organization layout.
No hosted LEAN service was used.

The durable and ephemeral canonical ledgr rows and the built-in SMA row
agree at the registered tolerance. Backtrader and zipline-reloaded pass
the registered Tier 1 tolerance while retaining classified residuals,
predominantly position sizing and, for Zipline, fill timing.

> **Scope of this report**
>
> Internal repo-local benchmark. Same host, same seed, single fixture. A
> B2 row, when explicitly requested, remains an opt-in
> (`compiled_accounting_model = "spot_fifo"`) on ledgr’s
> ephemeral/memory-backed path. Default ledgr execution remains
> canonical R. Numbers are for maintainer use and release closeout, not
> a public ranking or a universal performance claim.

## Optional B2 timing context

Same fixture, same seed, same shared bars CSV. The B2 row uses ledgr’s
explicit `compiled_accounting_model = "spot_fifo"` spot-FIFO hot frame
on the ephemeral benchmark boundary; Backtrader uses its standard
event-driven loop. Both run the same SMA crossover strategy.

| Note |
|:---|
| No B2 spot-FIFO peer-shaped row found beside this record bundle. Run the record command with –compiled-accounting-model spot_fifo to populate this section. |

Two ratios, both honest. The engine-phase ratio is the slice the
compiled hot frame actually replaces. The core-wall ratio is what a user
sees end-to-end. The remaining wall B2 spends after the engine phase is
R-side results materialization: building the canonical equity, fills,
and trades artifacts the harness measures. Backtrader’s equivalent
results phase is much smaller because it writes raw CSVs without
canonical materialization.

## Why parity comes before timing

A speed number only matters if the engine produces the same answer.
ledgr’s compiled `spot_fifo` row matches canonical ledgr ephemeral with
zero parsed canonical-output difference on this fixture across equity,
cash, and the position proxy.

When present, the compiled row is interpreted only after its canonical
outputs agree with the R path. Peer-by-peer parity against ledgr
canonical follows below; timing does not waive a failed semantic
comparison.

## Full peer comparison

When requested, the B2 sidecar row is measured on the same fixture as
the seven-row peer record bundle and appended here for timing context.
Backtrader, Zipline, quantstrat, and LEAN retain their declared
lifecycle boundaries and availability states; no row is treated as
universally representative of its engine or language.

ledgr appears in canonical and B2 rows because both answer useful
questions. Canonical durable and ephemeral track the R fold and the
auditability surface ledgr ships by default. B2 tracks the opt-in
compiled hot frame. Keeping both prevents reading a compiled opt-in
result as a default ledgr claim.

| Engine row | Status | Cost | Risk | Compiled | Full row | Snapshot prepare | Experiment setup | Engine phase | Results | Cold | Warm | Bars/sec |
|:---|:---|:---|:---|:---|:---|:---|:---|:---|:---|:---|:---|:---|
| ledgr_ttr_canonical | DONE | cost_zero | risk_none | NA | 166.640 | 19.860 | 0.410 | 136.670 | 9.660 | 166.600 | 146.740 | 3,781.51 |
| ledgr_ttr_canonical_ephemeral | DONE | cost_zero | risk_none | NA | 144.750 | 10.210 | 0.230 | 124.110 | 10.190 | 144.740 | 134.530 | 4,352.63 |
| ledgr_builtin_sma | DONE | cost_zero | risk_none | NA | 164.040 | 19.110 | 0.450 | 136.370 | 8.110 | 164.040 | 144.930 | 3,840.53 |
| quantstrat | UNAVAILABLE | NA | NA | NA | 0.050 | NA | NA | NA | NA | NA | NA | NA |
| backtrader | DONE | NA | NA | NA | 85.700 | 0.574 | 6.101 | 78.749 | 0.266 | 85.690 | 85.116 | 7,352.08 |
| zipline-reloaded-full | DONE | NA | NA | NA | 306.510 | 17.349 | 12.792 | 275.830 | 0.539 | 306.510 | 289.161 | 2,055.4 |
| LEAN | UNAVAILABLE | NA | NA | NA | 8.630 | NA | NA | NA | NA | NA | NA | NA |

Read `Cold` as the sum of snapshot preparation, experiment setup,
engine, and results. Read `Warm` as the same row without reusable
snapshot preparation. `Full row` is the wrapper clock around the engine
row; phase definitions are in the Methodology section.

For peer comparison, this complete boundary is the cold end-to-end view
when the engines perform meaningfully comparable preparation and produce
the required outputs. ledgr’s repeated research workflow has a separate
warm clock over an existing unchanged, verified snapshot. Snapshot
preparation is paid once per unchanged data-and-facts identity and again
after that identity changes.

![](peer_benchmark_files/figure-commonmark/unnamed-chunk-6-1.png)

## Equity curves

Each engine’s equity is normalized to its first observed value, so curve
shape is comparable without implying an absolute return ranking. A
flat-overlapping bundle of curves is the expected pattern when parity
holds; visible separation is a divergence-source signal worth
investigating in the parity tables below.

![](peer_benchmark_files/figure-commonmark/unnamed-chunk-7-1.png)

## Peer parity

ledgr’s canonical TTR row is the parity reference. Each peer is compared
against it across three tiers: per-bar equity behavior, derived top-line
metrics, and trade-level surface. A peer that disagrees with canonical
TTR gets a `review` status and a documented divergence attribution
rather than being treated as wrong by default.

The mental move when a parity check fails is to consider three
candidates in order: ledgr is wrong, the peer is wrong, the harness is
wrong. The residual difference is then attributed to a named source:
indicator initialization window, fill-timing edge, cost or margin
default, position-sizing rounding, timestamp alignment, or
float-ordering rounding.

### Tier 1: per-bar equity behavior

| Peer | Tier 1 | Parity surface | Equity corr | Max div | Return corr |
|:---|:---|:---|:---|:---|:---|
| ledgr_ttr_canonical_ephemeral | pass | equity + fills + realized trades | 1.000000 | \<0.0001% | 1.000000 |
| ledgr_builtin_sma | pass | equity + fills + realized trades | 1.000000 | 0% | 1.000000 |
| quantstrat | review (partial surface) | partial: equity + trade count only | NA | NA | NA |
| backtrader | pass | equity + fills + realized trades | 0.999999 | 0.06082% | 0.999746 |
| zipline-reloaded-full | pass | equity + fills + realized trades | 0.999757 | 0.2486% | 0.146064 |
| LEAN | review | unavailable | NA | NA | NA |

Rows in `review` carry an explicit attribution:

| Peer       | Review attribution       |
|:-----------|:-------------------------|
| quantstrat | unavailable peer surface |
| LEAN       | unavailable peer surface |

![](peer_benchmark_files/figure-commonmark/unnamed-chunk-10-1.png)

### Tier 2: derived top-line metrics

| Peer | Total return delta | Sharpe diff | Max DD delta |
|:---|:---|:---|:---|
| ledgr_ttr_canonical_ephemeral | \<0.00001 pp | 0.000000000000363265 | \<0.00001 pp |
| ledgr_builtin_sma | 0 pp | 0 | 0 pp |
| quantstrat | NA | NA | NA |
| backtrader | -0.055685 pp | -0.00973772 | -0.00017200 pp |
| zipline-reloaded-full | -0.18998 pp | -0.125183 | -0.0019703 pp |
| LEAN | NA | NA | NA |

### Tier 3: trade-level surface

| Peer | Trade count diff | Trade surface | Parity note |
|:---|---:|:---|:---|
| ledgr_ttr_canonical_ephemeral | 0 | available_realized_pnl | equity + fills + realized trades |
| ledgr_builtin_sma | 0 | available_realized_pnl | equity + fills + realized trades |
| quantstrat | NA | unavailable | partial: equity + trade count only |
| backtrader | -238 | available_realized_pnl | equity + fills + realized trades |
| zipline-reloaded-full | -682 | available_realized_pnl | equity + fills + realized trades |
| LEAN | NA | unavailable | unavailable |

### Per-bar divergence attribution

Every DONE peer row writes a per-bar `_divergence.csv` plus a
`_divergence_summary.csv`. The attribution columns below decompose total
absolute equity divergence against `ledgr_ttr_canonical` into named
sources.

| Peer | Total abs divergence | Diverging bars | First divergence | Indicator warmup | Fill timing | Calendar | Position size | Float rounding | Other |
|:---|:---|---:|:---|:---|:---|:---|:---|:---|:---|
| ledgr_ttr_canonical_ephemeral | 0.00004476123 | 1221 | 2018-01-15T00:00:00Z | 0% | 0% | 0% | 0% | 100.0% | 0% |
| ledgr_builtin_sma | 0 | 0 | NA | 0% | 0% | 0% | 0% | 100.0% | 0% |
| backtrader | 6931489\. | 1250 | 2018-01-15T00:00:00Z | 0% | 0.01299% | 0% | 99.99% | 0% | 0% |
| zipline-reloaded-full | 9200442\. | 1000 | 2018-01-16T00:00:00Z | 0% | 26.01% | 0% | 73.99% | 0% | 0% |

## Methodology

### Harness

The harness lives at `dev/bench/peer_benchmark/peer_benchmark.R`. It
runs two checks per peer: numerical parity against ledgr canonical TTR,
and same-host phase timing. The parity check asks whether the engines
agree on this strategy and data. The timing check asks how long this
local same-host harness took under the declared boundary.

Smoke command:

``` powershell
& "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe" dev/bench/peer_benchmark/peer_benchmark.R --preset smoke
```

Record command:

``` powershell
& "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe" dev/bench/peer_benchmark/peer_benchmark.R --preset record
```

Record command with the opt-in B2 row:

``` powershell
& "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe" dev/bench/peer_benchmark/peer_benchmark.R --preset record --compiled-accounting-model spot_fifo
```

Current-surface cost/risk-chain command:

``` powershell
& "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe" dev/bench/peer_benchmark/peer_benchmark.R --preset record --engine-set ledgr-cost --release v0.1.9.6
```

The harness writes ignored local artifacts under `dev/bench/results/`:
one shared bars CSV with input hash, per-engine canonical equity curves
where available, fills and trade summary tables where available, engine
surface-status rows for unavailable outputs, Tier 1/2/3 parity CSVs,
performance timing CSV, environment metadata JSON, and append-only
parity history JSON under `dev/bench/results/parity_history/`.

### Required rows

| Row | Status policy |
|----|----|
| ledgr canonical TTR | Required; errors if `TTR` is missing. |
| ledgr canonical TTR ephemeral | Required; runs the same fold core through an in-memory output handler and must match durable ledgr equity/fills before the run is accepted. |
| ledgr current-surface cost/risk ephemeral | Optional internal measurement row; enabled with `--engine-set ledgr-cost`; runs zero-cost/no-risk and public cost/risk-chain rows on the same fixture and seed. |
| ledgr B2 spot-FIFO ephemeral | Optional; enabled with `--compiled-accounting-model spot_fifo`; uses the same bars/features/strategy surface as ledgr canonical TTR ephemeral, uses the same closed enum and memory-handler dispatch as the public `compiled_accounting_model = "spot_fifo"` sweep opt-in, and must match canonical ledgr outputs before being interpreted as a peer-comparison row. |
| ledgr built-in SMA diagnostic | Required; runs through ledgr built-ins. |
| quantstrat | Runs when local R packages are installed; otherwise explicit unavailable row. |
| Backtrader | Managed through `dev/bench/peer_benchmark/python/backtrader/` and run through `python -m uv`. |
| zipline-reloaded full engine | Managed through `dev/bench/peer_benchmark/python/zipline/`; temporary csvdir bundle ingestion plus `zipline.run_algorithm()`. |
| LEAN CLI | Managed through `dev/bench/peer_benchmark/python/lean/`; invokes the local LEAN CLI or reports unavailable with the CLI failure reason. |

Optional peers must emit a status row. Missing fills/trade surfaces are
labeled with unavailable metadata rather than silently dropped.

### Phase definitions

Each DONE row in the performance table is split into four measured
phases:

- **Snapshot preparation**: reusable native data or bundle preparation.
- **Experiment setup**: construction repeated for each experiment.
- **Engine**: from ready-to-iterate until strategy execution completes
  and engine state is final.
- **Results**: from final engine state until canonical equity, fills,
  and trades are materialized for this harness.

The four phase columns must reconcile to the cold clock within 0.5
seconds or the harness aborts. The warm clock is experiment setup plus
engine plus results. LEAN is the one explicit exception: when the local
CLI runs, the whole CLI subprocess is bucketed as engine time because
preparation, execution, and extraction are not separable from outside
the CLI.

| Engine | Ingestion | Engine | Results |
|----|----|----|----|
| `ledgr_ttr_canonical` | `read.csv`, timestamp normalization, DuckDB snapshot creation, experiment construction | `ledgr_run()` | `ledgr_results()` for equity/fills plus canonical materialization |
| `ledgr_ttr_canonical_ephemeral` | `read.csv`, timestamp normalization, in-memory bars/features/projection construction | `ledgr_execute_fold()` with `ledgr_memory_output_handler()` | event-stream equity/fills reconstruction plus canonical materialization |
| `ledgr_ttr_canonical_ephemeral_with_cost_risk` | Same ephemeral ledgr boundary as `ledgr_ttr_canonical_ephemeral` | fold execution with `ledgr_cost_chain(spread_bps=5, fixed_fee=1)` and `ledgr_risk_chain(long_only, max_weight=0.20)` | event-stream equity/fills canonical materialization |
| `ledgr_ttr_compiled_spot_fifo_ephemeral` | Same ephemeral ledgr boundary as `ledgr_ttr_canonical_ephemeral` | fold execution with `compiled_accounting_model = "spot_fifo"` on the memory handler | event-stream equity/fills canonical materialization |
| `ledgr_builtin_sma` | Same durable ledgr boundary with built-in SMA features | `ledgr_run()` | `ledgr_results()` for equity/fills plus canonical materialization |
| `quantstrat` | `read.csv`, xts/globalenv construction, portfolio/account/orders/strategy setup | `applyStrategy()` plus account updates | account/transaction extraction plus canonical materialization |
| `backtrader` | `read.csv`, `PandasData` construction, `cerebro.adddata` loop | `cerebro.run()` | CSV writes from in-memory observer/fill rows |
| `zipline-reloaded-full` | `read.csv`, temporary csvdir creation, bundle registration and ingest | `run_algorithm()` | performance-frame transaction/equity extraction plus CSV writes |
| `LEAN` | Not separable from outside the CLI | whole CLI subprocess if available | Not separable from outside the CLI |

Boundary ambiguity decisions: quantstrat initialization is ingestion
because it builds native portfolio/order state before strategy
iteration; zipline bundle registration/ingest is ingestion because it
creates the native bundle consumed by `run_algorithm()`; LEAN CLI phases
are unavailable from outside the CLI.

| Engine | Boundary |
|:---|:---|
| ledgr_ttr_canonical | durable ledgr: snapshot preparation=bars CSV read plus DuckDB snapshot; experiment setup=ledgr_experiment plus run identity; engine=ledgr_run; results=ledgr_results equity/fills plus canonical materialization |
| ledgr_ttr_canonical_ephemeral | ephemeral ledgr: snapshot preparation=bars CSV read plus reusable bars matrices/views; experiment setup=features/projection plus execution spec; engine=ledgr_execute_fold with memory output handler; results=event-stream equity/fills reconstruction plus canonical materialization |
| ledgr_builtin_sma | durable ledgr built-in SMA: snapshot preparation=bars CSV read plus DuckDB snapshot; experiment setup=ledgr_experiment plus run identity; engine=ledgr_run; results=ledgr_results equity/fills plus canonical materialization |
| quantstrat | snapshot preparation=bars CSV read plus xts/globalenv setup; experiment setup=portfolio/account/orders/strategy setup; engine=applyStrategy plus account updates; results=equity/transaction extraction plus canonical writes |
| backtrader | snapshot preparation=bars CSV read plus grouped pandas bars; experiment setup=PandasData feeds, cerebro.adddata, broker and strategy; engine=cerebro.run; results=canonical equity/fill/trade writes |
| zipline-reloaded-full | snapshot preparation=bars CSV read, temporary csvdir construction, bundle registration and ingest; experiment setup=algorithm callbacks and calendar; engine=zipline run_algorithm; results=canonical equity/fill/trade writes |
| LEAN | snapshot preparation=shared-bars inspection; experiment setup=temporary project and config; engine=whole LEAN CLI subprocess including inseparable internal data loading; results=result extraction and canonical writes |

### Parity tiers

Tier 1 per-bar parity: equity-curve correlation, max single-bar equity
divergence as a fraction of ledgr equity, daily-return correlation, cash
trajectory match where both engines expose cash, and position proxy
match where both engines expose comparable positions.

Tier 2 derived top-line parity: total return, annualized return,
annualized volatility, Sharpe ratio where defined, and max drawdown.

Tier 3 trade-level parity: trade count, win rate and average trade where
the peer exposes comparable realized trade data, and explicit
unavailable metadata where the peer does not.

The ledgr crossover strategy used by this report is vectorized over
`ctx$features_wide`. It keeps previous crossover state in
`ctx$state_prev`, but the current feature comparison and target updates
are vector operations rather than a per-instrument R loop.

### Parity glossary

| Label | Meaning |
|----|----|
| `Tier 1` | Per-bar equity/return parity status. `pass` means the row passed the current tolerance; `review` means the row has a documented divergence attribution. |
| `Parity surface` | Which comparable artifacts exist for that peer. Quantstrat is partial because this harness currently gets account equity and transaction count, not comparable fills or realized trade P&L. |
| `Equity corr` | Correlation between peer equity and ledgr canonical equity. Closer to 1 is better. |
| `Max div` | Largest single-bar equity difference versus ledgr canonical, shown as a percent of ledgr equity. Lower is better. |
| `Return corr` | Correlation between one-bar equity changes. Closer to 1 is better. |
| `Total return delta` | Peer total return minus ledgr canonical total return, in percentage points. |
| `Sharpe diff` | Peer Sharpe minus ledgr canonical Sharpe. |
| `Max DD delta` | Peer max drawdown minus ledgr canonical max drawdown, in percentage points. |
| `Trade count diff` | Peer closed-trade count minus ledgr canonical closed-trade count. |

### Engine status

| Engine | Status | Reason |
|:---|:---|:---|
| ledgr_ttr_canonical | DONE | 9.66 |
| ledgr_ttr_canonical_ephemeral | DONE | 10.19 |
| ledgr_builtin_sma | DONE | 8.11000000000001 |
| quantstrat | UNAVAILABLE |  |
| backtrader | DONE | 0.266139500002623 |
| zipline-reloaded-full | DONE | 0.539096700001892 |
| LEAN | UNAVAILABLE | LEAN CLI unavailable: lean backtest rejected the temporary project root; local lean init organization setup is required. |

### Surface availability

| engine | equity | fills | trades |
|:---|:---|:---|:---|
| ledgr_ttr_canonical | available | available | available_realized_pnl |
| ledgr_ttr_canonical_ephemeral | available | available | available_realized_pnl |
| ledgr_builtin_sma | available | available | available_realized_pnl |
| quantstrat | unavailable | unavailable | unavailable |
| backtrader | available | available | available_realized_pnl |
| zipline-reloaded-full | available | available | available_realized_pnl |
| LEAN | unavailable | unavailable | unavailable |

### Latest record bundle

| field | value |
|:---|:---|
| created_at | 2026-09-17T10:49:09Z |
| release | v0.2.0.1 |
| preset | record |
| input_hash | 0b183457b3fe720d63b02a90fe552e1202fdb31b4e967a75e91304f9d3e416fc |
| git_sha | 6b09a1b57ff42293091130d2dca565f224a29aea |

## Caveats

### Same-host scope

Hardware, R version, OS, and toolchain versions are pinned to the
maintainer’s environment. The numbers are comparable within this record
bundle. They are not a portable speed ranking across hosts or a public
benchmark claim.

### Interpreting the B2 row

The B2 row is interpreted only when measured on the same peer fixture as
the external engines: same shared bars CSV, same fast/slow SMA settings,
same seed. It is also an opt-in compiled accelerator measurement, not a
default ledgr claim. ledgr’s default execution path remains canonical R.
Do not combine B2 numbers arithmetically with workload-grid B2 rows,
which use a different fixture.

### Engines deliberately excluded

VectorBT is excluded from the event-driven peer table because it is a
vectorized engine and a different paradigm. Published external LEAN and
Ziplime reference rows remain context-only. The same-host LEAN row is
driven only through the real LEAN CLI; if that CLI is not usable
locally, the row is marked unavailable.

### Historical-shape context

Do not compare bars/sec here directly to the v0.1.8.7
`peer_sma_crossover` row as a pure version regression. That row used the
same 500 x 1260 scale but a continuous `fast > slow` target strategy and
far fewer fills. This row uses high-turnover crossover-state semantics
plus per-engine parity artifacts and surface-status outputs. The
four-phase table is the useful comparison artifact, not a single
bars/sec headline.
