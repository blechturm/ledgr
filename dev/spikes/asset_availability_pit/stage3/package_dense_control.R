stage3_w21_strategy <- function(ctx, params) {
  if (identical(ctx$ts_utc, "2024-01-02T21:00:00Z")) {
    return(c(A02 = 800, A01 = 50))
  }
  if (identical(ctx$ts_utc, "2024-01-03T21:00:00Z")) {
    return(c(A02 = 660, A01 = 0))
  }
  if (identical(ctx$ts_utc, "2024-01-04T21:00:00Z")) {
    return(c(A02 = 660, A01 = 0))
  }
  c(A02 = 0, A01 = 0)
}

stage3_w02_strategy <- function(ctx, params) {
  c(A01 = 0, A02 = 500)
}

stage3_run_w02_package_case <- function(fixture, case_id) {
  stage3_assert(case_id %in% c("c0a", "c0b"), "Unknown W02 package control case.")
  bars <- fixture$bars
  if (identical(case_id, "c0a")) {
    bars <- bars[!(
      bars$instrument_id == "A01" &
        stage3_iso(bars$ts_utc) == stage3_iso(fixture$pulses[[2L]])
    ), , drop = FALSE]
  }

  snapshot <- ledgr::ledgr_snapshot_from_df(
    bars,
    db_path = tempfile(paste0("asset-availability-w02-", case_id, "-"), fileext = ".duckdb")
  )
  on.exit(try(ledgr::ledgr_snapshot_close(snapshot), silent = TRUE), add = TRUE)
  experiment <- ledgr::ledgr_experiment(
    snapshot = snapshot,
    strategy = stage3_w02_strategy,
    opening = ledgr::ledgr_opening(
      cash = fixture$opening_cash[[case_id]],
      positions = c(A01 = fixture$opening_a01),
      cost_basis = c(A01 = fixture$prices[["A01"]])
    ),
    universe = fixture$instrument_ids,
    timing_model = ledgr::ledgr_timing_next_open(),
    cost_model = ledgr::ledgr_cost_zero(),
    risk_chain = ledgr::ledgr_risk_none(),
    execution_mode = "audit_log"
  )

  run <- tryCatch(
    ledgr::ledgr_run(experiment, run_id = paste0("asset-availability-w02-", case_id)),
    error = identity
  )
  if (inherits(run, "error")) {
    return(list(
      case_id = case_id,
      error_class = class(run)[[1L]],
      error_message = conditionMessage(run),
      pulses_executed = 0L,
      fill_count = 0L,
      cash_after = fixture$opening_cash[[case_id]]
    ))
  }
  on.exit(try(close(run), silent = TRUE), add = TRUE)

  fills <- as.data.frame(ledgr::ledgr_results(run, what = "fills"))
  equity <- as.data.frame(ledgr::ledgr_results(run, what = "equity"))
  fill_pulse <- match(stage3_iso(fills$ts_utc), stage3_iso(fixture$pulses))
  stage3_assert(!anyNA(fill_pulse), "W02 package fill does not map to a fixture pulse.")
  cash_delta <- ifelse(
    fills$side == "BUY",
    -(fills$qty * fills$price + fills$fee),
    fills$qty * fills$price - fills$fee
  )
  list(
    case_id = case_id,
    error_class = NULL,
    fills = data.frame(
      event_time = stage3_iso(fixture$execution_times[fill_pulse]),
      asset_id = fills$instrument_id,
      qty = fills$qty,
      cash_delta = cash_delta,
      event_cash_after = fixture$opening_cash[[case_id]] + cumsum(cash_delta),
      stringsAsFactors = FALSE
    ),
    pulses_executed = nrow(equity),
    fill_count = nrow(fills),
    cash_after = tail(equity$cash, 1L),
    equity = tail(equity$equity, 1L)
  )
}

stage3_run_w02_package_controls <- function(provider) {
  fixture <- stage3_provider_w02(provider)
  list(
    c0a = stage3_run_w02_package_case(fixture, "c0a"),
    c0b = stage3_run_w02_package_case(fixture, "c0b")
  )
}

stage3_run_w21_memory_fold <- function(fixture, exp) {
  ids <- fixture$instrument_ids
  pulses <- fixture$pulses
  pulses_iso <- stage3_iso(pulses)
  matrix_field <- function(field) stage3_bar_matrix(fixture, field)
  bars_mat <- list(
    open = matrix_field("open"),
    high = matrix_field("high"),
    low = matrix_field("low"),
    close = matrix_field("close"),
    volume = matrix_field("volume")
  )
  bars_mat$gap_type <- matrix("", nrow = length(ids), ncol = length(pulses), dimnames = dimnames(bars_mat$close))
  bars_mat$is_synthetic <- matrix(FALSE, nrow = length(ids), ncol = length(pulses), dimnames = dimnames(bars_mat$close))
  bars_by_id <- stats::setNames(lapply(ids, function(id) {
    rows <- fixture$bars$instrument_id == id
    data.frame(
      instrument_id = id,
      ts_utc = fixture$bars$ts_utc[rows],
      open = fixture$bars$open[rows],
      high = fixture$bars$high[rows],
      low = fixture$bars$low[rows],
      close = fixture$bars$close[rows],
      volume = fixture$bars$volume[rows],
      gap_type = "",
      is_synthetic = FALSE,
      stringsAsFactors = FALSE
    )
  }), ids)
  opening_positions <- fixture$opening$positions[fixture$opening$positions != 0]
  opening_rows <- getFromNamespace("ledgr_opening_position_event_rows", "ledgr")(
    run_id = "asset-availability-w21-memory",
    ts_utc = pulses[[1L]],
    positions = opening_positions,
    cost_basis = fixture$opening$lot_basis,
    event_seq_start = 1L
  )
  handler <- getFromNamespace("ledgr_memory_output_handler", "ledgr")(
    "asset-availability-w21-memory"
  )
  handler$append_event_rows(opening_rows)
  execution <- getFromNamespace("ledgr_execution_spec", "ledgr")(
    run_id = "asset-availability-w21-memory",
    instrument_ids = ids,
    strategy_fn = stage3_w21_strategy,
    strategy_params = list(),
    strategy_call_signature = getFromNamespace("ledgr_strategy_signature", "ledgr")(stage3_w21_strategy),
    strategy_is_functional = TRUE,
    pulses_posix = pulses,
    pulses_iso = pulses_iso,
    start_idx = 1L,
    max_pulses = Inf,
    checkpoint_every = 0L,
    telemetry_stride = 0L,
    state = list(
      cash = fixture$opening$cash,
      positions = fixture$opening$positions[ids],
      lot_state = getFromNamespace("ledgr_lot_state_from_opening", "ledgr")(
        ids,
        opening_positions,
        fixture$opening$lot_basis
      )
    ),
    state_prev = NULL,
    bars_by_id = bars_by_id,
    bars_mat = bars_mat,
    static_bars_views = NULL,
    static_feature_views = NULL,
    feature_defs = list(),
    runtime_projection = getFromNamespace("ledgr_projection_from_feature_matrix", "ledgr")(
      feature_matrix = list(),
      universe = ids,
      pulses_posix = pulses
    ),
    active_alias_map = NULL,
    risk_plan = getFromNamespace("ledgr_risk_plan_compile", "ledgr")(
      exp$risk_chain,
      params = list()
    ),
    cost_resolver = getFromNamespace("ledgr_cost_resolver_from_plan_json", "ledgr")(
      exp$cost_plan_json
    ),
    event_seq_start = as.integer(nrow(opening_rows)) + 1L,
    telemetry = getFromNamespace("ledgr_sweep_telemetry_env", "ledgr")(),
    seed = NULL,
    event_mode = "buffered",
    use_fast_context = TRUE,
    compiled_accounting_model = NULL
  )
  warnings <- character()
  withCallingHandlers(
    getFromNamespace("ledgr_execute_fold", "ledgr")(execution, handler),
    warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  kernel <- getFromNamespace("ledgr_metric_kernel", "ledgr")(
    context = ledgr::ledgr_metric_context(),
    pulses = pulses
  )
  list(
    events = handler$typed_events(),
    summary = handler$inline_summary("asset-availability-w21-memory", kernel),
    warnings = warnings
  )
}

stage3_run_w21_package <- function(fixture) {
  db_path <- tempfile("asset-availability-w21-", fileext = ".duckdb")
  snapshot <- ledgr::ledgr_snapshot_from_df(fixture$bars, db_path = db_path)
  on.exit(try(ledgr::ledgr_snapshot_close(snapshot), silent = TRUE), add = TRUE)

  opening <- ledgr::ledgr_opening(
    cash = fixture$opening$cash,
    positions = fixture$opening$positions[fixture$opening$positions != 0],
    cost_basis = fixture$opening$lot_basis
  )
  exp <- ledgr::ledgr_experiment(
    snapshot = snapshot,
    strategy = stage3_w21_strategy,
    opening = opening,
    universe = fixture$instrument_ids,
    timing_model = ledgr::ledgr_timing_next_open(),
    cost_model = ledgr::ledgr_cost_fixed_fee(fixture$fixed_fee),
    risk_chain = ledgr::ledgr_risk_max_weight(fixture$max_weight),
    execution_mode = "audit_log"
  )
  run_warnings <- character()
  bt <- withCallingHandlers(
    ledgr::ledgr_run(exp, run_id = "asset-availability-w21"),
    warning = function(w) {
      run_warnings <<- c(run_warnings, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  on.exit(try(close(bt), silent = TRUE), add = TRUE)

  fills <- as.data.frame(ledgr::ledgr_results(bt, what = "fills"))
  equity <- as.data.frame(ledgr::ledgr_results(bt, what = "equity"))
  ledger <- as.data.frame(ledgr::ledgr_results(bt, what = "ledger"))
  metrics <- ledgr::ledgr_compute_metrics(bt)
  memory <- stage3_run_w21_memory_fold(fixture, exp)
  stage3_assert(
    any(grepl("LEDGR_LAST_BAR_NO_FILL", c(run_warnings, memory$warnings), fixed = TRUE)),
    "Package W21 did not emit the final-pulse no-fill warning."
  )
  memory_equity <- as.data.frame(memory$summary$equity)
  stage3_assert(
    isTRUE(all.equal(
      memory_equity[, c("cash", "equity")],
      equity[, c("cash", "equity")],
      tolerance = 1e-12
    )),
    "Package W21 durable and memory fold equity differ."
  )
  memory_fills <- as.data.frame(memory$summary$fills)
  fill_fields <- c("instrument_id", "side", "qty", "price", "fee")
  stage3_assert(
    identical(memory_fills[, fill_fields], fills[, fill_fields]),
    "Package W21 durable and memory fold fills differ."
  )

  source_identity <- list(
    snapshot_hash = as.character(
      getFromNamespace("ledgr_precompute_snapshot_meta", "ledgr")(snapshot)$snapshot_hash
    ),
    config_hash = as.character(getFromNamespace("config_hash", "ledgr")(bt$config))
  )

  execution_fills <- fills[
    stage3_iso(fills$ts_utc) != stage3_iso(fixture$pulses[[1L]]),
    ,
    drop = FALSE
  ]
  fill_pulse <- match(
    stage3_iso(execution_fills$ts_utc),
    stage3_iso(fixture$pulses)
  )
  stage3_assert(
    !anyNA(fill_pulse) && all(fill_pulse > 1L),
    "Package W21 fills do not map to next-open fixture labels."
  )
  package_fills <- data.frame(
    event_time = stage3_iso(fixture$execution_times[fill_pulse]),
    asset_id = execution_fills$instrument_id,
    side = execution_fills$side,
    qty = execution_fills$qty,
    price = execution_fills$price,
    fee = execution_fills$fee,
    stringsAsFactors = FALSE
  )
  package_fills$cash_delta <- ifelse(
    package_fills$side == "BUY",
    -(package_fills$qty * package_fills$price + package_fills$fee),
    package_fills$qty * package_fills$price - package_fills$fee
  )
  package_fills$cash_after <- fixture$opening$cash + cumsum(package_fills$cash_delta)
  memory_events <- memory$events
  fill_event_index <- which(memory_events$event_type %in% c("FILL", "FILL_PARTIAL"))
  stage3_assert(
    length(fill_event_index) == nrow(package_fills),
    "Package W21 memory events do not match materialized fills."
  )
  event_realized <- attr(memory_events, "ledgr_event_realized", exact = TRUE)
  event_cost_basis <- attr(memory_events, "ledgr_event_cost_basis", exact = TRUE)
  execution_realized <- event_realized[fill_event_index]
  package_fills$realized_cumulative <- execution_realized
  package_fills$realized_delta <- c(
    execution_realized[[1L]],
    diff(execution_realized)
  )
  package_fills$position_after <- NA_real_
  package_fills$lot_qty_after <- NA_real_
  package_fills$lot_basis_after <- NA_real_
  package_lot_state <- NULL
  for (i in seq_along(fill_event_index)) {
    event_index <- fill_event_index[[i]]
    package_lot_state <- getFromNamespace("ledgr_lot_state_from_events", "ledgr")(
      memory_events[seq_len(event_index), , drop = FALSE],
      instrument_ids = fixture$instrument_ids
    )
    stage3_assert(
      isTRUE(all.equal(package_lot_state$realized_pnl, event_realized[[event_index]])) &&
        isTRUE(all.equal(package_lot_state$total_cost_basis, event_cost_basis[[event_index]])),
      "Package W21 reconstructed lot state differs from fold-owned accounting facts."
    )
    id <- package_fills$asset_id[[i]]
    lots <- package_lot_state$lots[[id]] %||% list()
    lot_qty <- if (length(lots) == 0L) 0 else {
      sum(vapply(lots, function(lot) as.numeric(lot$qty), numeric(1L)))
    }
    package_fills$position_after[[i]] <- lot_qty
    package_fills$lot_qty_after[[i]] <- lot_qty
    if (length(lots) > 0L) {
      stage3_assert(length(lots) == 1L, "W21 expected one open FIFO lot per held asset.")
      package_fills$lot_basis_after[[i]] <- as.numeric(lots[[1L]]$price)
    }
  }

  targets_post <- lapply(seq_along(fixture$pulses), function(i) {
    ctx <- list(
      equity = equity$equity[[i]],
      vec = list(close = stage3_bar_matrix(fixture, "close")[, i])
    )
    getFromNamespace("ledgr_apply_risk_plan", "ledgr")(
      stats::setNames(
        as.numeric(fixture$targets[i, fixture$instrument_ids]),
        fixture$instrument_ids
      ),
      getFromNamespace("ledgr_risk_plan_compile", "ledgr")(
        ledgr::ledgr_risk_max_weight(fixture$max_weight),
        params = list()
      ),
      ctx
    )
  })

  positions <- stats::setNames(vapply(fixture$instrument_ids, function(id) {
    item <- package_lot_state$lots[[id]] %||% list()
    if (length(item) == 0L) 0 else {
      sum(vapply(item, function(lot) as.numeric(lot$qty), numeric(1L)))
    }
  }, numeric(1L)), fixture$instrument_ids)
  lots <- stats::setNames(lapply(fixture$instrument_ids, function(id) {
    item <- package_lot_state$lots[[id]] %||% list()
    if (length(item) == 0L) {
      data.frame(qty = numeric(), basis = numeric())
    } else {
      data.frame(
        qty = vapply(item, function(lot) as.numeric(lot$qty), numeric(1L)),
        basis = vapply(item, function(lot) as.numeric(lot$price), numeric(1L))
      )
    }
  }), fixture$instrument_ids)
  final_changed <- names(targets_post[[length(targets_post)]])[abs(
    targets_post[[length(targets_post)]] - positions
  ) > sqrt(.Machine$double.eps)]
  stage3_assert(length(final_changed) == 1L, "W21 expected one final-pulse target change.")
  final_warning <- unique(c(run_warnings, memory$warnings))
  final_warning <- final_warning[grepl("LEDGR_LAST_BAR_NO_FILL", final_warning, fixed = TRUE)]
  stage3_assert(length(final_warning) >= 1L, "W21 final no-fill warning is missing.")
  list(
    source = "package_fold",
    fixture = fixture,
    opening_cash = fixture$opening$cash,
    opening_positions = fixture$opening$positions,
    opening_basis = fixture$opening$lot_basis,
    targets_pre = lapply(seq_len(nrow(fixture$targets)), function(i) fixture$targets[i, ]),
    targets_post = targets_post,
    fills = package_fills,
    equity = equity$equity,
    cash = tail(equity$cash, 1L),
    positions = positions,
    lots = lots,
    realized = sum(package_fills$realized_delta),
    final_no_fill = list(
      asset_id = final_changed[[1L]],
      status = "no_fill",
      reason_code = sub(":.*$", "", final_warning[[1L]])
    ),
    source_identity = source_identity,
    raw = list(
      fills = fills,
      equity = equity,
      ledger = ledger,
      metrics = metrics,
      memory_events = memory$events,
      memory_summary = memory$summary,
      warnings = unique(c(run_warnings, memory$warnings))
    )
  )
}
