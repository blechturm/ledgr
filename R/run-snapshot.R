ledgr_run_snapshot_guard <- function(con,
                                     snapshot_db_path,
                                     db_path,
                                     snapshot_id,
                                     instrument_ids,
                                     start_ts_utc,
                                     end_ts_utc,
                                     run_id,
                                     fail_run,
                                     availability_active = FALSE) {
  tryCatch(
    ledgr_prepare_snapshot_source_tables(con, snapshot_db_path, db_path),
    error = function(e) {
      fail_run(
        conditionMessage(e),
        class = "LEDGR_SNAPSHOT_SOURCE_ERROR"
      )
    }
  )

  snap <- DBI::dbGetQuery(
    con,
    "SELECT status, snapshot_hash FROM snapshots WHERE snapshot_id = ?",
    params = list(snapshot_id)
  )
  if (nrow(snap) != 1) {
    fail_run(
      sprintf("Snapshot not found: %s", snapshot_id),
      class = "LEDGR_SNAPSHOT_NOT_FOUND"
    )
  }
  if (!identical(snap$status[[1]], "SEALED")) {
    fail_run(
      paste0(
        "LEDGR_SNAPSHOT_NOT_SEALED: snapshot status must be SEALED ",
        "for backtests (got ", snap$status[[1]], ")."
      ),
      class = "LEDGR_SNAPSHOT_NOT_SEALED"
    )
  }
  stored_snapshot_hash <- snap$snapshot_hash[[1]]
  if (!is.character(stored_snapshot_hash) ||
    length(stored_snapshot_hash) != 1 ||
    is.na(stored_snapshot_hash) ||
    !nzchar(stored_snapshot_hash)) {
    fail_run(
      paste0(
        "LEDGR_SNAPSHOT_NOT_SEALED: SEALED snapshot is missing ",
        "snapshot_hash."
      ),
      class = "LEDGR_SNAPSHOT_NOT_SEALED"
    )
  }

  recomputed <- ledgr_snapshot_hash(con, snapshot_id)
  if (!identical(recomputed, stored_snapshot_hash)) {
    fail_run(
      paste0(
        "LEDGR_SNAPSHOT_CORRUPTED: stored snapshot_hash does not match ",
        "recomputed hash."
      ),
      class = "LEDGR_SNAPSHOT_CORRUPTED"
    )
  }

  ids_sql <- paste(
    DBI::dbQuoteString(con, instrument_ids),
    collapse = ", "
  )
  missing_inst <- DBI::dbGetQuery(
    con,
    paste0(
      "SELECT u.instrument_id FROM ",
      "(SELECT UNNEST([", ids_sql, "]) AS instrument_id) u ",
      "LEFT JOIN snapshot_instruments si ",
      "ON si.instrument_id = u.instrument_id AND si.snapshot_id = ? ",
      "WHERE si.instrument_id IS NULL"
    ),
    params = list(snapshot_id)
  )$instrument_id
  if (length(missing_inst) > 0) {
    fail_run(
      paste0(
        "LEDGR_SNAPSHOT_COVERAGE_ERROR: universe instruments not present ",
        "in snapshot_instruments: ", paste(missing_inst, collapse = ", ")
      ),
      class = "LEDGR_SNAPSHOT_COVERAGE_ERROR"
    )
  }

  start_iso <- ledgr_normalize_ts_utc(start_ts_utc)
  end_iso <- ledgr_normalize_ts_utc(end_ts_utc)
  start_str <- sub("Z$", "", sub("T", " ", start_iso))
  end_str <- sub("Z$", "", sub("T", " ", end_iso))

  pulses <- DBI::dbGetQuery(
    con,
    paste0(
      "SELECT DISTINCT ts_utc FROM snapshot_bars ",
      "WHERE snapshot_id = ? AND instrument_id IN (", ids_sql, ") ",
      "AND ts_utc >= CAST(? AS TIMESTAMP) ",
      "AND ts_utc <= CAST(? AS TIMESTAMP) ",
      "ORDER BY ts_utc"
    ),
    params = list(snapshot_id, start_str, end_str)
  )$ts_utc
  if (length(pulses) == 0) {
    fail_run(
      paste0(
        "LEDGR_SNAPSHOT_COVERAGE_ERROR: no bars found in snapshot for ",
        "requested universe/time range."
      ),
      class = "LEDGR_SNAPSHOT_COVERAGE_ERROR"
    )
  }
  if (!isTRUE(availability_active) && length(pulses) < 2L) {
    fail_run(
      paste0(
        "Execution window must contain at least two pulses for next-bar ",
        "fill semantics."
      ),
      class = "ledgr_run_window_too_short"
    )
  }

  coverage <- DBI::dbGetQuery(
    con,
    paste0(
      "SELECT instrument_id, COUNT(*) AS n ",
      "FROM snapshot_bars ",
      "WHERE snapshot_id = ? AND instrument_id IN (", ids_sql, ") ",
      "AND ts_utc >= CAST(? AS TIMESTAMP) ",
      "AND ts_utc <= CAST(? AS TIMESTAMP) ",
      "GROUP BY instrument_id"
    ),
    params = list(snapshot_id, start_str, end_str)
  )
  if (!isTRUE(availability_active) &&
      (nrow(coverage) != length(instrument_ids) ||
       any(as.integer(coverage$n) < length(pulses)))) {
    missing_ids <- setdiff(
      instrument_ids,
      as.character(coverage$instrument_id)
    )
    msg <- paste0(
      "LEDGR_SNAPSHOT_COVERAGE_ERROR: per-instrument bars coverage is ",
      "incomplete for requested range."
    )
    if (length(missing_ids) > 0) {
      msg <- paste0(
        msg,
        " Missing instruments: ",
        paste(missing_ids, collapse = ", "),
        "."
      )
    }
    fail_run(msg, class = "LEDGR_SNAPSHOT_COVERAGE_ERROR")
  }

  ledgr_prepare_snapshot_runtime_views(
    con,
    snapshot_id,
    instrument_ids,
    start_ts_utc,
    end_ts_utc
  )
  DBI::dbExecute(
    con,
    "UPDATE runs SET snapshot_id = ? WHERE run_id = ?",
    params = list(snapshot_id, run_id)
  )

  list(snapshot_hash = stored_snapshot_hash)
}

ledgr_run_snapshot_calendar <- function(con,
                                        instrument_ids,
                                        start_ts_utc,
                                        end_ts_utc) {
  pulses <- ledgr_pulse_timestamps(
    con,
    instrument_ids,
    start_ts_utc,
    end_ts_utc
  )
  pulses_posix <- as.POSIXct(pulses, tz = "UTC")
  pulses_iso <- format(
    pulses_posix,
    "%Y-%m-%dT%H:%M:%SZ",
    tz = "UTC"
  )

  list(
    pulses = pulses,
    pulses_posix = pulses_posix,
    pulses_iso = pulses_iso
  )
}
