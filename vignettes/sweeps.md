# Exploratory Sweeps And Candidate Promotion


<style>
.ledgr-diagram {
  margin: 1.25rem auto 1.5rem auto;
  text-align: center;
}
&#10;.ledgr-diagram .mermaid {
  display: inline-block;
  max-width: 100%;
}
&#10;.ledgr-diagram .mermaid svg {
  display: block;
  height: auto !important;
  margin-left: auto;
  margin-right: auto;
}
&#10;.ledgr-grid-diagram .mermaid svg {
  max-width: 760px !important;
}
&#10;.ledgr-alias-diagram .mermaid svg {
  max-width: 820px !important;
}
</style>

This article explains how declared parameter variation becomes candidate
rows. The central idea is active aliases: one strategy can read stable
feature names such as `fast` and `slow` while the sweep varies the
concrete indicators behind those names.

Sweeps are for exploration. Promotion records one selected candidate as
a committed run. Neither step proves that the selected candidate will
generalize.

## Prerequisites

``` r
library(ledgr)
library(dplyr)
data("ledgr_demo_bars", package = "ledgr")
```

This article uses `dplyr` for tabular inspection. The sweep itself is
ledgr’s job.

## Sweep Is Exploration

<div class="ledgr-callout ledgr-callout-note">

**Definition**

A sweep is an evaluated candidate table over a declared grid. It is
exploratory: it returns candidate summaries, does not choose a winner,
and does not write candidate runs to the experiment store.

</div>

`ledgr_sweep()` evaluates a grid against a `ledgr_experiment()`. It
tells you what each declared candidate did. It does not decide which
candidate matters.

<div class="ledgr-callout ledgr-callout-note">

**Definition**

A sweep usually contains many candidates. Each candidate is one row of
the sweep: resolved feature parameters, strategy parameters, execution
seed, status, metrics, warnings or errors, and provenance.

</div>

That separation is the workflow boundary:

``` text
ledgr_sweep()                 explore declared candidates
ledgr_candidate()             select one row deliberately
ledgr_promote() / ledgr_run() commit an auditable run
```

<div class="ledgr-callout ledgr-callout-warning">

**Selection is not validation**

A sweep table records what was run. It does not prove that the selected
parameters were evaluated on held-out data. Promotion records a choice;
it does not make that choice out-of-sample.

</div>

## Declare Parameterized Features

Start with one sealed snapshot and one strategy. This article stays on
sweep mechanics rather than train/test or walk-forward evaluation.

``` r
bars <- ledgr_demo_bars |>
  filter(
    instrument_id %in% c("DEMO_01", "DEMO_02"),
    between(ts_utc, ledgr_utc("2019-01-01"), ledgr_utc("2019-06-30"))
  )

snapshot <- ledgr_snapshot_from_df(
  bars,
  snapshot_id = "sweep_alias_demo",
  db_path = tempfile(fileext = ".duckdb")
)

features <- ledgr_feature_map(
  fast = ledgr_ind_sma(ledgr_param("fast_n")),
  slow = ledgr_ind_sma(ledgr_param("slow_n"))
)

strategy <- ledgr_demo_sma_crossover_strategy()

exp <- ledgr_experiment(
  snapshot = snapshot,
  strategy = strategy,
  features = features,
  opening = ledgr_opening(cash = 100000),
  cost_model = ledgr_cost_zero()
)

exp
```

    ledgr_experiment
    ================
    Snapshot ID: sweep_alias_demo
    Database:    <temporary DuckDB path>
    Universe:    2 instruments
    Features:    2 mapped
    Opening:     cash=100000, positions=0
    Mode:        audit_log
    Metrics:     US equity daily (252 days/year * 1 bars/day = 252 bars/year)

The strategy function itself does not change across candidates. At each
pulse, ledgr calls the same `function(ctx, params)`: `ctx` contains the
current pulse-known market data, positions, cash, equity, and resolved
alias values; `params` contains the strategy-parameter values for this
candidate.

The demo strategy you assigned above follows this shape internally:

``` r
sma_crossover_body <- function(ctx, params) {
  targets <- ctx$flat()

  for (id in ctx$universe) {
    values <- ctx$features(id)
    if (
      passed_warmup(values) &&
        ((values[["fast"]] / values[["slow"]]) - 1) > params$threshold
    ) {
      targets[id] <- params$qty
    }
  }

  targets
}
```

During a sweep, `ctx$features(id)` returns values for the concrete
indicators resolved for that candidate. `params$threshold` and
`params$qty` come from the strategy grid. For the full strategy
contract, read `vignette("strategy-development", package = "ledgr")`.

<div class="ledgr-callout ledgr-callout-note">

**Definition**

An active alias is a stable strategy-facing feature name whose concrete
indicator can vary by candidate. The strategy reads aliases such as
`fast` and `slow`; ledgr resolves the concrete SMA windows for each
candidate before execution.

</div>

The strategy can keep reading `values[["fast"]]` and `values[["slow"]]`
even when one candidate uses SMA(5) and SMA(20) and another candidate
uses SMA(10) and SMA(40). The alias is the strategy-facing contract. The
concrete feature IDs and fingerprints are provenance.

Feature parameters vary the knobs exposed by a feature constructor. For
`ledgr_ind_sma()`, the knob is `n`, the moving-average window. For
TTR-backed features, the knobs are the supported arguments of the
wrapped TTR indicator. You still need to understand the feature you are
tuning; ledgr separates the parameter namespaces, but it does not decide
which indicator arguments are economically meaningful.

Only knobs declared with `ledgr_param("name")` need values in the
feature grid. Concrete arguments stay fixed. For example,
`ledgr_ind_sma(20)` needs no `feature_grid` entry, while
`ledgr_ind_sma(ledgr_param("fast_n"))` requires a scalar `fast_n` value
for each candidate.

<div class="ledgr-diagram ledgr-alias-diagram">

``` mermaid

flowchart TB
  params["feature params<br/>fast_n = 5<br/>slow_n = 20"]
  indicators["concrete indicators<br/>SMA 5 and SMA 20"]
  aliases["stable aliases<br/>fast and slow"]
  strategy["strategy reads<br/>fast and slow"]

  params --> indicators --> aliases --> strategy
```

</div>

For a second candidate with `fast_n = 10` and `slow_n = 40`, the same
arrows resolve to SMA(10) and SMA(40), but the strategy still reads
`values[["fast"]]` and `values[["slow"]]`. The aliases stay stable
across candidates.

## Build The Candidate Grid

<div class="ledgr-callout ledgr-callout-note">

**Definition**

Feature parameters materialize indicators before execution. Strategy
parameters are passed to `strategy(ctx, params)` during execution.
Keeping those namespaces separate is what lets a strategy read stable
aliases while the sweep varies indicator windows.

</div>

Use `ledgr_feature_grid()` for the feature knobs you decided to vary and
`ledgr_strategy_grid()` for the knobs in your own strategy code. Then
cross them with `ledgr_grid_cross()`.

``` r
feature_grid <- ledgr_feature_grid(
  fast_n = c(5L, 10L),
  slow_n = c(20L, 40L),
  .filter = fast_n < slow_n
)

strategy_grid <- ledgr_strategy_grid(
  threshold = c(0, 0.01),
  qty = c(5, 10)
)

grid <- ledgr_grid_cross(features = feature_grid, strategy = strategy_grid)
grid
```

    ledgr_param_grid
    ================
    Combinations: 16
    Labels:       feature_9a29b31dae19/strategy_86be010cf688, feature_9a29b31dae19/strategy_7ccbbefd14d1, feature_9a29b31dae19/strategy_ab759ad88623, feature_9a29b31dae19/strategy_dc6315936028, feature_af0f94c90243/strategy_86be010cf688, feature_af0f94c90243/strategy_7ccbbefd14d1
                  ... 10 more

    Grid labels identify sweep candidates; they are not committed run IDs.

The `.filter` expression is a structural grid constraint. Here it says
the fast moving average must be shorter than the slow moving average.
Filter expressions are evaluated against grid columns; they do not read
run state, feature data, or caller globals.

<div class="ledgr-callout ledgr-callout-warning">

**Mind the combinatorial explosion**

`ledgr_grid_cross()` multiplies grid dimensions. Four parameters with
five values each produce 625 candidates before you add another axis.
Keep early sweeps deliberately small, then expand only after the
candidate table is readable and the feature payload cost is understood.

</div>

The cross product is explicit:

<div class="ledgr-diagram ledgr-grid-diagram">

``` mermaid

flowchart TB
  fg["feature_grid<br/>fast_n, slow_n"]
  sg["strategy_grid<br/>threshold, qty"]
  cross["grid_cross"]
  rows["candidate rows<br/>feature params + strategy params"]

  fg --> cross
  sg --> cross
  cross --> rows
```

</div>

<div class="ledgr-callout ledgr-callout-tip">

**Try it**

Change `slow_n` to `c(20L, 40L, 60L)` and rerun the sweep. The strategy
code does not change. How many candidates appear after `.filter`, and
which candidate rows still use the same `fast` and `slow` aliases?

</div>

## Precompute Shared Features

Precomputing is an execution optimization, not a separate research
decision. The same declared feature grid is resolved once, deduplicated
by fingerprint, and reused across sweep candidates.

``` r
precomputed <- ledgr_precompute_features(exp, grid)
precomputed
```

    ledgr_precomputed_features
    ===========================
    Snapshot:   sweep_alias_demo
    Candidates: 16
    Features:   4
    Universe:   DEMO_01, DEMO_02
    Scoring:    2019-01-01T00:00:00Z to 2019-06-28T00:00:00Z

`ledgr_sweep()` can compute features internally for small grids. For
larger grids, precompute first so feature resolution and payload
validation are explicit. When a grid has more than 20 combinations and
no precomputed payload, ledgr warns because feature computation may be
repeated per candidate.

## Run The Sweep

Give the sweep a master seed when reproducible stochastic strategy
behavior matters. Each row receives its own derived `execution_seed`.
The default sweep is scalar-only: it keeps candidate summary rows but
not per-pulse return series.

``` r
sweep <- ledgr_sweep(
  exp,
  grid,
  precomputed_features = precomputed,
  seed = 2026L
)

sweep
```

    # ledgr sweep -- sweep_3f33242668ae4748
    # A tibble: 16 x 8
       candidate_id       candidate_row status sharpe_ratio total_return max_drawdown n_trades
       <chr>                      <int> <chr>         <dbl> <chr>        <chr>           <int>
     1 feature_9a29b31da~             1 DONE          0.541 +0.0%        -0.1%               6
     2 feature_9a29b31da~             2 DONE          3.07  +0.1%        -0.0%               3
     3 feature_9a29b31da~             3 DONE          0.541 +0.0%        -0.1%               6
     4 feature_9a29b31da~             4 DONE          3.08  +0.2%        -0.1%               3
     5 feature_af0f94c90~             5 DONE          1.80  +0.1%        -0.0%               5
     6 feature_af0f94c90~             6 DONE          2.05  +0.1%        -0.0%               3
     7 feature_af0f94c90~             7 DONE          1.80  +0.2%        -0.1%               5
     8 feature_af0f94c90~             8 DONE          2.05  +0.1%        -0.1%               3
     9 feature_6ff6fe3a1~             9 DONE          1.38  +0.1%        -0.0%               3
    10 feature_6ff6fe3a1~            10 DONE          2.12  +0.1%        -0.0%               2
    11 feature_6ff6fe3a1~            11 DONE          1.38  +0.1%        -0.1%               3
    12 feature_6ff6fe3a1~            12 DONE          2.12  +0.2%        -0.1%               2
    13 feature_fa560ccbe~            13 DONE          1.34  +0.1%        -0.0%               2
    14 feature_fa560ccbe~            14 DONE          1.30  +0.0%        -0.0%               2
    15 feature_fa560ccbe~            15 DONE          1.34  +0.1%        -0.1%               2
    16 feature_fa560ccbe~            16 DONE          1.30  +0.1%        -0.1%               2
    # i 1 more variable: execution_seed <int>

    # i 16 combinations: 16 done, 0 failed.
    # i Retention returns: none.
    # i Snapshot hash: 6eeff5ca520c516a61e0228c5ac06d22548c9d74e4e98d1e9f71fccdd2b8a87e.
    # i Cost model hash: 4011132b5979fc370e524ebbc525ac7f4158b4de43639ec985f4c90969b4b9d0.
    # i Metric context hash: 794b69bd7f9c704447d4b0208b8420cdf132ec7bd6582eaa037bf1066133c1bb.
    # i Saved artifact: not saved.
    # i Rows are printed in their current table order; rank or arrange explicitly before selecting candidates.
    # i Hidden columns (16): final_equity, annualized_return, volatility, win_rate, avg_trade, time_in_market, error_class, error_msg, params, feature_params, warnings, feature_fingerprints, provenance, t_engine, t_results, t_fills_extract

The table contains candidate summaries. It is not a full artifact store
and it does not write durable candidate ledgers, equity curves, feature
panels, or telemetry rows. Each row keeps the compact reproduction key
needed for later materialization: snapshot identity, selector, strategy
identity, feature fingerprints, seed metadata, and candidate params. Use
`ledgr_candidate_reproduction_key()` when you want to inspect that key
directly. Full equity, fills, trades, and ledger rows are created only
by committed runs.

If the experiment declares a `risk_chain`, sweep candidates also carry
`risk_chain_hash` and row-level provenance carries `risk_plan_json`.
These fields are execution identity: they say which target-risk plan
transformed the validated strategy targets before fill timing and cost
resolution. They do not rank candidates, select winners, estimate
liquidity, enforce broker policy, or turn risk settings into a separate
grid-composition surface. Parameterized risk arguments use ordinary
candidate params through `ledgr_param()`.

## Retain Candidate Return Series

When you need per-pulse net portfolio equity or adjacent-period returns
for completed candidates, opt in explicitly with
`ledgr_sweep_retention()`.

``` r
retained_sweep <- ledgr_sweep(
  exp,
  grid,
  precomputed_features = precomputed,
  seed = 2026L,
  retain = ledgr_sweep_retention("completed")
)

retained_long <- ledgr_sweep_returns(retained_sweep)

retained_long |>
  select(sweep_id, candidate_id, ts_utc, equity, period_return) |>
  slice_head(n = 8)
```

    # A tibble: 8 x 5
      sweep_id               candidate_id             ts_utc              equity period_return
      <chr>                  <chr>                    <dttm>               <dbl>         <dbl>
    1 sweep_1ce4ce04d65ece51 feature_9a29b31dae19/st~ 2019-01-01 00:00:00 100000            NA
    2 sweep_1ce4ce04d65ece51 feature_9a29b31dae19/st~ 2019-01-02 00:00:00 100000             0
    3 sweep_1ce4ce04d65ece51 feature_9a29b31dae19/st~ 2019-01-03 00:00:00 100000             0
    4 sweep_1ce4ce04d65ece51 feature_9a29b31dae19/st~ 2019-01-04 00:00:00 100000             0
    5 sweep_1ce4ce04d65ece51 feature_9a29b31dae19/st~ 2019-01-07 00:00:00 100000             0
    6 sweep_1ce4ce04d65ece51 feature_9a29b31dae19/st~ 2019-01-08 00:00:00 100000             0
    7 sweep_1ce4ce04d65ece51 feature_9a29b31dae19/st~ 2019-01-09 00:00:00 100000             0
    8 sweep_1ce4ce04d65ece51 feature_9a29b31dae19/st~ 2019-01-10 00:00:00 100000             0

`period_return` is `NA_real_` on the first retained row for each
candidate because there is no prior equity value to compare against.
Drop that first return before handing the series to an external metric
package:

``` r
external_metric_input <- retained_long |>
  filter(!is.na(period_return)) |>
  select(ts_utc, candidate_id, period_return)

external_metric_input |>
  slice_head(n = 8)
```

    # A tibble: 8 x 3
      ts_utc              candidate_id                               period_return
      <dttm>              <chr>                                              <dbl>
    1 2019-01-02 00:00:00 feature_9a29b31dae19/strategy_86be010cf688             0
    2 2019-01-03 00:00:00 feature_9a29b31dae19/strategy_86be010cf688             0
    3 2019-01-04 00:00:00 feature_9a29b31dae19/strategy_86be010cf688             0
    4 2019-01-07 00:00:00 feature_9a29b31dae19/strategy_86be010cf688             0
    5 2019-01-08 00:00:00 feature_9a29b31dae19/strategy_86be010cf688             0
    6 2019-01-09 00:00:00 feature_9a29b31dae19/strategy_86be010cf688             0
    7 2019-01-10 00:00:00 feature_9a29b31dae19/strategy_86be010cf688             0
    8 2019-01-11 00:00:00 feature_9a29b31dae19/strategy_86be010cf688             0

The retained series are net strategy returns. They include the execution
costs resolved by the experiment’s cost model, but they are not
benchmark-relative returns and they do not contain gross-vs-net
attribution. Failed candidates remain in the sweep summary table but
have no retained return rows.

Final-bar no-fill warnings are row-level warnings on the candidate
summary. They do not remove the final equity row from retained return
series.

Use the wide accessor when a downstream tool expects one return or
equity column per candidate:

``` r
ledgr_sweep_returns_wide(
  retained_sweep,
  candidates = retained_sweep$candidate_id[1:3],
  value = "returns"
) |>
  slice_head(n = 5)
```

    # A tibble: 5 x 4
      ts_utc              feature_9a29b31dae19~1 feature_9a29b31dae19~2 feature_9a29b31dae19~3
      <dttm>                               <dbl>                  <dbl>                  <dbl>
    1 2019-01-01 00:00:00                     NA                     NA                     NA
    2 2019-01-02 00:00:00                      0                      0                      0
    3 2019-01-03 00:00:00                      0                      0                      0
    4 2019-01-04 00:00:00                      0                      0                      0
    5 2019-01-07 00:00:00                      0                      0                      0
    # i abbreviated names: 1: `feature_9a29b31dae19/strategy_86be010cf688`,
    #   2: `feature_9a29b31dae19/strategy_7ccbbefd14d1`,
    #   3: `feature_9a29b31dae19/strategy_ab759ad88623`

## Save And Reopen Sweep Artifacts

A saved sweep is a compact artifact. It stores candidate summary
evidence and, when requested, retained net equity/return series. It is
not a batch of committed runs: full ledgers, fills, trades, and
per-instrument artifacts remain available only after explicit promotion.

``` r
saved_id <- ledgr_sweep_save(
  retained_sweep,
  snapshot,
  sweep_id = "sma_retained_sweep",
  note = "Exploratory SMA sweep with retained return series."
)

ledgr_sweep_list(snapshot)
```

    # ledgr saved sweep list
    # A tibble: 1 x 7
      sweep_id           created_at_utc      sweep_schema_version n_candidates n_completed
      <chr>              <dttm>                             <int>        <int>       <int>
    1 sma_retained_sweep 2026-06-07 23:28:57                    1           16          16
    # i 2 more variables: retention_returns <chr>, note <chr>

    # i Open one saved sweep with ledgr_sweep_open(snapshot, sweep_id).

``` r
reopened_sweep <- ledgr_sweep_open(snapshot, saved_id)

ledgr_sweep_info(reopened_sweep)
```

    ledgr Sweep Info
    ================

    Sweep ID:          sma_retained_sweep
    Snapshot:          sweep_alias_demo
    Snapshot Hash:     6eeff5ca520c516a61e0228c5ac06d22548c9d74e4e98d1e9f71fccdd2b8a87e
    Candidates:        16
    Completed:         16
    Failed:            0
    Retention returns: completed
    Cost Model Hash:   4011132b5979fc370e524ebbc525ac7f4158b4de43639ec985f4c90969b4b9d0
    Metric Hash:       794b69bd7f9c704447d4b0208b8420cdf132ec7bd6582eaa037bf1066133c1bb
    Feature Union:     ec14bedb02755979b16a79f7f101e821c00df9ec24f778a0a54ea53be608aca6

    Saved artifact
    Created At:        2026-06-07 23:28:57.696356
    Schema Version:    1
    Engine Version:    0.1.9.2
    Note:              Exploratory SMA sweep with retained return series.

Reopened sweeps behave like sweep result objects for candidate
extraction, ordinary dplyr inspection, retained return access, and
promotion. Promotion from a reopened saved sweep re-executes the
selected candidate from its reproduction key against the sealed
snapshot; it does not replay precomputed retained return rows as if they
were a committed ledger.

``` r
ledgr_sweep_returns(reopened_sweep) |>
  filter(candidate_id == reopened_sweep$candidate_id[[1]]) |>
  slice_head(n = 5)
```

    # A tibble: 5 x 5
      sweep_id           candidate_id                 ts_utc              equity period_return
      <chr>              <chr>                        <dttm>               <dbl>         <dbl>
    1 sma_retained_sweep feature_9a29b31dae19/strate~ 2019-01-01 00:00:00 100000            NA
    2 sma_retained_sweep feature_9a29b31dae19/strate~ 2019-01-02 00:00:00 100000             0
    3 sma_retained_sweep feature_9a29b31dae19/strate~ 2019-01-03 00:00:00 100000             0
    4 sma_retained_sweep feature_9a29b31dae19/strate~ 2019-01-04 00:00:00 100000             0
    5 sma_retained_sweep feature_9a29b31dae19/strate~ 2019-01-07 00:00:00 100000             0

## Three Evidence Tiers

Sweeps now give you three different levels of evidence. Use the cheapest
level that answers the question in front of you, then promote only the
candidate that needs committed-run artifacts.

| Tier | What it keeps | Typical use |
|----|----|----|
| Scalar row | Candidate params, status, scalar metrics, warnings, and reproduction key | Screen and debug a declared grid |
| Retained series | Scalar row plus net portfolio equity and period returns for completed candidates | Inspect return shape, rolling behavior, or external metric-package inputs |
| Promoted run | Full committed run artifacts: ledger, fills, trades, equity, metrics, and promotion context | Audit and reopen the selected candidate as a durable run |

Retention does not change execution identity. It changes which derived
evidence is kept after the same candidate execution.

Saved sweeps persist the same risk identity fields on the parent sweep
row and candidate rows. The first `ledgr_sweep_save()` against a
v0.1.9.2 store performs an additive saved-sweep schema migration for
`risk_chain_hash` and `risk_plan_json`; it does not rewrite candidate
results or create committed run artifacts.

## What Retained Returns Can And Cannot Validate

Retained returns make triage better because they let you inspect the
path of a candidate, not just its final scalar score. They can help you
notice unstable return profiles, drawdown concentration, missing warmup
behavior, and candidates whose scalar score hides a bad path.

They do not make the sweep statistically valid. If you selected the
candidate from the same sample, the retained path is still in-sample
evidence. Generalized validation belongs to a held-out evaluation,
walk-forward analysis, or later selection-integrity diagnostics.

<div class="ledgr-callout ledgr-callout-warning">

**Return paths are not validation by themselves**

Retained series preserve more evidence from a sweep. They do not prove
that the candidate-selection process was sound.

</div>

## Why ledgr And PerformanceAnalytics Metrics May Differ

Retained return series can be shaped for packages such as
PerformanceAnalytics, but ledgr metrics and external package metrics may
differ. Annualization, calendar assumptions, treatment of the leading
missing return, and return-shape conventions are package contracts, not
universal truths.

Keep ledgr’s scalar metric rows as the canonical ledgr evidence. Use
external metric packages as additional analysis over an explicit return
series, and label any overlapping headline metric when it comes from a
different convention.

The rest of this article uses the reopened sweep for candidate
inspection and promotion. That demonstrates that a saved sweep reopens
to the same dplyr-friendly surface as the in-session result.

The default sweep path is memory-backed and uses the canonical R
accounting fold. When your workload is spot-asset FIFO and you want the
scoped B2 accelerator, opt in explicitly:

``` r
sweep <- ledgr_sweep(
  exp,
  grid,
  precomputed_features = precomputed,
  seed = 2026L,
  compiled_accounting_model = "spot_fifo"
)
```

`compiled_accounting_model = NULL` remains the default. `"spot_fifo"` is
a memory-backed sweep accelerator only: it is not a general compiled
fold core, not the durable `ledgr_run()` path, not a non-spot accounting
model, and not enabled by default.

For independent candidates, `workers` can dispatch sweep rows in
parallel when the required backend and worker package dependencies are
available. Parallelism changes candidate dispatch, not strategy
semantics; interrupted parallel sweeps discard the partial table instead
of returning partially promotable rows. That means parallel sweep
execution is a dispatch choice over independent candidate rows, not a
second execution engine.

## Inspect Before Promotion

Name the ranking rule before selecting. Here the rule is deliberately
simple: among completed candidates, sort by Sharpe ratio descending.
ledgr does not own objective functions or automatic candidate ranking;
ordinary R code should make the selection rule visible.

``` r
ranked <- reopened_sweep |>
  filter(status == "DONE") |>
  arrange(desc(sharpe_ratio))

top_n <- ranked |>
  slice_head(n = 5) |>
  select(
    candidate_id, candidate_row, status, final_equity, total_return, sharpe_ratio,
    params, feature_params, execution_seed
  )

glimpse(top_n)
```

    Rows: 5
    Columns: 9
    $ candidate_id   <chr> "feature_9a29b31dae19/strategy_dc6315936028", "feature_9a29b31dae~
    $ candidate_row  <int> 4, 2, 12, 10, 8
    $ status         <chr> "DONE", "DONE", "DONE", "DONE", "DONE"
    $ final_equity   <dbl> 100225.1, 100112.6, 100164.7, 100082.3, 100141.2
    $ total_return   <dbl> 0.0022514428, 0.0011257214, 0.0016467258, 0.0008233629, 0.0014119~
    $ sharpe_ratio   <dbl> 3.075261, 3.074747, 2.123134, 2.122646, 2.053065
    $ params         <list> [10, 0.01], [5, 0.01], [10, 0.01], [5, 0.01], [10, 0.01]
    $ feature_params <list> [5, 20], [5, 20], [5, 40], [5, 40], [10, 20]
    $ execution_seed <int> 576288649, 189084572, 972927993, 1415197276, 319026249

``` r
issues <- reopened_sweep |>
  filter(status != "DONE") |>
  select(any_of(c("candidate_id", "candidate_row", "status", "error_class", "error_msg", "warnings"))) |>
  as_tibble()

issues
```

    # A tibble: 0 x 6
    # i 6 variables: candidate_id <chr>, candidate_row <int>, status <chr>,
    #   error_class <chr>, error_msg <chr>, warnings <list>

Some columns are list columns. `glimpse()` keeps the table readable
while still showing that params, feature params, warnings, and
provenance remain attached to the rows.

<div class="ledgr-callout ledgr-callout-note">

**Design note**

This explicit table code keeps the selection rule visible. A future
sweep-review helper may package this review shape, but it should
preserve the same explicit selection rule instead of making ranking
automatic.

</div>

## Promote One Candidate

Promotion replays one selected candidate as a committed run. This is the
slow path that explicitly pays to materialize durable ledger and equity
artifacts. For the full research loop around promotion notes, reopen,
and human review, read
`vignette("research-workflow", package = "ledgr")`.

``` r
candidate <- ledgr_candidate(ranked, 1)

promoted_run <- ledgr_promote(
  exp,
  candidate,
  run_id = "sweep_selected_candidate",
  note = "Selected highest-Sharpe completed candidate from the exploratory sweep."
)

summary(promoted_run)
```

    ledgr Backtest Summary
    ======================

    Performance Metrics:
      Total Return:        0.23%
      Annualized Return:   0.44%
      Max Drawdown:        -0.07%

    Risk Metrics:
      Risk-Free Rate:      0.00% annual
      Annualization:       252 periods/year (US equity daily)
      Volatility (annual): 0.14%
      Sharpe Ratio:        3.075

    Trade Statistics:
      Total Trades:        3
      Win Rate:            100.00%
      Avg Trade:           $75.05

    Exposure:
      Time in Market:      63.57%

## What A Sweep Does Not Prove

A sweep is exploratory evidence with an audit trail. It does not answer
whether the selected rule will generalize.

The more candidates you try, the more opportunity you create for
sample-specific luck to look like skill. If the question is
generalization rather than artifact reproducibility, use walk-forward
evaluation when that layer lands in v0.1.9.x.

This is the same selection-bias boundary that the v0.1.8.6 cycle
documented when it separated structured benchmark evidence from future
walk-forward validation.

## Failure Rows And Contract Errors

By default, candidate-level failures become rows with
`status = "FAILED"`. Inspect those rows before selecting anything.

This debug example uses no features so the failure is only about
strategy parameters. In ordinary research, the experiment usually
declares features just like the main sweep above.

``` r
debug_strategy <- function(ctx, params) {
  if (params$qty < 0) {
    stop("qty must be non-negative")
  }
  ctx$flat()
}

debug_exp <- ledgr_experiment(
  snapshot = snapshot,
  strategy = debug_strategy,
  features = list(),
  opening = ledgr_opening(cash = 100000),
  cost_model = ledgr_cost_zero()
)

debug_grid <- ledgr_strategy_grid(qty = c(5, -1))

failed_sweep <- ledgr_sweep(debug_exp, debug_grid)

failed_sweep |>
  select(candidate_id, candidate_row, status, error_class, error_msg, params)
```

    # ledgr sweep -- sweep_4334d56264abc036
    # A tibble: 2 x 3
      candidate_id          candidate_row status
      <chr>                         <int> <chr>
    1 strategy_69e7ad01d1e8             1 DONE
    2 strategy_8d5f90d900e7             2 FAILED

    # i 2 combinations: 1 done, 1 failed.
    # i Retention returns: none.
    # i Snapshot hash: 6eeff5ca520c516a61e0228c5ac06d22548c9d74e4e98d1e9f71fccdd2b8a87e.
    # i Cost model hash: 4011132b5979fc370e524ebbc525ac7f4158b4de43639ec985f4c90969b4b9d0.
    # i Metric context hash: 794b69bd7f9c704447d4b0208b8420cdf132ec7bd6582eaa037bf1066133c1bb.
    # i Saved artifact: not saved.
    # i Rows are printed in their current table order; rank or arrange explicitly before selecting candidates.
    # i Hidden columns (3): error_class, error_msg, params

Use the failed row as an interactive debugging handle: inspect
`error_class`, `error_msg`, and `params`, then reproduce the single
candidate in a smaller session before rerunning the sweep. For
pulse-level strategy debugging patterns, read
`vignette("strategy-development", package = "ledgr")`.

Contract errors still abort before a candidate table exists. Invalid
experiment or grid shape is not a failed strategy idea; it is a setup
problem that ledgr stops immediately so the sweep does not mix
incomparable rows.

`ledgr_candidate()` rejects failed rows by default. Use
`ledgr_candidate(results, which, allow_failed = TRUE)` only when you are
extracting a failed row for diagnostics; `ledgr_promote()` still rejects
failed candidates.

## Cost Models Are Fixed Inputs

Cost models are part of the experiment identity in this release. A sweep
varies feature parameters and strategy parameters across the declared
grid; it does not compose cost models as another grid dimension. If you
want to compare different cost assumptions, run separate experiments or
separate sweeps with explicit `cost_model` values and compare the
resulting evidence.

A future `ledgr_cost_grid()` may make cost assumptions participate in
candidate identity deliberately. That API is not part of the v1 cost
surface, so do not expect `ledgr_grid_cross()` to accept cost-model
dimensions.

## Explicit Non-Goals

Sweep mode intentionally leaves some decisions outside the API. It does
not ship:

- automatic ranking, objective functions, or `ledgr_tune()`;
- walk-forward, PBO, or CSCV helpers;
- risk-layer insertion;
- cost-grid composition such as `ledgr_cost_grid()`;
- paper/live trading adapters;
- intraday-specific support;
- full per-candidate committed-run artifacts.

## Where Next

- For the full research loop around sweeps, read
  `vignette("research-workflow", package = "ledgr")`.
- For feature maps, indicator identity, and active aliases, read
  `vignette("indicators", package = "ledgr")`.
- For no-lookahead pulse timing, next-open fills, and final-bar
  warnings, read `vignette("execution-semantics", package = "ledgr")`.
- For durable run comparison after promotion, read
  `vignette("experiment-store", package = "ledgr")`.
