ws20_context_has_data_frame <- function(ctx) {
  seen <- new.env(parent = emptyenv())
  contains <- function(value) {
    if (is.data.frame(value)) return(TRUE)
    if (is.function(value)) {
      value <- environment(value)
      if (isNamespace(value) || identical(value, globalenv()) ||
          grepl("^package:", environmentName(value))) return(FALSE)
    }
    if (is.environment(value)) {
      key <- format(value)
      if (exists(key, envir = seen, inherits = FALSE)) return(FALSE)
      assign(key, TRUE, envir = seen)
      value <- as.list.environment(value, all.names = TRUE)
    }
    if (!is.list(value)) return(FALSE)
    any(vapply(unclass(value), contains, logical(1)))
  }
  raw <- unclass(ctx)
  direct <- any(vapply(raw, is.data.frame, logical(1)))
  direct || contains(raw[[".pulse_lookup"]])
}

# ledgr-test-profile: fast
testthat::test_that("[LTB-0546] flat contexts retire frames across all entrances", {
  ids <- c("BBB", "AAA")
  dates <- as.Date("2020-01-01") + 0:4
  bars <- ledgr_test_make_bars(ids, dates)
  target_ts <- as.POSIXct(dates[[3L]], tz = "UTC")
  snapshot <- ledgr_snapshot_from_df(bars)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  features <- ledgr_feature_map(
    z_ret = ledgr_ind_returns(1),
    a_sma = ledgr_ind_sma(2)
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
    rep(c("z_ret", "a_sma"), times = 2L)
  )
  testthat::expect_identical(
    names(captured$wide)[4:10],
    c(
      "AAA__ohlcv_open", "AAA__ohlcv_high", "AAA__ohlcv_low",
      "AAA__ohlcv_close", "AAA__ohlcv_volume",
      "AAA__feature_z_ret", "AAA__feature_a_sma"
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

  expected_close <- stats::setNames(vapply(ids, function(id) bars$close[
    bars$instrument_id == id & bars$ts_utc == target_ts
  ], numeric(1)), ids)
  testthat::expect_identical(ctx$close, expected_close)
  saved_long <- captured$long
  saved_wide <- captured$wide
  testthat::expect_identical(ctx$close, expected_close)
  testthat::expect_identical(ledgr_pulse_features(ctx), saved_long)
  testthat::expect_identical(ledgr_pulse_wide(ctx), saved_wide)
  testthat::expect_identical(
    ledgr:::ledgr_strategy_error_features(ctx),
    "return_1, sma_2"
  )
  printed_and_ids <- testthat::with_mocked_bindings(
    list(
      printed = paste(utils::capture.output(print(ctx)), collapse = "\n"),
      ids = ledgr:::ledgr_strategy_error_features(ctx)
    ),
    ledgr_pulse_features = function(...) stop("long frame must not be built"),
    .package = "ledgr"
  )
  testthat::expect_identical(printed_and_ids$ids, "return_1, sma_2")
  printed <- printed_and_ids$printed
  testthat::expect_match(printed, "Daxis:     2 instruments", fixed = TRUE)
  testthat::expect_match(printed, "Features:  2 columns", fixed = TRUE)

  before <- ctx$.pulse_lookup$preparation_counts$feature_resolver
  invisible(names(ctx))
  invisible(names(ctx))
  invisible(ctx$z_ret)
  invisible(ctx$return_1)
  testthat::expect_identical(
    ctx$.pulse_lookup$preparation_counts$feature_resolver,
    before
  )
  testthat::expect_identical(before, 1L)
  testthat::expect_identical(ctx$.pulse_lookup$projection_idx, 3L)
  testthat::expect_identical(
    ctx$.pulse_lookup$cutoff_num,
    as.numeric(ledgr:::ledgr_utc(ctx$ts_utc))
  )

  first_map <- c(first = "return_1")
  second_map <- c(second = "sma_2")
  testthat::expect_identical(ledgr_pulse_features(ctx, first_map)$alias, rep("first", 2L))
  testthat::expect_identical(ledgr_pulse_features(ctx, second_map)$alias, rep("second", 2L))

  unmapped <- ledgr_pulse_snapshot(
    snapshot,
    universe = ids,
    ts_utc = pulse_ts,
    features = list(ledgr_ind_sma(2), ledgr_ind_returns(1))
  )
  on.exit(close(unmapped), add = TRUE)
  testthat::expect_identical(
    unique(ledgr_pulse_features(unmapped)$feature_id),
    c("return_1", "sma_2")
  )

  missing_snapshot <- availability_runtime_fixture(days = 5L, bar_days = c(1L, 2L, 4L, 5L))
  on.exit(ledgr_snapshot_close(missing_snapshot), add = TRUE)
  missing <- new.env(parent = emptyenv())
  missing_run <- ledgr_run(ledgr_experiment(
    missing_snapshot,
    function(ctx, params) {
      if (identical(as.Date(ctx$ts_utc), as.Date("2020-01-03"))) {
        missing$close <- ctx$close
      }
      ctx$hold()
    },
    universe = "AAA",
    opening = ledgr_opening(cash = 1000),
    valuation_policy = ledgr_valuation_stale(1),
    cost_model = ledgr_cost_zero()
  ), run_id = "ws20-missing-bar")
  on.exit(close(missing_run), add = TRUE)
  testthat::expect_true(is.na(missing$close[["AAA"]]))
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
  lookup_source <- paste(c(
    deparse(ledgr:::ledgr_pulse_context_feature_columns),
    deparse(ledgr:::ledgr_pulse_context_feature_readable)
  ), collapse = "\n")
  for (forbidden in c("unique(", "setdiff(", "$aliases", "$feature_ids", "$alias_map")) {
    testthat::expect_false(grepl(forbidden, lookup_source, fixed = TRUE), info = forbidden)
  }

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
      ts_utc = as.POSIXct("2020-01-02", tz = "UTC"),
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

  normalization_lengths <- integer()
  original_utc <- ledgr:::ledgr_utc
  counted_features <- data.frame(
    ts_utc = rep(as.POSIXct("2020-01-02", tz = "UTC"), 3L),
    instrument_id = rep("AAA", 3L),
    feature_name = c("a", "b", "c"),
    feature_value = 1:3
  )
  testthat::with_mocked_bindings(
    ledgr:::ledgr_pulse_context(
      run_id = "counted-ts", ts_utc = as.POSIXct("2020-01-02", tz = "UTC"),
      universe = "AAA", bars = data.frame(
        ts_utc = as.POSIXct("2020-01-02", tz = "UTC"), instrument_id = "AAA",
        open = 1, high = 1, low = 1, close = 1, volume = 1
      ), features = counted_features, cash = 100, equity = 100
    ),
    ledgr_utc = function(x, ...) {
      normalization_lengths <<- c(normalization_lengths, length(x))
      original_utc(x, ...)
    },
    .package = "ledgr"
  )
  testthat::expect_identical(sum(normalization_lengths == 3L), 1L)

  bad_ts <- data.frame(
    ts_utc = as.POSIXct(c("2020-01-02", "2020-01-03"), tz = "UTC"),
    instrument_id = c("AAA", "AAA"),
    feature_name = c("signal", "signal"),
    feature_value = c(1, 2)
  )
  testthat::expect_error(
    ledgr:::ledgr_pulse_context(
      run_id = "bad-ts", ts_utc = as.POSIXct("2020-01-02", tz = "UTC"),
      universe = "AAA", bars = data.frame(
        ts_utc = as.POSIXct("2020-01-02", tz = "UTC"), instrument_id = "AAA",
        open = 1, high = 1, low = 1, close = 1, volume = 1
      ), features = bad_ts, cash = 100, equity = 100
    ),
    class = "ledgr_invalid_pulse_context"
  )
  foreign <- bad_ts[1L, , drop = FALSE]
  foreign$instrument_id <- "BBB"
  testthat::expect_error(
    ledgr:::ledgr_pulse_context(
      run_id = "foreign", ts_utc = as.POSIXct("2020-01-02", tz = "UTC"),
      universe = "AAA", bars = data.frame(
        ts_utc = as.POSIXct("2020-01-02", tz = "UTC"), instrument_id = "AAA",
        open = 1, high = 1, low = 1, close = 1, volume = 1
      ), features = foreign, cash = 100, equity = 100
    ),
    class = "ledgr_invalid_pulse_context"
  )

  sweep_bars <- ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:3)
  sweep_snapshot <- ledgr_snapshot_from_df(sweep_bars)
  on.exit(ledgr_snapshot_close(sweep_snapshot), add = TRUE)
  sweep_experiment <- ledgr_experiment(
    sweep_snapshot,
    function(ctx, params) ctx$hold(),
    universe = "AAA",
    features = ledgr_feature_map(signal = ledgr_ind_sma(2)),
    opening = ledgr_opening(cash = 1000),
    cost_model = ledgr_cost_zero()
  )
  grid <- ledgr_grid_named(
    a = list(strategy = list(tag = 1L)),
    b = list(strategy = list(tag = 2L))
  )
  preparations <- 0L
  original_increment <- ledgr:::ledgr_context_preparation_increment
  testthat::with_mocked_bindings(
    ledgr_sweep(sweep_experiment, grid, seed = 1L, workers = 1L),
    ledgr_context_preparation_increment = function(counts, name) {
      if (identical(name, "feature_resolver")) {
        preparations <<- preparations + 1L
      }
      original_increment(counts, name)
    },
    .package = "ledgr"
  )
  testthat::expect_identical(preparations, 2L)
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
