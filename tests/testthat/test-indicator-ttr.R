testthat::test_that("TTR warmup rules table has the documented schema", {
  rules <- ledgr_ttr_warmup_rules()

  testthat::expect_s3_class(rules, "data.frame")
  testthat::expect_true(all(c("ttr_fn", "input", "formula", "required_args", "id_args") %in% names(rules)))
  testthat::expect_true(is.list(rules$required_args))
  testthat::expect_true(is.list(rules$id_args))
  testthat::expect_true(all(c("RSI", "SMA", "EMA", "ATR", "MACD") %in% rules$ttr_fn))
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
})

testthat::test_that("TTR input builders use TTR-compatible column names", {
  bars <- data.frame(
    open = 1:3,
    high = 2:4,
    low = 0:2,
    close = 1:3,
    volume = 10:12
  )

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
    ledgr_ind_ttr("WMA", input = "close", n = 10),
    "count the leading NA",
    class = "ledgr_invalid_args"
  )
  testthat::expect_error(
    ledgr_ind_ttr("RSI", input = "hlc", n = 14),
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
  args_by_fn <- list(
    RSI = list(n = 14),
    SMA = list(n = 20),
    EMA = list(n = 20),
    ATR = list(n = 20),
    MACD = list(nFast = 12, nSlow = 26, nSig = 9)
  )
  expected_by_fn <- list(
    RSI = 15L,
    SMA = 20L,
    EMA = 20L,
    ATR = 21L,
    MACD = 26L
  )

  rules <- ledgr_ttr_warmup_rules()
  for (i in seq_len(nrow(rules))) {
    fn <- rules$ttr_fn[[i]]
    testthat::expect_identical(
      ledgr:::ledgr_ttr_infer_requires_bars(fn, args_by_fn[[fn]]),
      expected_by_fn[[fn]]
    )
  }
  testthat::expect_identical(
    ledgr:::ledgr_ttr_infer_requires_bars("MACD", args_by_fn$MACD, output = "signal"),
    34L
  )
  testthat::expect_identical(
    ledgr:::ledgr_ttr_infer_requires_bars("MACD", args_by_fn$MACD, output = "histogram"),
    34L
  )
})

testthat::test_that("TTR series_fn normalizes warmup at inferred requires_bars", {
  testthat::skip_if_not_installed("TTR")

  bars <- data.frame(
    ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:79,
    instrument_id = "AAA",
    open = 100 + seq_len(80),
    high = 101 + seq_len(80),
    low = 99 + seq_len(80),
    close = 100 + seq_len(80),
    volume = 1000 + seq_len(80)
  )
  args_by_fn <- list(
    RSI = list(n = 14),
    SMA = list(n = 20),
    EMA = list(n = 20),
    ATR = list(n = 20),
    MACD = list(nFast = 12, nSlow = 26, nSig = 9)
  )
  output_by_fn <- list(
    RSI = NULL,
    SMA = NULL,
    EMA = NULL,
    ATR = "atr",
    MACD = "macd"
  )
  rules <- ledgr_ttr_warmup_rules()
  indicators <- lapply(seq_len(nrow(rules)), function(i) {
    fn <- rules$ttr_fn[[i]]
    do.call(
      ledgr_ind_ttr,
      c(
        list(fn, input = rules$input[[i]], output = output_by_fn[[fn]]),
        args_by_fn[[fn]]
      )
    )
  })

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

  bars <- data.frame(
    ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:79,
    instrument_id = "AAA",
    open = 100 + seq_len(80),
    high = 101 + seq_len(80),
    low = 99 + seq_len(80),
    close = 100 + seq_len(80),
    volume = 1000 + seq_len(80)
  )
  args_by_fn <- list(
    RSI = list(n = 14),
    SMA = list(n = 20),
    EMA = list(n = 20),
    ATR = list(n = 20),
    MACD = list(nFast = 12, nSlow = 26, nSig = 9)
  )
  output_by_fn <- list(
    RSI = NULL,
    SMA = NULL,
    EMA = NULL,
    ATR = "atr",
    MACD = "macd"
  )
  rules <- ledgr_ttr_warmup_rules()

  for (i in seq_len(nrow(rules))) {
    fn <- rules$ttr_fn[[i]]
    params <- list(
      ttr_fn = fn,
      ttr_version = as.character(utils::packageVersion("TTR")),
      input = rules$input[[i]],
      output = output_by_fn[[fn]],
      args = args_by_fn[[fn]]
    )
    values_from_ttr <- ledgr:::ledgr_ttr_call(bars, params)
    first_valid_from_ttr <- min(which(!is.na(values_from_ttr)))
    ind <- do.call(
      ledgr_ind_ttr,
      c(
        list(fn, input = rules$input[[i]], output = output_by_fn[[fn]]),
        args_by_fn[[fn]]
      )
    )
    testthat::expect_identical(first_valid_from_ttr, ind$requires_bars)
  }

  for (output in c("signal", "histogram")) {
    params <- list(
      ttr_fn = "MACD",
      ttr_version = as.character(utils::packageVersion("TTR")),
      input = "close",
      output = output,
      args = args_by_fn$MACD
    )
    values_from_ttr <- ledgr:::ledgr_ttr_call(bars, params)
    first_valid_from_ttr <- min(which(!is.na(values_from_ttr)))
    ind <- ledgr_ind_ttr(
      "MACD",
      input = "close",
      output = output,
      nFast = 12,
      nSlow = 26,
      nSig = 9
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
  strategy <- function(ctx) ctx$targets()

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
