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
      ctx$feature(id, feature_id)
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
          ctx$feature(id, feature_id)
        }, numeric(1))
      }), use.names = FALSE)
      names(values) <- as.vector(t(outer(
        params$ids,
        params$feature_ids,
        paste,
        sep = "::"
      )))
      return(list(
        targets = ctx$flat(),
        state_update = list(values = as.list(values))
      ))
    }
    ctx$flat()
  }
  experiment <- ledgr_experiment(
    snapshot,
    strategy,
    features = fixture$features,
    opening = ledgr_opening(cash = 10000),
    cost_model = ledgr_cost_zero()
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
  state_json <- DBI::dbGetQuery(
    ledgr:::get_connection(snapshot),
    paste0(
      "SELECT state_json FROM strategy_state ",
      "WHERE run_id = ? ORDER BY ts_utc DESC LIMIT 1"
    ),
    params = list(run$run_id)
  )$state_json[[1L]]
  run_values <- unlist(
    ledgr:::ledgr_json_read_nested(state_json)$values,
    use.names = TRUE
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
    c(40, 40)
  )
  testthat::expect_identical(
    unname(pulse_values[paste0(fixture$ids, "::series_path")]),
    c(40, 40)
  )
})
