
# ledgr

ledgr is an event-sourced systematic trading framework for R. The full
arc is research, paper trading, and live trading on any device that runs
R.

In v0.1.x, ledgr covers the research side: sealed market-data snapshots,
reproducible backtests, a durable experiment store, and a TTR indicator
adapter. Paper and live trading adapters follow in later releases.

The core design premise: strategies use the same contract across
backtest, paper, and live modes. All three use the same event-sourced
ledger model, so a backtest fill and a paper trade share the same schema
and auditability guarantees. Live trading extends the event stream with
broker lifecycle events -- submissions, acknowledgments, rejections --
without changing the strategy contract.

Most backtesting tools compute results from full price arrays. ledgr
records every decision and state change as an immutable event, then
derives trades, equity, and metrics from that ledger.

``` text
data -> sealed snapshot -> pulses -> event ledger -> results
```

Results come from recorded history, not a hidden intermediate
calculation.

## Install

``` r
if (!requireNamespace("pak", quietly = TRUE)) install.packages("pak")
pak::pak("blechturm/ledgr")
```

Then attach ledgr and tibble. ledgr returns tidy tibbles for inspection,
so it fits naturally into tidyverse-style workflows without requiring
the full tidyverse in the first run.

``` r
library(ledgr)
library(tibble)
```

## First Backtest

This first run creates two synthetic instruments, defines a
target-position strategy, and runs one backtest. The data is
deliberately generated in the example so the code works in a fresh R
session without local files or network data.

First create a small OHLCV data set:

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

bars |> as_tibble() |> head(4)
#> # A tibble: 4 x 7
#>   ts_utc              instrument_id  open  high   low close volume
#>   <dttm>              <chr>         <dbl> <dbl> <dbl> <dbl>  <int>
#> 1 2020-01-01 00:00:00 AAA            100   101.  99.6  100.   1000
#> 2 2020-01-02 00:00:00 AAA            100.  101.  99.7  100.   1001
#> 3 2020-01-03 00:00:00 AAA            100.  101. 100.0  101.   1002
#> 4 2020-01-06 00:00:00 AAA            101.  101. 100.   101.   1003
```

Every ledgr strategy ultimately returns target holding amounts. This
vector:

``` r
c(AAA = 10, BBB = 0)
#> AAA BBB
#>  10   0
```

means: hold 10 units of `AAA` and 0 units of `BBB`. Names matter because
ledgr has to match each target to `ctx$universe`; values are numeric
position quantities, not labels such as `"LONG"` or `"FLAT"`.

Now define a strategy that reads the close price at the current pulse
and returns target holdings for the full universe. `ctx$targets()`
creates a flat target vector over `ctx$universe`; the strategy then
changes only the holdings it wants to own:

``` r
strategy <- function(ctx) {
  targets <- ctx$targets()

  if (ctx$close("AAA") > 100.4) {
    targets["AAA"] <- 10
  }

  if (ctx$close("BBB") > 80.0) {
    targets["BBB"] <- 5
  }

  targets
}
```

Use `ctx$current_targets()` instead when the rule should keep current
holdings unless a signal explicitly changes them.

Run the backtest:

``` r
bt <- ledgr_backtest(
  data = bars,
  strategy = strategy,
  initial_cash = 10000,
  run_id = "readme-demo"
)

bt
#> ledgr Backtest Results
#> ======================
#>
#> Run ID:         readme-demo
#> Universe:       AAA, BBB
#> Date Range:     2020-01-01T00:00:00Z to 2020-02-14T00:00:00Z
#> Initial Cash:   $10000.00
#> Final Equity:   $10436.30
#> P&L:            $436.30 (4.36%)
#>
#> Use summary(bt) for detailed metrics
#> Use plot(bt) for equity curve visualization
```

Inspect the derived results:

``` r
summary(bt)
#> ledgr Backtest Summary
#> ======================
#>
#> Performance Metrics:
#>   Total Return:        4.36%
#>   Annualized Return:   39.98%
#>   Max Drawdown:        -4.00%
#>
#> Risk Metrics:
#>   Volatility (annual): 25.60%
#>
#> Trade Statistics:
#>   Total Trades:        4
#>   Win Rate:            0.00%
#>   Avg Trade:           $-0.34
#>
#> Exposure:
#>   Time in Market:      93.94%
bt |> as_tibble(what = "trades")
#> # A tibble: 4 x 9
#>   event_seq ts_utc              instrument_id side    qty price   fee realized_pnl action
#>       <int> <dttm>              <chr>         <chr> <dbl> <dbl> <dbl>        <dbl> <chr>
#> 1         1 2020-01-03 00:00:00 AAA           BUY      10 100.      0         0    OPEN
#> 2         2 2020-01-07 00:00:00 BBB           BUY       5  80.2     0         0    OPEN
#> 3         3 2020-01-13 00:00:00 BBB           SELL      5  80.0     0        -1.35 CLOSE
#> 4         4 2020-01-14 00:00:00 BBB           BUY       5  80.8     0         0    OPEN
```

The numbers come from generated toy data. They validate the API path,
not the strategy. Exact printed values can change after intentional
engine changes. The important invariant is not the exact toy numbers; it
is that the same data and same strategy produce the same ledger and
equity curve.

## Why ledgr?

Most backtesting tools assume reproducibility. ledgr makes it testable.

- Same data and the same strategy produce identical normalized ledger
  and equity outputs.
- All reported results come from the event ledger.
- Sealed snapshot hashes let you detect when the input data changed.

This matters because research often gets revisited months later. ledgr
gives you a way to prove which data and strategy produced the result you
are looking at.

Many tools compute results from full price arrays. ledgr follows the
sequential process more closely:

- new data arrives;
- the strategy sees one decision point in time, called a pulse;
- positions and cash can change;
- the system moves forward.

At each pulse, the strategy only sees data available at that timestamp.
Every state change is recorded as an event. The ledger is the source of
truth; trades, equity, and metrics are derived views of that ledger.

The first call to `ledgr_backtest(data = bars, ...)` created a sealed
snapshot, then called the same canonical engine used by explicit
snapshot workflows. We seal this data so you cannot accidentally lie to
your future self.

The quick ledger/equity count below confirms that the visible result is
backed by recorded events and derived equity rows.

``` r
c(
  ledger_rows = nrow(bt |> as_tibble(what = "ledger")),
  equity_rows = nrow(bt |> as_tibble(what = "equity"))
)
#> ledger_rows equity_rows
#>           4          33
```

## Trust Check: Determinism (Optional But Important)

``` r
normalize_result <- function(x) {
  if ("run_id" %in% names(x)) x$run_id <- NULL
  if ("event_id" %in% names(x)) x$event_id <- NULL

  x[] <- lapply(x, function(col) {
    if (inherits(col, "POSIXt")) {
      format(as.POSIXct(col, tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
    } else if (is.numeric(col)) {
      round(col, 10)
    } else {
      col
    }
  })

  row.names(x) <- NULL
  x
}

run_once <- function(run_id) {
  bt <- ledgr_backtest(
    data = bars,
    strategy = strategy,
    initial_cash = 10000,
    run_id = run_id
  )

  list(
    ledger = normalize_result(bt |> as_tibble(what = "ledger")),
    equity = normalize_result(bt |> as_tibble(what = "equity"))
  )
}

run_a <- run_once("readme-a")
run_b <- run_once("readme-b")

c(
  same_ledger = identical(run_a$ledger, run_b$ledger),
  same_equity = identical(run_a$equity, run_b$equity)
)
#> same_ledger same_equity
#>        TRUE        TRUE
```

The two runs use different run identifiers and different temporary
databases. After identity columns are removed, the ledger and equity
curve match exactly. That is the ledgr difference: replay is testable
instead of assumed. If the sealed input data changes, the snapshot hash
changes with it.

## What To Try Next

Good next edits are small and observable:

- change the `AAA` or `BBB` target quantities in `strategy()`;
- change the threshold values that trigger a position;
- add an indicator such as `ledgr_ind_sma(5)`;
- inspect a single decision point with `ledgr_pulse_snapshot()`.

## Documentation

``` r
help(package = "ledgr")
utils::packageDescription("ledgr")[c("Package", "Version", "Title")]
```

The v0.1.3 design packet is in `inst/design/ledgr_v0_1_3_spec_packet/`.
The v0.1.2 packet records the engine and UX foundation this release
builds on.
