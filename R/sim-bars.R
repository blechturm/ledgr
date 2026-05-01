#' Simulate deterministic synthetic OHLCV bars
#'
#' Creates reproducible synthetic daily bars for examples, documentation, and
#' local experimentation. The generator uses a simple log-return process with
#' instrument-specific drift and volatility, overnight gaps, and intraday high
#' and low ranges. It uses only base R and does not access the network.
#'
#' @param n_instruments Number of synthetic instruments.
#' @param n_days Number of business-day bars per instrument.
#' @param seed Random seed used for deterministic generation.
#' @param start First calendar date considered for the business-day sequence.
#' @param instrument_prefix Prefix used for generated instrument IDs.
#' @return A tibble with `ts_utc`, `instrument_id`, `open`, `high`, `low`,
#'   `close`, and `volume` columns suitable for `ledgr_snapshot_from_df()`.
#' @examples
#' bars <- ledgr_sim_bars(n_instruments = 3, n_days = 20, seed = 1)
#' head(bars)
#' @export
ledgr_sim_bars <- function(n_instruments = 10L,
                           n_days = 252L * 5L,
                           seed = 1L,
                           start = "2018-01-01",
                           instrument_prefix = "DEMO_") {
  n_instruments <- ledgr_sim_positive_integer(n_instruments, "n_instruments")
  n_days <- ledgr_sim_positive_integer(n_days, "n_days")
  seed <- ledgr_sim_integer_scalar(seed, "seed")
  start <- ledgr_sim_date(start)
  if (!is.character(instrument_prefix) || length(instrument_prefix) != 1L ||
    is.na(instrument_prefix) || !nzchar(instrument_prefix)) {
    rlang::abort("`instrument_prefix` must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }

  had_seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  old_seed <- if (had_seed) get(".Random.seed", envir = .GlobalEnv, inherits = FALSE) else NULL
  on.exit({
    if (had_seed) {
      assign(".Random.seed", old_seed, envir = .GlobalEnv)
    } else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
      rm(".Random.seed", envir = .GlobalEnv)
    }
  }, add = TRUE)
  set.seed(seed)

  dates <- ledgr_sim_business_days(start, n_days)
  market_shock <- stats::rnorm(n_days, mean = 0.0002, sd = 0.008)

  rows <- vector("list", n_instruments)
  for (i in seq_len(n_instruments)) {
    inst <- sprintf("%s%02d", instrument_prefix, i)
    base_price <- 50 + 5 * i
    drift <- 0.00012 + (i - (n_instruments + 1) / 2) * 0.000004
    vol <- 0.010 + (i %% 5) * 0.0015

    close_return <- drift + 0.45 * market_shock + stats::rnorm(n_days, mean = 0, sd = vol)
    close <- base_price * exp(cumsum(close_return))
    previous_close <- c(base_price, close[-n_days])
    open <- previous_close * exp(stats::rnorm(n_days, mean = 0, sd = vol * 0.25))
    high <- pmax(open, close) * (1 + abs(stats::rnorm(n_days, mean = 0.0025, sd = vol * 0.35)))
    low <- pmin(open, close) * (1 - abs(stats::rnorm(n_days, mean = 0.0025, sd = vol * 0.35)))
    low <- pmax(low, 0.01)
    volume <- pmax(1, round(stats::rnorm(n_days, mean = 500000 + i * 25000, sd = 80000)))

    rows[[i]] <- data.frame(
      ts_utc = as.POSIXct(dates, tz = "UTC"),
      instrument_id = inst,
      open = as.numeric(open),
      high = as.numeric(high),
      low = as.numeric(low),
      close = as.numeric(close),
      volume = as.numeric(volume),
      stringsAsFactors = FALSE
    )
  }

  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  tibble::as_tibble(out)
}

ledgr_sim_positive_integer <- function(x, arg) {
  value <- ledgr_sim_integer_scalar(x, arg)
  if (value < 1L) {
    rlang::abort(sprintf("`%s` must be >= 1.", arg), class = "ledgr_invalid_args")
  }
  value
}

ledgr_sim_integer_scalar <- function(x, arg) {
  if (!is.numeric(x) || length(x) != 1L || is.na(x) || !is.finite(x) || x != as.integer(x)) {
    rlang::abort(sprintf("`%s` must be a finite integer scalar.", arg), class = "ledgr_invalid_args")
  }
  as.integer(x)
}

ledgr_sim_date <- function(x) {
  out <- tryCatch(as.Date(x), error = function(e) NA)
  if (length(out) != 1L || is.na(out)) {
    rlang::abort("`start` must be coercible to a single Date.", class = "ledgr_invalid_args")
  }
  out
}

ledgr_sim_business_days <- function(start, n_days) {
  calendar_days <- seq.Date(start, by = "day", length.out = ceiling(n_days * 1.6) + 14L)
  wday <- as.POSIXlt(calendar_days, tz = "UTC")$wday
  business_days <- calendar_days[!wday %in% c(0L, 6L)]
  if (length(business_days) < n_days) {
    rlang::abort("Internal simulator error: not enough generated business days.", class = "ledgr_internal_error")
  }
  business_days[seq_len(n_days)]
}
