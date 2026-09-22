availability_store_contents <- function(path, run_id) {
  opened <- ledgr:::ledgr_run_store_open(path)
  on.exit(ledgr:::ledgr_run_store_close(opened), add = TRUE)
  tables <- c(
    "runs", "ledger_events", "strategy_state", "features", "equity_curve",
    "run_completion", "run_diagnostics"
  )
  stats::setNames(lapply(tables, function(table) {
    DBI::dbGetQuery(
      opened$con,
      sprintf("SELECT * FROM %s WHERE run_id = ? ORDER BY ALL", table),
      params = list(run_id)
    )
  }), tables)
}

availability_incomplete_experiment <- function(path, calls) {
  snapshot <- availability_runtime_fixture(days = 4L, bar_days = c(1L, 2L, 4L))
  source <- snapshot$db_path
  ledgr_snapshot_close(snapshot)
  file.copy(source, path, overwrite = TRUE)
  copied <- ledgr_snapshot_open(path, snapshot$snapshot_id)
  strategy <- function(ctx, params) {
    calls$n <- calls$n + 1L
    target <- ctx$hold()
    target[["AAA"]] <- 1
    target
  }
  list(
    snapshot = copied,
    experiment = ledgr_experiment(
      copied,
      strategy,
      valuation_policy = ledgr_valuation_stale(0),
      cost_model = ledgr_cost_zero()
    )
  )
}

# ledgr-test-profile: heavy_protocol
testthat::test_that("achieved incomplete runs reopen and rerun without mutation", {
  path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(path), add = TRUE)
  calls <- new.env(parent = emptyenv())
  calls$n <- 0L
  fixture <- availability_incomplete_experiment(path, calls)
  on.exit(ledgr_snapshot_close(fixture$snapshot), add = TRUE)

  first <- ledgr_run(fixture$experiment, run_id = "terminal-incomplete")
  on.exit(close(first), add = TRUE)
  first_info <- ledgr_run_info(fixture$snapshot, first$run_id)
  testthat::expect_identical(first_info$status, "INCOMPLETE")
  testthat::expect_true(first_info$completion_evidence_available)
  testthat::expect_identical(first_info$completion_status, "INCOMPLETE")
  testthat::expect_s3_class(first_info$requested_start_utc, "POSIXct")
  testthat::expect_s3_class(first_info$requested_end_utc, "POSIXct")
  testthat::expect_s3_class(first_info$achieved_start_utc, "POSIXct")
  testthat::expect_s3_class(first_info$achieved_end_utc, "POSIXct")
  testthat::expect_identical(
    first_info$stop_reason,
    "valuation_horizon_exhausted"
  )
  testthat::expect_identical(
    first_info$last_fully_valued_ts_utc,
    first_info$achieved_end_utc
  )
  testthat::expect_s3_class(first_info$last_executed_ts_utc, "POSIXct")
  testthat::expect_false(first_info$complete_performance)
  testthat::expect_identical(first_info$affected_instrument_ids, "AAA")
  calls_before_inventory <- calls$n
  store_before_inventory <- availability_store_contents(path, first$run_id)
  inventory <- ledgr_run_list(fixture$snapshot)
  inventory_row <- inventory[inventory$run_id == first$run_id, , drop = FALSE]
  testthat::expect_identical(nrow(inventory_row), 1L)
  testthat::expect_true(inventory_row$completion_evidence_available[[1L]])
  testthat::expect_identical(inventory_row$completion_status[[1L]], "INCOMPLETE")
  for (field in c(
    "requested_start_utc", "requested_end_utc", "achieved_start_utc",
    "achieved_end_utc", "stop_reason", "last_fully_valued_ts_utc",
    "last_executed_ts_utc", "complete_performance"
  )) {
    testthat::expect_identical(inventory_row[[field]][[1L]], first_info[[field]])
  }
  testthat::expect_identical(inventory_row$affected_instrument_ids[[1L]], "AAA")
  testthat::expect_identical(calls$n, calls_before_inventory)
  testthat::expect_identical(
    availability_store_contents(path, first$run_id),
    store_before_inventory
  )
  inventory_output <- utils::capture.output(print(inventory_row))
  testthat::expect_true(any(grepl("INCOMPLETE", inventory_output, fixed = TRUE)))
  testthat::expect_true(any(grepl("prefix only", inventory_output, fixed = TRUE)))
  testthat::expect_error(
    ledgr_run_compare(fixture$snapshot, run_ids = first$run_id),
    class = "ledgr_run_not_complete"
  )
  default_comparison <- ledgr_run_compare(fixture$snapshot)
  testthat::expect_false(first$run_id %in% default_comparison$run_id)
  testthat::expect_true(first$run_id %in% inventory$run_id)
  summary_output <- utils::capture.output(summary(first))
  for (label in c(
    "Completion Evidence", "Status:           INCOMPLETE",
    "Requested Window", "Achieved Window",
    "Stop Reason", "Last Fully Valued", "Last Executed",
    "Performance:       incomplete", "Affected IDs:      AAA"
  )) {
    testthat::expect_true(any(grepl(label, summary_output, fixed = TRUE)))
  }
  expected_prefix_heading <- sprintf(
    "Achieved-Prefix Metrics (%s to %s):",
    ledgr:::ledgr_completion_time_label(first_info$achieved_start_utc),
    ledgr:::ledgr_completion_time_label(first_info$achieved_end_utc)
  )
  testthat::expect_true(any(grepl(
    expected_prefix_heading,
    summary_output,
    fixed = TRUE
  )))
  for (line in c(
    "Total Return (prefix):",
    "Max Drawdown (prefix):",
    "Annualized Return:        withheld (achieved window is shorter than requested)",
    "Volatility (annual): withheld (achieved window is shorter than requested)",
    "Sharpe Ratio:        withheld (achieved window is shorter than requested)"
  )) {
    testthat::expect_true(any(grepl(line, summary_output, fixed = TRUE)))
  }
  testthat::expect_false(any(grepl("Annualized Return:   -", summary_output, fixed = TRUE)))
  testthat::expect_false(any(grepl("Volatility (annual): 9", summary_output, fixed = TRUE)))
  info_output <- utils::capture.output(print(first_info))
  testthat::expect_true(any(grepl("Completion Evidence", info_output, fixed = TRUE)))
  testthat::expect_false(any(grepl("Diagnostics: NA", info_output, fixed = TRUE)))
  completion_line <- grep("Completion Evidence:", info_output, fixed = TRUE)[[1L]]
  snapshot_line <- grep("Snapshot:", info_output, fixed = TRUE)[[1L]]
  testthat::expect_lt(completion_line, snapshot_line)
  for (label in c(
    "Run ID:", "Label:", "Status:", "Archived:", "Tags:", "Snapshot:",
    "Snapshot Hash:", "Feature Set Hash:", "Risk Chain Hash:",
    "Config Hash:", "Strategy Hash:", "Params Hash:", "Reproducibility:",
    "Execution Mode:", "Fill Timing:", "Timing Version:", "Elapsed Sec:",
    "Persist Features:", "Cache Hits:", "Cache Misses:"
  )) {
    testthat::expect_true(any(grepl(label, info_output, fixed = TRUE)))
  }
  calls_after_first <- calls$n
  before <- availability_store_contents(path, first$run_id)

  close(first)
  second <- ledgr_run(fixture$experiment, run_id = "terminal-incomplete")
  on.exit(close(second), add = TRUE)
  after <- availability_store_contents(path, second$run_id)
  testthat::expect_identical(calls$n, calls_after_first)
  testthat::expect_identical(after, before)

  close(second)
  reopened <- ledgr_run_open(fixture$snapshot, "terminal-incomplete")
  on.exit(close(reopened), add = TRUE)
  testthat::expect_s3_class(reopened, "ledgr_backtest")
  testthat::expect_identical(
    ledgr_results(reopened, "equity"),
    ledgr_results(first, "equity")
  )
  reopened_info <- ledgr_run_info(fixture$snapshot, reopened$run_id)
  completion_fields <- c(
    "completion_evidence_available", "completion_status",
    "requested_start_utc", "requested_end_utc",
    "achieved_start_utc", "achieved_end_utc", "stop_reason",
    "last_fully_valued_ts_utc", "last_executed_ts_utc",
    "complete_performance", "affected_instrument_ids"
  )
  testthat::expect_identical(
    reopened_info[completion_fields],
    first_info[completion_fields]
  )
  reopened_inventory <- ledgr_run_list(fixture$snapshot)
  reopened_row <- reopened_inventory[reopened_inventory$run_id == first$run_id, , drop = FALSE]
  testthat::expect_identical(reopened_row$affected_instrument_ids[[1L]], "AAA")
  testthat::expect_identical(
    reopened_row$achieved_end_utc[[1L]],
    first_info$achieved_end_utc
  )
  testthat::expect_identical(calls$n, calls_after_first)
})

# ledgr-test-profile: heavy_protocol
testthat::test_that("completion affected IDs come only from stopped diagnostics", {
  dates <- as.Date("2020-01-01") + 0:2
  sessions <- ledgr_facts_sessions(
    data.frame(
      session_date = dates,
      status = "open",
      session_open = "09:30:00",
      session_close = "16:00:00",
      knowledge_time = as.POSIXct(dates, tz = "UTC") - 1,
      stringsAsFactors = FALSE
    ),
    venue_id = "XNYS"
  )
  bars <- expand.grid(
    date_idx = seq_along(dates),
    instrument_id = c("AAA", "BBB"),
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  bars <- bars[!(bars$instrument_id == "AAA" & bars$date_idx == 3L), ]
  close <- 100 + bars$date_idx + ifelse(bars$instrument_id == "BBB", 20, 0)
  bars <- data.frame(
    ts_utc = as.POSIXct(paste(dates[bars$date_idx], "16:00:00"), tz = "UTC"),
    instrument_id = bars$instrument_id,
    open = close,
    high = close + 1,
    low = close - 1,
    close = close,
    volume = 1000,
    stringsAsFactors = FALSE
  )
  snapshot <- ledgr_snapshot_from_df(
    bars,
    instruments_df = data.frame(instrument_id = c("AAA", "BBB")),
    facts = ledgr_facts(sessions)
  )
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  strategy <- function(ctx, params) {
    target <- ctx$hold()
    target[c("AAA", "BBB")] <- 1
    target
  }
  experiment <- ledgr_experiment(
    snapshot,
    strategy,
    universe = c("AAA", "BBB"),
    valuation_policy = ledgr_valuation_stale(0),
    cost_model = ledgr_cost_zero()
  )
  bt <- ledgr_run(experiment, run_id = "affected-id-source")
  on.exit(close(bt), add = TRUE)

  diagnostics <- ledgr_results(bt, "diagnostics")
  testthat::expect_true(any(
    diagnostics$outcome == "filled" & diagnostics$instrument_id == "BBB"
  ))
  testthat::expect_identical(
    unique(diagnostics$instrument_id[diagnostics$outcome == "stopped"]),
    "AAA"
  )
  testthat::expect_identical(
    ledgr_run_info(snapshot, bt$run_id)$affected_instrument_ids,
    "AAA"
  )
  inventory <- ledgr_run_list(snapshot)
  testthat::expect_identical(
    inventory$affected_instrument_ids[[match(bt$run_id, inventory$run_id)]],
    "AAA"
  )
})

# ledgr-test-profile: heavy_protocol
testthat::test_that("terminal completion recovers projections without strategy replay", {
  path <- tempfile(fileext = ".duckdb")
  clean_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(c(path, clean_path)), add = TRUE)
  calls <- new.env(parent = emptyenv())
  calls$n <- 0L
  fixture <- availability_incomplete_experiment(path, calls)
  on.exit(ledgr_snapshot_close(fixture$snapshot), add = TRUE)
  clean_calls <- new.env(parent = emptyenv())
  clean_calls$n <- 0L
  clean_fixture <- availability_incomplete_experiment(clean_path, clean_calls)
  on.exit(ledgr_snapshot_close(clean_fixture$snapshot), add = TRUE)

  clean <- ledgr_run(clean_fixture$experiment, run_id = "terminal-recovery")
  on.exit(close(clean), add = TRUE)
  clean_rows <- availability_store_contents(clean_path, clean$run_id)

  seam <- new.env(parent = emptyenv())
  seam$fired <- FALSE
  original_transaction <- DBI::dbWithTransaction
  local({
    testthat::local_mocked_bindings(
      dbWithTransaction = function(conn, code, ...) {
        expression <- paste(deparse(substitute(code)), collapse = "\n")
        if (!seam$fired && grepl("DELETE FROM equity_curve", expression, fixed = TRUE)) {
          seam$fired <- TRUE
          stop("injected incomplete finalization failure", call. = FALSE)
        }
        original_transaction(conn, code, ...)
      },
      .package = "DBI"
    )
    testthat::expect_error(
      ledgr_run(fixture$experiment, run_id = "terminal-recovery"),
      "injected incomplete finalization failure",
      fixed = TRUE
    )
  })
  testthat::expect_true(seam$fired)
  failed <- availability_store_contents(path, "terminal-recovery")
  testthat::expect_identical(failed$runs$status, "FAILED")
  testthat::expect_identical(nrow(failed$run_completion), 1L)
  testthat::expect_identical(nrow(failed$equity_curve), 0L)
  failed_inventory <- ledgr_run_list(fixture$snapshot)
  failed_row <- failed_inventory[failed_inventory$run_id == "terminal-recovery", , drop = FALSE]
  failed_info <- ledgr_run_info(fixture$snapshot, "terminal-recovery")
  testthat::expect_identical(failed_row$status[[1L]], "FAILED")
  testthat::expect_true(failed_row$completion_evidence_available[[1L]])
  testthat::expect_identical(failed_row$completion_status[[1L]], "INCOMPLETE")
  testthat::expect_identical(
    failed_row$achieved_end_utc[[1L]],
    failed_info$achieved_end_utc
  )
  testthat::expect_identical(
    failed_row$affected_instrument_ids[[1L]],
    failed_info$affected_instrument_ids
  )
  calls_after_failure <- calls$n

  recovered <- ledgr_run(fixture$experiment, run_id = "terminal-recovery")
  on.exit(close(recovered), add = TRUE)
  recovered_rows <- availability_store_contents(path, recovered$run_id)
  testthat::expect_identical(calls$n, calls_after_failure)
  testthat::expect_identical(recovered_rows$runs$status, "INCOMPLETE")
  testthat::expect_true(is.na(recovered_rows$runs$error_msg))
  for (table in c("ledger_events", "strategy_state", "equity_curve", "run_completion", "run_diagnostics")) {
    testthat::expect_identical(recovered_rows[[table]], clean_rows[[table]])
  }
})

# ledgr-test-profile: review
testthat::test_that("complete availability runs recover finalization without strategy replay", {
  snapshot <- availability_runtime_fixture()
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  calls <- new.env(parent = emptyenv())
  calls$n <- 0L
  exp <- ledgr_experiment(
    snapshot,
    function(ctx, params) {
      calls$n <- calls$n + 1L
      ctx$hold()
    },
    valuation_policy = ledgr_valuation_stale(1),
    cost_model = ledgr_cost_zero()
  )
  seam <- new.env(parent = emptyenv())
  seam$fired <- FALSE
  original_transaction <- DBI::dbWithTransaction
  local({
    testthat::local_mocked_bindings(
      dbWithTransaction = function(conn, code, ...) {
        expression <- paste(deparse(substitute(code)), collapse = "\n")
        if (!seam$fired && grepl("DELETE FROM equity_curve", expression, fixed = TRUE)) {
          seam$fired <- TRUE
          stop("injected complete finalization failure", call. = FALSE)
        }
        original_transaction(conn, code, ...)
      },
      .package = "DBI"
    )
    testthat::expect_error(
      ledgr_run(exp, run_id = "complete-terminal-recovery"),
      "injected complete finalization failure",
      fixed = TRUE
    )
  })
  failed <- availability_store_contents(snapshot$db_path, "complete-terminal-recovery")
  testthat::expect_true(seam$fired)
  testthat::expect_identical(failed$runs$status, "FAILED")
  testthat::expect_identical(failed$run_completion$intended_terminal_status, "DONE")
  failed_inventory <- ledgr_run_list(snapshot)
  failed_row <- failed_inventory[
    failed_inventory$run_id == "complete-terminal-recovery", , drop = FALSE
  ]
  testthat::expect_true(failed_row$completion_evidence_available[[1L]])
  testthat::expect_identical(failed_row$completion_status[[1L]], "DONE")
  testthat::expect_identical(failed_row$affected_instrument_ids[[1L]], character())
  calls_after_failure <- calls$n

  recovered <- ledgr_run(exp, run_id = "complete-terminal-recovery")
  on.exit(close(recovered), add = TRUE)
  after <- availability_store_contents(snapshot$db_path, recovered$run_id)
  testthat::expect_identical(calls$n, calls_after_failure)
  testthat::expect_identical(after$runs$status, "DONE")
  testthat::expect_identical(after$ledger_events, failed$ledger_events)
  testthat::expect_true(nrow(after$equity_curve) > 0L)
})

# ledgr-test-profile: review
testthat::test_that("malformed terminal completion evidence fails closed", {
  path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(path), add = TRUE)
  calls <- new.env(parent = emptyenv())
  calls$n <- 0L
  fixture <- availability_incomplete_experiment(path, calls)
  on.exit(ledgr_snapshot_close(fixture$snapshot), add = TRUE)
  bt <- ledgr_run(fixture$experiment, run_id = "terminal-tamper")
  close(bt)

  opened <- ledgr:::ledgr_run_store_open(path)
  DBI::dbExecute(
    opened$con,
    "UPDATE run_completion SET achieved_end_utc = intended_end_utc WHERE run_id = ?",
    params = list("terminal-tamper")
  )
  ledgr:::ledgr_run_store_close(opened)
  testthat::expect_error(
    ledgr_run_open(fixture$snapshot, "terminal-tamper"),
    class = "ledgr_run_terminal_evidence_invalid"
  )
})

testthat::test_that("terminal completion validation rejects invalid incomplete bounds", {
  pulses <- as.POSIXct(
    c("2020-01-01 16:00:00", "2020-01-02 16:00:00", "2020-01-03 16:00:00"),
    tz = "UTC"
  )
  calendar <- list(pulses_posix = pulses)
  completion <- data.frame(
    run_id = "terminal-bounds",
    intended_start_utc = pulses[[1L]],
    intended_end_utc = pulses[[3L]],
    achieved_start_utc = pulses[[1L]],
    achieved_end_utc = pulses[[2L]],
    intended_terminal_status = "INCOMPLETE",
    stop_reason = "valuation_horizon_exhausted",
    last_fully_valued_ts_utc = pulses[[2L]],
    last_executed_ts_utc = pulses[[1L]],
    complete_performance = FALSE,
    stringsAsFactors = FALSE
  )
  testthat::expect_silent(ledgr:::ledgr_run_completion_validate(
    completion,
    "terminal-bounds",
    calendar
  ))

  complete <- completion
  complete$complete_performance <- TRUE
  testthat::expect_error(
    ledgr:::ledgr_run_completion_validate(complete, "terminal-bounds", calendar),
    class = "ledgr_run_terminal_evidence_invalid"
  )

  off_calendar <- completion
  off_calendar$intended_end_utc <- pulses[[3L]] + 3600
  testthat::expect_error(
    ledgr:::ledgr_run_completion_validate(off_calendar, "terminal-bounds", calendar),
    class = "ledgr_run_terminal_evidence_invalid"
  )

  missing_reason <- completion
  missing_reason$stop_reason <- NA_character_
  testthat::expect_error(
    ledgr:::ledgr_run_completion_validate(missing_reason, "terminal-bounds", calendar),
    class = "ledgr_run_terminal_evidence_invalid"
  )
})

# ledgr-test-profile: review
testthat::test_that("achieved incomplete shortcuts require their finalized prefix", {
  path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(path), add = TRUE)
  calls <- new.env(parent = emptyenv())
  calls$n <- 0L
  fixture <- availability_incomplete_experiment(path, calls)
  on.exit(ledgr_snapshot_close(fixture$snapshot), add = TRUE)
  bt <- ledgr_run(fixture$experiment, run_id = "terminal-prefix-tamper")
  close(bt)
  calls_after_run <- calls$n

  opened <- ledgr:::ledgr_run_store_open(path)
  DBI::dbExecute(
    opened$con,
    paste(
      "DELETE FROM equity_curve WHERE run_id = ? AND ts_utc =",
      "(SELECT MIN(ts_utc) FROM equity_curve WHERE run_id = ?)"
    ),
    params = list("terminal-prefix-tamper", "terminal-prefix-tamper")
  )
  ledgr:::ledgr_run_store_close(opened)

  testthat::expect_error(
    ledgr_run(fixture$experiment, run_id = "terminal-prefix-tamper"),
    class = "ledgr_run_terminal_evidence_invalid"
  )
  testthat::expect_error(
    ledgr_run_open(fixture$snapshot, "terminal-prefix-tamper"),
    class = "ledgr_run_terminal_evidence_invalid"
  )
  testthat::expect_identical(calls$n, calls_after_run)
})

# ledgr-test-profile: review
testthat::test_that("availability completion propagates through sweep persistence", {
  snapshot <- availability_runtime_fixture(days = 4L, bar_days = c(1L, 2L, 4L))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  strategy <- function(ctx, params) {
    target <- ctx$hold()
    target[["AAA"]] <- params$qty
    target
  }
  exp <- ledgr_experiment(
    snapshot,
    strategy,
    valuation_policy = ledgr_valuation_stale(0),
    cost_model = ledgr_cost_zero()
  )
  grid <- ledgr_param_grid(one = list(qty = 1))
  sweep <- ledgr_sweep(
    exp,
    grid,
    retain = ledgr_sweep_retention(returns = "completed")
  )

  testthat::expect_identical(sweep$status, "INCOMPLETE")
  testthat::expect_match(sweep$completion_json, "valuation_horizon_exhausted")
  testthat::expect_error(
    ledgr_candidate(sweep, 1L, allow_failed = TRUE),
    class = "ledgr_incomplete_sweep_candidate"
  )
  saved_id <- ledgr_sweep_save(sweep, snapshot, sweep_id = "incomplete-sweep")
  reopened <- ledgr_sweep_open(snapshot, saved_id)
  testthat::expect_identical(reopened$status, sweep$status)
  testthat::expect_identical(reopened$completion_json, sweep$completion_json)
  testthat::expect_gt(nrow(ledgr_sweep_returns(reopened, candidates = "one")), 0L)
  testthat::expect_error(
    ledgr_sweep_returns_panel(reopened),
    class = "ledgr_sweep_returns_incomplete_panel"
  )
  testthat::expect_error(
    ledgr_sweep_returns_panel(reopened, candidates = "one"),
    class = "ledgr_sweep_returns_candidate_not_completed"
  )
})

# ledgr-test-profile: review
testthat::test_that("parallel availability sweeps return the same compact terminal evidence", {
  testthat::skip_on_covr()
  testthat::skip_if_not_installed("mirai")
  snapshot <- availability_runtime_fixture(days = 4L, bar_days = c(1L, 2L, 4L))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  exp <- ledgr_experiment(
    snapshot,
    function(ctx, params) {
      target <- ctx$hold()
      target[["AAA"]] <- params$qty
      target
    },
    valuation_policy = ledgr_valuation_stale(0),
    cost_model = ledgr_cost_zero()
  )
  grid <- ledgr_param_grid(one = list(qty = 1), two = list(qty = 2))
  sequential <- ledgr_sweep(exp, grid, seed = 31L)
  parallel <- ledgr_sweep(exp, grid, seed = 31L, workers = 2L)
  direct <- ledgr_run(exp, params = list(qty = 1), run_id = "direct-parity")
  on.exit(close(direct), add = TRUE)
  direct_terminal <- ledgr:::ledgr_backtest_terminal_evidence(direct)

  testthat::expect_identical(parallel$status, sequential$status)
  testthat::expect_identical(parallel$completion_json, sequential$completion_json)
  testthat::expect_identical(parallel$candidate_id, sequential$candidate_id)
  testthat::expect_true(all(parallel$status == "INCOMPLETE"))
  testthat::expect_identical(sequential$completion_json[[1L]], direct_terminal$completion_json)
})

# ledgr-test-profile: review
testthat::test_that("direct and sweep paths both apply the opening-time status cutoff", {
  halt <- ledgr_facts_trading_status(data.frame(
    instrument_id = c("AAA", "AAA"),
    effective_from = as.POSIXct(
      c("2020-01-01 00:00:00", "2020-01-02 12:00:00"),
      tz = "UTC"
    ),
    effective_to = as.POSIXct(c(NA_character_, "2020-01-02 16:00:00"), tz = "UTC"),
    knowledge_time = as.POSIXct(
      c("2019-12-31 00:00:00", "2020-01-01 20:00:00"),
      tz = "UTC"
    ),
    status = c("active", "halted"),
    source = c("baseline", "exchange"),
    precedence = c(1L, 2L),
    stringsAsFactors = FALSE
  ))
  snapshot <- availability_runtime_fixture(
    days = 3L,
    status = halt,
    session_open = "14:30:00",
    session_close = "21:00:00"
  )
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  strategy <- function(ctx, params) {
    if (identical(ctx$ts_utc, "2020-01-01T21:00:00Z")) {
      c(AAA = params$qty)
    } else {
      ctx$flat()
    }
  }
  exp <- ledgr_experiment(
    snapshot,
    strategy,
    valuation_policy = ledgr_valuation_stale(1),
    cost_model = ledgr_cost_zero()
  )

  direct <- ledgr_run(exp, params = list(qty = 1), run_id = "opening-cutoff-direct")
  on.exit(close(direct), add = TRUE)
  sweep <- ledgr_sweep(exp, ledgr_param_grid(one = list(qty = 1)), seed = 99L)

  testthat::expect_equal(nrow(ledgr_results(direct, "fills")), 0L)
  testthat::expect_identical(sweep$status, "DONE")
  testthat::expect_identical(sweep$n_trades, 0L)
  testthat::expect_equal(
    sweep$final_equity,
    utils::tail(ledgr_results(direct, "equity")$equity, 1L)
  )
})

# ledgr-test-profile: review
testthat::test_that("availability result views and explanations are durable read-only evidence", {
  snapshot <- availability_runtime_fixture()
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  calls <- new.env(parent = emptyenv())
  calls$n <- 0L
  strategy <- function(ctx, params) {
    calls$n <- calls$n + 1L
    target <- ctx$hold()
    target[["AAA"]] <- 1
    target
  }
  exp <- ledgr_experiment(
    snapshot,
    strategy,
    valuation_policy = ledgr_valuation_stale(1),
    cost_model = ledgr_cost_zero()
  )
  bt <- ledgr_run(exp, run_id = "availability-explain")
  on.exit(close(bt), add = TRUE)
  calls_after_run <- calls$n
  before <- availability_store_contents(snapshot$db_path, bt$run_id)

  diagnostics <- tibble::as_tibble(bt, what = "diagnostics")
  availability <- tibble::as_tibble(bt, what = "availability")
  first_availability <- availability[
    availability$instrument_id == "AAA" &
      availability$ts_utc == min(availability$ts_utc),
    ,
    drop = FALSE
  ]
  last_availability <- availability[
    availability$instrument_id == "AAA" &
      availability$ts_utc == max(availability$ts_utc),
    ,
    drop = FALSE
  ]
  testthat::expect_identical(first_availability$member, TRUE)
  testthat::expect_identical(first_availability$held, FALSE)
  testthat::expect_identical(first_availability$priced, TRUE)
  testthat::expect_identical(first_availability$mark_source, "current_close")
  testthat::expect_identical(first_availability$mark_age, 0L)
  testthat::expect_identical(last_availability$member, TRUE)
  testthat::expect_identical(last_availability$held, TRUE)
  decision <- diagnostics[
    diagnostics$stage == "decision" & diagnostics$instrument_id == "AAA",
    ,
    drop = FALSE
  ][1L, ]
  explanation <- ledgr_run_explain(bt, "AAA", decision$ts_utc)

  local({
    altered <- diagnostics
    altered$position_before <- altered$position_before + 1000
    altered$price <- altered$price + 1000
    altered$mark_source <- "trace_only_value"
    altered$mark_age <- 1000L
    testthat::local_mocked_bindings(
      ledgr_backtest_diagnostics = function(...) altered,
      .package = "ledgr"
    )
    testthat::expect_identical(
      tibble::as_tibble(bt, what = "availability"),
      availability
    )
  })

  testthat::expect_identical(
    tibble::as_tibble(ledgr_results(bt, "diagnostics")),
    diagnostics
  )
  testthat::expect_identical(
    tibble::as_tibble(ledgr_results(bt, "availability")),
    availability
  )
  testthat::expect_identical(explanation$target_before_risk, 1)
  testthat::expect_identical(explanation$target_after_risk, 1)
  testthat::expect_identical(explanation$execution_outcome, "filled")
  testthat::expect_identical(explanation$resulting_position, 1)
  testthat::expect_identical(explanation$completion_status, "DONE")
  testthat::expect_true(explanation$complete_performance)
  testthat::expect_true(nzchar(explanation$feature_identity_json))

  close(bt)
  reopened <- ledgr_run_open(snapshot, bt$run_id)
  on.exit(close(reopened), add = TRUE)
  testthat::expect_identical(
    tibble::as_tibble(reopened, what = "diagnostics"),
    diagnostics
  )
  testthat::expect_identical(
    tibble::as_tibble(reopened, what = "availability"),
    availability
  )
  testthat::expect_identical(
    ledgr_run_explain(reopened, "AAA", decision$ts_utc),
    explanation
  )
  testthat::expect_identical(calls$n, calls_after_run)
  testthat::expect_identical(
    availability_store_contents(snapshot$db_path, bt$run_id),
    before
  )
})

# ledgr-test-profile: heavy_protocol
testthat::test_that("dense runs expose constant availability and no invented explanation", {
  snapshot <- ledgr_snapshot_from_df(utils::head(ledgr_demo_bars, 4L))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  exp <- ledgr_experiment(
    snapshot,
    function(ctx, params) ctx$flat(),
    cost_model = ledgr_cost_zero()
  )
  bt <- ledgr_run(exp, run_id = "dense-availability")
  on.exit(close(bt), add = TRUE)

  diagnostics <- tibble::as_tibble(bt, what = "diagnostics")
  availability <- tibble::as_tibble(bt, what = "availability")
  testthat::expect_identical(nrow(diagnostics), 0L)
  testthat::expect_identical(names(diagnostics), names(ledgr:::ledgr_availability_diagnostic_row(
    run_id = "x", diagnostic_seq = 1L, ts_utc = as.POSIXct("2020-01-01", tz = "UTC"),
    stage = "decision", outcome = "recorded"
  )))
  testthat::expect_true(nrow(availability) > 0L)
  testthat::expect_true(all(availability$member))
  testthat::expect_true(all(availability$admissible))
  testthat::expect_true(all(!availability$target_restricted))
  testthat::expect_error(
    ledgr_run_explain(bt, availability$instrument_id[[1L]], availability$ts_utc[[1L]]),
    class = "ledgr_run_explanation_unavailable"
  )
})

# ledgr-test-profile: review
testthat::test_that("walk-forward stops a carry-state chain on incomplete test evidence", {
  snapshot <- availability_runtime_fixture(
    days = 10L,
    bar_days = c(1L, 2L, 3L, 4L, 5L, 7L, 8L, 9L, 10L)
  )
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  exp <- ledgr_experiment(
    snapshot,
    function(ctx, params) ctx$hold(),
    opening = ledgr_opening(
      cash = 10000,
      positions = c(AAA = 1),
      cost_basis = c(AAA = 101)
    ),
    valuation_policy = ledgr_valuation_stale(0),
    cost_model = ledgr_cost_zero()
  )
  folds <- ledgr:::ledgr_fold_list(list(
    ledgr_fold(
      "2020-01-01T16:00:00Z", "2020-01-04T16:00:00Z",
      "2020-01-05T16:00:00Z", "2020-01-07T16:00:00Z", fold_seq = 1L
    ),
    ledgr_fold(
      "2020-01-04T16:00:00Z", "2020-01-07T16:00:00Z",
      "2020-01-08T16:00:00Z", "2020-01-10T16:00:00Z", fold_seq = 2L
    )
  ), constructor = list(type_id = "explicit"))
  wf <- ledgr_walk_forward(
    exp,
    grid = ledgr_param_grid(one = list(dummy = 1)),
    folds = folds,
    selection_rule = ledgr_select_argmax("sharpe_ratio"),
    seed = 44L
  )
  on.exit(lapply(wf$test_runs, close), add = TRUE)

  testthat::expect_identical(wf$status, "PARTIAL")
  testthat::expect_identical(nrow(wf$folds), 1L)
  testthat::expect_identical(wf$folds$status, "PARTIAL")
  testthat::expect_identical(length(wf$test_runs), 1L)
  test_rows <- wf$scores[wf$scores$window == "test", , drop = FALSE]
  testthat::expect_true(nrow(test_rows) > 0L)
  testthat::expect_true(all(test_rows$status == "INCOMPLETE"))
  testthat::expect_true(all(grepl("valuation_horizon_exhausted", test_rows$completion_json)))
  testthat::expect_false(any(wf$folds$fold_seq == 2L))

  reopened <- ledgr_walk_forward_open(snapshot, wf$session_id)
  testthat::expect_identical(reopened$status, "PARTIAL")
  testthat::expect_identical(reopened$folds, wf$folds)
  testthat::expect_identical(reopened$scores, wf$scores)
})

# ledgr-test-profile: heavy_protocol
testthat::test_that("[LTB-0024] walk-forward hydrates heterogeneous gaps on the session calendar", {
  dates <- as.Date("2020-01-01") + 0:9
  sessions <- ledgr_facts_sessions(
    data.frame(
      session_date = dates,
      status = "open",
      session_open = "09:30:00",
      session_close = "16:00:00",
      knowledge_time = as.POSIXct(dates, tz = "UTC") - 1,
      stringsAsFactors = FALSE
    ),
    venue_id = "XNYS"
  )
  make_bars <- function(instrument_id, keep, offset) {
    data.frame(
      instrument_id = instrument_id,
      ts_utc = as.POSIXct(paste(dates[keep], "16:00:00"), tz = "UTC"),
      open = 100 + offset + keep,
      high = 101 + offset + keep,
      low = 99 + offset + keep,
      close = 100 + offset + keep,
      volume = 1000,
      stringsAsFactors = FALSE
    )
  }
  bars <- rbind(
    make_bars("AAA", setdiff(seq_along(dates), 5L), 0),
    make_bars("BBB", setdiff(seq_along(dates), 8L), 20)
  )
  snapshot <- ledgr_snapshot_from_df(
    bars,
    instruments_df = data.frame(instrument_id = c("AAA", "BBB")),
    facts = ledgr_facts(sessions)
  )
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  exp <- ledgr_experiment(
    snapshot,
    function(ctx, params) {
      target <- ctx$hold()
      target[["BBB"]] <- params$qty
      target
    },
    universe = c("AAA", "BBB"),
    opening = ledgr_opening(
      cash = 10000,
      positions = c(AAA = 1, BBB = 1),
      cost_basis = c(AAA = 101, BBB = 121)
    ),
    valuation_policy = ledgr_valuation_stale(3),
    cost_model = ledgr_cost_zero()
  )
  grid <- ledgr_param_grid(one = list(qty = 2))
  folds <- ledgr:::ledgr_fold_list(
    list(
      ledgr_fold(
        "2020-01-01T16:00:00Z", "2020-01-03T16:00:00Z",
        "2020-01-04T16:00:00Z", "2020-01-05T16:00:00Z",
        fold_seq = 1L
      ),
      ledgr_fold(
        "2020-01-04T16:00:00Z", "2020-01-06T16:00:00Z",
        "2020-01-07T16:00:00Z", "2020-01-10T16:00:00Z",
        fold_seq = 2L
      )
    ),
    constructor = list(type_id = "explicit")
  )

  direct <- ledgr_run(
    exp,
    params = list(qty = 2),
    run_id = "heterogeneous-gap-direct"
  )
  on.exit(close(direct), add = TRUE)
  sweep <- ledgr_sweep(exp, grid, seed = 77L)
  wf <- ledgr_walk_forward(
    exp,
    grid = grid,
    folds = folds,
    selection_rule = ledgr_select_argmax("sharpe_ratio"),
    seed = 77L
  )
  on.exit(lapply(wf$test_runs, close), add = TRUE)

  testthat::expect_identical(
    ledgr_run_info(snapshot, direct$run_id)$status,
    "DONE"
  )
  testthat::expect_identical(sweep$status, "DONE")
  testthat::expect_identical(wf$status, "DONE")
  testthat::expect_identical(wf$folds$status, c("DONE", "DONE"))
  testthat::expect_length(wf$test_runs, 2L)

  first_equity <- ledgr_results(wf$test_runs[[1L]], "equity")
  first_final <- first_equity[nrow(first_equity), , drop = FALSE]
  opened <- ledgr:::ledgr_run_store_open(snapshot$db_path)
  on.exit(ledgr:::ledgr_run_store_close(opened), add = TRUE)
  first_positions <- ledgr:::ledgr_availability_positions_asof(
    opened$con,
    wf$test_runs[[1L]]$run_id,
    first_final$ts_utc[[1L]]
  )
  first_positions <- first_positions[abs(first_positions) > 1e-12]
  first_lots <- ledgr:::ledgr_lot_state_asof(
    opened$con,
    wf$test_runs[[1L]]$run_id,
    exp$universe,
    first_final$ts_utc[[1L]]
  )
  first_basis <- first_lots$cost_basis_by_inst[names(first_positions)] /
    first_positions
  second_opening <- wf$test_runs[[2L]]$config$opening

  testthat::expect_false(identical(first_positions, exp$opening$positions))
  testthat::expect_identical(second_opening$cash, first_final$cash[[1L]])
  testthat::expect_identical(second_opening$positions, first_positions)
  testthat::expect_identical(second_opening$cost_basis, first_basis)
})

testthat::test_that("walk-forward preserves incomplete status when prefix metrics fail", {
  path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(path), add = TRUE)
  calls <- new.env(parent = emptyenv())
  calls$n <- 0L
  fixture <- availability_incomplete_experiment(path, calls)
  on.exit(ledgr_snapshot_close(fixture$snapshot), add = TRUE)
  test_run <- ledgr_run(
    fixture$experiment,
    run_id = "incomplete-metric-prefix"
  )
  on.exit(close(test_run), add = TRUE)
  terminal <- ledgr:::ledgr_backtest_terminal_evidence(test_run)
  testthat::expect_identical(terminal$status, "INCOMPLETE")
  local({
    testthat::local_mocked_bindings(
      ledgr_compute_metrics = function(...) {
        rlang::abort("prefix too short", class = "ledgr_metric_prefix_too_short")
      },
      .package = "ledgr"
    )
    score <- ledgr:::ledgr_walk_forward_test_score_wide(test_run)
    testthat::expect_identical(score$status, "INCOMPLETE")
    testthat::expect_identical(score$error_class, "ledgr_metric_prefix_too_short")
    testthat::expect_identical(score$completion_json, terminal$completion_json)
  })
})
