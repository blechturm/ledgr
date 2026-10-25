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

ledgr_ws59_multi_lot_strategy <- function(ctx, params) {
  index <- match("AAA", ctx$universe)
  if (!is.na(index) && !isTRUE(ctx$vec$admissible[[index]])) {
    return(c(AAA = 0))
  }
  day <- as.Date(substr(ctx$ts_utc, 1L, 10L))
  target <- if (identical(day, as.Date(params$first_date))) {
    params$opening + params$addition
  } else {
    params$target
  }
  c(AAA = target)
}

ledgr_ws59_multi_lot_cases <- function() {
  list(
    empty_book = list(
      opening = 0.4451863695518114,
      addition = 0.53617929794592789,
      target = 3 * .Machine$double.eps / 2,
      held = FALSE
    ),
    live_book = list(
      opening = 1.376142555938568,
      addition = 2.4004326858976857,
      target = 2 * .Machine$double.eps,
      held = TRUE
    )
  )
}

ledgr_ws59_multi_lot_experiment <- function(snapshot, case) {
  ledgr_experiment(
    snapshot,
    ledgr_ws59_multi_lot_strategy,
    opening = ledgr_opening(
      cash = 1000,
      positions = c(AAA = case$opening),
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

  for (case_name in names(ledgr_ws59_multi_lot_cases())) {
    case <- ledgr_ws59_multi_lot_cases()[[case_name]]
    params <- c(case, list(first_date = "2020-01-01"))
    dense_case <- ledgr_snapshot_from_df(
      ledgr_ws59_dust_bars(6L),
      price_basis = "split_adjusted"
    )
    on.exit(ledgr_snapshot_close(dense_case), add = TRUE)
    dense_case_run <- ledgr_run(
      ledgr_ws59_multi_lot_experiment(dense_case, case),
      params = params,
      run_id = paste0("ws59-dense-", case_name)
    )
    on.exit(close(dense_case_run), add = TRUE)
    dense_case_opened <- ledgr_test_open_duckdb(dense_case_run$db_path)
    on.exit(
      ledgr_test_close_duckdb(dense_case_opened$con, dense_case_opened$drv),
      add = TRUE
    )
    dense_case_state <- ledgr_state_reconstruct(
      dense_case_run$run_id,
      dense_case_opened$con
    )
    testthat::expect_identical(
      dense_case_state$positions$qty != 0,
      case$held,
      info = case_name
    )
    dense_case_replay <- ledgr:::ledgr_replay_accounting_events(
      ledgr:::ledgr_prepare_accounting_events(
        as.data.frame(ledgr_results(dense_case_run, "ledger")),
        "AAA"
      )
    )
    testthat::expect_identical(
      ledgr:::ledgr_lot_count(dense_case_replay$lot_state, "AAA") > 0L,
      case$held,
      info = case_name
    )

    availability_case <- terminal_outcome_snapshot(
      list(AAA = rep(100, 6)),
      lifetime = terminal_outcome_lifetime("AAA", 5L)
    )
    on.exit(ledgr_snapshot_close(availability_case), add = TRUE)
    availability_case_exp <- terminal_outcome_experiment(
      availability_case,
      strategy = ledgr_ws59_multi_lot_strategy,
      positions = c(AAA = case$opening)
    )
    availability_case_run <- ledgr_run(
      availability_case_exp,
      params = params,
      run_id = paste0("ws59-availability-", case_name)
    )
    on.exit(close(availability_case_run), add = TRUE)
    availability_case_tables <- terminal_outcome_tables(availability_case_run)
    testthat::expect_identical(
      availability_case_tables$run$status,
      "DONE",
      info = case_name
    )
    testthat::expect_identical(
      any(availability_case_tables$events$event_type == "DISPOSITION"),
      case$held,
      info = case_name
    )
  }
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
  position <- ledgr:::ledgr_position_from_lots(second$state, "AAA")

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

  for (case_name in names(ledgr_ws59_multi_lot_cases())) {
    case <- ledgr_ws59_multi_lot_cases()[[case_name]]
    side <- c("BUY", "BUY", "SELL")
    qty <- c(case$opening, case$addition, case$opening + case$addition - case$target)
    r_state <- ledgr:::ledgr_lot_state("AAA")
    for (i in seq_along(qty)) {
      applied <- ledgr:::ledgr_lot_apply_fill(
        r_state, "AAA", side[[i]], qty[[i]], 100, 0
      )
      r_state <- applied$state
      r_position <- ledgr:::ledgr_position_from_lots(r_state, "AAA")
    }
    compiled_case <- ledgr:::ledgr_cpp_spot_fifo_batch(
      paste0("ws59-compiled-", case_name),
      rep.int(1L, 3L),
      rep("AAA", 3L),
      side,
      qty,
      rep(100, 3L),
      rep(0, 3L),
      as.double(1:3),
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
    testthat::expect_identical(compiled_case$positions[[1L]], r_position)
    testthat::expect_identical(
      length(compiled_case$lot_qty) > 0L,
      case$held,
      info = case_name
    )
    testthat::expect_identical(
      ledgr:::ledgr_lot_count(r_state, "AAA") > 0L,
      case$held,
      info = case_name
    )
    testthat::expect_identical(
      compiled_case$lot_qty,
      ledgr:::ledgr_lot_values(r_state, "AAA")$qty,
      info = case_name
    )

    public_snapshot <- ledgr_snapshot_from_df(
      ledgr_ws59_dust_bars(6L),
      price_basis = "split_adjusted"
    )
    on.exit(ledgr_snapshot_close(public_snapshot), add = TRUE)
    public_exp <- ledgr_ws59_multi_lot_experiment(public_snapshot, case)
    public_grid <- ledgr_grid_named(
      one = list(strategy = c(case, list(first_date = "2020-01-01")))
    )
    canonical_sweep <- ledgr_sweep(public_exp, public_grid, seed = 59L)
    compiled_sweep <- ledgr_sweep(
      public_exp,
      public_grid,
      seed = 59L,
      compiled_accounting_model = "spot_fifo"
    )
    stable_columns <- setdiff(
      names(canonical_sweep),
      c("t_engine", "t_results", "t_fills_extract")
    )
    testthat::expect_identical(
      as.data.frame(compiled_sweep)[stable_columns],
      as.data.frame(canonical_sweep)[stable_columns],
      info = case_name
    )
  }

  fold_source <- paste(deparse(body(ledgr:::ledgr_fold_stage_apply)), collapse = "\n")
  replay_source <- paste(
    deparse(body(ledgr:::ledgr_replay_accounting_events)),
    collapse = "\n"
  )
  cpp_source <- paste(readLines("../../src/spot_fifo.cpp", warn = FALSE), collapse = "\n")
  testthat::expect_match(fold_source, "ledgr_position_from_lots", fixed = TRUE)
  testthat::expect_match(replay_source, "ledgr_position_from_lots", fixed = TRUE)
  testthat::expect_match(
    cpp_source,
    "double new_net = inst_lots.empty() ? 0.0 : net_after",
    fixed = TRUE
  )
})

testthat::test_that("[LTB-0499] omitted metric calendars remain visibly defaulted", {
  omitted <- list(
    ledgr_metric_context_resolve(NULL),
    ledgr_metric_context_resolve(0.01),
    ledgr_metric_context_resolve(ledgr_risk_free_rate(0.015)),
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

  snapshot <- terminal_outcome_snapshot(list(AAA = 100:104))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  strategy <- function(ctx, params) ctx$hold()
  exp <- ledgr_experiment(
    snapshot,
    strategy,
    opening = ledgr_opening(
      cash = 1000,
      positions = c(AAA = 1),
      cost_basis = c(AAA = 100)
    ),
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
    opening = ledgr_opening(
      cash = 1000,
      positions = c(AAA = 1),
      cost_basis = c(AAA = 100)
    ),
    valuation_policy = ledgr_valuation_stale(1),
    metric_context = ledgr_metric_us_equity(),
    cost_model = ledgr_cost_zero()
  )
  explicit_run <- ledgr_run(
    explicit_exp,
    run_id = "ws59-explicit-calendar"
  )
  on.exit(close(explicit_run), add = TRUE)
  default_metrics <- unclass(ledgr_compute_metrics(run))
  explicit_metrics <- unclass(ledgr_compute_metrics(explicit_run))
  attributes(default_metrics) <- list(names = names(default_metrics))
  attributes(explicit_metrics) <- list(names = names(explicit_metrics))
  testthat::expect_identical(default_metrics, explicit_metrics)
  testthat::expect_gt(default_metrics$total_return, 0)
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

  dates <- as.Date("2020-01-01") + 0:2
  bars <- ledgr_test_make_bars("AAA", dates)
  rows <- data.frame(
    fact_id = "cash_fact",
    subtype = "ordinary_cash_dividend",
    parent_instrument_id = "AAA",
    entitlement_time = as.POSIXct("2020-01-02 00:00:00", tz = "UTC"),
    effective_time = as.POSIXct("2020-01-02 00:00:00", tz = "UTC"),
    knowledge_time = as.POSIXct("2020-01-01 00:00:00", tz = "UTC"),
    complete = TRUE,
    refusal_reason = NA_character_,
    provenance_tier = "snapshot_bound",
    gross_cash_per_parent_unit = 1.25,
    gross_cash_validated = TRUE,
    recipient_identity_validated = FALSE,
    recipient_quantity_validated = FALSE,
    source = "ws59",
    stringsAsFactors = FALSE
  )
  facts <- ledgr_facts(ledgr_facts_equity_corporate_actions(rows))
  modeled_snapshot <- ledgr_snapshot_from_df(
    bars,
    facts = facts,
    price_basis = "split_adjusted"
  )
  on.exit(ledgr_snapshot_close(modeled_snapshot), add = TRUE)
  modeled_exp <- ledgr_experiment(
    modeled_snapshot,
    function(ctx, params) ctx$hold(),
    opening = ledgr_opening(
      cash = 1000,
      positions = c(AAA = 1),
      cost_basis = c(AAA = 100)
    ),
    cost_model = ledgr_cost_zero()
  )
  modeled_run <- ledgr_run(modeled_exp, run_id = "ws59-modeled-headline")
  on.exit(close(modeled_run), add = TRUE)
  modeled_expected <- expected[[3L]]
  testthat::expect_true(modeled_expected %in% capture.output(print(modeled_run)))
  testthat::expect_true(modeled_expected %in% capture.output(summary(modeled_run)))
  modeled_reopened <- ledgr_run_open(modeled_snapshot, modeled_run$run_id)
  on.exit(close(modeled_reopened), add = TRUE)
  testthat::expect_true(
    modeled_expected %in% capture.output(print(modeled_reopened))
  )
  testthat::expect_true(
    modeled_expected %in% capture.output(summary(modeled_reopened))
  )
})
