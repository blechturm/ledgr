testthat::test_that("PulseContext validates basic fields and per-pulse bars", {
  ts <- "2020-01-02T00:00:00Z"
  universe <- c("A", "B")

  bars <- data.frame(
    instrument_id = c("A", "B"),
    ts_utc = c(ts, ts),
    open = c(1, 2),
    stringsAsFactors = FALSE
  )

  ctx <- ledgr:::ledgr_pulse_context(
    run_id = "run-1",
    ts_utc = ts,
    universe = universe,
    bars = bars,
    features = data.frame(),
    positions = stats::setNames(c(0, 1), c("A", "B")),
    cash = 1000,
    equity = 1000,
    safety_state = "GREEN"
  )

  testthat::expect_true(inherits(ctx, "ledgr_pulse_context"))
  testthat::expect_identical(ctx$ts_utc, ts)
})

testthat::test_that("PulseContext rejects empty universe and duplicate instrument ids", {
  ts <- "2020-01-02T00:00:00Z"
  bars <- data.frame(instrument_id = "A", ts_utc = ts, stringsAsFactors = FALSE)

  testthat::expect_error(
    ledgr:::ledgr_pulse_context("run-1", ts, character(), bars, cash = 1, equity = 1),
    "universe",
    fixed = TRUE
  )

  testthat::expect_error(
    ledgr:::ledgr_pulse_context("run-1", ts, c("A", "A"), bars, cash = 1, equity = 1),
    "duplicate",
    ignore.case = TRUE
  )
})

testthat::test_that("PulseContext rejects bars ts mismatch and bars instrument outside universe", {
  ts <- "2020-01-02T00:00:00Z"
  universe <- c("A", "B")

  bars_bad_ts <- data.frame(
    instrument_id = c("A", "B"),
    ts_utc = c(ts, "2020-01-03T00:00:00Z"),
    stringsAsFactors = FALSE
  )

  testthat::expect_error(
    ledgr:::ledgr_pulse_context("run-1", ts, universe, bars_bad_ts, cash = 1, equity = 1),
    "timestamps",
    ignore.case = TRUE
  )

  bars_bad_inst <- data.frame(instrument_id = "C", ts_utc = ts, stringsAsFactors = FALSE)
  testthat::expect_error(
    ledgr:::ledgr_pulse_context("run-1", ts, universe, bars_bad_inst, cash = 1, equity = 1),
    "not in universe",
    ignore.case = TRUE
  )
})

testthat::test_that("PulseContext rejects positions outside universe", {
  ts <- "2020-01-02T00:00:00Z"
  universe <- c("A", "B")
  bars <- data.frame(instrument_id = "A", ts_utc = ts, stringsAsFactors = FALSE)

  positions <- stats::setNames(c(1), c("C"))
  testthat::expect_error(
    ledgr:::ledgr_pulse_context("run-1", ts, universe, bars, positions = positions, cash = 1, equity = 1),
    "positions",
    ignore.case = TRUE
  )
})

testthat::test_that("HoldZeroStrategy is deterministic and returns valid targets", {
  ts <- "2020-01-02T00:00:00Z"
  universe <- c("A", "B")
  bars <- data.frame(instrument_id = c("A", "B"), ts_utc = c(ts, ts), stringsAsFactors = FALSE)
  ctx <- ledgr:::ledgr_pulse_context("run-1", ts, universe, bars, cash = 1, equity = 1)

  strat <- ledgr:::HoldZeroStrategy$new()
  out1 <- strat$on_pulse(ctx)
  out2 <- strat$on_pulse(ctx)

  testthat::expect_identical(out1, out2)
  testthat::expect_identical(names(out1$targets), universe)
  testthat::expect_true(all(out1$targets == 0))
})

testthat::test_that("EchoStrategy validates targets names", {
  ts <- "2020-01-02T00:00:00Z"
  universe <- c("A", "B")
  bars <- data.frame(instrument_id = c("A", "B"), ts_utc = c(ts, ts), stringsAsFactors = FALSE)
  ctx <- ledgr:::ledgr_pulse_context("run-1", ts, universe, bars, cash = 1, equity = 1)

  good_targets <- stats::setNames(c(0, 1), c("A", "B"))
  strat_ok <- ledgr:::EchoStrategy$new(params = list(targets = good_targets))
  out <- strat_ok$on_pulse(ctx)
  testthat::expect_identical(out$targets, good_targets)

  bad_extra <- stats::setNames(c(0, 1, 2), c("A", "B", "C"))
  strat_extra <- ledgr:::EchoStrategy$new(params = list(targets = bad_extra))
  testthat::expect_error(strat_extra$on_pulse(ctx), "outside universe", ignore.case = TRUE)

  bad_missing <- stats::setNames(c(1), c("A"))
  strat_missing <- ledgr:::EchoStrategy$new(params = list(targets = bad_missing))
  testthat::expect_error(strat_missing$on_pulse(ctx), "must include all", ignore.case = TRUE)

  bad_negative <- stats::setNames(c(-1, 0), c("A", "B"))
  strat_negative <- ledgr:::EchoStrategy$new(params = list(targets = bad_negative))
  out_negative <- strat_negative$on_pulse(ctx)
  testthat::expect_identical(out_negative$targets, bad_negative)
})

testthat::test_that("shared target validation rejects extra and non-finite targets", {
  universe <- c("A", "B")

  valid <- ledgr:::ledgr_validate_strategy_targets(stats::setNames(c(2, 1), c("B", "A")), universe)
  testthat::expect_identical(valid, stats::setNames(c(1, 2), universe))

  testthat::expect_error(
    ledgr:::ledgr_validate_strategy_targets(stats::setNames(c(0, 1, 2), c("A", "B", "C")), universe),
    class = "ledgr_invalid_strategy_result"
  )
  testthat::expect_error(
    ledgr:::ledgr_validate_strategy_targets(stats::setNames(c(0, Inf), universe), universe),
    class = "ledgr_invalid_strategy_result"
  )
  testthat::expect_error(
    ledgr:::ledgr_validate_strategy_targets(c(0, 1), universe),
    class = "ledgr_invalid_strategy_result"
  )
})

testthat::test_that("mutation guardrail catches a mutating strategy", {
  ts <- "2020-01-02T00:00:00Z"
  universe <- c("A", "B")
  bars <- data.frame(instrument_id = c("A", "B"), ts_utc = c(ts, ts), stringsAsFactors = FALSE)
  ctx <- ledgr:::ledgr_pulse_context("run-1", ts, universe, bars, cash = 1, equity = 1)

  strat <- ledgr:::BadMutatingStrategy$new()
  testthat::expect_error(strat$on_pulse(ctx), "mutated internal state", ignore.case = TRUE)
})

