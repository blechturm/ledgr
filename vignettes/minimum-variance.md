# A Long-Only Minimum-Variance Strategy


A minimum-variance portfolio asks a precise question: among the
portfolios you permit, which one has the lowest estimated variance? This
article answers that question inside a complete ledgr strategy. You will
read a causal return matrix, check that it contains a usable sample,
estimate and solve the portfolio in ordinary R, and turn the solution
into share targets.

This is the global minimum-variance portfolio: it uses estimated
covariance, not an expected-return forecast. That makes it a useful
first optimization example because the statistical input, constraints
and execution intent stay easy to see.

The complete path is:

``` text
causal returns -> ready sample -> covariance -> long-only weights -> targets
```

Ledgr then applies execution and cost policy, records fills and
accounting events, and stores a reproducible result. The statistical
estimate remains ordinary R code; ledgr owns the causal input and the
economic record.

The quadratic solver comes from `quadprog`; `dplyr` and `tidyr` keep the
shown result tables compact. Install them before running the article
yourself:

``` r
install.packages(c("quadprog", "dplyr", "tidyr"))
```

## Start From A Sealed Snapshot

This article starts where portfolio research normally starts: with a
sealed snapshot prepared by an adapter or a previous data step. Its
hidden setup builds a deterministic, offline snapshot of eight synthetic
equities over three years, including a venue calendar and point-in-time
membership. Open it like any other snapshot:

``` r
library(ledgr)
library(dplyr)
library(tidyr)

snapshot <- ledgr_snapshot_open(snapshot_path)
```

For the preparation workflow, read
`vignette("point-in-time-inputs", package = "ledgr")`. For the exact
meaning of a causal history window, read
`vignette("causal-history", package = "ledgr")`.

> [!NOTE]
>
> ### Demo data
>
> The snapshot is synthetic. One asset deliberately resembles a high-beta
> version of another so the long-only constraint becomes visible. The
> example proves the workflow, not an investment result.


## State The Research Choices

The strategy has four choices. Keeping them in one visible object makes
them part of every run and sweep candidate rather than hidden constants
in the callback.

``` r
strategy_params <- list(
  lookback = 252L,
  min_instruments = 2L,
  covariance_shrinkage = 0.5,
  equity_fraction = 0.95
)
```

- `lookback` is the number of expected venue sessions in the covariance
  window. Because this article does not override `min_observations`,
  ledgr’s finite-lookback default admits an instrument only when all 252
  return observations are finite.
- `min_instruments` is the minimum number of admitted instruments
  required before the strategy estimates a portfolio.
- `covariance_shrinkage` pulls the sample covariance toward its
  diagonal. A value of `0.5` gives equal weight to the sample covariance
  and its diagonal, which makes the estimate positive definite when
  every admitted instrument has positive variance.
- `equity_fraction` sizes at the decision close using 95% of available
  equity. The remaining headroom helps absorb price movement before
  next-open execution; whole-share rounding may leave additional cash.

These are example choices, not recommended universal values. Their
purpose is to make the method auditable.

## Write The Strategy

The strategy decides on the first expected session of each UTC month.
The two-session, zero-instrument read at the top is a temporary
scheduling workaround: it compares the current session with the previous
expected session. The workaround is kept separate so calendar scheduling
does not obscure the portfolio method.

``` r
min_variance <- function(ctx, params) {
  axis <- ctx |>
    ledgr_history_frame(
      bar = "close",
      lookback = 2L,
      instruments = character()
    )
  months <- format(axis$ts_utc, "%Y-%m", tz = "UTC")
  if (length(months) == 2L && months[[1L]] == months[[2L]]) {
    return(ctx$hold())
  }

  returns <- ctx |>
    ledgr_history_matrix(
      feature = "return_1",
      lookback = params$lookback,
      min_instruments = params$min_instruments
    )
  if (!ledgr_passed_warmup(returns)) {
    return(list(
      targets = ctx$hold(),
      intent_reason = "insufficient_sample"
    ))
  }

  sigma <- cov(returns)
  diagonal <- diag(diag(sigma), nrow = nrow(sigma))
  sigma <- (1 - params$covariance_shrinkage) * sigma +
    params$covariance_shrinkage * diagonal
  if (any(!is.finite(sigma)) || any(diag(sigma) <= 0)) {
    return(list(
      targets = ctx$hold(),
      intent_reason = "insufficient_sample"
    ))
  }

  n <- ncol(sigma)
  solution <- quadprog::solve.QP(
    Dmat = sigma,
    dvec = rep(0, n),
    Amat = cbind(rep(1, n), diag(n)),
    bvec = c(1, rep(0, n)),
    meq = 1L
  )$solution
  if (any(!is.finite(solution)) || any(solution < -1e-8) ||
      abs(sum(solution) - 1) > 1e-8) {
    stop("The optimizer returned invalid long-only weights.")
  }
  solution[solution < 0] <- 0
  solution <- solution / sum(solution)

  targets <- solution |>
    ledgr_align_weights(returns) |>
    ledgr_target_rebalance(
      ctx,
      equity_fraction = params$equity_fraction
    )

  # This strategy follows the point-in-time index. A holding that has left
  # the membership universe is therefore assigned a zero target.
  targets[!ctx$vec$member] <- 0

  list(targets = targets, intent_reason = "rebalanced")
}
```

There is one ordinary history read for the estimator. The returned
object is a sessions-by-instruments double matrix, so `cov()` and
`quadprog` consume it directly. `ledgr_align_weights()` restores the
matrix’s instrument identity to the unnamed numerical solution; the
strategy never reconstructs names from matrix columns.

The two intent reasons are deliberately sparse. `insufficient_sample`
means a scheduled decision lacked enough usable data. `rebalanced` means
the strategy submitted a new target. Ordinary non-decision pulses simply
return `ctx$hold()` and write no strategy-intent note. A genuine solver
failure is an error rather than a silent hold.

## Build The Experiment

The experiment registers the daily-return feature, the historical
membership universe and zero transaction costs. Replacing the cost model
changes what the same target intent costs; it does not change the
covariance estimate.

``` r
exp <- ledgr_experiment(
  snapshot,
  min_variance,
  features = list(ledgr_ind_returns(1L)),
  universe = ledgr_universe_members("DEMO_UNIVERSE"),
  cost_model = ledgr_cost_zero()
)
```

Because the strategy calls a package-qualified external solver,
preflight records `quadprog` as a dependency that sweep workers must be
able to load:

``` r
check <- ledgr_strategy_preflight(min_variance)
check$tier
```

    [1] "tier_2"

``` r
check$worker_dependencies$require_namespace
```

    [1] "quadprog"

## Inspect One Decision

`ledgr_pulse_snapshot()` is an inspection tool: it gives you the same
public context the strategy receives at one pulse without running a
backtest. It is useful here for seeing the estimator input and the
resulting target together.

``` r
decision_ctx <- ledgr_pulse_snapshot(
  exp,
  ts_utc = as.Date("2019-11-01"),
  params = strategy_params
)
returns <- decision_ctx |>
  ledgr_history_matrix(
    feature = "return_1",
    lookback = strategy_params$lookback,
    min_instruments = strategy_params$min_instruments
  )
dim(returns)
```

    [1] 252   7

``` r
decision <- min_variance(decision_ctx, strategy_params)
decision$intent_reason
```

    [1] "rebalanced"

``` r
decision$targets[colnames(returns)]
```

    DEMO_02 DEMO_03 DEMO_04 DEMO_05 DEMO_06 DEMO_07 DEMO_08
        213     279     179     241     156     135       0

``` r
close(decision_ctx)
```

The matrix dimensions answer the sample question directly: rows are
expected sessions and columns are admitted instruments. The target is a
full named quantity vector over the decision axis. Ledgr will try to
fill the difference between current and target quantities at the next
eligible open. See `vignette("execution-semantics", package = "ledgr")`
for that timing rule. `DEMO_08` has a zero target: its deliberately
redundant return stream makes the long-only constraint bind rather than
permitting a negative weight.

## Run And Read The Result

``` r
bt <- exp |>
  ledgr_run(
    params = strategy_params,
    run_id = "minimum-variance"
  )

fill_days <- ledgr_results(bt, "fills") |>
  distinct(fill_day = as.Date(ts_utc))
nrow(fill_days)
```

    [1] 24

``` r
slice_head(fill_days, n = 4L)
```

    # A tibble: 4 x 1
      fill_day
      <date>
    1 2019-01-02
    2 2019-02-04
    3 2019-03-04
    4 2019-04-02

``` r
bt
```

    ledgr Backtest Results
    ======================

    Run ID:                            minimum-variance
    Period:                            2018-01-01T16:00:00Z to 2020-12-31T16:00:00Z
    Opening Cash:                      $100000.00
    Final Equity:                      $109185.86
    Total Return:                      9.19%
    Max Drawdown:                      -6.68%
    Closed Trades:                     68

    Corporate actions: NONE - supplied facts did not affect held instruments
    Price basis: split_adjusted (declared)
    Valuation: CURRENT - every held mark was a current close
    Point in time: membership rule 'DEMO_UNIVERSE'; valuation stale-mark horizon 5 sessions (default)
    History policy: price carry 5 sessions (default); output carry off (default); segment limit 4 per fact, at least 16 (default)

    Use summary(bt) for metrics and evidence

The first year supplies the 252-session sample, so the strategy records
`insufficient_sample` on early monthly decisions and begins trading once
the panel is ready. Each fill occurs on the session after its decision
because the experiment uses ledgr’s next-open execution convention.

The result also reports costs, corporate-action fidelity, valuation
status, returns and drawdown. Those are ledger outputs, not values
recomputed by the strategy.

## Why The Optimization Has This Shape

The objective is `minimize w' Sigma w`, subject to `sum(w) = 1` and
`w_i >= 0` for every instrument.

The first constraint invests the allocated capital. The second makes the
portfolio long-only. They appear in `solve.QP()` as one equality column
and one non-negativity column per instrument.

The diagonal shrinkage is part of the estimator, not a ledgr
requirement. It stabilizes a covariance matrix when the number of
instruments is large relative to the window. This article uses a fixed
shrinkage value so the portfolio workflow stays visible; production
research should choose and validate that value out of sample.

## Sweep One Research Choice

An ordinary data frame gives one candidate per row. Here only the
shrinkage strength changes; the other choices remain visible rather than
being merged from hidden defaults.

``` r
grid <- data.frame(
  lookback = rep(252L, 3L),
  min_instruments = rep(2L, 3L),
  covariance_shrinkage = c(0.25, 0.50, 0.75),
  equity_fraction = rep(0.95, 3L)
)

sweep <- ledgr_sweep(exp, grid, seed = 1L)
sweep |>
  as_tibble() |>
  unnest_wider(params) |>
  select(
    candidate_id,
    covariance_shrinkage,
    status,
    sharpe_ratio,
    total_return,
    max_drawdown
  )
```

    # A tibble: 3 x 6
      candidate_id          covariance_shrinkage status sharpe_ratio total_return max_drawdown
      <chr>                                <dbl> <chr>         <dbl>        <dbl>        <dbl>
    1 strategy_201b4ccf363e                 0.25 DONE          0.490       0.0889      -0.0656
    2 strategy_4780d458cba0                 0.5  DONE          0.505       0.0919      -0.0668
    3 strategy_ec81a806cec4                 0.75 DONE          0.520       0.0946      -0.0679

The compact view puts the changed shrinkage value beside each candidate
ID and its main outcomes. This is exploration, not validation: choosing
a shrinkage value from the same period used to report it would overstate
the evidence. For held-out evaluation, continue with
`vignette("walk-forward", package = "ledgr")`.

> [!TIP]
>
> ### Try it
>
> Which shrinkage value has the highest in-sample Sharpe ratio in the
> compact table? Replace the three `lookback` values with `126L` and rerun
> the sweep. Does the ranking change, and why would neither ranking by
> itself validate the choice?


## What This Article Deliberately Leaves Elsewhere

This strategy excludes an instrument until its return window is complete
and assigns zero to an eligible instrument omitted from the allocation.
More advanced choices—keeping an omitted holding, turnover-aware
optimization, no-trade bands and richer allocation diagnostics—are
deliberately outside this introductory method.

Carried observations and missing-session evidence are taught in
`vignette("causal-history", package = "ledgr")`. Liquidity and capacity
are a different question again: whether an intended quantity could
realistically trade. They belong to execution policy, not to this
covariance example; see `vignette("risk-and-cost", package = "ledgr")`
for that boundary.

## Where Next

- Next in the Going Deeper sequence, use maintained external indicators
  in `vignette("ttr-indicators", package = "ledgr")`.
- For the causal and missingness rules behind the matrix, return to
  `vignette("causal-history", package = "ledgr")`.
- For membership changes and departed holdings, read
  `vignette("survivorship-bias", package = "ledgr")`.
- For selection and held-out evaluation, read
  `vignette("walk-forward", package = "ledgr")`.
