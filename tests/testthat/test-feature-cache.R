testthat::test_that("session feature cache reuses series by snapshot hash", {
  ledgr_clear_feature_cache()
  on.exit(ledgr_clear_feature_cache(), add = TRUE)

  calls <- new.env(parent = emptyenv())
  calls$n <- 0L

  ind <- ledgr_indicator(
    id = "cache_probe",
    fn = function(window) {
      stop("series_fn should be used for cache probe")
    },
    series_fn = function(bars, params = list()) {
      calls$n <- calls$n + 1L
      bars$close
    },
    requires_bars = 1L
  )

  strategy <- function(ctx, params) {
    value <- ctx$feature("TEST_A", "cache_probe")
    if (!is.na(value) && value < 0) {
      stop("unexpected negative feature")
    }
    ctx$flat()
  }

  db_path_a <- tempfile(fileext = ".duckdb")
  db_path_b <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path_a), add = TRUE)
  on.exit(unlink(db_path_b), add = TRUE)

  bars <- test_bars[test_bars$instrument_id == "TEST_A", , drop = FALSE]

  snap_a <- ledgr_snapshot_from_df(bars, db_path = db_path_a, snapshot_id = "snapshot_20200101_000000_caca")
  on.exit(ledgr_snapshot_close(snap_a), add = TRUE)
  snap_b <- ledgr_snapshot_from_df(bars, db_path = db_path_b, snapshot_id = "snapshot_20200101_000000_cacb")
  on.exit(ledgr_snapshot_close(snap_b), add = TRUE)

  bt_a <- ledgr_backtest(
    snapshot = snap_a,
    strategy = strategy,
    universe = "TEST_A",
    start = "2020-01-01",
    end = "2020-01-10",
    initial_cash = 1000,
    run_id = "cache-run-a",
    features = list(ind),
    db_path = db_path_a,
  cost_model = ledgr_cost_zero()
  )
  on.exit(close(bt_a), add = TRUE)

  telemetry_a <- ledgr:::ledgr_get_run_telemetry(bt_a$run_id)
  testthat::expect_identical(calls$n, 1L)
  testthat::expect_identical(as.integer(telemetry_a$feature_cache_misses), 1L)
  testthat::expect_identical(as.integer(telemetry_a$feature_cache_hits), 0L)

  bt_b <- ledgr_backtest(
    snapshot = snap_b,
    strategy = strategy,
    universe = "TEST_A",
    start = "2020-01-01",
    end = "2020-01-10",
    initial_cash = 1000,
    run_id = "cache-run-b",
    features = list(ind),
    db_path = db_path_b,
  cost_model = ledgr_cost_zero()
  )
  on.exit(close(bt_b), add = TRUE)

  telemetry_b <- ledgr:::ledgr_get_run_telemetry(bt_b$run_id)
  testthat::expect_identical(calls$n, 1L)
  testthat::expect_identical(as.integer(telemetry_b$feature_cache_misses), 0L)
  testthat::expect_identical(as.integer(telemetry_b$feature_cache_hits), 1L)

  bench <- ledgr_backtest_bench(bt_b)
  testthat::expect_true(all(c("feature_cache_hits", "feature_cache_misses") %in% bench$component))
  testthat::expect_equal(bench$mean[bench$component == "feature_cache_hits"], 1)
  testthat::expect_equal(bench$mean[bench$component == "feature_cache_misses"], 0)
})

testthat::test_that("ledgr_clear_feature_cache removes cached series", {
  ledgr_clear_feature_cache()
  on.exit(ledgr_clear_feature_cache(), add = TRUE)

  bars <- test_bars[test_bars$instrument_id == "TEST_A", , drop = FALSE]
  def <- list(
    id = "clear_probe",
    requires_bars = 1L,
    stable_after = 1L,
    fn = function(window) tail(window$close, 1),
    series_fn = function(bars, params = list()) bars$close,
    params = list()
  )
  key <- ledgr:::ledgr_feature_cache_key(
    snapshot_hash = "hash-for-clear-test",
    instrument_id = "TEST_A",
    feature_def = def,
    start_ts_utc = "2020-01-01T00:00:00Z",
    end_ts_utc = "2020-01-10T00:00:00Z"
  )
  ledgr:::ledgr_feature_cache_set(key, seq_len(nrow(bars)))
  testthat::expect_false(is.null(ledgr:::ledgr_feature_cache_get(key, expected_len = nrow(bars))))

  removed <- ledgr_clear_feature_cache()
  testthat::expect_identical(removed, 1L)
  testthat::expect_true(is.null(ledgr:::ledgr_feature_cache_get(key, expected_len = nrow(bars))))
})

testthat::test_that("feature cache key changes with indicator identity and date range", {
  base_def <- list(
    id = "key_probe",
    requires_bars = 1L,
    stable_after = 1L,
    fn = function(window) tail(window$close, 1),
    series_fn = function(bars, params = list()) bars$close,
    params = list()
  )
  changed_def <- base_def
  changed_def$series_fn <- function(bars, params = list()) bars$close * 2

  key_a <- ledgr:::ledgr_feature_cache_key(
    snapshot_hash = "same-snapshot-hash",
    instrument_id = "TEST_A",
    feature_def = base_def,
    start_ts_utc = "2020-01-01T00:00:00Z",
    end_ts_utc = "2020-01-10T00:00:00Z"
  )
  key_b <- ledgr:::ledgr_feature_cache_key(
    snapshot_hash = "same-snapshot-hash",
    instrument_id = "TEST_A",
    feature_def = changed_def,
    start_ts_utc = "2020-01-01T00:00:00Z",
    end_ts_utc = "2020-01-10T00:00:00Z"
  )
  key_c <- ledgr:::ledgr_feature_cache_key(
    snapshot_hash = "same-snapshot-hash",
    instrument_id = "TEST_A",
    feature_def = base_def,
    start_ts_utc = "2020-01-02T00:00:00Z",
    end_ts_utc = "2020-01-10T00:00:00Z"
  )

  testthat::expect_false(identical(key_a, key_b))
  testthat::expect_false(identical(key_a, key_c))
  testthat::expect_true(nzchar(ledgr:::ledgr_feature_engine_version()))
  testthat::expect_false(identical(ledgr:::ledgr_feature_engine_version(), "v0.1.4-series-fn-1"))
})

testthat::test_that("feature cache key is a deterministic length-prefixed session key", {
  def <- list(
    id = "key_probe",
    requires_bars = 1L,
    stable_after = 1L,
    fn = function(window) tail(window$close, 1),
    series_fn = function(bars, params = list()) bars$close,
    params = list()
  )

  key <- ledgr:::ledgr_feature_cache_key(
    snapshot_hash = "hash|with:delimiters",
    instrument_id = "TEST|A:1",
    feature_def = def,
    start_ts_utc = "2020-01-01T00:00:00Z",
    end_ts_utc = "2020-01-10T00:00:00Z"
  )
  same <- ledgr:::ledgr_feature_cache_key(
    snapshot_hash = "hash|with:delimiters",
    instrument_id = "TEST|A:1",
    feature_def = def,
    start_ts_utc = "2020-01-01T00:00:00Z",
    end_ts_utc = "2020-01-10T00:00:00Z"
  )
  different <- ledgr:::ledgr_feature_cache_key(
    snapshot_hash = "hash|with:delimiters",
    instrument_id = "TEST|A:10",
    feature_def = def,
    start_ts_utc = "2020-01-01T00:00:00Z",
    end_ts_utc = "2020-01-10T00:00:00Z"
  )

  testthat::expect_match(key, "^ledgr_feature_cache_v2\\|", perl = TRUE)
  testthat::expect_identical(key, same)
  testthat::expect_false(identical(key, different))
})

testthat::test_that("hoisted feature cache key parts match canonical key", {
  expect_key_parity <- function(def) {
    fingerprint <- ledgr:::ledgr_feature_def_fingerprint(def)
    engine_version <- ledgr:::ledgr_feature_engine_version()

    canonical <- ledgr:::ledgr_feature_cache_key(
      snapshot_hash = "same-snapshot-hash",
      instrument_id = "TEST_A",
      feature_def = def,
      start_ts_utc = "2020-01-01T00:00:00Z",
      end_ts_utc = "2020-01-10T00:00:00Z"
    )
    hoisted <- ledgr:::ledgr_feature_cache_key_from_parts(
      snapshot_hash = "same-snapshot-hash",
      instrument_id = "TEST_A",
      feature_fingerprint = fingerprint,
      feature_engine_version = engine_version,
      start_ts_utc = "2020-01-01T00:00:00Z",
      end_ts_utc = "2020-01-10T00:00:00Z"
    )

    testthat::expect_identical(hoisted, canonical)
  }

  scalar_def <- list(
    id = "scalar_probe",
    requires_bars = 1L,
    stable_after = 1L,
    fn = function(window) tail(window$close, 1),
    series_fn = function(bars, params = list()) bars$close,
    params = list()
  )
  parameterized_def <- scalar_def
  parameterized_def$id <- "parameterized_probe"
  parameterized_def$params <- list(n = 5L, method = "sma")
  explicit_def <- scalar_def
  explicit_def$id <- "explicit_probe"
  explicit_def$fingerprint <- "explicit-feature-fingerprint"

  expect_key_parity(scalar_def)
  expect_key_parity(parameterized_def)
  expect_key_parity(explicit_def)
})

testthat::test_that("hoisted feature cache key parts match bundle output keys", {
  testthat::skip_if_not_installed("TTR")

  bundle <- ledgr_ind_ttr_outputs("BBands", input = "close", outputs = c("dn", "up"), n = 5)
  defs <- ledgr:::ledgr_precompute_feature_defs_from_indicators(
    ledgr:::ledgr_indicator_bundle_indicators(bundle)
  )

  for (def in defs) {
    canonical <- ledgr:::ledgr_feature_cache_key(
      snapshot_hash = "same-snapshot-hash",
      instrument_id = "TEST_A",
      feature_def = def,
      start_ts_utc = "2020-01-01T00:00:00Z",
      end_ts_utc = "2020-01-10T00:00:00Z"
    )
    hoisted <- ledgr:::ledgr_feature_cache_key_from_parts(
      snapshot_hash = "same-snapshot-hash",
      instrument_id = "TEST_A",
      feature_fingerprint = ledgr:::ledgr_feature_def_fingerprint(def),
      feature_engine_version = ledgr:::ledgr_feature_engine_version(),
      start_ts_utc = "2020-01-01T00:00:00Z",
      end_ts_utc = "2020-01-10T00:00:00Z"
    )
    testthat::expect_identical(hoisted, canonical)
  }
})
