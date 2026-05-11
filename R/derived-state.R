ledgr_reconstruct_positions <- function(con, run_id) {
  if (!DBI::dbIsValid(con)) {
    rlang::abort("`con` must be a valid DBI connection.", class = "ledgr_invalid_con")
  }
  if (!is.character(run_id) || length(run_id) != 1 || is.na(run_id) || !nzchar(run_id)) {
    rlang::abort("`run_id` must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }

  rows <- DBI::dbGetQuery(
    con,
    "
    SELECT instrument_id, meta_json
    FROM ledger_events
    WHERE run_id = ?
    ORDER BY event_seq
    ",
    params = list(run_id)
  )

  pos <- numeric(0)
  if (nrow(rows) == 0) {
    return(pos)
  }

  for (i in seq_len(nrow(rows))) {
    instrument_id <- rows$instrument_id[[i]]
    if (is.na(instrument_id) || !nzchar(instrument_id)) next

    meta <- jsonlite::fromJSON(rows$meta_json[[i]], simplifyVector = FALSE)
    delta <- meta$position_delta
    if (!is.numeric(delta) || length(delta) != 1 || is.na(delta) || !is.finite(delta)) {
      rlang::abort("ledger_events.meta_json must include a finite numeric scalar `position_delta`.", class = "ledgr_invalid_ledger_meta")
    }

    if (is.null(names(pos)) || !(instrument_id %in% names(pos))) pos[instrument_id] <- 0
    pos[instrument_id] <- pos[instrument_id] + as.numeric(delta)
  }

  pos
}

ledgr_reconstruct_cash <- function(con, run_id, initial_cash) {
  if (!DBI::dbIsValid(con)) {
    rlang::abort("`con` must be a valid DBI connection.", class = "ledgr_invalid_con")
  }
  if (!is.character(run_id) || length(run_id) != 1 || is.na(run_id) || !nzchar(run_id)) {
    rlang::abort("`run_id` must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }
  if (!is.numeric(initial_cash) || length(initial_cash) != 1 || is.na(initial_cash) || !is.finite(initial_cash)) {
    rlang::abort("`initial_cash` must be a finite numeric scalar.", class = "ledgr_invalid_args")
  }

  rows <- DBI::dbGetQuery(
    con,
    "
    SELECT meta_json
    FROM ledger_events
    WHERE run_id = ?
    ORDER BY event_seq
    ",
    params = list(run_id)
  )

  cash <- as.numeric(initial_cash)
  if (nrow(rows) == 0) {
    return(cash)
  }

  for (i in seq_len(nrow(rows))) {
    meta <- jsonlite::fromJSON(rows$meta_json[[i]], simplifyVector = FALSE)
    delta <- meta$cash_delta
    if (!is.numeric(delta) || length(delta) != 1 || is.na(delta) || !is.finite(delta)) {
      rlang::abort("ledger_events.meta_json must include a finite numeric scalar `cash_delta`.", class = "ledgr_invalid_ledger_meta")
    }
    cash <- cash + as.numeric(delta)
  }

  cash
}

ledgr_rebuild_derived_state <- function(con, run_id, initial_cash, use_transaction = TRUE) {
  if (!DBI::dbIsValid(con)) {
    rlang::abort("`con` must be a valid DBI connection.", class = "ledgr_invalid_con")
  }
  if (!is.character(run_id) || length(run_id) != 1 || is.na(run_id) || !nzchar(run_id)) {
    rlang::abort("`run_id` must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }
  if (!is.numeric(initial_cash) || length(initial_cash) != 1 || is.na(initial_cash) || !is.finite(initial_cash)) {
    rlang::abort("`initial_cash` must be a finite numeric scalar.", class = "ledgr_invalid_args")
  }

  run_cfg <- DBI::dbGetQuery(con, "SELECT config_json FROM runs WHERE run_id = ?", params = list(run_id))
  if (nrow(run_cfg) != 1) {
    rlang::abort(sprintf("run_id not found in runs table: %s", run_id), class = "ledgr_invalid_args")
  }
  if (is.null(run_cfg$config_json[[1]]) || is.na(run_cfg$config_json[[1]]) || !nzchar(run_cfg$config_json[[1]])) {
    rlang::abort("runs.config_json is required for deterministic derived-state reconstruction.", class = "ledgr_invalid_run")
  }

  cfg <- jsonlite::fromJSON(run_cfg$config_json[[1]], simplifyVector = TRUE, simplifyDataFrame = FALSE, simplifyMatrix = FALSE)
  instrument_ids <- cfg$universe$instrument_ids
  start_ts_utc <- cfg$backtest$start_ts_utc
  end_ts_utc <- cfg$backtest$end_ts_utc
  if (!is.character(instrument_ids) || length(instrument_ids) < 1 || anyNA(instrument_ids) || any(!nzchar(instrument_ids))) {
    rlang::abort("runs.config_json must include universe.instrument_ids as a non-empty character vector.", class = "ledgr_invalid_run")
  }

  if (!is.null(cfg$data) && is.list(cfg$data) && identical(cfg$data$source, "snapshot")) {
    snapshot_id <- cfg$data$snapshot_id
    if (!is.character(snapshot_id) || length(snapshot_id) != 1 || is.na(snapshot_id) || !nzchar(snapshot_id)) {
      rlang::abort("runs.config_json must include data.snapshot_id for snapshot-backed reconstruction.", class = "ledgr_invalid_run")
    }
    run_db_path <- cfg$db_path
    if (!is.character(run_db_path) || length(run_db_path) != 1 || is.na(run_db_path) || !nzchar(run_db_path)) {
      rlang::abort("runs.config_json must include db_path for snapshot-backed reconstruction.", class = "ledgr_invalid_run")
    }
    snapshot_db_path <- ledgr_snapshot_db_path_from_config(cfg, run_db_path)
    ledgr_prepare_snapshot_source_tables(con, snapshot_db_path, run_db_path)

    snap <- DBI::dbGetQuery(
      con,
      "SELECT status, snapshot_hash FROM snapshots WHERE snapshot_id = ?",
      params = list(snapshot_id)
    )
    if (nrow(snap) != 1) {
      rlang::abort(sprintf("Snapshot not found for reconstruction: %s", snapshot_id), class = "LEDGR_SNAPSHOT_NOT_FOUND")
    }
    if (!identical(snap$status[[1]], "SEALED")) {
      rlang::abort(
        sprintf("LEDGR_SNAPSHOT_NOT_SEALED: snapshot status must be SEALED for reconstruction (got %s).", snap$status[[1]]),
        class = "LEDGR_SNAPSHOT_NOT_SEALED"
      )
    }
    stored_snapshot_hash <- snap$snapshot_hash[[1]]
    if (!is.character(stored_snapshot_hash) || length(stored_snapshot_hash) != 1 || is.na(stored_snapshot_hash) || !nzchar(stored_snapshot_hash)) {
      rlang::abort("LEDGR_SNAPSHOT_NOT_SEALED: SEALED snapshot is missing snapshot_hash.", class = "LEDGR_SNAPSHOT_NOT_SEALED")
    }
    recomputed <- ledgr_snapshot_hash(con, snapshot_id)
    if (!identical(recomputed, stored_snapshot_hash)) {
      rlang::abort("LEDGR_SNAPSHOT_CORRUPTED: stored snapshot_hash does not match recomputed hash.", class = "LEDGR_SNAPSHOT_CORRUPTED")
    }

    ledgr_prepare_snapshot_runtime_views(con, snapshot_id, instrument_ids, start_ts_utc, end_ts_utc)
  }

  pulses <- ledgr_pulse_timestamps(con, instrument_ids, start_ts_utc, end_ts_utc)

  events <- DBI::dbGetQuery(
    con,
    "
    SELECT
      event_seq,
      ts_utc,
      event_type,
      instrument_id,
      side,
      qty,
      price,
      fee,
      meta_json
    FROM ledger_events
    WHERE run_id = ?
    ORDER BY event_seq
    ",
    params = list(run_id)
  )

  start_iso <- ledgr_normalize_ts_utc(start_ts_utc)
  end_iso <- ledgr_normalize_ts_utc(end_ts_utc)
  start_ts <- as.POSIXct(start_iso, tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ")
  end_ts <- as.POSIXct(end_iso, tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ")
  if (is.na(start_ts) || is.na(end_ts)) {
    rlang::abort("runs.config_json includes invalid backtest timestamps.", class = "ledgr_invalid_run")
  }

  ids_sql <- paste(DBI::dbQuoteString(con, instrument_ids), collapse = ", ")
  bars_close <- DBI::dbGetQuery(
    con,
    paste0(
      "SELECT instrument_id, ts_utc, close ",
      "FROM bars ",
      "WHERE instrument_id IN (", ids_sql, ") ",
      "AND ts_utc >= ? AND ts_utc <= ? ",
      "ORDER BY ts_utc, instrument_id"
    ),
    params = list(start_ts, end_ts)
  )

  if (nrow(bars_close) == 0) {
    rlang::abort("No bars found for pulse calendar during derived-state reconstruction.", class = "ledgr_missing_bars")
  }

  close_map <- new.env(parent = emptyenv())
  for (i in seq_along(pulses)) {
    t <- pulses[i]
    key <- format(as.POSIXct(t, tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
    rows <- bars_close[bars_close$ts_utc == t, , drop = FALSE]
    if (nrow(rows) != length(instrument_ids)) {
      rlang::abort(sprintf("Missing bars.close for universe at ts_utc=%s.", key), class = "ledgr_missing_bars")
    }
    close_by_id <- stats::setNames(as.numeric(rows$close), as.character(rows$instrument_id))
    if (any(!(instrument_ids %in% names(close_by_id)))) {
      rlang::abort(sprintf("Missing bars.close for some instruments at ts_utc=%s.", key), class = "ledgr_missing_bars")
    }
    if (anyNA(close_by_id[instrument_ids]) || any(!is.finite(close_by_id[instrument_ids]))) {
      rlang::abort(sprintf("bars.close must be finite (no NA) at ts_utc=%s for mark-to-market.", key), class = "ledgr_missing_bars")
    }
    assign(key, close_by_id[instrument_ids], envir = close_map)
  }

  cash <- as.numeric(initial_cash)
  positions <- numeric(0)
  lot_state <- ledgr_lot_state(instrument_ids)
  realized_pnl <- 0

  event_idx <- 1L
  n_events <- nrow(events)

  apply_event <- function(row) {
    meta <- jsonlite::fromJSON(row$meta_json[[1]], simplifyVector = FALSE)
    cash_delta <- meta$cash_delta
    position_delta <- meta$position_delta
    if (!is.numeric(cash_delta) || length(cash_delta) != 1 || is.na(cash_delta) || !is.finite(cash_delta)) {
      rlang::abort("ledger_events.meta_json must include a finite numeric scalar `cash_delta`.", class = "ledgr_invalid_ledger_meta")
    }
    if (!is.numeric(position_delta) || length(position_delta) != 1 || is.na(position_delta) || !is.finite(position_delta)) {
      rlang::abort("ledger_events.meta_json must include a finite numeric scalar `position_delta`.", class = "ledgr_invalid_ledger_meta")
    }

    cash <<- cash + as.numeric(cash_delta)

    instrument_id <- row$instrument_id[[1]]
    if (!is.na(instrument_id) && nzchar(instrument_id)) {
      if (is.null(names(positions)) || !(instrument_id %in% names(positions))) positions[instrument_id] <<- 0
      positions[instrument_id] <<- positions[instrument_id] + as.numeric(position_delta)
    }

    if (identical(row$event_type[[1]], "CASHFLOW")) {
      lot_res <- ledgr_lot_apply_event(
        lot_state,
        event_type = row$event_type[[1]],
        instrument_id = instrument_id,
        meta = meta
      )
      lot_state <<- lot_res$state
      realized_pnl <<- lot_state$realized_pnl
      return(invisible(TRUE))
    }

    if (!(row$event_type[[1]] %in% c("FILL", "FILL_PARTIAL")) || is.na(instrument_id) || !nzchar(instrument_id)) {
      return(invisible(TRUE))
    }

    side <- row$side[[1]]
    qty <- as.numeric(row$qty[[1]])
    price <- as.numeric(row$price[[1]])
    fee <- as.numeric(row$fee[[1]])

    if (!is.character(side) || length(side) != 1 || is.na(side) || !(side %in% c("BUY", "SELL"))) {
      rlang::abort("ledger_events.side must be 'BUY' or 'SELL' for FILL events.", class = "ledgr_invalid_ledger_event")
    }
    if (!is.numeric(qty) || length(qty) != 1 || is.na(qty) || !is.finite(qty) || qty <= 0) {
      rlang::abort("ledger_events.qty must be a finite numeric scalar > 0 for FILL events.", class = "ledgr_invalid_ledger_event")
    }
    if (!is.numeric(price) || length(price) != 1 || is.na(price) || !is.finite(price) || price <= 0) {
      rlang::abort("ledger_events.price must be a finite numeric scalar > 0 for FILL events.", class = "ledgr_invalid_ledger_event")
    }
    if (!is.numeric(fee) || length(fee) != 1 || is.na(fee) || !is.finite(fee) || fee < 0) {
      rlang::abort("ledger_events.fee must be a finite numeric scalar >= 0 for FILL events.", class = "ledgr_invalid_ledger_event")
    }

    lot_res <- ledgr_lot_apply_event(
      lot_state,
      event_type = row$event_type[[1]],
      instrument_id = instrument_id,
      side = side,
      qty = qty,
      price = price,
      fee = fee,
      meta = meta
    )
    lot_state <<- lot_res$state
    realized_pnl <<- lot_state$realized_pnl
    invisible(TRUE)
  }

  eq_rows <- vector("list", length(pulses))
  eq_idx <- 1L

  for (i in seq_along(pulses)) {
    t <- pulses[i]
    while (event_idx <= n_events) {
      ev_ts <- as.POSIXct(events$ts_utc[[event_idx]], tz = "UTC")
      if (is.na(ev_ts)) rlang::abort("ledger_events.ts_utc contains an invalid timestamp.", class = "ledgr_invalid_ledger_event")
      if (ev_ts > t) break
      apply_event(events[event_idx, , drop = FALSE])
      event_idx <- event_idx + 1L
    }

    held <- positions[abs(positions) > 0]
    close_by_id <- get(format(t, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), envir = close_map, inherits = FALSE)
    positions_value <- 0
    if (length(held) > 0) {
      ids <- names(held)
      positions_value <- sum(as.numeric(held) * close_by_id[ids])
    }

    cost_basis_remaining <- 0
    if (length(lot_state$lots) > 0) {
      for (id in names(lot_state$lots)) {
        for (lot in lot_state$lots[[id]]) {
          cost_basis_remaining <- cost_basis_remaining + (as.numeric(lot$qty) * as.numeric(lot$price))
        }
      }
    }

    eq_rows[[eq_idx]] <- list(
      run_id = run_id,
      ts_utc = t,
      cash = cash,
      positions_value = positions_value,
      equity = cash + positions_value,
      realized_pnl = realized_pnl,
      unrealized_pnl = positions_value - cost_basis_remaining
    )
    eq_idx <- eq_idx + 1L
  }

  eq_df <- data.frame(
    run_id = vapply(eq_rows, `[[`, character(1), "run_id"),
    ts_utc = as.POSIXct(vapply(eq_rows, function(x) format(x$ts_utc, "%Y-%m-%d %H:%M:%S", tz = "UTC"), character(1)), tz = "UTC"),
    cash = vapply(eq_rows, `[[`, numeric(1), "cash"),
    positions_value = vapply(eq_rows, `[[`, numeric(1), "positions_value"),
    equity = vapply(eq_rows, `[[`, numeric(1), "equity"),
    realized_pnl = vapply(eq_rows, `[[`, numeric(1), "realized_pnl"),
    unrealized_pnl = vapply(eq_rows, `[[`, numeric(1), "unrealized_pnl"),
    stringsAsFactors = FALSE
  )

  # Internal invariant checks (I1/I2 level).
  total_cash_delta <- 0
  pos_deltas <- numeric(0)
  for (i in seq_len(nrow(events))) {
    meta <- jsonlite::fromJSON(events$meta_json[[i]], simplifyVector = FALSE)
    total_cash_delta <- total_cash_delta + as.numeric(meta$cash_delta)
    instrument_id <- events$instrument_id[[i]]
    if (!is.na(instrument_id) && nzchar(instrument_id)) {
      if (is.null(names(pos_deltas)) || !(instrument_id %in% names(pos_deltas))) pos_deltas[instrument_id] <- 0
      pos_deltas[instrument_id] <- pos_deltas[instrument_id] + as.numeric(meta$position_delta)
    }
  }
  expected_cash <- as.numeric(initial_cash) + total_cash_delta
  if (!isTRUE(all.equal(eq_df$cash[[nrow(eq_df)]], expected_cash, tolerance = 1e-10))) {
    rlang::abort("Cash identity violated: cash != initial_cash + sum(cash_delta).", class = "ledgr_invariant_violation")
  }
  final_positions <- positions
  if (length(pos_deltas) > 0) {
    for (id in names(pos_deltas)) {
      final_val <- if (is.null(names(final_positions)) || !(id %in% names(final_positions))) 0 else as.numeric(final_positions[[id]])
      if (!isTRUE(all.equal(final_val, as.numeric(pos_deltas[[id]]), tolerance = 1e-10))) {
        rlang::abort("Position identity violated: positions != cumulative position_delta.", class = "ledgr_invariant_violation")
      }
    }
  }

  if (!is.logical(use_transaction) || length(use_transaction) != 1 || is.na(use_transaction)) {
    rlang::abort("`use_transaction` must be TRUE or FALSE.", class = "ledgr_invalid_args")
  }
  if (isTRUE(use_transaction)) {
    DBI::dbWithTransaction(con, {
      DBI::dbExecute(con, "DELETE FROM equity_curve WHERE run_id = ?", params = list(run_id))
      DBI::dbAppendTable(con, "equity_curve", eq_df)
    })
  } else {
    DBI::dbExecute(con, "DELETE FROM equity_curve WHERE run_id = ?", params = list(run_id))
    DBI::dbAppendTable(con, "equity_curve", eq_df)
  }

  structure(
    list(
      positions = positions,
      cash = eq_df$cash[[nrow(eq_df)]],
      equity_curve = eq_df
    ),
    class = "ledgr_derived_state"
  )
}
