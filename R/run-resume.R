ledgr_run_resume_preflight <- function(is_resume, strategy_preflight) {
  if (isTRUE(is_resume)) {
    ledgr_abort_strategy_ambient_rng_for_resume(strategy_preflight)
  }
  invisible(TRUE)
}

ledgr_run_resume <- function(con,
                             output_handler,
                             run_id,
                             is_resume,
                             calendar,
                             persist_features,
                             start_ts_utc,
                             opening_positions,
                             opening_cost_basis) {
  fail_run <- output_handler$abort_run
  pulses <- calendar$pulses
  pulses_posix <- calendar$pulses_posix
  pulses_iso <- calendar$pulses_iso

  resume_posix <- pulses_posix[[1]]
  resume_iso <- pulses_iso[[1]]
  resume_exec_posix <- pulses_posix[[2]]
  start_idx <- 1L
  finalization_only_resume <- FALSE

  if (is_resume) {
    last_state <- DBI::dbGetQuery(
      con,
      "SELECT MAX(ts_utc) AS ts_utc FROM strategy_state WHERE run_id = ?",
      params = list(run_id)
    )$ts_utc[[1]]

    if (length(last_state) == 1 && !is.na(last_state)) {
      last_posix <- NULL
      if (inherits(last_state, "POSIXt")) {
        last_posix <- as.POSIXct(last_state, tz = "UTC")
      } else if (is.numeric(last_state)) {
        last_posix <- as.POSIXct(last_state, origin = "1970-01-01", tz = "UTC")
      } else if (is.character(last_state) && nzchar(last_state)) {
        last_posix <- as.POSIXct(last_state, tz = "UTC", tryFormats = c("%Y-%m-%dT%H:%M:%SZ", "%Y-%m-%d %H:%M:%S"))
      }
      if (is.null(last_posix) || is.na(last_posix)) {
        fail_run("Invalid strategy_state.ts_utc encountered; cannot resume deterministically.")
      }

      last_idx <- max(which(pulses_posix <= last_posix))
      if (!is.finite(last_idx) || is.na(last_idx) || last_idx < 1) {
        fail_run("strategy_state contains a timestamp not present in pulse calendar; cannot resume deterministically.")
      }

      start_idx <- as.integer(last_idx) + 1L
      if (start_idx <= length(pulses)) {
        resume_posix <- pulses_posix[[start_idx]]
        resume_iso <- pulses_iso[[start_idx]]
        resume_exec_posix <- if (start_idx < length(pulses_posix)) pulses_posix[[start_idx + 1L]] else as.POSIXct(NA_real_, origin = "1970-01-01", tz = "UTC")
      } else {
        finalization_only_resume <- TRUE
        resume_exec_posix <- as.POSIXct(NA_real_, origin = "1970-01-01", tz = "UTC")
      }
    } else {
      start_idx <- 1L
      resume_posix <- pulses_posix[[1]]
      resume_iso <- pulses_iso[[1]]
      resume_exec_posix <- if (length(pulses_posix) >= 2) pulses_posix[[2]] else as.POSIXct(NA_real_, origin = "1970-01-01", tz = "UTC")
    }

    # Resume cleanup removes prior tail rows that could create alternate outputs.
    # A post-fold failure has no uncommitted fold tail to remove.
    if (!isTRUE(finalization_only_resume)) {
      DBI::dbWithTransaction(con, {
        if (!is.na(resume_exec_posix)) {
          DBI::dbExecute(con, "DELETE FROM ledger_events WHERE run_id = ? AND ts_utc >= ?", params = list(run_id, resume_exec_posix))
        }
        if (isTRUE(persist_features)) {
          DBI::dbExecute(con, "DELETE FROM features WHERE run_id = ? AND ts_utc >= ?", params = list(run_id, resume_posix))
        }
        DBI::dbExecute(con, "DELETE FROM equity_curve WHERE run_id = ? AND ts_utc >= ?", params = list(run_id, resume_posix))
        DBI::dbExecute(con, "DELETE FROM strategy_state WHERE run_id = ? AND ts_utc >= ?", params = list(run_id, resume_iso))
      })
    }
  }

  next_event_seq <- DBI::dbGetQuery(
    con,
    "SELECT COALESCE(MAX(event_seq), 0) + 1 AS next_seq FROM ledger_events WHERE run_id = ?",
    params = list(run_id)
  )$next_seq[[1]]
  next_event_seq <- as.integer(next_event_seq)
  if (!is_resume && length(opening_positions) > 0L) {
    next_event_seq <- ledgr_write_opening_position_events(
      con = con,
      run_id = run_id,
      ts_utc = start_ts_utc,
      positions = opening_positions,
      cost_basis = opening_cost_basis,
      event_seq_start = next_event_seq
    )
  }

  list(
    resume_posix = resume_posix,
    resume_iso = resume_iso,
    resume_exec_posix = resume_exec_posix,
    start_idx = start_idx,
    finalization_only_resume = finalization_only_resume,
    next_event_seq = next_event_seq
  )
}
