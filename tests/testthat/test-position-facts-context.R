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

testthat::test_that("canonical replay preserves real same-bar order and non-fill semantics", {
  axis <- as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:3
  fill_rows <- data.frame(
    event_id = paste0("same-bar-", 1:3), run_id = "same-bar",
    ts_utc = rep(axis[[2L]], 3L), event_type = "FILL",
    instrument_id = "AAA", side = c("BUY", "SELL", "BUY"),
    qty = c(1, 1, 2), price = c(100, 101, 102), fee = 0,
    meta_json = NA_character_, event_seq = 1:3, stringsAsFactors = FALSE
  )
  replay <- ledgr:::ledgr_replay_accounting_events(
    ledgr:::ledgr_prepare_accounting_events(fill_rows, "AAA"), initial_cash = 1000
  )
  facts <- ledgr:::ledgr_position_facts_from_replay(replay, axis)
  testthat::expect_identical(facts$entry_bar, 2L)
  testthat::expect_identical(facts$exit_bar, 2L)
  reordered <- fill_rows[c(1L, 3L, 2L), , drop = FALSE]
  reordered$event_seq <- seq_len(nrow(reordered))
  reordered_replay <- ledgr:::ledgr_replay_accounting_events(
    ledgr:::ledgr_prepare_accounting_events(reordered, "AAA"), initial_cash = 1000
  )
  testthat::expect_false(identical(
    ledgr:::ledgr_position_facts_from_replay(reordered_replay, axis), facts
  ))

  disposition_meta <- list(
    source = "corporate_action_disposition", source_fact_id = "fact-1",
    position_delta = -1, cash_delta = 90, quantity = 1, mark = 90,
    mark_source_ts_utc = "2020-01-03T00:00:00Z", mark_age = 0L,
    position_before = 1, position_after = 0, realized_model_pnl = -10,
    disposition_policy_id = "test-policy"
  )
  nonfill_rows <- fill_rows[1L, , drop = FALSE]
  nonfill_rows$event_id <- "entry"
  nonfill_rows$ts_utc <- axis[[2L]]
  nonfill_rows$event_seq <- 1L
  disposition <- nonfill_rows
  disposition$event_id <- "disposition"
  disposition$ts_utc <- axis[[3L]]
  disposition$event_type <- "DISPOSITION"
  disposition$side <- NA_character_
  disposition$price <- 90
  disposition$meta_json <- as.character(canonical_json(disposition_meta))
  disposition$event_seq <- 2L
  replay <- ledgr:::ledgr_replay_accounting_events(
    ledgr:::ledgr_prepare_accounting_events(rbind(nonfill_rows, disposition), "AAA"),
    initial_cash = 1000
  )
  rebuilt <- ledgr:::ledgr_position_facts_from_replay(replay, axis)
  live <- ledgr:::ledgr_position_fact_state(1L)
  live <- ledgr:::ledgr_position_facts_apply(live, 1L, 0, 1, 2L, TRUE)
  live <- ledgr:::ledgr_position_facts_apply(live, 1L, 1, 0, 3L, FALSE)
  testthat::expect_identical(rebuilt, live)
  testthat::expect_true(is.na(rebuilt$entry_bar))
  testthat::expect_true(is.na(rebuilt$exit_bar))
  fills_only <- ledgr:::ledgr_replay_accounting_events(
    ledgr:::ledgr_prepare_accounting_events(nonfill_rows, "AAA"), initial_cash = 1000
  )
  testthat::expect_false(identical(
    ledgr:::ledgr_position_facts_from_replay(fills_only, axis), rebuilt
  ))
  disposition_as_fill <- ledgr:::ledgr_position_fact_state(1L)
  disposition_as_fill <- ledgr:::ledgr_position_facts_apply(
    disposition_as_fill, 1L, 0, 1, 2L, TRUE
  )
  disposition_as_fill <- ledgr:::ledgr_position_facts_apply(
    disposition_as_fill, 1L, 1, 0, 3L, TRUE
  )
  testthat::expect_false(identical(disposition_as_fill, rebuilt))
})

testthat::test_that("split and recipient non-fill changes never fabricate anchors", {
  facts <- ledgr:::ledgr_position_fact_state(2L, entry_bar = c(2L, NA), exit_bar = c(1L, 1L))
  split <- ledgr:::ledgr_position_facts_apply(facts, 1L, 2, 4, 3L, FALSE)
  testthat::expect_identical(split, facts)
  recipient <- ledgr:::ledgr_position_facts_apply(
    facts, c(1L, 2L), c(2, 0), c(0, 2), 4L, FALSE
  )
  testthat::expect_true(all(is.na(recipient$entry_bar)))
  testthat::expect_identical(recipient$exit_bar, c(1L, 1L))
  recipient_as_fill <- ledgr:::ledgr_position_facts_apply(
    facts, c(1L, 2L), c(2, 0), c(0, 2), 4L, TRUE
  )
  testthat::expect_false(identical(recipient_as_fill, recipient))
})

testthat::test_that("plain, uncarried and carried configuration hashes bind exact provenance", {
  dates <- as.Date("2020-01-01") + 0:2
  snapshot <- ledgr_snapshot_from_df(ledgr_test_make_bars("AAA", dates))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  strategy <- function(ctx, params) ctx$flat()
  exp <- ledgr_experiment(snapshot, strategy, cost_model = ledgr_cost_zero())
  first <- ledgr_run(exp, run_id = "position-fact-hash-1")
  second <- ledgr_run(exp, run_id = "position-fact-hash-2")
  plain <- first$config
  testthat::expect_identical(config_hash(plain), config_hash(second$config))
  close(first)
  close(second)

  uncarried_null <- plain
  uncarried_null$opening$carried <- ledgr:::ledgr_opening_carried_normalize(NULL)
  uncarried_explicit <- plain
  uncarried_explicit$opening$carried <- ledgr:::ledgr_opening_carried_normalize(list(
    lots = NULL, pending = NULL, frozen = character(), position_facts = NULL
  ))
  testthat::expect_identical(
    config_hash(uncarried_null), config_hash(uncarried_explicit)
  )

  carried <- uncarried_null
  carried$opening$carried$position_facts <- list(
    instrument_id = "AAA", entry_at = "2020-01-01T00:00:00Z", exit_at = ""
  )
  changed <- carried
  changed$opening$carried$position_facts$entry_at <- "2020-01-02T00:00:00Z"
  testthat::expect_false(identical(config_hash(uncarried_null), config_hash(carried)))
  testthat::expect_false(identical(config_hash(carried), config_hash(changed)))
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

testthat::test_that("three contiguous walk-forward windows retain entry and exit facts", {
  dates <- as.Date("2020-01-01") + 0:14
  snapshot <- ledgr_snapshot_from_df(ledgr_test_make_bars("AAA", dates))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  seen <- new.env(parent = emptyenv())
  seen$rows <- list()
  strategy <- function(ctx, params) {
    rows <- seen$rows[[ctx$run_id]] %||% list()
    rows[[length(rows) + 1L]] <- list(
      ts = ctx$ts_utc,
      entry_at = ctx$entry_at[["AAA"]],
      exit_at = ctx$exit_at[["AAA"]],
      entry_age = ctx$bars_since_entry[["AAA"]],
      exit_age = ctx$bars_since_exit[["AAA"]]
    )
    seen$rows[[ctx$run_id]] <- rows
    target <- ctx$hold()
    day <- substr(ctx$ts_utc, 1L, 10L)
    if (identical(day, "2020-01-04")) target[["AAA"]] <- 1
    if (identical(day, "2020-01-05")) target[["AAA"]] <- 0
    if (identical(day, "2020-01-06")) target[["AAA"]] <- 1
    target
  }
  exp <- ledgr_experiment(snapshot, strategy, cost_model = ledgr_cost_zero())
  folds <- ledgr:::ledgr_fold_list(list(
    ledgr_fold("2020-01-01", "2020-01-03", "2020-01-04", "2020-01-07", fold_seq = 1L),
    ledgr_fold("2020-01-04", "2020-01-07", "2020-01-08", "2020-01-10", fold_seq = 2L),
    ledgr_fold("2020-01-08", "2020-01-10", "2020-01-11", "2020-01-13", fold_seq = 3L)
  ), constructor = list(type_id = "position_fact_chain"))
  wf <- ledgr_walk_forward(
    exp,
    ledgr_grid_named(only = list(strategy = list())),
    folds,
    ledgr_rule_argmax("annualized_return"),
    no_selection = "previous",
    seed = 17L
  )
  on.exit(lapply(wf$test_runs, close), add = TRUE)
  testthat::expect_length(wf$test_runs, 3L)
  rows <- lapply(wf$test_runs, function(run) seen$rows[[run$run_id]][[1L]])
  testthat::expect_equal(rows[[2L]]$entry_at, as.POSIXct("2020-01-07", tz = "UTC"))
  testthat::expect_equal(rows[[3L]]$entry_at, rows[[2L]]$entry_at)
  testthat::expect_equal(rows[[2L]]$exit_at, as.POSIXct("2020-01-06", tz = "UTC"))
  testthat::expect_equal(rows[[3L]]$exit_at, rows[[2L]]$exit_at)
  testthat::expect_identical(rows[[2L]]$entry_age, 1)
  testthat::expect_identical(rows[[3L]]$entry_age, 4)
  testthat::expect_identical(rows[[2L]]$exit_age, 2)
  testthat::expect_identical(rows[[3L]]$exit_age, 5)
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

testthat::test_that("preparation counters increment at one site per run and candidate", {
  dates <- as.Date("2020-01-01") + 0:3
  snapshot <- ledgr_snapshot_from_df(ledgr_test_make_bars("AAA", dates))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  observed <- new.env(parent = emptyenv())
  original <- ledgr:::ledgr_context_preparation_increment
  testthat::local_mocked_bindings(
    ledgr_context_preparation_increment = function(counts, name) {
      observed[[name]] <- as.integer(observed[[name]] %||% 0L) + 1L
      original(counts, name)
    },
    .package = "ledgr"
  )
  strategy <- function(ctx, params) {
    invisible(ctx$entry_price)
    invisible(ctx$entry_price)
    ctx$flat()
  }
  exp <- ledgr_experiment(snapshot, strategy, cost_model = ledgr_cost_zero())
  run <- ledgr_run(exp, run_id = "preparation-one-run")
  close(run)
  testthat::expect_identical(
    mget(c("service", "feature_resolver", "fill_axis_map"), observed),
    list(service = 1L, feature_resolver = 1L, fill_axis_map = 1L)
  )
  rm(list = ls(observed, all.names = TRUE), envir = observed)
  sweep <- ledgr_sweep(
    exp,
    ledgr_grid_named(a = list(strategy = list(tag = "a")), b = list(strategy = list(tag = "b"))),
    workers = 1L
  )
  testthat::expect_true(all(sweep$status == "DONE"))
  testthat::expect_identical(
    mget(c("service", "feature_resolver", "fill_axis_map"), observed),
    list(service = 2L, feature_resolver = 2L, fill_axis_map = 2L)
  )
})

testthat::test_that("scheduled decision skips still count absolute entry age", {
  seen <- new.env(parent = emptyenv())
  seen$rows <- list()
  strategy <- ledgr_strategy_schedule(function(ctx, params) {
    rows <- seen$rows
    rows[[length(rows) + 1L]] <- list(
      ts = ctx$ts_utc, entry = ctx$entry_at[["AAA"]], age = ctx$bars_since_entry[["AAA"]]
    )
    seen$rows <- rows
    target <- ctx$hold()
    if (length(rows) == 1L) target[["AAA"]] <- 1
    target
  }, ledgr_schedule_dates(as.Date(c("2021-01-04", "2021-01-13"))))
  fixture <- ws42_history_fixture(strategy = strategy, features = list())
  on.exit(ledgr_snapshot_close(fixture$snapshot), add = TRUE)
  run <- ledgr_run(fixture$exp, run_id = "position-fact-skipped-decisions")
  close(run)
  testthat::expect_length(seen$rows, 2L)
  testthat::expect_equal(seen$rows[[2L]]$entry, fixture$axis[[2L]])
  testthat::expect_identical(seen$rows[[2L]]$age, 6)
})

testthat::test_that("position fact transitions refuse off-axis timestamps", {
  axis <- as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:2
  fill_axis <- ledgr:::ledgr_position_fact_fill_axis(axis, axis[1:2], axis[2:3])
  testthat::expect_identical(
    ledgr:::ledgr_position_fact_fill_bar(fill_axis, 1L, rep(axis[[2L]], 2L)),
    2L
  )
  testthat::expect_error(
    ledgr:::ledgr_position_fact_fill_bar(fill_axis, 1L, c(axis[[2L]], axis[[3L]])),
    class = "ledgr_position_fact_off_axis"
  )
  testthat::expect_error(
    ledgr:::ledgr_position_fact_bar_index(axis[[1L]] + 3600, axis),
    class = "ledgr_position_fact_off_axis"
  )
  testthat::expect_error(
    ledgr:::ledgr_position_fact_replay_axis_map(
      list(operation = 1L, ts_utc = axis[[1L]] - 3600), axis
    ),
    class = "ledgr_position_fact_off_axis"
  )
})
