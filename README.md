
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
  instrument_id = rep("AAPL", 3),
  ts_utc = as.POSIXct(c("2020-01-01", "2020-01-02", "2020-01-03"), tz = "UTC"),
  open = c(100, 101, 102),
  high = c(101, 102, 103),
  low = c(99, 100, 101),
  close = c(101, 102, 103),
  volume = c(1000, 1000, 1000)
)

strategy <- function(ctx) {
  c(AAPL = if (ctx$bars$close[[1]] > ctx$bars$open[[1]]) 1 else 0)
}

bt <- ledgr_backtest(
  data = bars,
  strategy = strategy,
  start = "2020-01-01",
  end = "2020-01-03"
)

summary(bt)
as_tibble(bt, "equity")
```

`ledgr_backtest(data = ...)` creates and seals a snapshot behind the scenes,
then calls the same `ledgr_run()` pipeline used by explicit snapshot workflows.

## Documentation

The v0.1.2 design packet is in `inst/design/ledgr_v0_1_2_spec_packet/`.
Vignette outlines are available in `vignettes/`; full narrative content is
planned for v0.1.3.
