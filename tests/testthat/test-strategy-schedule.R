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
    json_declaration <- ledgr:::ledgr_json_read_nested(
      as.character(canonical_json(unclass(rule)))
    )
    testthat::expect_identical(
      unclass(ledgr:::ledgr_schedule_validate(json_declaration)),
      unclass(ledgr:::ledgr_schedule_validate(rule))
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
  malformed_dates <- list(
    list(type_id = "dates", version = 1L, args = list(dates = "foo")),
    list(type_id = "dates", version = 1L, args = list(dates = "2024-13-45")),
    list(type_id = "dates", version = 1L, args = list(dates = "2024-01-05junk")),
    list(type_id = "dates", version = 1L, args = list(dates = "2024-01-05"), extra = TRUE)
  )
  for (declaration in malformed_dates) {
    testthat::expect_error(
      ledgr_strategy_schedule(strategy, declaration),
      class = "ledgr_invalid_strategy_schedule"
    )
  }
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
  compile_slice <- function(rule, pulse_index) {
    ledgr:::ledgr_compile_strategy_schedule(
      unclass(rule), list(), sessions, sessions$session_close[pulse_index]
    )$decision_due
  }
  testthat::expect_identical(
    compile_slice(ledgr_schedule_month_start(), 3:4),
    c(TRUE, FALSE)
  )
  testthat::expect_identical(
    compile_slice(ledgr_schedule_month_end(), 5:6),
    c(FALSE, TRUE)
  )
  testthat::expect_identical(
    compile_slice(ledgr_schedule_month_end(), 8L),
    FALSE
  )
  testthat::expect_identical(
    compile(ledgr_schedule_dates(sessions$session_date[[1L]])),
    rep(FALSE, length(pulses))
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
  distinct_intraday <- sort(c(pulses[[1L]] - 60, pulses[[1L]]))
  testthat::expect_error(
    ledgr:::ledgr_compile_strategy_schedule(
      unclass(ledgr_schedule_month_start()), list(), sessions, distinct_intraday
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
  for (owner in c(
    "ledgr_register_strategy_fn", "ledgr_strategy_source_info",
    "ledgr_strategy_preflight"
  )) {
    owner_source <- paste(deparse(body(getFromNamespace(owner, "ledgr"))), collapse = "\n")
    testthat::expect_match(owner_source, "ledgr_strategy_schedule_inner", fixed = TRUE)
  }
  tier3 <- ledgr_strategy_schedule(
    function(ctx, params) missing_user_helper(ctx),
    ledgr_schedule_month_start()
  )
  testthat::expect_false(ledgr_strategy_preflight(tier3)$allowed)

  date_a <- unclass(ledgr_schedule_dates(as.Date("2024-01-05")))
  date_b <- unclass(ledgr_schedule_dates(as.Date("2024-01-08")))
  param_a <- unclass(ledgr_schedule_from_param("when"))
  param_b <- unclass(ledgr_schedule_from_param("rebalance_when"))
  testthat::expect_false(identical(
    ledgr:::ledgr_strategy_schedule_hash(date_a),
    ledgr:::ledgr_strategy_schedule_hash(date_b)
  ))
  testthat::expect_false(identical(
    ledgr:::ledgr_strategy_schedule_hash(param_a),
    ledgr:::ledgr_strategy_schedule_hash(param_b)
  ))
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
  reopened_run <- ledgr_run_open(fixture$snapshot, "schedule-run")
  on.exit(close(reopened_run), add = TRUE)
  sweep <- ledgr_sweep(
    fixture$exp,
    ledgr_grid_named(one = list(strategy = list()))
  )

  testthat::expect_s3_class(run, "ledgr_run")
  testthat::expect_identical(
    unclass(ledgr:::ledgr_schedule_validate(reopened_run$config$strategy_schedule)),
    unclass(ledgr:::ledgr_schedule_validate(run$config$strategy_schedule))
  )
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
  testthat::expect_error(
    ledgr_run(year_exp, run_id = "schedule-year-run"),
    class = "ledgr_schedule_no_decision"
  )
  year_sweep <- ledgr_sweep(
    year_exp,
    ledgr_grid_named(one = list(strategy = list()))
  )
  testthat::expect_identical(year_sweep$status, "FAILED")
  testthat::expect_match(year_sweep$error_class, "ledgr_schedule_no_decision", fixed = TRUE)
  candidate <- ledgr_candidate(sweep, "one")
  testthat::expect_identical(
    candidate$sweep_meta$strategy_schedule,
    unclass(ledgr_schedule_week_start())
  )
  config_with <- function(declaration) {
    out <- run$config
    out$strategy_schedule <- declaration
    ledgr:::config_hash(out)
  }
  testthat::expect_false(identical(
    config_with(unclass(ledgr_schedule_dates(fixture$days[[2L]]))),
    config_with(unclass(ledgr_schedule_dates(fixture$days[[3L]])))
  ))
  testthat::expect_false(identical(
    config_with(unclass(ledgr_schedule_from_param("when"))),
    config_with(unclass(ledgr_schedule_from_param("rebalance_when")))
  ))

  window <- ledgr:::ledgr_experiment_window(
    fixture$exp, fixture$days[[6L]], fixture$days[[8L]]
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
  testthat::expect_identical(
    counter$calls[[5L]], c(TRUE, FALSE, FALSE)
  )
  testthat::expect_identical(
    counter$calls[[6L]], c(TRUE, FALSE, FALSE)
  )

  plain_sweep <- ledgr_sweep(
    plain_exp,
    ledgr_grid_named(one = list(strategy = list()))
  )
  plain_candidate <- ledgr_candidate(plain_sweep, "one")
  testthat::expect_false("strategy_schedule" %in% names(plain_candidate$sweep_meta))
  testthat::expect_false("strategy_schedule_hash" %in% names(plain_candidate$sweep_meta))

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

# ledgr-test-profile: review
testthat::test_that("[LTB-0505] scheduled skips bypass only decision and plan stages", {
  counts <- new.env(parent = emptyenv())
  for (stage in c("p1", "p2", "p3", "p4", "p5")) counts[[stage]] <- 0L
  originals <- list(
    p1 = ledgr:::ledgr_fold_stage_observe_settle,
    p2 = ledgr:::ledgr_fold_stage_decide,
    p3 = ledgr:::ledgr_fold_stage_plan,
    p4 = ledgr:::ledgr_fold_stage_apply,
    p5 = ledgr:::ledgr_fold_stage_commit
  )
  count_stage <- function(name, fn) {
    force(name)
    force(fn)
    function(...) {
      counts[[name]] <- counts[[name]] + 1L
      fn(...)
    }
  }
  testthat::local_mocked_bindings(
    ledgr_fold_stage_observe_settle = count_stage("p1", originals$p1),
    ledgr_fold_stage_decide = count_stage("p2", originals$p2),
    ledgr_fold_stage_plan = count_stage("p3", originals$p3),
    ledgr_fold_stage_apply = count_stage("p4", originals$p4),
    ledgr_fold_stage_commit = count_stage("p5", originals$p5),
    .package = "ledgr"
  )

  strategy <- ledgr_strategy_schedule(
    function(ctx, params) {
      previous <- ctx$state_prev
      n <- if (is.null(previous) || is.null(previous$n)) 0L else previous$n
      list(
        targets = ctx$hold(),
        state_update = list(n = n + 1L),
        intent_reason = "rebalanced"
      )
    },
    ledgr_schedule_week_start()
  )
  fixture <- ws42_history_fixture(strategy = strategy, features = list())
  on.exit(ledgr_snapshot_close(fixture$snapshot), add = TRUE)
  run <- ledgr_run(fixture$exp, run_id = "scheduled-stage-gate")
  on.exit(close(run), add = TRUE)

  info <- ledgr_run_info(fixture$snapshot, run$run_id)
  testthat::expect_identical(counts$p1, info$pulse_count)
  testthat::expect_identical(counts$p4, info$pulse_count)
  testthat::expect_identical(counts$p5, info$pulse_count)
  testthat::expect_identical(counts$p2, info$decision_pulse_count)
  testthat::expect_identical(counts$p3, info$decision_pulse_count)
  testthat::expect_identical(
    info$decision_pulse_count + info$scheduled_skip_count,
    info$pulse_count
  )

  opened <- ledgr:::ledgr_run_store_open(fixture$snapshot$db_path)
  on.exit(ledgr:::ledgr_run_store_close(opened), add = TRUE)
  diagnostics <- DBI::dbGetQuery(
    opened$con,
    "SELECT instrument_id, stage, outcome, reason_code, reasons, detail_json FROM run_diagnostics WHERE run_id = ? AND reason_code = 'scheduled_skip' ORDER BY diagnostic_seq",
    params = list(run$run_id)
  )
  testthat::expect_identical(nrow(diagnostics), info$scheduled_skip_count)
  testthat::expect_identical(unique(diagnostics$instrument_id), "")
  testthat::expect_identical(unique(diagnostics$stage), "decision")
  testthat::expect_identical(unique(diagnostics$outcome), "skipped")
  testthat::expect_identical(unique(diagnostics$reasons), "scheduled_skip")
  testthat::expect_identical(unique(diagnostics$detail_json), "{}")

  states <- DBI::dbGetQuery(
    opened$con,
    "SELECT state_json FROM strategy_state WHERE run_id = ? ORDER BY ts_utc",
    params = list(run$run_id)
  )
  state_n <- vapply(
    states$state_json,
    function(json) {
      value <- ledgr:::ledgr_json_read_config(json)$n
      if (length(value) != 1L) 0L else as.integer(value)
    },
    integer(1)
  )
  testthat::expect_identical(length(state_n), info$pulse_count)
  testthat::expect_identical(max(state_n), info$decision_pulse_count)
  testthat::expect_identical(sum(diff(state_n) != 0L), info$decision_pulse_count)

  year_strategy <- ledgr_strategy_schedule(
    ledgr:::ledgr_strategy_schedule_inner(strategy),
    ledgr_schedule_year_start()
  )
  year_exp <- fixture$exp
  year_exp$strategy <- year_strategy
  testthat::expect_error(
    ledgr_run(year_exp, run_id = "scheduled-zero-flat"),
    class = "ledgr_schedule_no_decision"
  )
  year_exp$opening$positions <- c(AAA = 1)
  year_exp$opening$cost_basis <- c(AAA = 100)
  opened_run <- ledgr_run(year_exp, run_id = "scheduled-zero-opening")
  on.exit(close(opened_run), add = TRUE)
  opened_info <- ledgr_run_info(fixture$snapshot, opened_run$run_id)
  testthat::expect_identical(opened_info$decision_pulse_count, 0L)
  testthat::expect_identical(opened_info$scheduled_skip_count, opened_info$pulse_count)
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0506] schema 124 persists, reopens and discloses schedules", {
  strategy <- ledgr_strategy_schedule(
    function(ctx, params) list(targets = ctx$hold(), intent_reason = "rebalanced"),
    ledgr_schedule_week_start()
  )
  fixture <- ws42_history_fixture(strategy = strategy, features = list())
  on.exit(ledgr_snapshot_close(fixture$snapshot), add = TRUE)
  run <- ledgr_run(fixture$exp, run_id = "scheduled-persistence")
  on.exit(close(run), add = TRUE)

  opened <- ledgr:::ledgr_run_store_open(fixture$snapshot$db_path)
  provenance <- DBI::dbGetQuery(
    opened$con,
    "SELECT schedule_json, schedule_hash FROM run_provenance WHERE run_id = ?",
    params = list(run$run_id)
  )
  telemetry <- DBI::dbGetQuery(
    opened$con,
    "SELECT pulse_count, decision_pulse_count, scheduled_skip_count FROM run_telemetry WHERE run_id = ?",
    params = list(run$run_id)
  )
  ledgr:::ledgr_run_store_close(opened)
  declaration <- unclass(ledgr_schedule_week_start())
  testthat::expect_identical(
    provenance$schedule_json[[1]],
    ledgr:::ledgr_strategy_schedule_json(declaration)
  )
  testthat::expect_identical(
    provenance$schedule_hash[[1]],
    ledgr:::ledgr_strategy_schedule_hash(declaration)
  )
  testthat::expect_identical(
    as.integer(telemetry$decision_pulse_count + telemetry$scheduled_skip_count),
    as.integer(telemetry$pulse_count)
  )

  info <- ledgr_run_info(fixture$snapshot, run$run_id)
  testthat::expect_identical(
    unclass(ledgr:::ledgr_schedule_validate(info$strategy_schedule)),
    unclass(ledgr:::ledgr_schedule_validate(declaration))
  )
  recovered <- ledgr_run_strategy(fixture$snapshot, run$run_id, trust = TRUE)
  testthat::expect_identical(
    ledgr:::ledgr_strategy_schedule_declaration(recovered$strategy_function),
    declaration
  )
  reopened <- ledgr_run_open(fixture$snapshot, run$run_id)
  on.exit(close(reopened), add = TRUE)
  testthat::expect_identical(
    unclass(ledgr:::ledgr_schedule_validate(reopened$config$strategy_schedule)),
    unclass(ledgr:::ledgr_schedule_validate(declaration))
  )

  schedule_surfaces <- list(
    experiment = capture.output(print(fixture$exp)),
    plan = capture.output(print(ledgr_experiment_plan(fixture$exp))),
    info = capture.output(print(info)),
    run = capture.output(print(reopened)),
    summary = capture.output(summary(reopened))
  )
  for (surface in names(schedule_surfaces)) {
    text <- schedule_surfaces[[surface]]
    testthat::expect_true(
      any(grepl("Strategy schedule: week start", text, fixed = TRUE)),
      info = surface
    )
  }
  for (text in schedule_surfaces[c("info", "run", "summary")]) {
    testthat::expect_true(any(grepl("Decision pulses:", text, fixed = TRUE)))
    testthat::expect_true(any(grepl("scheduled skips:", text, fixed = TRUE)))
  }

  opened <- ledgr:::ledgr_run_store_open(fixture$snapshot$db_path)
  DBI::dbExecute(
    opened$con,
    "UPDATE run_provenance SET schedule_hash = 'wrong' WHERE run_id = ?",
    params = list(run$run_id)
  )
  ledgr:::ledgr_run_store_close(opened)
  testthat::expect_error(
    ledgr_run_strategy(fixture$snapshot, run$run_id),
    class = "ledgr_schedule_identity_mismatch"
  )
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0507] skipped pulses preserve economics and resume state", {
  opening <- ledgr_opening(
    cash = 1000,
    positions = c(AAA = 1),
    cost_basis = c(AAA = 10)
  )
  plain_strategy <- function(ctx, params) ctx$hold()
  scheduled_strategy <- ledgr_strategy_schedule(
    plain_strategy,
    ledgr_schedule_week_start()
  )
  plain <- ws42_history_fixture(
    strategy = plain_strategy,
    features = list(),
    opening = opening,
    dividend = c(2L, 3L)
  )
  scheduled <- ws42_history_fixture(
    strategy = scheduled_strategy,
    features = list(),
    opening = opening,
    dividend = c(2L, 3L)
  )
  on.exit(ledgr_snapshot_close(plain$snapshot), add = TRUE)
  on.exit(ledgr_snapshot_close(scheduled$snapshot), add = TRUE)
  plain_run <- ledgr_run(plain$exp, run_id = "schedule-economic-plain")
  scheduled_run <- ledgr_run(scheduled$exp, run_id = "schedule-economic-gated")
  on.exit(close(plain_run), add = TRUE)
  on.exit(close(scheduled_run), add = TRUE)

  economic_rows <- function(fixture, run_id) {
    opened <- ledgr:::ledgr_run_store_open(fixture$snapshot$db_path)
    on.exit(ledgr:::ledgr_run_store_close(opened))
    DBI::dbGetQuery(
      opened$con,
      paste(
        "SELECT event_seq, ts_utc, event_type, instrument_id, side, qty, price, fee, meta_json",
        "FROM ledger_events WHERE run_id = ? ORDER BY event_seq"
      ),
      params = list(run_id)
    )
  }
  testthat::expect_identical(
    economic_rows(plain, plain_run$run_id),
    economic_rows(scheduled, scheduled_run$run_id)
  )

  state_strategy <- ledgr_strategy_schedule(
    function(ctx, params) {
      previous <- ctx$state_prev
      n <- if (is.null(previous) || is.null(previous$n)) 0L else previous$n
      list(targets = ctx$hold(), state_update = list(n = n + 1L))
    },
    ledgr_schedule_week_start()
  )
  resumed <- ws42_history_fixture(strategy = state_strategy, features = list())
  on.exit(ledgr_snapshot_close(resumed$snapshot), add = TRUE)
  reference <- ledgr_run(resumed$exp, run_id = "schedule-resume-reference")
  on.exit(close(reference), add = TRUE)
  old_interrupt <- getOption("ledgr.interrupt")
  on.exit(options(ledgr.interrupt = old_interrupt), add = TRUE)
  options(ledgr.interrupt = TRUE)
  partial <- ledgr_run(resumed$exp, run_id = "schedule-resume")
  close(partial)
  options(ledgr.interrupt = FALSE)
  completed <- ledgr_run(resumed$exp, run_id = "schedule-resume")
  on.exit(close(completed), add = TRUE)

  opened <- ledgr:::ledgr_run_store_open(resumed$snapshot$db_path)
  on.exit(ledgr:::ledgr_run_store_close(opened), add = TRUE)
  fetch <- function(table, run_id, order) {
    DBI::dbGetQuery(
      opened$con,
      sprintf("SELECT * EXCLUDE(run_id) FROM %s WHERE run_id = ? ORDER BY %s", table, order),
      params = list(run_id)
    )
  }
  testthat::expect_identical(
    fetch("equity_curve", reference$run_id, "ts_utc"),
    fetch("equity_curve", completed$run_id, "ts_utc")
  )
  testthat::expect_identical(
    fetch("strategy_state", reference$run_id, "ts_utc"),
    fetch("strategy_state", completed$run_id, "ts_utc")
  )
})
