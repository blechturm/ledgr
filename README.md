
# ledgr

ledgr is a correctness-first R backtesting package for deterministic research
workflows. It turns bar data into sealed snapshots, runs one canonical
event-sourced engine, and derives results from the ledger.

ledgr is not a live-trading system, broker adapter, or optimization framework.

## Installation

ledgr is not on CRAN yet. For local development:

```r
pak::pak("maxthomasberger/ledgr")
```

or from a checked-out repository:

```r
devtools::install()
```

## Quickstart

```r
library(ledgr)

bars <- tibble::tibble(
  instrument_id = "AAPL",
  ts_utc = as.POSIXct(c("2020-01-02", "2020-01-03", "2020-01-06", "2020-01-07", "2020-01-08"), tz = "UTC"),
  open = c(100, 101, 102, 101, 103),
  high = c(101, 102, 103, 104, 105),
  low = c(99, 100, 100, 100, 102),
  close = c(101, 102, 101, 103, 104),
  volume = c(1000, 1100, 1050, 1200, 1300)
)

strategy <- function(ctx) {
  c(AAPL = if (ctx$bars$close[[1]] > ctx$bars$open[[1]]) 1 else 0)
}

bt <- ledgr_backtest(
  data = bars,
  strategy = strategy,
  start = "2020-01-02",
  end = "2020-01-07"
)

summary(bt)
tibble::as_tibble(bt, what = "equity")
```

`ledgr_backtest(data = ...)` creates and seals a snapshot behind the scenes,
then calls the same `ledgr_run()` pipeline used by explicit snapshot workflows.
For a fuller interactive walkthrough, see `dev/ledgr_v0.1.2_new_api_demo.R`.

## Documentation

The v0.1.2 design packet is in `inst/design/ledgr_v0_1_2_spec_packet/`.
Vignette outlines are available in `vignettes/`; full narrative content is
planned for v0.1.3.
