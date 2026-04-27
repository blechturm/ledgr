testthat::test_that("ledgr_backtest is equivalent to ledgr_run for functional strategies", {
  db_path_direct <- tempfile(fileext = ".duckdb")
  db_path_wrapper <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path_direct), add = TRUE)
  on.exit(unlink(db_path_wrapper), add = TRUE)

  snapshot_id <- "snapshot_20200101_000000_abcd"

  snap_direct <- ledgr_snapshot_from_df(test_bars, db_path = db_path_direct, snapshot_id = snapshot_id)
  on.exit(ledgr_snapshot_close(snap_direct), add = TRUE)

  snap_wrapper <- ledgr_snapshot_from_df(test_bars, db_path = db_path_wrapper, snapshot_id = snapshot_id)
  on.exit(ledgr_snapshot_close(snap_wrapper), add = TRUE)

  universe <- c("TEST_A", "TEST_B")
  config <- ledgr:::ledgr_config(
    snapshot = snap_direct,
    universe = universe,
    strategy = test_strategy,
    backtest = ledgr:::ledgr_backtest_config(start = "2020-01-01", end = "2020-12-31", initial_cash = 100000),
    db_path = db_path_direct
  )
  result_direct <- ledgr:::ledgr_run(config)

  result_wrapper <- ledgr_backtest(
    snapshot = snap_wrapper,
    strategy = test_strategy,
    universe = universe,
    start = "2020-01-01",
    end = "2020-12-31",
    initial_cash = 100000,
    db_path = db_path_wrapper
  )

  con_direct <- ledgr:::get_connection(snap_direct)
  con_wrapper <- ledgr:::get_connection(snap_wrapper)

  cfg_json_direct <- DBI::dbGetQuery(
    con_direct,
    "SELECT config_json FROM runs WHERE run_id = ?",
    params = list(result_direct$run_id)
  )$config_json[[1]]
  cfg_json_wrapper <- DBI::dbGetQuery(
    con_wrapper,
    "SELECT config_json FROM runs WHERE run_id = ?",
    params = list(result_wrapper$run_id)
  )$config_json[[1]]

  cfg_direct <- jsonlite::fromJSON(cfg_json_direct, simplifyVector = FALSE)
  cfg_wrapper <- jsonlite::fromJSON(cfg_json_wrapper, simplifyVector = FALSE)
  cfg_direct$db_path <- NULL
  cfg_wrapper$db_path <- NULL
  cfg_direct$data$snapshot_db_path <- NULL
  cfg_wrapper$data$snapshot_db_path <- NULL
  testthat::expect_identical(
    ledgr:::canonical_json(cfg_direct),
    ledgr:::canonical_json(cfg_wrapper)
  )

  events1 <- get_ledger_events(con_direct, result_direct$run_id)
  events2 <- get_ledger_events(con_wrapper, result_wrapper$run_id)

  compare_cols <- c("event_seq", "ts_utc", "event_type", "instrument_id", "side", "qty", "price", "fee", "meta_json")
  testthat::expect_equal(nrow(events1), nrow(events2))
  testthat::expect_identical(events1[, compare_cols], events2[, compare_cols])

  eq1 <- get_final_equity(con_direct, result_direct$run_id)
  eq2 <- get_final_equity(con_wrapper, result_wrapper$run_id)
  testthat::expect_equal(eq1, eq2, tolerance = 1e-10)
})

testthat::test_that("functional strategies must return targets for the full universe", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  snap <- ledgr_snapshot_from_df(test_bars, db_path = db_path, snapshot_id = "snapshot_20200101_000000_abcd")
  on.exit(ledgr_snapshot_close(snap), add = TRUE)

  missing_target_strategy <- function(ctx) {
    c(TEST_A = 0)
  }

  testthat::expect_error(
    ledgr_backtest(
      snapshot = snap,
      strategy = missing_target_strategy,
      universe = c("TEST_A", "TEST_B"),
      start = "2020-01-01",
      end = "2020-12-31",
      initial_cash = 100000,
      db_path = db_path
    ),
    "a named numeric target vector with names matching ctx$universe",
    fixed = TRUE,
    class = "ledgr_invalid_strategy_result"
  )

  unnamed_target_strategy <- function(ctx) {
    c(0, 0)
  }

  testthat::expect_error(
    ledgr_backtest(
      snapshot = snap,
      strategy = unnamed_target_strategy,
      universe = c("TEST_A", "TEST_B"),
      start = "2020-01-01",
      end = "2020-12-31",
      initial_cash = 100000,
      db_path = db_path
    ),
    "a named numeric target vector with names matching ctx$universe",
    fixed = TRUE,
    class = "ledgr_invalid_strategy_result"
  )
})

testthat::test_that("ledgr_backtest data-first path matches explicit snapshot workflow", {
  db_path_data <- tempfile(fileext = ".duckdb")
  db_path_explicit <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path_data), add = TRUE)
  on.exit(unlink(db_path_explicit), add = TRUE)

  bt_data <- ledgr_backtest(
    data = test_bars,
    strategy = test_strategy,
    start = "2020-01-01",
    end = "2020-12-31",
    initial_cash = 100000,
    db_path = db_path_data
  )

  snap <- ledgr_snapshot_from_df(test_bars, db_path = db_path_explicit)
  on.exit(ledgr_snapshot_close(snap), add = TRUE)
  bt_explicit <- ledgr_backtest(
    snapshot = snap,
    strategy = test_strategy,
    universe = sort(unique(test_bars$instrument_id)),
    start = "2020-01-01",
    end = "2020-12-31",
    initial_cash = 100000,
    db_path = db_path_explicit
  )

  testthat::expect_identical(bt_data$config$universe$instrument_ids, sort(unique(test_bars$instrument_id)))

  con_data <- ledgr:::get_connection(bt_data)
  con_explicit <- ledgr:::get_connection(bt_explicit)
  bars_count <- DBI::dbGetQuery(con_data, "SELECT COUNT(*) AS n FROM bars")$n[[1]]
  testthat::expect_identical(as.integer(bars_count), 0L)

  events_data <- get_ledger_events(con_data, bt_data$run_id)
  events_explicit <- get_ledger_events(con_explicit, bt_explicit$run_id)
  compare_cols <- c("event_seq", "ts_utc", "event_type", "instrument_id", "side", "qty", "price", "fee", "meta_json")
  testthat::expect_identical(events_data[, compare_cols], events_explicit[, compare_cols])

  eq_data <- ledgr_compute_equity_curve(bt_data)
  eq_explicit <- ledgr_compute_equity_curve(bt_explicit)
  testthat::expect_equal(eq_data$equity, eq_explicit$equity, tolerance = 1e-10)
})

testthat::test_that("ledgr_backtest source validation and inference are clear", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  snap <- ledgr_snapshot_from_df(test_bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snap), add = TRUE)

  testthat::expect_error(
    ledgr_backtest(snapshot = snap, data = test_bars, strategy = test_strategy),
    "exactly one data source",
    class = "ledgr_invalid_args"
  )

  bt <- ledgr_backtest(
    data = snap,
    strategy = test_strategy,
    start = "2020-01-01",
    end = "2020-12-31",
    db_path = db_path
  )
  testthat::expect_identical(bt$config$universe$instrument_ids, sort(unique(test_bars$instrument_id)))

  bad_data <- test_bars
  bad_data$instrument_id <- NULL
  testthat::expect_error(
    ledgr_backtest(data = bad_data, strategy = test_strategy, start = "2020-01-01", end = "2020-12-31"),
    "instrument_id",
    class = "ledgr_invalid_args"
  )
})

testthat::test_that("functional strategy fingerprints include captured values", {
  target_qty <- 1
  key_one <- ledgr:::ledgr_register_strategy_fn(function(ctx) {
    stats::setNames(rep(target_qty, length(ctx$universe)), ctx$universe)
  })

  target_qty <- 2
  key_two <- ledgr:::ledgr_register_strategy_fn(function(ctx) {
    stats::setNames(rep(target_qty, length(ctx$universe)), ctx$universe)
  })

  testthat::expect_false(identical(key_one, key_two))

  captured_time <- Sys.time()
  testthat::expect_error(
    ledgr:::ledgr_register_strategy_fn(function(ctx) {
      captured_time
      stats::setNames(rep(0, length(ctx$universe)), ctx$universe)
    }),
    class = "ledgr_config_non_deterministic"
  )
})

testthat::test_that("default runtime context is data-frame compatible with pulse snapshot context", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  snap <- ledgr_snapshot_from_df(test_bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snap), add = TRUE)

  universe <- c("TEST_A", "TEST_B")
  ts_utc <- iso_utc(test_bars$ts_utc[[10]])
  ctx <- ledgr_pulse_snapshot(snap, universe = universe, ts_utc = ts_utc, features = list(ledgr_ind_sma(2)))
  on.exit(close(ctx), add = TRUE)
  testthat::expect_true(is.data.frame(ctx$bars))
  testthat::expect_true(is.data.frame(ctx$features))
  testthat::expect_true(is.function(ctx$feature))
  testthat::expect_true(is.data.frame(ctx$features_wide))
  testthat::expect_true("sma_2" %in% names(ctx$features_wide))

  data_frame_strategy <- function(ctx) {
    if (!is.data.frame(ctx$bars) || nrow(ctx$bars) != length(ctx$universe)) {
      stop("runtime bars context is not data-frame compatible")
    }
    if (!is.data.frame(ctx$features) || !all(c("instrument_id", "feature_name", "feature_value") %in% names(ctx$features))) {
      stop("runtime features context is not data-frame compatible")
    }
    if (!is.function(ctx$feature)) {
      stop("runtime feature accessor is missing")
    }
    if (!is.data.frame(ctx$features_wide) || !("sma_2" %in% names(ctx$features_wide))) {
      stop("runtime wide feature context is missing")
    }

    feature_value <- ctx$feature("TEST_A", "sma_2")
    long_value <- ctx$features$feature_value[
      ctx$features$instrument_id == "TEST_A" &
        ctx$features$feature_name == "sma_2"
    ][[1]]
    if (!identical(feature_value, long_value)) {
      stop("runtime feature accessor does not match long feature table")
    }

    stats::setNames(rep(0, length(ctx$universe)), ctx$universe)
  }

  testthat::expect_error(
    ledgr_backtest(
      snapshot = snap,
      strategy = data_frame_strategy,
      universe = universe,
      start = "2020-01-01",
      end = "2020-01-15",
      features = list(ledgr_ind_sma(2)),
      db_path = db_path
    ),
    NA
  )
})

testthat::test_that("backtest feature hydration uses indicator series_fn", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  calls <- new.env(parent = emptyenv())
  calls$series_fn <- 0L

  ind <- ledgr_indicator(
    id = "series_backtest_probe",
    fn = function(window) {
      stop("fallback fn should not be called when series_fn is available")
    },
    series_fn = function(bars, params = list()) {
      calls$series_fn <- calls$series_fn + 1L
      bars$close
    },
    requires_bars = 1L
  )

  strategy <- function(ctx) {
    value <- ctx$feature("TEST_A", "series_backtest_probe")
    if (!is.na(value) && value < 0) {
      stop("unexpected negative feature")
    }
    ctx$targets()
  }

  bt <- ledgr_backtest(
    data = test_bars,
    strategy = strategy,
    start = "2020-01-01",
    end = "2020-01-10",
    initial_cash = 1000,
    features = list(ind),
    db_path = db_path
  )
  on.exit(close(bt), add = TRUE)

  testthat::expect_identical(calls$series_fn, 2L)
  features <- DBI::dbGetQuery(
    ledgr:::get_connection(bt),
    "SELECT feature_name FROM features WHERE run_id = ?",
    params = list(bt$run_id)
  )
  testthat::expect_true("series_backtest_probe" %in% features$feature_name)
})
