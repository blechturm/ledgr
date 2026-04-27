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
  testthat::expect_identical(ctx$targets(), stats::setNames(c(0, 0), universe))
  testthat::expect_identical(ctx$targets(default = 2), stats::setNames(c(2, 2), universe))
  testthat::expect_identical(ctx$current_targets(), stats::setNames(c(0, 3), universe))

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
    ctx$targets(default = NA_real_),
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
  testthat::expect_true(is.function(ctx$targets))
  testthat::expect_true(is.function(ctx$current_targets))
  testthat::expect_equal(ctx$close("TEST_A"), ctx$bars$close[ctx$bars$instrument_id == "TEST_A"])
  testthat::expect_equal(ctx$position("TEST_A"), 0)
  testthat::expect_identical(ctx$targets(), stats::setNames(c(0, 0), universe))
  testthat::expect_identical(ctx$current_targets(), stats::setNames(c(0, 0), universe))
  testthat::expect_true(is.environment(ctx$.pulse_lookup))
})

testthat::test_that("runtime strategy contexts expose strategy authoring helpers", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  snap <- ledgr_snapshot_from_df(test_bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snap), add = TRUE)

  observed <- new.env(parent = emptyenv())
  observed$count <- 0L

  helper_strategy <- function(ctx) {
    if (!is.function(ctx$close) || !is.function(ctx$targets) || !is.function(ctx$position) || !is.function(ctx$current_targets)) {
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
    if (!identical(ctx$current_targets(), expected_current)) {
      stop("runtime current_targets accessor does not match ctx$positions")
    }

    observed$count <- observed$count + 1L
    targets <- ctx$targets()
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
