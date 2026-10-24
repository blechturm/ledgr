# A Long-Only Minimum-Variance Strategy


A minimum-variance portfolio puts its money where the estimated risk is
lowest. This article builds one such strategy from the history tools of
`vignette("causal-history", package = "ledgr")`: it estimates a
covariance matrix from daily returns once a month, solves for the
long-only weights with the smallest estimated variance, and turns them
into share targets. Every step uses ledgr’s public functions, so the
same strategy runs in a single backtest, a sweep and on parallel
workers.

Three choices that an estimator usually hides are made explicit here:
which instruments enter the estimate, what happens to a holding the
estimate leaves out, and what the strategy does on a day it cannot
estimate at all.

The solver comes from the `quadprog` package. The code chunks that run
the strategy are evaluated only when it is installed:

``` r
install.packages("quadprog")
```

## The Demo Data

The demo is three years of simulated sessions for eight instruments from
`ledgr_sim_pit_inputs()`, with two changes to its bars, so that the
screens below have something to screen:

- `DEMO_05` trades thinly from June to November 2019: it has no print on
  every second session, so ledgr carries its previous close forward on
  those sessions.
- `DEMO_08` is listed late: its first print is on 3 September 2019.

``` r
library(ledgr)

ids <- sprintf("DEMO_%02d", 1:8)
pit <- ledgr_sim_pit_inputs(ids, from = "2018-01-01", to = "2020-12-31", seed = 7L)
bars <- pit$bars
day <- as.Date(bars$ts_utc)
thin <- sort(unique(day[day >= as.Date("2019-06-01") & day <= as.Date("2019-11-30")]))
skipped <- thin[seq(2L, length(thin), by = 2L)]
bars <- bars[!(bars$instrument_id == "DEMO_05" & day %in% skipped), ]
day <- as.Date(bars$ts_utc)
bars <- bars[!(bars$instrument_id == "DEMO_08" & day < as.Date("2019-09-03")), ]

facts <- ledgr_facts(
  ledgr_facts_sessions(pit$sessions, venue_id = "DEMO_VENUE",
                       knowledge = "evidenced", timezone = "UTC"),
  ledgr_facts_membership_snapshots(pit$membership, universe_id = "DEMO_UNIVERSE",
                                   complete = TRUE, knowledge = "evidenced"),
  ledgr_facts_trading_status(pit$trading_status, knowledge = "evidenced"),
  ledgr_facts_lifetime(pit$lifetime, knowledge = "evidenced"),
  ledgr_facts_equity_corporate_actions(pit$corporate_actions)
)
snapshot_path <- file.path(tempdir(), "minimum-variance-demo.duckdb")
if (file.exists(snapshot_path)) unlink(snapshot_path)
snapshot <- ledgr_snapshot_from_df(
  bars, instruments_df = pit$instruments, facts = facts,
  db_path = snapshot_path, snapshot_id = "minimum_variance_demo",
  price_basis = "split_adjusted"
)
pit$cases
```

                     type instrument_id       date
    1       venue_closure          <NA> 2018-01-04
    2 missing_observation       DEMO_04 2018-01-09
    3           delisting       DEMO_01 2018-01-12
    4                halt       DEMO_02 2018-01-03
    5       cash_dividend       DEMO_03 2018-01-10

The simulated inputs also hold the teaching cases of
`vignette("point-in-time-inputs", package = "ledgr")`. All of them fall
in the first two weeks of 2018. One of them is a cash dividend on
`DEMO_03` on 10 January 2018. The strategy holds nothing until its first
decision a year later, so no dividend is posted in this demo; the run
below says so. The bars are split-adjusted and exclude distributions, so
the strategy estimates risk from price returns.

## The Strategy

The whole strategy is one function. Everything it needs is defined
inside it, because preflight refuses a strategy that calls a helper from
the calling session.

``` r
min_variance <- function(ctx, params) {
  hold <- function(reason) {
    list(targets = ctx$hold(), intent_reason = reason)
  }

  # 1. Decide only on a month's first session: the session whose UTC month
  #    differs from that of the previous expected venue session. The data
  #    start has no previous session and counts as a month start.
  axis <- ctx |>
    ledgr_history_frame(bar = "close", lookback = 2L, instruments = character())
  months <- format(axis$ts_utc, "%Y-%m", tz = "UTC")
  if (length(months) == 2L && months[[1L]] == months[[2L]]) {
    return(hold("not_a_decision_date"))
  }

  # 2. Read closes over the window and screen out instruments whose window
  #    holds too many carried prices.
  closes <- ctx |>
    ledgr_history_frame(bar = "close", lookback = params$lookback,
                        min_instruments = 1L)
  if (!ledgr_passed_warmup(closes)) {
    return(hold("insufficient_history"))
  }
  selection <- ledgr_history_info(closes)$selection
  selection <- selection[selection$requested, , drop = FALSE]
  candidates <- selection$instrument_id[
    selection$carried_input_share <= params$carry_threshold
  ]

  # 3. Read one ordinary matrix of daily returns. The read itself excludes
  #    instruments with too few usable returns and records whether enough
  #    instruments remain for the estimator.
  returns <- ctx |>
    ledgr_history_matrix(
      feature = "return_1",
      lookback = params$lookback,
      instruments = candidates,
      min_observations = params$min_observations,
      min_instruments = params$min_instruments
    )
  if (!ledgr_passed_warmup(returns)) {
    reason <- if (ledgr_history_info(returns)$available_lookback < params$lookback) {
      "insufficient_history"
    } else {
      "too_few_instruments"
    }
    return(hold(reason))
  }

  # 4. Estimate a pairwise covariance and shrink it toward its diagonal. A
  #    pairwise estimate need not be positive definite, so floor its
  #    eigenvalues at eigenvalue_floor times the largest one. Hold only when no
  #    repair is possible: a pair without common valid returns, or no
  #    positive variance at all.
  sigma <- stats::cov(returns, use = "pairwise.complete.obs")
  sigma <- (1 - params$covariance_shrinkage) * sigma +
    params$covariance_shrinkage * diag(diag(sigma))
  if (anyNA(sigma)) {
    return(hold("covariance_not_positive_definite"))
  }
  values <- eigen(sigma, symmetric = TRUE, only.values = TRUE)$values
  largest <- max(values)
  if (!(largest > 0)) {
    return(hold("covariance_not_positive_definite"))
  }
  if (min(values) < params$eigenvalue_floor * largest) {
    decomposition <- eigen(sigma, symmetric = TRUE)
    floored <- decomposition$values
    floored[floored < params$eigenvalue_floor * largest] <-
      params$eigenvalue_floor * largest
    sigma <- decomposition$vectors %*% (floored * t(decomposition$vectors))
    sigma <- (sigma + t(sigma)) / 2
  }

  # 5. Solve: minimise w' sigma w subject to sum(w) = 1 and w >= 0.
  n <- ncol(sigma)
  solution <- tryCatch(
    quadprog::solve.QP(Dmat = sigma, dvec = rep(0, n),
                       Amat = cbind(rep(1, n), diag(n)),
                       bvec = c(1, rep(0, n)), meq = 1L)$solution,
    error = function(e) NULL
  )
  if (is.null(solution) || any(!is.finite(solution)) ||
      any(solution < -1e-8) || abs(sum(solution) - 1) > 1e-8) {
    return(hold("solver_failure"))
  }
  solution[solution < 0] <- 0
  solution <- solution / sum(solution)

  # 6. Keep every holding the estimate left out, and target the rest.
  held <- ctx$universe[ctx$vec$position != 0]
  estimated <- ledgr_history_info(returns)$included_ids
  held_excluded <- if (isTRUE(params$keep_excluded)) {
    setdiff(held, estimated)
  } else {
    character()
  }
  target <- tryCatch(
    solution |>
      ledgr_align_weights(returns) |>
      ledgr_target_rebalance(
        ctx,
        equity_fraction = params$equity_fraction,
        keep = held_excluded
      ),
    ledgr_target_sizing_unavailable = function(e) NULL
  )
  if (is.null(target)) {
    return(hold("no_permissible_mark"))
  }

  # 7. Sell index leavers: holdings that are no longer members of the
  #    universe. The rebalance preserves them, so target them to zero.
  leavers <- ctx$universe[ctx$vec$position != 0 & !ctx$vec$member]
  target[leavers] <- 0
  list(targets = target, intent_reason = "solved")
}
```

The callback has no hidden defaults. This visible object is the strategy
configuration used below and is stored with every run:

``` r
strategy_params <- list(
  lookback = 252L,
  min_observations = 60L,
  min_instruments = 2L,
  carry_threshold = 0.2,
  covariance_shrinkage = 0.5,
  eigenvalue_floor = 1e-6,
  equity_fraction = 0.95,
  keep_excluded = TRUE
)
```

Each parameter makes one research choice explicit:

- `lookback = 252`: the estimation window, in expected venue sessions.
  It is finite, so each decision reads the same amount of history
  however long the run is.
- `carry_threshold = 0.2`: the largest share of carried closes an
  instrument may have in its window and still be estimated.
- `covariance_shrinkage = 0.5`: how far the covariance is pulled toward
  its diagonal, a fixed number in (0, 1\]. Without it, a window with
  fewer sessions than instruments gives a singular covariance. Half way
  is a strong pull; it keeps the estimate usable when instruments
  outnumber sessions.
- `min_observations = 60`: the fewest valid daily returns an instrument
  needs, about a quarter of the default window.
- `min_instruments = 2`: the fewest admitted instruments needed before
  the optimizer is called. It changes readiness, not which columns are
  admitted.
- `eigenvalue_floor = 1e-6`: the smallest eigenvalue the covariance may
  keep, as a fraction of its largest. Each pair’s covariance is
  estimated from the sessions both instruments have, so instruments with
  short or different histories, such as recent index entrants, can give
  a matrix that is not positive definite even after shrinkage. Raising
  its eigenvalues to the floor is the standard nearest positive definite
  repair; an estimate whose eigenvalues are all above the floor is left
  unchanged.
- `keep_excluded = TRUE`: keep holdings the estimate left out. It exists
  so that this article can show what happens without it.
- `equity_fraction = 0.95`: invest 95% of the capital left after
  preserved holdings, leaving a small cash buffer.

The callback returns targets plus an optional `intent_reason`. ledgr
records that reason once for the decision pulse, so `solved`,
`insufficient_history` and the other outcomes remain available after the
run is reopened. This is decision evidence, not a general factor or
prediction store; that broader surface remains tracked as `LFB-028`.

## One Decision, Step By Step

`ledgr_pulse_snapshot()` builds the context a run would hand to the
strategy on one session. On 1 November 2019, the first session of the
month, the close read shows how much of each window was carried:

``` r
exp <- ledgr_experiment(
  snapshot, min_variance,
  features = list(ledgr_ind_returns(1L)),
  universe = ledgr_universe_members("DEMO_UNIVERSE"),
  cost_model = ledgr_cost_zero()
)
november <- ledgr_pulse_snapshot(
  exp,
  ts_utc = as.Date("2019-11-01"),
  params = strategy_params
)
closes <- november |> ledgr_history_frame(bar = "close", lookback = 252L)
ledgr_history_info(closes)$selection[, c("instrument_id", "requested",
                                         "carried_input_count", "carried_input_share")]
```

    # A tibble: 8 x 4
      instrument_id requested carried_input_count carried_input_share
      <chr>         <lgl>                   <int>               <dbl>
    1 DEMO_02       TRUE                        0               0
    2 DEMO_03       TRUE                        0               0
    3 DEMO_04       TRUE                        0               0
    4 DEMO_05       TRUE                       55               0.218
    5 DEMO_06       TRUE                        0               0
    6 DEMO_07       TRUE                        0               0
    7 DEMO_08       TRUE                        0               0
    8 DEMO_01       FALSE                      NA              NA

`DEMO_01` was delisted in January 2018, so it is not requested.
`DEMO_05`’s thin trading has carried 55 of its 252 closes, a share of
0.218, above the threshold of 0.2: the strategy leaves it out. Return
features never use a carried close, so its return cells on those
sessions are missing rather than zero.

The return read of the remaining instruments shows how many valid daily
returns each has:

``` r
selection <- ledgr_history_info(closes)$selection
candidates <- selection$instrument_id[selection$requested &
                                        selection$carried_input_share <= 0.2]
returns <- november |>
  ledgr_history_matrix(
    feature = "return_1",
    lookback = strategy_params$lookback,
    instruments = candidates,
    min_observations = strategy_params$min_observations,
    min_instruments = strategy_params$min_instruments
  )
return_selection <- ledgr_history_info(returns)$selection
return_selection[, c("instrument_id", "finite_observation_count", "included")]
```

    # A tibble: 8 x 3
      instrument_id finite_observation_count included
      <chr>                            <int> <lgl>
    1 DEMO_02                            252 TRUE
    2 DEMO_03                            252 TRUE
    3 DEMO_04                            252 TRUE
    4 DEMO_06                            252 TRUE
    5 DEMO_07                            252 TRUE
    6 DEMO_08                             43 FALSE
    7 DEMO_01                             NA FALSE
    8 DEMO_05                             NA FALSE

`DEMO_08` has traded for two months, so it has fewer than 60 valid
returns and is left out too. The five instruments that remain are
estimated, and the solver’s output becomes share targets:

``` r
decision <- min_variance(november, strategy_params)
decision$intent_reason
```

    [1] "solved"

``` r
decision$targets
```

    <ledgr_target> [8 assets]
    origin: ledgr_align_weights
    non-NA: 8/8
    DEMO_01 DEMO_02 DEMO_03 DEMO_04 DEMO_05 DEMO_06
          0     263     341     222       0     189

`ledgr_align_weights()` names the solver’s unnamed output by the
instruments included by the identified return matrix, in matrix-column
order, and refuses a vector of the wrong length. No `colnames()` bridge
is needed: the matrix carries that identity from the causal read through
the estimator.

## Decision Dates

The strategy currently decides on the first session of each month and
returns `ctx$hold()` on every other session. This predicate is a
workaround until the parked scheduler RFC provides orchestration outside
the callback; it is not a general scheduling helper or guarantee. It
finds the first session from a two-session history read with no
instruments: if the current session and the previous expected session
fall in the same month, this is not a decision date. The very first
session of the data has no previous session, so it counts as a month
start. Months are taken in UTC. That is right for this venue, whose
sessions close at 16:00 UTC on the venue’s own civil date; for a venue
whose close falls after midnight UTC, the UTC month would differ from
the venue’s month.

Before a full window of 252 sessions exists, the strategy holds as well:

``` r
outcome_on <- function(date, params = list()) {
  params <- utils::modifyList(strategy_params, params)
  ctx <- ledgr_pulse_snapshot(exp, ts_utc = as.Date(date), params = params)
  on.exit(close(ctx))
  min_variance(ctx, params)$intent_reason
}
outcome_on("2019-11-12")
```

    [1] "not_a_decision_date"

``` r
outcome_on("2018-06-01")
```

    [1] "insufficient_history"

## Run It

Preflight classifies the strategy as Tier 2, because it calls a package
outside base R. It records `quadprog` as a namespace that parallel
workers must load.

``` r
check <- ledgr_strategy_preflight(min_variance)
check$tier
```

    [1] "tier_2"

``` r
check$worker_dependencies$require_namespace
```

    [1] "quadprog"

``` r
bt <- exp |>
  ledgr_run(params = strategy_params, run_id = "minimum-variance")
fills <- as.data.frame(ledgr_results(bt, "fills"))
fill_days <- unique(as.Date(fills$ts_utc))
length(fill_days)
```

    [1] 24

``` r
head(fill_days, 4)
```

    [1] "2019-01-02" "2019-02-04" "2019-03-04" "2019-04-02"

``` r
bt
```

    ledgr Backtest Results
    ======================

    Run ID:                            minimum-variance
    Period:                            2018-01-01T16:00:00Z to 2020-12-31T16:00:00Z
    Opening Cash:                      $100000.00
    Final Equity:                      $111480.50
    Total Return:                      11.48%
    Max Drawdown:                      -6.29%
    Closed Trades:                     65

    Corporate actions: NONE - supplied facts did not affect held instruments
    Price basis: split_adjusted (declared)
    Valuation: STALE - 1 holding valued at a permitted stale close (longest age 1 session)
    Point in time: membership rule 'DEMO_UNIVERSE'; valuation stale-mark horizon 5 sessions (default)
    History policy: price carry 5 sessions (default); output carry off (default); segment limit 4 per fact, at least 16 (default)

    Use summary(bt) for metrics and evidence

The run has 36 month starts. The first twelve hold for want of a full
window, and the strategy trades after each of the other 24: the fills
fall on the session after each decision, at the next open. The summary
line on corporate actions confirms that the demo’s only dividend
affected no holding. The valuation line reads STALE because `DEMO_05`
was held through its thin stretch: on every second session it was valued
at its previous close, which the default valuation policy permits for up
to five sessions.

## Holdings The Estimate Leaves Out

Three decisions are deliberately separate:

- **Estimation exclusion:** the history read leaves a column out because
  it fails `min_observations`, or the strategy’s carry screen does not
  request it.
- **Allocation output:** the solver returns weights only for the
  instruments it estimated.
- **Execution intent:** the strategy must still say whether an omitted
  holding is kept or liquidated.

Leaving an instrument out of the estimate should not sell anything by
itself. But `ledgr_target_rebalance()` targets every eligible instrument
without a weight to zero, so a holding the estimate left out would be
sold at the next open. The strategy therefore passes every holding
outside the estimate in `keep`, and the rebalance keeps its quantity and
sizes the rest around it.

`DEMO_05` is held when its carried share crosses the threshold in
November 2019. Its share stays above 0.2 until the thin stretch leaves
the window in July 2020:

``` r
share_on <- function(date) {
  ctx <- ledgr_pulse_snapshot(exp, ts_utc = as.Date(date), params = strategy_params)
  on.exit(close(ctx))
  selection <- ledgr_history_info(
    ctx |> ledgr_history_frame(bar = "close", lookback = 252L)
  )$selection
  selection$carried_input_share[selection$instrument_id == "DEMO_05"]
}
dates <- c("2019-10-01", "2019-11-01", "2020-06-01", "2020-07-01")
data.frame(date = dates, demo_05_share = round(vapply(dates, share_on, numeric(1)), 3))
```

                     date demo_05_share
    2019-10-01 2019-10-01         0.171
    2019-11-01 2019-11-01         0.218
    2020-06-01 2020-06-01         0.242
    2020-07-01 2020-07-01         0.198

Run once with `keep` and once without, and compare the `DEMO_05` fills
from October 2019 to July 2020:

``` r
without_keep <- exp |>
  ledgr_run(
    params = utils::modifyList(strategy_params, list(keep_excluded = FALSE)),
    run_id = "minimum-variance-no-keep"
  )
demo_05_fills <- function(bt) {
  fills <- as.data.frame(ledgr_results(bt, "fills"))
  fills[fills$instrument_id == "DEMO_05" &
          fills$ts_utc > as.POSIXct("2019-10-01", tz = "UTC") &
          fills$ts_utc < as.POSIXct("2020-07-31", tz = "UTC"),
        c("ts_utc", "side", "qty")]
}
demo_05_fills(bt)
```

                     ts_utc side qty
    104 2020-07-02 09:30:00 SELL  38

``` r
demo_05_fills(without_keep)
```

                     ts_utc side qty
    57  2019-11-04 09:30:00 SELL 223
    105 2020-07-02 09:30:00  BUY 189

With `keep`, the position is not traded while `DEMO_05` is outside the
estimate; it is rebalanced again once the estimate includes it in July
2020. Without `keep`, the rebalance sells the whole position at the open
after the November decision and buys it back in July.

Index leavers are the opposite case. When an instrument leaves the
universe, `ledgr_target_rebalance()` preserves the holding: it is not a
member, so the helper neither weights nor sells it, and it would stay in
the book indefinitely. The strategy therefore targets every held
non-member to zero after the rebalance. Both choices are deliberate: an
instrument the estimate left out is kept, because leaving it out is an
estimation choice; an instrument the index dropped is sold, because the
strategy holds index members. The demo’s universe never changes, so this
run has no leaver. The sale happens on decisions that solve: on a
decision that holds, a leaver stays until the next one, and so does one
halted at the decision. One cost remains: the rebalance reserved the
leaver’s value before sizing the others, so the cash from the sale stays
idle until the next decision.

## When The Strategy Holds

On a decision date the strategy returns `ctx$hold()` instead of a target
when it cannot estimate. Each case has its own durable intent reason:

- `not_a_decision_date` and `insufficient_history`, shown above.
- `too_few_instruments`: fewer than the required number of instruments
  pass the screens. Here the requirement is deliberately larger than the
  demo universe:

``` r
outcome_on("2019-11-01", list(min_instruments = 9L))
```

    [1] "too_few_instruments"

- `covariance_not_positive_definite`: the covariance cannot be repaired,
  because two estimated instruments share no valid return in the window
  (a missing entry) or no instrument has a positive variance. A
  covariance that is merely singular or indefinite is repaired by the
  eigenvalue floor instead. With five sessions for six instruments the
  sample covariance is singular, and a negligible shrinkage leaves it
  so, yet the strategy still solves:

``` r
outcome_on(
  "2019-11-01",
  list(lookback = 5L, min_observations = 2L, covariance_shrinkage = 1e-12)
)
```

    [1] "solved"

- `solver_failure`: `solve.QP()` raises an error or returns a solution
  that does not sum to one or has a weight below zero beyond rounding.
  With the repaired covariance and these constraints this should not
  happen, but the strategy holds rather than trade on a broken solution.
- `no_permissible_mark`: `ledgr_target_rebalance()` refuses with
  `ledgr_target_sizing_unavailable` when it must value a holding, kept
  or weighted, that has no permissible mark. The strategy catches
  exactly that class and holds.

In a run, ledgr does not let it come to that. Before the strategy is
called, every holding must have a permissible mark, a current or recent
close, or a frozen one under the default valuation policy. A run that
starts from a book holding `DEMO_08` before its first print stops at the
first session:

``` r
book <- ledgr_experiment(
  snapshot, min_variance,
  features = list(ledgr_ind_returns(1L)),
  opening = ledgr_opening(cash = 100000, positions = c(DEMO_08 = 100),
                          cost_basis = c(DEMO_08 = 50)),
  universe = ledgr_universe_members("DEMO_UNIVERSE"),
  cost_model = ledgr_cost_zero()
)
unpriced <- book |>
  ledgr_run(params = strategy_params, run_id = "minimum-variance-unpriced")
completion <- ledgr_run_completion(unpriced)
completion$completion_status
```

    [1] "INCOMPLETE"

``` r
completion$stop_reason
```

    [1] "valuation_horizon_exhausted"

The run is `INCOMPLETE` with `valuation_horizon_exhausted`: the holding
could not be valued, and the strategy was never asked to decide.

## Sweep The Window And The Threshold

The strategy reads its parameters from `params`, so the window and the
carry threshold are ordinary sweep parameters. Preflight told the
workers to load `quadprog`:

``` r
grid <- data.frame(
  lookback = rep(c(126L, 252L), each = 2L),
  min_observations = rep(60L, 4L),
  min_instruments = rep(2L, 4L),
  carry_threshold = rep(c(0.1, 0.2), 2L),
  covariance_shrinkage = rep(0.5, 4L),
  eigenvalue_floor = rep(1e-6, 4L),
  equity_fraction = rep(0.95, 4L),
  keep_excluded = rep(TRUE, 4L)
)
sweep <- ledgr_sweep(exp, grid, workers = 2L, seed = 1L)
sweep
```

    # ledgr sweep -- sweep_de1e2f4cdb234c4d
    # A tibble: 4 x 10
      strategy_params            feature_params candidate_id candidate_row status sharpe_ratio
      <chr>                      <chr>          <chr>                <int> <chr>         <dbl>
    1 <truncated; use ledgr_can~ {}             strategy_31~             1 DONE          0.596
    2 <truncated; use ledgr_can~ {}             strategy_1c~             2 DONE          0.596
    3 <truncated; use ledgr_can~ {}             strategy_a4~             3 DONE          0.632
    4 <truncated; use ledgr_can~ {}             strategy_c8~             4 DONE          0.634
    # i 4 more variables: total_return <chr>, max_drawdown <chr>, n_trades <int>,
    #   execution_seed <int>

    # i 4 candidates attempted: 4 done, 0 incomplete, 0 failed.
    # i Retention returns: none.
    # i Retention trades: none.
    # i Snapshot hash: 46496decff05d89987617a0968c2ceeb9c34018e4fb5b063f3a290dcd33045f5.
    # i Cost model hash: 4011132b5979fc370e524ebbc525ac7f4158b4de43639ec985f4c90969b4b9d0.
    # i Metric context hash: 794b69bd7f9c704447d4b0208b8420cdf132ec7bd6582eaa037bf1066133c1bb.
    # i Saved artifact: not saved.
    # i Rows are printed in their current table order; rank or arrange explicitly before selecting candidates.
    # i Hidden columns (24): completion_json, stop_reason, affected_instrument_ids, valuation_state, frozen_instrument_sessions, max_frozen_equity_weight, frozen_at_end_value, assumed_terminal_outcomes, final_equity, annualized_return, volatility, win_rate, avg_trade, time_in_market, error_class, error_msg, params, warnings, feature_fingerprints, risk_chain_hash, provenance, t_engine, t_results, t_fills_extract

## Where Next

- `vignette("ttr-indicators", package = "ledgr")` declares TTR
  indicators such as RSI, Bollinger bands and MACD.
- `vignette("causal-history", package = "ledgr")` explains every history
  read used here.
- `vignette("sweeps", package = "ledgr")` covers candidate selection and
  promotion after a sweep.
