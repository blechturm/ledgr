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

ledgr_rebuild_derived_state <- function(con, run_id, initial_cash) {
  if (!DBI::dbIsValid(con)) {
    rlang::abort("`con` must be a valid DBI connection.", class = "ledgr_invalid_con")
  }
  if (!is.character(run_id) || length(run_id) != 1 || is.na(run_id) || !nzchar(run_id)) {
    rlang::abort("`run_id` must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }
  if (!is.numeric(initial_cash) || length(initial_cash) != 1 || is.na(initial_cash) || !is.finite(initial_cash)) {
    rlang::abort("`initial_cash` must be a finite numeric scalar.", class = "ledgr_invalid_args")
  }

  run_exists <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM runs WHERE run_id = ?", params = list(run_id))$n[[1]] > 0
  if (!isTRUE(run_exists)) {
    rlang::abort(sprintf("run_id not found in runs table: %s", run_id), class = "ledgr_invalid_args")
  }

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

  cash <- as.numeric(initial_cash)
  positions <- numeric(0)
  lots <- list()
  realized_pnl <- 0

  if (nrow(events) == 0) {
    DBI::dbWithTransaction(con, {
      DBI::dbExecute(con, "DELETE FROM equity_curve WHERE run_id = ?", params = list(run_id))
    })
    return(structure(
      list(
        positions = positions,
        cash = cash,
        equity_curve = data.frame()
      ),
      class = "ledgr_derived_state"
    ))
  }

  eq_rows <- vector("list", length(unique(events$ts_utc)))
  eq_idx <- 1L

  current_ts <- NULL

  flush_equity_row <- function(ts_posix) {
    held <- positions[abs(positions) > 0]
    instrument_ids <- names(held)
    positions_value <- 0
    if (length(instrument_ids) > 0) {
      ids_sql <- paste(DBI::dbQuoteString(con, instrument_ids), collapse = ", ")
      bars <- DBI::dbGetQuery(
        con,
        paste0(
          "SELECT instrument_id, close FROM bars WHERE instrument_id IN (",
          ids_sql,
          ") AND ts_utc = ?"
        ),
        params = list(ts_posix)
      )
      if (nrow(bars) == 0 || any(!(instrument_ids %in% bars$instrument_id))) {
        missing_ids <- setdiff(instrument_ids, bars$instrument_id)
        rlang::abort(
          sprintf(
            "Missing bars.close for held instruments at ts_utc=%s: %s",
            format(ts_posix, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
            paste(missing_ids, collapse = ", ")
          ),
          class = "ledgr_missing_bars"
        )
      }
      close_by_id <- stats::setNames(as.numeric(bars$close), bars$instrument_id)
      positions_value <- sum(as.numeric(held) * close_by_id[instrument_ids])
    }

    cost_basis_remaining <- 0
    if (length(lots) > 0) {
      for (id in names(lots)) {
        for (lot in lots[[id]]) {
          cost_basis_remaining <- cost_basis_remaining + (as.numeric(lot$qty) * as.numeric(lot$price))
        }
      }
    }

    list(
      run_id = run_id,
      ts_utc = ts_posix,
      cash = cash,
      positions_value = positions_value,
      equity = cash + positions_value,
      realized_pnl = realized_pnl,
      unrealized_pnl = positions_value - cost_basis_remaining
    )
  }

  for (i in seq_len(nrow(events))) {
    ts_posix <- as.POSIXct(events$ts_utc[[i]], tz = "UTC")
    if (is.null(current_ts)) current_ts <- ts_posix

    if (!identical(ts_posix, current_ts)) {
      eq_rows[[eq_idx]] <- flush_equity_row(current_ts)
      eq_idx <- eq_idx + 1L
      current_ts <- ts_posix
    }

    meta <- jsonlite::fromJSON(events$meta_json[[i]], simplifyVector = FALSE)
    cash_delta <- meta$cash_delta
    position_delta <- meta$position_delta
    if (!is.numeric(cash_delta) || length(cash_delta) != 1 || is.na(cash_delta) || !is.finite(cash_delta)) {
      rlang::abort("ledger_events.meta_json must include a finite numeric scalar `cash_delta`.", class = "ledgr_invalid_ledger_meta")
    }
    if (!is.numeric(position_delta) || length(position_delta) != 1 || is.na(position_delta) || !is.finite(position_delta)) {
      rlang::abort("ledger_events.meta_json must include a finite numeric scalar `position_delta`.", class = "ledgr_invalid_ledger_meta")
    }

    cash <- cash + as.numeric(cash_delta)

    instrument_id <- events$instrument_id[[i]]
    if (!is.na(instrument_id) && nzchar(instrument_id)) {
      if (is.null(names(positions)) || !(instrument_id %in% names(positions))) positions[instrument_id] <- 0
      positions[instrument_id] <- positions[instrument_id] + as.numeric(position_delta)
    }

    # v0.1.0 realized/unrealized PnL: FIFO cost basis, fees reduce PnL.
    if (identical(events$event_type[[i]], "FILL") && !is.na(instrument_id) && nzchar(instrument_id)) {
      side <- events$side[[i]]
      qty <- as.numeric(events$qty[[i]])
      price <- as.numeric(events$price[[i]])
      fee <- as.numeric(events$fee[[i]])

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

      if (side == "BUY") {
        if (is.null(lots[[instrument_id]])) lots[[instrument_id]] <- list()
        lots[[instrument_id]][[length(lots[[instrument_id]]) + 1L]] <- list(qty = qty, price = price)
        realized_pnl <- realized_pnl - fee
      } else {
        qty_to_sell <- qty
        if (is.null(lots[[instrument_id]])) {
          rlang::abort("SELL fill encountered with no existing lots (shorting not supported in v0.1.0).", class = "ledgr_invalid_ledger_event")
        }
        lot_list <- lots[[instrument_id]]
        available <- sum(vapply(lot_list, function(l) as.numeric(l$qty), numeric(1)))
        if (available + 1e-12 < qty_to_sell) {
          rlang::abort("SELL fill exceeds available position (shorting not supported in v0.1.0).", class = "ledgr_invalid_ledger_event")
        }

        trade_pnl <- 0
        j <- 1L
        while (qty_to_sell > 0 && j <= length(lot_list)) {
          lot_qty <- as.numeric(lot_list[[j]]$qty)
          lot_price <- as.numeric(lot_list[[j]]$price)
          take <- min(lot_qty, qty_to_sell)

          trade_pnl <- trade_pnl + (price - lot_price) * take

          lot_qty <- lot_qty - take
          qty_to_sell <- qty_to_sell - take

          lot_list[[j]]$qty <- lot_qty
          j <- j + 1L
        }

        lot_list <- Filter(function(l) as.numeric(l$qty) > 0, lot_list)
        lots[[instrument_id]] <- lot_list
        realized_pnl <- realized_pnl + trade_pnl - fee
      }
    }
  }

  eq_rows[[eq_idx]] <- flush_equity_row(current_ts)
  eq_rows <- eq_rows[seq_len(eq_idx)]

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

  DBI::dbWithTransaction(con, {
    DBI::dbExecute(con, "DELETE FROM equity_curve WHERE run_id = ?", params = list(run_id))
    DBI::dbAppendTable(con, "equity_curve", eq_df)
  })

  structure(
    list(
      positions = positions,
      cash = eq_df$cash[[nrow(eq_df)]],
      equity_curve = eq_df
    ),
    class = "ledgr_derived_state"
  )
}
