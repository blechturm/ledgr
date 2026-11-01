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
    if (day == "2020-01-02") target[["AAA"]] <- 3
    if (day == "2020-01-03") target[["AAA"]] <- 1
    if (day == "2020-01-04") target[["AAA"]] <- 0
    if (day == "2020-01-05") target[["AAA"]] <- 1
    target
  }
  exp <- ledgr_experiment(
    snapshot, strategy, universe = "AAA",
    opening = ledgr_opening(cash = 10000), cost_model = ledgr_cost_zero()
  )
  bt <- ledgr_run(exp, run_id = "position-facts-live")
  on.exit(close(bt), add = TRUE)

  x <- seen$value
  testthat::expect_identical(vapply(x, `[[`, numeric(1), "position"), c(0, 2, 3, 1, 0, 1))
  testthat::expect_true(is.na(x[[1L]]$entry_at))
  testthat::expect_equal(x[[2L]]$entry_at, as.POSIXct("2020-01-02", tz = "UTC"))
  testthat::expect_identical(x[[2L]]$since_entry, 0)
  testthat::expect_identical(x[[3L]]$since_entry, 1)
  testthat::expect_identical(x[[4L]]$since_entry, 2)
  testthat::expect_true(is.finite(x[[4L]]$entry_price))
  testthat::expect_equal(x[[5L]]$exit_at, as.POSIXct("2020-01-05", tz = "UTC"))
  testthat::expect_identical(x[[5L]]$since_exit, 0)
  testthat::expect_equal(x[[6L]]$entry_at, as.POSIXct("2020-01-06", tz = "UTC"))
  testthat::expect_equal(x[[6L]]$exit_at, as.POSIXct("2020-01-05", tz = "UTC"))
  testthat::expect_identical(x[[6L]]$since_entry, 0)
  testthat::expect_identical(x[[6L]]$since_exit, 1)
  testthat::expect_true(all(vapply(x[1:4], function(v) is.infinite(v$since_exit), logical(1))))
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

testthat::test_that("durable resume preserves carried opening anchors", {
  dates <- as.Date("2020-01-01") + 0:5
  snapshot <- ledgr_snapshot_from_df(ledgr_test_make_bars("AAA", dates))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  seen <- new.env(parent = emptyenv())
  seen$rows <- list()
  strategy <- function(ctx, params) {
    seen$rows[[length(seen$rows) + 1L]] <- c(
      entry = as.numeric(ctx$entry_at[["AAA"]]),
      entry_age = ctx$bars_since_entry[["AAA"]],
      exit = as.numeric(ctx$exit_at[["AAA"]]),
      exit_age = ctx$bars_since_exit[["AAA"]]
    )
    ctx$hold()
  }
  opening <- ledgr_opening(
    cash = 10000, positions = c(AAA = 2), cost_basis = c(AAA = 100)
  )
  opening$carried <- list(
    lots = NULL, pending = NULL, frozen = character(),
    position_facts = list(
      instrument_id = "AAA",
      entry_at = "2020-01-01T00:00:00Z",
      exit_at = "2020-01-01T00:00:00Z"
    )
  )
  exp <- ledgr_experiment(
    snapshot, strategy, opening = opening, cost_model = ledgr_cost_zero()
  )
  seed_run <- ledgr_run(exp, run_id = "carried-facts-config")
  config <- seed_run$config
  close(seed_run)

  seen$rows <- list()
  live <- ledgr_run_config(config, run_id = "carried-facts-live")
  live_rows <- seen$rows
  seen$rows <- list()
  partial <- ledgr:::ledgr_run_fold(
    config, run_id = "carried-facts-resume", control = list(max_pulses = 2L)
  )
  prefix_n <- length(seen$rows)
  resumed <- ledgr_run_config(config, run_id = "carried-facts-resume")
  testthat::expect_equal(seen$rows[(prefix_n + 1L):length(seen$rows)], live_rows[(prefix_n + 1L):length(live_rows)])
})

testthat::test_that("pulse inspection reports unknown basis and anchors for supplied positions", {
  bars <- ledgr_test_make_bars(c("AAA", "BBB"), as.Date("2020-01-01") + 0:4)
  snapshot <- ledgr_snapshot_from_df(bars)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  pulse <- ledgr_pulse_snapshot(
    snapshot, c("AAA", "BBB"), max(bars$ts_utc), positions = c(AAA = 2)
  )
  on.exit(close(pulse), add = TRUE)
  testthat::expect_identical(pulse$position, c(AAA = 2, BBB = 0))
  testthat::expect_true(all(is.na(pulse$entry_price)))
  testthat::expect_true(all(is.na(pulse$entry_at)))
  testthat::expect_true(all(is.na(pulse$exit_at)))
})

testthat::test_that("position facts build only on first read and services prepare once", {
  dates <- as.Date("2020-01-01") + 0:3
  snapshot <- ledgr_snapshot_from_df(ledgr_test_make_bars("AAA", dates))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  counters <- new.env(parent = emptyenv())
  strategy <- function(ctx, params) {
    counters$ctx <- ctx
    if (isTRUE(params$read)) {
      invisible(ctx$entry_price)
      invisible(ctx$entry_price)
    }
    ctx$flat()
  }
  exp <- ledgr_experiment(snapshot, strategy, cost_model = ledgr_cost_zero())
  no_read <- ledgr_run(exp, params = list(read = FALSE), run_id = "facts-lazy-none")
  close(no_read)
  lookup <- unclass(counters$ctx)[[".pulse_lookup"]]
  testthat::expect_false(exists("entry_price", lookup$build_counts, inherits = FALSE))
  testthat::expect_identical(
    mget(c("service", "feature_resolver", "fill_axis_map"), lookup$preparation_counts),
    list(service = 1L, feature_resolver = 1L, fill_axis_map = 1L)
  )
  read <- ledgr_run(exp, params = list(read = TRUE), run_id = "facts-lazy-read")
  close(read)
  lookup <- unclass(counters$ctx)[[".pulse_lookup"]]
  testthat::expect_identical(lookup$build_counts$entry_price, length(dates))
})

testthat::test_that("position fact transitions refuse off-axis timestamps", {
  axis <- as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:2
  testthat::expect_error(
    ledgr:::ledgr_position_fact_bar_index(axis[[1L]] + 3600, axis),
    class = "ledgr_position_fact_off_axis"
  )
})
