ledgr_pulse_feature_parity_fixture <- function() {
  ids <- c("AAA", "BBB")
  pulses <- as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:19
  close_a <- cumsum(c(100, rep(c(2, -1, 3, -2), length.out = 19L)))
  close_b <- cumsum(c(80, rep(c(-1, 2, -2, 3), length.out = 19L)))
  closes <- c(close_a, close_b)
  bars <- data.frame(
    instrument_id = rep(ids, each = length(pulses)),
    ts_utc = rep(pulses, times = length(ids)),
    open = closes,
    high = closes + 1,
    low = closes - 1,
    close = closes,
    volume = 1000,
    stringsAsFactors = FALSE
  )

  features <- list(
    ledgr_ind_sma(3),
    ledgr_indicator(
      id = "series_path",
      fn = function(window, params) -999,
      requires_bars = 2,
      stable_after = 3,
      params = list(scale = 2),
      series_fn = function(bars, params) seq_len(nrow(bars)) * params$scale
    ),
    ledgr_indicator(
      id = "window_only",
      fn = function(window) mean(window$close),
      requires_bars = 2,
      stable_after = 3
    ),
    ledgr_indicator(
      id = "window_params",
      fn = function(window, params) nrow(window) * params$scale,
      requires_bars = 2,
      stable_after = 4,
      params = list(scale = 10)
    )
  )
  if (requireNamespace("TTR", quietly = TRUE)) {
    features[[length(features) + 1L]] <- ledgr_ind_ttr(
      "RSI",
      input = "close",
      n = 14
    )
  }

  list(ids = ids, pulses = pulses, bars = bars, features = features)
}

ledgr_pulse_feature_values <- function(ctx, ids, feature_ids) {
  values <- unlist(lapply(ids, function(id) {
    vapply(feature_ids, function(feature_id) {
      ctx[[feature_id]][[id]]
    }, numeric(1))
  }), use.names = FALSE)
  names(values) <- as.vector(t(outer(ids, feature_ids, paste, sep = "::")))
  values
}

testthat::test_that("[LTB-0100] pulse inspection uses the run feature path", {
  fixture <- ledgr_pulse_feature_parity_fixture()
  snapshot <- ledgr_snapshot_from_df(
    fixture$bars,
    db_path = tempfile(fileext = ".duckdb")
  )
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  feature_ids <- vapply(fixture$features, function(feature) feature$id, character(1))
  target_ts <- ledgr_iso_utc(tail(fixture$pulses, 1L))
  strategy <- function(ctx, params) {
    if (identical(ledgr_iso_utc(ctx$ts_utc), params$target_ts)) {
      values <- unlist(lapply(params$ids, function(id) {
        vapply(params$feature_ids, function(feature_id) {
          ctx[[feature_id]][[id]]
        }, numeric(1))
      }), use.names = FALSE)
      names(values) <- as.vector(t(outer(
        params$ids,
        params$feature_ids,
        paste,
        sep = "::"
      )))
      return(ledgr_strategy_result(ctx$flat(), values = paste(
        names(values), format(values, digits = 17), sep = "=", collapse = ";"
      )))
    }
    ctx$flat()
  }
  experiment <- ledgr_experiment(
    snapshot,
    strategy,
    features = fixture$features,
    opening = ledgr_opening(cash = 10000),
    cost_model = ledgr_cost_zero(),
    portfolio_state = list(values = "")
  )
  run <- ledgr_run(
    experiment,
    params = list(
      target_ts = target_ts,
      ids = fixture$ids,
      feature_ids = feature_ids
    ),
    run_id = "pulse-feature-parity"
  )
  on.exit(close(run), add = TRUE)
  encoded <- availability_last_state(run)$values
  pieces <- strsplit(encoded, ";", fixed = TRUE)[[1L]]
  run_values <- stats::setNames(
    as.numeric(sub("^[^=]*=", "", pieces)),
    sub("=.*$", "", pieces)
  )

  pulse <- ledgr_pulse_snapshot(
    snapshot,
    universe = fixture$ids,
    ts_utc = target_ts,
    features = fixture$features,
    cash = 10000
  )
  on.exit(close(pulse), add = TRUE)
  pulse_values <- ledgr_pulse_feature_values(
    pulse,
    fixture$ids,
    feature_ids
  )
  run_values <- run_values[names(pulse_values)]

  testthat::expect_identical(pulse_values, run_values)
  testthat::expect_identical(
    unname(pulse_values[paste0(fixture$ids, "::window_params")]),
    c(20, 20)
  )
  testthat::expect_identical(
    unname(pulse_values[paste0(fixture$ids, "::series_path")]),
    c(40, 40)
  )
})

testthat::test_that("[LTB-0104] fn-only pulse features use the run preparation", {
  fixture <- ledgr_pulse_feature_parity_fixture()
  calls <- new.env(parent = emptyenv())
  calls$n <- 0L
  counted <- ledgr_indicator(
    id = "counted_window",
    fn = function(window) {
      calls$n <- calls$n + 1L
      mean(window$close)
    },
    requires_bars = 2,
    stable_after = 4
  )
  snapshot <- ledgr_snapshot_from_df(
    fixture$bars,
    db_path = tempfile(fileext = ".duckdb")
  )
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  pulse <- ledgr_pulse_snapshot(
    snapshot,
    universe = fixture$ids,
    ts_utc = ledgr_iso_utc(tail(fixture$pulses, 1L)),
    features = list(counted),
    cash = 10000
  )
  on.exit(close(pulse), add = TRUE)
  pulse_calls <- calls$n

  calls$n <- 0L
  experiment <- ledgr_experiment(
    snapshot,
    function(ctx, params) ctx$flat(),
    features = list(counted),
    opening = ledgr_opening(cash = 10000),
    cost_model = ledgr_cost_zero()
  )
  run <- ledgr_run(experiment, run_id = "fn-only-pulse-preparation")
  on.exit(close(run), add = TRUE)
  run_calls <- calls$n

  testthat::expect_gt(pulse_calls, 0L)
  testthat::expect_identical(pulse_calls, run_calls)
  testthat::expect_identical(
    unname(pulse[["counted_window"]]),
    c(110.5, 88)
  )
})
