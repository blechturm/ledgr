testthat::test_that("pulse context exposes narrative scalar accessors", {
  ts <- "2020-01-02T00:00:00Z"
  universe <- c("A", "B")
  bars <- data.frame(
    instrument_id = universe,
    ts_utc = c(ts, ts),
    open = c(10, 20),
    high = c(11, 21),
    low = c(9, 19),
    close = c(10.5, 20.5),
    volume = c(100, 200),
    stringsAsFactors = FALSE
  )
  positions <- stats::setNames(c(3), "B")

  ctx <- ledgr:::ledgr_pulse_context(
    run_id = "run-1",
    ts_utc = ts,
    universe = universe,
    bars = bars,
    positions = positions,
    cash = 1000,
    equity = 1061.5
  )

  testthat::expect_true(is.function(ctx$bar))
  testthat::expect_true(is.function(ctx$open))
  testthat::expect_true(is.function(ctx$high))
  testthat::expect_true(is.function(ctx$low))
  testthat::expect_true(is.function(ctx$close))
  testthat::expect_true(is.function(ctx$volume))
  testthat::expect_true(is.function(ctx$position))
  testthat::expect_true(is.function(ctx$flat))
  testthat::expect_true(is.function(ctx$hold))
  testthat::expect_true(is.function(ctx$targets))
  testthat::expect_true(is.function(ctx$current_targets))

  testthat::expect_equal(ctx$open("A"), 10)
  testthat::expect_equal(ctx$high("A"), 11)
  testthat::expect_equal(ctx$low("A"), 9)
  testthat::expect_equal(ctx$close("A"), 10.5)
  testthat::expect_equal(ctx$volume("B"), 200)
  testthat::expect_null(names(ctx$close("A")))

  bar_b <- ctx$bar("B")
  testthat::expect_true(is.data.frame(bar_b))
  testthat::expect_equal(nrow(bar_b), 1L)
  testthat::expect_identical(as.character(bar_b$instrument_id), "B")

  testthat::expect_equal(ctx$position("A"), 0)
  testthat::expect_equal(ctx$position("B"), 3)
  testthat::expect_identical(ctx$flat(), stats::setNames(c(0, 0), universe))
  testthat::expect_identical(ctx$flat(default = 2), stats::setNames(c(2, 2), universe))
  testthat::expect_identical(ctx$hold(), stats::setNames(c(0, 3), universe))
  testthat::expect_error(ctx$targets(), class = "ledgr_context_helper_removed")
  testthat::expect_error(ctx$current_targets(), class = "ledgr_context_helper_removed")
  testthat::expect_error(ctx$targets(), "`ctx$targets()` was removed", fixed = TRUE)
  testthat::expect_error(ctx$current_targets(), "`ctx$current_targets()` was removed", fixed = TRUE)

  testthat::expect_true(is.numeric(ctx$cash))
  testthat::expect_true(is.numeric(ctx$equity))
  testthat::expect_false(is.function(ctx$cash))
  testthat::expect_false(is.function(ctx$equity))

  testthat::expect_true(is.environment(ctx$.pulse_lookup))
  testthat::expect_identical(ctx$.pulse_lookup$bar_index, stats::setNames(1:2, universe))
})

testthat::test_that("pulse context accessors fail loudly on ambiguity", {
  ts <- "2020-01-02T00:00:00Z"
  bars <- data.frame(
    instrument_id = c("AAA", "BBB"),
    ts_utc = c(ts, ts),
    open = c(10, 20),
    high = c(11, 21),
    low = c(9, 19),
    close = c(10.5, 20.5),
    stringsAsFactors = FALSE
  )

  ctx <- ledgr:::ledgr_pulse_context(
    run_id = "run-1",
    ts_utc = ts,
    universe = c("AAA", "BBB"),
    bars = bars,
    cash = 1000,
    equity = 1000
  )

  testthat::expect_error(
    ctx$close("AA"),
    "Available ctx\\$universe: AAA, BBB"
  )
  testthat::expect_error(
    ctx$volume("AAA"),
    "missing required field `volume`",
    fixed = TRUE
  )
  testthat::expect_error(
    ctx$flat(default = NA_real_),
    "`default` must be a finite numeric scalar",
    fixed = TRUE
  )

  duplicate_bars <- rbind(bars[1, , drop = FALSE], bars[1, , drop = FALSE])
  testthat::expect_error(
    ledgr:::ledgr_pulse_context(
      run_id = "run-1",
      ts_utc = ts,
      universe = c("AAA", "BBB"),
      bars = duplicate_bars,
      cash = 1000,
      equity = 1000
    ),
    "duplicate rows for instrument_id: AAA",
    fixed = TRUE
  )
})

testthat::test_that("pulse context feature accessor fails loudly on unknown feature IDs", {
  ts <- "2020-01-02T00:00:00Z"
  bars <- data.frame(
    instrument_id = "AAA",
    ts_utc = ts,
    open = 10,
    high = 11,
    low = 9,
    close = 10.5,
    volume = 100,
    stringsAsFactors = FALSE
  )
  features <- data.frame(
    instrument_id = "AAA",
    ts_utc = ts,
    feature_name = "return_20",
    feature_value = NA_real_,
    stringsAsFactors = FALSE
  )

  ctx <- ledgr:::ledgr_pulse_context(
    run_id = "run-1",
    ts_utc = ts,
    universe = "AAA",
    bars = bars,
    features = features,
    cash = 1000,
    equity = 1000
  )

  testthat::expect_true(is.na(ctx$feature("AAA", "return_20")))
  testthat::expect_error(
    ctx$feature("AAA", "returns_20"),
    class = "ledgr_unknown_feature_id"
  )
  testthat::expect_error(
    ctx$feature("AAA", "returns_20"),
    "Available feature IDs: return_20",
    fixed = TRUE
  )
})

testthat::test_that("pulse context feature accessor fails when no features are registered", {
  ts <- "2020-01-02T00:00:00Z"
  bars <- data.frame(
    instrument_id = "AAA",
    ts_utc = ts,
    open = 10,
    high = 11,
    low = 9,
    close = 10.5,
    volume = 100,
    stringsAsFactors = FALSE
  )

  ctx <- ledgr:::ledgr_pulse_context(
    run_id = "run-1",
    ts_utc = ts,
    universe = "AAA",
    bars = bars,
    cash = 1000,
    equity = 1000
  )

  testthat::expect_error(
    ctx$feature("AAA", "rsi_20"),
    class = "ledgr_unknown_feature_id"
  )
  testthat::expect_error(
    ctx$feature("AAA", "rsi_20"),
    "Available feature IDs: <none>",
    fixed = TRUE
  )
})

testthat::test_that("pulse context feature maps return aliased pulse values", {
  ts <- "2020-01-02T00:00:00Z"
  bars <- data.frame(
    instrument_id = c("AAA", "BBB"),
    ts_utc = c(ts, ts),
    open = c(10, 20),
    high = c(11, 21),
    low = c(9, 19),
    close = c(10.5, 20.5),
    volume = c(100, 200),
    stringsAsFactors = FALSE
  )
  features <- data.frame(
    instrument_id = c("AAA", "AAA", "BBB", "BBB"),
    ts_utc = rep(ts, 4),
    feature_name = rep(c("sma_2", "return_2"), 2),
    feature_value = c(10.25, NA_real_, 20.25, 0.05),
    stringsAsFactors = FALSE
  )
  feature_map <- ledgr_feature_map(
    trend = ledgr_ind_sma(2),
    ret = ledgr_ind_returns(2)
  )

  ctx <- ledgr:::ledgr_pulse_context(
    run_id = "run-1",
    ts_utc = ts,
    universe = c("AAA", "BBB"),
    bars = bars,
    features = features,
    cash = 1000,
    equity = 1000
  )

  x_aaa <- ctx$features("AAA", feature_map)
  x_bbb <- ctx$features("BBB", feature_map)

  testthat::expect_identical(names(x_aaa), c("trend", "ret"))
  testthat::expect_equal(x_aaa[["trend"]], 10.25)
  testthat::expect_true(is.na(x_aaa[["ret"]]))
  testthat::expect_false(passed_warmup(x_aaa))
  testthat::expect_true(passed_warmup(x_bbb))
  testthat::expect_equal(x_bbb[["ret"]], 0.05)
  testthat::expect_equal(ctx$feature("BBB", "return_2"), x_bbb[["ret"]])
})

testthat::test_that("pulse context feature maps fail loudly for invalid lookup", {
  ts <- "2020-01-02T00:00:00Z"
  bars <- data.frame(
    instrument_id = "AAA",
    ts_utc = ts,
    open = 10,
    high = 11,
    low = 9,
    close = 10.5,
    volume = 100,
    stringsAsFactors = FALSE
  )
  features <- data.frame(
    instrument_id = "AAA",
    ts_utc = ts,
    feature_name = "sma_2",
    feature_value = 10.25,
    stringsAsFactors = FALSE
  )
  ctx <- ledgr:::ledgr_pulse_context(
    run_id = "run-1",
    ts_utc = ts,
    universe = "AAA",
    bars = bars,
    features = features,
    cash = 1000,
    equity = 1000
  )

  testthat::expect_error(
    ctx$features("BBB", ledgr_feature_map(sma = ledgr_ind_sma(2))),
    class = "ledgr_invalid_pulse_context"
  )
  testthat::expect_error(
    ctx$features("AAA", list(sma = ledgr_ind_sma(2))),
    class = "ledgr_invalid_feature_map"
  )
  testthat::expect_error(
    ctx$features("AAA", ledgr_feature_map(ret = ledgr_ind_returns(2))),
    "Available feature IDs: sma_2",
    fixed = TRUE,
    class = "ledgr_unknown_feature_id"
  )
})

testthat::test_that("passed_warmup validates input shape", {
  testthat::expect_true(passed_warmup(c(a = 1, b = 0)))
  testthat::expect_false(passed_warmup(c(a = 1, b = NA_real_)))
  testthat::expect_error(passed_warmup(numeric()), class = "ledgr_empty_warmup_input")
  testthat::expect_error(passed_warmup("x"), class = "ledgr_invalid_warmup_input")
})

testthat::test_that("interactive pulse snapshots expose strategy authoring helpers", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  snap <- ledgr_snapshot_from_df(test_bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snap), add = TRUE)

  universe <- c("TEST_A", "TEST_B")
  ts_utc <- iso_utc(test_bars$ts_utc[[10]])
  ctx <- ledgr_pulse_snapshot(
    snapshot = snap,
    universe = universe,
    ts_utc = ts_utc,
    features = list(ledgr_ind_sma(2)),
    initial_cash = 1000
  )
  on.exit(close(ctx), add = TRUE)

  testthat::expect_s3_class(ctx, "ledgr_pulse_context")
  testthat::expect_true(is.function(ctx$close))
  testthat::expect_true(is.function(ctx$position))
  testthat::expect_true(is.function(ctx$flat))
  testthat::expect_true(is.function(ctx$hold))
  testthat::expect_true(is.function(ctx$features))
  testthat::expect_equal(ctx$close("TEST_A"), ctx$bars$close[ctx$bars$instrument_id == "TEST_A"])
  testthat::expect_equal(ctx$position("TEST_A"), 0)
  testthat::expect_identical(ctx$flat(), stats::setNames(c(0, 0), universe))
  testthat::expect_identical(ctx$hold(), stats::setNames(c(0, 0), universe))
  testthat::expect_error(
    ctx$feature("TEST_A", "sma_200"),
    class = "ledgr_unknown_feature_id"
  )
  testthat::expect_true(is.environment(ctx$.pulse_lookup))
})

testthat::test_that("runtime strategy contexts expose strategy authoring helpers", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  snap <- ledgr_snapshot_from_df(test_bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snap), add = TRUE)

  observed <- new.env(parent = emptyenv())
  observed$count <- 0L

  helper_strategy <- function(ctx, params) {
    if (!is.function(ctx$close) || !is.function(ctx$flat) || !is.function(ctx$position) || !is.function(ctx$hold)) {
      stop("runtime context accessors are missing")
    }
    if (is.function(ctx$cash) || is.function(ctx$equity)) {
      stop("cash/equity must remain scalar fields")
    }
    if (!identical(ctx$close("TEST_A"), unname(ctx$bars$close[ctx$bars$instrument_id == "TEST_A"]))) {
      stop("runtime close accessor does not match ctx$bars")
    }
    if (!identical(ctx$position("TEST_A"), unname(if ("TEST_A" %in% names(ctx$positions)) ctx$positions[["TEST_A"]] else 0))) {
      stop("runtime position accessor does not match ctx$positions")
    }
    expected_current <- stats::setNames(rep(0, length(ctx$universe)), ctx$universe)
    if (length(ctx$positions) > 0) expected_current[names(ctx$positions)] <- as.numeric(ctx$positions)
    if (!identical(ctx$hold(), expected_current)) {
      stop("runtime hold accessor does not match ctx$positions")
    }

    observed$count <- observed$count + 1L
    targets <- ctx$flat()
    if (observed$count == 1L && ctx$close("TEST_A") > 0) {
      targets["TEST_A"] <- 1
    }
    targets
  }

  testthat::expect_error(
    ledgr_backtest(
      snapshot = snap,
      strategy = helper_strategy,
      universe = c("TEST_A", "TEST_B"),
      start = "2020-01-01",
      end = "2020-01-15",
      db_path = db_path
    ),
    NA
  )
  testthat::expect_gt(observed$count, 0L)
})

testthat::test_that("feature-map strategies match across execution modes", {
  bars <- ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:8)
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  features <- ledgr_feature_map(ret = ledgr_ind_returns(2))
  strategy <- function(ctx, params) {
    x <- ctx$features("AAA", features)
    if (!identical(x[["ret"]], ctx$feature("AAA", "return_2"))) {
      stop("mapped feature value does not match scalar feature accessor")
    }
    targets <- ctx$flat()
    if (passed_warmup(x) && x[["ret"]] > 0) {
      targets["AAA"] <- 1
    }
    targets
  }

  results <- lapply(c("audit_log", "db_live"), function(mode) {
    local({
      exp <- ledgr_experiment(
        snapshot = snapshot,
        strategy = strategy,
        features = features,
        opening = ledgr_opening(cash = 1000),
        execution_mode = mode
      )
      bt <- ledgr_run(exp, params = list(), run_id = paste0("feature-map-", mode))
      on.exit(close(bt), add = TRUE)
      list(
        fills = ledgr_results(bt, "fills"),
        equity = ledgr_results(bt, "equity")
      )
    })
  })

  fills_a <- results[[1]]$fills
  fills_b <- results[[2]]$fills
  equity_a <- results[[1]]$equity
  equity_b <- results[[2]]$equity

  testthat::expect_equal(fills_a$instrument_id, fills_b$instrument_id)
  testthat::expect_equal(fills_a$side, fills_b$side)
  testthat::expect_equal(fills_a$qty, fills_b$qty)
  testthat::expect_equal(fills_a$price, fills_b$price, tolerance = 1e-8)
  testthat::expect_equal(equity_a$equity, equity_b$equity, tolerance = 1e-8)
})
