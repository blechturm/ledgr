testthat::test_that("flat context columns are named, lazy, strict and frozen", {
  ts <- as.POSIXct("2020-01-02", tz = "UTC")
  bars <- data.frame(
    ts_utc = rep(ts, 2L), instrument_id = c("BBB", "AAA"),
    open = c(20, 10), high = c(21, 11), low = c(19, 9),
    close = c(20.5, 10.5), volume = c(200, 100)
  )
  features <- data.frame(
    ts_utc = rep(ts, 2L), instrument_id = c("AAA", "BBB"),
    feature_name = "score", feature_value = c(1, 2)
  )
  positions <- c(AAA = 3, BBB = 0)
  counts <- new.env(parent = emptyenv())
  ctx <- ledgr:::ledgr_pulse_context(
    "flat", ts, c("AAA", "BBB"), bars, features, positions,
    cash = 100, equity = 131.5
  )
  ctx$.pulse_lookup$build_counts <- counts

  testthat::expect_identical(ctx$close, c(AAA = 10.5, BBB = 20.5))
  testthat::expect_identical(ctx$position, c(AAA = 3, BBB = 0))
  testthat::expect_identical(ctx$held, c(AAA = TRUE, BBB = FALSE))
  testthat::expect_identical(ctx$buyable, c(AAA = TRUE, BBB = TRUE))
  testthat::expect_identical(ctx$holding_value, c(AAA = 31.5, BBB = 0))
  testthat::expect_identical(ctx$score, c(AAA = 1, BBB = 2))
  invisible(ctx$close)
  testthat::expect_identical(counts$close, 1L)
  testthat::expect_identical(counts$score, 1L)

  before_names <- names(ctx)
  utils::capture.output(str(ctx))
  testthat::expect_identical(names(ctx), before_names)
  testthat::expect_false(exists("open", counts, inherits = FALSE))

  bars$close[] <- 999
  positions[] <- 99
  testthat::expect_identical(ctx$close, c(AAA = 10.5, BBB = 20.5))
  testthat::expect_identical(ctx$position, c(AAA = 3, BBB = 0))
  testthat::expect_error(ctx$missing_column, class = "ledgr_unknown_context_field")
  testthat::expect_error(ctx$vec, class = "ledgr_unknown_context_field")
  testthat::expect_error(ctx$feature("AAA", "score"), class = "ledgr_unknown_context_field")
})

testthat::test_that("feature names cannot shadow flat context fields", {
  testthat::expect_error(
    ledgr_feature_map(close = ledgr_ind_sma(2)),
    "reserved pulse context field",
    class = "ledgr_invalid_feature_map"
  )
})

testthat::test_that("held positions without a permissible mark keep unknown holding value", {
  ts <- as.POSIXct("2020-01-02", tz = "UTC")
  bars <- data.frame(
    ts_utc = ts, instrument_id = "AAA", open = NA_real_, high = NA_real_,
    low = NA_real_, close = NA_real_, volume = NA_real_
  )
  ctx <- ledgr:::ledgr_pulse_context(
    "unpriced", ts, "AAA", bars, positions = c(AAA = 2), cash = 0, equity = 0
  )
  testthat::expect_true(is.na(ctx$holding_value[["AAA"]]))
})

testthat::test_that("changing and holdings-only axes retain exact flat names", {
  ts <- as.POSIXct("2020-01-02", tz = "UTC")
  bars <- data.frame(
    ts_utc = rep(ts, 2L), instrument_id = c("AAA", "OLD"),
    open = c(10, 20), high = c(11, 21), low = c(9, 19),
    close = c(10, 20), volume = c(100, 200)
  )
  ctx <- ledgr:::ledgr_pulse_context(
    "holdings-only", ts, c("AAA", "OLD"), bars,
    positions = c(AAA = 0, OLD = 2), cash = 100, equity = 140
  )
  availability <- list(
    member = c(AAA = TRUE, OLD = FALSE), held = c(AAA = FALSE, OLD = TRUE),
    target_restricted = c(AAA = FALSE, OLD = TRUE),
    target_restriction_reason = c(AAA = "", OLD = "not_member"),
    priced = c(AAA = TRUE, OLD = TRUE), mark_age = c(AAA = 0L, OLD = 0L),
    risk_mark = c(AAA = 10, OLD = 20),
    mark_source = c(AAA = "current_close", OLD = "current_close")
  )
  ctx <- ledgr:::ledgr_update_pulse_context_helpers(ctx, availability = availability)
  testthat::expect_identical(names(ctx$member), c("AAA", "OLD"))
  testthat::expect_identical(ctx$member, c(AAA = TRUE, OLD = FALSE))
  testthat::expect_identical(ctx$held, c(AAA = FALSE, OLD = TRUE))
  testthat::expect_identical(ctx$position, c(AAA = 0, OLD = 2))
  changed <- ledgr:::ledgr_pulse_context(
    "changed", ts, "AAA", bars[1L, , drop = FALSE],
    positions = c(AAA = 0), cash = 100, equity = 100
  )
  testthat::expect_identical(names(changed$close), "AAA")
  testthat::expect_identical(names(changed$position), "AAA")
})

testthat::test_that("saved fold views freeze lazy buffers and sweep candidates isolate them", {
  dates <- as.Date("2020-01-01") + 0:3
  bars <- ledgr_test_make_bars("AAA", dates)
  snapshot <- ledgr_snapshot_from_df(bars)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  saved <- new.env(parent = emptyenv())
  strategy <- function(ctx, params) {
    if (is.null(saved$ctx)) {
      saved$ctx <- ctx
    } else {
      saved$later_open <- saved$ctx$open
    }
    ctx$flat()
  }
  exp <- ledgr_experiment(opening = ledgr_opening(cash = 100000), snapshot, strategy, cost_model = ledgr_cost_zero())
  run <- ledgr_run(exp, run_id = "flat-buffer-freeze")
  close(run)
  testthat::expect_identical(saved$later_open, c(AAA = bars$open[[1L]]))
  testthat::expect_false(identical(saved$later_open, c(AAA = bars$open[[2L]])))

  starts <- new.env(parent = emptyenv())
  candidate_strategy <- function(ctx, params) {
    if (!exists(params$tag, starts, inherits = FALSE)) {
      starts[[params$tag]] <- ctx$position
    }
    target <- ctx$hold()
    target[["AAA"]] <- params$qty
    target
  }
  candidate_exp <- ledgr_experiment(opening = ledgr_opening(cash = 100000),
    snapshot, candidate_strategy, cost_model = ledgr_cost_zero()
  )
  result <- ledgr_sweep(
    candidate_exp,
    ledgr_grid_named(
      first = list(strategy = list(tag = "first", qty = 1)),
      second = list(strategy = list(tag = "second", qty = 2))
    ),
    workers = 1L
  )
  testthat::expect_true(all(result$status == "DONE"))
  testthat::expect_identical(starts$first, c(AAA = 0))
  testthat::expect_identical(starts$second, c(AAA = 0))
})
