ledgr_test_ttr_cases <- function() {
  list(
    list(fn = "RSI", input = "close", output = NULL, args = list(n = 14), requires_bars = 15L, id = "ttr_rsi_14"),
    list(fn = "SMA", input = "close", output = NULL, args = list(n = 20), requires_bars = 20L, id = "ttr_sma_20"),
    list(fn = "EMA", input = "close", output = NULL, args = list(n = 20), requires_bars = 20L, id = "ttr_ema_20"),
    list(fn = "ATR", input = "hlc", output = "atr", args = list(n = 20), requires_bars = 21L, id = "ttr_atr_20_atr"),
    list(fn = "MACD", input = "close", output = "macd", args = list(nFast = 12, nSlow = 26, nSig = 9), requires_bars = 34L, id = "ttr_macd_12_26_9_macd"),
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

ledgr_test_ttr_parity_cases <- function() {
  single_output <- ledgr_test_ttr_cases()
  multi_output <- list(
    list(fn = "ATR", input = "hlc", output = "tr", args = list(n = 20), requires_bars = 21L, id = "ttr_atr_20_tr"),
    list(fn = "ATR", input = "hlc", output = "trueHigh", args = list(n = 20), requires_bars = 21L, id = "ttr_atr_20_truehigh"),
    list(fn = "ATR", input = "hlc", output = "trueLow", args = list(n = 20), requires_bars = 21L, id = "ttr_atr_20_truelow"),
    list(fn = "MACD", input = "close", output = "signal", args = list(nFast = 12, nSlow = 26, nSig = 9), requires_bars = 34L, id = "ttr_macd_12_26_9_signal"),
    list(fn = "MACD", input = "close", output = "histogram", args = list(nFast = 12, nSlow = 26, nSig = 9), requires_bars = 34L, id = "ttr_macd_12_26_9_histogram"),
    list(fn = "BBands", input = "close", output = "dn", args = list(n = 20), requires_bars = 20L, id = "ttr_bbands_20_dn"),
    list(fn = "BBands", input = "close", output = "mavg", args = list(n = 20), requires_bars = 20L, id = "ttr_bbands_20_mavg"),
    list(fn = "BBands", input = "close", output = "pctB", args = list(n = 20), requires_bars = 20L, id = "ttr_bbands_20_pctb"),
    list(fn = "aroon", input = "hl", output = "aroonUp", args = list(n = 20), requires_bars = 20L, id = "ttr_aroon_20_aroonup"),
    list(fn = "aroon", input = "hl", output = "aroonDn", args = list(n = 20), requires_bars = 20L, id = "ttr_aroon_20_aroondn"),
    list(fn = "DonchianChannel", input = "hl", output = "high", args = list(n = 20), requires_bars = 20L, id = "ttr_donchianchannel_20_high"),
    list(fn = "DonchianChannel", input = "hl", output = "low", args = list(n = 20), requires_bars = 20L, id = "ttr_donchianchannel_20_low")
  )
  c(single_output, multi_output)
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

ledgr_test_ttr_case_label <- function(case) {
  sprintf(
    "%s input=%s output=%s args=%s TTR=%s",
    case$fn,
    case$input,
    if (is.null(case$output)) "<vector>" else case$output,
    paste(sprintf("%s=%s", names(case$args), unlist(case$args, use.names = FALSE)), collapse = ","),
    as.character(utils::packageVersion("TTR"))
  )
}

ledgr_test_ind_ttr_from_case <- function(case) {
  do.call(
    ledgr_ind_ttr,
    c(list(case$fn, input = case$input, output = case$output), case$args)
  )
}

ledgr_test_ttr_raw_result <- function(bars, case) {
  x <- ledgr:::ledgr_ttr_build_input(bars, case$input)
  ttr_fn <- getExportedValue("TTR", case$fn)
  if (identical(case$input, "hlcv") && case$fn %in% c("MFI", "CMF")) {
    do.call(ttr_fn, c(list(x[, c("High", "Low", "Close"), drop = FALSE], x[, "Volume"]), case$args))
  } else {
    do.call(ttr_fn, c(list(x), case$args))
  }
}

ledgr_test_ttr_select_direct <- function(result, case) {
  if (is.null(dim(result))) {
    if (!is.null(case$output)) {
      stop(sprintf("TTR::%s returned a vector for output %s.", case$fn, case$output))
    }
    return(as.numeric(result))
  }
  cols <- colnames(result)
  if (is.null(cols) || any(!nzchar(cols))) {
    cols <- as.character(seq_len(ncol(result)))
  }
  if (identical(case$fn, "MACD") && identical(case$output, "histogram")) {
    return(as.numeric(result[, "macd"] - result[, "signal"]))
  }
  output <- case$output
  if (is.null(output)) {
    if (ncol(result) != 1L) {
      stop(sprintf("TTR::%s returned multiple columns without an output.", case$fn))
    }
    output <- cols[[1L]]
  }
  if (!output %in% cols) {
    stop(sprintf("Missing output %s from TTR::%s. Available: %s", output, case$fn, paste(cols, collapse = ", ")))
  }
  as.numeric(result[, output])
}

ledgr_test_ttr_direct_values <- function(bars, case) {
  values <- ledgr_test_ttr_select_direct(ledgr_test_ttr_raw_result(bars, case), case)
  values[is.nan(values)] <- NA_real_
  unname(values)
}

ledgr_test_ttr_expected_values <- function(bars, case) {
  values <- ledgr_test_ttr_direct_values(bars, case)
  if (case$requires_bars > 1L && length(values) > 0L) {
    values[seq_len(min(case$requires_bars - 1L, length(values)))] <- NA_real_
  }
  values
}

ledgr_test_ttr_first_callable <- function(case, max_n = 80L) {
  for (n in seq_len(max_n)) {
    bars <- ledgr_test_ttr_bars(n)
    value <- tryCatch({
      values <- ledgr_test_ttr_direct_values(bars, case)
      utils::tail(values, 1L)
    }, error = function(e) NA_real_)
    if (is.numeric(value) && length(value) == 1L && !is.na(value) && is.finite(value)) {
      return(n)
    }
  }
  NA_integer_
}

ledgr_test_macd_warmup_cases <- function() {
  outputs <- c("macd", "signal", "histogram")
  percents <- c(TRUE, FALSE)
  unlist(
    lapply(outputs, function(output) {
      lapply(percents, function(percent) {
        args <- list(nFast = 12, nSlow = 26, nSig = 9, percent = percent)
        list(
          fn = "MACD",
          input = "close",
          output = output,
          percent = percent,
          args = args,
          requires_bars = 34L,
          id = ledgr:::ledgr_ttr_default_id("MACD", c("nFast", "nSlow", "nSig"), args, output)
        )
      })
    }),
    recursive = FALSE
  )
}

testthat::test_that("TTR warmup rules table has the documented schema", {
  rules <- ledgr_ind_ttr_warmup_rules()

  testthat::expect_s3_class(rules, "tbl_df")
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
    ledgr:::ledgr_ttr_infer_requires_bars("MACD", macd_args, output = "macd"),
    34L
  )
  testthat::expect_identical(
    ledgr:::ledgr_ttr_infer_requires_bars("MACD", macd_args, output = "signal"),
    34L
  )
  testthat::expect_identical(
    ledgr:::ledgr_ttr_infer_requires_bars("MACD", macd_args, output = "histogram"),
    34L
  )
})

testthat::test_that("TTR parity matrix covers every supported rule and output", {
  testthat::skip_if_not_installed("TTR")

  bars <- ledgr_test_ttr_bars()
  cases <- ledgr_test_ttr_parity_cases()
  rules <- ledgr_ind_ttr_warmup_rules()
  covered <- unique(vapply(cases, `[[`, character(1), "fn"))

  testthat::expect_setequal(covered, rules$ttr_fn)
  testthat::expect_setequal(
    vapply(cases[vapply(cases, `[[`, character(1), "fn") == "ATR"], `[[`, character(1), "output"),
    c("atr", "tr", "trueHigh", "trueLow")
  )
  testthat::expect_setequal(
    vapply(cases[vapply(cases, `[[`, character(1), "fn") == "BBands"], `[[`, character(1), "output"),
    c("up", "dn", "mavg", "pctB")
  )
  testthat::expect_setequal(
    vapply(cases[vapply(cases, `[[`, character(1), "fn") == "MACD"], `[[`, character(1), "output"),
    c("macd", "signal", "histogram")
  )
  testthat::expect_setequal(
    vapply(cases[vapply(cases, `[[`, character(1), "fn") == "aroon"], `[[`, character(1), "output"),
    c("oscillator", "aroonUp", "aroonDn")
  )
  testthat::expect_setequal(
    vapply(cases[vapply(cases, `[[`, character(1), "fn") == "DonchianChannel"], `[[`, character(1), "output"),
    c("mid", "high", "low")
  )
})

testthat::test_that("TTR ledgr output matches direct TTR output after normalization", {
  testthat::skip_if_not_installed("TTR")

  bars <- ledgr_test_ttr_bars()

  for (case in ledgr_test_ttr_parity_cases()) {
    label <- ledgr_test_ttr_case_label(case)
    ind <- ledgr_test_ind_ttr_from_case(case)
    values_from_ttr <- ledgr_test_ttr_expected_values(bars, case)
    values_from_ledgr <- ledgr:::ledgr_compute_feature_series(bars, ind)
    first_valid_from_ledgr <- which(!is.na(values_from_ledgr))[1]
    first_callable_from_ttr <- ledgr_test_ttr_first_callable(case, max_n = nrow(bars))

    testthat::expect_identical(ind$id, case$id, info = label)
    testthat::expect_identical(ind$requires_bars, case$requires_bars, info = label)
    testthat::expect_identical(first_callable_from_ttr, case$requires_bars, info = label)
    testthat::expect_identical(first_valid_from_ledgr, case$requires_bars, info = label)
    # ledgr_test_ttr_expected_values() forces rows 1:(requires_bars-1) to NA for
    # all cases. For MACD output="macd", full-series TTR returns finite values at
    # rows nSlow:(nSlow+nSig-2), but those rows are warmup in pulse-by-pulse
    # execution, so equality in that zone is NA == NA, not raw value comparison.
    testthat::expect_equal(values_from_ledgr, values_from_ttr, tolerance = 1e-12, info = label)
    testthat::expect_equal(ind$fn(bars), utils::tail(values_from_ledgr, 1), tolerance = 1e-12, info = label)
  }
})

testthat::test_that("MACD audit case uses direct TTR warmup with percent false", {
  testthat::skip_if_not_installed("TTR")

  bars <- ledgr_test_ttr_bars()
  ind <- ledgr_ind_ttr(
    "MACD",
    input = "close",
    output = "macd",
    nFast = 12,
    nSlow = 26,
    nSig = 9,
    percent = FALSE
  )

  testthat::expect_identical(ind$requires_bars, 34L)
  testthat::expect_identical(ind$stable_after, 34L)

  values <- ledgr:::ledgr_compute_feature_series(bars, ind)
  first_valid <- which(!is.na(values))[1]
  testthat::expect_identical(first_valid, 34L)
  testthat::expect_false(any(is.na(values[seq.int(ind$stable_after, length(values))])))

  first_callable_from_ttr <- ledgr_test_ttr_first_callable(list(
    fn = "MACD",
    input = "close",
    output = "macd",
    args = list(nFast = 12, nSlow = 26, nSig = 9, percent = FALSE),
    requires_bars = 34L,
    id = "ttr_macd_12_26_9_false_macd"
  ))
  testthat::expect_identical(first_callable_from_ttr, ind$requires_bars)
})

testthat::test_that("MACD warmup matches direct TTR output for all percent/output cases", {
  testthat::skip_if_not_installed("TTR")

  bars <- ledgr_test_ttr_bars()
  ttr_version <- as.character(utils::packageVersion("TTR"))

  # LDG-1502: long direct TTR output can contain macd values before row 34,
  # but TTR::MACD itself cannot be called at pulse lengths 26-33 because it
  # computes the signal EMA internally. ledgr therefore treats all MACD outputs
  # as first callable at nSlow + nSig - 1.
  for (case in ledgr_test_macd_warmup_cases()) {
    label <- ledgr_test_ttr_case_label(case)
    values_from_ttr <- ledgr_test_ttr_expected_values(bars, case)
    first_callable_from_ttr <- ledgr_test_ttr_first_callable(case, max_n = nrow(bars))

    ind <- do.call(
      ledgr_ind_ttr,
      c(list("MACD", input = "close", output = case$output), case$args)
    )
    values_from_ledgr <- ledgr:::ledgr_compute_feature_series(bars, ind)
    first_valid_from_ledgr <- which(!is.na(values_from_ledgr))[1]

    testthat::expect_identical(ind$requires_bars, case$requires_bars, info = label)
    testthat::expect_identical(first_callable_from_ttr, case$requires_bars, info = label)
    testthat::expect_identical(first_valid_from_ledgr, case$requires_bars, info = label)
    # For MACD macd output, direct full-series TTR has finite values at rows
    # 26-33. Ledgr masks those rows because pulse-by-pulse TTR is not callable
    # until row 34, so equality there is intentionally warmup NA == warmup NA.
    testthat::expect_equal(values_from_ledgr, values_from_ttr, tolerance = 1e-12, info = label)
  }
})

testthat::test_that("TTR short samples return aligned warmup NA instead of low-level TTR errors", {
  testthat::skip_if_not_installed("TTR")

  cases <- c(
    ledgr_test_macd_warmup_cases(),
    list(
      list(fn = "RSI", input = "close", output = NULL, args = list(n = 14), requires_bars = 15L, id = "ttr_rsi_14"),
      list(fn = "ATR", input = "hlc", output = "atr", args = list(n = 20), requires_bars = 21L, id = "ttr_atr_20_atr"),
      list(fn = "BBands", input = "close", output = "up", args = list(n = 20), requires_bars = 20L, id = "ttr_bbands_20_up"),
      list(fn = "aroon", input = "hl", output = "oscillator", args = list(n = 20), requires_bars = 20L, id = "ttr_aroon_20_oscillator"),
      list(fn = "DonchianChannel", input = "hl", output = "mid", args = list(n = 20), requires_bars = 20L, id = "ttr_donchianchannel_20_mid")
    )
  )

  for (case in cases) {
    ind <- ledgr_test_ind_ttr_from_case(case)
    for (n in unique(pmax(1L, c(case$requires_bars - 1L, case$requires_bars, case$requires_bars + 1L)))) {
      values <- ledgr:::ledgr_compute_feature_series(ledgr_test_ttr_bars(n), ind)
      label <- paste(ledgr_test_ttr_case_label(case), "n=", n)
      testthat::expect_equal(length(values), n, info = label)
      if (n < case$requires_bars) {
        testthat::expect_true(all(is.na(values)), info = label)
      } else {
        testthat::expect_false(is.na(utils::tail(values, 1L)), info = label)
      }
    }
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

testthat::test_that("TTR output bundles materialize ordinary indicators with stable names", {
  testthat::skip_if_not_installed("TTR")

  bundle <- ledgr_ind_ttr_outputs("BBands", input = "close", n = 20)
  indicators <- ledgr:::ledgr_indicator_bundle_indicators(bundle)

  testthat::expect_s3_class(bundle, "ledgr_indicator_bundle")
  testthat::expect_true(all(vapply(indicators, inherits, logical(1), "ledgr_indicator")))
  testthat::expect_identical(
    ledgr_feature_id(bundle),
    c("bbands_dn", "bbands_mavg", "bbands_up", "bbands_pctb")
  )
  testthat::expect_identical(
    ledgr_feature_id(indicators),
    c("bbands_dn", "bbands_mavg", "bbands_up", "bbands_pctb")
  )
  testthat::expect_identical(
    vapply(indicators, function(ind) ind$params$output, character(1)),
    c("dn", "mavg", "up", "pctB")
  )

  fingerprints <- vapply(indicators, ledgr:::ledgr_indicator_fingerprint, character(1))
  testthat::expect_length(unique(fingerprints), length(fingerprints))
})

testthat::test_that("TTR output bundle naming supports filters, prefixes, and raw-name opt-in", {
  testthat::skip_if_not_installed("TTR")

  filtered <- ledgr_ind_ttr_outputs("BBands", input = "close", outputs = c("dn", "up"), n = 20)
  explicit <- ledgr_ind_ttr_outputs("BBands", input = "close", outputs = c("dn", "up"), prefix = "bb", n = 20)
  raw <- ledgr_ind_ttr_outputs("BBands", input = "close", outputs = c("dn", "pctB"), prefix = NULL, n = 20)
  named <- ledgr_ind_ttr_outputs(
    "BBands",
    input = "close",
    outputs = c("dn", "up"),
    naming = c(dn = "lower_band", up = "upper_band"),
    n = 20
  )

  testthat::expect_identical(ledgr_feature_id(filtered), c("bbands_dn", "bbands_up"))
  testthat::expect_identical(ledgr_feature_id(explicit), c("bb_dn", "bb_up"))
  testthat::expect_identical(ledgr_feature_id(raw), c("dn", "pctb"))
  testthat::expect_identical(ledgr_feature_id(named), c("lower_band", "upper_band"))
  testthat::expect_error(
    ledgr_ind_ttr_outputs("BBands", input = "close", outputs = c("missing"), n = 20),
    "Available outputs: dn, mavg, up, pctB",
    class = "ledgr_invalid_args"
  )
  testthat::expect_error(
    ledgr_ind_ttr_outputs("BBands", input = "close", naming = c(dn = "lower_band", up = "upper_band"), n = 20),
    "`naming` renames selected outputs; it does not filter outputs",
    fixed = TRUE,
    class = "ledgr_invalid_args"
  )
})

testthat::test_that("TTR output bundles include MACD derived histogram output", {
  testthat::skip_if_not_installed("TTR")

  bundle <- ledgr_ind_ttr_outputs(
    "MACD",
    input = "close",
    nFast = 12,
    nSlow = 26,
    nSig = 9,
    percent = FALSE
  )
  indicators <- ledgr:::ledgr_indicator_bundle_indicators(bundle)

  testthat::expect_identical(
    ledgr_feature_id(bundle),
    c("macd_macd", "macd_signal", "macd_histogram")
  )
  testthat::expect_identical(
    vapply(indicators, function(ind) ind$params$output, character(1)),
    c("macd", "signal", "histogram")
  )

  bars <- ledgr_test_ttr_bars()
  values <- lapply(indicators, function(ind) ledgr:::ledgr_compute_feature_series(bars, ind))
  testthat::expect_equal(
    values[[3]],
    values[[1]] - values[[2]],
    tolerance = 1e-12
  )
})

testthat::test_that("TTR output bundles flatten at feature boundaries", {
  testthat::skip_if_not_installed("TTR")

  bundle <- ledgr_ind_ttr_outputs("BBands", input = "close", outputs = c("dn", "up"), n = 20)
  feature_map <- ledgr_feature_map(bands = bundle, trend = ledgr_ind_sma(20))

  testthat::expect_identical(
    unname(ledgr_feature_id(feature_map)),
    c("bbands_dn", "bbands_up", "sma_20")
  )
  testthat::expect_identical(
    names(ledgr_feature_id(feature_map)),
    c("bbands_dn", "bbands_up", "trend")
  )
  testthat::expect_identical(
    ledgr_feature_contracts(list(bundle))$feature_id,
    c("bbands_dn", "bbands_up")
  )

  snapshot <- ledgr_snapshot_from_df(ledgr_test_ttr_bars(45L))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  strategy <- function(ctx, params) ctx$flat()
  exp_static <- ledgr_experiment(snapshot, strategy, features = list(bundle), cost_model = ledgr_cost_zero())
  exp_factory <- ledgr_experiment(
    snapshot,
    strategy,
    features = function(params) {
      ledgr_ind_ttr_outputs("BBands", input = "close", outputs = params$outputs, n = 20)
    },
  cost_model = ledgr_cost_zero()
  )
  grid <- ledgr_param_grid(short = list(outputs = c("dn", "up")))

  testthat::expect_identical(
    ledgr_feature_id(ledgr:::ledgr_experiment_materialize_features(exp_static, list())),
    c("bbands_dn", "bbands_up")
  )
  resolved <- ledgr:::ledgr_resolve_feature_candidates(exp_factory, grid)
  testthat::expect_identical(resolved$candidate_features$feature_ids[[1]], c("bbands_dn", "bbands_up"))
  testthat::expect_match(resolved$candidate_features$feature_set_hash[[1]], "^[0-9a-f]{64}$")
})

testthat::test_that("parameterized TTR declarations resolve to concrete indicators and bundle identities", {
  testthat::skip_if_not_installed("TTR")

  rsi <- ledgr_ind_ttr("RSI", input = "close", n = ledgr_param("rsi_n"))
  testthat::expect_s3_class(rsi, "ledgr_parameterized_indicator")
  testthat::expect_error(ledgr_feature_id(rsi), class = "ledgr_unresolved_feature_id")

  features <- ledgr_feature_map(
    signal = rsi,
    bands = ledgr_ind_ttr_outputs(
      "BBands",
      input = "close",
      outputs = c("dn", "up"),
      n = ledgr_param("bb_n")
    )
  )

  params <- ledgr_parameters(features)
  testthat::expect_identical(params$param_name, c("rsi_n", "bb_n", "bb_n"))
  testthat::expect_identical(params$alias, c("signal", "bbands_dn", "bbands_up"))

  resolved_20 <- ledgr:::ledgr_resolve_feature_map(
    features,
    feature_params = list(rsi_n = 14L, bb_n = 20L)
  )
  resolved_50 <- ledgr:::ledgr_resolve_feature_map(
    features,
    feature_params = list(rsi_n = 14L, bb_n = 50L)
  )
  resolved_20_again <- ledgr:::ledgr_resolve_feature_map(
    features,
    feature_params = list(rsi_n = 14L, bb_n = 20L)
  )

  ids_20 <- ledgr_feature_id(resolved_20)
  ids_50 <- ledgr_feature_id(resolved_50)
  ids_20_again <- ledgr_feature_id(resolved_20_again)
  testthat::expect_identical(names(ids_20), c("signal", "bbands_dn", "bbands_up"))
  testthat::expect_identical(ids_20[["signal"]], "ttr_rsi_14")
  testthat::expect_identical(ids_20, ids_20_again)
  testthat::expect_false(identical(unname(ids_20[c("bbands_dn", "bbands_up")]), unname(ids_50[c("bbands_dn", "bbands_up")])))
  testthat::expect_identical(
    anyDuplicated(c(unname(ids_20[c("bbands_dn", "bbands_up")]), unname(ids_50[c("bbands_dn", "bbands_up")]))),
    0L
  )
  testthat::expect_error(
    ledgr_ind_ttr_outputs("stoch", input = "hlc", nFastK = ledgr_param("n")),
    "currently supports ATR, BBands, MACD, aroon, and DonchianChannel",
    class = "ledgr_unsupported_param_placement"
  )
})

testthat::test_that("TTR indicators use series_fn during backtest feature precomputation", {
  testthat::skip_if_not_installed("TTR")

  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)
  ledgr_feature_cache_clear()
  on.exit(ledgr_feature_cache_clear(), add = TRUE)

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
    db_path = db_path,
  cost_model = ledgr_cost_zero()
  )
  on.exit(close(bt), add = TRUE)

  features <- DBI::dbGetQuery(
    ledgr:::get_connection(bt),
    "SELECT DISTINCT feature_name FROM features WHERE run_id = ?",
    params = list(bt$run_id)
  )
  testthat::expect_true(ind$id %in% features$feature_name)
})
