testthat::test_that("pulse context exposes flat named columns and refuses retired frames", {
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

  for (retired in c("bars", "bar", "feature_table", "features_wide")) {
    testthat::expect_error(ctx[[retired]], class = "ledgr_unknown_context_field")
  }
  testthat::expect_true(is.numeric(ctx$open))
  testthat::expect_true(is.numeric(ctx$high))
  testthat::expect_true(is.numeric(ctx$low))
  testthat::expect_true(is.numeric(ctx$close))
  testthat::expect_true(is.numeric(ctx$volume))
  testthat::expect_true(is.numeric(ctx$position))
  testthat::expect_true(is.function(ctx$flat))
  testthat::expect_true(is.function(ctx$hold))
  testthat::expect_error(ctx$idx, class = "ledgr_unknown_context_field")
  testthat::expect_error(ctx$tradable, class = "ledgr_unknown_context_field")
  testthat::expect_error(ctx$positions, class = "ledgr_unknown_context_field")
  testthat::expect_error(ctx$targets, class = "ledgr_unknown_context_field")
  testthat::expect_error(ctx$current_targets, class = "ledgr_unknown_context_field")
  testthat::expect_error(ctx$safety_state, class = "ledgr_unknown_context_field")

  testthat::expect_equal(ctx$open[["A"]], 10)
  testthat::expect_equal(ctx$high[["A"]], 11)
  testthat::expect_equal(ctx$low[["A"]], 9)
  testthat::expect_equal(ctx$close[["A"]], 10.5)
  testthat::expect_equal(ctx$volume[["B"]], 200)
  testthat::expect_null(names(ctx$close[["A"]]))
  testthat::expect_identical(match("A", ctx$universe), 1L)
  testthat::expect_identical(match("Z", ctx$universe), NA_integer_)
  testthat::expect_error(ctx$vec, class = "ledgr_unknown_context_field")
  testthat::expect_equal(ctx$open, c(A = 10, B = 20))
  testthat::expect_equal(ctx$high, c(A = 11, B = 21))
  testthat::expect_equal(ctx$low, c(A = 9, B = 19))
  testthat::expect_equal(ctx$close, c(A = 10.5, B = 20.5))
  testthat::expect_equal(ctx$volume, c(A = 100, B = 200))
  testthat::expect_equal(ctx$position, c(A = 0, B = 3))

  testthat::expect_equal(ctx$position[["A"]], 0)
  testthat::expect_equal(ctx$position[["B"]], 3)
  testthat::expect_identical(ctx$flat(), stats::setNames(c(0, 0), universe))
  testthat::expect_identical(ctx$flat(default = 2), stats::setNames(c(2, 2), universe))
  testthat::expect_identical(ctx$hold(), stats::setNames(c(0, 3), universe))
  testthat::expect_identical(names(ctx$buyable)[ctx$buyable], universe)

  testthat::expect_true(is.numeric(ctx$cash))
  testthat::expect_true(is.numeric(ctx$equity))
  testthat::expect_false(is.function(ctx$cash))
  testthat::expect_false(is.function(ctx$equity))

  testthat::expect_true(is.environment(ctx$.pulse_lookup))
  testthat::expect_false(any(vapply(
    as.list.environment(ctx$.pulse_lookup, all.names = TRUE),
    is.data.frame,
    logical(1)
  )))
})

testthat::test_that("[LTB-0061] ctx$buyable is eligibility and not a price plane", {
  ids <- c("HALTED", "UNPRICED", "HELD_NONMEMBER", "MEMBER")
  bars <- data.frame(
    instrument_id = ids,
    ts_utc = rep(as.POSIXct("2020-01-02", tz = "UTC"), length(ids)),
    open = rep(10, length(ids)),
    high = rep(11, length(ids)),
    low = rep(9, length(ids)),
    close = c(10, NA_real_, 8, 12),
    volume = rep(100, length(ids)),
    stringsAsFactors = FALSE
  )
  ctx <- ledgr:::ledgr_pulse_context(
    run_id = "tradable",
    ts_utc = bars$ts_utc[[1L]],
    universe = ids,
    bars = bars,
    positions = stats::setNames(2, "HELD_NONMEMBER"),
    cash = 1000,
    equity = 1000
  )
  availability <- list(
    member = stats::setNames(c(TRUE, TRUE, FALSE, TRUE), ids),
    held = stats::setNames(c(FALSE, FALSE, TRUE, FALSE), ids),
    target_restricted = stats::setNames(c(TRUE, FALSE, TRUE, FALSE), ids),
    target_restriction_reason = stats::setNames(c("halted", "", "nonmember", ""), ids),
    priced = stats::setNames(c(TRUE, FALSE, TRUE, TRUE), ids),
    mark_age = stats::setNames(rep(0L, length(ids)), ids),
    risk_mark = stats::setNames(c(10, NA_real_, 8, 12), ids),
    mark_source = stats::setNames(c("current_close", "", "current_close", "current_close"), ids)
  )
  ctx <- ledgr:::ledgr_update_pulse_context_helpers(
    ctx,
    bars = bars,
    positions = ctx$.positions,
    universe = ids,
    availability = availability
  )

  testthat::expect_identical(names(ctx$buyable)[ctx$buyable], c("UNPRICED", "MEMBER"))

  weights <- ledgr_weight_equal(names(ctx$buyable)[ctx$buyable])
  testthat::expect_error(
    ledgr_target_rebalance(
      ctx,
      weights = weights,
      index_leavers = "keep",
      capital_base = "total_equity"
    ),
    NA
  )

  dense <- ledgr:::ledgr_pulse_context(
    run_id = "dense",
    ts_utc = bars$ts_utc[[1L]],
    universe = ids,
    bars = transform(bars, close = c(10, 0, -1, Inf)),
    cash = 1000,
    equity = 1000
  )
  testthat::expect_identical(names(dense$buyable)[dense$buyable], ids)

  availability$member[] <- FALSE
  empty <- ledgr:::ledgr_update_pulse_context_helpers(
    ctx,
    bars = bars,
    positions = ctx$.positions,
    universe = ids,
    availability = availability
  )
  targets <- empty$flat()
  targets[names(empty$buyable)[empty$buyable]] <- 1
  testthat::expect_identical(names(empty$buyable)[empty$buyable], character())
  testthat::expect_identical(targets, stats::setNames(rep(0, length(ids)), ids))
})

testthat::test_that("projection contexts manifest inspection only on demand", {
  pulses <- as.POSIXct("2020-01-01", tz = "UTC")
  universe <- c("AAA", "BBB")
  projection <- ledgr:::ledgr_runtime_projection(
    feature_values = list(signal = matrix(c(1, 2), nrow = 2L)),
    universe = universe,
    pulses_posix = pulses
  )
  bars <- data.frame(
    instrument_id = universe,
    ts_utc = rep(pulses[[1]], 2L),
    open = c(10, 20),
    high = c(11, 21),
    low = c(9, 19),
    close = c(10.5, 20.5),
    volume = c(100, 200),
    stringsAsFactors = FALSE
  )
  ctx <- ledgr:::ledgr_pulse_context(
    run_id = "run-1",
    ts_utc = pulses[[1]],
    universe = universe,
    bars = bars,
    cash = 1000,
    equity = 1000
  )
  ctx <- ledgr:::ledgr_update_pulse_context_helpers(
    ctx,
    bars = bars,
    universe = universe,
    projection = projection,
    pulse_idx = 1L,
    feature_ids = "signal"
  )

  testthat::expect_s3_class(ctx, "ledgr_pulse_context")
  testthat::expect_error(ctx$feature_table, class = "ledgr_unknown_context_field")
  testthat::expect_error(ctx$features_wide, class = "ledgr_unknown_context_field")
  testthat::expect_equal(ctx[["signal"]][["AAA"]], 1)
  testthat::expect_equal(unname(ctx[["signal"]]), c(1, 2))
  testthat::expect_equal(ledgr_pulse_features(ctx)$feature_value, c(1, 2))
  testthat::expect_equal(ledgr_pulse_wide(ctx)$AAA__feature_signal, 1)
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

  testthat::expect_error(ctx$close[["AA"]], "subscript out of bounds", fixed = TRUE)
  testthat::expect_true(is.na(ctx$volume[["AAA"]]))
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

  testthat::expect_true(is.na(ctx[["return_20"]][["AAA"]]))
  testthat::expect_true(is.na(ctx[["return_20"]][[1L]]))
  testthat::expect_error(
    ctx[["returns_20"]][["AAA"]],
    class = "ledgr_unknown_context_field"
  )
  testthat::expect_error(
    ctx[["returns_20"]][["AAA"]],
    "Unknown pulse context field `returns_20`.",
    fixed = TRUE
  )
  testthat::expect_error(
    ctx[["returns_20"]],
    class = "ledgr_unknown_context_field"
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
    ctx[["rsi_20"]][["AAA"]],
    class = "ledgr_unknown_context_field"
  )
  testthat::expect_error(
    ctx[["rsi_20"]][["AAA"]],
    "Unknown pulse context field `rsi_20`.",
    fixed = TRUE
  )
})

testthat::test_that("pulse context exposes active aliases as flat columns", {
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
  ctx <- ledgr:::ledgr_update_pulse_context_helpers(
    ctx,
    active_alias_map = c(trend = "sma_2", ret = "return_2")
  )

  x_aaa <- c(trend = ctx$trend[["AAA"]], ret = ctx$ret[["AAA"]])
  x_bbb <- c(trend = ctx$trend[["BBB"]], ret = ctx$ret[["BBB"]])

  testthat::expect_identical(names(x_aaa), c("trend", "ret"))
  testthat::expect_equal(x_aaa[["trend"]], 10.25)
  testthat::expect_true(is.na(x_aaa[["ret"]]))
  testthat::expect_false(ledgr_passed_warmup(x_aaa))
  testthat::expect_true(ledgr_passed_warmup(x_bbb))
  testthat::expect_equal(x_bbb[["ret"]], 0.05)
  testthat::expect_equal(ctx[["return_2"]][["BBB"]], x_bbb[["ret"]])

  testthat::expect_equal(ctx$sma_2[["AAA"]], 10.25)
  testthat::expect_true(is.na(ctx$return_2[["AAA"]]))
})

testthat::test_that("retired feature readers fail loudly", {
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

  testthat::expect_error(ctx$features, class = "ledgr_unknown_context_field")
  testthat::expect_error(ctx$feature, class = "ledgr_unknown_context_field")
  testthat::expect_equal(ctx$sma_2[["AAA"]], 10.25)
})

testthat::test_that("ledgr_passed_warmup validates input shape", {
  testthat::expect_true(ledgr_passed_warmup(c(a = 1, b = 0)))
  testthat::expect_false(ledgr_passed_warmup(c(a = 1, b = NA_real_)))
  testthat::expect_error(ledgr_passed_warmup(numeric()), class = "ledgr_empty_warmup_input")
  testthat::expect_error(ledgr_passed_warmup("x"), class = "ledgr_invalid_warmup_input")
})

testthat::test_that("interactive pulse snapshots expose strategy authoring helpers", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  snap <- ledgr_snapshot_from_df(test_bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snap), add = TRUE)

  universe <- c("TEST_A", "TEST_B")
  ts_utc <- ledgr_iso_utc(test_bars$ts_utc[[10]])
  ctx <- ledgr_pulse_snapshot(
    snapshot = snap,
    universe = universe,
    ts_utc = ts_utc,
    features = list(ledgr_ind_sma(2)),
    cash = 1000
  )
  on.exit(close(ctx), add = TRUE)

  testthat::expect_s3_class(ctx, "ledgr_pulse_context")
  testthat::expect_true(is.numeric(ctx$close))
  testthat::expect_true(is.numeric(ctx$position))
  testthat::expect_true(is.function(ctx$flat))
  testthat::expect_true(is.function(ctx$hold))
  testthat::expect_error(ctx$features, class = "ledgr_unknown_context_field")
  bar_ts <- vapply(test_bars$ts_utc, ledgr_iso_utc, character(1))
  testthat::expect_equal(ctx$close[["TEST_A"]], test_bars$close[test_bars$instrument_id == "TEST_A" & bar_ts == ts_utc])
  testthat::expect_equal(ctx$position[["TEST_A"]], 0)
  testthat::expect_identical(ctx$flat(), stats::setNames(c(0, 0), universe))
  testthat::expect_identical(ctx$hold(), stats::setNames(c(0, 0), universe))
  testthat::expect_error(
    ctx[["sma_200"]][["TEST_A"]],
    class = "ledgr_unknown_context_field"
  )
  testthat::expect_true(is.environment(ctx$.pulse_lookup))
})

testthat::test_that("[LTB-0094] pulse snapshots match dense fold state and valuation", {
  ts <- as.POSIXct("2026-01-01", tz = "UTC") + 86400 * 0:2
  bars <- do.call(rbind, lapply(seq_along(ts), function(i) {
    data.frame(
      ts_utc = rep(ts[[i]], 2L),
      instrument_id = c("AAA", "BBB"),
      open = c(10, 20),
      high = c(10, 20),
      low = c(10, 20),
      close = c(10, 20),
      volume = c(1000, 1000),
      stringsAsFactors = FALSE
    )
  }))
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)
  snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  observed <- new.env(parent = emptyenv())
  observed$pulse <- 0L
  weights <- ledgr_weights(c(AAA = 0.5, BBB = 0.5))
  strategy <- function(ctx, params) {
    observed$pulse <- observed$pulse + 1L
    if (observed$pulse == 1L) {
      observed$first <- list(
        cash = ctx$cash,
        equity = ctx$equity,
        positions = ctx$hold(),
        target = ledgr_target_rebalance(ctx, weights = weights)
      )
      return(ledgr_strategy_result(ctx$hold(), pulses_seen = 3L))
    } else {
      observed$state <- ctx$state
    }
    ctx$hold()
  }
  experiment <- ledgr_experiment(
    snapshot = snapshot,
    strategy = strategy,
    opening = ledgr_opening(
      cash = 100,
      positions = c(BBB = 2, AAA = 1),
      cost_basis = c(BBB = 20, AAA = 10)
    ),
    cost_model = ledgr_cost_zero(),
    portfolio_state = list(pulses_seen = 0L)
  )
  backtest <- ledgr_run(experiment, run_id = "pulse-snapshot-fold-oracle")
  on.exit(close(backtest), add = TRUE)

  pulse <- ledgr_pulse_snapshot(
    snapshot,
    universe = c("AAA", "BBB"),
    ts_utc = ts[[1L]],
    cash = 100,
    positions = c(BBB = 2, AAA = 1)
  )
  on.exit(close(pulse), add = TRUE)
  testthat::expect_identical(pulse$cash, observed$first$cash)
  testthat::expect_identical(pulse$equity, observed$first$equity)
  testthat::expect_identical(pulse$hold(), observed$first$positions)
  testthat::expect_identical(
    ledgr_target_rebalance(pulse, weights = weights),
    observed$first$target
  )

  state_pulse <- ledgr_pulse_snapshot(
    snapshot,
    universe = c("AAA", "BBB"),
    ts_utc = ts[[2L]],
    cash = 100,
    positions = c(BBB = 2, AAA = 1),
    portfolio_state = list(pulses_seen = 3L)
  )
  on.exit(close(state_pulse), add = TRUE)
  testthat::expect_identical(state_pulse$state$pulses_seen, observed$state$pulses_seen)

  printed <- capture.output(print(state_pulse))
  testthat::expect_true(any(grepl("Cash:      100", printed, fixed = TRUE)))
  testthat::expect_true(any(grepl("Equity:    150", printed, fixed = TRUE)))
  testthat::expect_true(any(grepl("Positions: 2 nonzero", printed, fixed = TRUE)))
  testthat::expect_true(any(grepl("State:     declared", printed, fixed = TRUE)))
  testthat::expect_false(any(grepl("pulses_seen", printed, fixed = TRUE)))

  testthat::expect_false("initial_cash" %in% names(formals(ledgr_pulse_snapshot)))
  testthat::expect_error(
    ledgr_pulse_snapshot(
      snapshot,
      universe = c("AAA", "BBB"),
      ts_utc = ts[[1L]],
      initial_cash = 100
    ),
    regexp = "Unused pulse-inspection argument"
  )

  testthat::expect_error(
    ledgr_experiment(
      snapshot = snapshot,
      strategy = function(ctx, params) ctx$hold(),
      opening = ledgr_opening(cash = 100),
      cost_model = ledgr_cost_zero(),
      portfolio_state = list(callback = function() NULL)
    ),
    class = "ledgr_invalid_strategy_state"
  )
  testthat::expect_error(
    ledgr_pulse_snapshot(
      snapshot,
      universe = c("AAA", "BBB"),
      ts_utc = ts[[1L]],
      portfolio_state = list(callback = function() NULL)
    ),
    class = "ledgr_invalid_strategy_state"
  )
})

# ledgr-test-profile: heavy_protocol
testthat::test_that("runtime strategy contexts expose strategy authoring helpers", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)
  bars <- ledgr_test_compact_bars()

  snap <- ledgr_snapshot_from_df(bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snap), add = TRUE)

  observed <- new.env(parent = emptyenv())
  observed$count <- 0L

  helper_strategy <- function(ctx, params) {
    if (!is.numeric(ctx$close) || !is.function(ctx$flat) || !is.numeric(ctx$position) || !is.function(ctx$hold)) {
      stop("runtime context accessors are missing")
    }
    if (is.function(ctx$cash) || is.function(ctx$equity)) {
      stop("cash/equity must remain scalar fields")
    }
    if (!identical(ctx$position[["TEST_A"]], unname(ctx$position[[match("TEST_A", ctx$universe)]]))) {
      stop("runtime scalar position does not match ctx$position")
    }
    expected_current <- stats::setNames(as.numeric(ctx$position), ctx$universe)
    if (!identical(ctx$hold(), expected_current)) {
      stop("runtime hold accessor does not match ctx$position")
    }

    observed$count <- observed$count + 1L
    targets <- ctx$flat()
    if (observed$count == 1L && ctx$close[["TEST_A"]] > 0) {
      targets["TEST_A"] <- 1
    }
    targets
  }

  testthat::expect_error(
    ledgr_test_run(
      snapshot = snap,
      strategy = helper_strategy,
      universe = c("TEST_A", "TEST_B"),
      start = "2020-01-01",
      end = max(bars$ts_utc),
      db_path = db_path,
    cost_model = ledgr_cost_zero()
    ),
    NA
  )
  testthat::expect_gt(observed$count, 0L)
})

# ledgr-test-profile: heavy_protocol
testthat::test_that("feature-map strategies match across execution modes", {
  bars <- ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:4)
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  features <- ledgr_feature_map(ret = ledgr_ind_returns(2))
  strategy <- function(ctx, params) {
    x <- ctx$ret[["AAA"]]
    if (!identical(x, ctx[["return_2"]][["AAA"]])) {
      stop("mapped feature value does not match scalar feature accessor")
    }
    targets <- ctx$flat()
    if (ledgr_passed_warmup(x) && x > 0) {
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
        execution_mode = mode,
      cost_model = ledgr_cost_zero()
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
