# ledgr v0.1.2 interactive API demo
#
# Run this file from the repository root with:
#
#   source("dev/ledgr_v0.1.2_new_api_demo.R")
#
# or run it from a terminal with:
#
#   Rscript dev/ledgr_v0.1.2_new_api_demo.R
#
# The script is intentionally verbose. The comments explain what each new
# v0.1.2 API does and why you would use it in an interactive research workflow.

suppressPackageStartupMessages({
  library(DBI)
  library(tibble)
})

cat_section <- function(title) {
  cat("\n", "==== ", title, " ====\n", sep = "")
}

find_ledgr_repo_root <- function(start) {
  cur <- normalizePath(start, winslash = "/", mustWork = TRUE)
  repeat {
    desc <- file.path(cur, "DESCRIPTION")
    if (file.exists(desc)) {
      first_line <- readLines(desc, n = 1L, warn = FALSE)
      if (length(first_line) == 1L && identical(first_line, "Package: ledgr")) {
        return(cur)
      }
    }

    parent <- dirname(cur)
    if (identical(parent, cur)) return(NULL)
    cur <- parent
  }
}

load_ledgr_for_demo <- function() {
  # Prefer the checked-out source tree when this file is run from the repo.
  # That keeps the demo aligned with your current branch without requiring
  # reinstalling the package after every edit.
  script_file <- tryCatch(
    {
      f <- sys.frames()[[1]]$ofile
      if (is.null(f)) NA_character_ else normalizePath(f, winslash = "/", mustWork = TRUE)
    },
    error = function(e) NA_character_
  )

  cmd_file <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  if (is.na(script_file) && length(cmd_file) > 0) {
    script_file <- normalizePath(sub("^--file=", "", cmd_file[[1]]), winslash = "/", mustWork = TRUE)
  }

  starts <- unique(c(
    if (!is.na(script_file)) dirname(script_file),
    getwd()
  ))

  repo_root <- NULL
  for (start in starts) {
    repo_root <- find_ledgr_repo_root(start)
    if (!is.null(repo_root)) break
  }

  if (!is.null(repo_root) && requireNamespace("pkgload", quietly = TRUE)) {
    pkgload::load_all(repo_root, quiet = TRUE)
    cat("Loaded ledgr from source tree: ", repo_root, "\n", sep = "")
    return(invisible(TRUE))
  }

  # Fallback for running the demo outside the repo after installing ledgr.
  suppressPackageStartupMessages(library(ledgr))
  cat("Loaded installed ledgr package.\n")
  invisible(TRUE)
}

load_ledgr_for_demo()

cat_section("1. Create synthetic OHLCV bars")

# v0.1.2's data-first API accepts a plain data.frame or tibble with OHLCV bars.
# The required columns are:
#
#   ts_utc, instrument_id, open, high, low, close
#
# volume is optional but useful. Timestamps can be POSIXct, Date, or accepted
# ISO strings. ledgr normalizes them to canonical UTC internally.
set.seed(20260424)
all_dates <- seq.Date(as.Date("2020-01-01"), as.Date("2020-03-31"), by = "day")
dates <- all_dates[!weekdays(all_dates) %in% c("Saturday", "Sunday")]
instruments <- c("AAA", "BBB")

make_bars_for_instrument <- function(instrument_id, base_price, drift) {
  n <- length(dates)
  returns <- stats::rnorm(n, mean = drift, sd = 0.015)
  close <- base_price * cumprod(1 + returns)
  open <- close * (1 + stats::rnorm(n, mean = 0, sd = 0.003))
  high <- pmax(open, close) * (1 + stats::runif(n, min = 0.001, max = 0.012))
  low <- pmin(open, close) * (1 - stats::runif(n, min = 0.001, max = 0.012))

  tibble::tibble(
    ts_utc = as.POSIXct(dates, tz = "UTC"),
    instrument_id = instrument_id,
    open = round(open, 4),
    high = round(high, 4),
    low = round(low, 4),
    close = round(close, 4),
    volume = round(stats::runif(n, min = 100000, max = 250000))
  )
}

bars <- rbind(
  make_bars_for_instrument("AAA", base_price = 100, drift = 0.0010),
  make_bars_for_instrument("BBB", base_price = 80, drift = -0.0002)
)

print(head(bars, 8))

# The default ledgr fill model is "next_open": a target decided at pulse t is
# filled at the next available bar. We therefore end the backtest one business
# day before the final synthetic bar so any final signal still has a next-open
# price.
backtest_start <- as.character(dates[[1]])
backtest_end <- as.character(dates[[length(dates) - 1L]])

cat_section("2. Define built-in indicators")

# Features are ledgr indicators. They are deterministic definitions that the
# engine computes at each pulse without lookahead.
#
# The built-ins used here are:
# - ledgr_ind_sma(5): a 5-bar simple moving average
# - ledgr_ind_returns(1): one-bar return
#
# The canonical feature output appears in ctx$features as a long data.frame:
#   ts_utc, instrument_id, feature_name, feature_value
#
# For interactive strategy code, v0.1.2 also exposes:
# - ctx$feature("AAA", "sma_5") for a single value lookup
# - ctx$features_wide for one row per instrument
features <- list(
  ledgr_ind_sma(5),
  ledgr_ind_returns(1)
)

cat("Feature IDs: ", paste(vapply(features, `[[`, character(1), "id"), collapse = ", "), "\n", sep = "")

cat_section("3. Write a normal R function strategy")

# A v0.1.2 functional strategy is just a function(ctx).
#
# Important contract:
# - It must return a named numeric target vector for the full universe.
# - Names must match ctx$universe exactly.
# - Values are target position quantities, not LONG/FLAT strings.
#
# The context shape is intentionally data-frame friendly:
# - ctx$bars is a data.frame with one row per instrument for the current pulse.
# - ctx$features is a data.frame with the computed indicator values.
# - ctx$feature(instrument_id, feature_name) gives a scalar feature lookup.
# - ctx$positions, ctx$cash, and ctx$equity describe current simulated state.
#
# This toy rule holds 10 shares when close is above SMA(5) and the one-bar
# return is positive. Otherwise it targets a flat position.
momentum_strategy <- function(ctx) {
  targets <- stats::setNames(rep(0, length(ctx$universe)), ctx$universe)

  for (instrument_id in ctx$universe) {
    bar <- ctx$bars[ctx$bars$instrument_id == instrument_id, , drop = FALSE]
    sma_5 <- ctx$feature(instrument_id, "sma_5")
    return_1 <- ctx$feature(instrument_id, "return_1")

    has_signal <- nrow(bar) == 1L &&
      length(sma_5) == 1L &&
      length(return_1) == 1L &&
      is.finite(sma_5) &&
      is.finite(return_1) &&
      bar$close[[1]] > sma_5 &&
      return_1 > 0

    if (isTRUE(has_signal)) {
      targets[[instrument_id]] <- 10
    }
  }

  targets
}

cat_section("4. Run the new data-first backtest API")

# This is the "no-thinking" v0.1.2 entry point:
#
#   ledgr_backtest(data = bars, strategy = ...)
#
# We do not create a DuckDB connection, snapshot, or config manually here.
# ledgr does that internally:
#
#   data.frame -> sealed snapshot -> canonical config -> ledgr_run() -> result
#
# Because db_path is omitted, ledgr creates a temporary DuckDB database. The
# resulting path is still available as bt$db_path if you want to inspect it.
bt <- ledgr_backtest(
  data = bars,
  strategy = momentum_strategy,
  start = backtest_start,
  end = backtest_end,
  initial_cash = 100000,
  features = features
)

print(bt)
cat("Run database: ", bt$db_path, "\n", sep = "")
cat("Run ID:       ", bt$run_id, "\n", sep = "")

cat_section("5. Inspect results with S3 helpers")

# print(bt) is concise. summary(bt) computes standard metrics from the DB.
#
# The object does not cache result tables. Helpers read the ledger/equity tables
# from DuckDB each time so the backtest object stays small and immutable.
summary(bt)

cat("\nThese results are meaningless; this demo validates the API, not the strategy.\n")

# Use tibble::as_tibble() to extract tidy result tables.
equity <- tibble::as_tibble(bt, what = "equity")
trades <- tibble::as_tibble(bt, what = "trades")
ledger <- tibble::as_tibble(bt, what = "ledger")

cat("\nEquity curve sample:\n")
print(head(equity, 8))

cat("\nTrades/fills sample:\n")
print(head(trades, 8))

cat("\nRaw ledger sample:\n")
print(head(ledger, 8))

cat_section("6. Plot interactively")

# plot(bt) uses ggplot2. If gridExtra is installed, ledgr shows equity and
# drawdown panels together. In non-interactive Rscript runs, we skip plotting to
# avoid creating Rplots.pdf files in the repo.
if (interactive()) {
  if (requireNamespace("ggplot2", quietly = TRUE)) {
    plot(bt)
  } else {
    message("Install ggplot2 to use plot(bt): install.packages('ggplot2')")
  }
} else {
  message("Non-interactive session: skipping plot(bt).")
}

cat_section("7. Optional explicit snapshot workflow")

# The data-first path is best for first use. For repeatable research, you may
# want to create the sealed snapshot explicitly and reuse it across runs.
#
# This still uses the same execution path after the snapshot exists.
snapshot <- ledgr_snapshot_from_df(bars)
on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

print(snapshot)

bt_from_snapshot <- ledgr_backtest(
  snapshot = snapshot,
  strategy = momentum_strategy,
  # In explicit snapshot mode, you can pass the universe yourself. If omitted,
  # v0.1.2 can infer it from snapshot instruments.
  universe = instruments,
  start = backtest_start,
  end = backtest_end,
  initial_cash = 100000,
  features = features
)

equity_from_snapshot <- tibble::as_tibble(bt_from_snapshot, what = "equity")

cat("Final equity, data-first run:      ", tail(equity$equity, 1), "\n", sep = "")
cat("Final equity, explicit snapshot:  ", tail(equity_from_snapshot$equity, 1), "\n", sep = "")

cat_section("8. Inspect a single pulse")

# ledgr_pulse_snapshot() is a read-only interactive tool. It lets you inspect
# exactly what a strategy would see at one decision point.
#
# This is useful for debugging strategy logic before running a full backtest.
pulse_ts <- bars$ts_utc[bars$instrument_id == "AAA"][20]
pulse_ctx <- ledgr_pulse_snapshot(
  snapshot = snapshot,
  universe = instruments,
  ts_utc = pulse_ts,
  features = features,
  initial_cash = 100000
)
on.exit(close(pulse_ctx), add = TRUE)

print(pulse_ctx)

cat("\nPulse bars:\n")
print(pulse_ctx$bars)

cat("\nPulse features:\n")
print(pulse_ctx$features)

cat("\nStrategy output at this pulse:\n")
print(momentum_strategy(pulse_ctx))

cat_section("9. Develop an indicator against a read-only window")

# ledgr_indicator_dev() opens a read-only development window for one instrument.
# The returned object is environment-backed and has helper methods:
#
# - dev$test(fn): run an indicator-like function against the current window
# - dev$test_dates(fn, dates): run the same function over multiple window ends
# - dev$plot(): interactively plot the close series
# - close(dev): release the dedicated snapshot connection
dev <- ledgr_indicator_dev(
  snapshot = snapshot,
  instrument_id = "AAA",
  ts_utc = pulse_ts,
  lookback = 10L
)
on.exit(close(dev), add = TRUE)

print(dev)

cat("\nIndicator dev window:\n")
print(dev$window)

cat("\nTest a custom close-range indicator on the current window:\n")
range_indicator <- function(window) {
  max(window$close) - min(window$close)
}
print(dev$test(range_indicator))

cat("\nRun that same indicator over several dates:\n")
print(dev$test_dates(range_indicator, dates = bars$ts_utc[bars$instrument_id == "AAA"][18:22]))

if (interactive()) {
  dev$plot()
}

cat_section("10. Cleanup")

# Snapshot/pulse/dev objects own lazy DuckDB connections. Explicit close calls
# make interactive Windows sessions less likely to hold file locks.
close(dev)
close(pulse_ctx)
ledgr_snapshot_close(snapshot)

cat("Data-first run DB remains available for this R session:\n")
cat(bt$db_path, "\n")

cat("\nDemo complete.\n")
