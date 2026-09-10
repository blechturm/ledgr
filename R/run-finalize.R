ledgr_run_finalize <- function(con,
                               output_handler,
                               run,
                               calendar,
                               projection,
                               fold) {
  run_id <- run$run_id
  start_ts_utc <- run$start_ts_utc
  end_ts_utc <- run$end_ts_utc
  instrument_ids <- run$instrument_ids
  initial_cash <- run$initial_cash
  pulses <- calendar$pulses
  bars_mat <- projection$bars_mat
  persist_features <- projection$persist_features
  feature_defs <- projection$feature_defs
  runtime_projection <- projection$runtime_projection
  telemetry <- fold$telemetry
  processed <- fold$processed

  finalization_error <- tryCatch({
    post_start <- ledgr_time_now()
    events_df <- DBI::dbGetQuery(
      con,
      "
      SELECT event_seq, ts_utc, event_type, instrument_id, side, qty, price, fee, meta_json
      FROM ledger_events
      WHERE run_id = ?
      ORDER BY event_seq
      ",
      params = list(run_id)
    )

    pulses_posix <- as.POSIXct(pulses, tz = "UTC")
    close_mat <- NULL
    if (!is.null(bars_mat)) {
      close_mat <- bars_mat$close
    } else {
      start_iso <- ledgr_normalize_ts_utc(start_ts_utc)
      end_iso <- ledgr_normalize_ts_utc(end_ts_utc)
      start_ts <- as.POSIXct(start_iso, tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ")
      end_ts <- as.POSIXct(end_iso, tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ")
      ids_sql <- paste(DBI::dbQuoteString(con, instrument_ids), collapse = ", ")
      bars_close <- DBI::dbGetQuery(
        con,
        paste0(
          "SELECT instrument_id, ts_utc, close ",
          "FROM bars ",
          "WHERE instrument_id IN (", ids_sql, ") ",
          "AND ts_utc >= ? AND ts_utc <= ? ",
          "ORDER BY instrument_id, ts_utc"
        ),
        params = list(start_ts, end_ts)
      )
      if (nrow(bars_close) == 0) {
        rlang::abort("No bars found for pulse calendar during derived-state reconstruction.", class = "ledgr_missing_bars")
      }
      close_mat <- matrix(NA_real_, nrow = length(instrument_ids), ncol = length(pulses_posix))
      for (j in seq_along(instrument_ids)) {
        id <- instrument_ids[[j]]
        rows <- bars_close[bars_close$instrument_id == id, , drop = FALSE]
        if (nrow(rows) != length(pulses_posix)) {
          rlang::abort(sprintf("Missing bars.close for instrument_id=%s during derived-state reconstruction.", id), class = "ledgr_missing_bars")
        }
        close_mat[j, ] <- as.numeric(rows$close)
      }
    }

    n_events <- nrow(events_df)
    event_ts <- if (n_events > 0) as.POSIXct(events_df$ts_utc, tz = "UTC") else as.POSIXct(character(0), tz = "UTC")
    event_ts_num <- as.numeric(event_ts)
    pulse_ts_num <- as.numeric(pulses_posix)

    cash_delta <- numeric(n_events)
    position_delta <- numeric(n_events)
    event_meta <- vector("list", n_events)
    if (n_events > 0) {
      for (i in seq_len(n_events)) {
        meta <- ledgr_json_read_nested(events_df$meta_json[[i]])
        event_meta[[i]] <- meta
        cash_delta[[i]] <- as.numeric(meta$cash_delta)
        position_delta[[i]] <- as.numeric(meta$position_delta)
      }
    }

    idx <- findInterval(pulse_ts_num, event_ts_num)
    cash_cum <- if (n_events > 0) cumsum(cash_delta) else numeric(0)
    cash_at <- rep(as.numeric(initial_cash), length(idx))
    has_event <- idx > 0
    if (any(has_event)) {
      cash_at[has_event] <- as.numeric(initial_cash) + cash_cum[idx[has_event]]
    }

    n_inst <- length(instrument_ids)
    n_pulses <- length(pulses_posix)
    positions_mat <- matrix(0, nrow = n_inst, ncol = n_pulses)
    if (n_events > 0) {
      for (j in seq_along(instrument_ids)) {
        id <- instrument_ids[[j]]
        ev_idx <- which(events_df$instrument_id == id)
        if (length(ev_idx) == 0) next
        pos_cum <- cumsum(position_delta[ev_idx])
        idx_inst <- findInterval(pulse_ts_num, event_ts_num[ev_idx])
        has_inst_event <- idx_inst > 0
        if (any(has_inst_event)) {
          positions_mat[j, has_inst_event] <- pos_cum[idx_inst[has_inst_event]]
        }
      }
    }

    positions_value <- if (n_pulses > 0) colSums(positions_mat * close_mat) else numeric(0)

    reconstruction_lots <- ledgr_lot_state(instrument_ids)
    event_realized <- numeric(n_events)
    event_cost_basis <- numeric(n_events)

    if (n_events > 0) {
      for (i in seq_len(n_events)) {
        instrument_id <- events_df$instrument_id[[i]]
        lot_res <- ledgr_lot_apply_event(
          reconstruction_lots,
          event_type = events_df$event_type[[i]],
          instrument_id = instrument_id,
          side = events_df$side[[i]],
          qty = events_df$qty[[i]],
          price = events_df$price[[i]],
          fee = events_df$fee[[i]],
          meta = event_meta[[i]]
        )
        reconstruction_lots <- lot_res$state

        event_realized[[i]] <- reconstruction_lots$realized_pnl
        event_cost_basis[[i]] <- reconstruction_lots$total_cost_basis
      }
    }

    realized_at <- numeric(length(idx))
    cost_basis_at <- numeric(length(idx))
    if (any(has_event)) {
      realized_at[has_event] <- event_realized[idx[has_event]]
      cost_basis_at[has_event] <- event_cost_basis[idx[has_event]]
    }

    equity <- cash_at + positions_value
    unrealized <- positions_value - cost_basis_at

    if (length(pulses_posix) == 0) {
      eq_df <- data.frame(
        run_id = character(0),
        ts_utc = as.POSIXct(character(0), tz = "UTC"),
        cash = numeric(0),
        positions_value = numeric(0),
        equity = numeric(0),
        realized_pnl = numeric(0),
        unrealized_pnl = numeric(0),
        stringsAsFactors = FALSE
      )
    } else {
      eq_df <- data.frame(
        run_id = rep(run_id, length(pulses_posix)),
        ts_utc = pulses_posix,
        cash = cash_at,
        positions_value = positions_value,
        equity = equity,
        realized_pnl = realized_at,
        unrealized_pnl = unrealized,
        stringsAsFactors = FALSE
      )
    }
    if (isTRUE(persist_features) && length(feature_defs) > 0) {
      def_ids <- vapply(feature_defs, function(d) d$id, character(1))
      n_def <- length(def_ids)
      n_p <- length(pulses_posix)
      if (n_p > 0 && n_def > 0) {
        DBI::dbWithTransaction(con, {
          DBI::dbExecute(con, "DELETE FROM features WHERE run_id = ?", params = list(run_id))
          for (j in seq_along(instrument_ids)) {
            id <- instrument_ids[[j]]
            feat_vals <- matrix(NA_real_, nrow = n_def, ncol = n_p)
            for (d in seq_len(n_def)) {
              feat_vals[d, ] <- runtime_projection$feature_values[[def_ids[[d]]]][j, ]
            }
            out <- data.frame(
              run_id = rep(run_id, n_def * n_p),
              instrument_id = rep(id, n_def * n_p),
              ts_utc = rep(pulses_posix, each = n_def),
              feature_name = rep(def_ids, times = n_p),
              feature_value = as.vector(feat_vals),
              stringsAsFactors = FALSE
            )
            DBI::dbAppendTable(con, "features", out)
          }
        })
      }
    }
    DBI::dbWithTransaction(con, {
      DBI::dbExecute(con, "DELETE FROM equity_curve WHERE run_id = ?", params = list(run_id))
      if (nrow(eq_df) > 0) {
        DBI::dbAppendTable(con, "equity_curve", eq_df)
      }
      output_handler$record_run_status("DONE", NA_character_)
    })
    NULL
  }, error = function(e) e)
  if (!is.null(finalization_error)) {
    try(output_handler$record_failure(conditionMessage(finalization_error)), silent = TRUE)
    try(
      ledgr_finalize_fold_telemetry(
        output_handler = output_handler,
        status = "FAILED",
        telemetry = telemetry,
        processed = processed,
        strict = FALSE
      ),
      silent = TRUE
    )
    rlang::cnd_signal(finalization_error)
  }
  telemetry$t_post <- ledgr_time_elapsed(post_start, ledgr_time_now())

  ledgr_finalize_fold_telemetry(
    output_handler = output_handler,
    status = "DONE",
    telemetry = telemetry,
    processed = processed
  )

  list(
    status = "DONE",
    telemetry = telemetry
  )
}
