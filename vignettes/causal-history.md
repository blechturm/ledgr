# Reading Causal History


A strategy sees one pulse at a time, but most estimators need a window
of past values: a covariance matrix, a trailing volatility, a momentum
score. `ledgr_history_frame()` returns that window from inside the
strategy, already aligned to the venue’s sessions and cut off at the
pulse. Every value in it was observed at or before the pulse, and every
fact behind it was knowable then.

This article starts from a snapshot that already exists, runs it once,
and then reads history the way a strategy would: defaults first, then
the explicit choices, then the evidence that explains each cell. It ends
with one portfolio estimate that goes from history to targets without
rebuilding any timestamp or instrument name by hand.

## Open A Snapshot And Run It

Someone has already sealed a point-in-time snapshot of eight synthetic
instruments over 2020 into the DuckDB file named by `snapshot_path`.
Opening it, declaring an experiment and running it takes three calls.

``` r
library(ledgr)

snapshot <- ledgr_snapshot_open(snapshot_path)

momentum <- function(ctx, params) {
  ctx |>
    ledgr_signal_return(params$lookback) |>
    ledgr_select_top_n(params$n, partial = "allow") |>
    ledgr_weight_equal() |>
    ledgr_target_rebalance(ctx, equity_fraction = 0.95)
}

exp <- ledgr_experiment(
  snapshot,
  momentum,
  features = list(ledgr_ind_returns(20L)),
  universe = ledgr_universe_members("DEMO_UNIVERSE"),
  cost_model = ledgr_cost_zero()
)

bt <- exp |> ledgr_run(params = list(lookback = 20L, n = 3L), run_id = "hello-history")
bt
```

    ledgr Backtest Results
    ======================

    Run ID:                            hello-history
    Period:                            2020-01-01T16:00:00Z to 2020-12-31T16:00:00Z
    Opening Cash:                      $100000.00
    Final Equity:                      $107536.73
    Total Return:                      7.54%
    Max Drawdown:                      -6.50%
    Closed Trades:                     369

    Corporate actions: NONE - supplied facts did not affect held instruments
    Price basis: split_adjusted (declared)
    Valuation: CURRENT - every held mark was a current close
    Point in time: membership rule 'DEMO_UNIVERSE'; valuation stale-mark horizon 5 sessions (default)
    History policy: price carry 5 sessions (default); output carry off (default); segment limit 4 per fact, at least 16 (default)

    Use summary(bt) for metrics and evidence

The snapshot already declares a venue calendar, a changing universe,
trading halts, a delisting and a dividend, so the experiment reads them
without further declarations. The inputs it was built from are in `pit`;
`pit$cases` lists where each of those teaching cases sits. The rest of
this article looks inside single decisions of experiments like this one.

## Read History From Inside A Strategy

`ledgr_pulse_snapshot()` builds the context a run would hand to its
strategy at one session, without running anything. That makes it the
easiest place to try a history read.

``` r
ctx <- ledgr_pulse_snapshot(exp, ts_utc = as.Date("2020-06-30"),
                            params = list(lookback = 20L, n = 3L))
closes <- ctx |> ledgr_history_frame(bar = "close")
closes
```

    ledgr_history
    Source:    bar:close
    Cutoff:    2020-06-30T16:00:00Z
    Sessions:  129 of requested Inf
    Included:  7 of 7 requested
    Layout:    wide
                    ts_utc  DEMO_02  DEMO_03  DEMO_04  DEMO_05  DEMO_06  DEMO_07  DEMO_08
    1  2020-01-01 16:00:00 54.35278 61.92477 67.91859 75.69739 82.71295 88.72165 97.44337
    2  2020-01-02 16:00:00 53.82880 61.98869 68.00197 76.40134 83.47645 87.10980 96.00984
    3  2020-01-03 16:00:00 52.84110 61.55028 68.15578 76.10772 84.03599 86.22051 96.02343
    4  2020-01-07 16:00:00 52.84110 61.11773 68.54419 75.70023 84.58441 85.97055 98.32701
    5  2020-01-08 16:00:00 51.70957 60.81023 68.57806 75.82866 83.94279 86.20651 97.45505
    6  2020-01-09 16:00:00 51.91068 60.78340 68.57806 74.84628 83.56187 86.18592 97.38834
    7  2020-01-10 16:00:00 52.10159 61.05278 70.08739 74.93042 82.97788 87.07357 95.54874
    8  2020-01-13 16:00:00 51.78570 61.18984 69.76760 74.85918 82.48346 87.01355 94.79809
    9  2020-01-14 16:00:00 51.55428 61.81879 70.89406 74.36089 81.23445 87.14538 92.41565
    10 2020-01-15 16:00:00 52.05666 62.07643 71.14075 75.25940 80.95590 87.60192 92.78829
    # i Selection, exclusions and window: ledgr_history_info(x)

The defaults are the ones most estimators want:

- `lookback = Inf` returns every expected venue session from the start
  of the data up to the pulse. A finite `lookback` returns the last
  sessions of that same history, so a shorter read is never computed
  differently.
- `instruments = "admissible"` returns the instruments the strategy may
  target at this pulse.
- `na_action = "keep"` keeps every requested instrument, missing values
  and all.
- `layout = "wide"` returns one row per session, `ts_utc` first, then
  one column per instrument.

## Turn A History Result Into A Matrix

Estimators want a numeric matrix. `ledgr_history_matrix()` drops the
time column and keeps the session stamps and instrument IDs as dimension
names; it reads nothing new.

``` r
returns <- ctx |> ledgr_history_frame(feature = "return_20", lookback = 5L)
ledgr_history_matrix(returns)
```

                              DEMO_02     DEMO_03    DEMO_04    DEMO_05    DEMO_06    DEMO_07
    2020-06-24T16:00:00Z  0.001212701 -0.07089401 0.02891716 0.05876594 0.09509636 0.02960912
    2020-06-25T16:00:00Z  0.002492065 -0.07075835 0.03107565 0.06357680 0.06696785 0.08128262
    2020-06-26T16:00:00Z -0.006688253 -0.08159495 0.03476388 0.06589196 0.04363223 0.07551917
    2020-06-29T16:00:00Z -0.018122740 -0.09998689 0.03778841 0.05982185 0.02913296 0.07207856
    2020-06-30T16:00:00Z -0.020660492 -0.08316307 0.01035216 0.02559996 0.04561532 0.06935646
                            DEMO_08
    2020-06-24T16:00:00Z 0.06824649
    2020-06-25T16:00:00Z 0.08076402
    2020-06-26T16:00:00Z 0.07965017
    2020-06-29T16:00:00Z 0.06554025
    2020-06-30T16:00:00Z 0.05875374

`ledgr_history_info()` returns what the result records about itself: its
source, cutoff, window, how many sessions it holds and which requested
instruments it includes or left out.

``` r
ledgr_history_info(returns)
```

    ledgr_history_info
    Source:       feature:return_20
    Cutoff:       2020-06-30T16:00:00Z
    Window start: 2020-06-24T16:00:00Z
    Sessions:     5 of requested 5
    Selector:     admissible, na_action = keep
    Included:     7 of 7 requested
    Used before window: yes
    # i Selection table: info$selection

## Choose The Instruments And The Missing Values

The defaults can be replaced one at a time.
`instruments = "decision_axis"` adds instruments the strategy holds but
may no longer buy, such as a former member.
`na_action = "drop_instruments"` leaves an instrument out of the
estimate when its window is incomplete, and records why.

``` r
window <- ctx |>
  ledgr_history_frame(bar = "close", lookback = 120L,
                      instruments = "decision_axis",
                      na_action = "drop_instruments")
info <- ledgr_history_info(window)
info
```

    ledgr_history_info
    Source:       bar:close
    Cutoff:       2020-06-30T16:00:00Z
    Window start: 2020-01-15T16:00:00Z
    Sessions:     120 of requested 120
    Selector:     decision_axis, na_action = drop_instruments
    Included:     7 of 8 requested
    Excluded:     DEMO_01 (structural_exclusion)
    Used before window: no
    # i Selection table: info$selection

``` r
info$selection[, c("instrument_id", "requested", "included", "exclusion_reason")]
```

    # A tibble: 8 x 4
      instrument_id requested included exclusion_reason
      <chr>         <lgl>     <lgl>    <chr>
    1 DEMO_01       TRUE      FALSE    "structural_exclusion"
    2 DEMO_02       TRUE      TRUE     ""
    3 DEMO_03       TRUE      TRUE     ""
    4 DEMO_04       TRUE      TRUE     ""
    5 DEMO_05       TRUE      TRUE     ""
    6 DEMO_06       TRUE      TRUE     ""
    7 DEMO_07       TRUE      TRUE     ""
    8 DEMO_08       TRUE      TRUE     ""

Leaving an instrument out of an estimate is an estimation choice only.
It creates no target, no zero target and no order.

The long layout returns one row per session and instrument, with the
evidence for each cell next to its value.

``` r
long <- ctx |> ledgr_history_frame(bar = "close", lookback = 3L, layout = "long")
as.data.frame(long)[, c("ts_utc", "instrument_id", "value", "observed",
                        "input_carried", "missing_reason")]
```

                    ts_utc instrument_id     value observed input_carried missing_reason
    1  2020-06-26 16:00:00       DEMO_02  60.47717     TRUE         FALSE
    2  2020-06-26 16:00:00       DEMO_03  54.38033     TRUE         FALSE
    3  2020-06-26 16:00:00       DEMO_04  71.35853     TRUE         FALSE
    4  2020-06-26 16:00:00       DEMO_05  80.99545     TRUE         FALSE
    5  2020-06-26 16:00:00       DEMO_06 104.84468     TRUE         FALSE
    6  2020-06-26 16:00:00       DEMO_07  99.38147     TRUE         FALSE
    7  2020-06-26 16:00:00       DEMO_08 105.96463     TRUE         FALSE
    8  2020-06-29 16:00:00       DEMO_02  59.85268     TRUE         FALSE
    9  2020-06-29 16:00:00       DEMO_03  53.74017     TRUE         FALSE
    10 2020-06-29 16:00:00       DEMO_04  71.67608     TRUE         FALSE
    11 2020-06-29 16:00:00       DEMO_05  81.21115     TRUE         FALSE
    12 2020-06-29 16:00:00       DEMO_06 103.89116     TRUE         FALSE
    13 2020-06-29 16:00:00       DEMO_07 100.13248     TRUE         FALSE
    14 2020-06-29 16:00:00       DEMO_08 105.12591     TRUE         FALSE
    15 2020-06-30 16:00:00       DEMO_02  60.01966     TRUE         FALSE
    16 2020-06-30 16:00:00       DEMO_03  53.70228     TRUE         FALSE
    17 2020-06-30 16:00:00       DEMO_04  70.98360     TRUE         FALSE
    18 2020-06-30 16:00:00       DEMO_05  79.96038     TRUE         FALSE
    19 2020-06-30 16:00:00       DEMO_06 104.61145     TRUE         FALSE
    20 2020-06-30 16:00:00       DEMO_07 100.08169     TRUE         FALSE
    21 2020-06-30 16:00:00       DEMO_08 103.70806     TRUE         FALSE

## Is There Enough History?

`ledgr_history_sufficient()` answers a structural question: does the
result hold the requested number of sessions and at least
`min_instruments` included instruments? Without `lookback` it uses the
lookback the result was read with.

``` r
recent <- ctx |>
  ledgr_history_frame(feature = "return_20", lookback = 60L,
                      na_action = "drop_instruments")
ledgr_history_sufficient(recent, min_instruments = 3L)
```

    [1] TRUE

``` r
early <- ledgr_pulse_snapshot(exp, ts_utc = as.Date("2020-01-15"),
                              params = list(lookback = 20L, n = 3L))
early_returns <- early |>
  ledgr_history_frame(feature = "return_20", lookback = 60L,
                      na_action = "drop_instruments")
ledgr_history_sufficient(early_returns, min_instruments = 3L)
```

    [1] FALSE

In January there are not yet 60 sessions of history, so the answer is
`FALSE`. This is not indicator warm-up: it inspects no value. Whether a
feature value is ready is cell evidence, described next.

## Feature History And Indicator Classes

Every indicator belongs to one of two history classes. A bounded
indicator, such as a 20-session return or a simple moving average,
depends only on its last `requires_bars` expected sessions. A
history-dependent indicator, such as TTR’s recursive exponential moving
average, depends on everything before it and starts again after a gap it
cannot bridge. Printing an indicator shows its class and where the class
comes from.

``` r
ledgr_ind_sma(20)
```

    ledgr indicator
      ID:            sma_20
      Requires bars: 20
      Stable after:  20
      Series fn:     yes
      History class: bounded (package catalogue)
      Required:      close
      Input carry:   eligible (package catalogue)

``` r
ledgr_ind_ttr("EMA", input = "close", n = 10)
```

    ledgr indicator
      ID:            ttr_ema_10
      Requires bars: 10
      Stable after:  10
      Series fn:     yes
      History class: history_dependent (package catalogue)
      Required:      close
      Input carry:   eligible (package catalogue)

Feature cells carry their own evidence. `ready` turns `TRUE` once a cell
has enough admitted sessions behind it, `calculation_valid` once it is
ready and finite, and `missing_reason` says why any other cell has no
usable value.

``` r
warm <- early |> ledgr_history_frame(feature = "return_20", layout = "long")
head(as.data.frame(warm)[warm$instrument_id == "DEMO_05",
                         c("ts_utc", "value", "ready", "calculation_valid",
                           "missing_reason")], 3)
```

                    ts_utc value ready calculation_valid missing_reason
    4  2020-01-01 16:00:00    NA FALSE             FALSE      not_ready
    11 2020-01-02 16:00:00    NA FALSE             FALSE      not_ready
    18 2020-01-03 16:00:00    NA FALSE             FALSE      not_ready

## Carried Prices Are Disclosed

By default the experiment’s history policy carries a missing open, high,
low or close forward for at most five expected sessions; volume never
carries. A carried cell says so, with its source session and age.

``` r
pit$cases
```

                     type instrument_id       date
    1       venue_closure          <NA> 2020-01-06
    2 missing_observation       DEMO_04 2020-01-09
    3           delisting       DEMO_01 2020-01-14
    4                halt       DEMO_02 2020-01-03
    5       cash_dividend       DEMO_03 2020-01-10

``` r
gap <- pit$cases[pit$cases$type == "missing_observation", ]
open_days <- as.Date(pit$sessions$session_date[pit$sessions$status == "open"])
after_gap <- open_days[match(as.Date(gap$date), open_days) + 2L]
gap_ctx <- ledgr_pulse_snapshot(exp, ts_utc = after_gap,
                                params = list(lookback = 20L, n = 3L))
carried <- gap_ctx |>
  ledgr_history_frame(bar = "close", lookback = 4L,
                      instruments = gap$instrument_id, layout = "long")
as.data.frame(carried)[, c("ts_utc", "value", "observed", "input_carried",
                           "source_ts_utc", "carry_age_sessions")]
```

                   ts_utc    value observed input_carried       source_ts_utc
    1 2020-01-08 16:00:00 68.57806     TRUE         FALSE 2020-01-08 16:00:00
    2 2020-01-09 16:00:00 68.57806    FALSE          TRUE 2020-01-08 16:00:00
    3 2020-01-10 16:00:00 70.08739     TRUE         FALSE 2020-01-10 16:00:00
    4 2020-01-13 16:00:00 69.76760     TRUE         FALSE 2020-01-13 16:00:00
      carry_age_sessions
    1                  0
    2                  1
    3                  0
    4                  0

The selection table counts how much of each instrument’s window was
carried:

``` r
ledgr_history_info(carried)$selection[, c("instrument_id", "required_input_count",
                                          "carried_input_count",
                                          "carried_input_share")]
```

    # A tibble: 8 x 4
      instrument_id required_input_count carried_input_count carried_input_share
      <chr>                        <int>               <int>               <dbl>
    1 DEMO_04                          4                   1                0.25
    2 DEMO_01                         NA                  NA               NA
    3 DEMO_02                         NA                  NA               NA
    4 DEMO_03                         NA                  NA               NA
    5 DEMO_05                         NA                  NA               NA
    6 DEMO_06                         NA                  NA               NA
    7 DEMO_07                         NA                  NA               NA
    8 DEMO_08                         NA                  NA               NA

`ledgr_history_policy(price_carry = NULL)` turns input carry off, so a
missing close stays missing.

## Read Return Features, Not Differences Of Carried Closes

A carried close repeats the previous close, so a return computed by
differencing the close history is exactly zero on the missing session,
and the next session carries the whole two-session move as if it were
one day. Neither number is an observed daily return. Return and
volatility features never consume a carried price: the cell on the
missing session is missing with the reason `carried_input_excluded`, the
next one is `not_ready` while the return restarts, and the first return
computed from two observed closes follows.

``` r
with_return <- ledgr_experiment(
  snapshot, momentum,
  features = list(ledgr_ind_returns(1L)),
  universe = ledgr_universe_members("DEMO_UNIVERSE"),
  cost_model = ledgr_cost_zero()
)
gap_ctx1 <- ledgr_pulse_snapshot(with_return, ts_utc = after_gap,
                                 params = list(lookback = 1L, n = 3L))
close_window <- gap_ctx1 |>
  ledgr_history_frame(bar = "close", lookback = 4L, instruments = gap$instrument_id)
diff(log(ledgr_history_matrix(close_window)[, 1]))
```

    2020-01-09T16:00:00Z 2020-01-10T16:00:00Z 2020-01-13T16:00:00Z
             0.000000000          0.021770203         -0.004573114

``` r
return_cells <- gap_ctx1 |>
  ledgr_history_frame(feature = "return_1", lookback = 3L,
                      instruments = gap$instrument_id, layout = "long")
as.data.frame(return_cells)[, c("ts_utc", "value", "missing_reason")]
```

                   ts_utc        value         missing_reason
    1 2020-01-09 16:00:00           NA carried_input_excluded
    2 2020-01-10 16:00:00           NA              not_ready
    3 2020-01-13 16:00:00 -0.004562673

## From History To Targets

This is the whole estimation flow in one strategy: read a window of
daily returns, estimate minimum-variance weights with a plain solver,
name the solver’s output through the history result, and turn the
weights into targets. The solver is defined inside the strategy, because
preflight refuses a strategy that depends on a function from the calling
session.

``` r
estimate <- function(ctx, params) {
  # A plain long-only minimum-variance solver: it returns an unnamed vector
  # in the column order of its input.
  min_variance <- function(sigma) {
    w <- solve(sigma + diag(1e-6, ncol(sigma)), rep(1, ncol(sigma)))
    w <- pmax(as.vector(w), 0)
    w / sum(w)
  }
  returns <- ctx |>
    ledgr_history_frame(feature = "return_1", lookback = params$lookback,
                        na_action = "drop_instruments")
  if (!ledgr_history_sufficient(returns, min_instruments = 3L)) {
    return(ctx$hold())
  }
  w <- min_variance(stats::cov(ledgr_history_matrix(returns)))
  held <- ctx$universe[ctx$vec$position != 0]
  keep <- intersect(ledgr_history_info(returns)$excluded_ids, held)
  returns |>
    ledgr_history_weights(w) |>
    ledgr_target_rebalance(ctx, equity_fraction = 0.95, keep = keep)
}

estimating <- ledgr_experiment(
  snapshot, estimate,
  features = list(ledgr_ind_returns(1L)),
  universe = ledgr_universe_members("DEMO_UNIVERSE"),
  cost_model = ledgr_cost_zero()
)
```

At one pulse, the strategy returns a full target, a share quantity for
every instrument; `c()` prints all of them:

``` r
june <- ledgr_pulse_snapshot(estimating, ts_utc = as.Date("2020-06-30"),
                             params = list(lookback = 40L))
c(estimate(june, list(lookback = 40L)))
```

    DEMO_01 DEMO_02 DEMO_03 DEMO_04 DEMO_05 DEMO_06 DEMO_07 DEMO_08
          0     365     159      93     134     177     176     104

`ledgr_history_weights()` reads the unnamed solver output in the order
of the result’s included instruments and refuses a vector of the wrong
length, so no column name is rebuilt by hand.

Two separate choices are at work. Estimation exclusion decides which
instruments enter the covariance estimate. Execution intent decides what
happens to each position. `ledgr_target_rebalance()` targets every
eligible instrument without a weight to zero, so an instrument the
estimate dropped would be sold. Passing the dropped instruments that are
held in `keep` preserves those positions instead. The excluded IDs come
from `ledgr_history_info()`; the held ones from the context. A held
instrument that is no longer admissible is not requested under the
default selector, so it never appears among the excluded IDs;
`ledgr_target_rebalance()` already preserves such holdings.

``` r
estimated <- estimating |>
  ledgr_run(params = list(lookback = 40L), run_id = "history-estimate")
estimated
```

    ledgr Backtest Results
    ======================

    Run ID:                            history-estimate
    Period:                            2020-01-01T16:00:00Z to 2020-12-31T16:00:00Z
    Opening Cash:                      $100000.00
    Final Equity:                      $109912.34
    Total Return:                      9.91%
    Max Drawdown:                      -4.09%
    Closed Trades:                     733

    Corporate actions: NONE - supplied facts did not affect held instruments
    Price basis: split_adjusted (declared)
    Valuation: CURRENT - every held mark was a current close
    Point in time: membership rule 'DEMO_UNIVERSE'; valuation stale-mark horizon 5 sessions (default)
    History policy: price carry 5 sessions (default); output carry off (default); segment limit 4 per fact, at least 16 (default)

    Use summary(bt) for metrics and evidence

## When A Fact Arrives Late

Facts can become known after the sessions they describe. A lifetime fact
may say an instrument was inactive for two sessions, but arrive only on
the third. The two kinds of history treat that differently:

- bar history is restated with what is known at the cutoff, so a read
  after the fact arrives marks those sessions as inactive;
- feature history is a vintage view, so each feature cell keeps the
  value and the evidence it had at its own pulse. The late fact changes
  feature cells only from the pulse at which it became known.

``` r
days <- as.Date("2021-01-04") + c(0:4, 7:9)
close_at <- function(d) as.POSIXct(paste(d, "21:00:00"), tz = "UTC")
open_at <- function(d) as.POSIXct(paste(d, "14:30:00"), tz = "UTC")
late_bars <- data.frame(
  instrument_id = rep(c("AAA", "DDD"), each = 8L),
  ts_utc = rep(close_at(days), 2L),
  close = c(11:18, 41, 43, 46, 50, 55, 61, 68, 76)
)
late_bars$open <- late_bars$high <- late_bars$low <- late_bars$close
late_bars$volume <- 100
calendar <- seq(min(days), max(days), by = "day")
is_open <- calendar %in% days
late_members <- data.frame(effective_from = close_at(days[[1L]] - 1),
                           knowledge_time = close_at(days[[1L]] - 1))
late_members$members <- I(list(c("AAA", "DDD")))
late_facts <- ledgr_facts(
  ledgr_facts_sessions(data.frame(
    session_date = calendar, status = ifelse(is_open, "open", "closed"),
    session_open = ifelse(is_open, "14:30:00", NA),
    session_close = ifelse(is_open, "21:00:00", NA)
  ), venue_id = "LATE_VENUE", knowledge = "assume_effective"),
  ledgr_facts_membership_snapshots(late_members, universe_id = "late",
                                   complete = TRUE, knowledge = "assume_effective"),
  ledgr_facts_lifetime(data.frame(
    instrument_id = "DDD",
    effective_from = open_at(days[[5L]]),
    effective_to = open_at(days[[7L]]),
    knowledge_time = open_at(days[[7L]]),
    assertion = "known_inactive",
    terminal_event = NA_character_
  ))
)
late_snapshot <- ledgr_snapshot_from_df(
  late_bars, data.frame(instrument_id = c("AAA", "DDD")),
  db_path = file.path(tempdir(), "late-fact.duckdb"),
  snapshot_id = "late_fact", facts = late_facts, price_basis = "split_adjusted"
)
late_exp <- ledgr_experiment(
  late_snapshot, function(ctx, params) ctx$hold(),
  features = ledgr_feature_map(sma = ledgr_ind_sma(2)),
  universe = ledgr_universe_members("late"),
  cost_model = ledgr_cost_zero()
)
read_ddd <- function(day, ...) {
  ctx <- ledgr_pulse_snapshot(late_exp, ts_utc = day)
  on.exit(close(ctx))
  out <- ctx |> ledgr_history_frame(..., instruments = "DDD", layout = "long")
  as.data.frame(out)[5:6, c("ts_utc", "value", "expected", "missing_reason")]
}
read_ddd(days[[6L]], bar = "close")
```

                   ts_utc value expected missing_reason
    5 2021-01-08 21:00:00    55     TRUE
    6 2021-01-11 21:00:00    61     TRUE

``` r
read_ddd(days[[7L]], bar = "close")
```

                   ts_utc value expected          missing_reason
    5 2021-01-08 21:00:00    55    FALSE inactive_interval_print
    6 2021-01-11 21:00:00    61    FALSE inactive_interval_print

``` r
read_ddd(days[[7L]], feature = "sma")
```

                   ts_utc value expected missing_reason
    5 2021-01-08 21:00:00  52.5     TRUE
    6 2021-01-11 21:00:00  58.0     TRUE

Read at the sixth session, both sessions are ordinary. Read at the
seventh, after the fact is known, the bar history marks them as prints
from an inactive interval, while the moving-average cells keep the
values they were computed with at the time.

## Walk-Forward Windows Read One History

A walk-forward test window does not start its history at the window
start. Every run, sweep candidate and window reads the same history from
the start of the data, so a feature or a history read at the first pulse
of a test window sees everything before the window, as it would inside
one long run.

``` r
folds <- ledgr_folds_rolling(start = "2020-01-01", end = "2021-01-01",
                             train_window = "6 months", test_window = "3 months")
wf <- ledgr_walk_forward(
  exp, ledgr_strategy_grid(lookback = 20L, n = c(2L, 3L)), folds,
  selection_rule = ledgr_rule_argmax("sharpe_ratio"), seed = 1L
)
wf$folds[, c("fold_seq", "test_start_utc", "status")]
```

    # A tibble: 2 x 3
      fold_seq test_start_utc      status
         <int> <dttm>              <chr>
    1        1 2020-07-01 00:00:00 DONE
    2        2 2020-10-01 00:00:00 DONE

``` r
first_test <- ledgr_pulse_snapshot(exp, ts_utc = as.Date("2020-07-01"),
                                   params = list(lookback = 20L, n = 3L))
history_start <- first_test |> ledgr_history_frame(bar = "close")
ledgr_history_info(history_start)$data_start_utc
```

    [1] "2020-01-01 16:00:00 UTC"

``` r
nrow(history_start)
```

    [1] 130

At the first test pulse, 1 July, the read starts on 1 January: every
session before the window is there.

The default `opening_state_policy = "carry_test_state"` also carries the
portfolio across window boundaries, so consecutive test windows form one
continuous economic chain.

## Read A Finite Lookback

`lookback = Inf` is convenient for exploring, but a strategy that reads
the whole history at every pulse allocates in proportion to everything
seen so far, and the total work over a run grows with the square of its
length. Read the window your estimator needs.

``` r
full <- ctx |> ledgr_history_frame(feature = "return_20")
last_60 <- ctx |> ledgr_history_frame(feature = "return_20", lookback = 60L)
vapply(list(full = full, last_60 = last_60),
       function(x) format(utils::object.size(x), units = "Kb"), character(1))
```

          full    last_60
    "219.9 Kb" "115.4 Kb"

Both reads end at the same pulse and agree on every session they share;
the first grows with every pulse of a run, the second does not.

## What ledgr Guarantees

ledgr guarantees that its own history, feature and fact readers return
only data known at the decision time. Strategy code outside them is the
author’s responsibility. `ledgr_strategy_preflight()` helps with a
best-effort static check: it refuses code that reaches private context
internals, non-exported ledgr objects or environment-inspecting
functions, which is how a strategy could otherwise reach prepared data
from later sessions.

``` r
peeking <- function(ctx, params) {
  future <- ctx$.history
  ctx$hold()
}
ledgr_strategy_preflight(peeking)
```

    ledgr Strategy Preflight
    =========================

    Tier:    tier_3
    Allowed: FALSE
    Reason:  Strategy reaches private context internals: $.history, .history. Read the context through its public fields and functions and history through `ledgr_history_frame()`.

Preflight is not a sandbox. R gives a strategy no private memory, so
code that deliberately works around the check, for example by reading a
file of future prices, is outside what ledgr can guarantee.

## Where Next

- Continue with `vignette("point-in-time-inputs", package = "ledgr")` to
  see how a snapshot like the one above is prepared from bars and facts.
- For how missing sessions and halts become values, see
  `vignette("missing-data-and-sessions", package = "ledgr")`.
