ledgr_test_duckdb_args <- if ("shared_home" %in% names(formals(duckdb::duckdb))) {
  list(shared_home = FALSE)
} else {
  list()
}
ledgr_test_duckdb_driver <- do.call(duckdb::duckdb, ledgr_test_duckdb_args)
duckdb::duckdb_shutdown(ledgr_test_duckdb_driver)
rm(ledgr_test_duckdb_args, ledgr_test_duckdb_driver)

ledgr_test_open_duckdb <- function(db_path, attempts = 50L, sleep_s = 0.05) {
  ledgr_open_duckdb_with_retry(db_path, attempts = attempts, sleep_s = sleep_s)
}

ledgr_test_close_duckdb <- function(con, drv) {
  if (!is.null(con) && DBI::dbIsValid(con)) {
    ledgr_checkpoint_duckdb(con)
  }
  suppressWarnings(try(DBI::dbDisconnect(con, shutdown = FALSE), silent = TRUE))
  suppressWarnings(try(duckdb::duckdb_shutdown(drv), silent = TRUE))
  invisible(TRUE)
}

fixture_path <- testthat::test_path("fixtures", "test_bars.R")
if (file.exists(fixture_path)) {
  source(fixture_path, local = TRUE)
}

ledgr_test_compact_bars <- function(bars = test_bars, n_pulses = 6L) {
  n_pulses <- as.integer(n_pulses)
  stopifnot(length(n_pulses) == 1L, !is.na(n_pulses), n_pulses > 0L)
  timestamps <- sort(unique(as.character(bars$ts_utc)))
  keep <- utils::head(timestamps, n_pulses)
  bars[as.character(bars$ts_utc) %in% keep, , drop = FALSE]
}

test_strategy <- function(ctx, params) {
  c(TEST_A = 100, TEST_B = 50)
}

get_test_connection <- function(db_path = tempfile(fileext = ".duckdb")) {
  opened <- ledgr_test_open_duckdb(db_path)
  con <- opened$con
  drv <- opened$drv
  attr(con, "ledgr_duckdb_drv") <- drv

  ledgr_create_schema(con)
  ledgr_validate_schema(con)

  list(con = con, drv = drv, db_path = db_path)
}

close_test_connection <- function(test_con) {
  if (is.list(test_con) && !is.null(test_con$con) && !is.null(test_con$drv)) {
    ledgr_test_close_duckdb(test_con$con, test_con$drv)
  }
  invisible(TRUE)
}

get_ledger_events <- function(con, run_id) {
  DBI::dbGetQuery(
    con,
    "
    SELECT event_seq, ts_utc, event_type, instrument_id, side, qty, price, fee, meta_json
    FROM ledger_events
    WHERE run_id = ?
    ORDER BY event_seq
    ",
    params = list(run_id)
  )
}

get_final_equity <- function(con, run_id) {
  df <- DBI::dbGetQuery(
    con,
    "
    SELECT equity
    FROM equity_curve
    WHERE run_id = ?
    ORDER BY ts_utc DESC
    LIMIT 1
    ",
    params = list(run_id)
  )
  if (nrow(df) < 1) return(NA_real_)
  as.numeric(df$equity[[1]])
}

ledgr_test_make_db <- function(instrument_ids, ts_utc, bars_df, shuffle = FALSE) {
  db_path <- tempfile(fileext = ".duckdb")

  opened <- ledgr_test_open_duckdb(db_path)
  con <- opened$con
  drv <- opened$drv
  on.exit(ledgr_test_close_duckdb(con, drv), add = TRUE)

  ledgr_create_schema(con)
  DBI::dbAppendTable(con, "instruments", data.frame(instrument_id = instrument_ids, stringsAsFactors = FALSE))

  if (isTRUE(shuffle)) {
    bars_df <- bars_df[sample.int(nrow(bars_df)), , drop = FALSE]
  }
  DBI::dbAppendTable(con, "bars", bars_df)

  db_path
}

ledgr_test_make_bars <- function(instrument_ids, ts_utc) {
  ts <- as.POSIXct(ts_utc, tz = "UTC")
  out <- do.call(
    rbind,
    lapply(seq_along(instrument_ids), function(i) {
      instrument_id <- instrument_ids[[i]]
      base <- 100 + i * 10
      n <- length(ts)
      data.frame(
        instrument_id = instrument_id,
        ts_utc = ts,
        open = base + seq_len(n) * 1,
        high = base + seq_len(n) * 1,
        low = base + seq_len(n) * 1,
        close = base + seq_len(n) * 1,
        volume = rep(1, n),
        stringsAsFactors = FALSE
      )
    })
  )
  out
}

# LDG-3166 (design note Section 5, decision 10, category 1): one next-open
# fill as a one-row typed fill group through the production batch resolver,
# with its effects from ledgr_fill_publication_deltas(). Returns the group,
# its row index and its instrument ID, the publication boundary's inputs.
ledgr_test_next_open_fill <- function(desired_qty_delta,
                                      next_bar = NULL,
                                      spread_bps = 0,
                                      commission_fixed = 0,
                                      price_round_digits = 8L,
                                      next_open_price = NULL,
                                      instrument_id = NULL,
                                      ts_utc = NULL) {
  open_label <- "`next_open_price`"
  if (!is.null(next_bar)) {
    instrument_id <- next_bar$instrument_id
    ts_utc <- next_bar$ts_utc
    next_open_price <- next_bar$open
    open_label <- "`next_bar$open`"
  }
  epoch <- if (inherits(ts_utc, "POSIXt")) {
    as.numeric(ts_utc)
  } else {
    as.numeric(as.POSIXct(ts_utc, tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ"))
  }
  # The production next-open input refusals, in the base order, with the
  # open labelled by its input form.
  ledgr:::ledgr_plan_refuse_inputs(
    as.numeric(desired_qty_delta), as.numeric(next_open_price),
    ledgr:::ledgr_plan_epoch_valid(epoch), epoch, open_label
  )
  resolver <- ledgr:::ledgr_cost_resolver_from_model(
    ledgr_cost_chain(
      ledgr_cost_spread_bps(spread_bps),
      ledgr_cost_fixed_fee(commission_fixed)
    ),
    price_round_digits = price_round_digits
  )
  side <- ledgr:::ledgr_plan_side(desired_qty_delta)
  qty <- abs(as.numeric(desired_qty_delta))
  resolved <- ledgr:::ledgr_plan_resolve(resolver, side, qty, as.numeric(next_open_price))
  effects <- ledgr:::ledgr_fill_publication_deltas(side, qty, resolved$price, resolved$fee)
  groups <- ledgr:::ledgr_plan_groups(
    1L, 1L, side, qty, resolved$price, resolved$fee, epoch, 0,
    ledgr:::ledgr_carrier_segments(1L, integer(), integer()),
    1L, effects, integer(), integer(), numeric()
  )
  fill <- ledgr:::ledgr_carrier_new(groups$fill, "fill", 1L, list(context_pos = 1L, actionable_k = 1L))
  list(fill = fill, i = 1L, instrument_id = instrument_id)
}

ledgr_test_cost_resolver <- function(spread_bps = 0,
                                     commission_fixed = 0,
                                     price_round_digits = 8L) {
  ledgr:::ledgr_cost_resolver_from_model(
    ledgr_cost_chain(
      ledgr_cost_spread_bps(spread_bps),
      ledgr_cost_fixed_fee(commission_fixed)
    ),
    price_round_digits = price_round_digits
  )
}

ledgr_test_snapshot_backed_config <- function(cfg, bars_df, snapshot_id = NULL) {
  if (is.null(snapshot_id)) {
    snapshot_id <- paste0("test_snapshot_", substr(digest::digest(list(cfg$db_path, nrow(bars_df))), 1, 12))
  }
  snapshot <- ledgr_snapshot_from_df(bars_df, db_path = cfg$db_path, snapshot_id = snapshot_id)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  cfg$data <- list(
    source = "snapshot",
    snapshot_id = snapshot$snapshot_id,
    snapshot_db_path = snapshot$db_path,
    snapshot_hash = ledgr_snapshot_info(snapshot)$snapshot_hash[[1L]]
  )
  cfg$identity_rule_version <- 5L
  ledgr_test_modernize_config(cfg)
}

ledgr_test_store_tables <- function(con) {
  as.character(DBI::dbGetQuery(
    con,
    "SELECT table_name FROM information_schema.tables WHERE table_schema = 'main'"
  )$table_name)
}

ledgr_test_store_columns <- function(con, table_name) {
  as.character(DBI::dbGetQuery(
    con,
    paste(
      "SELECT column_name FROM information_schema.columns",
      "WHERE table_schema = 'main' AND table_name = ?",
      "ORDER BY ordinal_position"
    ),
    params = list(table_name)
  )$column_name)
}

ledgr_test_modernize_config <- function(cfg, cost_model = ledgr_cost_zero()) {
  cfg$fill_model <- NULL
  cfg$timing_model <- ledgr_timing_next_open()
  cfg$cost_model <- list(
    cost_model_hash = ledgr:::ledgr_cost_model_hash(cost_model),
    cost_plan_json = ledgr:::ledgr_cost_plan_json(cost_model)
  )
  cfg$risk_chain <- ledgr:::ledgr_config_risk_identity()
  cfg$corporate_actions <- ledgr:::ledgr_corporate_action_policy_identity(
    ledgr_corporate_actions_research()
  )
  cfg$identity_rule_version <- 5L
  cfg$history <- ledgr:::ledgr_history_policy_identity(ledgr_history_policy())
  # A seeded configuration names its pulse-seed rule (LDG-3159).
  if (is.list(cfg$engine) && !is.null(cfg$engine$seed)) {
    cfg$engine$pulse_seed_rule <- ledgr:::ledgr_pulse_seed_rule_version
  }
  if (is.list(cfg$strategy) && !is.list(cfg$strategy$provenance)) {
    strategy <- ledgr:::ledgr_strategy_spec(cfg$strategy)
    cfg$strategy$id <- strategy$id
    cfg$strategy$params <- strategy$params
    cfg$strategy$provenance <- strategy$provenance
  }
  if (is.null(cfg$strategy_params_json) || is.null(cfg$strategy_params_hash)) {
    strategy_params <- ledgr:::ledgr_strategy_params_info(
      cfg$strategy_params %||% list()
    )
    cfg$strategy_params <- strategy_params$value
    cfg$strategy_params_json <- strategy_params$json
    cfg$strategy_params_hash <- strategy_params$hash
  }
  if (is.list(cfg$data) && is.null(cfg$data$snapshot_hash) &&
      is.character(cfg$data$snapshot_id) &&
      length(cfg$data$snapshot_id) == 1L &&
      !is.na(cfg$data$snapshot_id)) {
    path <- cfg$data$snapshot_db_path %||% cfg$db_path
    if (is.character(path) && length(path) == 1L && file.exists(path)) {
      opened <- ledgr:::ledgr_run_store_open(path)
      on.exit(ledgr:::ledgr_run_store_close(opened), add = TRUE)
      row <- DBI::dbGetQuery(
        opened$con,
        "SELECT snapshot_hash FROM snapshots WHERE snapshot_id = ?",
        params = list(cfg$data$snapshot_id)
      )
      if (nrow(row) == 1L) cfg$data$snapshot_hash <- row$snapshot_hash[[1L]]
    }
  }
  cfg
}

ledgr_test_norm_ts <- function(x) {
  format(as.POSIXct(x, tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
}

ledgr_test_snapshot_for_run <- function(db_path, bt) {
  snapshot_id <- bt$config$data$snapshot_id
  if (!is.character(snapshot_id) || length(snapshot_id) != 1L || is.na(snapshot_id) || !nzchar(snapshot_id)) {
    rlang::abort("Test backtest config does not contain a snapshot id.", class = "ledgr_test_error")
  }
  ledgr_snapshot_open(db_path, snapshot_id)
}

ledgr_test_fetch_ledger_core <- function(con, run_id) {
  df <- DBI::dbGetQuery(
    con,
    "
    SELECT ts_utc, instrument_id, side, qty, price, fee, meta_json, event_seq
    FROM ledger_events
    WHERE run_id = ?
    ORDER BY ts_utc, instrument_id, side, qty, price, fee, meta_json, event_seq
    ",
    params = list(run_id)
  )
  if (nrow(df) == 0) return(df)
  df$ts_utc <- ledgr_test_norm_ts(df$ts_utc)
  df
}

ledgr_test_fetch_equity_curve_core <- function(con, run_id) {
  df <- DBI::dbGetQuery(
    con,
    "
    SELECT ts_utc, cash, positions_value, equity, realized_pnl, unrealized_pnl
    FROM equity_curve
    WHERE run_id = ?
    ORDER BY ts_utc
    ",
    params = list(run_id)
  )
  if (nrow(df) == 0) return(df)
  df$ts_utc <- ledgr_test_norm_ts(df$ts_utc)
  df
}

# covr instruments ledgr in every process that loads it, including mirai worker
# daemons, and stopping a daemon can cut off its coverage trace and break the
# coverage run. Coverage runs therefore start no workers; the ordinary runs
# cover the worker paths.
ledgr_test_in_coverage <- function() {
  requireNamespace("covr", quietly = TRUE) && covr::in_covr()
}

# Fresh R processes inherit covr's instrumented package loader. On Windows,
# their namespace finalizers can leave truncated trace files when the process
# exits, which makes the parent collector fail before it can calculate
# coverage. Keep the subprocess assertion live, but isolate its unusable trace
# from the parent trace directory. Ordinary test runs are unchanged.
ledgr_test_system2 <- function(command, args = character(), ...) {
  run <- function() system2(command, args, ...)
  if (!ledgr_test_in_coverage()) return(run())

  child_coverage <- tempfile("ledgr-covr-child-")
  dir.create(child_coverage)
  on.exit(unlink(child_coverage, recursive = TRUE, force = TRUE), add = TRUE)
  withr::with_envvar(c(COVERAGE_DIR = child_coverage), run())
}

ledgr_test_skip_workers_in_coverage <- function() {
  testthat::skip_if(ledgr_test_in_coverage(), "Coverage runs start no worker daemons.")
}
ledgr_test_run <- function(snapshot = NULL,
                           strategy,
                           universe = NULL,
                           start = NULL,
                           end = NULL,
                           initial_cash = 100000,
                           strategy_params = list(),
                           features = list(),
                           timing_model = ledgr_timing_next_open(),
                           cost_model,
                           risk_chain = ledgr_risk_none(),
                           execution_mode = "audit_log",
                           checkpoint_every = 10000L,
                           db_path = NULL,
                           control = list(),
                           run_id = NULL,
                           data = NULL,
                           corporate_action_policy = ledgr_corporate_actions_research(),
                           ...) {
  dots <- list(...)
  if (length(dots) > 0L) {
    rlang::abort("Unsupported test setup argument.", class = "ledgr_invalid_args")
  }
  if (!is.null(snapshot) && !is.null(data)) {
    rlang::abort("Provide exactly one of `snapshot` and `data`.", class = "ledgr_invalid_args")
  }
  source <- snapshot %||% data
  if (is.data.frame(source)) {
    source <- ledgr_snapshot_from_df(source, db_path = db_path)
  }
  if (!inherits(source, "ledgr_snapshot")) {
    rlang::abort("Test setup requires a snapshot or data frame.", class = "ledgr_invalid_args")
  }
  if (is.null(universe)) {
    opened <- ledgr_snapshot_hold(source)
    on.exit(opened(), add = TRUE)
    universe <- as.character(DBI::dbGetQuery(
      ledgr:::get_connection(source),
      "SELECT instrument_id FROM snapshot_instruments WHERE snapshot_id = ? ORDER BY instrument_id",
      params = list(source$snapshot_id)
    )$instrument_id)
  }
  exp <- ledgr_experiment(
    snapshot = source,
    universe = universe,
    strategy = strategy,
    opening = ledgr_opening(cash = initial_cash, date = start),
    features = features,
    timing_model = timing_model,
    cost_model = cost_model,
    risk_chain = risk_chain,
    execution_mode = control$execution_mode %||% execution_mode,
    corporate_action_policy = corporate_action_policy
  )
  # Test-only engine controls exercise telemetry and early-exit paths without
  # adding those diagnostics knobs to the public experiment surface.
  exp$control <- control
  if (!is.null(end)) {
    window <- ledgr_experiment_window(
      exp,
      start_utc = start %||% source$metadata$start_date,
      end_utc = end
    )
    return(ledgr_run_window(exp, params = strategy_params, window = window, run_id = run_id))
  }
  ledgr_run(exp, params = strategy_params, run_id = run_id)
}
