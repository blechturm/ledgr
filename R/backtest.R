#' Run a backtest (v0.1.2)
#'
#' Thin wrapper around the canonical engine entrypoint `ledgr_run()`.
#'
#' @param snapshot A `ledgr_snapshot` object.
#' @param strategy Strategy function or object with `$on_pulse(ctx)` method.
#' @param universe Character vector of instrument IDs.
#' @param start Start timestamp (NULL = snapshot start).
#' @param end End timestamp (NULL = snapshot end).
#' @param initial_cash Starting capital.
#' @param features List of ledgr indicator definitions (optional).
#' @param fill_model Fill model config (NULL = instant fill).
#' @param db_path Database path for the run ledger (NULL = snapshot DB).
#' @param run_id Optional run identifier to resume or reuse.
#' @return A `ledgr_backtest` object.
#' @export
ledgr_backtest <- function(snapshot,
                           strategy,
                           universe,
                           start = NULL,
                           end = NULL,
                           initial_cash = 100000,
                           features = list(),
                           fill_model = NULL,
                           db_path = NULL,
                           run_id = NULL) {
  if (!inherits(snapshot, "ledgr_snapshot")) {
    rlang::abort(
      "'snapshot' must be a ledgr_snapshot object. Create with: ledgr_snapshot_from_df() or ledgr_snapshot_from_yahoo().",
      class = "ledgr_invalid_args"
    )
  }

  if (!is.character(universe) || length(universe) < 1 || anyNA(universe) || any(!nzchar(universe))) {
    rlang::abort("'universe' must contain at least one instrument.", class = "ledgr_invalid_args")
  }
  if (anyDuplicated(universe)) {
    rlang::abort("'universe' must not contain duplicates.", class = "ledgr_invalid_args")
  }

  if (is.null(db_path)) db_path <- snapshot$db_path
  if (!is.character(db_path) || length(db_path) != 1 || is.na(db_path) || !nzchar(db_path)) {
    rlang::abort("`db_path` must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }

  if (!is.null(run_id)) {
    if (!is.character(run_id) || length(run_id) != 1 || is.na(run_id) || !nzchar(run_id)) {
      rlang::abort("`run_id` must be NULL or a non-empty character scalar.", class = "ledgr_invalid_args")
    }
  }

  if (!is.list(features)) {
    rlang::abort("`features` must be a list.", class = "ledgr_invalid_args")
  }

  if (is.null(start)) start <- snapshot$metadata$start_date
  if (is.null(end)) end <- snapshot$metadata$end_date
  if (is.null(start) || is.null(end) || anyNA(c(start, end))) {
    rlang::abort("`start` and `end` must be provided or available in snapshot metadata.", class = "ledgr_invalid_args")
  }

  # Validate universe against snapshot instruments.
  con_snap <- get_connection(snapshot)
  inst <- DBI::dbGetQuery(
    con_snap,
    "SELECT instrument_id FROM snapshot_instruments WHERE snapshot_id = ?",
    params = list(snapshot$snapshot_id)
  )$instrument_id
  missing <- setdiff(universe, inst)
  if (length(missing) > 0) {
    rlang::abort(
      sprintf(
        "Instruments not found in snapshot: %s. Available instruments: %s",
        paste(missing, collapse = ", "),
        paste(inst, collapse = ", ")
      ),
      class = "ledgr_invalid_args"
    )
  }

  config <- ledgr_config(
    snapshot = snapshot,
    universe = universe,
    strategy = strategy,
    backtest = ledgr_backtest_config(start = start, end = end, initial_cash = initial_cash),
    features = features,
    fill_model = fill_model,
    db_path = db_path,
    run_id = run_id
  )

  result <- ledgr_run(config)

  new_ledgr_backtest(
    run_id = result$run_id,
    db_path = result$db_path,
    config = config
  )
}

ledgr_run <- function(config, run_id = NULL) {
  ledgr_backtest_run(config = config, run_id = run_id)
}

new_ledgr_backtest <- function(run_id, db_path, config) {
  if (!is.character(run_id) || length(run_id) != 1 || is.na(run_id) || !nzchar(run_id)) {
    rlang::abort("`run_id` must be a non-empty character scalar.", class = "ledgr_invalid_backtest")
  }
  if (!is.character(db_path) || length(db_path) != 1 || is.na(db_path) || !nzchar(db_path)) {
    rlang::abort("`db_path` must be a non-empty character scalar.", class = "ledgr_invalid_backtest")
  }
  if (!is.list(config)) {
    rlang::abort("`config` must be a list.", class = "ledgr_invalid_backtest")
  }

  state <- new.env(parent = emptyenv())
  state$con <- NULL
  state$drv <- NULL

  structure(
    list(
      run_id = run_id,
      db_path = db_path,
      config = config,
      .state = state
    ),
    class = c("ledgr_backtest", "ledgr_run")
  )
}

backtest_state <- function(bt) {
  state <- bt$.state
  if (is.null(state) || !is.environment(state)) {
    state <- new.env(parent = emptyenv())
    state$con <- NULL
    state$drv <- NULL
    bt$.state <- state
  }
  state
}

ledgr_backtest_open <- function(bt) {
  if (!inherits(bt, "ledgr_backtest")) {
    rlang::abort("`bt` must be a ledgr_backtest object.", class = "ledgr_invalid_backtest")
  }

  state <- backtest_state(bt)
  con <- state$con
  if (!is.null(con) && DBI::dbIsValid(con)) {
    return(list(con = con, opened_new = FALSE))
  }

  opened <- ledgr_open_duckdb_with_retry(bt$db_path)
  state$con <- opened$con
  state$drv <- opened$drv
  attr(state$con, "ledgr_duckdb_drv") <- opened$drv

  list(con = state$con, opened_new = TRUE)
}

ledgr_backtest_config <- function(start, end, initial_cash = 100000) {
  start_iso <- iso_utc(start)
  end_iso <- iso_utc(end)

  start_ts <- as.POSIXct(start_iso, tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ")
  end_ts <- as.POSIXct(end_iso, tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ")
  if (is.na(start_ts) || is.na(end_ts)) {
    rlang::abort("`start` and `end` must be parseable timestamps.", class = "ledgr_invalid_args")
  }
  if (start_ts > end_ts) {
    rlang::abort("`start` must be before or equal to `end`.", class = "ledgr_invalid_args")
  }
  if (!is.numeric(initial_cash) || length(initial_cash) != 1 || is.na(initial_cash) || !is.finite(initial_cash)) {
    rlang::abort("`initial_cash` must be a finite numeric scalar.", class = "ledgr_invalid_args")
  }

  list(start = start_iso, end = end_iso, initial_cash = as.numeric(initial_cash))
}

ledgr_fill_model_instant <- function() {
  list(type = "next_open", spread_bps = 0, commission_fixed = 0)
}

ledgr_strategy_spec <- function(strategy) {
  if (is.function(strategy)) {
    key <- ledgr_register_strategy_fn(strategy)
    return(list(id = "functional", params = list(strategy_key = key)))
  }

  if (is.list(strategy) && is.character(strategy$id)) {
    params <- strategy$params
    if (is.null(params)) params <- list()
    if (!is.list(params)) {
      rlang::abort("strategy.params must be a list.", class = "ledgr_invalid_args")
    }
    return(list(id = strategy$id, params = params))
  }

  if (!is.null(strategy) && is.function(strategy$on_pulse)) {
    fn <- function(ctx) strategy$on_pulse(ctx)
    key <- ledgr_register_strategy_fn(fn)
    return(list(id = "functional", params = list(strategy_key = key)))
  }

  rlang::abort(
    "`strategy` must be a function or an object with $on_pulse(ctx).",
    class = "ledgr_invalid_args"
  )
}

ledgr_config <- function(snapshot,
                         universe,
                         strategy,
                         backtest,
                         features = list(),
                         fill_model = NULL,
                         db_path = NULL,
                         run_id = NULL) {
  if (!inherits(snapshot, "ledgr_snapshot")) {
    rlang::abort("`snapshot` must be a ledgr_snapshot object.", class = "ledgr_invalid_args")
  }
  if (!is.character(universe) || length(universe) < 1 || anyNA(universe) || any(!nzchar(universe))) {
    rlang::abort("`universe` must be a non-empty character vector.", class = "ledgr_invalid_args")
  }
  if (!is.list(backtest)) {
    rlang::abort("`backtest` must be a list from ledgr_backtest_config().", class = "ledgr_invalid_args")
  }
  if (is.null(db_path)) db_path <- snapshot$db_path
  if (!is.character(db_path) || length(db_path) != 1 || is.na(db_path) || !nzchar(db_path)) {
    rlang::abort("`db_path` must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }
  if (!is.list(features)) {
    rlang::abort("`features` must be a list.", class = "ledgr_invalid_args")
  }

  if (is.null(fill_model)) fill_model <- ledgr_fill_model_instant()
  if (!is.list(fill_model)) {
    rlang::abort("`fill_model` must be a list.", class = "ledgr_invalid_args")
  }

  strat <- ledgr_strategy_spec(strategy)

  config <- list(
    db_path = db_path,
    engine = list(seed = 1L, tz = "UTC"),
    universe = list(instrument_ids = universe),
    backtest = list(
      start_ts_utc = backtest$start,
      end_ts_utc = backtest$end,
      pulse = "EOD",
      initial_cash = backtest$initial_cash
    ),
    fill_model = list(
      type = fill_model$type,
      spread_bps = fill_model$spread_bps,
      commission_fixed = fill_model$commission_fixed
    ),
    features = if (length(features) > 0) {
      list(enabled = TRUE, defs = features)
    } else {
      list(enabled = FALSE, defs = list())
    },
    strategy = list(
      id = strat$id,
      params = strat$params
    ),
    data = list(
      source = "snapshot",
      snapshot_id = snapshot$snapshot_id
    )
  )

  if (!is.null(run_id)) config$run_id <- run_id

  config
}

ledgr_backtest_equity <- function(con, run_id) {
  DBI::dbGetQuery(
    con,
    "
    SELECT ts_utc, equity, cash, positions_value
    FROM equity_curve
    WHERE run_id = ?
    ORDER BY ts_utc
    ",
    params = list(run_id)
  )
}

ledgr_extract_fills_internal <- function(bt) {
  con <- get_connection(bt)
  rows <- DBI::dbGetQuery(
    con,
    "
    SELECT ts_utc, instrument_id, side, qty, price, fee, meta_json
    FROM ledger_events
    WHERE run_id = ? AND event_type = 'FILL'
    ORDER BY event_seq
    ",
    params = list(bt$run_id)
  )

  if (nrow(rows) == 0) {
    return(tibble::as_tibble(rows))
  }

  realized <- vapply(
    rows$meta_json,
    function(x) {
      if (is.null(x) || (is.atomic(x) && length(x) == 1 && is.na(x))) return(NA_real_)
      meta <- jsonlite::fromJSON(x, simplifyVector = TRUE)
      if (is.null(meta$realized_pnl)) return(NA_real_)
      as.numeric(meta$realized_pnl)
    },
    numeric(1)
  )

  out <- rows[, c("ts_utc", "instrument_id", "side", "qty", "price", "fee"), drop = FALSE]
  out$realized_pnl <- realized
  tibble::as_tibble(out)
}

compute_annualized_return <- function(equity) {
  if (!is.data.frame(equity) || nrow(equity) < 2) return(NA_real_)

  days <- as.numeric(difftime(
    as.Date(equity$ts_utc[[nrow(equity)]]),
    as.Date(equity$ts_utc[[1]]),
    units = "days"
  ))
  if (!is.finite(days) || days <= 0) return(NA_real_)
  years <- days / 365
  if (years <= 0) return(NA_real_)

  total_return <- (equity$equity[[nrow(equity)]] / equity$equity[[1]]) - 1
  (1 + total_return)^(1 / years) - 1
}

compute_max_drawdown <- function(equity_values) {
  if (length(equity_values) < 1) return(NA_real_)
  running_max <- cummax(equity_values)
  drawdown <- (equity_values / running_max) - 1
  min(drawdown, na.rm = TRUE)
}

compute_time_in_market <- function(equity) {
  if (!is.data.frame(equity) || nrow(equity) == 0) return(NA_real_)
  mean(abs(equity$positions_value) > 1e-6)
}

ledgr_compute_metrics_internal <- function(bt, metrics = "standard") {
  if (!identical(metrics, "standard")) {
    rlang::abort(
      "Only metrics='standard' supported in v0.1.2. Advanced metrics are deferred to v0.1.3.",
      class = "ledgr_invalid_args"
    )
  }

  con <- get_connection(bt)
  equity <- ledgr_backtest_equity(con, bt$run_id)
  equity$equity <- as.numeric(equity$equity)
  equity$positions_value <- as.numeric(equity$positions_value)

  fills <- ledgr_extract_fills_internal(bt)

  returns <- numeric(0)
  if (nrow(equity) > 1) {
    prev <- equity$equity[-nrow(equity)]
    cur <- equity$equity[-1]
    returns <- (cur / prev) - 1
  }

  list(
    total_return = if (nrow(equity) > 0) (equity$equity[[nrow(equity)]] / equity$equity[[1]]) - 1 else NA_real_,
    annualized_return = compute_annualized_return(equity),
    volatility = if (length(returns) > 1) stats::sd(returns, na.rm = TRUE) * sqrt(252) else NA_real_,
    max_drawdown = compute_max_drawdown(equity$equity),
    n_trades = nrow(fills),
    win_rate = if (nrow(fills) > 0) sum(fills$realized_pnl > 0, na.rm = TRUE) / nrow(fills) else NA_real_,
    avg_trade = if (nrow(fills) > 0) mean(fills$realized_pnl, na.rm = TRUE) else NA_real_,
    time_in_market = compute_time_in_market(equity)
  )
}

#' @export
print.ledgr_backtest <- function(x, ...) {
  if (!inherits(x, "ledgr_backtest")) {
    rlang::abort("`x` must be a ledgr_backtest object.", class = "ledgr_invalid_backtest")
  }

  cfg <- x$config
  universe <- cfg$universe$instrument_ids
  start <- cfg$backtest$start_ts_utc
  end <- cfg$backtest$end_ts_utc
  initial_cash <- cfg$backtest$initial_cash

  con <- get_connection(x)
  final_equity <- DBI::dbGetQuery(
    con,
    "
    SELECT equity
    FROM equity_curve
    WHERE run_id = ?
    ORDER BY ts_utc DESC
    LIMIT 1
    ",
    params = list(x$run_id)
  )$equity[[1]]
  final_equity <- as.numeric(final_equity)

  pnl <- final_equity - initial_cash
  pnl_pct <- (pnl / initial_cash) * 100

  cat("ledgr Backtest Results\n")
  cat("======================\n\n")
  cat("Run ID:        ", x$run_id, "\n")
  cat("Universe:      ", paste(universe, collapse = ", "), "\n")
  cat("Date Range:    ", start, "to", end, "\n")
  cat("Initial Cash:  ", sprintf("$%.2f", initial_cash), "\n")
  cat("Final Equity:  ", sprintf("$%.2f", final_equity), "\n")
  cat("P&L:           ", sprintf("$%.2f (%.2f%%)", pnl, pnl_pct), "\n\n")
  cat("Use summary(bt) for detailed metrics\n")
  cat("Use plot(bt) for equity curve visualization\n")

  invisible(x)
}

#' @export
summary.ledgr_backtest <- function(object, metrics = "standard", ...) {
  if (!inherits(object, "ledgr_backtest")) {
    rlang::abort("`object` must be a ledgr_backtest object.", class = "ledgr_invalid_backtest")
  }

  computed <- ledgr_compute_metrics_internal(object, metrics = metrics)

  cat("ledgr Backtest Summary\n")
  cat("======================\n\n")

  cat("Performance Metrics:\n")
  cat(sprintf("  Total Return:        %.2f%%\n", computed$total_return * 100))
  cat(sprintf("  Annualized Return:   %.2f%%\n", computed$annualized_return * 100))
  cat(sprintf("  Max Drawdown:        %.2f%%\n", computed$max_drawdown * 100))

  cat("\nRisk Metrics:\n")
  cat(sprintf("  Volatility (annual): %.2f%%\n", computed$volatility * 100))

  cat("\nTrade Statistics:\n")
  cat(sprintf("  Total Trades:        %d\n", computed$n_trades))
  if (computed$n_trades > 0) {
    cat(sprintf("  Win Rate:            %.2f%%\n", computed$win_rate * 100))
    cat(sprintf("  Avg Trade:           $%.2f\n", computed$avg_trade))
  } else {
    cat("  Win Rate:            N/A (no trades)\n")
    cat("  Avg Trade:           N/A (no trades)\n")
  }

  cat("\nExposure:\n")
  cat(sprintf("  Time in Market:      %.2f%%\n", computed$time_in_market * 100))

  invisible(object)
}

#' @export
as_tibble.ledgr_backtest <- function(x, what = "equity", ...) {
  if (!inherits(x, "ledgr_backtest")) {
    rlang::abort("`x` must be a ledgr_backtest object.", class = "ledgr_invalid_backtest")
  }

  what <- match.arg(what, c("equity", "fills", "ledger"))
  con <- get_connection(x)

  switch(
    what,
    equity = {
      eq <- ledgr_backtest_equity(con, x$run_id)
      eq <- tibble::as_tibble(eq)
      if (nrow(eq) > 0) {
        eq$running_max <- cummax(eq$equity)
        eq$drawdown <- (eq$equity / eq$running_max) - 1
      }
      eq
    },
    fills = ledgr_extract_fills_internal(x),
    ledger = tibble::as_tibble(
      DBI::dbGetQuery(
        con,
        "
        SELECT *
        FROM ledger_events
        WHERE run_id = ?
        ORDER BY event_seq
        ",
        params = list(x$run_id)
      )
    )
  )
}
