Getting Started with ledgr
================

This vignette walks through the ledgr research loop:

1.  create bar data;
2.  write a target-holdings strategy;
3.  run a backtest;
4.  inspect the recorded results;
5.  debug one decision point;
6.  move from exploratory data to durable research artifacts.

The goal is not to build a profitable strategy. The goal is to
understand how ledgr models decisions over time and why it records them
in an event ledger. The data is deliberately synthetic so the vignette
can run offline; the same workflow applies to real OHLCV bars.

## Step 1: Create Bar Data

``` r
library(ledgr)
library(tibble)
```

``` r
set.seed(20260425)
calendar <- seq.Date(as.Date("2020-01-01"), as.Date("2020-02-14"), by = "day")
dates <- calendar[!(weekdays(calendar) %in% c("Saturday", "Sunday"))]

make_bars <- function(instrument_id, start_price, drift) {
  n <- length(dates)
  close <- start_price + cumsum(drift + stats::rnorm(n, mean = 0, sd = 0.35))
  open <- c(start_price, close[-n])

  data.frame(
    ts_utc = as.POSIXct(dates, tz = "UTC"),
    instrument_id = instrument_id,
    open = round(open, 2),
    high = round(pmax(open, close) + 0.45, 2),
    low = round(pmin(open, close) - 0.45, 2),
    close = round(close, 2),
    volume = seq.int(1000L, 1000L + n - 1L),
    stringsAsFactors = FALSE
  )
}

bars <- rbind(
  make_bars("AAA", start_price = 100, drift = 0.18),
  make_bars("BBB", start_price = 80, drift = -0.04)
)

bars |> as_tibble() |> head(6)
#> # A tibble: 6 x 7
#>   ts_utc              instrument_id  open  high   low close volume
#>   <dttm>              <chr>         <dbl> <dbl> <dbl> <dbl>  <int>
#> 1 2020-01-01 00:00:00 AAA            100   101.  99.6  100.   1000
#> 2 2020-01-02 00:00:00 AAA            100.  101.  99.7  100.   1001
#> 3 2020-01-03 00:00:00 AAA            100.  101. 100.0  101.   1002
#> 4 2020-01-06 00:00:00 AAA            101.  101. 100.   101.   1003
#> 5 2020-01-07 00:00:00 AAA            101.  101. 100.   101.   1004
#> 6 2020-01-08 00:00:00 AAA            101.  102. 100.   101.   1005
```

This is the smallest useful shape for ledgr bar data. Each row is one
instrument at one timestamp.

Required columns are `ts_utc`, `instrument_id`, `open`, `high`, `low`,
and `close`. `volume` is optional. The timestamps in this example are
business days because that reads more like market data, but ledgr does
not require daily bars or a specific exchange calendar.

A backtest is only as auditable as its inputs. ledgr turns these rows
into a sealed snapshot before it runs the engine. A snapshot is the data
contract for a run.

## Step 2: Write A Strategy

``` r
strategy <- function(ctx, params) {
  targets <- ctx$flat()

  if (ctx$close("AAA") > 100.4) {
    targets["AAA"] <- floor(0.40 * ctx$equity / ctx$close("AAA"))
  }

  if (ctx$close("BBB") > 80.0) {
    targets["BBB"] <- floor(0.30 * ctx$equity / ctx$close("BBB"))
  }

  targets
}
```

Read the function as a short research rule:

- start from flat target holdings;
- put about 40% of current equity into `AAA` when its close is above
  100.4;
- put about 30% of current equity into `BBB` when its close is above
  80.0.

The helper calls keep strategy code readable. `ctx$flat()` creates a
named target vector over the full universe and initializes every
instrument to flat. `ctx$close("AAA")` reads the close price at the
current decision point. `ctx$cash` is current simulated cash, and
`ctx$equity` is current simulated portfolio value.
`ctx$position("AAA")`, which we use later, reads the current held
quantity.

## Step 3: Run The First Backtest

``` r
bt <- ledgr_backtest(
  data = bars,
  strategy = strategy,
  initial_cash = 10000,
  run_id = "getting-started-demo"
)

bt
#> ledgr Backtest Results
#> ======================
#>
#> Run ID:         getting-started-demo
#> Universe:       AAA, BBB
#> Date Range:     2020-01-01T00:00:00Z to 2020-02-14T00:00:00Z
#> Execution Mode: audit_log
#> Initial Cash:   $10000.00
#> Final Equity:   $13107.17
#> P&L:            $3107.17 (31.07%)
#>
#> Use summary(bt) for detailed metrics
#> Use plot(bt) for equity curve visualization
```

`ledgr_backtest()` is the primary first-use path. It accepts a data
frame, creates a sealed snapshot internally, runs the strategy, and
returns a handle to one recorded run.

The fixed `run_id` makes printed output stable. In interactive work you
can omit it and ledgr will generate a unique one. A `ledgr_backtest`
object points to one run.

A `ledgr_backtest` object owns a lazy DuckDB connection. In longer
scripts, register cleanup after construction so Windows file handles do
not stay open:

``` r
on.exit(close(bt), add = TRUE)
```

When `start` and `end` are omitted, ledgr uses the full timestamp range
in the snapshot. If you pass a narrower window, the snapshot can still
contain more data, but the run only iterates through pulses inside that
inclusive window.

## Step 4: Inspect The Result Views

``` r
summary(bt)
#> ledgr Backtest Summary
#> ======================
#>
#> Performance Metrics:
#>   Total Return:        31.07%
#>   Annualized Return:   742.14%
#>   Max Drawdown:        -29.63%
#>
#> Risk Metrics:
#>   Volatility (annual): 199.20%
#>
#> Trade Statistics:
#>   Total Trades:        7
#>   Win Rate:            28.57%
#>   Avg Trade:           $-0.81
#>
#> Exposure:
#>   Time in Market:      93.94%
```

In this toy run, total return is positive while win rate is 0%. That is
not a contradiction: win rate is computed from closed trades, and the
profitable `AAA` position remains open at the end. Its gain appears in
equity, not in the closed-trade win rate.

The summary is a derived view. It is useful for a quick read, but the
audit trail lives underneath it.

``` r
bt |> as_tibble(what = "trades")
#> # A tibble: 7 x 9
#>   event_seq ts_utc              instrument_id side    qty price   fee realized_pnl action
#>       <int> <dttm>              <chr>         <chr> <dbl> <dbl> <dbl>        <dbl> <chr>
#> 1         1 2020-01-03 00:00:00 AAA           BUY      39 100.      0        0     OPEN
#> 2         2 2020-01-07 00:00:00 BBB           BUY      37  80.2     0        0     OPEN
#> 3         3 2020-01-13 00:00:00 BBB           SELL     37  80.0     0       -9.99  CLOSE
#> 4         4 2020-01-14 00:00:00 BBB           BUY      37  80.8     0        0     OPEN
#> 5         5 2020-01-22 00:00:00 BBB           SELL      1  81.4     0        0.620 CLOSE
#> 6         6 2020-01-23 00:00:00 BBB           BUY       1  81.2     0        0     OPEN
#> 7         7 2020-02-13 00:00:00 AAA           SELL      1 104.      0        3.69  CLOSE
```

`trades` is the research-friendly fills table. It answers: what actually
got executed?

``` r
bt |> as_tibble(what = "ledger")
#> # A tibble: 7 x 11
#>   event_id     run_id ts_utc              event_type instrument_id side    qty price   fee
#>   <chr>        <chr>  <dttm>              <chr>      <chr>         <chr> <dbl> <dbl> <dbl>
#> 1 getting-sta~ getti~ 2020-01-03 00:00:00 FILL       AAA           BUY      39 100.      0
#> 2 getting-sta~ getti~ 2020-01-07 00:00:00 FILL       BBB           BUY      37  80.2     0
#> 3 getting-sta~ getti~ 2020-01-13 00:00:00 FILL       BBB           SELL     37  80.0     0
#> 4 getting-sta~ getti~ 2020-01-14 00:00:00 FILL       BBB           BUY      37  80.8     0
#> 5 getting-sta~ getti~ 2020-01-22 00:00:00 FILL       BBB           SELL      1  81.4     0
#> 6 getting-sta~ getti~ 2020-01-23 00:00:00 FILL       BBB           BUY       1  81.2     0
#> 7 getting-sta~ getti~ 2020-02-13 00:00:00 FILL       AAA           SELL      1 104.      0
#> # i 2 more variables: meta_json <chr>, event_seq <int>
```

`ledger` is the raw event stream. It is the source of truth. Use it when
you need to audit the exact sequence of state changes.

``` r
bt |> as_tibble(what = "equity") |> tail(6)
#> # A tibble: 6 x 6
#>   ts_utc              equity  cash positions_value running_max drawdown
#>   <dttm>               <dbl> <dbl>           <dbl>       <dbl>    <dbl>
#> 1 2020-02-07 00:00:00 10065. 3085.           6980.      12999.   -0.226
#> 2 2020-02-10 00:00:00 10089. 3085.           7004.      12999.   -0.224
#> 3 2020-02-11 00:00:00 10085. 3189.           6897.      12999.   -0.224
#> 4 2020-02-12 00:00:00 10127. 3189.           6938.      12999.   -0.221
#> 5 2020-02-13 00:00:00 13099. 6083.           7016.      13099.    0
#> 6 2020-02-14 00:00:00 13107. 6083.           7024.      13107.    0
```

`equity` is the portfolio value over time. It is also derived from
recorded state, not from a hidden intermediate calculation.

Trades, equity, and metrics are views over recorded history. If a number
looks strange, you can trace it back to the events that produced it.

``` r
plot(bt)
```

<img src="figures/getting-started-plot-backtest-1.png" alt="Line chart of the backtest equity curve above an area chart of drawdown over the same date range." width="100%" />

The plot is another derived view over the same recorded state. The top
panel shows equity over time. The bottom panel shows drawdown relative
to the running maximum.

## Step 5: Understand Pulses, Targets, And Fills

ledgr does not treat data as a static table. It simulates a system that
moves forward in time:

``` text
data.frame
-> sealed snapshot (immutable input)
-> pulse-by-pulse execution (time iteration)
-> event ledger (state changes recorded)
-> derived views (trades, equity, summary)
```

A pulse is one decision point. At each pulse, the strategy observes only
the current and past state, returns target holdings, and then the engine
records any position changes as events.

Every ledgr strategy returns target holding amounts:

``` r
c(AAA = 10, BBB = 0)
```

That means: hold 10 units of `AAA` and hold 0 units of `BBB`.

Names are part of the contract because ledgr must match each target to
`ctx$universe`. These are invalid strategy outputs:

``` r
c(10, 0)                  # missing instrument names
c(AAA = "LONG", BBB = 0)  # not numeric
```

ledgr expects a named numeric target vector with names matching
`ctx$universe`. It does not accept raw signal labels such as `"LONG"` or
`"FLAT"` as core strategy output.

`ctx$flat()` starts from flat positions. That is useful when every pulse
should fully restate the desired portfolio. For hold-unless-signal
rules, start from the current position vector instead:

``` r
targets <- ctx$hold()
```

That pattern says: keep current holdings unless this pulse explicitly
changes them.

The default fill model is next-open. A target change decided at pulse
`t` fills on the next available bar. If the strategy asks for a new
position on the final available pulse, there is no next bar to fill
against, so ledgr warns with `LEDGR_LAST_BAR_NO_FILL` and records no
fill for that final request.

Non-default fill costs are supplied through `fill_model`:

``` r
fill_model <- list(type = "next_open", spread_bps = 5, commission_fixed = 1)
```

Real trading systems receive information step by step. ledgr follows
that shape. The strategy does not get future prices. It gets the current
pulse, makes a decision, and the engine moves forward.

You can throttle rebalances inside the strategy by using `ctx$ts_utc`.
This toy example only changes targets on the first calendar day of a
month and keeps current holdings otherwise:

``` r
monthly_strategy <- function(ctx, params) {
  targets <- ctx$hold()
  if (format(as.Date(ctx$ts_utc), "%d") != "01") return(targets)

  if (ctx$close("AAA") > 100) {
    targets["AAA"] <- floor(0.50 * ctx$equity / ctx$close("AAA"))
  }

  targets
}
```

## Step 6: Add A Simple Indicator

Indicators are deterministic features computed at each pulse. The
strategy can read them from the same `ctx` object.

``` r
features <- list(ledgr_ind_sma(3))

sma_strategy <- function(ctx, params) {
  targets <- ctx$flat()
  sma_3 <- ctx$feature("AAA", "sma_3")

  if (is.finite(sma_3) && ctx$close("AAA") > sma_3) {
    targets["AAA"] <- 10
  }

  targets
}

bt_sma <- ledgr_backtest(
  data = bars,
  strategy = sma_strategy,
  features = features,
  end = as.POSIXct("2020-02-13", tz = "UTC"),
  initial_cash = 10000,
  run_id = "getting-started-sma"
)

bt_sma |> as_tibble(what = "trades") |> head(6)
#> # A tibble: 6 x 9
#>   event_seq ts_utc              instrument_id side    qty price   fee realized_pnl action
#>       <int> <dttm>              <chr>         <chr> <dbl> <dbl> <dbl>        <dbl> <chr>
#> 1         1 2020-01-06 00:00:00 AAA           BUY      10  101.     0        0     OPEN
#> 2         2 2020-01-13 00:00:00 AAA           SELL     10  101.     0        7.60  CLOSE
#> 3         3 2020-01-15 00:00:00 AAA           BUY      10  101.     0        0     OPEN
#> 4         4 2020-01-21 00:00:00 AAA           SELL     10  102.     0        0.600 CLOSE
#> 5         5 2020-01-23 00:00:00 AAA           BUY      10  102.     0        0     OPEN
#> 6         6 2020-01-28 00:00:00 AAA           SELL     10  101.     0       -3.40  CLOSE
```

The first few indicator values may be `NA` while the indicator warms up.
In the strategy above, `is.finite(sma_3)` prevents trading before the
SMA is available.

The example uses an explicit `end` one bar before the last available
bar. That keeps the example focused on indicator behavior rather than
the final-bar no-fill warning described above.

Indicators are part of the pulse context. ledgr computes the feature
values without lookahead and records the run through the same event
ledger.

## Step 7: Debug One Pulse

After a run, the most common debugging question is: why did the strategy
make that decision at that time?

The useful answer is a pulse snapshot: the exact context the strategy
saw at one timestamp. The first backtest created a snapshot internally.
Here we create one explicitly so the debugging tool has a snapshot
handle, then choose a readable timestamp.

``` r
snapshot <- ledgr_snapshot_from_df(
  bars,
  db_path = tempfile(fileext = ".duckdb")
)

decision_time <- as.POSIXct("2020-01-14", tz = "UTC")
decision_time
#> [1] "2020-01-14 UTC"
```

``` r
pulse <- ledgr_pulse_snapshot(
  snapshot = snapshot,
  universe = c("AAA", "BBB"),
  ts_utc = decision_time
)

pulse$ts_utc
#> [1] "2020-01-14T00:00:00Z"
pulse$bars
#>   instrument_id               ts_utc   open   high    low  close volume
#> 1           AAA 2020-01-14T00:00:00Z 101.29 101.92 100.84 101.47   1009
#> 2           BBB 2020-01-14T00:00:00Z  80.77  81.22  80.28  80.73   1009
pulse$close("AAA")
#> [1] 101.47
pulse$position("AAA")
#> [1] 0
pulse$hold()
#> AAA BBB
#>   0   0
strategy(pulse, list())
#> AAA BBB
#> 394 371
```

At this moment, the strategy only sees state available at
`pulse$ts_utc`. `pulse$hold()` shows the current holdings as a full
target vector. `strategy(pulse, list())` shows the target holdings the
strategy would request from that context.

A pulse snapshot is read-only. It is meant for research and debugging,
not for changing run state. The close calls release DuckDB connections.

``` r
close(pulse)
ledgr_snapshot_close(snapshot)
```

Debugging a backtest should not require guessing from final outputs. You
can inspect the decision context directly.

## Step 8: Use Yahoo As A Convenience Source

Yahoo is the quickest path from a ticker symbol to a sealed ledgr
snapshot. This path requires the optional `quantmod` package and network
access:

``` r
install.packages("quantmod")
```

``` r
library(quantmod)

yahoo_strategy <- function(ctx, params) {
  targets <- ctx$flat()

  if (ctx$close("AAPL") > ctx$open("AAPL")) {
    targets["AAPL"] <- floor(0.40 * ctx$equity / ctx$close("AAPL"))
  }

  if (ctx$close("MSFT") > ctx$open("MSFT")) {
    targets["MSFT"] <- floor(0.30 * ctx$equity / ctx$close("MSFT"))
  }

  targets
}

yahoo_snapshot <- ledgr_snapshot_from_yahoo(
  symbols = c("AAPL", "MSFT"),
  from = "2020-01-01",
  to = "2020-03-31",
  db_path = tempfile(fileext = ".duckdb")
)

yahoo_bt <- ledgr_backtest(
  snapshot = yahoo_snapshot,
  strategy = yahoo_strategy,
  universe = c("AAPL", "MSFT"),
  start = "2020-01-01",
  end = "2020-03-31",
  initial_cash = 10000
)

yahoo_bt
yahoo_bt |> as_tibble(what = "trades")
plot(yahoo_bt)

ledgr_snapshot_close(yahoo_snapshot)
```

The code above is meant to be run interactively. It is not defensive
because the dependency is part of the workflow: install `quantmod`,
attach it, fetch data, seal the result, then run ledgr.

The rendered vignette does not execute the live Yahoo chunk because live
API output is not a stable release artifact. Yahoo is convenient for
exploration, but it is provider-dependent and not deterministic as a
source. Providers can revise historical data.

For durable research, download once, seal the downloaded data into a
snapshot, and reuse that snapshot. The ledgr audit guarantees apply to
the sealed data, not to the external provider.

## Step 9: Make Research Durable

The quick path creates temporary storage for you. For research you want
to keep, choose the data file and DuckDB path yourself. This vignette
uses `tempfile()` for CRAN-safe examples; in real projects use a stable
path under your research directory.

``` r
bars_csv <- tempfile(fileext = ".csv")
artifact_db <- tempfile("ledgr_getting_started_", fileext = ".duckdb")

bars_for_csv <- bars
bars_for_csv$ts_utc <- format(bars_for_csv$ts_utc, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")

utils::write.csv(bars_for_csv, bars_csv, row.names = FALSE)

snapshot <- ledgr_snapshot_from_csv(
  csv_path = bars_csv,
  db_path = artifact_db
)
snapshot_id <- snapshot$snapshot_id

durable_bt <- ledgr_backtest(
  snapshot = snapshot,
  strategy = strategy,
  universe = c("AAA", "BBB"),
  initial_cash = 10000,
  run_id = "getting-started-durable"
)

basename(durable_bt$db_path)
#> [1] "ledgr_getting_started_deec6d9a57b7.duckdb"
file.exists(durable_bt$db_path)
#> [1] TRUE

durable_bt |> as_tibble(what = "trades")
#> # A tibble: 7 x 9
#>   event_seq ts_utc              instrument_id side    qty price   fee realized_pnl action
#>       <int> <dttm>              <chr>         <chr> <dbl> <dbl> <dbl>        <dbl> <chr>
#> 1         1 2020-01-03 00:00:00 AAA           BUY      39 100.      0        0     OPEN
#> 2         2 2020-01-07 00:00:00 BBB           BUY      37  80.2     0        0     OPEN
#> 3         3 2020-01-13 00:00:00 BBB           SELL     37  80.0     0       -9.99  CLOSE
#> 4         4 2020-01-14 00:00:00 BBB           BUY      37  80.8     0        0     OPEN
#> 5         5 2020-01-22 00:00:00 BBB           SELL      1  81.4     0        0.620 CLOSE
#> 6         6 2020-01-23 00:00:00 BBB           BUY       1  81.2     0        0     OPEN
#> 7         7 2020-02-13 00:00:00 AAA           SELL      1 104.      0        3.69  CLOSE
durable_bt |> as_tibble(what = "equity") |> tail(3)
#> # A tibble: 3 x 6
#>   ts_utc              equity  cash positions_value running_max drawdown
#>   <dttm>               <dbl> <dbl>           <dbl>       <dbl>    <dbl>
#> 1 2020-02-12 00:00:00 10127. 3189.           6938.      12999.   -0.221
#> 2 2020-02-13 00:00:00 13099. 6083.           7016.      13099.    0
#> 3 2020-02-14 00:00:00 13107. 6083.           7024.      13107.    0

close(durable_bt)
ledgr_snapshot_close(snapshot)

reloaded_snapshot <- ledgr_snapshot_load(artifact_db, snapshot_id, verify = TRUE)
ledgr_snapshot_info(reloaded_snapshot)[, c("snapshot_id", "status", "bar_count")]
#>                     snapshot_id status bar_count
#> 1 snapshot_20260428_165835_215e SEALED        66
ledgr_snapshot_close(reloaded_snapshot)
```

The close calls at the end release file handles. They do not delete a
stable project database; this example uses temporary paths only so the
vignette can run cleanly during package checks.

CSV workflows should write timestamps as explicit UTC strings such as
`2020-01-01T00:00:00Z`. The parser is deliberately strict because
timestamp ambiguity is a common source of backtest drift.

This DuckDB file now contains:

- the sealed input snapshot;
- the recorded run events;
- derived views such as trades and equity.

Keeping this file means keeping the research artifact.

`ledgr_snapshot_load()` is the rerun path. It reopens an existing sealed
snapshot by database path and snapshot id. It does not create or
overwrite snapshots, and `verify = TRUE` recomputes the snapshot hash
before returning.

`run_id` names one run inside that artifact file. The experiment-store
helpers make those runs discoverable and reopenable without recomputing
the strategy:

``` r
durable_snapshot <- ledgr_snapshot_load(artifact_db, snapshot_id)

ledgr_run_list(durable_snapshot)[, c("run_id", "status", "execution_mode", "total_return")]
#> # A tibble: 1 x 4
#>   run_id                  status execution_mode total_return
#>   <chr>                   <chr>  <chr>                 <dbl>
#> 1 getting-started-durable DONE   audit_log             0.311

run_info <- ledgr_run_info(durable_snapshot, "getting-started-durable")
run_info
#> ledgr Run Info
#> ==============
#>
#> Run ID:          getting-started-durable
#> Label:           NA
#> Status:          DONE
#> Archived:        FALSE
#> Tags:            NA
#> Snapshot:        snapshot_20260428_165835_215e
#> Snapshot Hash:   a91451efaef4cd8be93458d12f4680166107b56033ec9e5a0c9f23e3d39a9442
#> Config Hash:     200a1c5c0dc9829f53237274c14e266ff8df82440abeaff53e88ee4e4a0976b9
#> Strategy Hash:   e6f588c03da63a973d766baab1ee5ecf169303cc705a1d8876556c64334dc8d9
#> Params Hash:     071685bbedd79b55e3cadcf0089a6d740ffa729e425e34aef44a8beab9a67c87
#> Reproducibility: tier_1
#> Execution Mode:  audit_log
#> Elapsed Sec:     0.94
#> Persist Features:TRUE
#> Cache Hits:      0
#> Cache Misses:    0

reopened_bt <- ledgr_run_open(durable_snapshot, "getting-started-durable")
reopened_bt |> ledgr_results(what = "equity") |> tail(2)
#> # A tibble: 2 x 6
#>   ts_utc              equity  cash positions_value running_max drawdown
#>   <dttm>               <dbl> <dbl>           <dbl>       <dbl>    <dbl>
#> 1 2020-02-13 00:00:00 13099. 6083.           7016.      13099.        0
#> 2 2020-02-14 00:00:00 13107. 6083.           7024.      13107.        0
close(reopened_bt)
close(durable_snapshot)
```

Use `ledgr_run_label()` for mutable human-readable names and
`ledgr_run_archive()` to hide old runs from default listings without
deleting their artifacts. `run_id` itself is immutable.

Reproducibility is not only about getting the same answer in one R
session. It is also about keeping the data and run artifacts that
explain where the answer came from.

## Step 10: Know The Scope

ledgr currently focuses on deterministic research backtests.

It does not include:

- live trading;
- streaming data;
- broker integrations;
- paper-trading state;
- parameter optimization;
- walk-forward testing.

Those are different systems with different state and safety
requirements. This release keeps the onboarding path focused on
backtests that can be reproduced, inspected, and audited.
