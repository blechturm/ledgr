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

> [!NOTE]
>
> ### Definition
>
> A sweep is an evaluated candidate table over a declared grid. It is
> exploratory: it returns candidate summaries, does not choose a winner,
> and does not write candidate runs to the experiment store.

`ledgr_sweep()` evaluates a grid against a `ledgr_experiment()`. It
tells you what each declared candidate did. It does not decide which
candidate matters.

> [!NOTE]
>
> ### Definition
>
> A sweep usually contains many candidates. Each candidate is one row of
> the sweep: resolved feature parameters, strategy parameters, execution
> seed, status, metrics, warnings or errors, and provenance.

That separation is the workflow boundary:

``` text
ledgr_sweep()                 explore declared candidates
ledgr_candidate()             select one row deliberately
ledgr_promote() / ledgr_run() commit an auditable run
```

> [!WARNING]
>
> ### Selection is not validation
>
> A sweep table records what was run. It does not prove that the
> selected parameters were evaluated on held-out data. Promotion records
> a choice; it does not make that choice out-of-sample.

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
  opening = ledgr_opening(cash = 100000)
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

> [!NOTE]
>
> ### Definition
>
> An active alias is a stable strategy-facing feature name whose
> concrete indicator can vary by candidate. The strategy reads aliases
> such as `fast` and `slow`; ledgr resolves the concrete SMA windows for
> each candidate before execution.

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

> [!NOTE]
>
> ### Definition
>
> Feature parameters materialize indicators before execution. Strategy
> parameters are passed to `strategy(ctx, params)` during execution.
> Keeping those namespaces separate is what lets a strategy read stable
> aliases while the sweep varies indicator windows.

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
    Labels:       feature_403538546350/strategy_26bee9909056, feature_403538546350/strategy_0aa75c3004e3, feature_403538546350/strategy_b2317c0ea414, feature_403538546350/strategy_50fe1adcd9c5, feature_363d9fed8e92/strategy_26bee9909056, feature_363d9fed8e92/strategy_0aa75c3004e3
                  ... 10 more

    Grid labels identify sweep candidates; they are not committed run IDs.

The `.filter` expression is a structural grid constraint. Here it says
the fast moving average must be shorter than the slow moving average.
Filter expressions are evaluated against grid columns; they do not read
run state, feature data, or caller globals.

> [!WARNING]
>
> ### Mind the combinatorial explosion
>
> `ledgr_grid_cross()` multiplies grid dimensions. Four parameters with
> five values each produce 625 candidates before you add another axis.
> Keep early sweeps deliberately small, then expand only after the
> candidate table is readable and the feature payload cost is
> understood.

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

> [!TIP]
>
> ### Try it
>
> Change `slow_n` to `c(20L, 40L, 60L)` and rerun the sweep. The
> strategy code does not change. How many candidates appear after
> `.filter`, and which candidate rows still use the same `fast` and
> `slow` aliases?

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

``` r
sweep <- ledgr_sweep(
  exp,
  grid,
  precomputed_features = precomputed,
  seed = 2026L
)

sweep
```

    # ledgr sweep -- sweep_63168c6bb7e3842e
    # A tibble: 16 x 7
       run_id            status sharpe_ratio total_return max_drawdown n_trades execution_seed
       <chr>             <chr>         <dbl> <chr>        <chr>           <int>          <int>
     1 feature_40353854~ DONE          0.541 +0.0%        -0.1%               6     1052907656
     2 feature_40353854~ DONE          3.07  +0.1%        -0.0%               3      947421329
     3 feature_40353854~ DONE          0.541 +0.0%        -0.1%               6     2134127254
     4 feature_40353854~ DONE          3.08  +0.2%        -0.1%               3     2051697679
     5 feature_363d9fed~ DONE          1.80  +0.1%        -0.0%               5     1310819559
     6 feature_363d9fed~ DONE          2.05  +0.1%        -0.0%               3      646378071
     7 feature_363d9fed~ DONE          1.80  +0.2%        -0.1%               5      659701663
     8 feature_363d9fed~ DONE          2.05  +0.1%        -0.1%               3       87492416
     9 feature_056fef29~ DONE          1.38  +0.1%        -0.0%               3      745595795
    10 feature_056fef29~ DONE          2.12  +0.1%        -0.0%               2      399616899
    11 feature_056fef29~ DONE          1.38  +0.1%        -0.1%               3     2131100969
    12 feature_056fef29~ DONE          2.12  +0.2%        -0.1%               2     2098648481
    13 feature_616262e3~ DONE          1.34  +0.1%        -0.0%               2     1050313246
    14 feature_616262e3~ DONE          1.30  +0.0%        -0.0%               2     1598413647
    15 feature_616262e3~ DONE          1.34  +0.1%        -0.1%               2     1060032084
    16 feature_616262e3~ DONE          1.30  +0.1%        -0.1%               2       36882923

    # i 16 combinations: 16 done, 0 failed.
    # i Rows are printed in their current table order; rank or arrange explicitly before selecting candidates.
    # i Hidden columns (13): final_equity, annualized_return, volatility, win_rate, avg_trade, time_in_market, error_class, error_msg, params, feature_params, warnings, feature_fingerprints, provenance

The table contains candidate summaries. It is not a full artifact store.
Full equity, fills, trades, and ledger rows are created by committed
runs.

## Inspect Before Promotion

Name the ranking rule before selecting. Here the rule is deliberately
simple: among completed candidates, sort by Sharpe ratio descending.
ledgr does not own objective functions or automatic candidate ranking;
ordinary R code should make the selection rule visible.

``` r
ranked <- sweep |>
  filter(status == "DONE") |>
  arrange(desc(sharpe_ratio))

top_n <- ranked |>
  slice_head(n = 5) |>
  select(
    run_id, status, final_equity, total_return, sharpe_ratio,
    params, feature_params, execution_seed
  )

glimpse(top_n)
```

    Rows: 5
    Columns: 8
    $ run_id         <chr> "feature_403538546350/strategy_50fe1adcd9c5", "feature_4035385463~
    $ status         <chr> "DONE", "DONE", "DONE", "DONE", "DONE"
    $ final_equity   <dbl> 100225.1, 100112.6, 100164.7, 100082.3, 100141.2
    $ total_return   <dbl> 0.0022514428, 0.0011257214, 0.0016467258, 0.0008233629, 0.0014119~
    $ sharpe_ratio   <dbl> 3.075261, 3.074747, 2.123134, 2.122646, 2.053065
    $ params         <list> [0.01, 10], [0.01, 5], [0.01, 10], [0.01, 5], [0.01, 10]
    $ feature_params <list> [5, 20], [5, 20], [5, 40], [5, 40], [10, 20]
    $ execution_seed <int> 2051697679, 947421329, 2098648481, 399616899, 87492416

``` r
issues <- sweep |>
  filter(status != "DONE") |>
  select(any_of(c("run_id", "status", "error_class", "error_msg", "warnings"))) |>
  as_tibble()

issues
```

    # A tibble: 0 x 5
    # i 5 variables: run_id <chr>, status <chr>, error_class <chr>, error_msg <chr>,
    #   warnings <list>

Some columns are list columns. `glimpse()` keeps the table readable
while still showing that params, feature params, warnings, and
provenance remain attached to the rows.

> [!NOTE]
>
> ### Design note
>
> This explicit table code keeps the selection rule visible. The
> v0.1.8.6 cycle plans a sweep-review helper that ranks completed
> candidates, returns a compact review table, separates issue rows, and
> preserves the same explicit selection rule.

## Promote One Candidate

Promotion replays one selected candidate as a committed run. For the
full research loop around promotion notes, reopen, and human review,
read `vignette("research-workflow", package = "ledgr")`.

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
  opening = ledgr_opening(cash = 100000)
)

debug_grid <- ledgr_strategy_grid(qty = c(5, -1))

failed_sweep <- ledgr_sweep(debug_exp, debug_grid)

failed_sweep |>
  select(run_id, status, error_class, error_msg, params)
```

    # ledgr sweep -- sweep_48f0f71c00fbbfcf
    # A tibble: 2 x 2
      run_id                status
      <chr>                 <chr>
    1 strategy_f1bc254d9d19 DONE
    2 strategy_88823aa43318 FAILED

    # i 2 combinations: 1 done, 1 failed.
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

## Explicit Non-Goals

Current sweep mode intentionally stays small. It does not currently
ship:

- automatic ranking, objective functions, or `ledgr_tune()`;
- parallel sweep execution;
- walk-forward, PBO, or CSCV helpers;
- risk-layer insertion;
- public cost-model factories;
- paper/live trading adapters;
- intraday-specific support;
- `ledgr_save_sweep()` or full sweep artifact persistence.

## Where Next

- For the full research loop around sweeps, read
  `vignette("research-workflow", package = "ledgr")`.
- For feature maps, indicator identity, and active aliases, read
  `vignette("indicators", package = "ledgr")`.
- For no-lookahead pulse timing, next-open fills, and final-bar
  warnings, read `vignette("execution-semantics", package = "ledgr")`.
- For durable run comparison after promotion, read
  `vignette("experiment-store", package = "ledgr")`.
