testthat::test_that("canonical fill transitions maintain flat context position facts", {
  dates <- as.Date("2020-01-01") + 0:5
  bars <- ledgr_test_make_bars("AAA", dates)
  snapshot <- ledgr_snapshot_from_df(bars)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  seen <- new.env(parent = emptyenv())
  seen$value <- list()
  strategy <- function(ctx, params) {
    seen$value[[length(seen$value) + 1L]] <- list(
      ts = ctx$ts_utc, position = ctx$position[["AAA"]],
      entry_price = ctx$entry_price[["AAA"]], entry_at = ctx$entry_at[["AAA"]],
      exit_at = ctx$exit_at[["AAA"]],
      since_entry = ctx$bars_since_entry[["AAA"]],
      since_exit = ctx$bars_since_exit[["AAA"]]
    )
    target <- ctx$hold()
    day <- substr(ctx$ts_utc, 1L, 10L)
    if (day == "2020-01-01") target[["AAA"]] <- 2
    if (day == "2020-01-03") target[["AAA"]] <- 0
    if (day == "2020-01-04") target[["AAA"]] <- 1
    target
  }
  exp <- ledgr_experiment(
    snapshot, strategy, universe = "AAA",
    opening = ledgr_opening(cash = 10000), cost_model = ledgr_cost_zero()
  )
  bt <- ledgr_run(exp, run_id = "position-facts-live")
  on.exit(close(bt), add = TRUE)

  x <- seen$value
  testthat::expect_identical(vapply(x, `[[`, numeric(1), "position"), c(0, 2, 2, 0, 1, 1))
  testthat::expect_true(is.na(x[[1L]]$entry_at))
  testthat::expect_equal(x[[2L]]$entry_at, as.POSIXct("2020-01-02", tz = "UTC"))
  testthat::expect_identical(x[[2L]]$since_entry, 0)
  testthat::expect_identical(x[[3L]]$since_entry, 1)
  testthat::expect_equal(x[[4L]]$exit_at, as.POSIXct("2020-01-04", tz = "UTC"))
  testthat::expect_identical(x[[4L]]$since_exit, 0)
  testthat::expect_equal(x[[5L]]$entry_at, as.POSIXct("2020-01-05", tz = "UTC"))
  testthat::expect_equal(x[[5L]]$exit_at, as.POSIXct("2020-01-04", tz = "UTC"))
  testthat::expect_identical(x[[5L]]$since_entry, 0)
  testthat::expect_identical(x[[5L]]$since_exit, 1)
  testthat::expect_true(all(vapply(x[1:3], function(v) is.infinite(v$since_exit), logical(1))))
})

testthat::test_that("non-fill transitions invalidate entry without fabricating exit", {
  facts <- ledgr:::ledgr_position_fact_state(1L, entry_bar = 3L, exit_bar = 2L)
  facts <- ledgr:::ledgr_position_facts_apply(facts, 1L, 2, 0, 4L, FALSE)
  testthat::expect_true(is.na(facts$entry_bar))
  testthat::expect_identical(facts$exit_bar, 2L)
  facts <- ledgr:::ledgr_position_facts_apply(facts, 1L, 0, 5, 5L, FALSE)
  testthat::expect_true(is.na(facts$entry_bar))
  testthat::expect_identical(facts$exit_bar, 2L)
})

testthat::test_that("same-bar transitions follow event order", {
  facts <- ledgr:::ledgr_position_fact_state(1L)
  facts <- ledgr:::ledgr_position_facts_apply(facts, 1L, 0, 2, 3L, TRUE)
  testthat::expect_identical(facts$entry_bar, 3L)
  facts <- ledgr:::ledgr_position_facts_apply(facts, 1L, 2, 0, 3L, TRUE)
  testthat::expect_true(is.na(facts$entry_bar))
  testthat::expect_identical(facts$exit_bar, 3L)
  facts <- ledgr:::ledgr_position_facts_apply(facts, 1L, 0, 1, 3L, TRUE)
  testthat::expect_identical(facts$entry_bar, 3L)
  testthat::expect_identical(facts$exit_bar, 3L)
})

testthat::test_that("resume rebuilds position facts from the committed accounting prefix", {
  dates <- as.Date("2020-01-01") + 0:5
  snapshot <- ledgr_snapshot_from_df(ledgr_test_make_bars("AAA", dates))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  seen <- new.env(parent = emptyenv())
  seen$rows <- list()
  strategy <- function(ctx, params) {
    seen$rows[[length(seen$rows) + 1L]] <- list(
      ts = ctx$ts_utc,
      entry_at = ctx$entry_at[["AAA"]],
      bars_since_entry = ctx$bars_since_entry[["AAA"]],
      entry_price = ctx$entry_price[["AAA"]]
    )
    target <- ctx$hold()
    if (identical(ctx$ts_utc, "2020-01-01T00:00:00Z")) target[["AAA"]] <- 2
    target
  }
  exp <- ledgr_experiment(
    snapshot, strategy,
    opening = ledgr_opening(cash = 10000),
    cost_model = ledgr_cost_zero()
  )
  setup <- ledgr_run(exp, run_id = "facts-config")
  config <- setup$config
  close(setup)
  seen$rows <- list()
  partial <- ledgr:::ledgr_run_fold(
    config, run_id = "facts-resume", control = list(max_pulses = 3L)
  )
  before <- length(seen$rows)
  resumed <- ledgr_run_config(config, run_id = "facts-resume")
  first <- seen$rows[[before + 1L]]
  testthat::expect_identical(first$ts, "2020-01-04T00:00:00Z")
  testthat::expect_equal(first$entry_at, as.POSIXct("2020-01-02", tz = "UTC"))
  testthat::expect_identical(first$bars_since_entry, 2)
  testthat::expect_true(is.finite(first$entry_price))
})

testthat::test_that("carried facts retain shared-axis anchors and external openings do not invent them", {
  axis <- as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:5
  state <- ledgr:::ledgr_position_fact_state(2L, entry_bar = c(2L, NA), exit_bar = c(1L, NA))
  carried <- ledgr:::ledgr_position_facts_carried(state, c("AAA", "BBB"), axis)
  rebuilt <- ledgr:::ledgr_position_facts_from_carried(
    list(position_facts = carried), c("AAA", "BBB"), axis
  )
  testthat::expect_identical(rebuilt, state)

  external <- ledgr:::ledgr_position_facts_from_carried(
    list(position_facts = NULL), c("AAA", "BBB"), axis
  )
  testthat::expect_true(all(is.na(external$entry_bar)))
  testthat::expect_true(all(is.na(external$exit_bar)))
})
