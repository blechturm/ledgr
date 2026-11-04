ledgr_sweep_test_bars <- function(n_pulses = 6L) {
  offsets <- seq_len(n_pulses) - 1L
  data.frame(
    ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * offsets,
    instrument_id = "AAA",
    open = 100 + offsets,
    high = 101 + offsets,
    low = 99 + offsets,
    close = 100 + offsets,
    volume = 1000,
    stringsAsFactors = FALSE
  )
}

# Direct-fold fixtures take their runtime projection from production
# precompute (LDG-3067); the payload is computed by ledgr_precompute_features()
# on a sealed snapshot of the same bars, never by a test-only matrix builder.
ledgr_sweep_test_precomputed <- function(bars, indicators, feature_defs) {
  snapshot <- ledgr_snapshot_from_df(bars)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  exp <- ledgr_experiment(opening = ledgr_opening(cash = 100000),
    snapshot,
    function(ctx, params) ctx$flat(),
    features = indicators,
    cost_model = ledgr_cost_zero()
  )
  precomputed <- ledgr_precompute_features(exp, ledgr_grid_named(candidate = list(strategy = list())))
  testthat::expect_identical(
    precomputed$feature_union$fingerprint,
    vapply(feature_defs, `[[`, character(1), "fingerprint")
  )
  precomputed
}

ledgr_sweep_artifact_counts <- function(snapshot) {
  con <- get_connection(snapshot)
  tables <- c("runs", "ledger_events", "equity_curve", "run_telemetry")
  stats::setNames(vapply(tables, function(table) {
    if (!DBI::dbExistsTable(con, table)) {
      return(0L)
    }
    as.integer(DBI::dbGetQuery(con, sprintf("SELECT COUNT(*) AS n FROM %s", table))$n[[1]])
  }, integer(1)), tables)
}

testthat::test_that("memory output handler stores typed events equivalent to ledger rows", {
  handler <- ledgr:::ledgr_output_handler(ledgr:::ledgr_output_sink_memory("typed-memory"))
  opening <- ledgr:::ledgr_opening_position_event_rows(
    run_id = "typed-memory",
    ts_utc = as.POSIXct("2020-01-01", tz = "UTC"),
    positions = c(AAA = 2),
    cost_basis = c(AAA = 10),
    event_seq_start = 1L
  )
  handler$append_event_rows(opening)
  handler$init_buffers(1L)

  # LDG-3166 (design note Section 5, category 1): a one-row typed fill.
  fill <- ledgr_test_next_open_fill(
    desired_qty_delta = -1,
    next_bar = list(instrument_id = "AAA", ts_utc = "2020-01-02T00:00:00Z", open = 12),
    commission_fixed = 0.25
  )
  # LDG-3167 (category 1): the expected row is the one-row block of the
  # durable builder (serialized metadata), with its epoch as POSIXct.
  full_block <- ledgr:::ledgr_fill_event_payload("typed-memory", fill$fill, fill$i, fill$instrument_id, 2L)
  full_block$ts_utc <- .POSIXct(full_block$ts_utc, tz = "UTC")
  write_res <- handler$write_fill_events(fill$fill, fill$i, fill$instrument_id, 2L)
  testthat::expect_identical(nrow(handler$events()), 1L)
  handler$flush_pulse_events()

  expected <- tibble::as_tibble(rbind(opening, ledgr:::ledgr_event_row_df(full_block)))
  events <- handler$events()
  typed_events <- handler$typed_events()

  testthat::expect_s3_class(events, "tbl_df")
  testthat::expect_equal(as.data.frame(events), as.data.frame(expected), ignore_attr = TRUE)
  testthat::expect_identical(events$event_seq, c(1L, 2L))
  testthat::expect_identical(events$event_type, c("CASHFLOW", "FILL"))
  testthat::expect_s3_class(typed_events, "ledgr_memory_events")
  testthat::expect_false("meta_json" %in% names(typed_events))
  testthat::expect_identical(typed_events$source, c("opening_position", NA_character_))
  pulses <- as.POSIXct(c("2020-01-01", "2020-01-02"), tz = "UTC")
  testthat::expect_equal(
    ledgr:::ledgr_fills_from_events(typed_events, pulses),
    ledgr:::ledgr_fills_from_events(events, pulses)
  )
})

testthat::test_that("memory output handler preserves full event columns across growth", {
  run_id <- "typed-memory-growth"
  handler <- ledgr:::ledgr_output_handler(ledgr:::ledgr_output_sink_memory(run_id))
  n_events <- 1025L
  handler$init_buffers(n_events)
  expected <- vector("list", n_events)
  for (i in seq_len(n_events)) {
    fill <- ledgr_test_next_open_fill(
      desired_qty_delta = i,
      next_bar = list(
        instrument_id = sprintf("inst-%04d", i),
        ts_utc = as.POSIXct("2020-01-01 00:00:00", tz = "UTC") + i,
        open = 100 + i
      ),
      spread_bps = 0,
      commission_fixed = i / 100
    )
    # LDG-3167 (category 1): one typed block per event, written and flushed;
    # the expected row is the durable builder's one-row block.
    block <- ledgr:::ledgr_fill_event_payload(run_id, fill$fill, fill$i, fill$instrument_id, i)
    block$ts_utc <- .POSIXct(block$ts_utc, tz = "UTC")
    block$mark_source_ts_utc <- .POSIXct(block$mark_source_ts_utc, tz = "UTC")
    expected[[i]] <- block[ledgr:::ledgr_output_event_columns]
    handler$write_fill_events(fill$fill, fill$i, fill$instrument_id, i)
    handler$flush_pulse_events()
  }

  events <- handler$events()
  expected <- do.call(rbind.data.frame, c(expected, list(stringsAsFactors = FALSE)))
  testthat::expect_identical(events$event_id, expected$event_id)
  testthat::expect_identical(events$run_id, expected$run_id)
  testthat::expect_equal(
    as.POSIXct(events$ts_utc, tz = "UTC"),
    as.POSIXct(expected$ts_utc, tz = "UTC")
  )
  testthat::expect_identical(events$event_type, expected$event_type)
  testthat::expect_identical(events$instrument_id, expected$instrument_id)
  testthat::expect_identical(events$side, expected$side)
  testthat::expect_equal(events$qty, expected$qty)
  testthat::expect_equal(events$price, expected$price)
  testthat::expect_equal(events$fee, expected$fee)
  testthat::expect_identical(as.integer(events$event_seq), expected$event_seq)
  for (name in setdiff(ledgr:::ledgr_accounting_event_columns(), c(
    "event_id", "run_id", "ts_utc", "event_type", "instrument_id", "side",
    "qty", "price", "fee", "event_seq", "mark_source_ts_utc"
  ))) {
    testthat::expect_identical(events[[name]], expected[[name]], info = name)
  }
  testthat::expect_identical(
    as.numeric(events$mark_source_ts_utc),
    as.numeric(expected$mark_source_ts_utc)
  )
})

testthat::test_that("single-pass sweep summary matches separate reconstruction helpers", {
  handler <- ledgr:::ledgr_output_handler(ledgr:::ledgr_output_sink_memory("single-pass-summary"))
  pulses <- as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:1
  opening <- ledgr:::ledgr_opening_position_event_rows(
    run_id = "single-pass-summary",
    ts_utc = pulses[[1L]],
    positions = c(AAA = 2),
    cost_basis = c(AAA = 10),
    event_seq_start = 1L
  )
  handler$append_event_rows(opening)
  handler$init_buffers(1L)

  # LDG-3166 (design note Section 5, category 1): a one-row typed fill.
  fill <- ledgr_test_next_open_fill(
    desired_qty_delta = -1,
    next_bar = list(instrument_id = "AAA", ts_utc = "2020-01-02T00:00:00Z", open = 12),
    commission_fixed = 0.25
  )
  handler$write_fill_events(fill$fill, fill$i, fill$instrument_id, 2L)
  handler$flush_pulse_events()
  events <- handler$typed_events()
  close_mat <- matrix(c(10, 12), nrow = 1L, dimnames = list("AAA", NULL))
  metric_kernel <- ledgr:::ledgr_metric_kernel(context = ledgr_metric_context(), pulses = pulses)

  summary <- ledgr:::ledgr_sweep_summary_from_ordered_events(
    events = events,
    pulses_posix = pulses,
    close_mat = close_mat,
    initial_cash = 1000,
    instrument_ids = "AAA",
    run_id = "single-pass-summary",
    metric_kernel = metric_kernel
  )
  equity <- ledgr:::ledgr_equity_from_events(
    events = events,
    pulses_posix = pulses,
    close_mat = close_mat,
    initial_cash = 1000,
    instrument_ids = "AAA",
    run_id = "single-pass-summary"
  )
  fills <- ledgr:::ledgr_fills_from_events(events, pulses)
  metrics <- ledgr:::ledgr_metrics_from_equity_fills(
    equity = equity,
    fills = fills,
    metric_kernel = metric_kernel
  )

  testthat::expect_equal(summary$equity, equity)
  testthat::expect_equal(summary$fills, fills)
  testthat::expect_equal(summary$metrics, metrics)
  testthat::expect_equal(summary$final_equity, equity$equity[[nrow(equity)]])

  unsorted <- events[c(2L, 1L), , drop = FALSE]
  testthat::expect_error(
    ledgr:::ledgr_sweep_summary_from_ordered_events(
      events = unsorted,
      pulses_posix = pulses,
      close_mat = close_mat,
      initial_cash = 1000,
      instrument_ids = "AAA",
      run_id = "single-pass-summary",
      metric_kernel = metric_kernel
    ),
    class = "ledgr_invalid_event_order"
  )
})

testthat::test_that("inline accounting summary matches reconstruction with opening and split fill", {
  run_id <- "inline-accounting-summary"
  handler <- ledgr:::ledgr_output_handler(ledgr:::ledgr_output_sink_memory(run_id))
  pulses <- as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:1
  opening <- ledgr:::ledgr_opening_position_event_rows(
    run_id = run_id,
    ts_utc = pulses[[1L]],
    positions = c(AAA = 2),
    cost_basis = c(AAA = 10),
    event_seq_start = 1L
  )
  handler$append_event_rows(opening)
  handler$init_buffers(1L)

  # LDG-3164 (decision 10, categories 1 and 4): the typed opening and the
  # typed fill operation feed the same handler calls; AAA is book position 1.
  lot_state <- ledgr:::ledgr_lot_book_from_opening(
    instrument_ids = "AAA",
    positions = c(AAA = 2),
    cost_basis = c(AAA = 10)
  )
  # LDG-3168 (category 1): the equity facts are rows of a typed equity
  # record, handed to the inline summary as the fold's frozen prefix.
  equity <- ledgr:::ledgr_fold_equity_record(2L)
  equity <- ledgr:::ledgr_fold_equity_append(
    equity,
    ts = pulses[[1L]],
    cash = 1000,
    positions_value = 20,
    realized_pnl = lot_state$realized_pnl,
    cost_basis = lot_state$total_cost_basis
  )

  # LDG-3166 (design note Section 5, category 1): a one-row typed fill.
  fill <- ledgr_test_next_open_fill(
    desired_qty_delta = -3,
    next_bar = list(instrument_id = "AAA", ts_utc = "2020-01-02T00:00:00Z", open = 12),
    commission_fixed = 0.25
  )
  lot_res <- ledgr:::ledgr_lot_fill(
    lot_state,
    pos = 1L,
    side = fill$fill$side,
    qty = fill$fill$qty,
    price = fill$fill$price,
    fee = fill$fill$fee
  )
  lot_state <- lot_res$book
  write_res <- handler$write_fill_events(fill$fill, fill$i, fill$instrument_id, 2L)
  handler$record_accounting_fact(write_res, lot_res$applied)
  handler$flush_pulse_events()
  equity <- ledgr:::ledgr_fold_equity_append(
    equity,
    ts = pulses[[2L]],
    cash = 1000 + write_res$cash_delta,
    positions_value = -12,
    realized_pnl = lot_state$realized_pnl,
    cost_basis = lot_state$total_cost_basis
  )

  events <- handler$typed_events()
  close_mat <- matrix(c(10, 12), nrow = 1L, dimnames = list("AAA", NULL))
  metric_kernel <- ledgr:::ledgr_metric_kernel(context = ledgr_metric_context(), pulses = pulses)
  reconstructed <- ledgr:::ledgr_sweep_summary_from_ordered_events(
    events = events,
    pulses_posix = pulses,
    close_mat = close_mat,
    initial_cash = 1000,
    instrument_ids = "AAA",
    run_id = run_id,
    metric_kernel = metric_kernel
  )
  inline <- handler$inline_summary(run_id, metric_kernel, ledgr:::ledgr_fold_equity_prefix(equity))

  testthat::expect_equal(inline$equity, reconstructed$equity)
  testthat::expect_equal(inline$fills, reconstructed$fills)
  testthat::expect_equal(inline$metrics, reconstructed$metrics)
  testthat::expect_equal(inline$final_equity, reconstructed$final_equity)
  testthat::expect_null(attr(events, "ledgr_event_realized"))
  testthat::expect_null(attr(events, "ledgr_event_cost_basis"))
  testthat::expect_equal(inline$fills$action, c("CLOSE", "OPEN"))
  testthat::expect_equal(inline$fills$qty, c(2, 1))
})

# ledgr-test-profile: heavy_protocol
testthat::test_that("sweep public compiled accounting opt-in dispatches spot FIFO path", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)
  pulses <- as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:3
  bars <- data.frame(
    ts_utc = pulses,
    instrument_id = "AAA",
    open = c(10, 11, 12, 13),
    high = c(10.5, 11.5, 12.5, 13.5),
    low = c(9.5, 10.5, 11.5, 12.5),
    close = c(10, 11, 12, 13),
    volume = 1000,
    stringsAsFactors = FALSE
  )
  snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  targets_by_day <- stats::setNames(
    c(2, -1, 1, 1),
    vapply(pulses, ledgr:::ledgr_normalize_ts_utc, character(1))
  )
  strategy <- function(ctx, params) {
    stats::setNames(targets_by_day[[ctx$ts_utc]], "AAA")
  }
  exp <- ledgr_experiment(
    snapshot,
    strategy,
    features = list(),
    opening = ledgr_opening(cash = 1000),
    cost_model = ledgr_cost_fixed_fee(0.25)
  )
  grid <- ledgr_grid_named(candidate = list(strategy = list()))
  r_path <- ledgr_sweep(exp, grid, seed = 123L)
  compiled_arg_path <- ledgr_sweep(
    exp,
    grid,
    seed = 123L,
    compiled_accounting_model = "spot_fifo"
  )

  withr::local_options(list(ledgr.internal.compiled_accounting_model = "spot_fifo"))
  option_ignored_path <- ledgr_sweep(exp, grid, seed = 123L)

  testthat::expect_identical(as.character(compiled_arg_path$status), as.character(r_path$status))
  testthat::expect_equal(compiled_arg_path$final_equity, r_path$final_equity)
  testthat::expect_equal(compiled_arg_path$n_trades, r_path$n_trades)
  testthat::expect_identical(
    attr(compiled_arg_path, "execution_assumptions")$compiled_accounting_model,
    "spot_fifo"
  )
  testthat::expect_identical(as.character(option_ignored_path$status), as.character(r_path$status))
  testthat::expect_equal(option_ignored_path$final_equity, r_path$final_equity)
  testthat::expect_equal(option_ignored_path$n_trades, r_path$n_trades)
  testthat::expect_null(attr(option_ignored_path, "execution_assumptions")$compiled_accounting_model)

  withr::local_options(list(ledgr.internal.compiled_accounting_model = NULL))
  restored_path <- ledgr_sweep(exp, grid, seed = 123L)
  testthat::expect_null(getOption("ledgr.internal.compiled_accounting_model", NULL))
  testthat::expect_equal(restored_path$final_equity, r_path$final_equity)
  testthat::expect_equal(restored_path$n_trades, r_path$n_trades)
  testthat::expect_error(
    ledgr_sweep(exp, grid, seed = 123L, compiled_accounting_model = "futures_margin"),
    class = "ledgr_unsupported_accounting_model"
  )
})

# ledgr-test-profile: heavy_protocol
testthat::test_that("sweep public compiled accounting preserves risk parity", {
  snapshot <- ledgr_snapshot_from_df(ledgr_sweep_test_bars())
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) {
    if (identical(ctx$ts_utc, "2020-01-01T00:00:00Z")) {
      targets <- ctx$flat()
      targets["AAA"] <- 1000
      return(targets)
    }
    ctx$hold()
  }
  risk <- ledgr_risk_max_weight(ledgr_param("cap"))
  exp <- ledgr_experiment(opening = ledgr_opening(cash = 100000),
    snapshot,
    strategy,
    risk_chain = risk,
    cost_model = ledgr_cost_zero()
  )
  grid <- ledgr_grid_named(
    low = list(strategy = list(cap = 0.10)),
    high = list(strategy = list(cap = 0.20))
  )

  r_path <- ledgr_sweep(exp, grid, seed = 123L)
  compiled_path <- ledgr_sweep(
    exp,
    grid,
    seed = 123L,
    compiled_accounting_model = "spot_fifo"
  )

  testthat::expect_identical(as.character(compiled_path$status), as.character(r_path$status))
  testthat::expect_equal(compiled_path$final_equity, r_path$final_equity, tolerance = 1e-12)
  testthat::expect_equal(compiled_path$n_trades, r_path$n_trades)
  testthat::expect_identical(compiled_path$risk_chain_hash, r_path$risk_chain_hash)
  testthat::expect_true(all(vapply(compiled_path$provenance, function(provenance) {
    identical(provenance$risk_plan_json, ledgr:::ledgr_risk_plan_json(risk))
  }, logical(1))))
  testthat::expect_identical(
    attr(compiled_path, "execution_assumptions")$compiled_accounting_model,
    "spot_fifo"
  )
  testthat::expect_gt(compiled_path$final_equity[[2]], compiled_path$final_equity[[1]])
  testthat::expect_error(
    ledgr_sweep(exp, grid, seed = 123L, compiled_accounting_model = "futures_margin"),
    class = "ledgr_unsupported_accounting_model"
  )

  failure_grid <- ledgr_grid_named(
    ok = list(strategy = list(cap = 0.10)),
    bad = list(strategy = list(cap = 2))
  )
  failure_path <- ledgr_sweep(
    exp,
    failure_grid,
    seed = 123L,
    stop_on_error = FALSE,
    compiled_accounting_model = "spot_fifo"
  )
  testthat::expect_identical(as.character(failure_path$status), c("DONE", "FAILED"))
  testthat::expect_identical(failure_path$error_class[[2]], "ledgr_invalid_risk_model")
})

testthat::test_that("fills reconstruction is invariant under hostile collapse settings", {
  events <- ledgr:::ledgr_accounting_rows(
    event_id = sprintf("event_%02d", 1:4),
    run_id = "hostile-collapse-fills",
    ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:3,
    event_type = rep("FILL", 4L),
    instrument_id = rep("AAA", 4L),
    side = c("BUY", "SELL", "SELL", "BUY"),
    qty = c(2, 1, 3, 1),
    price = c(10, 12, 11, 9),
    fee = c(0, 0.1, 0.2, 0),
    event_seq = 1:4,
    cash_delta = c(-20, 11.9, 32.8, -9),
    position_delta = c(2, -1, -3, 1)
  )

  pulses <- as.POSIXct(events$ts_utc, tz = "UTC")
  expected <- ledgr:::ledgr_fills_from_events(events, pulses)
  old <- collapse::set_collapse()
  on.exit(do.call(collapse::set_collapse, old), add = TRUE)
  collapse::set_collapse(nthreads = 2L, na.rm = TRUE, sort = FALSE, stable.algo = FALSE)
  hostile <- ledgr:::ledgr_fills_from_events(events, pulses)

  testthat::expect_equal(hostile, expected)
})

# ledgr-test-profile: heavy_protocol
testthat::test_that("ledgr_sweep returns ordered summary rows without store writes", {
  snapshot <- ledgr_snapshot_from_df(ledgr_sweep_test_bars())
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    targets["AAA"] <- params$qty
    targets
  }
  exp <- ledgr_experiment(opening = ledgr_opening(cash = 100000), snapshot, strategy, cost_model = ledgr_cost_zero())
  grid <- ledgr_grid_named(a = list(strategy = list(qty = 1)), b = list(strategy = list(qty = 2)))

  before_counts <- ledgr_sweep_artifact_counts(snapshot)
  before_telemetry <- ls(ledgr:::.ledgr_telemetry_registry, all.names = TRUE)
  out <- ledgr_sweep(exp, grid, seed = 123L)
  after_counts <- ledgr_sweep_artifact_counts(snapshot)
  after_telemetry <- ls(ledgr:::.ledgr_telemetry_registry, all.names = TRUE)

  testthat::expect_s3_class(out, "ledgr_sweep_results")
  testthat::expect_identical(out$candidate_id, c("a", "b"))
  testthat::expect_identical(out$candidate_row, 1:2)
  testthat::expect_identical(out$status, c("DONE", "DONE"))
  testthat::expect_true(all(is.finite(out$final_equity)))
  testthat::expect_true(all(is.finite(out$total_return)))
  testthat::expect_true(all(!is.na(out$execution_seed)))
  testthat::expect_identical(attr(out, "evaluation_scope"), "exploratory")
  testthat::expect_identical(before_counts, after_counts)
  testthat::expect_identical(before_telemetry, after_telemetry)
})

# ledgr-test-profile: heavy_protocol
testthat::test_that("ledgr_sweep_results has the v0.1.8 column and metadata contract", {
  snapshot <- ledgr_snapshot_from_df(ledgr_sweep_test_bars())
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    targets["AAA"] <- params$qty
    targets
  }
  exp <- ledgr_experiment(opening = ledgr_opening(cash = 100000), snapshot, strategy, cost_model = ledgr_cost_zero())
  grid <- ledgr_grid_named(a = list(strategy = list(qty = 1)), b = list(strategy = list(qty = 2)))

  unseeded <- ledgr_sweep(exp, grid)
  seeded <- ledgr_sweep(exp, grid, seed = 123L)

  testthat::expect_identical(
    names(seeded),
    c(
      "candidate_id", "candidate_row", "status", "completion_json",
      # LDG-2960 derives these from completion_json on every sweep table.
      "stop_reason", "affected_instrument_ids", "valuation_state",
      "frozen_instrument_sessions", "max_frozen_equity_weight",
      "frozen_at_end_value", "assumed_terminal_outcomes", "final_equity", "total_return",
      "annualized_return", "volatility", "sharpe_ratio", "max_drawdown",
      "n_trades", "win_rate", "avg_trade", "time_in_market",
      "execution_seed", "error_class", "error_msg", "params",
      "feature_params", "warnings", "diagnostics", "feature_fingerprints", "risk_chain_hash",
      "provenance", "t_engine", "t_results", "t_fills_extract"
    )
  )
  testthat::expect_type(unseeded$execution_seed, "integer")
  testthat::expect_true(all(is.na(unseeded$execution_seed)))
  testthat::expect_type(seeded$execution_seed, "integer")
  testthat::expect_true(all(!is.na(seeded$execution_seed)))
  testthat::expect_true(all(is.finite(seeded$t_engine)))
  testthat::expect_true(all(is.finite(seeded$t_results)))
  testthat::expect_equal(seeded$t_fills_extract, rep(0, 2L))

  versions <- vapply(seeded$provenance, `[[`, character(1), "provenance_version")
  testthat::expect_identical(versions, rep("ledgr_provenance_v2", 2L))
  testthat::expect_true(all(vapply(seeded$provenance, function(row) {
    all(c(
      "snapshot_hash", "strategy_hash", "feature_set_hash", "master_seed",
      "seed_contract", "evaluation_scope"
    ) %in% names(row))
  }, logical(1))))

  testthat::expect_match(attr(seeded, "sweep_id"), "^sweep_[0-9a-f]{16}$")
  testthat::expect_identical(attr(seeded, "master_seed"), 123L)
  testthat::expect_identical(attr(seeded, "seed_contract"), "ledgr_seed_v2")
  testthat::expect_identical(attr(seeded, "evaluation_scope"), "exploratory")
  testthat::expect_identical(attr(seeded, "snapshot_id"), snapshot$snapshot_id)
  testthat::expect_match(attr(seeded, "snapshot_hash"), "^[0-9a-f]{64}$")
  testthat::expect_identical(attr(seeded, "scoring_range")$start, "2020-01-01T00:00:00Z")
  testthat::expect_identical(attr(seeded, "scoring_range")$end, "2020-01-06T00:00:00Z")
  testthat::expect_identical(attr(seeded, "universe"), "AAA")
  testthat::expect_match(attr(seeded, "strategy_hash"), "^[0-9a-f]{64}$")
  testthat::expect_identical(attr(seeded, "strategy_source_capture_method"), "deparse_function")
  testthat::expect_s3_class(attr(seeded, "strategy_preflight"), "ledgr_strategy_preflight")
  testthat::expect_type(attr(seeded, "feature_union"), "character")
  testthat::expect_match(attr(seeded, "feature_union_hash"), "^[0-9a-f]{64}$")
  testthat::expect_identical(
    attr(seeded, "feature_union_hash"),
    ledgr:::ledgr_feature_set_hash(attr(seeded, "feature_union"))
  )
  testthat::expect_s3_class(attr(seeded, "candidate_features"), "tbl_df")
  testthat::expect_true(is.list(attr(seeded, "execution_assumptions")))

  for (row in seeded$provenance) {
    testthat::expect_identical(row$snapshot_hash, attr(seeded, "snapshot_hash"))
    testthat::expect_identical(row$strategy_hash, attr(seeded, "strategy_hash"))
    testthat::expect_match(row$feature_set_hash, "^[0-9a-f]{64}$")
    testthat::expect_identical(row$master_seed, 123L)
    testthat::expect_identical(row$seed_contract, "ledgr_seed_v2")
    testthat::expect_identical(row$evaluation_scope, "exploratory")
  }
})

# ledgr-test-profile: heavy_protocol
testthat::test_that("ledgr_sweep preserves warning conditions", {
  snapshot <- ledgr_snapshot_from_df(ledgr_sweep_test_bars())
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) {
    rlang::warn("candidate warning", class = "ledgr_test_sweep_warning")
    ctx$flat()
  }
  exp <- ledgr_experiment(opening = ledgr_opening(cash = 100000), snapshot, strategy, cost_model = ledgr_cost_zero())
  grid <- ledgr_grid_named(candidate = list(strategy = list()))
  out <- ledgr_sweep(exp, grid, seed = 123L)

  testthat::expect_true(length(out$warnings[[1]]) > 0L)
  testthat::expect_s3_class(out$warnings[[1]][[1]], "ledgr_test_sweep_warning")
})

# ledgr-test-profile: heavy_protocol
testthat::test_that("ledgr_sweep_results prints a curated view", {
  snapshot <- ledgr_snapshot_from_df(ledgr_sweep_test_bars())
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) ctx$flat()
  exp <- ledgr_experiment(opening = ledgr_opening(cash = 100000), snapshot, strategy, cost_model = ledgr_cost_zero())
  grid <- ledgr_grid_named(candidate = list(strategy = list()))
  out <- ledgr_sweep(exp, grid, seed = 123L)

  printed <- utils::capture.output(print(out))
  testthat::expect_true(any(grepl("ledgr sweep", printed, fixed = TRUE)))
  testthat::expect_true(any(grepl("execution_seed", printed, fixed = TRUE)))
  testthat::expect_true(any(grepl("current table order", printed, fixed = TRUE)))
  testthat::expect_false(any(grepl("parameter-grid order", printed, fixed = TRUE)))
  testthat::expect_true(any(grepl("Hidden columns", printed, fixed = TRUE)))
  testthat::expect_true(any(grepl("win_rate", printed, fixed = TRUE)))
  testthat::expect_true(any(grepl("params", printed, fixed = TRUE)))
  testthat::expect_true(any(grepl("warnings", printed, fixed = TRUE)))
  testthat::expect_true(any(grepl("feature_fingerprints", printed, fixed = TRUE)))
  testthat::expect_true(any(grepl("provenance", printed, fixed = TRUE)))

  degraded <- out[c("candidate_id", "status")]
  degraded_print <- utils::capture.output(print(degraded))
  testthat::expect_true(any(grepl("candidate_id", degraded_print, fixed = TRUE)))
  testthat::expect_true(any(grepl("status", degraded_print, fixed = TRUE)))
})

# ledgr-test-profile: heavy_protocol
testthat::test_that("ledgr_sweep_results print footer stays neutral after reordering", {
  snapshot <- ledgr_snapshot_from_df(ledgr_sweep_test_bars())
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) ctx$flat()
  exp <- ledgr_experiment(opening = ledgr_opening(cash = 100000), snapshot, strategy, cost_model = ledgr_cost_zero())
  grid <- ledgr_grid_named(a = list(strategy = list(qty = 1)), b = list(strategy = list(qty = 2)))
  out <- ledgr_sweep(exp, grid, seed = 123L)
  reordered <- out[c(2L, 1L), ]

  printed <- utils::capture.output(print(reordered))
  testthat::expect_true(any(grepl("current table order", printed, fixed = TRUE)))
  testthat::expect_false(any(grepl("parameter-grid order", printed, fixed = TRUE)))
})

# ledgr-test-profile: heavy_protocol
testthat::test_that("ledgr_candidate selects by label or position and handles failures", {
  snapshot <- ledgr_snapshot_from_df(ledgr_sweep_test_bars())
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    targets["AAA"] <- params$qty
    targets
  }
  exp <- ledgr_experiment(opening = ledgr_opening(cash = 100000), snapshot, strategy, cost_model = ledgr_cost_zero())
  grid <- ledgr_grid_named(a = list(strategy = list(qty = 1)), b = list(strategy = list(qty = 2)))
  out <- ledgr_sweep(exp, grid, seed = 123L)

  by_label <- ledgr_candidate(out, "b")
  by_position <- ledgr_candidate(out, 1)
  testthat::expect_s3_class(by_label, "ledgr_sweep_candidate")
  testthat::expect_identical(by_label$candidate_id, "b")
  testthat::expect_identical(by_label$candidate_row, 2L)
  testthat::expect_identical(by_label$params, list(qty = 2))
  testthat::expect_identical(by_position$candidate_id, "a")
  testthat::expect_identical(by_position$candidate_row, 1L)
  testthat::expect_identical(by_position$params, list(qty = 1))
  testthat::expect_identical(by_label$sweep_meta$sweep_id, attr(out, "sweep_id"))
  testthat::expect_s3_class(by_label$selection_view, "tbl_df")
  testthat::expect_identical(nrow(by_label$selection_view), 2L)
  testthat::expect_identical(by_label$selection_view$candidate_id, c("a", "b"))
  testthat::expect_identical(by_label$selection_view$candidate_row, 1:2)

  features <- function(params) {
    if (params$n < 1) {
      rlang::abort("bad feature params", class = "ledgr_test_bad_feature")
    }
    list(ledgr_indicator("custom_close", function(window) tail(window$close, 1), requires_bars = 1))
  }
  failed_exp <- ledgr_experiment(opening = ledgr_opening(cash = 100000), snapshot, function(ctx, params) ctx$flat(), features = features, cost_model = ledgr_cost_zero())
  failed_grid <- ledgr_grid_named(good = list(strategy = list(n = 1)), bad = list(strategy = list(n = 0)))
  failed <- ledgr_sweep(failed_exp, failed_grid)
  testthat::expect_error(ledgr_candidate(failed, "bad"), class = "ledgr_failed_sweep_candidate")
  diagnostic <- ledgr_candidate(failed, "bad", allow_failed = TRUE)
  testthat::expect_identical(diagnostic$status, "FAILED")
  testthat::expect_error(
    ledgr_promote(exp, diagnostic, run_id = "should-not-promote"),
    class = "ledgr_promote_failed_candidate"
  )
})

# ledgr-test-profile: heavy_protocol
testthat::test_that("ledgr_candidate supports degraded tibble-like inputs", {
  snapshot <- ledgr_snapshot_from_df(ledgr_sweep_test_bars())
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) ctx$flat()
  exp <- ledgr_experiment(opening = ledgr_opening(cash = 100000), snapshot, strategy, cost_model = ledgr_cost_zero())
  grid <- ledgr_grid_named(candidate = list(strategy = list()))
  out <- ledgr_sweep(exp, grid, seed = 123L)
  plain <- tibble::as_tibble(out)

  candidate <- NULL
  testthat::expect_message(
    candidate <- ledgr_candidate(plain, "candidate"),
    "not a `ledgr_sweep_results` object",
    fixed = TRUE
  )
  testthat::expect_s3_class(candidate, "ledgr_sweep_candidate")
  testthat::expect_null(candidate$sweep_meta)
  testthat::expect_identical(candidate$params, list())
})

# ledgr-test-profile: heavy_protocol
testthat::test_that("sweep candidate key supports later durable materialization", {
  snapshot <- ledgr_snapshot_from_df(ledgr_sweep_test_bars(5L))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  ind <- ledgr_indicator(
    id = "custom_close",
    fn = function(window) tail(window$close, 1),
    requires_bars = 1
  )
  strategy <- function(ctx, params) {
    value <- ctx[["custom_close"]][["AAA"]]
    targets <- ctx$flat()
    if (!is.na(value) && value > params$threshold) {
      targets["AAA"] <- params$qty
    }
    targets
  }
  exp <- ledgr_experiment(opening = ledgr_opening(cash = 100000), snapshot, strategy, features = list(ind), cost_model = ledgr_cost_zero())
  grid <- ledgr_grid_named(candidate = list(strategy = list(qty = 1, threshold = 102)))

  before_counts <- ledgr_sweep_artifact_counts(snapshot)
  results <- ledgr_sweep(exp, grid, seed = 123L)
  after_sweep_counts <- ledgr_sweep_artifact_counts(snapshot)
  candidate <- ledgr_candidate(results, "candidate")
  key <- ledgr_candidate_reproduction_key(candidate)

  testthat::expect_identical(before_counts, after_sweep_counts)
  testthat::expect_s3_class(key, "ledgr_candidate_reproduction_key")
  testthat::expect_identical(key$reproduction_key_version, "ledgr_candidate_reproduction_key_v2")
  testthat::expect_identical(key$source_sweep$sweep_id, attr(results, "sweep_id"))
  testthat::expect_identical(key$candidate$candidate_id, "candidate")
  testthat::expect_identical(key$candidate$candidate_row, 1L)
  testthat::expect_identical(key$candidate$params, list(qty = 1, threshold = 102))
  testthat::expect_identical(key$candidate$feature_params, candidate$feature_params)
  testthat::expect_identical(key$snapshot$snapshot_id, snapshot$snapshot_id)
  testthat::expect_identical(key$snapshot$snapshot_hash, attr(results, "snapshot_hash"))
  testthat::expect_identical(key$selector$universe, "AAA")
  testthat::expect_identical(key$strategy$strategy_hash, attr(results, "strategy_hash"))
  testthat::expect_identical(key$features$feature_set_hash, candidate$provenance$feature_set_hash)
  testthat::expect_identical(key$features$feature_union_hash, attr(results, "feature_union_hash"))
  testthat::expect_identical(key$features$feature_fingerprints, candidate$feature_fingerprints)
  testthat::expect_identical(key$risk$risk_chain_hash, candidate$provenance$risk_chain_hash)
  testthat::expect_identical(key$risk$risk_plan_json, candidate$provenance$risk_plan_json)
  testthat::expect_true(nzchar(key$engine$feature_engine_version))
  testthat::expect_identical(key$seed$execution_seed, candidate$execution_seed)
  testthat::expect_identical(key$seed$master_seed, 123L)
  testthat::expect_identical(key$seed$seed_contract, "ledgr_seed_v2")
  testthat::expect_identical(key$metric_context$metric_context_hash, attr(results, "metric_context_hash"))

  bt <- ledgr_promote(exp, candidate, run_id = "materialized-candidate")
  on.exit(close(bt), add = TRUE)
  after_promote_counts <- ledgr_sweep_artifact_counts(snapshot)

  testthat::expect_gt(after_promote_counts[["runs"]], after_sweep_counts[["runs"]])
  testthat::expect_gt(after_promote_counts[["ledger_events"]], after_sweep_counts[["ledger_events"]])
  testthat::expect_gt(after_promote_counts[["equity_curve"]], after_sweep_counts[["equity_curve"]])
  equity <- ledgr_results(bt, "equity")
  testthat::expect_equal(equity$equity[[nrow(equity)]], results$final_equity[[1]], tolerance = 1e-12)
})

# ledgr-test-profile: heavy_protocol
testthat::test_that("ledgr_promote forwards candidate params and execution seed", {
  snapshot <- ledgr_snapshot_from_df(ledgr_sweep_test_bars(3L))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    targets["AAA"] <- params$qty
    targets
  }
  exp <- ledgr_experiment(opening = ledgr_opening(cash = 100000), snapshot, strategy, cost_model = ledgr_cost_zero())
  grid <- ledgr_grid_named(a = list(strategy = list(qty = 1)), b = list(strategy = list(qty = 2)))
  out <- ledgr_sweep(exp, grid, seed = 123L)
  candidate <- ledgr_candidate(out, "b")

  bt <- ledgr_promote(
    exp,
    candidate,
    run_id = "promoted-candidate-run",
    note = "reviewed candidate",
    require_same_snapshot = TRUE
  )
  on.exit(close(bt), add = TRUE)

  testthat::expect_s3_class(bt, "ledgr_backtest")
  testthat::expect_identical(bt$config$strategy_params, list(qty = 2))
  testthat::expect_identical(bt$config$engine$seed, candidate$execution_seed)
  testthat::expect_identical(attr(bt, "promotion_note"), "reviewed candidate")

  bt_no_note <- ledgr_promote(
    exp,
    candidate,
    run_id = "promoted-candidate-run-no-note",
    require_same_snapshot = TRUE
  )
  on.exit(close(bt_no_note), add = TRUE)
  testthat::expect_null(attr(bt_no_note, "promotion_note", exact = TRUE))
  testthat::expect_error(
    ledgr_promote(exp, candidate, run_id = "empty-note", note = ""),
    class = "ledgr_invalid_args"
  )
})

# ledgr-test-profile: heavy_protocol
testthat::test_that("ledgr_promote validates same-snapshot provenance when requested", {
  snapshot <- ledgr_snapshot_from_df(ledgr_sweep_test_bars(2L))
  other_bars <- ledgr_sweep_test_bars(2L)
  other_bars$open <- other_bars$open + 10
  other_bars$high <- other_bars$high + 10
  other_bars$low <- other_bars$low + 10
  other_bars$close <- other_bars$close + 10
  other_snapshot <- ledgr_snapshot_from_df(other_bars)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  on.exit(ledgr_snapshot_close(other_snapshot), add = TRUE)

  strategy <- function(ctx, params) ctx$flat()
  exp <- ledgr_experiment(opening = ledgr_opening(cash = 100000), snapshot, strategy, cost_model = ledgr_cost_zero())
  other_exp <- ledgr_experiment(opening = ledgr_opening(cash = 100000), other_snapshot, strategy, cost_model = ledgr_cost_zero())
  grid <- ledgr_grid_named(candidate = list(strategy = list()))
  candidate <- ledgr_candidate(ledgr_sweep(exp, grid), "candidate")

  testthat::expect_error(
    ledgr_promote(other_exp, candidate, run_id = "wrong-snapshot"),
    regexp = "require_same_snapshot = FALSE",
    class = "ledgr_candidate_snapshot_mismatch"
  )

  bt_cross <- ledgr_promote(
    other_exp,
    candidate,
    run_id = "cross-snapshot-explicit",
    require_same_snapshot = FALSE
  )
  on.exit(close(bt_cross), add = TRUE)
  testthat::expect_s3_class(bt_cross, "ledgr_backtest")

  candidate$provenance$snapshot_hash <- NULL
  testthat::expect_error(
    ledgr_promote(exp, candidate, run_id = "missing-snapshot"),
    class = "ledgr_candidate_missing_snapshot_hash"
  )
})

# ledgr-test-profile: heavy_protocol
testthat::test_that("ledgr_sweep_candidate print shows strategy name and hash when available", {
  snapshot <- ledgr_snapshot_from_df(ledgr_sweep_test_bars())
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) ctx$flat()
  attr(strategy, "name") <- "named_strategy"
  exp <- ledgr_experiment(opening = ledgr_opening(cash = 100000), snapshot, strategy, cost_model = ledgr_cost_zero())
  grid <- ledgr_grid_named(candidate = list(strategy = list()))
  candidate <- ledgr_candidate(ledgr_sweep(exp, grid, seed = 123L), "candidate")

  printed <- utils::capture.output(print(candidate))
  testthat::expect_true(any(grepl("named_strategy", printed, fixed = TRUE)))
  testthat::expect_true(any(grepl("Execution seed:", printed, fixed = TRUE)))
  testthat::expect_true(any(grepl("Feature-set hash:", printed, fixed = TRUE)))
})

# ledgr-test-profile: heavy_protocol
testthat::test_that("derived execution seeds are stable across sweep invocations", {
  snapshot <- ledgr_snapshot_from_df(ledgr_sweep_test_bars())
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    targets["AAA"] <- params$qty
    targets
  }
  exp <- ledgr_experiment(opening = ledgr_opening(cash = 100000), snapshot, strategy, cost_model = ledgr_cost_zero())
  grid <- ledgr_grid_named(a = list(strategy = list(qty = 1)), b = list(strategy = list(qty = 2)))

  one <- ledgr_sweep(exp, grid, seed = 123L)
  two <- ledgr_sweep(exp, grid, seed = 123L)

  testthat::expect_identical(one$execution_seed, two$execution_seed)
  testthat::expect_false(identical(one$execution_seed[[1]], one$execution_seed[[2]]))
  testthat::expect_identical(attr(one, "master_seed"), 123L)
  testthat::expect_false(identical(attr(one, "sweep_id"), attr(two, "sweep_id")))
})

# ledgr-test-profile: heavy_protocol
testthat::test_that("ledgr_sweep captures candidate failures and stop_on_error rethrows", {
  snapshot <- ledgr_snapshot_from_df(ledgr_sweep_test_bars())
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) ctx$flat()
  features <- function(params) {
    if (params$n < 1) {
      rlang::abort("bad feature params", class = "ledgr_test_bad_feature")
    }
    list(ledgr_indicator("custom_close", function(window) tail(window$close, 1), requires_bars = 1))
  }
  exp <- ledgr_experiment(opening = ledgr_opening(cash = 100000), snapshot, strategy, features = features, cost_model = ledgr_cost_zero())
  grid <- ledgr_grid_named(good = list(strategy = list(n = 1)), bad = list(strategy = list(n = 0)))

  out <- ledgr_sweep(exp, grid)
  testthat::expect_identical(out$status, c("DONE", "FAILED"))
  testthat::expect_identical(out$error_class[[2]], "ledgr_test_bad_feature")
  testthat::expect_error(
    ledgr_sweep(exp, grid, stop_on_error = TRUE),
    class = "ledgr_test_bad_feature"
  )
})

# ledgr-test-profile: heavy_protocol
testthat::test_that("ledgr_sweep stop_on_error preserves unique strategy error classes", {
  snapshot <- ledgr_snapshot_from_df(ledgr_sweep_test_bars())
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) {
    rlang::abort("bad strategy", class = "ledgr_test_bad_strategy")
  }
  exp <- ledgr_experiment(opening = ledgr_opening(cash = 100000), snapshot, strategy, cost_model = ledgr_cost_zero())
  grid <- ledgr_grid_named(candidate = list(strategy = list()))

  err <- testthat::capture_error(ledgr_sweep(exp, grid, stop_on_error = TRUE))
  testthat::expect_s3_class(err, "ledgr_strategy_error")
  testthat::expect_s3_class(err, "ledgr_test_bad_strategy")
  testthat::expect_identical(class(err), unique(class(err)))
})

testthat::test_that("ledgr_sweep rejects Tier 3 strategies before candidate execution", {
  snapshot <- ledgr_snapshot_from_df(ledgr_sweep_test_bars())
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  helper <- function(ctx) ctx$flat()
  strategy <- function(ctx, params) {
    helper(ctx)
  }
  exp <- ledgr_experiment(opening = ledgr_opening(cash = 100000), snapshot, strategy, cost_model = ledgr_cost_zero())
  grid <- ledgr_grid_named(candidate = list(strategy = list()))

  err <- testthat::capture_error(ledgr_sweep(exp, grid))
  testthat::expect_s3_class(err, "ledgr_strategy_preflight_error")
  testthat::expect_s3_class(err, "ledgr_strategy_tier3")
  testthat::expect_match(conditionMessage(err), "helper", fixed = TRUE)
  testthat::expect_match(conditionMessage(err), "There is no force override", fixed = TRUE)
  testthat::expect_false(grepl("by default", conditionMessage(err), fixed = TRUE))
})

# ledgr-test-profile: heavy_protocol
testthat::test_that("ledgr_sweep rejects forbidden calls and global assignment before candidate execution", {
  snapshot <- ledgr_snapshot_from_df(ledgr_sweep_test_bars(2L))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  grid <- ledgr_grid_named(candidate = list(strategy = list()))

  sys_time_strategy <- function(ctx, params) {
    Sys.time()
    ctx$flat()
  }
  sys_time_exp <- ledgr_experiment(opening = ledgr_opening(cash = 100000), snapshot, sys_time_strategy, cost_model = ledgr_cost_zero())
  sys_time_err <- testthat::capture_error(ledgr_sweep(sys_time_exp, grid))
  testthat::expect_s3_class(sys_time_err, "ledgr_strategy_preflight_error")
  testthat::expect_s3_class(sys_time_err, "ledgr_strategy_tier3")
  testthat::expect_match(conditionMessage(sys_time_err), "Sys.time", fixed = TRUE)
  testthat::expect_false(inherits(sys_time_err, "ledgr_config_non_deterministic"))

  do_call_strategy <- function(ctx, params) {
    do.call("Sys.time", list())
    ctx$flat()
  }
  do_call_exp <- ledgr_experiment(opening = ledgr_opening(cash = 100000), snapshot, do_call_strategy, cost_model = ledgr_cost_zero())
  do_call_err <- testthat::capture_error(ledgr_sweep(do_call_exp, grid))
  testthat::expect_s3_class(do_call_err, "ledgr_strategy_preflight_error")
  testthat::expect_s3_class(do_call_err, "ledgr_strategy_tier3")
  testthat::expect_match(conditionMessage(do_call_err), "do.call", fixed = TRUE)
  testthat::expect_match(conditionMessage(do_call_err), "Sys.time", fixed = TRUE)
  testthat::expect_false(inherits(do_call_err, "ledgr_config_non_deterministic"))

  attr_strategy <- function(ctx, params) {
    attr(ctx, "secret") <- 1
    ctx$flat()
  }
  attr_exp <- ledgr_experiment(opening = ledgr_opening(cash = 100000), snapshot, attr_strategy, cost_model = ledgr_cost_zero())
  attr_err <- testthat::capture_error(ledgr_sweep(attr_exp, grid))
  testthat::expect_s3_class(attr_err, "ledgr_strategy_preflight_error")
  testthat::expect_s3_class(attr_err, "ledgr_strategy_tier3")
  testthat::expect_match(conditionMessage(attr_err), "attr(ctx", fixed = TRUE)

  counter <- 0L
  global_assign_strategy <- function(ctx, params) {
    counter <<- counter + 1L
    ctx$flat()
  }
  global_assign_exp <- ledgr_experiment(opening = ledgr_opening(cash = 100000), snapshot, global_assign_strategy, cost_model = ledgr_cost_zero())
  global_assign_err <- testthat::capture_error(ledgr_sweep(global_assign_exp, grid))
  testthat::expect_s3_class(global_assign_err, "ledgr_strategy_preflight_error")
  testthat::expect_s3_class(global_assign_err, "ledgr_strategy_tier3")
  testthat::expect_match(conditionMessage(global_assign_err), "<<-", fixed = TRUE)
  testthat::expect_identical(counter, 0L)
})

# ledgr-test-profile: heavy_protocol
testthat::test_that("feature-consuming sweep strategies see the same feature values as ledgr_run", {
  snapshot <- ledgr_snapshot_from_df(ledgr_sweep_test_bars(4L))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  observed <- new.env(parent = emptyenv())
  observed$mode <- "sweep"
  observed$sweep <- numeric()
  observed$run <- numeric()
  ind <- ledgr_indicator(
    id = "custom_close",
    fn = function(window) tail(window$close, 1),
    requires_bars = 1
  )
  strategy <- function(ctx, params) {
    value <- ctx[["custom_close"]][["AAA"]]
    observed[[observed$mode]] <- c(observed[[observed$mode]], value)
    targets <- ctx$flat()
    targets["AAA"] <- if (value > 101) 1 else 0
    targets
  }
  exp <- ledgr_experiment(opening = ledgr_opening(cash = 100000), snapshot, strategy, features = list(ind), cost_model = ledgr_cost_zero())
  grid <- ledgr_grid_named(candidate = list(strategy = list()))

  out <- ledgr_sweep(exp, grid)
  observed$mode <- "run"
  bt <- ledgr_run(exp, params = list(), run_id = "feature-parity-run")
  on.exit(close(bt), add = TRUE)

  testthat::expect_identical(out$status[[1]], "DONE")
  testthat::expect_equal(observed$sweep, observed$run)
})

testthat::test_that("precomputed features validate current factory identity before sweep", {
  snapshot <- ledgr_snapshot_from_df(ledgr_sweep_test_bars(3L))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  calls <- new.env(parent = emptyenv())
  calls$n <- 0L
  features <- function(params) {
    calls$n <- calls$n + 1L
    list(ledgr_indicator("custom_close", function(window) tail(window$close, 1), requires_bars = 1))
  }
  strategy <- function(ctx, params) {
    value <- ctx[["custom_close"]][["AAA"]]
    targets <- ctx$flat()
    targets["AAA"] <- if (value > 101) 1 else 0
    targets
  }
  exp <- ledgr_experiment(opening = ledgr_opening(cash = 100000), snapshot, strategy, features = features, cost_model = ledgr_cost_zero())
  grid <- ledgr_grid_named(a = list(strategy = list()), b = list(strategy = list()))
  precomputed <- ledgr_precompute_features(exp, grid)

  calls$n <- 0L
  out <- ledgr_sweep(exp, grid, precomputed_features = precomputed)
  testthat::expect_identical(out$status, c("DONE", "DONE"))
  testthat::expect_identical(calls$n, 2L)
})

# ledgr-test-profile: review
testthat::test_that("the shared fold core has a private two-boundary interface", {
  exports <- getNamespaceExports("ledgr")
  testthat::expect_false("ledgr_execute_fold" %in% exports)
  testthat::expect_true(exists("ledgr_execute_fold", envir = asNamespace("ledgr"), inherits = FALSE))
  testthat::expect_identical(
    names(formals(ledgr:::ledgr_execute_fold)),
    c("execution", "output_handler")
  )
  testthat::expect_true(is.function(ledgr:::ledgr_run_fold))
  testthat::expect_true(is.function(ledgr:::ledgr_sweep_run_candidate))
})
