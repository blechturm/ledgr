ws20_context_has_data_frame <- function(ctx) {
  direct <- any(vapply(unclass(ctx), is.data.frame, logical(1)))
  lookup <- unclass(ctx)[[".pulse_lookup"]]
  nested <- if (is.environment(lookup)) {
    any(vapply(as.list.environment(lookup, all.names = TRUE), is.data.frame, logical(1)))
  } else {
    FALSE
  }
  direct || nested
}

# ledgr-test-profile: fast
testthat::test_that("[LTB-0546] flat contexts retire frames across all entrances", {
  ids <- c("BBB", "AAA")
  dates <- as.Date("2020-01-01") + 0:4
  bars <- ledgr_test_make_bars(ids, dates)
  snapshot <- ledgr_snapshot_from_df(bars)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  features <- ledgr_feature_map(
    ret = ledgr_ind_returns(1),
    sma = ledgr_ind_sma(2)
  )
  captured <- new.env(parent = emptyenv())
  target_iso <- ledgr_iso_utc(as.POSIXct(dates[[3L]], tz = "UTC"))
  strategy <- function(ctx, params) {
    if (identical(ctx$ts_utc, target_iso)) {
      captured$ctx <- ctx
      captured$long <- ledgr_pulse_features(ctx)
      captured$wide <- ledgr_pulse_wide(ctx)
    }
    ctx$hold()
  }
  experiment <- ledgr_experiment(
    snapshot,
    strategy,
    universe = ids,
    features = features,
    opening = ledgr_opening(cash = 1000),
    cost_model = ledgr_cost_zero()
  )
  run <- ledgr_run(experiment, run_id = "ws20-frame-retirement")
  on.exit(close(run), add = TRUE)
  ctx <- captured$ctx
  testthat::expect_s3_class(ctx, "ledgr_pulse_context")
  testthat::expect_false(ws20_context_has_data_frame(ctx))
  retired <- c("bars", "bar", "feature_table", "features_wide")
  testthat::expect_length(intersect(names(ctx), retired), 0L)
  for (name in retired) {
    testthat::expect_error(ctx[[name]], class = "ledgr_unknown_context_field")
  }
  testthat::expect_error(
    ledgr_feature_map(bars = ledgr_ind_sma(2)),
    class = "ledgr_invalid_feature_map"
  )
  testthat::expect_identical(
    captured$long$instrument_id,
    rep(ids, each = 2L)
  )
  testthat::expect_identical(
    captured$long$alias,
    rep(c("ret", "sma"), times = 2L)
  )
  testthat::expect_identical(
    names(captured$wide)[4:10],
    c(
      "AAA__ohlcv_open", "AAA__ohlcv_high", "AAA__ohlcv_low",
      "AAA__ohlcv_close", "AAA__ohlcv_volume",
      "AAA__feature_ret", "AAA__feature_sma"
    )
  )

  pulse_ts <- ctx$ts_utc
  from_experiment <- ledgr_pulse_snapshot(experiment, ts_utc = pulse_ts)
  from_snapshot <- ledgr_pulse_snapshot(
    snapshot,
    universe = ids,
    ts_utc = pulse_ts,
    features = features
  )
  on.exit(close(from_experiment), add = TRUE)
  on.exit(close(from_snapshot), add = TRUE)
  testthat::expect_identical(names(from_experiment), names(ctx))
  testthat::expect_identical(names(from_snapshot), names(ctx))
  testthat::expect_identical(ledgr_pulse_features(from_experiment), captured$long)
  testthat::expect_identical(ledgr_pulse_features(from_snapshot), captured$long)
  for (removed in c(
    "feature_params", "active_alias_map", "alias_map_json", "alias_map_hash",
    "alias_map_version"
  )) {
    testthat::expect_error(from_snapshot[[removed]], class = "ledgr_unknown_context_field")
  }

  saved_close <- ctx$close
  saved_long <- captured$long
  saved_wide <- captured$wide
  testthat::expect_identical(ctx$close, saved_close)
  testthat::expect_identical(ledgr_pulse_features(ctx), saved_long)
  testthat::expect_identical(ledgr_pulse_wide(ctx), saved_wide)
})

# ledgr-test-profile: fast
testthat::test_that("[LTB-0547] P2 reuses prepared primitives and manifests no frame", {
  decide_source <- paste(deparse(ledgr:::ledgr_fold_stage_decide), collapse = "\n")
  for (forbidden in c(
    "ledgr_history_bar_packet_frame", "ledgr_projection_feature_table",
    "ledgr_projection_features_wide", "feature_table =", "features_wide ="
  )) {
    testthat::expect_false(grepl(forbidden, decide_source, fixed = TRUE), info = forbidden)
  }
  ns <- asNamespace("ledgr")
  for (removed in c(
    "ledgr_history_bar_packet_frame", "ledgr_projection_feature_table",
    "ledgr_projection_feature_table_schema", "ledgr_projection_features_wide",
    "ledgr_projection_features_wide_columns", "ledgr_features_wide",
    "ledgr_pulse_context_bar", "ledgr_pulse_feature_table"
  )) {
    testthat::expect_false(exists(removed, envir = ns, inherits = FALSE), info = removed)
  }
  helper_source <- paste(c(
    deparse(ledgr_pulse_features),
    deparse(ledgr_pulse_wide),
    deparse(ledgr:::ledgr_pulse_inspection_feature_map)
  ), collapse = "\n")
  for (forbidden in c("rbind(", "canonical_json", "sha256", "dbGet", "dbExecute", "seal")) {
    testthat::expect_false(grepl(forbidden, helper_source, fixed = TRUE), info = forbidden)
  }
  testthat::expect_false(grepl("feature_table", paste(deparse(print.ledgr_pulse_context), collapse = "\n"), fixed = TRUE))
  testthat::expect_false(grepl("feature_table", paste(deparse(ledgr:::ledgr_strategy_error_features), collapse = "\n"), fixed = TRUE))

  fixture_ctx <- ledgr:::ledgr_pulse_context(
    run_id = "ws20-fixture",
    ts_utc = as.POSIXct("2020-01-02", tz = "UTC"),
    universe = "AAA",
    bars = data.frame(
      ts_utc = as.POSIXct("2020-01-02", tz = "UTC"),
      instrument_id = "AAA",
      open = 1,
      high = 1,
      low = 1,
      close = 1,
      volume = 1
    ),
    features = data.frame(
      instrument_id = "AAA",
      feature_name = "signal",
      feature_value = 1
    ),
    positions = c(AAA = 0),
    cash = 100,
    equity = 100
  )
  vector_env <- environment(fixture_ctx$.pulse_lookup$feature_vector)
  testthat::expect_false(any(vapply(
    as.list.environment(vector_env, all.names = TRUE),
    is.data.frame,
    logical(1)
  )))
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0548] mapped inspection returns typed empty axes", {
  dates <- as.Date("2020-01-01") + 0:3
  closes <- as.POSIXct(paste(dates, "16:00:00"), tz = "UTC")
  sessions <- ledgr_facts_sessions(data.frame(
    session_date = dates,
    status = "open",
    session_open = "09:30:00",
    session_close = "16:00:00",
    knowledge_time = as.POSIXct(dates, tz = "UTC") - 1
  ), venue_id = "XNYS")
  membership <- ledgr_facts_membership_snapshots(data.frame(
    instrument_id = c("AAA", NA_character_),
    effective_from = closes[c(1L, 3L)] - 3600,
    knowledge_time = closes[c(1L, 3L)] - 7200
  ), universe_id = "empty", complete = TRUE)
  bars <- data.frame(
    ts_utc = closes,
    instrument_id = "AAA",
    open = 100:103,
    high = 101:104,
    low = 99:102,
    close = 100:103,
    volume = 1000
  )
  snapshot <- ledgr_snapshot_from_df(
    bars,
    instruments_df = data.frame(instrument_id = "AAA"),
    facts = ledgr_facts(sessions, membership),
    price_basis = "split_adjusted"
  )
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  captured <- new.env(parent = emptyenv())
  experiment <- ledgr_experiment(
    snapshot,
    function(ctx, params) {
      if (length(ctx$universe) == 0L) captured$ctx <- ctx
      ctx$hold()
    },
    universe = ledgr_universe_members("empty"),
    features = ledgr_feature_map(ret = ledgr_ind_returns(1)),
    opening = ledgr_opening(cash = 1000),
    cost_model = ledgr_cost_zero()
  )
  run <- ledgr_run(experiment, run_id = "ws20-empty-axis")
  on.exit(close(run), add = TRUE)
  ctx <- captured$ctx
  testthat::expect_length(ctx$universe, 0L)
  long <- ledgr_pulse_features(ctx, c(ret = "return_1"))
  wide <- ledgr_pulse_wide(ctx, c(ret = "return_1"))
  testthat::expect_identical(
    names(long),
    c("ts_utc", "instrument_id", "feature_id", "feature_value", "alias")
  )
  testthat::expect_identical(nrow(long), 0L)
  testthat::expect_s3_class(long$ts_utc, "POSIXct")
  testthat::expect_identical(names(wide), c("ts_utc", "cash", "equity"))
  testthat::expect_error(
    ledgr_pulse_features(ctx, c(bad = "not_registered")),
    class = "ledgr_unknown_feature_id"
  )
})
