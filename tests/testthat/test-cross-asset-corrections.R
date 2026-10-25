# ledgr-test-file-profile: review

ledgr_ws59_dust_values <- function() {
  buy <- 0.89101464257119367
  sell <- 0.89101464257119356
  list(buy = buy, sell = sell, residue = buy - sell)
}

ledgr_ws59_dust_bars <- function(n = 5L) {
  data.frame(
    ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * (seq_len(n) - 1L),
    instrument_id = "AAA",
    open = 100,
    high = 101,
    low = 99,
    close = 100,
    volume = 1000,
    stringsAsFactors = FALSE
  )
}

ledgr_ws59_dust_strategy <- function(ctx, params) {
  c(AAA = if (ctx$position("AAA") > 0) params$residue else 0)
}

ledgr_ws59_dust_experiment <- function(snapshot, values) {
  ledgr_experiment(
    snapshot,
    ledgr_ws59_dust_strategy,
    opening = ledgr_opening(
      cash = 1000,
      positions = c(AAA = values$buy),
      cost_basis = c(AAA = 100)
    ),
    cost_model = ledgr_cost_zero()
  )
}

testthat::test_that("[LTB-0497] fractional lot dust closes one canonical position", {
  values <- ledgr_ws59_dust_values()
  testthat::expect_identical(values$residue, .Machine$double.eps / 2)

  dense <- ledgr_snapshot_from_df(
    ledgr_ws59_dust_bars(),
    price_basis = "split_adjusted"
  )
  on.exit(ledgr_snapshot_close(dense), add = TRUE)
  dense_exp <- ledgr_ws59_dust_experiment(dense, values)
  dense_run <- ledgr_run(
    dense_exp,
    params = list(residue = values$residue),
    run_id = "ws59-dense-dust"
  )
  on.exit(close(dense_run), add = TRUE)

  opened <- ledgr_test_open_duckdb(dense_run$db_path)
  on.exit(ledgr_test_close_duckdb(opened$con, opened$drv), add = TRUE)
  rebuilt <- ledgr_state_reconstruct(dense_run$run_id, opened$con)
  testthat::expect_identical(rebuilt$positions$qty, 0)
  replay <- ledgr:::ledgr_replay_accounting_events(
    ledgr:::ledgr_prepare_accounting_events(
      as.data.frame(ledgr_results(dense_run, "ledger")),
      "AAA"
    )
  )
  testthat::expect_identical(unname(replay$positions), 0)
  testthat::expect_identical(unname(replay$lot_state$net_by_inst), 0)
  testthat::expect_identical(
    ledgr:::ledgr_accounting_positions_at_pulses(
      replay,
      ledgr_results(dense_run, "equity")$ts_utc,
      "AAA"
    )[, nrow(ledgr_results(dense_run, "equity"))],
    c(AAA = 0)
  )
  dense_fill <- ledgr_run_fills(dense_run)
  testthat::expect_identical(dense_fill$qty, values$sell)

  lifetime <- terminal_outcome_lifetime("AAA", 4L)
  availability <- terminal_outcome_snapshot(
    list(AAA = rep(100, 5)),
    lifetime = lifetime
  )
  on.exit(ledgr_snapshot_close(availability), add = TRUE)
  availability_exp <- terminal_outcome_experiment(
    availability,
    strategy = ledgr_ws59_dust_strategy,
    positions = c(AAA = values$buy)
  )
  availability_run <- ledgr_run(
    availability_exp,
    params = list(residue = values$residue),
    run_id = "ws59-availability-dust"
  )
  on.exit(close(availability_run), add = TRUE)
  tables <- terminal_outcome_tables(availability_run)
  testthat::expect_identical(tables$run$status, "DONE")
  testthat::expect_false(any(tables$events$event_type == "DISPOSITION"))
  testthat::expect_identical(
    tables$events$qty[tables$events$event_type == "FILL"],
    values$sell
  )
  availability_opened <- ledgr_test_open_duckdb(availability_run$db_path)
  on.exit(
    ledgr_test_close_duckdb(availability_opened$con, availability_opened$drv),
    add = TRUE
  )
  availability_state <- ledgr_state_reconstruct(
    availability_run$run_id,
    availability_opened$con
  )
  testthat::expect_identical(availability_state$positions$qty, 0)

  reopened <- ledgr_run_open(availability, availability_run$run_id)
  on.exit(close(reopened), add = TRUE)
  testthat::expect_identical(
    ledgr_results(reopened, "ledger")$qty,
    ledgr_results(availability_run, "ledger")$qty
  )
})

testthat::test_that("[LTB-0498] R and compiled FIFO share the dust boundary", {
  values <- ledgr_ws59_dust_values()
  state <- ledgr:::ledgr_lot_state("AAA")
  first <- ledgr:::ledgr_lot_apply_fill(
    state, "AAA", "BUY", values$buy, 100, 0
  )
  second <- ledgr:::ledgr_lot_apply_fill(
    first$state, "AAA", "SELL", values$sell, 100, 0
  )
  position <- ledgr:::ledgr_position_apply_delta(0, values$buy, values$buy)
  position <- ledgr:::ledgr_position_apply_delta(
    position,
    -values$sell,
    second$state$net_by_inst[[1L]]
  )

  compiled <- ledgr:::ledgr_cpp_spot_fifo_batch(
    "ws59-compiled-dust",
    as.integer(c(1, 1)),
    c("AAA", "AAA"),
    c("BUY", "SELL"),
    as.double(c(values$buy, values$sell)),
    as.double(c(100, 100)),
    as.double(c(0, 0)),
    as.double(c(1, 2)),
    1L,
    as.double(0),
    as.double(1000),
    integer(),
    double(),
    double(),
    as.double(0),
    as.double(0),
    as.double(0),
    as.double(0)
  )
  testthat::expect_identical(position, 0)
  testthat::expect_identical(second$state$net_by_inst[[1L]], 0)
  testthat::expect_identical(compiled$positions, 0)
  testthat::expect_length(compiled$lot_qty, 0L)
  testthat::expect_equal(compiled$cash, 1000, tolerance = 0)
  testthat::expect_equal(compiled$realized_pnl, 0, tolerance = 0)
  testthat::expect_identical(compiled$event_qty, c(values$buy, values$sell))

  fold_source <- paste(deparse(body(ledgr:::ledgr_fold_stage_apply)), collapse = "\n")
  replay_source <- paste(
    deparse(body(ledgr:::ledgr_replay_accounting_events)),
    collapse = "\n"
  )
  cpp_source <- paste(readLines("../../src/spot_fifo.cpp", warn = FALSE), collapse = "\n")
  testthat::expect_match(fold_source, "ledgr_position_apply_delta", fixed = TRUE)
  testthat::expect_match(replay_source, "ledgr_position_apply_delta", fixed = TRUE)
  testthat::expect_match(cpp_source, "std::abs(new_net) <= position_tol", fixed = TRUE)
})

testthat::test_that("[LTB-0499] omitted metric calendars remain visibly defaulted", {
  omitted <- list(
    ledgr_metric_context_resolve(NULL),
    ledgr_metric_context(),
    ledgr_metric_context(0.01),
    ledgr_metric_context(risk_free_rate = 0.02),
    ledgr_metric_context(ledgr_risk_free_rate(0.03))
  )
  testthat::expect_true(all(vapply(
    omitted,
    function(x) identical(x$calendar$label, "US equity daily (default)"),
    logical(1)
  )))
  explicit <- list(
    ledgr_metric_us_equity(),
    ledgr_metric_context(calendar = ledgr_calendar_us_equity()),
    ledgr_metric_crypto()
  )
  testthat::expect_true(all(!grepl(
    "(default)",
    vapply(explicit, function(x) x$calendar$label, character(1)),
    fixed = TRUE
  )))
  testthat::expect_identical(
    ledgr_metric_context_hash(omitted[[1L]]),
    ledgr_metric_context_hash(explicit[[1L]])
  )
  testthat::expect_identical(
    ledgr:::ledgr_metric_context_payload(omitted[[1L]]),
    ledgr:::ledgr_metric_context_payload(explicit[[1L]])
  )
  stored <- ledgr:::ledgr_metric_context_from_json(
    ledgr:::ledgr_metric_context_json(omitted[[1L]])
  )
  testthat::expect_identical(stored$calendar$label, "US equity daily (default)")

  snapshot <- terminal_outcome_snapshot(list(AAA = rep(100, 5)))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  strategy <- function(ctx, params) ctx$hold()
  exp <- ledgr_experiment(
    snapshot,
    strategy,
    opening = ledgr_opening(cash = 1000),
    valuation_policy = ledgr_valuation_stale(1),
    cost_model = ledgr_cost_zero()
  )
  plan_text <- paste(capture.output(print(ledgr_experiment_plan(exp))), collapse = "\n")
  exp_text <- paste(capture.output(print(exp)), collapse = "\n")
  testthat::expect_match(plan_text, "US equity daily (default)", fixed = TRUE)
  testthat::expect_match(exp_text, "US equity daily (default)", fixed = TRUE)
  run <- ledgr_run(exp, run_id = "ws59-default-calendar")
  on.exit(close(run), add = TRUE)
  testthat::expect_match(
    paste(capture.output(print(run)), collapse = "\n"),
    "US equity daily (default)",
    fixed = TRUE
  )
  testthat::expect_match(
    paste(capture.output(summary(run)), collapse = "\n"),
    "US equity daily (default)",
    fixed = TRUE
  )
  reopened <- ledgr_run_open(snapshot, run$run_id)
  on.exit(close(reopened), add = TRUE)
  testthat::expect_identical(
    ledgr_metric_context(reopened)$calendar$label,
    "US equity daily (default)"
  )
  testthat::expect_match(
    paste(capture.output(print(reopened)), collapse = "\n"),
    "US equity daily (default)",
    fixed = TRUE
  )
  testthat::expect_match(
    paste(capture.output(print(summary(reopened))), collapse = "\n"),
    "US equity daily (default)",
    fixed = TRUE
  )

  explicit_exp <- ledgr_experiment(
    snapshot,
    strategy,
    opening = ledgr_opening(cash = 1000),
    valuation_policy = ledgr_valuation_stale(1),
    metric_context = ledgr_metric_us_equity(),
    cost_model = ledgr_cost_zero()
  )
  explicit_run <- ledgr_run(
    explicit_exp,
    run_id = "ws59-explicit-calendar"
  )
  on.exit(close(explicit_run), add = TRUE)
  run_rows <- DBI::dbGetQuery(
    ledgr:::get_connection(snapshot),
    paste(
      "SELECT run_id, config_hash, metric_context_hash FROM runs",
      "WHERE run_id IN (?, ?) ORDER BY run_id"
    ),
    params = list(explicit_run$run_id, run$run_id)
  )
  testthat::expect_identical(length(unique(run_rows$config_hash)), 1L)
  testthat::expect_identical(length(unique(run_rows$metric_context_hash)), 1L)

  grid <- ledgr_grid_named(candidate = list(strategy = list()))
  default_sweep <- ledgr_sweep(exp, grid, seed = 59L)
  explicit_sweep <- ledgr_sweep(explicit_exp, grid, seed = 59L)
  default_candidate <- ledgr_candidate(default_sweep, 1L)
  explicit_candidate <- ledgr_candidate(explicit_sweep, 1L)
  testthat::expect_identical(
    default_candidate$candidate_id,
    explicit_candidate$candidate_id
  )
  testthat::expect_identical(
    default_candidate$execution_seed,
    explicit_candidate$execution_seed
  )
  testthat::expect_identical(
    ledgr_candidate_reproduction_key(default_candidate)$metric_context,
    ledgr_candidate_reproduction_key(explicit_candidate)$metric_context
  )
  ledgr_sweep_save(default_sweep, snapshot, sweep_id = "ws59-default-sweep")
  reopened_sweep <- ledgr_sweep_open(snapshot, "ws59-default-sweep")
  testthat::expect_identical(
    ledgr_metric_context(reopened_sweep)$calendar$label,
    "US equity daily (default)"
  )
  candidate <- ledgr_candidate(reopened_sweep, 1L)
  promoted <- ledgr_promote(
    exp,
    candidate,
    run_id = "ws59-default-promotion"
  )
  on.exit(close(promoted), add = TRUE)
  testthat::expect_identical(
    ledgr_metric_context(ledgr_promotion_context(promoted))$calendar$label,
    "US equity daily (default)"
  )

  folds <- ledgr:::ledgr_fold_list(
    list(ledgr_fold(
      "2020-01-01", "2020-01-02", "2020-01-03", "2020-01-05",
      fold_seq = 1L
    )),
    constructor = list(type_id = "explicit")
  )
  selection <- ledgr_rule_argmax("total_return")
  default_identity <- ledgr:::ledgr_walk_forward_session_identity(
    exp, grid, folds, selection, 59L, "carry_test_state", "fail"
  )
  explicit_identity <- ledgr:::ledgr_walk_forward_session_identity(
    explicit_exp, grid, folds, selection, 59L, "carry_test_state", "fail"
  )
  testthat::expect_identical(default_identity$session_id, explicit_identity$session_id)
})

testthat::test_that("[LTB-0500] result headlines are asset neutral without API drift", {
  states <- c("not_supplied", "none", "modeled", "unsupported")
  expected <- c(
    "Economic events: NOT SUPPLIED - returns may omit distributions",
    "Economic events: NONE - supplied facts did not affect held instruments",
    "Economic events: MODELED - configured settlement conventions were exercised",
    "Economic events: UNSUPPORTED - supplied effects were not represented"
  )
  actual <- vapply(states, function(state) {
    ledgr:::ledgr_corporate_action_headline(list(corporate_action_fidelity = state))
  }, character(1))
  testthat::expect_identical(unname(actual), expected)
  testthat::expect_true(exists("ledgr_corporate_action_summary", asNamespace("ledgr")))
  source <- paste(
    readLines("../../R/corporate-action-results.R", warn = FALSE),
    collapse = "\n"
  )
  retired <- paste("Corporate", "actions:")
  testthat::expect_false(grepl(retired, source, fixed = TRUE))
  testthat::expect_match(
    source,
    "ledgr_corporate_action_summary <- function",
    fixed = TRUE
  )
})
