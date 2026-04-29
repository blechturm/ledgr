ledgr_test_ttr_cases <- function() {
  list(
    list(fn = "RSI", input = "close", output = NULL, args = list(n = 14), requires_bars = 15L, id = "ttr_rsi_14"),
    list(fn = "SMA", input = "close", output = NULL, args = list(n = 20), requires_bars = 20L, id = "ttr_sma_20"),
    list(fn = "EMA", input = "close", output = NULL, args = list(n = 20), requires_bars = 20L, id = "ttr_ema_20"),
    list(fn = "ATR", input = "hlc", output = "atr", args = list(n = 20), requires_bars = 21L, id = "ttr_atr_20_atr"),
    list(fn = "MACD", input = "close", output = "macd", args = list(nFast = 12, nSlow = 26, nSig = 9), requires_bars = 26L, id = "ttr_macd_12_26_9_macd"),
    list(fn = "WMA", input = "close", output = NULL, args = list(n = 10), requires_bars = 10L, id = "ttr_wma_10"),
    list(fn = "ROC", input = "close", output = NULL, args = list(n = 10), requires_bars = 11L, id = "ttr_roc_10"),
    list(fn = "momentum", input = "close", output = NULL, args = list(n = 10), requires_bars = 11L, id = "ttr_momentum_10"),
    list(fn = "CCI", input = "hlc", output = NULL, args = list(n = 20), requires_bars = 20L, id = "ttr_cci_20"),
    list(fn = "BBands", input = "close", output = "up", args = list(n = 20), requires_bars = 20L, id = "ttr_bbands_20_up"),
    list(fn = "aroon", input = "hl", output = "oscillator", args = list(n = 20), requires_bars = 20L, id = "ttr_aroon_20_oscillator"),
    list(fn = "DonchianChannel", input = "hl", output = "mid", args = list(n = 20), requires_bars = 20L, id = "ttr_donchianchannel_20_mid"),
    list(fn = "MFI", input = "hlcv", output = NULL, args = list(n = 14), requires_bars = 15L, id = "ttr_mfi_14"),
    list(fn = "CMF", input = "hlcv", output = NULL, args = list(n = 20), requires_bars = 20L, id = "ttr_cmf_20"),
    list(fn = "runMean", input = "close", output = NULL, args = list(n = 20), requires_bars = 20L, id = "ttr_runmean_20"),
    list(fn = "runSD", input = "close", output = NULL, args = list(n = 20), requires_bars = 20L, id = "ttr_runsd_20"),
    list(fn = "runVar", input = "close", output = NULL, args = list(n = 20), requires_bars = 20L, id = "ttr_runvar_20"),
    list(fn = "runMAD", input = "close", output = NULL, args = list(n = 20), requires_bars = 20L, id = "ttr_runmad_20")
  )
}

ledgr_test_ttr_bars <- function(n = 80L) {
  x <- seq_len(n)
  data.frame(
    ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * (x - 1L),
    instrument_id = "AAA",
    open = 100 + x,
    high = 101 + x,
    low = 99 + x,
    close = 100 + x,
    volume = 1000 + x
  )
}

ledgr_test_ind_ttr_from_case <- function(case) {
  do.call(
    ledgr_ind_ttr,
    c(list(case$fn, input = case$input, output = case$output), case$args)
  )
}

testthat::test_that("TTR warmup rules table has the documented schema", {
  rules <- ledgr_ttr_warmup_rules()

  testthat::expect_s3_class(rules, "data.frame")
  testthat::expect_true(all(c("ttr_fn", "input", "formula", "required_args", "id_args") %in% names(rules)))
  testthat::expect_true(is.list(rules$required_args))
  testthat::expect_true(is.list(rules$id_args))
  expected <- unique(vapply(ledgr_test_ttr_cases(), `[[`, character(1), "fn"))
  testthat::expect_setequal(rules$ttr_fn, expected)
})

testthat::test_that("ledgr_ind_ttr constructs known indicators with deterministic IDs", {
  testthat::skip_if_not_installed("TTR")

  rsi <- ledgr_ind_ttr("RSI", input = "close", n = 14)
  atr <- ledgr_ind_ttr("ATR", input = "hlc", output = "atr", n = 20)
  macd <- ledgr_ind_ttr("MACD", input = "close", output = "macd", nFast = 12, nSlow = 26, nSig = 9)

  testthat::expect_s3_class(rsi, "ledgr_indicator")
  testthat::expect_s3_class(atr, "ledgr_indicator")
  testthat::expect_s3_class(macd, "ledgr_indicator")
  testthat::expect_identical(rsi$id, "ttr_rsi_14")
  testthat::expect_identical(atr$id, "ttr_atr_20_atr")
  testthat::expect_identical(macd$id, "ttr_macd_12_26_9_macd")
  testthat::expect_identical(rsi$params$args, list(n = 14))
  testthat::expect_identical(atr$params$input, "hlc")
  testthat::expect_true(nzchar(atr$params$ttr_version))

  wma <- ledgr_ind_ttr("WMA", input = "close", n = 10)
  bbands <- ledgr_ind_ttr("BBands", input = "close", output = "up", n = 20)
  wide_bbands <- ledgr_ind_ttr("BBands", input = "close", output = "up", n = 20, sd = 3)
  testthat::expect_identical(wma$id, "ttr_wma_10")
  testthat::expect_identical(bbands$id, "ttr_bbands_20_up")
  testthat::expect_identical(wide_bbands$id, "ttr_bbands_20_3_up")
})

testthat::test_that("TTR input builders use TTR-compatible column names", {
  bars <- data.frame(
    open = 1:3,
    high = 2:4,
    low = 0:2,
    close = 1:3,
    volume = 10:12
  )

  testthat::expect_identical(colnames(ledgr:::ledgr_ttr_build_input(bars, "hl")), c("High", "Low"))
  testthat::expect_identical(colnames(ledgr:::ledgr_ttr_build_input(bars, "hlc")), c("High", "Low", "Close"))
  testthat::expect_identical(colnames(ledgr:::ledgr_ttr_build_input(bars, "ohlc")), c("Open", "High", "Low", "Close"))
  testthat::expect_identical(colnames(ledgr:::ledgr_ttr_build_input(bars, "hlcv")), c("High", "Low", "Close", "Volume"))
})

testthat::test_that("TTR constructor errors are actionable", {
  testthat::skip_if_not_installed("TTR")

  testthat::expect_error(
    ledgr_ind_ttr("RSI", input = "close"),
    "requires explicit `n`",
    class = "ledgr_invalid_args"
  )
  testthat::expect_error(
    ledgr_ind_ttr("BBands", input = "close", output = "up"),
    "requires explicit `n`",
    class = "ledgr_invalid_args"
  )
  testthat::expect_error(
    ledgr_ind_ttr("DEMA", input = "close", n = 10),
    "count the leading NA",
    class = "ledgr_invalid_args"
  )
  testthat::expect_error(
    ledgr_ind_ttr("RSI", input = "hlc", n = 14),
    "does not support input = \"hlc\"",
    class = "ledgr_invalid_args"
  )
  testthat::expect_error(
    ledgr_ind_ttr("aroon", input = "hlc", output = "oscillator", n = 20),
    "does not support input = \"hlc\"",
    class = "ledgr_invalid_args"
  )
  testthat::expect_error(
    ledgr_ind_ttr("ATR", input = "hlc", n = 20),
    "Available outputs: tr, atr, trueHigh, trueLow",
    class = "ledgr_invalid_args"
  )
  testthat::expect_error(
    ledgr_ind_ttr("ATR", input = "hlc", output = "missing", n = 20),
    "Available outputs: tr, atr, trueHigh, trueLow",
    class = "ledgr_invalid_args"
  )
})

testthat::test_that("unknown TTR functions can be used with explicit warmup", {
  testthat::skip_if_not_installed("TTR")

  ind <- ledgr_ind_ttr("WMA", input = "close", n = 10, requires_bars = 10)
  testthat::expect_s3_class(ind, "ledgr_indicator")
  testthat::expect_identical(ind$id, "ttr_wma_10")
  testthat::expect_identical(ind$requires_bars, 10L)
})

testthat::test_that("TTR warmup inference is implemented for every rules-table entry", {
  for (case in ledgr_test_ttr_cases()) {
    testthat::expect_identical(
      ledgr:::ledgr_ttr_infer_requires_bars(case$fn, case$args, output = case$output),
      case$requires_bars
    )
  }
  macd_args <- list(nFast = 12, nSlow = 26, nSig = 9)
  testthat::expect_identical(
    ledgr:::ledgr_ttr_infer_requires_bars("MACD", macd_args, output = "signal"),
    34L
  )
  testthat::expect_identical(
    ledgr:::ledgr_ttr_infer_requires_bars("MACD", macd_args, output = "histogram"),
    34L
  )
})

testthat::test_that("TTR series_fn normalizes warmup at inferred requires_bars", {
  testthat::skip_if_not_installed("TTR")

  bars <- ledgr_test_ttr_bars()
  indicators <- lapply(ledgr_test_ttr_cases(), ledgr_test_ind_ttr_from_case)

  for (ind in indicators) {
    values <- ledgr:::ledgr_compute_feature_series(bars, ind)
    first_valid <- which(!is.na(values))[1]
    testthat::expect_identical(first_valid, ind$requires_bars)
    testthat::expect_length(values, nrow(bars))
    testthat::expect_equal(ind$fn(bars), utils::tail(values, 1), tolerance = 1e-12)
  }
})

testthat::test_that("TTR warmup rules match direct TTR output", {
  testthat::skip_if_not_installed("TTR")

  bars <- ledgr_test_ttr_bars()

  for (case in ledgr_test_ttr_cases()) {
    params <- list(
      ttr_fn = case$fn,
      ttr_version = as.character(utils::packageVersion("TTR")),
      input = case$input,
      output = case$output,
      args = case$args
    )
    values_from_ttr <- ledgr:::ledgr_ttr_call(bars, params)
    first_valid_from_ttr <- min(which(!is.na(values_from_ttr)))
    ind <- ledgr_test_ind_ttr_from_case(case)
    testthat::expect_identical(first_valid_from_ttr, ind$requires_bars)
  }

  macd_args <- list(nFast = 12, nSlow = 26, nSig = 9)
  for (output in c("signal", "histogram")) {
    params <- list(
      ttr_fn = "MACD",
      ttr_version = as.character(utils::packageVersion("TTR")),
      input = "close",
      output = output,
      args = macd_args
    )
    values_from_ttr <- ledgr:::ledgr_ttr_call(bars, params)
    first_valid_from_ttr <- min(which(!is.na(values_from_ttr)))
    ind <- ledgr_ind_ttr(
      "MACD",
      input = "close",
      output = output,
      nFast = macd_args$nFast,
      nSlow = macd_args$nSlow,
      nSig = macd_args$nSig
    )
    testthat::expect_identical(first_valid_from_ttr, ind$requires_bars)
  }
})

testthat::test_that("TTR fingerprint includes TTR version metadata", {
  testthat::skip_if_not_installed("TTR")

  ind_a <- ledgr_ind_ttr("RSI", input = "close", n = 14)
  ind_b <- ind_a
  ind_b$params$ttr_version <- paste0(ind_a$params$ttr_version, "-changed")

  testthat::expect_false(identical(
    ledgr:::ledgr_indicator_fingerprint(ind_a),
    ledgr:::ledgr_indicator_fingerprint(ind_b)
  ))
})

testthat::test_that("TTR indicators use series_fn during backtest feature precomputation", {
  testthat::skip_if_not_installed("TTR")

  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)
  ledgr_clear_feature_cache()
  on.exit(ledgr_clear_feature_cache(), add = TRUE)

  snap <- ledgr_snapshot_from_df(test_bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snap), add = TRUE)

  ind <- ledgr_ind_ttr("RSI", input = "close", n = 3)
  ind$fn <- function(window, params) {
    stop("backtest precomputation should use series_fn for TTR indicators")
  }
  strategy <- function(ctx, params) ctx$flat()

  bt <- ledgr_backtest(
    snapshot = snap,
    strategy = strategy,
    universe = c("TEST_A", "TEST_B"),
    start = "2020-01-01",
    end = "2020-01-10",
    features = list(ind),
    db_path = db_path
  )
  on.exit(close(bt), add = TRUE)

  features <- DBI::dbGetQuery(
    ledgr:::get_connection(bt),
    "SELECT DISTINCT feature_name FROM features WHERE run_id = ?",
    params = list(bt$run_id)
  )
  testthat::expect_true(ind$id %in% features$feature_name)
})
