ws16_target_context <- function() {
  list(
    universe = c("AAA", "BBB", "OLD", "MISS"),
    equity = 1000,
    cash = 400,
    close = c(AAA = 10, BBB = 20, OLD = 5, MISS = NA_real_),
    position = c(AAA = 10, BBB = 5, OLD = 4, MISS = 2),
    held = c(AAA = TRUE, BBB = TRUE, OLD = TRUE, MISS = TRUE),
    member = c(AAA = TRUE, BBB = TRUE, OLD = FALSE, MISS = TRUE),
    buyable = c(AAA = TRUE, BBB = TRUE, OLD = FALSE, MISS = TRUE),
    holding_value = c(AAA = 100, BBB = 100, OLD = 20, MISS = 30),
    .notes = new.env(parent = emptyenv())
  )
}

# ledgr-test-profile: fast
testthat::test_that("[LTB-0529] plain selection and weights bind rank, pool and empty rules", {
  score <- c(z = 2, A = 2, b = NA_real_, q = 1)
  testthat::expect_identical(ledgr_select_top(score, n = 2), c("A", "z"))
  testthat::expect_identical(ledgr_select_lowest(score, n = 2), c("q", "A"))
  testthat::expect_identical(ledgr_select_top(score, n = 0), character())
  testthat::expect_identical(
    ledgr_select_top(score, fraction = 0.25),
    "A"
  )
  testthat::expect_identical(
    ledgr_select_top(score, n = 4, within = c(q = TRUE, z = NA, A = TRUE, b = FALSE)),
    c("A", "q")
  )
  testthat::expect_identical(
    ledgr_select_lowest(score, n = 2, within = c("z", "q")),
    c("q", "z")
  )
  testthat::expect_identical(ledgr_weight_equal(c("A", "q")), c(A = 0.5, q = 0.5))
  testthat::expect_identical(ledgr_weight_equal(c("A", "q"), each = 0.2), c(A = 0.2, q = 0.2))
  testthat::expect_identical(ledgr_weight_equal(character()), stats::setNames(numeric(), character()))

  for (bad in list(
    quote(ledgr_select_top(score, n = 1, fraction = 0.5)),
    quote(ledgr_select_top(score, n = -1)),
    quote(ledgr_select_top(score, n = .Machine$integer.max + 1)),
    quote(ledgr_select_top(score, fraction = 0)),
    quote(ledgr_select_top(score, n = 1, within = c(TRUE, FALSE))),
    quote(ledgr_select_top(score, n = 1, within = c(nope = TRUE))),
    quote(ledgr_weight_equal(c("A", "A"))),
    quote(ledgr_weight_equal(c("A", "q"), each = 0.6))
  )) {
    testthat::expect_error(eval(bad), class = "rlang_error")
  }
  testthat::expect_false(inherits(ledgr_select_top(score, n = 1), "ledgr_selection"))
  testthat::expect_false(inherits(ledgr_weight_equal("A"), "ledgr_weights"))

  retired <- c(
    paste0("ledgr_signal_", "feature"),
    paste0("ledgr_select_top", "_n"),
    paste0("ledgr_strategy_", "schedule")
  )
  has_retired_public_spelling <- function(lines) {
    any(vapply(retired, function(name) {
      public_pattern <- paste0(
        "export\\(", name, "\\)|\\\\alias\\{", name,
        "\\}|(^|[^[:alnum:]_])", name, "[[:space:]]*\\("
      )
      any(grepl(public_pattern, lines, perl = TRUE))
    }, logical(1)))
  }
  root <- testthat::test_path("..", "..")
  source_files <- c(
    list.files(file.path(root, "R"), full.names = TRUE, pattern = "[.]R$"),
    list.files(file.path(root, "man"), full.names = TRUE, pattern = "[.]Rd$"),
    list.files(
      file.path(root, "vignettes"),
      full.names = TRUE,
      recursive = TRUE,
      pattern = "[.](qmd|md)$"
    )
  )
  maintained <- c(
    readLines(file.path(root, "NAMESPACE"), warn = FALSE),
    unlist(lapply(source_files, readLines, warn = FALSE), use.names = FALSE)
  )
  testthat::expect_false(has_retired_public_spelling(maintained))
  testthat::expect_true(
    has_retired_public_spelling(c(maintained, "export(ledgr_select_top_n)"))
  )
})

# ledgr-test-profile: fast
testthat::test_that("[LTB-0530] ctx-first target verbs share sizing and make book policy explicit", {
  ctx <- ws16_target_context()
  rebalance <- ledgr_target_rebalance(
    ctx,
    weights = c(AAA = 0.5, BBB = 0.5),
    keep = "OLD",
    index_leavers = "sell",
    capital_base = "remaining_equity",
    invest_fraction = 0.8
  )
  piped <- c(AAA = 0.5, BBB = 0.5) |>
    ledgr_target_rebalance(
      ctx,
      weights = _,
      keep = "OLD",
      index_leavers = "sell",
      capital_base = "remaining_equity",
      invest_fraction = 0.8
    )
  testthat::expect_identical(rebalance, piped)
  testthat::expect_identical(
    stats::setNames(as.numeric(rebalance), names(rebalance)),
    c(AAA = 39, BBB = 19, OLD = 4, MISS = 0)
  )
  testthat::expect_identical(attr(rebalance, "origin")$capital_base, "remaining_equity")
  testthat::expect_identical(attr(rebalance, "origin")$invest_fraction, 0.8)

  # Character keeps decide named leavers before the general policy. Logical
  # keeps never do, so the general sell still wins for OLD.
  character_keep <- ledgr_target_rebalance(ctx, keep = "OLD", index_leavers = "sell")
  logical_keep <- ledgr_target_rebalance(
    ctx,
    keep = c(AAA = TRUE, BBB = TRUE, OLD = TRUE, MISS = TRUE),
    index_leavers = "sell"
  )
  general_keep <- ledgr_target_rebalance(ctx, index_leavers = "keep")
  testthat::expect_identical(as.numeric(character_keep), c(0, 0, 4, 0))
  testthat::expect_identical(as.numeric(logical_keep), c(10, 5, 0, 2))
  testthat::expect_identical(as.numeric(general_keep), c(0, 0, 4, 0))

  testthat::expect_error(
    ledgr_target_rebalance(ctx, weights = c(AAA = 1)),
    class = "ledgr_invalid_strategy_result",
    regexp = "leavers"
  )
  testthat::expect_error(
    ledgr_target_rebalance(
      ctx, weights = c(AAA = 1), keep = "OLD", index_leavers = "sell"
    ),
    class = "ledgr_invalid_args",
    regexp = "capital_base"
  )
  testthat::expect_error(
    ledgr_target_rebalance(
      ctx, weights = c(OLD = 0.5), keep = "OLD", index_leavers = "sell"
    ),
    class = "ledgr_invalid_strategy_helper"
  )
  testthat::expect_error(
    ledgr_target_adjust(ctx, weights = c(AAA = 0.5), exit = c(TRUE, FALSE, FALSE, FALSE)),
    class = "ledgr_invalid_strategy_result"
  )
  testthat::expect_error(
    ledgr_target_rebalance(
      ctx,
      weights = c(AAA = 0.5),
      keep = c(AAA = TRUE, BBB = FALSE, OLD = FALSE, MISS = FALSE),
      index_leavers = "sell"
    ),
    class = "ledgr_invalid_strategy_result"
  )
  testthat::expect_error(
    ledgr_target_adjust(ctx, weights = c(AAA = 0.5), add_value = c(AAA = 20)),
    class = "ledgr_invalid_strategy_result"
  )
  testthat::expect_error(
    ledgr_target_adjust(
      ctx,
      add_value = c(AAA = 20),
      exit = c(AAA = TRUE, BBB = FALSE, OLD = FALSE, MISS = FALSE)
    ),
    class = "ledgr_invalid_strategy_result"
  )

  held <- ledgr_target_adjust(ctx)
  testthat::expect_identical(as.numeric(held), as.numeric(ctx$position))
  testthat::expect_identical(attr(held, "origin")$capital_base, "not_required")
  cleared <- ledgr_target_rebalance(ctx, keep = "OLD", index_leavers = "sell")
  testthat::expect_identical(as.numeric(cleared), c(0, 0, 4, 0))
  adjusted <- ledgr_target_adjust(
    ctx,
    weights = c(AAA = 0.5),
    add_value = c(BBB = 40),
    capital_base = "total_equity"
  )
  testthat::expect_identical(as.numeric(adjusted), c(50, 7, 4, 2))

  # P, A and U each reserve exactly once. Existing BBB exposure is in P and
  # the requested 40 currency units are in A, leaving 810 for AAA.
  once_only <- ledgr_target_adjust(
    ctx,
    weights = c(AAA = 1),
    add_value = c(BBB = 40),
    capital_base = "remaining_equity"
  )
  testthat::expect_identical(as.numeric(once_only), c(81, 7, 4, 2))

  zero_unpriced <- ledgr_target_rebalance(
    ctx,
    weights = c(MISS = 0),
    keep = "OLD",
    index_leavers = "sell"
  )
  testthat::expect_identical(as.numeric(zero_unpriced), c(0, 0, 4, 0))

  unavailable <- ledgr_target_adjust(
    ctx,
    weights = c(MISS = 0.2),
    capital_base = "total_equity"
  )
  testthat::expect_identical(unavailable[["MISS"]], 2)
  testthat::expect_identical(attr(unavailable, "sizing_skipped"), "MISS")
  testthat::expect_identical(ctx$.notes$sizing_skipped, "MISS")

  guard_ctx <- ws16_target_context()
  guard_ctx$holding_value[["MISS"]] <- 300
  guarded <- ledgr_target_adjust(
    guard_ctx,
    weights = c(AAA = 0.8, MISS = 0.2),
    capital_base = "total_equity"
  )
  testthat::expect_identical(as.numeric(guarded), c(70, 5, 4, 2))

  unmarked <- ws16_target_context()
  unmarked$holding_value[["OLD"]] <- NA_real_
  testthat::expect_error(
    ledgr_target_adjust(unmarked),
    class = "ledgr_target_sizing_unavailable"
  )

  # Both public verbs are deliberately thin wrappers over one private engine.
  source <- readLines(
    file.path(testthat::test_path("..", ".."), "R", "strategy-helpers.R"),
    warn = FALSE
  )
  testthat::expect_identical(sum(grepl("^[[:space:]]*ledgr_target_size\\(", source)), 2L)
})

# ledgr-test-profile: fast
testthat::test_that("[LTB-0531] construction requires investor inputs and schedule queries are pure", {
  snapshot <- ws42_dense_snapshot()
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  strategy <- function(ctx, params) ctx$hold()
  testthat::expect_error(
    ledgr_experiment(snapshot, strategy, cost_model = ledgr_cost_zero()),
    class = "ledgr_invalid_experiment",
    regexp = "ledgr_opening"
  )
  testthat::expect_error(
    ledgr_experiment(snapshot, strategy, opening = ledgr_opening(cash = 1)),
    class = "ledgr_cost_model_unspecified",
    regexp = "ledgr_cost_zero"
  )
  testthat::expect_error(
    ledgr_opening(cash = 0, positions = c(AAA = 0)),
    class = "ledgr_invalid_opening",
    regexp = "opening positions"
  )
  zero <- ledgr_experiment(
    snapshot,
    strategy,
    opening = ledgr_opening(cash = 0, positions = c(AAA = 1), cost_basis = c(AAA = 11)),
    cost_model = ledgr_cost_zero()
  )
  testthat::expect_identical(zero$opening$cash, 0)
  zero_run <- ledgr_run(zero, run_id = "ws16-zero-cash-opening")
  on.exit(close(zero_run), add = TRUE)
  zero_equity <- ledgr_results(zero_run, "equity")
  testthat::expect_gt(nrow(zero_equity), 0L)
  testthat::expect_true(all(zero_equity$equity > 0))
  experiment_text <- paste(utils::capture.output(print(zero)), collapse = "\n")
  plan_text <- paste(
    utils::capture.output(print(ledgr_experiment_plan(zero))),
    collapse = "\n"
  )
  for (text in list(experiment_text, plan_text)) {
    testthat::expect_match(text, "Opening:", fixed = TRUE)
    testthat::expect_match(text, "cash=0", fixed = TRUE)
    testthat::expect_match(text, "positions=1", fixed = TRUE)
    testthat::expect_match(text, "Costs:", fixed = TRUE)
    testthat::expect_match(text, "supplied (zero)", fixed = TRUE)
  }

  calls <- 0L
  ctx <- structure(
    list(
      .schedule_query = function(schedule) {
        calls <<- calls + 1L
        identical(schedule$type_id, "month_start")
      }
    ),
    class = c("ledgr_pulse_context", "list")
  )
  declaration <- ledgr_schedule_month_start()
  testthat::expect_true(ledgr_schedule_due(ctx, declaration))
  testthat::expect_true(ledgr_schedule_due(ctx, declaration))
  testthat::expect_identical(calls, 2L)

  compiler_calls <- 0L
  testthat::with_mocked_bindings({
    query <- ledgr:::ledgr_strategy_schedule_query(
      sessions = data.frame(),
      pulses_posix = as.POSIXct(c("2021-01-04", "2021-01-05"), tz = "UTC"),
      strategy_params = list()
    )
    testthat::expect_true(query(declaration, 1L))
    testthat::expect_false(query(ledgr_schedule_month_start(), 2L))
    testthat::expect_identical(compiler_calls, 1L)
  },
    ledgr_compile_strategy_schedule = function(...) {
      compiler_calls <<- compiler_calls + 1L
      list(decision_due = c(TRUE, FALSE))
    },
    .package = "ledgr"
  )

  stop_strategy <- function(ctx, params) {
    decision_day <- substr(ctx$ts_utc, 1L, 10L)
    state <- ctx$state_prev
    state$dates <- c(state$dates, decision_day)
    state$due <- c(
      state$due,
      ledgr_schedule_due(ctx, ledgr_schedule_weekday("wednesday"))
    )
    targets <- if (identical(decision_day, "2021-01-05")) ctx$flat() else ctx$hold()
    list(targets = targets, state_update = state)
  }
  fixture <- ws42_history_fixture(
    strategy = stop_strategy,
    features = list(),
    opening = ledgr_opening(
      cash = 1000,
      positions = c(AAA = 1),
      cost_basis = c(AAA = 11)
    )
  )
  on.exit(ledgr_snapshot_close(fixture$snapshot), add = TRUE)
  run <- ledgr_run(fixture$exp, run_id = "ws16-mixed-cadence-stop")
  on.exit(close(run), add = TRUE, after = FALSE)
  fills <- ledgr_results(run, "fills")
  seen <- availability_last_state(run)
  testthat::expect_identical(length(seen$dates), length(fixture$days))
  testthat::expect_identical(seen$due, as.integer(format(fixture$days, "%u")) == 3L)
  testthat::expect_identical(fills$side, "SELL")
  testthat::expect_identical(as.Date(fills$ts_utc), as.Date("2021-01-06"))

  sweep <- ledgr_sweep(
    fixture$exp,
    ledgr_grid_named(one = list(strategy = list())),
    seed = 531L
  )
  testthat::expect_identical(sweep$status, "DONE")
  testthat::expect_equal(
    sweep$final_equity[[1L]],
    tail(ledgr_results(run, "equity")$equity, 1L)
  )
})
