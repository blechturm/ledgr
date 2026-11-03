testthat::test_that("ledgr_feature_contracts supports maps, named lists, unnamed lists, and indicators", {
  features <- ledgr_feature_map(
    ret = ledgr_ind_returns(5),
    sma = ledgr_ind_sma(10)
  )

  contracts <- ledgr_feature_contracts(features)
  testthat::expect_s3_class(contracts, "tbl_df")
  testthat::expect_equal(names(contracts), c("alias", "feature_id", "source", "requires_bars", "stable_after"))
  testthat::expect_equal(contracts$alias, c("ret", "sma"))
  testthat::expect_equal(contracts$feature_id, c("return_5", "sma_10"))
  testthat::expect_equal(contracts$source, c("ledgr", "ledgr"))

  named <- ledgr_feature_contracts(list(signal = ledgr_ind_returns(2)))
  testthat::expect_equal(named$alias, "signal")
  testthat::expect_equal(named$feature_id, "return_2")

  unnamed <- ledgr_feature_contracts(list(ledgr_ind_returns(2)))
  testthat::expect_true(is.na(unnamed$alias[[1]]))
  testthat::expect_equal(unnamed$feature_id, "return_2")

  single <- ledgr_feature_contracts(ledgr_ind_sma(3))
  testthat::expect_true(is.na(single$alias[[1]]))
  testthat::expect_equal(single$feature_id, "sma_3")

  custom <- ledgr_indicator(
    id = "custom_close",
    fn = function(window) tail(window$close, 1),
    requires_bars = 1
  )
  testthat::expect_equal(ledgr_feature_contracts(custom)$source, "custom")

  custom_matching_builtin_shape <- ledgr_indicator(
    id = "sma_10",
    fn = function(window) tail(window$close, 1),
    requires_bars = 10,
    params = list(n = 10)
  )
  testthat::expect_equal(ledgr_feature_contracts(custom_matching_builtin_shape)$source, "custom")

  testthat::expect_error(
    ledgr_feature_contracts(list(bad = "not an indicator")),
    class = "ledgr_invalid_args"
  )
})

# ledgr-test-profile: review
testthat::test_that("ledgr_feature_contracts identifies TTR-backed indicators when TTR is installed", {
  testthat::skip_if_not_installed("TTR")

  contracts <- ledgr_feature_contracts(
    ledgr_feature_map(rsi = ledgr_ind_ttr("RSI", input = "close", n = 14))
  )

  testthat::expect_equal(contracts$source, "TTR")
  testthat::expect_equal(contracts$feature_id, "ttr_rsi_14")
})

testthat::test_that("ledgr_feature_contract_check reports snapshot-specific warmup feasibility", {
  bars <- ledgr_test_make_bars(c("AAA", "BBB"), as.Date("2020-01-01") + 0:7)
  bars <- bars[!(bars$instrument_id == "BBB" & bars$ts_utc > ledgr_utc("2020-01-04")), , drop = FALSE]
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  features <- ledgr_feature_map(
    ret = ledgr_ind_returns(3),
    sma = ledgr_ind_sma(6)
  )
  check <- ledgr_feature_contract_check(snapshot, features)

  testthat::expect_s3_class(check, "tbl_df")
  testthat::expect_equal(
    names(check),
    c(
      "alias", "instrument_id", "feature_id", "source",
      "requires_bars", "stable_after", "available_bars", "warmup_achievable"
    )
  )
  testthat::expect_equal(nrow(check), 4L)
  testthat::expect_equal(check$instrument_id, c("AAA", "AAA", "BBB", "BBB"))
  testthat::expect_equal(check$feature_id, rep(c("return_3", "sma_6"), times = 2))
  testthat::expect_equal(check$alias, rep(c("ret", "sma"), times = 2))

  aaa_sma <- check[check$instrument_id == "AAA" & check$feature_id == "sma_6", , drop = FALSE]
  bbb_sma <- check[check$instrument_id == "BBB" & check$feature_id == "sma_6", , drop = FALSE]
  testthat::expect_equal(aaa_sma$available_bars, 8L)
  testthat::expect_true(aaa_sma$warmup_achievable)
  testthat::expect_equal(bbb_sma$available_bars, 4L)
  testthat::expect_false(bbb_sma$warmup_achievable)
})

testthat::test_that("ledgr_feature_contract_check supports indicator and list inputs without mutating snapshots", {
  bars <- ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:4)
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  before <- ledgr_snapshot_info(snapshot)$bar_count[[1]]

  single <- ledgr_feature_contract_check(snapshot, ledgr_ind_sma(3))
  testthat::expect_equal(single$feature_id, "sma_3")
  testthat::expect_true(is.na(single$alias[[1]]))
  testthat::expect_true(single$warmup_achievable[[1]])

  named <- ledgr_feature_contract_check(snapshot, list(signal = ledgr_ind_returns(2)))
  testthat::expect_equal(named$alias, "signal")
  testthat::expect_equal(named$feature_id, "return_2")

  after <- ledgr_snapshot_info(snapshot)$bar_count[[1]]
  testthat::expect_identical(after, before)
})

testthat::test_that("ledgr_feature_contract_check rejects feature factories without concrete params", {
  bars <- ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:4)
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  factory <- function(params) {
    list(ledgr_ind_sma(params$n))
  }

  testthat::expect_error(
    ledgr_feature_contract_check(snapshot, factory),
    class = "ledgr_feature_factory_requires_params"
  )
})

testthat::test_that("[LTB-0112] feature inspection refuses unresolved maps", {
  features <- ledgr_feature_map(
    fast = ledgr_ind_sma(ledgr_param("fast_n")),
    baseline = ledgr_ind_sma(4)
  )
  expected_message <- paste(
    "`features` contains parameterized declarations.",
    "Supply concrete values through `feature_params` before inspection."
  )

  contracts_error <- rlang::catch_cnd(ledgr_feature_contracts(features))
  testthat::expect_s3_class(
    contracts_error,
    "ledgr_feature_factory_requires_params"
  )
  testthat::expect_identical(conditionMessage(contracts_error), expected_message)

  bars <- ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:4)
  snapshot <- ledgr_snapshot_from_df(
    bars,
    db_path = tempfile(fileext = ".duckdb")
  )
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  check_error <- rlang::catch_cnd(
    ledgr_feature_contract_check(snapshot, features)
  )
  testthat::expect_s3_class(
    check_error,
    "ledgr_feature_factory_requires_params"
  )
  testthat::expect_identical(conditionMessage(check_error), expected_message)

  concrete <- ledgr_feature_map(
    fast = ledgr_ind_sma(2),
    baseline = ledgr_ind_sma(4)
  )
  testthat::expect_identical(
    ledgr_feature_contracts(concrete),
    tibble::tibble(
      alias = c("fast", "baseline"),
      feature_id = c("sma_2", "sma_4"),
      source = c("ledgr", "ledgr"),
      requires_bars = c(2L, 4L),
      stable_after = c(2L, 4L)
    )
  )

  validation_calls <- 0L
  original_validate <- ledgr:::ledgr_validate_feature_map_object
  testthat::local_mocked_bindings(
    ledgr_validate_feature_map_object = function(x) {
      validation_calls <<- validation_calls + 1L
      original_validate(x)
    },
    .package = "ledgr"
  )
  ledgr_feature_contracts(concrete)
  testthat::expect_identical(validation_calls, 1L)
})

testthat::test_that("[LTB-0186] feature params resolve inspection like execution", {
  bars <- ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:5)
  snapshot <- ledgr_snapshot_from_df(
    bars,
    db_path = tempfile(fileext = ".duckdb")
  )
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  features <- ledgr_feature_map(
    fast = ledgr_ind_sma(ledgr_param("fast_n")),
    baseline = ledgr_ind_sma(4L)
  )
  before <- features
  params <- list(fast_n = 2L)
  contracts <- ledgr_feature_contracts(features, feature_params = params)
  checked <- ledgr_feature_contract_check(
    snapshot,
    features,
    feature_params = params
  )
  expected_map <- c(fast = "sma_2", baseline = "sma_4")

  testthat::expect_identical(contracts$alias, names(expected_map))
  testthat::expect_identical(contracts$feature_id, unname(expected_map))
  testthat::expect_identical(
    unique(checked[, c("alias", "feature_id")]),
    contracts[, c("alias", "feature_id")]
  )
  pulse <- ledgr_pulse_snapshot(
    snapshot,
    universe = "AAA",
    ts_utc = max(bars$ts_utc),
    features = features,
    feature_params = params
  )
  on.exit(close(pulse), add = TRUE)
  testthat::expect_identical(
    unclass(pulse)[[".pulse_lookup"]]$feature_lookup$name_lookup$alias_map,
    expected_map
  )
  for (removed in c("feature_params", "active_alias_map", "alias_map_json", "alias_map_hash", "alias_map_version")) {
    testthat::expect_error(pulse[[removed]], class = "ledgr_unknown_context_field")
  }

  run <- ledgr_run(
    ledgr_experiment(
      snapshot,
      function(ctx, params) ctx$flat(),
      features = features,
      cost_model = ledgr_cost_zero(),
      opening = ledgr_opening(cash = 100000)
    ),
    feature_params = params,
    run_id = "feature-contract-params"
  )
  on.exit(close(run), add = TRUE)
  run_map <- ledgr:::ledgr_alias_map_from_json(run$config$alias_map_json)
  testthat::expect_identical(run_map[names(expected_map)], expected_map)
  testthat::expect_identical(features, before)
  testthat::expect_identical(
    names(formals(ledgr_feature_contracts)),
    c("features", "feature_params")
  )
  testthat::expect_identical(
    names(formals(ledgr_feature_contract_check)),
    c("snapshot", "features", "feature_params")
  )
  testthat::expect_error(
    ledgr_feature_contracts(features, feature_params = 2L),
    "`feature_params` must be NULL or a list.",
    class = "ledgr_invalid_args",
    fixed = TRUE
  )
  testthat::expect_error(
    ledgr_feature_contracts(features, feature_params = list()),
    regexp = "alias `fast` argument `n`",
    class = "ledgr_param_missing"
  )
  testthat::expect_error(
    ledgr_feature_contracts(
      function(params) list(ledgr_ind_sma(params$n)),
      feature_params = list(n = 2L)
    ),
    class = "ledgr_feature_factory_requires_params"
  )
})

testthat::test_that("pulse feature views expose long and wide pulse-known data", {
  bars <- ledgr_test_make_bars(c("AAA", "BBB"), as.Date("2020-01-01") + 0:5)
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  features <- ledgr_feature_map(
    ret = ledgr_ind_returns(2),
    sma = ledgr_ind_sma(3)
  )
  pulse <- ledgr_pulse_snapshot(
    snapshot,
    universe = c("AAA", "BBB"),
    ts_utc = ledgr_utc("2020-01-06"),
    features = features,
    cash = 1000
  )
  on.exit(close(pulse), add = TRUE)

  long_all <- ledgr_pulse_features(pulse)
  testthat::expect_s3_class(long_all, "tbl_df")
  testthat::expect_equal(names(long_all), c("ts_utc", "instrument_id", "feature_id", "feature_value", "alias"))
  testthat::expect_s3_class(long_all$ts_utc, "POSIXct")
  testthat::expect_equal(long_all$instrument_id, rep(c("AAA", "BBB"), each = 2))
  testthat::expect_equal(long_all$feature_id, rep(c("return_2", "sma_3"), times = 2))
  testthat::expect_equal(long_all$alias, rep(c("ret", "sma"), times = 2))
  testthat::expect_true(all(c("return_2", "sma_3") %in% long_all$feature_id))

  long_mapped <- ledgr_pulse_features(pulse, features)
  testthat::expect_s3_class(long_mapped, "tbl_df")
  testthat::expect_equal(long_mapped$instrument_id, rep(c("AAA", "BBB"), each = 2))
  testthat::expect_equal(long_mapped$alias, rep(c("ret", "sma"), times = 2))
  testthat::expect_equal(long_mapped$feature_id, rep(c("return_2", "sma_3"), times = 2))

  wide <- ledgr_pulse_wide(pulse, features)
  testthat::expect_s3_class(wide, "tbl_df")
  testthat::expect_equal(nrow(wide), 1L)
  testthat::expect_true(all(c("ts_utc", "cash", "equity") %in% names(wide)))
  testthat::expect_s3_class(wide$ts_utc, "POSIXct")
  testthat::expect_equal(
    names(wide),
    c(
      "ts_utc", "cash", "equity",
      "AAA__ohlcv_open", "AAA__ohlcv_high", "AAA__ohlcv_low", "AAA__ohlcv_close", "AAA__ohlcv_volume",
      "AAA__feature_ret", "AAA__feature_sma",
      "BBB__ohlcv_open", "BBB__ohlcv_high", "BBB__ohlcv_low", "BBB__ohlcv_close", "BBB__ohlcv_volume",
      "BBB__feature_ret", "BBB__feature_sma"
    )
  )

  testthat::expect_equal(wide[["AAA__ohlcv_close"]], pulse$close[["AAA"]])
  testthat::expect_equal(wide[["BBB__ohlcv_volume"]], pulse$volume[["BBB"]])
  testthat::expect_equal(wide[["AAA__feature_ret"]], pulse$return_2[["AAA"]])
  testthat::expect_equal(wide[["BBB__feature_sma"]], pulse$sma_3[["BBB"]])

  wide_all <- ledgr_pulse_wide(pulse)
  testthat::expect_s3_class(wide_all, "tbl_df")
  testthat::expect_equal(
    names(wide_all),
    c(
      "ts_utc", "cash", "equity",
      "AAA__ohlcv_open", "AAA__ohlcv_high", "AAA__ohlcv_low", "AAA__ohlcv_close", "AAA__ohlcv_volume",
      "AAA__feature_ret", "AAA__feature_sma",
      "BBB__ohlcv_open", "BBB__ohlcv_high", "BBB__ohlcv_low", "BBB__ohlcv_close", "BBB__ohlcv_volume",
      "BBB__feature_ret", "BBB__feature_sma"
    )
  )

  testthat::expect_error(
    ledgr_validate_pulse_wide_names(instruments = "AA__A", feature_ids = "return_2"),
    class = "ledgr_invalid_pulse_wide_names"
  )
  testthat::expect_error(
    ledgr_validate_pulse_wide_names(instruments = "AAA", feature_ids = "bad__feature"),
    regexp = "Feature ID or alias",
    class = "ledgr_invalid_pulse_wide_names"
  )
})

# ledgr-test-profile: fast
testthat::test_that("[LTB-0549] pulse inspection manifests prepared primitives directly", {
  bars <- ledgr_test_make_bars(c("BBB", "AAA"), as.Date("2020-01-01") + 0:5)
  snapshot <- ledgr_snapshot_from_df(
    bars,
    db_path = tempfile(fileext = ".duckdb")
  )
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  features <- ledgr_feature_map(
    z_ret = ledgr_ind_returns(2),
    a_sma = ledgr_ind_sma(3)
  )
  pulse <- testthat::with_mocked_bindings(
    ledgr_pulse_snapshot(
      snapshot,
      universe = c("BBB", "AAA"),
      ts_utc = ledgr_utc("2020-01-06"),
      features = features,
      cash = 1000
    ),
    ledgr_pulse_context_fixture_cutoff = function(...) {
      stop("production pulse preparation must not parse its cutoff")
    },
    .package = "ledgr"
  )
  on.exit(close(pulse), add = TRUE)

  long <- testthat::with_mocked_bindings(
    ledgr_pulse_features(pulse),
    ledgr_pulse_context_fixture_cutoff = function(...) {
      stop("inspection must use its prepared numeric cutoff")
    },
    .package = "ledgr"
  )
  testthat::expect_identical(
    long$ts_utc,
    rep(ledgr_utc("2020-01-06"), 4L)
  )
  testthat::expect_identical(
    long$instrument_id,
    rep(c("BBB", "AAA"), each = 2L)
  )
  testthat::expect_identical(
    long$feature_id,
    rep(c("return_2", "sma_3"), times = 2L)
  )
  testthat::expect_identical(
    long$alias,
    rep(c("z_ret", "a_sma"), times = 2L)
  )
  testthat::expect_identical(
    long$feature_value,
    c(
      pulse$return_2[["BBB"]], pulse$sma_3[["BBB"]],
      pulse$return_2[["AAA"]], pulse$sma_3[["AAA"]]
    )
  )

  original_lookup <- unclass(pulse)[[".pulse_lookup"]]
  shifted_lookup <- list2env(
    as.list.environment(original_lookup, all.names = TRUE),
    parent = emptyenv()
  )
  shifted_lookup$cutoff_num <- original_lookup$cutoff_num + 86400
  shifted_raw <- unclass(pulse)
  shifted_raw[[".pulse_lookup"]] <- shifted_lookup
  shifted <- structure(shifted_raw, class = class(pulse))
  shifted_time <- structure(
    shifted_lookup$cutoff_num,
    class = c("POSIXct", "POSIXt"),
    tzone = "UTC"
  )
  testthat::expect_identical(
    ledgr_pulse_features(shifted)$ts_utc,
    rep(shifted_time, 4L)
  )
  testthat::expect_identical(ledgr_pulse_wide(shifted)$ts_utc, shifted_time)

  counted_lookup <- list2env(
    as.list.environment(original_lookup, all.names = TRUE),
    parent = emptyenv()
  )
  original_vector <- original_lookup$feature_vector
  calls <- 0L
  counted_lookup$feature_vector <- function(feature_id, default = NA_real_) {
    calls <<- calls + 1L
    original_vector(feature_id, default = default)
  }
  raw <- unclass(pulse)
  raw[[".pulse_lookup"]] <- counted_lookup
  counted <- structure(raw, class = "ledgr_pulse_context")

  testthat::expect_identical(ledgr_pulse_features(counted), long)
  testthat::expect_identical(calls, 2L)
  calls <- 0L
  wide <- testthat::with_mocked_bindings(
    ledgr_pulse_wide(counted),
    ledgr_pulse_features = function(...) stop("wide inspection must not build long rows"),
    ledgr_pulse_context_fixture_cutoff = function(...) {
      stop("inspection must use its prepared numeric cutoff")
    },
    .package = "ledgr"
  )
  testthat::expect_identical(calls, 2L)
  testthat::expect_identical(
    names(wide),
    c(
      "ts_utc", "cash", "equity",
      "AAA__ohlcv_open", "AAA__ohlcv_high", "AAA__ohlcv_low",
      "AAA__ohlcv_close", "AAA__ohlcv_volume",
      "AAA__feature_z_ret", "AAA__feature_a_sma",
      "BBB__ohlcv_open", "BBB__ohlcv_high", "BBB__ohlcv_low",
      "BBB__ohlcv_close", "BBB__ohlcv_volume",
      "BBB__feature_z_ret", "BBB__feature_a_sma"
    )
  )
  testthat::expect_identical(wide$ts_utc, ledgr_utc("2020-01-06"))
  testthat::expect_identical(wide$AAA__feature_z_ret, pulse$return_2[["AAA"]])
  testthat::expect_identical(wide$BBB__feature_a_sma, pulse$sma_3[["BBB"]])

  long_source <- paste(deparse(ledgr_pulse_features), collapse = "\n")
  wide_source <- paste(deparse(ledgr_pulse_wide), collapse = "\n")
  time_source <- paste(
    deparse(ledgr:::ledgr_pulse_inspection_time),
    collapse = "\n"
  )
  for (forbidden in c("ledgr_utc", "tibble::tibble(", "rbind(")) {
    testthat::expect_false(grepl(forbidden, long_source, fixed = TRUE), info = forbidden)
  }
  for (forbidden in c(
    "ledgr_pulse_features(", "pivot(", "tibble::as_tibble(", "rows$",
    "ledgr_utc", "rbind("
  )) {
    testthat::expect_false(grepl(forbidden, wide_source, fixed = TRUE), info = forbidden)
  }
  for (forbidden in c("ledgr_utc", "as.POSIXct", "as.POSIXlt", "strptime", "grepl")) {
    testthat::expect_false(grepl(forbidden, time_source, fixed = TRUE), info = forbidden)
  }
})

testthat::test_that("pulse snapshots resolve active aliases with feature params", {
  bars <- ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:5)
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  features <- ledgr_feature_map(
    z_short = ledgr_ind_sma(ledgr_param("fast_n")),
    a_long = ledgr_ind_sma(ledgr_param("slow_n"))
  )
  pulse <- ledgr_pulse_snapshot(
    snapshot,
    universe = "AAA",
    ts_utc = ledgr_utc("2020-01-06"),
    features = features,
    feature_params = list(fast_n = 2L, slow_n = 3L)
  )
  on.exit(close(pulse), add = TRUE)

  x <- c(z_short = pulse$z_short[["AAA"]], a_long = pulse$a_long[["AAA"]])
  testthat::expect_identical(names(x), c("z_short", "a_long"))
  testthat::expect_identical(
    unclass(pulse)[[".pulse_lookup"]]$feature_lookup$name_lookup$alias_map,
    c(z_short = "sma_2", a_long = "sma_3")
  )
  testthat::expect_error(pulse$alias_map_hash, class = "ledgr_unknown_context_field")

  long <- ledgr_pulse_features(pulse)
  testthat::expect_identical(long$alias, c("z_short", "a_long"))
  testthat::expect_identical(long$feature_id, c("sma_2", "sma_3"))

  wide <- ledgr_pulse_wide(pulse)
  testthat::expect_true("AAA__feature_z_short" %in% names(wide))
  testthat::expect_false("AAA__feature_sma_2" %in% names(wide))

  exact <- ledgr_pulse_features(pulse, c(raw_fast = "sma_2"))
  testthat::expect_identical(exact$alias, "raw_fast")
  testthat::expect_identical(exact$feature_id, "sma_2")
})

testthat::test_that("pulse snapshots name missing feature params by alias and argument", {
  bars <- ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:5)
  snapshot <- ledgr_snapshot_from_df(bars, db_path = tempfile(fileext = ".duckdb"))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  features <- ledgr_feature_map(fast = ledgr_ind_sma(ledgr_param("fast_n")))

  testthat::expect_error(
    ledgr_pulse_snapshot(
      snapshot,
      universe = "AAA",
      ts_utc = ledgr_utc("2020-01-06"),
      features = features
    ),
    regexp = "alias `fast` argument `n`",
    class = "ledgr_param_missing"
  )
})

testthat::test_that("feature inspection views fail loudly for unregistered mapped feature IDs", {
  bars <- ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:5)
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  pulse <- ledgr_pulse_snapshot(
    snapshot,
    universe = "AAA",
    ts_utc = ledgr_utc("2020-01-06"),
    features = list(ledgr_ind_sma(3))
  )
  on.exit(close(pulse), add = TRUE)

  testthat::expect_error(
    ledgr_pulse_features(pulse, ledgr_feature_map(ret = ledgr_ind_returns(2))),
    class = "ledgr_unknown_feature_id"
  )
})

# ledgr-test-profile: heavy_protocol
testthat::test_that("feature inspection views match across execution modes", {
  bars <- ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:3)
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  features <- ledgr_feature_map(ret = ledgr_ind_returns(2), sma = ledgr_ind_sma(3))
  observed <- new.env(parent = emptyenv())
  strategy <- function(ctx, params) {
    # Overwrite on each pulse and retain the terminal pulse for parity checks.
    long <- ledgr_pulse_features(ctx, features)
    wide <- ledgr_pulse_wide(ctx, features)
    long_all <- ledgr_pulse_features(ctx)
    wide_all <- ledgr_pulse_wide(ctx)
    testthat::expect_gt(nrow(long), 0L)
    testthat::expect_true(any(grepl("__feature_", names(wide), fixed = TRUE)))
    testthat::expect_gt(nrow(long_all), 0L)
    testthat::expect_true(any(grepl("__feature_", names(wide_all), fixed = TRUE)))
    long$ts_utc <- format(long$ts_utc, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
    wide$ts_utc <- format(wide$ts_utc, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
    long_all$ts_utc <- format(long_all$ts_utc, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
    wide_all$ts_utc <- format(wide_all$ts_utc, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
    observed[[ctx$run_id]] <- list(
      long = long,
      wide = wide,
      long_all = long_all,
      wide_all = wide_all
    )
    targets <- ctx$flat()
    x <- c(ret = ctx$ret[["AAA"]], sma = ctx$sma[["AAA"]])
    if (ledgr_passed_warmup(x) && x[["ret"]] > 0) {
      targets["AAA"] <- 1
    }
    targets
  }

  for (mode in c("audit_log", "db_live")) {
    local({
      exp <- ledgr_experiment(
        snapshot = snapshot,
        strategy = strategy,
        features = features,
        opening = ledgr_opening(cash = 1000),
        execution_mode = mode,
      cost_model = ledgr_cost_zero()
      )
      bt <- ledgr_run(exp, params = list(), run_id = paste0("inspection-", mode))
      on.exit(close(bt), add = TRUE)
    })
  }

  audit <- observed[["inspection-audit_log"]]
  live <- observed[["inspection-db_live"]]
  testthat::expect_equal(audit$long$feature_id, live$long$feature_id)
  testthat::expect_equal(audit$long$alias, live$long$alias)
  testthat::expect_equal(audit$long$feature_value, live$long$feature_value, tolerance = 1e-8)
  testthat::expect_equal(names(audit$wide), names(live$wide))
  testthat::expect_equal(audit$wide, live$wide, tolerance = 1e-8)
  testthat::expect_equal(audit$long_all$feature_id, live$long_all$feature_id)
  testthat::expect_equal(audit$long_all$alias, live$long_all$alias)
  testthat::expect_equal(audit$long_all$feature_value, live$long_all$feature_value, tolerance = 1e-8)
  testthat::expect_equal(names(audit$wide_all), names(live$wide_all))
  testthat::expect_equal(audit$wide_all, live$wide_all, tolerance = 1e-8)
})
