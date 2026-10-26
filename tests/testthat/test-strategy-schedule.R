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
    ledgr_schedule_weekday("wednesday"), ledgr_schedule_month_day(15),
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
testthat::test_that("[LTB-0512] scheduled skips retain valuation evidence", {
  opening <- ledgr_opening(cash = 1000, positions = c(BBB = 2), cost_basis = c(BBB = 42))
  manual_strategy <- function(ctx, params) {
    if (!ctx$ts_utc %in% params$due) return(ctx$hold())
    previous <- ctx$state_prev
    n <- if (is.null(previous) || is.null(previous$n)) 0L else previous$n
    list(targets = ctx$hold(), state_update = list(n = n + 1L), intent_reason = "rebalanced")
  }
  scheduled_strategy <- ledgr_strategy_schedule(
    function(ctx, params) {
      previous <- ctx$state_prev
      n <- if (is.null(previous) || is.null(previous$n)) 0L else previous$n
      list(targets = ctx$hold(), state_update = list(n = n + 1L), intent_reason = "rebalanced")
    },
    ledgr_schedule_week_start()
  )
  fixture <- ws42_history_fixture(
    strategy = manual_strategy, features = list(), opening = opening,
    valuation_policy = ledgr_valuation_stale(1)
  )
  on.exit(ledgr_snapshot_close(fixture$snapshot), add = TRUE)
  # week_start waits for the first proved boundary, so the partial first week
  # has no decision and the second Monday is the only due pulse.
  due <- ws42_iso(fixture$axis[[6L]])
  manual <- ledgr_run(fixture$exp, params = list(due = due), run_id = "schedule-valuation-manual")
  scheduled_exp <- fixture$exp
  scheduled_exp$strategy <- scheduled_strategy
  scheduled <- ledgr_run(
    scheduled_exp, params = list(due = due), run_id = "schedule-valuation-declared"
  )
  on.exit(close(manual), add = TRUE)
  on.exit(close(scheduled), add = TRUE)

  opened <- ledgr:::ledgr_run_store_open(fixture$snapshot$db_path)
  on.exit(ledgr:::ledgr_run_store_close(opened), add = TRUE)
  rows <- function(table, run_id, order) {
    DBI::dbGetQuery(
      opened$con,
      sprintf("SELECT * EXCLUDE(run_id) FROM %s WHERE run_id = ? ORDER BY %s", table, order),
      params = list(run_id)
    )
  }
  manual_events <- rows("ledger_events", manual$run_id, "event_seq")
  scheduled_events <- rows("ledger_events", scheduled$run_id, "event_seq")
  event_values <- setdiff(names(manual_events), "event_id")
  testthat::expect_identical(manual_events[event_values], scheduled_events[event_values])
  testthat::expect_identical(
    rows("equity_curve", manual$run_id, "ts_utc"),
    rows("equity_curve", scheduled$run_id, "ts_utc")
  )
  testthat::expect_identical(
    rows("strategy_state", manual$run_id, "ts_utc"),
    rows("strategy_state", scheduled$run_id, "ts_utc")
  )
  testthat::expect_identical(manual$status, scheduled$status)

  manual_valuation <- ledgr_valuation_summary(manual)
  scheduled_valuation <- ledgr_valuation_summary(scheduled)
  testthat::expect_identical(scheduled_valuation, manual_valuation)
  testthat::expect_identical(scheduled_valuation$valuation_state, "frozen")
  testthat::expect_identical(scheduled_valuation$stale_instrument_sessions, 1L)
  testthat::expect_identical(scheduled_valuation$frozen_instrument_sessions, 1L)

  diagnostics <- DBI::dbGetQuery(
    opened$con,
    paste(
      "SELECT ts_utc, instrument_id, stage, outcome, reason_code, quantity, mark_source",
      "FROM run_diagnostics WHERE run_id = ? ORDER BY diagnostic_seq"
    ),
    params = list(scheduled$run_id)
  )
  skips <- diagnostics[diagnostics$reason_code == "scheduled_skip", , drop = FALSE]
  testthat::expect_identical(nrow(skips), 7L)
  testthat::expect_identical(unique(skips$instrument_id), "")
  testthat::expect_identical(unique(skips$stage), "decision")
  testthat::expect_identical(unique(skips$outcome), "skipped")
  marks <- diagnostics[
    diagnostics$stage == "valuation" & diagnostics$outcome == "marked",
    ,
    drop = FALSE
  ]
  testthat::expect_identical(marks$instrument_id, c("BBB", "BBB"))
  testthat::expect_identical(marks$mark_source, c("stale_close", "frozen_close"))
  testthat::expect_true(all(marks$reason_code == ""))
  testthat::expect_true(all(as.numeric(marks$quantity) != 0))
  testthat::expect_true(all(ws42_iso(marks$ts_utc) %in% ws42_iso(fixture$axis[-c(1L, 6L)])))

  selected <- c(
    "valuation_state", "frozen_instrument_sessions",
    "max_frozen_equity_weight", "frozen_at_end_value"
  )
  listed <- ledgr_run_list(fixture$snapshot)
  compared <- ledgr_run_compare(
    fixture$snapshot, run_ids = c(manual$run_id, scheduled$run_id)
  )
  selected_values <- function(x) {
    at <- match(c(manual$run_id, scheduled$run_id), x$run_id)
    stats::setNames(lapply(selected, function(nm) unname(x[[nm]][at])), selected)
  }
  listed_values <- selected_values(listed)
  compared_values <- selected_values(compared)
  testthat::expect_identical(listed_values, compared_values)
  for (nm in selected) {
    testthat::expect_identical(compared_values[[nm]][[1L]], compared_values[[nm]][[2L]])
  }
  testthat::expect_identical(compared[[selected[[1L]]]], rep("frozen", 2L))
  testthat::expect_identical(compared[[selected[[2L]]]], rep(1L, 2L))
  testthat::expect_gt(compared_values$max_frozen_equity_weight[[2L]], 0)

  grid <- ledgr_grid_named(one = list(strategy = list(due = due)))
  manual_sweep <- ledgr_sweep(fixture$exp, grid, seed = 3119L)
  scheduled_sweep <- ledgr_sweep(scheduled_exp, grid, seed = 3119L)
  for (nm in selected) {
    testthat::expect_identical(manual_sweep[[nm]], scheduled_sweep[[nm]])
    testthat::expect_identical(scheduled_sweep[[nm]], compared_values[[nm]][[2L]])
  }
  warning_line <- "WARNING: this result relies on declared valuation or terminal assumptions."
  testthat::expect_true(warning_line %in% utils::capture.output(print(scheduled)))
  testthat::expect_true("Valuation Evidence:" %in% utils::capture.output(summary(scheduled)))

  close(scheduled)
  reopened <- ledgr_run_open(fixture$snapshot, "schedule-valuation-declared")
  on.exit(close(reopened), add = TRUE)
  testthat::expect_identical(ledgr_valuation_summary(reopened), manual_valuation)

  stale_fixture <- ws42_history_fixture(
    strategy = manual_strategy, features = list(), opening = opening,
    valuation_policy = ledgr_valuation_stale(3)
  )
  on.exit(ledgr_snapshot_close(stale_fixture$snapshot), add = TRUE)
  stale_due <- ws42_iso(stale_fixture$axis[[6L]])
  stale_manual <- ledgr_run(
    stale_fixture$exp, params = list(due = stale_due), run_id = "schedule-stale-manual"
  )
  stale_scheduled_exp <- stale_fixture$exp
  stale_scheduled_exp$strategy <- scheduled_strategy
  stale_scheduled <- ledgr_run(
    stale_scheduled_exp, params = list(due = stale_due), run_id = "schedule-stale-declared"
  )
  on.exit(close(stale_manual), add = TRUE)
  on.exit(close(stale_scheduled), add = TRUE)
  testthat::expect_identical(
    ledgr_valuation_summary(stale_scheduled), ledgr_valuation_summary(stale_manual)
  )
  testthat::expect_identical(ledgr_valuation_summary(stale_scheduled)$valuation_state, "stale")
  stale_list <- ledgr_run_list(stale_fixture$snapshot)
  stale_at <- match(c(stale_manual$run_id, stale_scheduled$run_id), stale_list$run_id)
  testthat::expect_identical(stale_list$valuation_state[stale_at], rep("stale", 2L))
  stale_grid <- ledgr_grid_named(one = list(strategy = list(due = stale_due)))
  stale_manual_sweep <- ledgr_sweep(stale_fixture$exp, stale_grid, seed = 3119L)
  stale_scheduled_sweep <- ledgr_sweep(stale_scheduled_exp, stale_grid, seed = 3119L)
  testthat::expect_identical(stale_manual_sweep$valuation_state, "stale")
  testthat::expect_identical(stale_scheduled_sweep$valuation_state, "stale")
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
testthat::test_that("[LTB-0510] common calendar schedules stay inside their period", {
  sessions_from_dates <- function(dates) {
    data.frame(
      session_date = dates,
      status = "open",
      session_close = as.POSIXct(paste(dates, "21:00:00"), tz = "UTC"),
      stringsAsFactors = FALSE
    )
  }
  due_dates <- function(rule, dates, pulse_dates = dates) {
    sessions <- sessions_from_dates(dates)
    pulse_index <- match(pulse_dates, dates)
    compiled <- ledgr:::ledgr_compile_strategy_schedule(
      unclass(rule), list(), sessions, sessions$session_close[pulse_index]
    )
    as.Date(format(pulse_dates[compiled$decision_due], "%Y-%m-%d"))
  }

  seven_day_dates <- seq(as.Date("2024-01-01"), as.Date("2024-01-07"), by = "day")
  for (index in seq_along(ledgr:::ledgr_schedule_weekday_tokens)) {
    token <- ledgr:::ledgr_schedule_weekday_tokens[[index]]
    testthat::expect_identical(
      due_dates(ledgr_schedule_weekday(token), seven_day_dates),
      as.Date(format(seven_day_dates[index], "%Y-%m-%d")),
      info = token
    )
  }

  weekday_dates <- as.Date(c(
    "2024-01-01", "2024-01-02", "2024-01-03", "2024-01-04",
    "2024-01-08", "2024-01-09", "2024-01-10", "2024-01-11"
  ))
  testthat::expect_identical(
    due_dates(ledgr_schedule_weekday("friday"), weekday_dates),
    as.Date(character())
  )
  testthat::expect_identical(
    due_dates(ledgr_schedule_weekday("monday"), weekday_dates),
    as.Date(c("2024-01-01", "2024-01-08"))
  )
  testthat::expect_identical(
    due_dates(
      ledgr_schedule_weekday("wednesday"),
      as.Date(c("2024-01-01", "2024-01-02", "2024-01-04", "2024-01-05"))
    ),
    as.Date("2024-01-04")
  )
  testthat::expect_identical(
    due_dates(
      ledgr_schedule_weekday("wednesday"),
      as.Date(c("2024-01-04", "2024-01-05", "2024-01-08", "2024-01-10"))
    ),
    as.Date("2024-01-10")
  )
  testthat::expect_identical(
    due_dates(
      ledgr_schedule_weekday("wednesday"),
      as.Date(c("2024-01-03", "2024-01-04", "2024-01-08", "2024-01-10"))
    ),
    as.Date(c("2024-01-03", "2024-01-10"))
  )
  long_weekdays <- seq(as.Date("2024-01-01"), as.Date("2024-01-18"), by = "day")
  long_weekdays <- long_weekdays[as.integer(format(long_weekdays, "%u")) <= 5L]
  testthat::expect_identical(
    due_dates(
      ledgr_schedule_weekday("wednesday"),
      long_weekdays,
      long_weekdays[long_weekdays >= as.Date("2024-01-11")]
    ),
    as.Date("2024-01-17")
  )

  calendar_dates <- seq(as.Date("2024-01-01"), as.Date("2024-04-30"), by = "day")
  calendar_dates <- calendar_dates[as.integer(format(calendar_dates, "%u")) <= 5L]
  month_cases <- list(
    `1` = as.Date(c("2024-01-01", "2024-02-01", "2024-03-01", "2024-04-01")),
    `15` = as.Date(c("2024-01-15", "2024-02-15", "2024-03-15", "2024-04-15")),
    `28` = as.Date(c("2024-01-29", "2024-02-28", "2024-03-28", "2024-04-29")),
    `29` = as.Date(c("2024-01-29", "2024-02-29", "2024-03-29", "2024-04-29")),
    `30` = as.Date(c("2024-01-30", "2024-04-30")),
    `31` = as.Date("2024-01-31")
  )
  for (day in names(month_cases)) {
    testthat::expect_identical(
      due_dates(ledgr_schedule_month_day(as.integer(day)), calendar_dates),
      month_cases[[day]],
      info = day
    )
  }
  testthat::expect_identical(
    due_dates(
      ledgr_schedule_month_day(15),
      calendar_dates[calendar_dates >= as.Date("2024-01-16")]
    )[1L],
    as.Date("2024-02-15")
  )
  testthat::expect_identical(
    due_dates(
      ledgr_schedule_month_day(15),
      calendar_dates[calendar_dates >= as.Date("2024-01-15")]
    )[1L],
    as.Date("2024-01-15")
  )
  january <- calendar_dates[format(calendar_dates, "%Y-%m") == "2024-01"]
  testthat::expect_identical(
    due_dates(ledgr_schedule_month_day(1), january),
    as.Date("2024-01-01")
  )
  testthat::expect_identical(
    due_dates(ledgr_schedule_month_start(), january),
    as.Date(character())
  )

  testthat::expect_identical(
    unclass(ledgr_schedule_month_day(15)),
    unclass(ledgr_schedule_month_day(15L))
  )
  round_trip <- ledgr:::ledgr_json_read_nested(as.character(canonical_json(
    unclass(ledgr_schedule_month_day(15))
  )))
  testthat::expect_identical(
    unclass(ledgr:::ledgr_schedule_validate(round_trip)),
    unclass(ledgr_schedule_month_day(15L))
  )
  testthat::expect_identical(
    ledgr:::ledgr_strategy_schedule_label(ledgr_schedule_weekday("wednesday")),
    "wednesday"
  )
  testthat::expect_identical(
    ledgr:::ledgr_strategy_schedule_label(ledgr_schedule_month_day(15)),
    "month day 15"
  )

  for (bad in list("Wednesday", "funday", NA_character_, c("monday", "tuesday"))) {
    testthat::expect_error(
      ledgr_schedule_weekday(bad),
      "exactly one of: monday, tuesday, wednesday, thursday, friday, saturday, sunday",
      class = "ledgr_invalid_strategy_schedule"
    )
  }
  for (bad in list(0, 32, 1.5, NA_real_, "15", c(15, 16))) {
    testthat::expect_error(
      ledgr_schedule_month_day(bad),
      "one whole number from 1 through 31",
      class = "ledgr_invalid_strategy_schedule"
    )
  }
  testthat::expect_error(
    ledgr:::ledgr_schedule_validate(list(
      type_id = "weekday", version = 1L, args = list(day = "Wednesday")
    )),
    class = "ledgr_invalid_strategy_schedule"
  )
  testthat::expect_error(
    ledgr:::ledgr_schedule_validate(list(
      type_id = "month_day", version = 1L, args = list(day = 32)
    )),
    class = "ledgr_invalid_strategy_schedule"
  )

  old_rules <- list(
    month_start = ledgr_schedule_month_start(),
    month_end = ledgr_schedule_month_end(),
    week_start = ledgr_schedule_week_start(),
    quarter_start = ledgr_schedule_quarter_start(),
    year_start = ledgr_schedule_year_start(),
    dates = ledgr_schedule_dates(as.Date("2024-01-05")),
    param = ledgr_schedule_from_param("when")
  )
  old_json <- c(
    month_start = '{"args":[],"type_id":"month_start","version":1}',
    month_end = '{"args":[],"type_id":"month_end","version":1}',
    week_start = '{"args":[],"type_id":"week_start","version":1}',
    quarter_start = '{"args":[],"type_id":"quarter_start","version":1}',
    year_start = '{"args":[],"type_id":"year_start","version":1}',
    dates = '{"args":{"dates":"2024-01-05"},"type_id":"dates","version":1}',
    param = '{"args":{"name":"when"},"type_id":"param","version":1}'
  )
  old_hashes <- c(
    month_start = "2764ab3064839f43dc7bff55101ce2da5bef1b7aba95344b8a647ee8c795c432",
    month_end = "06b70481ba748ef9f0dac2c5d47d7bcf6195894474de8144aa87578aace43504",
    week_start = "223c74557f761049094c7dc391327c134b68c218b43b41a64c518c932075a55e",
    quarter_start = "93df3cb4e876a4706a75cd23ad91903c553771cdf31c26e05aedc0de1fe659e8",
    year_start = "2df9e2d9bf595db35a967cb902bacf45b008f72302e4a3c297aad7d1a409c661",
    dates = "29701d4a33267c968d9caf36dd5096f072cff76c11ee643692895c53d7f516cb",
    param = "fce98ddc8161d67402fff61e67b7863f774eb46da56da510f9dc0ed0dcec6bfb"
  )
  testthat::expect_identical(
    vapply(old_rules, function(rule) as.character(canonical_json(unclass(rule))), character(1)),
    old_json
  )
  testthat::expect_identical(
    vapply(old_rules, ledgr:::ledgr_strategy_schedule_hash, character(1)),
    old_hashes
  )
  testthat::expect_false(identical(
    ledgr:::ledgr_strategy_schedule_hash(ledgr_schedule_weekday("monday")),
    ledgr:::ledgr_strategy_schedule_hash(ledgr_schedule_weekday("tuesday"))
  ))
  testthat::expect_false(identical(
    ledgr:::ledgr_strategy_schedule_hash(ledgr_schedule_month_day(15)),
    ledgr:::ledgr_strategy_schedule_hash(ledgr_schedule_month_day(16))
  ))

  compiler_source <- paste(
    deparse(body(ledgr:::ledgr_compile_strategy_schedule)),
    collapse = "\n"
  )
  testthat::expect_false(grepl("grepl(\"_start$\"", compiler_source, fixed = TRUE))
  testthat::expect_false(grepl("weekdays(", compiler_source, fixed = TRUE))
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
  counts$history_view <- 0L
  originals <- list(
    p1 = ledgr:::ledgr_fold_stage_observe_settle,
    p2 = ledgr:::ledgr_fold_stage_decide,
    p3 = ledgr:::ledgr_fold_stage_plan,
    p4 = ledgr:::ledgr_fold_stage_apply,
    p5 = ledgr:::ledgr_fold_stage_commit,
    history_reader = ledgr:::ledgr_history_substrate_fold_reader
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
    ledgr_history_substrate_fold_reader = function(...) {
      reader <- originals$history_reader(...)
      original_view <- reader$view
      reader$view <- function(...) {
        counts$history_view <- counts$history_view + 1L
        original_view(...)
      }
      reader
    },
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
  testthat::expect_identical(counts$history_view, info$decision_pulse_count)
  testthat::expect_identical(
    info$decision_pulse_count + info$scheduled_skip_count,
    info$pulse_count
  )

  opened <- ledgr:::ledgr_run_store_open(fixture$snapshot$db_path)
  on.exit(ledgr:::ledgr_run_store_close(opened), add = TRUE)
  diagnostics <- DBI::dbGetQuery(
    opened$con,
    "SELECT ts_utc, instrument_id, stage, outcome, reason_code, reasons, detail_json FROM run_diagnostics WHERE run_id = ? AND reason_code = 'scheduled_skip' ORDER BY diagnostic_seq",
    params = list(run$run_id)
  )
  testthat::expect_identical(nrow(diagnostics), info$scheduled_skip_count)
  testthat::expect_identical(unique(diagnostics$instrument_id), "")
  testthat::expect_identical(unique(diagnostics$stage), "decision")
  testthat::expect_identical(unique(diagnostics$outcome), "skipped")
  testthat::expect_identical(unique(diagnostics$reasons), "scheduled_skip")
  testthat::expect_identical(unique(diagnostics$detail_json), "{}")
  all_decisions <- DBI::dbGetQuery(
    opened$con,
    "SELECT ts_utc, reason_code FROM run_diagnostics WHERE run_id = ? AND stage = 'decision' ORDER BY diagnostic_seq",
    params = list(run$run_id)
  )
  skipped_key <- vapply(
    diagnostics$ts_utc,
    ledgr:::ledgr_normalize_ts_utc,
    character(1)
  )
  decision_key <- vapply(
    all_decisions$ts_utc,
    ledgr:::ledgr_normalize_ts_utc,
    character(1)
  )
  at_skips <- all_decisions[
    decision_key %in% skipped_key,
    ,
    drop = FALSE
  ]
  testthat::expect_identical(nrow(at_skips), info$scheduled_skip_count)
  testthat::expect_identical(unique(at_skips$reason_code), "scheduled_skip")
  reconciliation <- DBI::dbGetQuery(
    opened$con,
    "SELECT COUNT(*) AS n FROM run_diagnostics WHERE run_id = ? AND stage = 'reconciliation'",
    params = list(run$run_id)
  )
  testthat::expect_identical(as.integer(reconciliation$n[[1L]]), info$pulse_count)

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

  old_interrupt <- getOption("ledgr.interrupt")
  on.exit(options(ledgr.interrupt = old_interrupt), add = TRUE)
  options(ledgr.interrupt = TRUE)
  carried_partial <- ledgr_run(year_exp, run_id = "scheduled-zero-carried")
  close(carried_partial)
  options(ledgr.interrupt = FALSE)
  carried_done <- ledgr_run(year_exp, run_id = "scheduled-zero-carried")
  on.exit(close(carried_done), add = TRUE)
  carried_info <- ledgr_run_info(fixture$snapshot, carried_done$run_id)
  testthat::expect_identical(carried_info$status, "DONE")
  testthat::expect_identical(carried_info$decision_pulse_count, 0L)
  testthat::expect_identical(
    carried_info$scheduled_skip_count,
    opened_info$scheduled_skip_count
  )
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
    expected_counts <- sprintf(
      "Decision pulses: %d; scheduled skips: %d",
      info$decision_pulse_count,
      info$scheduled_skip_count
    )
    testthat::expect_true(expected_counts %in% text)
  }

  mutate_store <- function(sql, params = list()) {
    store <- ledgr:::ledgr_run_store_open(fixture$snapshot$db_path)
    on.exit(ledgr:::ledgr_run_store_close(store))
    DBI::dbExecute(store$con, sql, params = c(params, list(run$run_id)))
    invisible(NULL)
  }
  restore_provenance <- function() {
    mutate_store(
      "UPDATE run_provenance SET schedule_json = ?, schedule_hash = ? WHERE run_id = ?",
      list(provenance$schedule_json[[1L]], provenance$schedule_hash[[1L]])
    )
    mutate_store(
      "UPDATE run_telemetry SET decision_pulse_count = ?, scheduled_skip_count = ? WHERE run_id = ?",
      list(telemetry$decision_pulse_count[[1L]], telemetry$scheduled_skip_count[[1L]])
    )
  }
  expect_readers_refuse <- function() {
    testthat::expect_error(
      ledgr_run_info(fixture$snapshot, run$run_id),
      class = "ledgr_schedule_identity_mismatch"
    )
    testthat::expect_error(
      ledgr_run_open(fixture$snapshot, run$run_id),
      class = "ledgr_schedule_identity_mismatch"
    )
    testthat::expect_error(
      ledgr_run_strategy(fixture$snapshot, run$run_id),
      class = "ledgr_schedule_identity_mismatch"
    )
    testthat::expect_error(
      print(run),
      class = "ledgr_schedule_identity_mismatch"
    )
    testthat::expect_error(
      summary(run),
      class = "ledgr_schedule_identity_mismatch"
    )
  }

  mutate_store(
    "UPDATE run_provenance SET schedule_json = NULL WHERE run_id = ?"
  )
  expect_readers_refuse()
  restore_provenance()

  mutate_store(
    "UPDATE run_provenance SET schedule_hash = NULL WHERE run_id = ?"
  )
  expect_readers_refuse()
  restore_provenance()

  mutate_store(
    "UPDATE run_provenance SET schedule_json = '{' WHERE run_id = ?"
  )
  expect_readers_refuse()
  restore_provenance()

  forged <- unclass(ledgr_schedule_month_start())
  mutate_store(
    "UPDATE run_provenance SET schedule_json = ?, schedule_hash = ? WHERE run_id = ?",
    list(
      ledgr:::ledgr_strategy_schedule_json(forged),
      ledgr:::ledgr_strategy_schedule_hash(forged)
    )
  )
  expect_readers_refuse()
  restore_provenance()

  mutate_store(
    "UPDATE run_telemetry SET decision_pulse_count = NULL WHERE run_id = ?"
  )
  testthat::expect_error(
    ledgr_run_info(fixture$snapshot, run$run_id),
    class = "ledgr_schedule_identity_mismatch"
  )
  testthat::expect_error(
    ledgr_run_open(fixture$snapshot, run$run_id),
    class = "ledgr_schedule_identity_mismatch"
  )
  testthat::expect_error(
    print(run),
    class = "ledgr_schedule_identity_mismatch"
  )
  testthat::expect_error(
    summary(run),
    class = "ledgr_schedule_identity_mismatch"
  )
  restore_provenance()

  mutate_store(
    "UPDATE run_telemetry SET scheduled_skip_count = NULL WHERE run_id = ?"
  )
  testthat::expect_error(
    ledgr_run_info(fixture$snapshot, run$run_id),
    class = "ledgr_schedule_identity_mismatch"
  )
  restore_provenance()

  mutate_store(
    "UPDATE run_telemetry SET decision_pulse_count = -1 WHERE run_id = ?"
  )
  testthat::expect_error(
    ledgr_run_info(fixture$snapshot, run$run_id),
    class = "ledgr_schedule_identity_mismatch"
  )
  restore_provenance()

  mutate_store("UPDATE runs SET status = 'RUNNING' WHERE run_id = ?")
  finalized <- ledgr_run(fixture$exp, run_id = run$run_id)
  on.exit(close(finalized), add = TRUE)
  finalized_info <- ledgr_run_info(fixture$snapshot, run$run_id)
  testthat::expect_identical(
    finalized_info$decision_pulse_count,
    as.integer(telemetry$decision_pulse_count[[1L]])
  )
  testthat::expect_identical(
    finalized_info$scheduled_skip_count,
    as.integer(telemetry$scheduled_skip_count[[1L]])
  )

  mutate_store("UPDATE runs SET status = 'RUNNING' WHERE run_id = ?")
  mutate_store("DELETE FROM run_telemetry WHERE run_id = ?")
  unfinished_info <- ledgr_run_info(fixture$snapshot, run$run_id)
  testthat::expect_identical(unfinished_info$status, "RUNNING")
  testthat::expect_true(is.na(unfinished_info$decision_pulse_count))
  testthat::expect_true(is.na(unfinished_info$scheduled_skip_count))
  testthat::expect_identical(
    unclass(ledgr:::ledgr_schedule_validate(unfinished_info$strategy_schedule)),
    declaration
  )

  unresolved_strategy <- ledgr_strategy_schedule(
    function(ctx, params) ctx$hold(),
    ledgr_schedule_from_param("when")
  )
  unresolved <- ws42_history_fixture(
    strategy = unresolved_strategy,
    features = list()
  )
  on.exit(ledgr_snapshot_close(unresolved$snapshot), add = TRUE)
  testthat::expect_error(
    ledgr_run(
      unresolved$exp,
      params = list(when = "bogus"),
      run_id = "scheduled-failed-before-counts"
    ),
    class = "ledgr_schedule_param_unresolved"
  )
  failed_info <- ledgr_run_info(
    unresolved$snapshot,
    "scheduled-failed-before-counts"
  )
  testthat::expect_identical(failed_info$status, "FAILED")
  testthat::expect_match(failed_info$error_msg, "supported fixed schedule")
  testthat::expect_true(is.na(failed_info$decision_pulse_count))
  testthat::expect_true(is.na(failed_info$scheduled_skip_count))
  testthat::expect_identical(
    unclass(ledgr:::ledgr_schedule_validate(failed_info$strategy_schedule)),
    unclass(ledgr_schedule_from_param("when"))
  )

  plain <- ws42_history_fixture(
    strategy = function(ctx, params) ctx$hold(),
    features = list()
  )
  on.exit(ledgr_snapshot_close(plain$snapshot), add = TRUE)
  plain_run <- ledgr_run(plain$exp, run_id = "unscheduled-print-no-schedule-read")
  on.exit(close(plain_run), add = TRUE)
  schedule_reads <- 0L
  testthat::local_mocked_bindings(
    ledgr_run_schedule_evidence = function(...) {
      schedule_reads <<- schedule_reads + 1L
      stop("unscheduled print read schedule evidence")
    },
    .package = "ledgr"
  )
  invisible(capture.output(print(plain_run)))
  testthat::expect_identical(schedule_reads, 0L)
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
      if (isTRUE(getOption("ledgr.schedule.interrupt_on_decision", FALSE)) && n == 0L) {
        options(ledgr.interrupt = TRUE)
      }
      list(targets = ctx$hold(), state_update = list(n = n + 1L))
    },
    ledgr_schedule_week_start()
  )
  resumed <- ws42_history_fixture(
    strategy = state_strategy,
    features = list(),
    opening = opening,
    dividend = c(2L, 3L)
  )
  on.exit(ledgr_snapshot_close(resumed$snapshot), add = TRUE)
  reference <- ledgr_run(resumed$exp, run_id = "schedule-resume-reference")
  on.exit(close(reference), add = TRUE)
  old_interrupt <- getOption("ledgr.interrupt")
  old_schedule_interrupt <- getOption("ledgr.schedule.interrupt_on_decision")
  on.exit(options(
    ledgr.interrupt = old_interrupt,
    ledgr.schedule.interrupt_on_decision = old_schedule_interrupt
  ), add = TRUE)
  options(
    ledgr.interrupt = FALSE,
    ledgr.schedule.interrupt_on_decision = TRUE
  )
  partial <- ledgr_run(resumed$exp, run_id = "schedule-resume")
  close(partial)
  options(
    ledgr.interrupt = FALSE,
    ledgr.schedule.interrupt_on_decision = FALSE
  )
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
  fetch_events <- function(run_id) {
    DBI::dbGetQuery(
      opened$con,
      paste(
        "SELECT event_id, run_id, event_seq, ts_utc, event_type, instrument_id, side, qty, price, fee, meta_json",
        "FROM ledger_events WHERE run_id = ? ORDER BY event_seq"
      ),
      params = list(run_id)
    )
  }
  reference_events <- fetch_events(reference$run_id)
  completed_events <- fetch_events(completed$run_id)
  economic_columns <- setdiff(names(reference_events), c("event_id", "run_id"))
  testthat::expect_identical(
    reference_events[economic_columns],
    completed_events[economic_columns]
  )
  reference_replay <- ledgr:::ledgr_replay_accounting_events(
    ledgr:::ledgr_prepare_accounting_events(reference_events, "AAA"),
    initial_cash = 1000
  )
  completed_replay <- ledgr:::ledgr_replay_accounting_events(
    ledgr:::ledgr_prepare_accounting_events(completed_events, "AAA"),
    initial_cash = 1000
  )
  testthat::expect_identical(reference_replay$positions, completed_replay$positions)
  testthat::expect_identical(reference_replay$lot_state, completed_replay$lot_state)
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0508] orchestration formats preserve schedule identity", {
  inner <- function(ctx, params) {
    target <- ctx$flat()
    target["AAA"] <- params$qty
    target
  }
  strategy <- ledgr_strategy_schedule(
    inner,
    ledgr_schedule_from_param("when")
  )
  fixture <- ws42_history_fixture(
    strategy = strategy,
    features = list(),
    opening = ledgr_opening(
      cash = 1000,
      positions = c(AAA = 1),
      cost_basis = c(AAA = 11)
    )
  )
  on.exit(ledgr_snapshot_close(fixture$snapshot), add = TRUE)
  grid <- ledgr_grid_named(
    month = list(strategy = list(when = "month_start", qty = 2)),
    week = list(strategy = list(when = "week_start", qty = 2))
  )

  captured_tasks <- list()
  original_eval <- ledgr:::ledgr_sweep_eval_candidate_task
  testthat::local_mocked_bindings(
    ledgr_sweep_eval_candidate_task = function(task, stop_on_error = FALSE) {
      captured_tasks[[length(captured_tasks) + 1L]] <<- task
      original_eval(task, stop_on_error = stop_on_error)
    },
    .package = "ledgr"
  )
  sweeps <- lapply(1:3, function(workers) {
    ledgr_sweep(fixture$exp, grid, seed = 91L, workers = workers)
  })
  reference <- sweeps[[1L]]
  for (sweep in sweeps[-1L]) {
    testthat::expect_identical(sweep$status, reference$status)
    testthat::expect_identical(sweep$final_equity, reference$final_equity)
    testthat::expect_identical(sweep$provenance, reference$provenance)
  }
  testthat::expect_identical(
    names(reference),
    c(
      "candidate_id", "candidate_row", "status", "completion_json",
      "stop_reason", "affected_instrument_ids", "valuation_state",
      "frozen_instrument_sessions", "max_frozen_equity_weight",
      "frozen_at_end_value", "assumed_terminal_outcomes", "final_equity", "total_return",
      "annualized_return", "volatility", "sharpe_ratio", "max_drawdown",
      "n_trades", "win_rate", "avg_trade", "time_in_market",
      "execution_seed", "error_class", "error_msg", "params",
      "feature_params", "warnings", "feature_fingerprints", "risk_chain_hash",
      "provenance", "t_engine", "t_results", "t_fills_extract"
    )
  )
  provenance <- reference$provenance
  testthat::expect_identical(
    vapply(provenance, `[[`, character(1), "provenance_version"),
    rep("ledgr_provenance_v2", 2L)
  )
  testthat::expect_identical(
    provenance[[1L]]$strategy_schedule,
    provenance[[2L]]$strategy_schedule
  )
  testthat::expect_false(identical(
    provenance[[1L]]$resolved_schedule_hash,
    provenance[[2L]]$resolved_schedule_hash
  ))

  testthat::expect_length(captured_tasks, 2L)
  testthat::expect_true(all(vapply(captured_tasks, function(task) {
    inherits(task$exp$strategy, "ledgr_scheduled_strategy") &&
      identical(
        ledgr:::ledgr_strategy_schedule_hash(
          ledgr:::ledgr_strategy_schedule_declaration(task$exp$strategy)
        ),
        provenance[[1L]]$schedule_hash
      )
  }, logical(1))))
  nested_names <- function(x) {
    if (!is.list(x)) return(character())
    c(names(x), unlist(lapply(x, nested_names), use.names = FALSE))
  }
  transported_names <- unique(unlist(lapply(captured_tasks, nested_names), use.names = FALSE))
  testthat::expect_length(
    grep("decision|verdict|mask|due", transported_names, ignore.case = TRUE, value = TRUE),
    0L
  )
  worker_source <- paste(
    deparse(body(ledgr:::ledgr_sweep_candidate_execution)),
    collapse = "\n"
  )
  testthat::expect_equal(
    lengths(regmatches(worker_source, gregexpr("ledgr_compile_strategy_schedule", worker_source, fixed = TRUE))),
    1L
  )

  ledgr_sweep_save(reference, fixture$snapshot, sweep_id = "scheduled-sweep")
  reopened <- ledgr_sweep_open(fixture$snapshot, "scheduled-sweep")
  testthat::expect_identical(
    ledgr:::ledgr_strategy_schedule_hash(attr(reopened, "strategy_schedule")),
    ledgr:::ledgr_strategy_schedule_hash(attr(reference, "strategy_schedule"))
  )
  testthat::expect_identical(
    vapply(reopened$provenance, `[[`, character(1), "resolved_schedule_hash"),
    vapply(reference$provenance, `[[`, character(1), "resolved_schedule_hash")
  )
  in_memory <- ledgr_candidate(reference, "week")
  durable <- ledgr_candidate(reopened, "week")
  in_memory_key <- ledgr_candidate_reproduction_key(in_memory)
  durable_key <- ledgr_candidate_reproduction_key(durable)
  testthat::expect_identical(
    in_memory_key$strategy_schedule$schedule_hash,
    durable_key$strategy_schedule$schedule_hash
  )
  testthat::expect_identical(
    in_memory_key$strategy_schedule$resolved_schedule_hash,
    durable_key$strategy_schedule$resolved_schedule_hash
  )
  testthat::expect_identical(
    in_memory_key$reproduction_key_version,
    "ledgr_candidate_reproduction_key_v2"
  )
  testthat::expect_identical(
    in_memory_key$strategy_schedule$resolved_schedule$type_id,
    "week_start"
  )
  old_candidate <- in_memory
  old_candidate$provenance$provenance_version <- "ledgr_provenance_v1"
  testthat::expect_error(
    ledgr_candidate_reproduction_key(old_candidate),
    class = "ledgr_sweep_schema_incompatible"
  )

  unscheduled_exp <- fixture$exp
  unscheduled_exp$strategy <- inner
  unscheduled <- ledgr_sweep(
    unscheduled_exp,
    ledgr_grid_named(one = list(strategy = list(qty = 2))),
    seed = 91L
  )
  unscheduled_candidate <- ledgr_candidate(unscheduled, "one")
  testthat::expect_false("strategy_schedule" %in% names(unscheduled_candidate$provenance))
  testthat::expect_false(
    "strategy_schedule" %in% names(ledgr_candidate_reproduction_key(unscheduled_candidate))
  )
  testthat::expect_false(
    "strategy_schedule" %in% names(attr(unscheduled, "execution_assumptions"))
  )

  mixed_grid <- ledgr_grid_named(
    valid = list(strategy = list(when = "week_start", qty = 2)),
    invalid = list(strategy = list(when = "fortnight", qty = 3))
  )
  mixed <- testthat::expect_no_error(ledgr_sweep(
    fixture$exp,
    mixed_grid,
    seed = 91L,
    stop_on_error = FALSE
  ))
  testthat::expect_identical(mixed$status, c("DONE", "FAILED"))
  testthat::expect_match(
    mixed$error_class[[2L]],
    "ledgr_schedule_param_unresolved",
    fixed = TRUE
  )
  ledgr_sweep_save(mixed, fixture$snapshot, sweep_id = "scheduled-failed-sweep")
  mixed_reopened <- ledgr_sweep_open(fixture$snapshot, "scheduled-failed-sweep")
  testthat::expect_identical(mixed_reopened$status, mixed$status)
  testthat::expect_identical(mixed_reopened$error_class, mixed$error_class)

  failed_for_another_reason <- mixed
  failed_for_another_reason$error_class[[2L]] <- "ledgr_strategy_error"
  ledgr_sweep_save(
    failed_for_another_reason,
    fixture$snapshot,
    sweep_id = "scheduled-other-failure-sweep"
  )
  other_failure_reopened <- ledgr_sweep_open(
    fixture$snapshot,
    "scheduled-other-failure-sweep"
  )
  testthat::expect_identical(
    other_failure_reopened$error_class,
    failed_for_another_reason$error_class
  )
  testthat::expect_identical(
    other_failure_reopened$provenance[[2L]]$schedule_hash,
    failed_for_another_reason$provenance[[2L]]$schedule_hash
  )

  resolvable_authored_only <- mixed
  resolvable_authored_only$params[[2L]]$when <- "week_start"
  ledgr_sweep_save(
    resolvable_authored_only,
    fixture$snapshot,
    sweep_id = "scheduled-resolvable-authored-only-sweep"
  )
  testthat::expect_error(
    ledgr_sweep_open(fixture$snapshot, "scheduled-resolvable-authored-only-sweep"),
    class = "ledgr_schedule_identity_mismatch"
  )

  promoted_a <- testthat::expect_no_warning(
    ledgr_promote(fixture$exp, in_memory, "scheduled-promote-a")
  )
  promoted_b <- testthat::expect_no_warning(
    ledgr_promote(fixture$exp, durable, "scheduled-promote-b")
  )
  on.exit(close(promoted_a), add = TRUE)
  on.exit(close(promoted_b), add = TRUE)
  testthat::expect_identical(promoted_a$config$strategy_schedule, promoted_b$config$strategy_schedule)
  testthat::expect_identical(ledgr_run_fills(promoted_a), ledgr_run_fills(promoted_b))
  context <- ledgr_promotion_context(promoted_b)
  testthat::expect_identical(context$promotion_context_version, "ledgr_promotion_v3")
  testthat::expect_identical(context$source_sweep$schedule_hash, provenance[[1L]]$schedule_hash)

  week_exp <- fixture$exp
  week_exp$strategy <- ledgr_strategy_schedule(inner, ledgr_schedule_week_start())
  month_exp <- fixture$exp
  month_exp$strategy <- ledgr_strategy_schedule(inner, ledgr_schedule_month_start())
  fixed_grid <- ledgr_grid_named(one = list(strategy = list(qty = 2)))
  testthat::expect_warning(
    scheduled_into_plain <- ledgr_promote(
      unscheduled_exp,
      in_memory,
      "scheduled-into-plain"
    ),
    "schedule_hash",
    class = "ledgr_promote_identity_mismatch"
  )
  on.exit(close(scheduled_into_plain), add = TRUE)
  testthat::expect_warning(
    plain_into_scheduled <- ledgr_promote(
      week_exp,
      unscheduled_candidate,
      "plain-into-scheduled"
    ),
    "schedule_hash",
    class = "ledgr_promote_identity_mismatch"
  )
  on.exit(close(plain_into_scheduled), add = TRUE)
  testthat::expect_identical(
    ledgr_promotion_context(scheduled_into_plain)$identity_check$mismatched,
    "schedule_hash"
  )
  testthat::expect_identical(
    ledgr_promotion_context(plain_into_scheduled)$identity_check$mismatched,
    "schedule_hash"
  )

  folds <- ledgr:::ledgr_fold_list(
    list(ledgr_fold(
      fixture$days[[1L]], fixture$days[[4L]],
      fixture$days[[5L]], fixture$days[[8L]], fold_seq = 1L
    )),
    constructor = list(type_id = "explicit")
  )
  walk_week <- suppressWarnings(ledgr_walk_forward(
    week_exp, fixed_grid, folds,
    selection_rule = ledgr_rule_argmax("annualized_return"), seed = 91L
  ))
  walk_month <- suppressWarnings(ledgr_walk_forward(
    month_exp, fixed_grid, folds,
    selection_rule = ledgr_rule_argmax("annualized_return"), seed = 91L
  ))
  walk_mixed <- testthat::expect_no_error(suppressWarnings(ledgr_walk_forward(
    fixture$exp, mixed_grid, folds,
    selection_rule = ledgr_rule_argmax("annualized_return"), seed = 91L
  )))
  on.exit(lapply(walk_week$test_runs, close), add = TRUE)
  on.exit(lapply(walk_month$test_runs, close), add = TRUE)
  on.exit(lapply(walk_mixed$test_runs, close), add = TRUE)
  testthat::expect_setequal(
    unique(walk_mixed$scores$status[walk_mixed$scores$window == "train"]),
    c("DONE", "FAILED")
  )
  testthat::expect_false(identical(
    walk_week$scores$candidate_key,
    walk_month$scores$candidate_key
  ))
  for (window in c("train", "test")) {
    testthat::expect_false(identical(
      walk_week$scores$candidate_key[walk_week$scores$window == window],
      walk_month$scores$candidate_key[walk_month$scores$window == window]
    ))
  }
  wf_candidate <- ledgr_candidate(walk_week, fold_seq = 1L)
  month_wf_candidate <- ledgr_candidate(walk_month, fold_seq = 1L)
  testthat::expect_identical(
    wf_candidate$provenance$provenance_version,
    "ledgr_walk_forward_candidate_v2"
  )
  testthat::expect_identical(
    wf_candidate$provenance$resolved_schedule$type_id,
    "week_start"
  )
  testthat::expect_identical(
    wf_candidate$provenance$strategy_hash,
    month_wf_candidate$provenance$strategy_hash
  )
  testthat::expect_false(identical(
    wf_candidate$provenance$schedule_hash,
    month_wf_candidate$provenance$schedule_hash
  ))
  testthat::expect_false(identical(
    ledgr_candidate_reproduction_key(wf_candidate)$strategy_schedule$schedule_hash,
    ledgr_candidate_reproduction_key(month_wf_candidate)$strategy_schedule$schedule_hash
  ))
  testthat::expect_warning(
    fixed_schedule_mismatch <- ledgr_promote(
      month_exp,
      wf_candidate,
      "fixed-schedule-mismatch"
    ),
    "schedule_hash",
    class = "ledgr_promote_identity_mismatch"
  )
  on.exit(close(fixed_schedule_mismatch), add = TRUE)
  old_session_meta <- list(
    status = "DONE",
    walk_forward_schema_version = ledgr:::ledgr_walk_forward_schema_version,
    candidate_schema_version = "v1",
    identity_rule_version = ledgr:::ledgr_identity_rule_version
  )
  testthat::expect_error(
    ledgr:::ledgr_walk_forward_parse_session_meta(
      as.character(canonical_json(old_session_meta))
    ),
    "required v2",
    class = "ledgr_walk_forward_invalid_session"
  )

  con <- ledgr:::get_connection(fixture$snapshot)
  stored_parent <- DBI::dbGetQuery(
    con,
    "SELECT execution_assumptions_json FROM sweeps WHERE sweep_id = 'scheduled-sweep'"
  )
  parent_assumptions <- ledgr:::ledgr_json_read_nested(
    stored_parent$execution_assumptions_json[[1L]]
  )
  tampered_parent <- parent_assumptions
  tampered_parent$schedule_hash <- paste0("bad-", tampered_parent$schedule_hash)
  DBI::dbExecute(
    con,
    "UPDATE sweeps SET execution_assumptions_json = ? WHERE sweep_id = 'scheduled-sweep'",
    params = list(as.character(canonical_json(tampered_parent)))
  )
  testthat::expect_error(
    ledgr_sweep_open(fixture$snapshot, "scheduled-sweep"),
    class = "ledgr_schedule_identity_mismatch"
  )
  DBI::dbExecute(
    con,
    "UPDATE sweeps SET execution_assumptions_json = ? WHERE sweep_id = 'scheduled-sweep'",
    params = list(stored_parent$execution_assumptions_json[[1L]])
  )
  stored_candidate <- DBI::dbGetQuery(
    con,
    "SELECT provenance_json FROM sweep_candidates WHERE sweep_id = 'scheduled-sweep' AND candidate_id = 'week'"
  )
  candidate_provenance <- ledgr:::ledgr_json_read_nested(
    stored_candidate$provenance_json[[1L]]
  )
  tampered_candidate <- candidate_provenance
  tampered_candidate$resolved_schedule_hash <- paste0(
    "bad-",
    tampered_candidate$resolved_schedule_hash
  )
  DBI::dbExecute(
    con,
    "UPDATE sweep_candidates SET provenance_json = ? WHERE sweep_id = 'scheduled-sweep' AND candidate_id = 'week'",
    params = list(as.character(canonical_json(tampered_candidate)))
  )
  testthat::expect_error(
    ledgr_sweep_open(fixture$snapshot, "scheduled-sweep"),
    class = "ledgr_schedule_identity_mismatch"
  )
  DBI::dbExecute(
    con,
    "UPDATE sweep_candidates SET provenance_json = ? WHERE sweep_id = 'scheduled-sweep' AND candidate_id = 'week'",
    params = list(stored_candidate$provenance_json[[1L]])
  )
  DBI::dbExecute(
    con,
    "UPDATE sweeps SET sweep_schema_version = 5 WHERE sweep_id = 'scheduled-sweep'"
  )
  testthat::expect_error(
    ledgr_sweep_open(fixture$snapshot, "scheduled-sweep"),
    "Saved sweep schema version 5 is not current; required 6.",
    class = "ledgr_sweep_schema_incompatible",
    fixed = TRUE
  )
  DBI::dbExecute(
    con,
    "UPDATE sweeps SET sweep_schema_version = 6 WHERE sweep_id = 'scheduled-sweep'"
  )
  stored <- DBI::dbGetQuery(
    con,
    "SELECT candidate_id, provenance_json FROM sweep_candidates WHERE sweep_id = 'scheduled-sweep' ORDER BY candidate_row"
  )
  for (i in seq_len(nrow(stored))) {
    old_provenance <- ledgr:::ledgr_json_read_nested(stored$provenance_json[[i]])
    old_provenance$provenance_version <- "ledgr_provenance_v1"
    DBI::dbExecute(
      con,
      "UPDATE sweep_candidates SET provenance_json = ? WHERE sweep_id = 'scheduled-sweep' AND candidate_id = ?",
      params = list(
        as.character(canonical_json(old_provenance)),
        stored$candidate_id[[i]]
      )
    )
  }
  testthat::expect_error(
    ledgr_sweep_open(fixture$snapshot, "scheduled-sweep"),
    "Saved sweep candidate provenance version ledgr_provenance_v1 is not current; required ledgr_provenance_v2.",
    class = "ledgr_sweep_schema_incompatible",
    fixed = TRUE
  )
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0511] common calendar schedules use generic orchestration carriers", {
  inner <- function(ctx, params) {
    previous <- ctx$state_prev
    decision_n <- if (is.null(previous) || is.null(previous$decision_n)) {
      1L
    } else {
      previous$decision_n + 1L
    }
    target <- ctx$flat()
    target["AAA"] <- if (decision_n %% 2L == 1L) params$qty else 0
    list(targets = target, state_update = list(decision_n = decision_n))
  }
  weekday_strategy <- ledgr_strategy_schedule(
    inner,
    ledgr_schedule_weekday("monday")
  )
  fixture <- ws42_history_fixture(
    strategy = weekday_strategy,
    features = list(),
    opening = ledgr_opening(
      cash = 1000,
      positions = c(AAA = 1),
      cost_basis = c(AAA = 11)
    )
  )
  on.exit(ledgr_snapshot_close(fixture$snapshot), add = TRUE)
  grid <- ledgr_grid_named(one = list(strategy = list(qty = 2)))

  run <- ledgr_run(fixture$exp, params = list(qty = 2), seed = 3115L)
  on.exit(close(run), add = TRUE)
  sweep <- ledgr_sweep(
    fixture$exp,
    grid,
    seed = 3115L,
    workers = 2L,
    retain = ledgr_sweep_retention(returns = "completed")
  )
  candidate <- ledgr_candidate(sweep, "one")
  run_info <- ledgr_run_info(fixture$snapshot, run$run_id)
  testthat::expect_identical(run_info$strategy_schedule$type_id, "weekday")
  testthat::expect_identical(run_info$strategy_schedule$args$day, "monday")
  testthat::expect_identical(
    candidate$provenance$resolved_schedule,
    run_info$strategy_schedule
  )
  testthat::expect_identical(
    candidate$provenance$resolved_schedule_hash,
    run_info$schedule_hash
  )
  run_equity <- ledgr_results(run, "equity")
  sweep_equity <- ledgr_sweep_returns(sweep)
  testthat::expect_identical(sweep_equity$ts_utc, run_equity$ts_utc)
  testthat::expect_identical(sweep_equity$equity, run_equity$equity)
  testthat::expect_equal(
    sweep$final_equity[[1L]],
    run_equity$equity[[nrow(run_equity)]]
  )
  testthat::expect_identical(run_info$decision_pulse_count, 2L)
  testthat::expect_identical(run_info$scheduled_skip_count, 6L)

  recovered <- ledgr_run_strategy(fixture$snapshot, run$run_id, trust = TRUE)
  testthat::expect_identical(
    ledgr:::ledgr_strategy_schedule_declaration(recovered$strategy_function),
    unclass(ledgr_schedule_weekday("monday"))
  )

  ledgr_sweep_save(sweep, fixture$snapshot, sweep_id = "calendar-sweep")
  reopened <- ledgr_sweep_open(fixture$snapshot, "calendar-sweep")
  reopened_candidate <- ledgr_candidate(reopened, "one")
  testthat::expect_identical(
    unclass(ledgr:::ledgr_schedule_validate(
      reopened_candidate$provenance$strategy_schedule
    )),
    unclass(ledgr:::ledgr_schedule_validate(
      candidate$provenance$strategy_schedule
    ))
  )
  reopened_key <- ledgr_candidate_reproduction_key(reopened_candidate)
  in_memory_key <- ledgr_candidate_reproduction_key(candidate)
  testthat::expect_identical(
    reopened_key$strategy_schedule$schedule_hash,
    in_memory_key$strategy_schedule$schedule_hash
  )
  testthat::expect_identical(
    reopened_key$strategy_schedule$resolved_schedule_hash,
    in_memory_key$strategy_schedule$resolved_schedule_hash
  )
  promoted <- testthat::expect_no_warning(ledgr_promote(
    fixture$exp,
    reopened_candidate,
    "calendar-promoted"
  ))
  on.exit(close(promoted), add = TRUE)
  testthat::expect_identical(
    ledgr_run_info(fixture$snapshot, promoted$run_id)$strategy_schedule,
    run_info$strategy_schedule
  )

  month_day_exp <- fixture$exp
  month_day_exp$strategy <- ledgr_strategy_schedule(
    inner,
    ledgr_schedule_month_day(4L)
  )
  folds <- ledgr:::ledgr_fold_list(
    list(ledgr_fold(
      fixture$days[[1L]], fixture$days[[4L]],
      fixture$days[[5L]], fixture$days[[8L]], fold_seq = 1L
    )),
    constructor = list(type_id = "explicit")
  )
  walk <- suppressWarnings(ledgr_walk_forward(
    month_day_exp,
    grid,
    folds,
    selection_rule = ledgr_rule_argmax("annualized_return"),
    seed = 3115L
  ))
  on.exit(lapply(walk$test_runs, close), add = TRUE)
  walk_candidate <- ledgr_candidate(walk, fold_seq = 1L)
  testthat::expect_identical(
    walk_candidate$provenance$resolved_schedule$type_id,
    "month_day"
  )
  testthat::expect_identical(
    walk_candidate$provenance$resolved_schedule$args$day,
    4L
  )
  testthat::expect_identical(
    walk_candidate$provenance$resolved_schedule_hash,
    ledgr:::ledgr_strategy_schedule_hash(
      walk_candidate$provenance$resolved_schedule
    )
  )
  testthat::expect_identical(
    walk_candidate$provenance$schedule_hash,
    ledgr:::ledgr_strategy_schedule_hash(ledgr_schedule_month_day(4L))
  )
  testthat::expect_identical(
    ledgr_candidate_reproduction_key(walk_candidate)$strategy_schedule$resolved_schedule$args$day,
    4L
  )
})
