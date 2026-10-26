schedule_test_axis <- function() {
  dates <- as.Date(c(
    "2024-01-30", "2024-01-31", "2024-02-01", "2024-02-02",
    "2024-02-05", "2024-02-29", "2024-03-01", "2024-03-04"
  ))
  data.frame(
    session_date = dates,
    status = "open",
    session_close = as.POSIXct(paste(dates, "21:00:00"), tz = "UTC"),
    stringsAsFactors = FALSE
  )
}

# ledgr-test-profile: review
testthat::test_that("[LTB-0501] schedule declarations are inert and serializable", {
  captured <- 7
  strategy <- function(ctx, params) ctx$hold(reason = as.character(captured))
  rules <- list(
    ledgr_schedule_month_start(), ledgr_schedule_month_end(),
    ledgr_schedule_week_start(), ledgr_schedule_quarter_start(),
    ledgr_schedule_year_start(),
    ledgr_schedule_dates(as.Date(c("2024-02-03", "2024-02-03"))),
    ledgr_schedule_from_param("when")
  )

  for (rule in rules) {
    scheduled <- ledgr_strategy_schedule(strategy, rule)
    testthat::expect_s3_class(scheduled, "ledgr_scheduled_strategy")
    testthat::expect_identical(body(scheduled), body(strategy))
    testthat::expect_identical(environment(scheduled), environment(strategy))
    testthat::expect_identical(
      unserialize(serialize(attr(scheduled, "ledgr_schedule"), NULL)),
      attr(scheduled, "ledgr_schedule")
    )
  }
  testthat::expect_error(
    ledgr_strategy_schedule(
      ledgr_strategy_schedule(strategy, ledgr_schedule_month_start()),
      ledgr_schedule_month_end()
    ),
    class = "ledgr_invalid_strategy_schedule"
  )
  testthat::expect_error(
    ledgr_strategy_schedule(
      strategy,
      list(type_id = "month_start", version = 1.5, args = list())
    ),
    class = "ledgr_invalid_strategy_schedule"
  )
  testthat::expect_error(
    ledgr_strategy_schedule(1L, ledgr_schedule_month_start()),
    class = "ledgr_invalid_strategy_schedule"
  )
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0502] compiler binds parent-axis boundary semantics", {
  sessions <- schedule_test_axis()
  pulses <- sessions$session_close[c(2L, 3L, 5L, 6L, 7L)]
  compile <- function(rule, params = list()) {
    ledgr:::ledgr_compile_strategy_schedule(
      unclass(rule), params, sessions, pulses
    )$decision_due
  }

  # Jan 31 is not a month start; Feb 1 and Mar 1 are. Feb 29 is a month end,
  # while the partial executable range does not turn its final pulse into one.
  testthat::expect_identical(
    compile(ledgr_schedule_month_start()),
    c(FALSE, TRUE, FALSE, FALSE, TRUE)
  )
  testthat::expect_identical(
    compile(ledgr_schedule_month_end()),
    c(TRUE, FALSE, FALSE, TRUE, FALSE)
  )
  testthat::expect_identical(
    compile(ledgr_schedule_week_start()),
    c(FALSE, FALSE, TRUE, TRUE, FALSE)
  )
  testthat::expect_identical(
    compile(ledgr_schedule_dates(as.Date(c("2024-02-03", "2024-02-04")))),
    c(FALSE, FALSE, TRUE, FALSE, FALSE)
  )
  testthat::expect_identical(
    compile(ledgr_schedule_from_param("when"), list(when = "month_start")),
    compile(ledgr_schedule_month_start())
  )

  boundary_sessions <- data.frame(
    session_date = as.Date(c("2023-12-29", "2024-01-02", "2024-03-28", "2024-04-01")),
    status = "open",
    session_close = as.POSIXct(
      paste(c("2023-12-29", "2024-01-02", "2024-03-28", "2024-04-01"), "21:00:00"),
      tz = "UTC"
    )
  )
  boundary_compile <- function(rule) {
    ledgr:::ledgr_compile_strategy_schedule(
      unclass(rule), list(), boundary_sessions, boundary_sessions$session_close
    )$decision_due
  }
  testthat::expect_identical(
    boundary_compile(ledgr_schedule_quarter_start()),
    c(FALSE, TRUE, FALSE, TRUE)
  )
  testthat::expect_identical(
    boundary_compile(ledgr_schedule_year_start()),
    c(FALSE, TRUE, FALSE, FALSE)
  )
  for (token in ledgr:::ledgr_schedule_fixed_types) {
    direct <- do.call(get(paste0("ledgr_schedule_", token)), list())
    testthat::expect_identical(
      compile(ledgr_schedule_from_param("when"), list(when = token)),
      compile(direct)
    )
  }
  long_dates <- seq(as.Date("2023-12-01"), as.Date("2025-02-28"), by = "day")
  long_dates <- long_dates[!as.POSIXlt(long_dates)$wday %in% c(0L, 6L)]
  long_sessions <- data.frame(
    session_date = long_dates,
    status = "open",
    session_close = as.POSIXct(paste(long_dates, "21:00:00"), tz = "UTC")
  )
  parameter_masks <- lapply(ledgr:::ledgr_schedule_fixed_types, function(token) {
    ledgr:::ledgr_compile_strategy_schedule(
      unclass(ledgr_schedule_from_param("when")), list(when = token),
      long_sessions, long_sessions$session_close
    )$decision_due
  })
  testthat::expect_length(unique(vapply(
    parameter_masks, function(mask) paste(as.integer(mask), collapse = ""), character(1)
  )), length(ledgr:::ledgr_schedule_fixed_types))

  testthat::expect_error(
    compile(ledgr_schedule_dates(as.Date("2025-01-01"))),
    class = "ledgr_schedule_date_out_of_range"
  )
  testthat::expect_error(
    compile(ledgr_schedule_from_param("when"), list()),
    class = "ledgr_schedule_param_unresolved"
  )
  for (bad in list("week_end", 1L, NA_character_, c("month_start", "month_end"))) {
    testthat::expect_error(
      compile(ledgr_schedule_from_param("when"), list(when = bad)),
      class = "ledgr_schedule_param_unresolved"
    )
  }
  testthat::expect_error(
    compile(ledgr_schedule_dates(as.Date("2023-01-01"))),
    class = "ledgr_schedule_date_out_of_range"
  )
  testthat::expect_error(
    ledgr:::ledgr_compile_strategy_schedule(
      unclass(ledgr_schedule_month_start()), list(), NULL, pulses
    ),
    class = "ledgr_schedule_sessions_required"
  )
  duplicated <- c(pulses[[1L]], pulses[[1L]])
  testthat::expect_error(
    ledgr:::ledgr_compile_strategy_schedule(
      unclass(ledgr_schedule_month_start()), list(), sessions, duplicated
    ),
    class = "ledgr_schedule_intraday_unsupported"
  )
  duplicate_sessions <- rbind(sessions, sessions[1L, , drop = FALSE])
  testthat::expect_error(
    ledgr:::ledgr_compile_strategy_schedule(
      unclass(ledgr_schedule_month_start()), list(), duplicate_sessions, pulses
    ),
    class = "ledgr_schedule_axis_invalid"
  )
  testthat::expect_error(
    ledgr:::ledgr_compile_strategy_schedule(
      unclass(ledgr_schedule_month_start()), list(), sessions,
      pulses + 60
    ),
    class = "ledgr_schedule_axis_invalid"
  )
  absent <- ledgr:::ledgr_compile_strategy_schedule(NULL, list(), NULL, pulses)
  testthat::expect_null(absent$decision_due)
  testthat::expect_identical(absent$decision_pulse_count, length(pulses))
  testthat::expect_identical(absent$scheduled_skip_count, 0L)

  compiler_source <- paste(deparse(body(ledgr:::ledgr_compile_strategy_schedule)), collapse = "\n")
  testthat::expect_false(grepl("bars", compiler_source, fixed = TRUE))
  testthat::expect_false(grepl("format.POSIX", compiler_source, fixed = TRUE))
  testthat::expect_false(grepl("for (", compiler_source, fixed = TRUE))
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0503] schedule identity is separate from strategy source", {
  strategy <- function(ctx, params) ctx$hold()
  month <- ledgr_strategy_schedule(strategy, ledgr_schedule_month_start())
  year <- ledgr_strategy_schedule(strategy, ledgr_schedule_year_start())
  plain <- ledgr:::ledgr_strategy_spec(strategy)
  month_spec <- ledgr:::ledgr_strategy_spec(month)
  year_spec <- ledgr:::ledgr_strategy_spec(year)

  testthat::expect_identical(month_spec$id, plain$id)
  testthat::expect_identical(month_spec$params, plain$params)
  testthat::expect_identical(month_spec$provenance, plain$provenance)
  testthat::expect_identical(year_spec$provenance, plain$provenance)
  testthat::expect_false(identical(
    month_spec$strategy_schedule,
    year_spec$strategy_schedule
  ))
  testthat::expect_identical(
    ledgr_strategy_preflight(month),
    ledgr_strategy_preflight(strategy)
  )
  tier3 <- ledgr_strategy_schedule(
    function(ctx, params) missing_user_helper(ctx),
    ledgr_schedule_month_start()
  )
  testthat::expect_false(ledgr_strategy_preflight(tier3)$allowed)
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0504] run and sweep compile the same schedule once", {
  counter <- new.env(parent = emptyenv())
  counter$calls <- list()
  original <- ledgr:::ledgr_compile_strategy_schedule
  testthat::local_mocked_bindings(
    ledgr_compile_strategy_schedule = function(declaration, strategy_params, sessions, pulses_posix) {
      out <- original(declaration, strategy_params, sessions, pulses_posix)
      counter$calls[[length(counter$calls) + 1L]] <- out$decision_due
      out
    },
    .package = "ledgr"
  )

  strategy <- ledgr_strategy_schedule(
    function(ctx, params) ctx$hold(),
    ledgr_schedule_week_start()
  )
  fixture <- ws42_history_fixture(strategy = strategy, features = list())
  on.exit(ledgr_snapshot_close(fixture$snapshot), add = TRUE)
  run <- ledgr_run(fixture$exp, run_id = "schedule-run")
  sweep <- ledgr_sweep(
    fixture$exp,
    ledgr_grid_named(one = list(strategy = list()))
  )

  testthat::expect_s3_class(run, "ledgr_run")
  testthat::expect_identical(sweep$status, "DONE")
  testthat::expect_length(counter$calls, 2L)
  testthat::expect_identical(counter$calls[[1L]], counter$calls[[2L]])
  testthat::expect_identical(
    run$config$strategy_schedule,
    unclass(ledgr_schedule_week_start())
  )

  plain_exp <- fixture$exp
  plain_exp$strategy <- ledgr:::ledgr_strategy_schedule_inner(strategy)
  plain_run <- ledgr_run(plain_exp, run_id = "plain-run")
  testthat::expect_null(plain_run$config$strategy_schedule)
  testthat::expect_false("strategy_schedule" %in% names(plain_run$config))
  testthat::expect_false("decision_due" %in% names(run$config))
  testthat::expect_false(identical(
    ledgr:::config_hash(run$config),
    ledgr:::config_hash(plain_run$config)
  ))

  year_exp <- fixture$exp
  year_exp$strategy <- ledgr_strategy_schedule(
    ledgr:::ledgr_strategy_schedule_inner(strategy),
    ledgr_schedule_year_start()
  )
  year_run <- ledgr_run(year_exp, run_id = "schedule-year-run")
  year_sweep <- ledgr_sweep(
    year_exp,
    ledgr_grid_named(one = list(strategy = list()))
  )
  testthat::expect_false(identical(
    ledgr:::config_hash(run$config),
    ledgr:::config_hash(year_run$config)
  ))
  testthat::expect_false(identical(
    attr(sweep, "strategy_schedule_hash"),
    attr(year_sweep, "strategy_schedule_hash")
  ))
  candidate <- ledgr_candidate(sweep, "one")
  testthat::expect_identical(
    candidate$sweep_meta$strategy_schedule,
    unclass(ledgr_schedule_week_start())
  )

  window <- ledgr:::ledgr_experiment_window(
    fixture$exp, fixture$days[[2L]], fixture$days[[7L]]
  )
  window_run <- ledgr:::ledgr_run_window(
    fixture$exp, window = window, run_id = "schedule-window-run"
  )
  on.exit(close(window_run), add = TRUE)
  window_sweep <- ledgr:::ledgr_sweep_window(
    fixture$exp,
    ledgr_grid_named(one = list(strategy = list())),
    window = window
  )
  testthat::expect_identical(window_sweep$status, "DONE")
  # The window reads a slice of the same parent-axis verdict: its first pulse
  # cannot manufacture a weekly boundary.
  testthat::expect_identical(
    counter$calls[[5L]],
    counter$calls[[6L]]
  )

  folds <- ledgr:::ledgr_fold_list(
    list(ledgr_fold(
      fixture$days[[1L]], fixture$days[[4L]],
      fixture$days[[5L]], fixture$days[[8L]], fold_seq = 1L
    )),
    constructor = list(type_id = "explicit")
  )
  walk_forward <- suppressWarnings(ledgr_walk_forward(
    fixture$exp,
    ledgr_grid_named(one = list(strategy = list())),
    folds,
    selection_rule = ledgr_rule_argmax("annualized_return"),
    seed = 1L
  ))
  on.exit(lapply(walk_forward$test_runs, close), add = TRUE)
  testthat::expect_s3_class(walk_forward, "ledgr_walk_forward_results")

  runner_source <- paste(deparse(body(ledgr:::ledgr_run_fold_impl)), collapse = "\n")
  sweep_source <- paste(deparse(body(ledgr:::ledgr_sweep_candidate_execution)), collapse = "\n")
  testthat::expect_identical(
    lengths(regmatches(runner_source, gregexpr("ledgr_compile_strategy_schedule", runner_source, fixed = TRUE))),
    1L
  )
  testthat::expect_identical(
    lengths(regmatches(sweep_source, gregexpr("ledgr_compile_strategy_schedule", sweep_source, fixed = TRUE))),
    1L
  )
  for (stage in c(
    "ledgr_fold_stage_observe_settle", "ledgr_fold_stage_decide",
    "ledgr_fold_stage_plan", "ledgr_fold_stage_apply", "ledgr_fold_stage_commit"
  )) {
    stage_source <- paste(deparse(body(getFromNamespace(stage, "ledgr"))), collapse = "\n")
    testthat::expect_false(grepl("ledgr_compile_strategy_schedule", stage_source, fixed = TRUE))
  }

  dense <- ws42_dense_snapshot()
  on.exit(ledgr_snapshot_close(dense), add = TRUE)
  testthat::expect_error(
    ledgr_experiment(dense, strategy, cost_model = ledgr_cost_zero()),
    class = "ledgr_schedule_sessions_required"
  )
})
