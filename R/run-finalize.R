ledgr_run_terminal_evidence_abort <- function(message) {
  rlang::abort(
    message,
    class = c("ledgr_run_terminal_evidence_invalid", "ledgr_invalid_run")
  )
}

ledgr_run_completion_read <- function(con, run_id, required = FALSE) {
  rows <- DBI::dbGetQuery(
    con,
    "SELECT * FROM run_completion WHERE run_id = ?",
    params = list(run_id)
  )
  if (nrow(rows) == 0L && !isTRUE(required)) return(NULL)
  if (nrow(rows) != 1L) {
    ledgr_run_terminal_evidence_abort(
      sprintf("Run '%s' does not have exactly one terminal completion row.", run_id)
    )
  }
  rows
}

ledgr_run_completion_validate <- function(completion, run_id, calendar, stored_status = NULL) {
  if (!is.data.frame(completion) || nrow(completion) != 1L) {
    ledgr_run_terminal_evidence_abort("Terminal completion evidence must contain exactly one row.")
  }
  required <- c(
    "run_id", "intended_start_utc", "intended_end_utc", "achieved_start_utc",
    "achieved_end_utc", "intended_terminal_status", "stop_reason",
    "last_fully_valued_ts_utc", "last_executed_ts_utc", "complete_performance"
  )
  if (!all(required %in% names(completion))) {
    ledgr_run_terminal_evidence_abort("Terminal completion evidence is missing required fields.")
  }
  if (!identical(as.character(completion$run_id[[1L]]), as.character(run_id))) {
    ledgr_run_terminal_evidence_abort("Terminal completion evidence belongs to a different run.")
  }
  terminal_status <- as.character(completion$intended_terminal_status[[1L]])
  if (!terminal_status %in% c("DONE", "INCOMPLETE")) {
    ledgr_run_terminal_evidence_abort("Terminal completion status must be DONE or INCOMPLETE.")
  }
  if (!is.null(stored_status) && identical(stored_status, "INCOMPLETE") &&
      !identical(terminal_status, "INCOMPLETE")) {
    ledgr_run_terminal_evidence_abort("Stored INCOMPLETE status disagrees with terminal completion evidence.")
  }

  pulses <- as.POSIXct(calendar$pulses_posix, tz = "UTC")
  if (length(pulses) < 1L) {
    ledgr_run_terminal_evidence_abort("Terminal completion evidence requires a non-empty pulse calendar.")
  }
  intended_start <- as.POSIXct(completion$intended_start_utc[[1L]], tz = "UTC")
  intended_end <- as.POSIXct(completion$intended_end_utc[[1L]], tz = "UTC")
  if (is.na(intended_start) || is.na(intended_end) ||
      as.numeric(intended_start) != as.numeric(pulses[[1L]]) ||
      as.numeric(intended_end) != as.numeric(utils::tail(pulses, 1L))) {
    ledgr_run_terminal_evidence_abort("Terminal completion intended bounds do not match the run calendar.")
  }

  achieved_start <- as.POSIXct(completion$achieved_start_utc[[1L]], tz = "UTC")
  achieved_end <- as.POSIXct(completion$achieved_end_utc[[1L]], tz = "UTC")
  has_start <- !is.na(achieved_start)
  has_end <- !is.na(achieved_end)
  if (!identical(has_start, has_end)) {
    ledgr_run_terminal_evidence_abort("Terminal completion achieved bounds must both be present or absent.")
  }
  if (has_start) {
    if (as.numeric(achieved_start) != as.numeric(pulses[[1L]]) ||
        !as.numeric(achieved_end) %in% as.numeric(pulses) ||
        achieved_end < achieved_start) {
      ledgr_run_terminal_evidence_abort("Terminal completion achieved bounds are inconsistent with the run calendar.")
    }
  }
  last_valued <- as.POSIXct(completion$last_fully_valued_ts_utc[[1L]], tz = "UTC")
  if (!identical(is.na(last_valued), is.na(achieved_end)) ||
      (!is.na(last_valued) && as.numeric(last_valued) != as.numeric(achieved_end))) {
    ledgr_run_terminal_evidence_abort("Terminal completion last-valued timestamp disagrees with its achieved end.")
  }
  last_executed <- as.POSIXct(completion$last_executed_ts_utc[[1L]], tz = "UTC")
  if (!is.na(last_executed) &&
      (last_executed < intended_start || last_executed > intended_end)) {
    ledgr_run_terminal_evidence_abort("Terminal completion last-executed timestamp is outside the run calendar.")
  }

  complete_performance <- isTRUE(completion$complete_performance[[1L]])
  stop_reason <- as.character(completion$stop_reason[[1L]])
  if (identical(terminal_status, "DONE")) {
    if (!complete_performance || !has_end ||
        as.numeric(achieved_end) != as.numeric(intended_end)) {
      ledgr_run_terminal_evidence_abort("DONE completion evidence must cover the full intended horizon.")
    }
  } else if (complete_performance || length(stop_reason) != 1L || is.na(stop_reason) || !nzchar(stop_reason)) {
    ledgr_run_terminal_evidence_abort("INCOMPLETE completion evidence requires a stop reason and incomplete performance.")
  }
  completion
}

ledgr_run_completion_validate_finalized <- function(con, completion, run_id, calendar) {
  achieved_end <- as.POSIXct(completion$achieved_end_utc[[1L]], tz = "UTC")
  expected <- as.POSIXct(calendar$pulses_posix, tz = "UTC")
  if (is.na(achieved_end)) {
    expected <- expected[FALSE]
  } else {
    expected <- expected[expected <= achieved_end]
  }
  equity <- DBI::dbGetQuery(
    con,
    "SELECT ts_utc FROM equity_curve WHERE run_id = ? ORDER BY ts_utc",
    params = list(run_id)
  )
  actual <- as.POSIXct(equity$ts_utc, tz = "UTC")
  if (!identical(as.numeric(actual), as.numeric(expected))) {
    ledgr_run_terminal_evidence_abort(
      "Finalized terminal evidence does not contain its exact achieved equity prefix."
    )
  }

  stop_reason <- as.character(completion$stop_reason[[1L]])
  stop_rows <- DBI::dbGetQuery(
    con,
    paste(
      "SELECT COUNT(*) AS n FROM run_diagnostics",
      "WHERE run_id = ? AND reason_code = ? AND outcome = 'stopped'"
    ),
    params = list(run_id, stop_reason)
  )
  if (stop_rows$n[[1L]] < 1L) {
    ledgr_run_terminal_evidence_abort(
      "Finalized INCOMPLETE evidence does not contain its recorded stop diagnostic."
    )
  }
  invisible(TRUE)
}

ledgr_run_terminal_recovery_telemetry <- function() {
  telemetry <- new.env(parent = emptyenv())
  telemetry$t_pre <- 0
  telemetry$t_post <- NA_real_
  telemetry$t_loop <- 0
  telemetry$telemetry_stride <- 0L
  telemetry$telemetry_samples <- 0L
  telemetry$feature_cache_hits <- 0L
  telemetry$feature_cache_misses <- 0L
  for (name in c("t_pulse", "t_bars", "t_ctx", "t_fill", "t_state", "t_feats", "t_strat", "t_target", "t_event", "t_exec")) {
    telemetry[[name]] <- numeric()
  }
  telemetry
}

ledgr_run_terminal_recovery_equity <- function(con,
                                               run_id,
                                               completion,
                                               calendar,
                                               bars_mat,
                                               instrument_ids,
                                               initial_cash,
                                               availability_provider) {
  achieved_end <- as.POSIXct(completion$achieved_end_utc[[1L]], tz = "UTC")
  if (is.na(achieved_end)) return(list())
  pulses <- as.POSIXct(calendar$pulses_posix, tz = "UTC")
  keep <- which(pulses <= achieved_end)
  lapply(keep, function(i) {
    ts <- pulses[[i]]
    state <- ledgr_state_asof(
      con,
      run_id,
      initial_cash,
      ts,
      instrument_ids = instrument_ids
    )
    positions <- stats::setNames(rep(0, length(instrument_ids)), instrument_ids)
    present <- intersect(names(state$positions), instrument_ids)
    if (length(present) > 0L) positions[present] <- as.numeric(state$positions[present])
    held <- names(positions)[positions != 0]
    if (length(held) == 0L) {
      positions_value <- 0
    } else {
      valuation <- ledgr_availability_valuation_marks(
        bars_mat = bars_mat,
        instrument_ids = instrument_ids,
        axis = held,
        pulse_idx = i,
        pulses_posix = pulses,
        max_sessions = as.integer(availability_provider$valuation_policy$max_sessions)
      )
      if (any(!valuation$priced[held])) {
        ledgr_run_terminal_evidence_abort(
          "Committed terminal evidence cannot reconstruct every achieved valuation row."
        )
      }
      positions_value <- sum(as.numeric(positions[held]) * as.numeric(valuation$mark[held]))
    }
    list(
      ts_utc = ts,
      cash = as.numeric(state$cash),
      positions_value = as.numeric(positions_value),
      realized_pnl = as.numeric(state$lot_state$realized_pnl),
      cost_basis = as.numeric(state$lot_state$total_cost_basis)
    )
  })
}

ledgr_run_fold_equity_frame <- function(run_id, fold_equity) {
  if (length(fold_equity) == 0L) {
    return(data.frame(
      run_id = character(),
      ts_utc = as.POSIXct(character(), tz = "UTC"),
      cash = numeric(),
      positions_value = numeric(),
      equity = numeric(),
      realized_pnl = numeric(),
      unrealized_pnl = numeric(),
      stringsAsFactors = FALSE
    ))
  }
  ts_utc <- as.POSIXct(
    vapply(fold_equity, function(x) as.numeric(x$ts_utc), numeric(1)),
    origin = "1970-01-01",
    tz = "UTC"
  )
  cash <- vapply(fold_equity, `[[`, numeric(1), "cash")
  positions_value <- vapply(fold_equity, `[[`, numeric(1), "positions_value")
  realized_pnl <- vapply(fold_equity, `[[`, numeric(1), "realized_pnl")
  cost_basis <- vapply(fold_equity, `[[`, numeric(1), "cost_basis")
  data.frame(
    run_id = rep(as.character(run_id), length(ts_utc)),
    ts_utc = ts_utc,
    cash = cash,
    positions_value = positions_value,
    equity = cash + positions_value,
    realized_pnl = realized_pnl,
    unrealized_pnl = positions_value - cost_basis,
    stringsAsFactors = FALSE
  )
}

ledgr_run_equity_prefix_columns <- function() {
  c(
    "run_id", "ts_utc", "cash", "positions_value", "equity",
    "realized_pnl", "unrealized_pnl"
  )
}

ledgr_run_equity_prefix_read <- function(con, run_id) {
  DBI::dbGetQuery(
    con,
    paste(
      "SELECT run_id, ts_utc, cash, positions_value, equity,",
      "realized_pnl, unrealized_pnl FROM equity_curve",
      "WHERE run_id = ? ORDER BY ts_utc"
    ),
    params = list(run_id)
  )
}

ledgr_run_equity_prefix_normalize <- function(rows, run_id, calendar, label) {
  columns <- ledgr_run_equity_prefix_columns()
  if (!is.data.frame(rows) || !all(columns %in% names(rows))) {
    ledgr_run_terminal_evidence_abort(
      sprintf("%s equity evidence is missing required fields.", label)
    )
  }
  rows <- rows[, columns, drop = FALSE]
  if (nrow(rows) == 0L) {
    rows$ts_utc <- as.POSIXct(rows$ts_utc, tz = "UTC")
    return(rows)
  }
  if (any(is.na(rows$run_id)) ||
      any(as.character(rows$run_id) != as.character(run_id))) {
    ledgr_run_terminal_evidence_abort(
      sprintf("%s equity evidence belongs to a different run.", label)
    )
  }
  rows$run_id <- as.character(rows$run_id)
  rows$ts_utc <- as.POSIXct(rows$ts_utc, tz = "UTC")
  timestamp <- as.numeric(rows$ts_utc)
  calendar_timestamp <- as.numeric(as.POSIXct(calendar$pulses_posix, tz = "UTC"))
  if (anyNA(timestamp) || any(match(timestamp, calendar_timestamp, nomatch = 0L) == 0L)) {
    ledgr_run_terminal_evidence_abort(
      sprintf("%s equity evidence contains an out-of-calendar pulse.", label)
    )
  }
  if (length(timestamp) > 1L && any(diff(timestamp) < 0)) {
    ledgr_run_terminal_evidence_abort(
      sprintf("%s equity evidence is not monotone.", label)
    )
  }
  for (name in setdiff(columns, c("run_id", "ts_utc"))) {
    rows[[name]] <- as.numeric(rows[[name]])
  }
  rows
}

ledgr_run_equity_values_equal <- function(left, right) {
  left_na <- is.na(left)
  right_na <- is.na(right)
  same_missing <- left_na & right_na & (is.nan(left) == is.nan(right))
  same_value <- !left_na & !right_na & left == right
  same_missing | same_value
}

ledgr_run_equity_prefix_expected <- function(calendar, achieved_end_utc) {
  pulses <- as.POSIXct(calendar$pulses_posix, tz = "UTC")
  achieved_end <- as.POSIXct(achieved_end_utc, tz = "UTC")
  if (length(achieved_end) != 1L || is.na(achieved_end)) {
    return(pulses[FALSE])
  }
  if (!as.numeric(achieved_end) %in% as.numeric(pulses)) {
    ledgr_run_terminal_evidence_abort(
      "Equity-prefix end is outside the intended pulse calendar."
    )
  }
  pulses[pulses <= achieved_end]
}

ledgr_run_equity_prefix_merge <- function(prior,
                                          current,
                                          run_id,
                                          calendar,
                                          achieved_end_utc) {
  prior <- ledgr_run_equity_prefix_normalize(prior, run_id, calendar, "Prior")
  current <- ledgr_run_equity_prefix_normalize(current, run_id, calendar, "Current")
  combined <- rbind(prior, current)
  expected <- ledgr_run_equity_prefix_expected(calendar, achieved_end_utc)
  if (nrow(combined) == 0L) {
    if (length(expected) != 0L) {
      ledgr_run_terminal_evidence_abort(
        "Merged equity evidence does not contain its exact achieved prefix."
      )
    }
    return(combined)
  }

  timestamp <- as.numeric(combined$ts_utc)
  order_index <- order(timestamp, seq_along(timestamp))
  combined <- combined[order_index, , drop = FALSE]
  timestamp <- timestamp[order_index]
  repeated <- duplicated(timestamp)
  if (any(repeated)) {
    previous <- c(NA_integer_, seq_len(nrow(combined) - 1L))
    same_value <- rep(TRUE, nrow(combined))
    value_columns <- setdiff(
      ledgr_run_equity_prefix_columns(),
      c("run_id", "ts_utc")
    )
    for (name in value_columns) {
      same_value[repeated] <- same_value[repeated] &
        ledgr_run_equity_values_equal(
          combined[[name]][repeated],
          combined[[name]][previous[repeated]]
        )
    }
    if (any(repeated & !same_value)) {
      ledgr_run_terminal_evidence_abort(
        "Merged equity evidence contains conflicting duplicate pulses."
      )
    }
  }
  merged <- combined[!repeated, , drop = FALSE]
  rownames(merged) <- NULL
  if (!identical(as.numeric(merged$ts_utc), as.numeric(expected))) {
    ledgr_run_terminal_evidence_abort(
      "Merged equity evidence does not contain its exact achieved prefix."
    )
  }
  merged
}

ledgr_run_equity_prefix_commit <- function(con,
                                           run_id,
                                           current,
                                           calendar,
                                           achieved_end_utc = NULL,
                                           record_status = NULL) {
  DBI::dbWithTransaction(con, {
    current <- ledgr_run_equity_prefix_normalize(
      current,
      run_id,
      calendar,
      "Current"
    )
    prior <- current[0, , drop = FALSE]
    if (is.null(achieved_end_utc)) {
      prior <- ledgr_run_equity_prefix_read(con, run_id)
      candidate_timestamp <- c(
        as.numeric(as.POSIXct(prior$ts_utc, tz = "UTC")),
        as.numeric(current$ts_utc)
      )
      if (length(candidate_timestamp) == 0L) {
        achieved_end_utc <- as.POSIXct(NA_real_, origin = "1970-01-01", tz = "UTC")
      } else {
        achieved_end_utc <- as.POSIXct(
          max(candidate_timestamp),
          origin = "1970-01-01",
          tz = "UTC"
        )
      }
    } else {
      expected <- ledgr_run_equity_prefix_expected(calendar, achieved_end_utc)
      current_timestamp <- as.numeric(current$ts_utc[!duplicated(current$ts_utc)])
      if (!identical(current_timestamp, as.numeric(expected))) {
        prior <- ledgr_run_equity_prefix_read(con, run_id)
      }
    }
    merged <- ledgr_run_equity_prefix_merge(
      prior,
      current,
      run_id,
      calendar,
      achieved_end_utc
    )
    DBI::dbExecute(
      con,
      "DELETE FROM equity_curve WHERE run_id = ?",
      params = list(run_id)
    )
    if (nrow(merged) > 0L) {
      DBI::dbAppendTable(con, "equity_curve", merged)
    }
    if (is.function(record_status)) record_status()
    invisible(merged)
  })
}

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
  terminal_status <- fold$status %||% "DONE"
  fold_equity <- fold$equity_facts %||% list()
  use_fold_equity <- length(fold_equity) > 0L

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

    pulses_posix <- if (use_fold_equity) {
      as.POSIXct(vapply(fold_equity, function(x) as.numeric(x$ts_utc), numeric(1)), origin = "1970-01-01", tz = "UTC")
    } else {
      as.POSIXct(pulses, tz = "UTC")
    }
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
    cash_at <- if (use_fold_equity) {
      vapply(fold_equity, `[[`, numeric(1), "cash")
    } else {
      rep(as.numeric(initial_cash), length(idx))
    }
    has_event <- idx > 0
    if (!use_fold_equity && any(has_event)) {
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

    positions_value <- if (use_fold_equity) {
      vapply(fold_equity, `[[`, numeric(1), "positions_value")
    } else if (n_pulses > 0) {
      colSums(positions_mat * close_mat)
    } else {
      numeric(0)
    }

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

    realized_at <- if (use_fold_equity) {
      vapply(fold_equity, `[[`, numeric(1), "realized_pnl")
    } else {
      numeric(length(idx))
    }
    cost_basis_at <- if (use_fold_equity) {
      vapply(fold_equity, `[[`, numeric(1), "cost_basis")
    } else {
      numeric(length(idx))
    }
    if (!use_fold_equity && any(has_event)) {
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
    if (use_fold_equity) {
      completion <- ledgr_run_completion_read(con, run_id, required = TRUE)
      completion <- ledgr_run_completion_validate(completion, run_id, calendar)
      if (!identical(
        as.character(completion$intended_terminal_status[[1L]]),
        as.character(terminal_status)
      )) {
        ledgr_run_terminal_evidence_abort(
          "Fold status disagrees with terminal completion evidence."
        )
      }
      ledgr_run_equity_prefix_commit(
        con = con,
        run_id = run_id,
        current = eq_df,
        calendar = calendar,
        achieved_end_utc = completion$achieved_end_utc[[1L]],
        record_status = function() {
          output_handler$record_run_status(terminal_status, NA_character_)
        }
      )
    } else {
      DBI::dbWithTransaction(con, {
        DBI::dbExecute(con, "DELETE FROM equity_curve WHERE run_id = ?", params = list(run_id))
        if (nrow(eq_df) > 0) {
          DBI::dbAppendTable(con, "equity_curve", eq_df)
        }
        output_handler$record_run_status(terminal_status, NA_character_)
      })
    }
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
    status = terminal_status,
    telemetry = telemetry,
    processed = processed
  )

  list(
    status = terminal_status,
    telemetry = telemetry
  )
}
