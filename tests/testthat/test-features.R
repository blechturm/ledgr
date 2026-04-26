insert_test_run <- function(con, run_id) {
  DBI::dbExecute(
    con,
    "
    INSERT INTO runs (
      run_id,
      created_at_utc,
      engine_version,
      config_json,
      config_hash,
      data_hash,
      status,
      error_msg
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ",
    params = list(
      run_id,
      as.POSIXct("2020-01-01 00:00:00", tz = "UTC"),
      "0.1.0",
      "{}",
      "config-hash",
      "data-hash",
      "CREATED",
      NA_character_
    )
  )
}

make_test_bars <- function(instrument_ids, start_ts_utc, n) {
  start <- as.POSIXct(start_ts_utc, tz = "UTC", format = "%Y-%m-%d %H:%M:%S")
  if (is.na(start)) start <- as.POSIXct(start_ts_utc, tz = "UTC")
  ts <- start + (seq_len(n) - 1L) * 86400
  ts <- as.POSIXct(ts, origin = "1970-01-01", tz = "UTC")
  out <- do.call(
    rbind,
    lapply(seq_along(instrument_ids), function(i) {
      instrument_id <- instrument_ids[[i]]
      base <- 100 + i * 10
      data.frame(
        instrument_id = instrument_id,
        ts_utc = ts,
        open = base + seq_len(n) * 0.1,
        high = base + seq_len(n) * 0.1 + 0.5,
        low = base + seq_len(n) * 0.1 - 0.5,
        close = base + seq_len(n) * 0.1 + 0.2,
        volume = 1000 + seq_len(n),
        stringsAsFactors = FALSE
      )
    })
  )
  out$ts_utc <- as.POSIXct(out$ts_utc, tz = "UTC")
  out
}

normalize_features_df <- function(df) {
  df <- df[order(df$instrument_id, df$ts_utc, df$feature_name), , drop = FALSE]
  df$ts_utc <- format(as.POSIXct(df$ts_utc, tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  df$feature_value <- as.numeric(df$feature_value)
  df
}

testthat::test_that("feature definitions are validated fail-loud", {
  good <- list(
    id = "x",
    requires_bars = 1L,
    stable_after = 1L,
    fn = function(window_bars_df) 1.0,
    params = list()
  )
  testthat::expect_true(ledgr:::ledgr_validate_feature_def(good))

  testthat::expect_error(
    ledgr:::ledgr_validate_feature_def(list(requires_bars = 1L, stable_after = 1L, fn = function(w) 1.0)),
    "feature_def$id",
    fixed = TRUE
  )

  testthat::expect_error(
    ledgr:::ledgr_validate_feature_def(list(id = "x", requires_bars = 0L, stable_after = 0L, fn = function(w) 1.0)),
    "requires_bars",
    fixed = TRUE
  )

  testthat::expect_error(
    ledgr:::ledgr_validate_feature_def(list(id = "x", requires_bars = 2L, stable_after = 1L, fn = function(w) 1.0)),
    "stable_after",
    fixed = TRUE
  )

  testthat::expect_error(
    ledgr:::ledgr_validate_feature_def(list(id = "x", requires_bars = 1L, stable_after = 1L, fn = 1)),
    "feature_def$fn",
    fixed = TRUE
  )

  testthat::expect_error(
    ledgr:::ledgr_validate_feature_def(
      list(id = "x", requires_bars = 1L, stable_after = 1L, fn = function(w) 1.0, series_fn = 1)
    ),
    "feature_def$series_fn",
    fixed = TRUE
  )

  testthat::expect_error(
    ledgr:::ledgr_validate_feature_def(
      list(
        id = "x",
        requires_bars = 1L,
        stable_after = 1L,
        fn = function(w) 1.0,
        params = list(env = environment())
      )
    ),
    class = "ledgr_config_non_deterministic"
  )

  testthat::expect_error(
    ledgr:::ledgr_validate_feature_defs(list(good, good)),
    "duplicate",
    ignore.case = TRUE
  )
})

testthat::test_that("feature series uses vectorized series_fn when available", {
  bars <- make_test_bars(c("AAA"), "2020-01-01 00:00:00", n = 6)
  calls <- new.env(parent = emptyenv())
  calls$fn <- 0L
  calls$series_fn <- 0L

  def <- list(
    id = "series_path",
    requires_bars = 2L,
    stable_after = 2L,
    fn = function(window) {
      calls$fn <- calls$fn + 1L
      tail(window$close, 1)
    },
    series_fn = function(bars, params = list()) {
      calls$series_fn <- calls$series_fn + 1L
      bars$close
    },
    params = list()
  )

  values <- ledgr:::ledgr_compute_feature_series(bars, def)

  testthat::expect_identical(calls$series_fn, 1L)
  testthat::expect_identical(calls$fn, 0L)
  testthat::expect_true(is.na(values[[1]]))
  testthat::expect_equal(values[-1], bars$close[-1])
})

testthat::test_that("feature series validates vectorized output", {
  bars <- make_test_bars(c("AAA"), "2020-01-01 00:00:00", n = 4)
  base_def <- list(
    id = "bad_series",
    requires_bars = 2L,
    stable_after = 2L,
    fn = function(window) tail(window$close, 1),
    params = list()
  )

  len_def <- base_def
  len_def$series_fn <- function(bars, params = list()) bars$close[-1]
  testthat::expect_error(
    ledgr:::ledgr_compute_feature_series(bars, len_def),
    "expected 4",
    fixed = TRUE
  )

  type_def <- base_def
  type_def$series_fn <- function(bars, params = list()) as.character(bars$close)
  testthat::expect_error(
    ledgr:::ledgr_compute_feature_series(bars, type_def),
    "non-numeric",
    fixed = TRUE
  )

  inf_def <- base_def
  inf_def$series_fn <- function(bars, params = list()) c(NA_real_, 1, Inf, 2)
  testthat::expect_error(
    ledgr:::ledgr_compute_feature_series(bars, inf_def),
    "infinite",
    fixed = TRUE
  )

  inf_warmup_def <- base_def
  inf_warmup_def$series_fn <- function(bars, params = list()) c(Inf, 1, 2, 3)
  values <- ledgr:::ledgr_compute_feature_series(bars, inf_warmup_def)
  testthat::expect_true(is.na(values[[1]]))
  testthat::expect_equal(values[-1], c(1, 2, 3))

  nan_def <- base_def
  nan_def$series_fn <- function(bars, params = list()) c(NaN, 1, 2, 3)
  values <- ledgr:::ledgr_compute_feature_series(bars, nan_def)
  testthat::expect_true(is.na(values[[1]]))
  testthat::expect_false(is.nan(values[[1]]))

  nan_late_def <- base_def
  nan_late_def$series_fn <- function(bars, params = list()) c(NA_real_, 1, NaN, 3)
  testthat::expect_error(
    ledgr:::ledgr_compute_feature_series(bars, nan_late_def),
    "NaN outside",
    fixed = TRUE
  )

  na_late_def <- base_def
  na_late_def$series_fn <- function(bars, params = list()) c(NA_real_, 1, NA_real_, 3)
  testthat::expect_error(
    ledgr:::ledgr_compute_feature_series(bars, na_late_def),
    "NA outside",
    fixed = TRUE
  )
})

testthat::test_that("fn-only feature fallback uses bounded windows", {
  bars <- make_test_bars(c("AAA"), "2020-01-01 00:00:00", n = 8)
  seen <- new.env(parent = emptyenv())
  seen$max_rows <- 0L

  def <- list(
    id = "bounded_fn",
    requires_bars = 3L,
    stable_after = 3L,
    fn = function(window) {
      seen$max_rows <- max(seen$max_rows, nrow(window))
      mean(window$close)
    },
    params = list()
  )

  values <- ledgr:::ledgr_compute_feature_series(bars, def)

  testthat::expect_true(all(is.na(values[1:2])))
  testthat::expect_identical(seen$max_rows, 3L)
  testthat::expect_false(anyNA(values[3:length(values)]))
})

testthat::test_that("feature engine writes explicit warmup NA rows and is deterministic", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  ledgr_create_schema(con)

  run_id <- "run-features-1"
  insert_test_run(con, run_id)

  instrument_ids <- c("AAA", "BBB")
  DBI::dbAppendTable(con, "instruments", data.frame(instrument_id = instrument_ids))

  bars <- make_test_bars(instrument_ids, "2020-01-01 00:00:00", n = 10)
  bars <- bars[sample.int(nrow(bars)), , drop = FALSE]
  DBI::dbAppendTable(con, "bars", bars)

  feature_defs <- list(
    ledgr:::ledgr_feature_sma_n(3L),
    ledgr:::ledgr_feature_return_1()
  )

  testthat::expect_error(
    ledgr:::ledgr_compute_features(
      con,
      run_id = run_id,
      instrument_ids = instrument_ids,
      start_ts_utc = "2020-01-01T00:00:00Z",
      end_ts_utc = "2020-01-10T00:00:00Z",
      feature_defs = feature_defs
    ),
    NA
  )

  f1 <- DBI::dbGetQuery(
    con,
    "
    SELECT *
    FROM features
    WHERE run_id = ?
    ORDER BY instrument_id, ts_utc, feature_name
    ",
    params = list(run_id)
  )

  testthat::expect_true(nrow(f1) > 0)

  sma_aaa <- DBI::dbGetQuery(
    con,
    "
    SELECT ts_utc, feature_value
    FROM features
    WHERE run_id = ? AND instrument_id = 'AAA' AND feature_name = 'sma_3'
    ORDER BY ts_utc
    ",
    params = list(run_id)
  )
  testthat::expect_equal(nrow(sma_aaa), 10L)
  testthat::expect_true(is.na(sma_aaa$feature_value[[1]]))
  testthat::expect_true(is.na(sma_aaa$feature_value[[2]]))
  testthat::expect_false(is.na(sma_aaa$feature_value[[3]]))

  testthat::expect_error(
    ledgr:::ledgr_compute_features(
      con,
      run_id = run_id,
      instrument_ids = instrument_ids,
      start_ts_utc = "2020-01-01T00:00:00Z",
      end_ts_utc = "2020-01-10T00:00:00Z",
      feature_defs = feature_defs
    ),
    NA
  )

  f2 <- DBI::dbGetQuery(
    con,
    "
    SELECT *
    FROM features
    WHERE run_id = ?
    ORDER BY instrument_id, ts_utc, feature_name
    ",
    params = list(run_id)
  )

  testthat::expect_equal(normalize_features_df(f2), normalize_features_df(f1))
})

testthat::test_that("feature engine output is independent of bar insertion order", {
  run_id <- "run-features-2"
  instrument_ids <- c("AAA", "BBB")

  feature_defs <- list(
    ledgr:::ledgr_feature_sma_n(3L),
    ledgr:::ledgr_feature_return_1()
  )

  bars <- make_test_bars(instrument_ids, "2020-01-01 00:00:00", n = 10)
  bars_shuffled <- bars[sample.int(nrow(bars)), , drop = FALSE]

  con1 <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con1, shutdown = TRUE), add = TRUE)
  ledgr_create_schema(con1)
  insert_test_run(con1, run_id)
  DBI::dbAppendTable(con1, "instruments", data.frame(instrument_id = instrument_ids))
  DBI::dbAppendTable(con1, "bars", bars_shuffled)
  ledgr:::ledgr_compute_features(
    con1,
    run_id = run_id,
    instrument_ids = instrument_ids,
    start_ts_utc = "2020-01-01T00:00:00Z",
    end_ts_utc = "2020-01-10T00:00:00Z",
    feature_defs = feature_defs
  )
  f_shuffled <- DBI::dbGetQuery(
    con1,
    "
    SELECT *
    FROM features
    WHERE run_id = ?
    ORDER BY instrument_id, ts_utc, feature_name
    ",
    params = list(run_id)
  )

  con2 <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con2, shutdown = TRUE), add = TRUE)
  ledgr_create_schema(con2)
  insert_test_run(con2, run_id)
  DBI::dbAppendTable(con2, "instruments", data.frame(instrument_id = instrument_ids))
  DBI::dbAppendTable(con2, "bars", bars)
  ledgr:::ledgr_compute_features(
    con2,
    run_id = run_id,
    instrument_ids = instrument_ids,
    start_ts_utc = "2020-01-01T00:00:00Z",
    end_ts_utc = "2020-01-10T00:00:00Z",
    feature_defs = feature_defs
  )
  f_sorted <- DBI::dbGetQuery(
    con2,
    "
    SELECT *
    FROM features
    WHERE run_id = ?
    ORDER BY instrument_id, ts_utc, feature_name
    ",
    params = list(run_id)
  )

  testthat::expect_equal(normalize_features_df(f_shuffled), normalize_features_df(f_sorted))
})

testthat::test_that("no-lookahead checker passes for built-in features on deterministic bars", {
  bars <- make_test_bars(c("AAA"), "2020-01-01 00:00:00", n = 10)
  bars <- bars[order(bars$ts_utc), , drop = FALSE]

  testthat::expect_error(
    ledgr:::ledgr_check_no_lookahead(ledgr:::ledgr_feature_sma_n(3L), bars, horizons = c(1L, 3L)),
    NA
  )
  testthat::expect_error(
    ledgr:::ledgr_check_no_lookahead(ledgr:::ledgr_feature_return_1(), bars, horizons = c(1L, 3L)),
    NA
  )
})

testthat::test_that("feature engine fails loud when bars are missing for an instrument", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  ledgr_create_schema(con)

  run_id <- "run-features-3"
  insert_test_run(con, run_id)

  DBI::dbAppendTable(con, "instruments", data.frame(instrument_id = c("AAA", "BBB")))
  bars <- make_test_bars(c("AAA"), "2020-01-01 00:00:00", n = 3)
  DBI::dbAppendTable(con, "bars", bars)

  testthat::expect_error(
    ledgr:::ledgr_compute_features(
      con,
      run_id = run_id,
      instrument_ids = c("AAA", "BBB"),
      start_ts_utc = "2020-01-01T00:00:00Z",
      end_ts_utc = "2020-01-03T00:00:00Z",
      feature_defs = list(ledgr:::ledgr_feature_sma_n(2L))
    ),
    "Missing bars",
    fixed = TRUE
  )
})
