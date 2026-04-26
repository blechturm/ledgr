# Benchmark LDG-712 indicator series_fn performance
#
# Run from the repository root with:
#
#   Rscript dev/benchmark_ldg_712_indicator_series_fn.R
#
# The script compares a custom ATR-style indicator using the legacy scalar
# fn-only path against the vectorized series_fn path added in v0.1.4.

suppressPackageStartupMessages({
  library(tibble)
})

load_ledgr_for_benchmark <- function() {
  desc <- file.path(getwd(), "DESCRIPTION")
  is_ledgr_repo <- file.exists(desc) &&
    any(readLines(desc, warn = FALSE) == "Package: ledgr")

  if (is_ledgr_repo && requireNamespace("pkgload", quietly = TRUE)) {
    pkgload::load_all(".", quiet = TRUE)
    return(invisible(TRUE))
  }

  suppressPackageStartupMessages(library(ledgr))
  invisible(TRUE)
}

load_ledgr_for_benchmark()

business_days <- function(start, end) {
  days <- seq.Date(as.Date(start), as.Date(end), by = "day")
  days[!weekdays(days) %in% c("Saturday", "Sunday")]
}

make_bars <- function() {
  set.seed(712)
  dates <- business_days("2019-01-01", "2023-12-31")
  n <- length(dates)
  returns <- stats::rnorm(n, mean = 0.0002, sd = 0.012)
  close <- 100 * cumprod(1 + returns)
  open <- close * (1 + stats::rnorm(n, sd = 0.002))
  high <- pmax(open, close) * (1 + stats::runif(n, 0.001, 0.01))
  low <- pmin(open, close) * (1 - stats::runif(n, 0.001, 0.01))

  tibble(
    ts_utc = as.POSIXct(dates, tz = "UTC"),
    instrument_id = "AAA",
    open = open,
    high = high,
    low = low,
    close = close,
    volume = 100000
  )
}

rolling_mean <- function(x, n) {
  out <- rep(NA_real_, length(x))
  if (length(x) < n) return(out)
  cs <- c(0, cumsum(x))
  idx <- n:length(x)
  out[idx] <- (cs[idx + 1L] - cs[idx - n + 1L]) / n
  out
}

atr_series_base <- function(bars, n) {
  high <- as.numeric(bars$high)
  low <- as.numeric(bars$low)
  close <- as.numeric(bars$close)
  prev_close <- c(NA_real_, close[-length(close)])
  tr <- pmax(
    high - low,
    abs(high - prev_close),
    abs(low - prev_close),
    na.rm = TRUE
  )
  rolling_mean(tr, n)
}

atr_series <- function(bars, params) {
  n <- as.integer(params$n)
  atr_series_base(bars, n)
}

atr_latest <- function(window, params) {
  values <- atr_series(window, params)
  utils::tail(values, 1)
}

make_strategy <- function(feature_id) {
  force(feature_id)
  function(ctx) {
    value <- ctx$feature("AAA", feature_id)
    if (!is.na(value) && value < 0) {
      stop("ATR cannot be negative")
    }
    ctx$targets()
  }
}

time_expr <- function(expr) {
  gc()
  elapsed <- system.time(force(expr))[["elapsed"]]
  as.numeric(elapsed)
}

legacy_expanding_series <- function(bars, fn, params, stable_after) {
  out <- rep(NA_real_, nrow(bars))
  calls <- 0L
  for (i in seq_len(nrow(bars))) {
    if (i < stable_after) next
    calls <- calls + 1L
    out[[i]] <- fn(bars[seq_len(i), , drop = FALSE], params)
  }
  list(values = out, calls = calls)
}

bars <- make_bars()
params <- list(n = 20L)
reps <- as.integer(Sys.getenv("LEDGR_BENCH_REPS", "3"))
if (is.na(reps) || reps < 1L) reps <- 3L

fn_calls <- new.env(parent = emptyenv())
fn_calls$n <- 0L
series_calls <- new.env(parent = emptyenv())
series_calls$n <- 0L

fn_only_indicator <- ledgr_indicator(
  id = "atr20_fn_only",
  fn = function(window, params) {
    fn_calls$n <- fn_calls$n + 1L
    atr_latest(window, params)
  },
  requires_bars = 21L,
  stable_after = 21L,
  params = params
)

series_indicator <- ledgr_indicator(
  id = "atr20_series_fn",
  fn = function(window, params) {
    stop("series_fn benchmark unexpectedly used fallback fn")
  },
  series_fn = function(bars, params) {
    series_calls$n <- series_calls$n + 1L
    atr_series(bars, params)
  },
  requires_bars = 21L,
  stable_after = 21L,
  params = params
)

cat("LDG-712 indicator benchmark\n")
cat("===========================\n")
cat("Rows: ", nrow(bars), "\n", sep = "")
cat("Indicator: ATR20-style rolling true range via base R\n")

feature_fn_time <- time_expr({
  values_fn <- ledgr:::ledgr_compute_feature_series(bars, fn_only_indicator)
})

feature_series_time <- time_expr({
  values_series <- ledgr:::ledgr_compute_feature_series(bars, series_indicator)
})

legacy_time <- time_expr({
  legacy <- legacy_expanding_series(bars, atr_latest, params, stable_after = 21L)
})

cat("\nFeature precompute only\n")
cat("-----------------------\n")
cat(sprintf("legacy expanding:    %.3fs (%d fn calls)\n", legacy_time, legacy$calls))
cat(sprintf("fn-only elapsed:     %.3fs (%d fn calls)\n", feature_fn_time, fn_calls$n))
cat(sprintf("series_fn elapsed:   %.3fs (%d series_fn calls)\n", feature_series_time, series_calls$n))
cat(sprintf("bounded/legacy:      %.2fx\n", feature_fn_time / max(legacy_time, .Machine$double.eps)))
cat(sprintf("series/legacy:       %.2fx\n", feature_series_time / max(legacy_time, .Machine$double.eps)))
cat("same non-warmup values: ", isTRUE(all.equal(values_fn, values_series, tolerance = 1e-10, check.attributes = FALSE)), "\n", sep = "")

run_backtest_once <- function(indicator, run_id) {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  bt <- ledgr_backtest(
    data = bars,
    strategy = make_strategy(indicator$id),
    start = min(bars$ts_utc),
    end = max(bars$ts_utc),
    initial_cash = 10000,
    run_id = run_id,
    features = list(indicator),
    persist_features = FALSE,
    db_path = db_path
  )
  on.exit(close(bt), add = TRUE)

  invisible(bt$run_id)
}

benchmark_backtest <- function(indicator, run_id_prefix, reps) {
  times <- numeric(reps)
  for (i in seq_len(reps)) {
    times[[i]] <- time_expr(run_backtest_once(indicator, paste0(run_id_prefix, "-", i)))
  }
  list(times = times, median = stats::median(times))
}

fn_calls$n <- 0L
series_calls$n <- 0L

bt_fn <- benchmark_backtest(fn_only_indicator, "ldg-712-fn-only", reps)
bt_series <- benchmark_backtest(series_indicator, "ldg-712-series-fn", reps)

cat("\nEnd-to-end backtest\n")
cat("-------------------\n")
cat("persist_features:    FALSE\n")
cat(sprintf("repetitions:         %d\n", reps))
cat(sprintf("fn-only median:      %.3fs (%d fn calls total)\n", bt_fn$median, fn_calls$n))
cat(sprintf("series_fn median:    %.3fs (%d series_fn calls total)\n", bt_series$median, series_calls$n))
cat(sprintf("series/fn ratio:     %.2fx\n", bt_series$median / max(bt_fn$median, .Machine$double.eps)))
cat(sprintf("fn-only samples:     %s\n", paste(sprintf("%.3f", bt_fn$times), collapse = ", ")))
cat(sprintf("series_fn samples:   %s\n", paste(sprintf("%.3f", bt_series$times), collapse = ", ")))

cat("\nInterpretation\n")
cat("--------------\n")
cat("The series_fn path should call the custom indicator once per instrument,\n")
cat("while the fn-only fallback calls once per post-warmup pulse with bounded\n")
cat("windows. End-to-end timings include runner and DuckDB overhead; the feature\n")
cat("precompute section isolates the LDG-712 performance fix. LDG-713 will\n")
cat("address reuse across repeated parameter sweeps.\n")
