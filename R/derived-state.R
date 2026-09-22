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

  cfg <- ledgr_json_read_config(run_cfg$config_json[[1]])
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
      event_id,
      run_id,
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

  prepared <- ledgr_prepare_accounting_events(events, instrument_ids)
  replay <- ledgr_replay_accounting_events(prepared, initial_cash = initial_cash)
  event_at_pulse <- findInterval(
    as.numeric(as.POSIXct(pulses, tz = "UTC")),
    as.numeric(prepared$ts_utc)
  )

  cash_at <- rep(as.numeric(initial_cash), length(pulses))
  realized_at <- numeric(length(pulses))
  basis_at <- numeric(length(pulses))
  has_event <- event_at_pulse > 0L
  cash_at[has_event] <- replay$cash_after[event_at_pulse[has_event]]
  realized_at[has_event] <- replay$event_realized[event_at_pulse[has_event]]
  basis_at[has_event] <- replay$event_cost_basis[event_at_pulse[has_event]]

  positions_mat <- ledgr_accounting_positions_at_pulses(
    replay,
    pulses,
    instrument_ids
  )

  eq_rows <- vector("list", length(pulses))
  eq_idx <- 1L

  for (i in seq_along(pulses)) {
    t <- pulses[i]
    positions <- stats::setNames(positions_mat[, i], instrument_ids)
    held <- positions[abs(positions) > 0]
    close_by_id <- get(format(t, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), envir = close_map, inherits = FALSE)
    positions_value <- 0
    if (length(held) > 0) {
      ids <- names(held)
      positions_value <- sum(as.numeric(held) * close_by_id[ids])
    }

    eq_rows[[eq_idx]] <- list(
      run_id = run_id,
      ts_utc = t,
      cash = cash_at[[i]],
      positions_value = positions_value,
      equity = cash_at[[i]] + positions_value,
      realized_pnl = realized_at[[i]],
      unrealized_pnl = positions_value - basis_at[[i]]
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
  expected_cash <- as.numeric(initial_cash) + sum(prepared$cash_delta)
  if (!isTRUE(all.equal(eq_df$cash[[nrow(eq_df)]], expected_cash, tolerance = 1e-10))) {
    rlang::abort("Cash identity violated: cash != initial_cash + sum(cash_delta).", class = "ledgr_invariant_violation")
  }
  final_positions <- replay$positions
  valid_position <- !is.na(prepared$instrument_id) & nzchar(prepared$instrument_id)
  position_totals <- if (any(valid_position)) {
    tapply(
      prepared$position_delta[valid_position],
      prepared$instrument_id[valid_position],
      sum
    )
  } else {
    numeric()
  }
  if (length(position_totals) > 0) {
    for (id in names(position_totals)) {
      final_val <- if (!(id %in% names(final_positions))) 0 else as.numeric(final_positions[[id]])
      if (!isTRUE(all.equal(final_val, as.numeric(position_totals[[id]]), tolerance = 1e-10))) {
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

  touched_ids <- unique(prepared$instrument_id[
    !is.na(prepared$instrument_id) & nzchar(prepared$instrument_id)
  ])
  positions <- if (length(touched_ids) > 0L) replay$positions[touched_ids] else numeric()

  structure(
    list(
      positions = positions,
      cash = eq_df$cash[[nrow(eq_df)]],
      equity_curve = eq_df
    ),
    class = "ledgr_derived_state"
  )
}
