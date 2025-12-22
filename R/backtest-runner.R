#' Run a deterministic EOD backtest (v0.1.0)
#'
#' Executes the v0.1.0 EOD pulse loop against a DuckDB database preloaded with
#' `instruments` and `bars`, writing derived outputs back to the same database.
#'
#' @param config A config list (or JSON string) matching the v0.1.0 config contract.
#' @param run_id Optional run identifier to resume or reuse.
#' @return A list with `run_id` and `db_path`.
#' @export
ledgr_backtest_run <- function(config, run_id = NULL) {
  ledgr_backtest_run_internal(config = config, run_id = run_id, control = list())
}

.ledgr_telemetry_registry <- new.env(parent = emptyenv())

ledgr_time_now <- function() {
  if (requireNamespace("nanotime", quietly = TRUE)) {
    return(nanotime::nanotime())
  }
  proc.time()[[3]]
}

ledgr_time_elapsed <- function(start, end) {
  if (inherits(start, "nanotime")) {
    return(as.numeric(end - start) / 1e9)
  }
  as.numeric(end - start)
}

ledgr_store_run_telemetry <- function(run_id, telemetry) {
  if (is.character(run_id) && length(run_id) == 1 && nzchar(run_id)) {
    assign(run_id, telemetry, envir = .ledgr_telemetry_registry)
  }
  invisible(TRUE)
}

ledgr_get_run_telemetry <- function(run_id) {
  if (!is.character(run_id) || length(run_id) != 1 || !nzchar(run_id)) return(NULL)
  if (!exists(run_id, envir = .ledgr_telemetry_registry, inherits = FALSE)) return(NULL)
  get(run_id, envir = .ledgr_telemetry_registry, inherits = FALSE)
}

ledgr_backtest_run_internal <- function(config, run_id = NULL, control = list()) {
  ledgr_validate_config(config)

  cfg <- if (is.character(config)) {
    jsonlite::fromJSON(config, simplifyVector = TRUE, simplifyDataFrame = FALSE, simplifyMatrix = FALSE)
  } else {
    config
  }
  if (!is.list(cfg)) {
    rlang::abort("`config` must be a list (or JSON string).", class = "ledgr_invalid_config")
  }

  db_path <- cfg$db_path
  instrument_ids <- cfg$universe$instrument_ids
  start_ts_utc <- cfg$backtest$start_ts_utc
  end_ts_utc <- cfg$backtest$end_ts_utc
  initial_cash <- as.numeric(cfg$backtest$initial_cash)
  seed <- as.integer(cfg$engine$seed)

  snapshot_id <- NULL
  if (!is.null(cfg$data) && is.list(cfg$data) && identical(cfg$data$source, "snapshot")) {
    snapshot_id <- cfg$data$snapshot_id
  }
  if (!is.null(snapshot_id)) {
    if (!is.character(snapshot_id) || length(snapshot_id) != 1 || is.na(snapshot_id) || !nzchar(snapshot_id)) {
      rlang::abort("config$data$snapshot_id must be a non-empty string when data.source == 'snapshot'.", class = "ledgr_invalid_config")
    }
  }

  set.seed(seed)

  opened <- ledgr_open_duckdb_with_retry(db_path)
  drv <- opened$drv
  con <- opened$con
  on.exit(suppressWarnings(try(duckdb::duckdb_shutdown(drv), silent = TRUE)), add = TRUE)
  on.exit(suppressWarnings(try(DBI::dbDisconnect(con, shutdown = TRUE), silent = TRUE)), add = TRUE)

  ledgr_create_schema(con)
  ledgr_validate_schema(con)

  config_json <- canonical_json(cfg)
  cfg_hash <- config_hash(cfg)

  if (is.null(run_id)) {
    if (!is.null(cfg$run_id) && is.character(cfg$run_id) && length(cfg$run_id) == 1 && nzchar(cfg$run_id) && !is.na(cfg$run_id)) {
      run_id <- cfg$run_id
    } else {
      run_id <- paste0(
        "run_",
        substr(digest::digest(paste0(cfg_hash, ":", seed), algo = "sha256"), 1, 16)
      )
    }
  }

  if (!is.character(run_id) || length(run_id) != 1 || is.na(run_id) || !nzchar(run_id)) {
    rlang::abort("`run_id` must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }

  engine_version <- as.character(utils::packageVersion("ledgr"))

  run_row <- DBI::dbGetQuery(
    con,
    "SELECT run_id, status, config_hash, data_hash, snapshot_id FROM runs WHERE run_id = ?",
    params = list(run_id)
  )

  is_resume <- nrow(run_row) > 0

  if (!is_resume) {
    run_snapshot_id <- if (is.null(snapshot_id)) NA_character_ else snapshot_id
    DBI::dbExecute(
      con,
      "
      INSERT INTO runs (
        run_id,
        created_at_utc,
        engine_version,
        config_json,
        config_hash,
        data_hash,
        snapshot_id,
        status,
        error_msg
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ",
      params = list(
        run_id,
        as.POSIXct(Sys.time(), tz = "UTC"),
        engine_version,
        config_json,
        cfg_hash,
        NA_character_,
        run_snapshot_id,
        "CREATED",
        NA_character_
      )
    )
  } else {
    stored_cfg_hash <- run_row$config_hash[[1]]
    if (!identical(stored_cfg_hash, cfg_hash)) {
      rlang::abort("Refusing to resume: config_hash does not match stored run.", class = "ledgr_run_hash_mismatch")
    }
    stored_snapshot_id <- run_row$snapshot_id[[1]]
    if (!is.null(snapshot_id)) {
      if (!is.character(stored_snapshot_id) || length(stored_snapshot_id) != 1 || is.na(stored_snapshot_id) || !nzchar(stored_snapshot_id)) {
        rlang::abort("Refusing to resume: stored run has no snapshot_id.", class = "ledgr_run_hash_mismatch")
      }
      if (!identical(stored_snapshot_id, snapshot_id)) {
        rlang::abort("Refusing to resume: snapshot_id does not match stored run.", class = "ledgr_run_hash_mismatch")
      }
    }
    if (identical(run_row$status[[1]], "DONE")) {
      return(list(run_id = run_id, db_path = db_path))
    }
  }

  fail_run <- function(msg, class = "ledgr_run_failed") {
    DBI::dbExecute(
      con,
      "UPDATE runs SET status = ?, error_msg = ? WHERE run_id = ?",
      params = list("FAILED", msg, run_id)
    )
    rlang::abort(msg, class = class)
  }

  # v0.1.1 snapshot integration:
  # - verify snapshot status SEALED
  # - tamper detection: recompute hash and compare
  # - enforce universe subset and coverage
  # - create TEMP VIEW instruments/bars so v0.1.0 pipeline reads snapshot data
  if (!is.null(snapshot_id)) {
    snap <- DBI::dbGetQuery(
      con,
      "SELECT status, snapshot_hash FROM snapshots WHERE snapshot_id = ?",
      params = list(snapshot_id)
    )
    if (nrow(snap) != 1) {
      fail_run(sprintf("Snapshot not found: %s", snapshot_id), class = "LEDGR_SNAPSHOT_NOT_FOUND")
    }
    if (!identical(snap$status[[1]], "SEALED")) {
      fail_run(
        sprintf("LEDGR_SNAPSHOT_NOT_SEALED: snapshot status must be SEALED for backtests (got %s).", snap$status[[1]]),
        class = "LEDGR_SNAPSHOT_NOT_SEALED"
      )
    }
    stored_snapshot_hash <- snap$snapshot_hash[[1]]
    if (!is.character(stored_snapshot_hash) || length(stored_snapshot_hash) != 1 || is.na(stored_snapshot_hash) || !nzchar(stored_snapshot_hash)) {
      fail_run("LEDGR_SNAPSHOT_NOT_SEALED: SEALED snapshot is missing snapshot_hash.", class = "LEDGR_SNAPSHOT_NOT_SEALED")
    }

    recomputed <- ledgr_snapshot_hash(con, snapshot_id)
    if (!identical(recomputed, stored_snapshot_hash)) {
      fail_run("LEDGR_SNAPSHOT_CORRUPTED: stored snapshot_hash does not match recomputed hash.", class = "LEDGR_SNAPSHOT_CORRUPTED")
    }

    ids_sql <- paste(DBI::dbQuoteString(con, instrument_ids), collapse = ", ")
    missing_inst <- DBI::dbGetQuery(
      con,
      paste0(
        "SELECT u.instrument_id FROM (SELECT UNNEST([", ids_sql, "]) AS instrument_id) u ",
        "LEFT JOIN snapshot_instruments si ON si.instrument_id = u.instrument_id AND si.snapshot_id = ? ",
        "WHERE si.instrument_id IS NULL"
      ),
      params = list(snapshot_id)
    )$instrument_id
    if (length(missing_inst) > 0) {
      fail_run(
        sprintf("LEDGR_SNAPSHOT_COVERAGE_ERROR: universe instruments not present in snapshot_instruments: %s", paste(missing_inst, collapse = ", ")),
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
        "AND ts_utc >= CAST(? AS TIMESTAMP) AND ts_utc <= CAST(? AS TIMESTAMP) ",
        "ORDER BY ts_utc"
      ),
      params = list(snapshot_id, start_str, end_str)
    )$ts_utc
    if (length(pulses) == 0) {
      fail_run("LEDGR_SNAPSHOT_COVERAGE_ERROR: no bars found in snapshot for requested universe/time range.", class = "LEDGR_SNAPSHOT_COVERAGE_ERROR")
    }

    coverage <- DBI::dbGetQuery(
      con,
      paste0(
        "SELECT instrument_id, COUNT(*) AS n ",
        "FROM snapshot_bars ",
        "WHERE snapshot_id = ? AND instrument_id IN (", ids_sql, ") ",
        "AND ts_utc >= CAST(? AS TIMESTAMP) AND ts_utc <= CAST(? AS TIMESTAMP) ",
        "GROUP BY instrument_id"
      ),
      params = list(snapshot_id, start_str, end_str)
    )
    if (nrow(coverage) != length(instrument_ids) || any(as.integer(coverage$n) < length(pulses))) {
      missing_ids <- setdiff(instrument_ids, as.character(coverage$instrument_id))
      msg <- "LEDGR_SNAPSHOT_COVERAGE_ERROR: per-instrument bars coverage is incomplete for requested range."
      if (length(missing_ids) > 0) {
        msg <- paste0(msg, " Missing instruments: ", paste(missing_ids, collapse = ", "), ".")
      }
      fail_run(msg, class = "LEDGR_SNAPSHOT_COVERAGE_ERROR")
    }

    # Snapshot-backed sourcing via TEMP VIEWs that shadow v0.1.0 tables.
    try(DBI::dbExecute(con, "DROP VIEW IF EXISTS temp.instruments"), silent = TRUE)
    try(DBI::dbExecute(con, "DROP VIEW IF EXISTS temp.bars"), silent = TRUE)

    DBI::dbExecute(
      con,
      paste0(
        "CREATE TEMP VIEW instruments AS ",
        "SELECT instrument_id, symbol, currency, asset_class ",
        "FROM snapshot_instruments ",
        "WHERE snapshot_id = ", DBI::dbQuoteString(con, snapshot_id), " ",
        "AND instrument_id IN (", ids_sql, ")"
      )
    )
    DBI::dbExecute(
      con,
      paste0(
        "CREATE TEMP VIEW bars AS ",
        "SELECT instrument_id, ts_utc, open, high, low, close, volume, ",
        "CAST('NONE' AS TEXT) AS gap_type, CAST(FALSE AS BOOLEAN) AS is_synthetic ",
        "FROM snapshot_bars ",
        "WHERE snapshot_id = ", DBI::dbQuoteString(con, snapshot_id), " ",
        "AND instrument_id IN (", ids_sql, ") ",
        "AND ts_utc >= CAST(", DBI::dbQuoteString(con, start_str), " AS TIMESTAMP) ",
        "AND ts_utc <= CAST(", DBI::dbQuoteString(con, end_str), " AS TIMESTAMP)"
      )
    )

    DBI::dbExecute(con, "UPDATE runs SET snapshot_id = ? WHERE run_id = ?", params = list(snapshot_id, run_id))
  }

  # Validate run-relevant bars subset is sane per spec (v0.1.0 fail-loud).
  validate_bars_subset <- function() {
    start_iso <- ledgr_normalize_ts_utc(start_ts_utc)
    end_iso <- ledgr_normalize_ts_utc(end_ts_utc)
    start_str <- sub("Z$", "", sub("T", " ", start_iso))
    end_str <- sub("Z$", "", sub("T", " ", end_iso))
    ids_sql <- paste(DBI::dbQuoteString(con, instrument_ids), collapse = ", ")

    counts <- DBI::dbGetQuery(
      con,
      paste0(
        "SELECT instrument_id, COUNT(*) AS n ",
        "FROM bars ",
        "WHERE instrument_id IN (", ids_sql, ") ",
        "AND ts_utc >= CAST(? AS TIMESTAMP) AND ts_utc <= CAST(? AS TIMESTAMP) ",
        "GROUP BY instrument_id"
      ),
      params = list(start_str, end_str)
    )

    if (nrow(counts) != length(instrument_ids) || any(counts$n < 2)) {
      rlang::abort("Bars must include at least 2 rows per instrument in the requested range.", class = "ledgr_bad_bars")
    }

    bars <- DBI::dbGetQuery(
      con,
      paste0(
        "SELECT instrument_id, ts_utc, open, high, low, close ",
        "FROM bars ",
        "WHERE instrument_id IN (", ids_sql, ") ",
        "AND ts_utc >= CAST(? AS TIMESTAMP) AND ts_utc <= CAST(? AS TIMESTAMP) ",
        "ORDER BY instrument_id, ts_utc"
      ),
      params = list(start_str, end_str)
    )
    if (nrow(bars) == 0) rlang::abort("No bars found for requested universe/time range.", class = "ledgr_bad_bars")

    bad <- which(
      !(bars$high >= pmax(bars$open, bars$close, bars$low, na.rm = TRUE)) |
        !(bars$low <= pmin(bars$open, bars$close, bars$high, na.rm = TRUE))
    )
    if (length(bad) > 0) {
      rlang::abort("Bars contain an OHLC violation (high/low bounds).", class = "ledgr_bad_bars")
    }

    invisible(TRUE)
  }

  data_hash <- tryCatch(
    {
      validate_bars_subset()
      ledgr_data_hash(con, instrument_ids, start_ts_utc, end_ts_utc)
    },
    error = function(e) {
      fail_run(conditionMessage(e))
    }
  )

  if (is_resume) {
    stored_data_hash <- run_row$data_hash[[1]]
    if (!identical(stored_data_hash, data_hash)) {
      fail_run("Refusing to resume: data_hash does not match stored run.")
    }
  }

  DBI::dbExecute(con, "UPDATE runs SET data_hash = ? WHERE run_id = ?", params = list(data_hash, run_id))

  feature_defs <- ledgr_feature_defs_from_config(cfg)

  strategy <- ledgr_strategy_from_config(cfg)

  pulses <- ledgr_pulse_timestamps(con, instrument_ids, start_ts_utc, end_ts_utc)

  resume_posix <- pulses[[1]]
  resume_iso <- ledgr_normalize_ts_utc(resume_posix)
  resume_exec_posix <- pulses[[2]]
  start_idx <- 1L

  if (is_resume) {
    last_state <- DBI::dbGetQuery(
      con,
      "SELECT MAX(ts_utc) AS ts_utc FROM strategy_state WHERE run_id = ?",
      params = list(run_id)
    )$ts_utc[[1]]

    if (is.character(last_state) && length(last_state) == 1 && !is.na(last_state) && nzchar(last_state)) {
      last_posix <- as.POSIXct(last_state, tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ")
      if (is.na(last_posix)) {
        fail_run("Invalid strategy_state.ts_utc encountered; cannot resume deterministically.")
      }

      last_idx <- max(which(pulses <= last_posix))
      if (!is.finite(last_idx) || is.na(last_idx) || last_idx < 1) {
        fail_run("strategy_state contains a timestamp not present in pulse calendar; cannot resume deterministically.")
      }

      start_idx <- as.integer(last_idx) + 1L
      if (start_idx <= length(pulses)) {
        resume_posix <- pulses[[start_idx]]
        resume_iso <- ledgr_normalize_ts_utc(resume_posix)
        resume_exec_posix <- if (start_idx < length(pulses)) pulses[[start_idx + 1L]] else as.POSIXct(NA_real_, origin = "1970-01-01", tz = "UTC")
      } else {
        resume_exec_posix <- as.POSIXct(NA_real_, origin = "1970-01-01", tz = "UTC")
      }
    } else {
      start_idx <- 1L
      resume_posix <- pulses[[1]]
      resume_iso <- ledgr_normalize_ts_utc(resume_posix)
      resume_exec_posix <- if (length(pulses) >= 2) pulses[[2]] else as.POSIXct(NA_real_, origin = "1970-01-01", tz = "UTC")
    }

    # Resume cleanup: remove any previously written tail rows to avoid alternate-reality outputs.
    DBI::dbWithTransaction(con, {
      if (!is.na(resume_exec_posix)) {
        DBI::dbExecute(con, "DELETE FROM ledger_events WHERE run_id = ? AND ts_utc >= ?", params = list(run_id, resume_exec_posix))
      }
      DBI::dbExecute(con, "DELETE FROM features WHERE run_id = ? AND ts_utc >= ?", params = list(run_id, resume_posix))
      DBI::dbExecute(con, "DELETE FROM equity_curve WHERE run_id = ? AND ts_utc >= ?", params = list(run_id, resume_posix))
      DBI::dbExecute(con, "DELETE FROM strategy_state WHERE run_id = ? AND ts_utc >= ?", params = list(run_id, resume_iso))
    })
  }

  next_event_seq <- DBI::dbGetQuery(
    con,
    "SELECT COALESCE(MAX(event_seq), 0) + 1 AS next_seq FROM ledger_events WHERE run_id = ?",
    params = list(run_id)
  )$next_seq[[1]]
  next_event_seq <- as.integer(next_event_seq)

  max_pulses <- control$max_pulses
  if (is.null(max_pulses)) max_pulses <- Inf

  DBI::dbExecute(con, "UPDATE runs SET status = ?, error_msg = ? WHERE run_id = ?", params = list("RUNNING", NA_character_, run_id))

  processed <- 0L
  total_pulses <- length(pulses) - start_idx + 1L
  if (total_pulses < 0) total_pulses <- 0L
  telemetry_cap <- total_pulses
  if (is.finite(max_pulses)) {
    telemetry_cap <- min(telemetry_cap, as.integer(max_pulses))
  }
  telemetry <- list(
    t_state = if (telemetry_cap > 0) numeric(telemetry_cap) else numeric(0),
    t_feats = if (telemetry_cap > 0) numeric(telemetry_cap) else numeric(0),
    t_strat = if (telemetry_cap > 0) numeric(telemetry_cap) else numeric(0),
    t_exec = if (telemetry_cap > 0) numeric(telemetry_cap) else numeric(0)
  )
  telemetry_idx <- 0L

  current_state <- list(cash = as.numeric(initial_cash), positions = numeric(0))
  last_event_seq_applied <- 0L

  run_ok <- tryCatch(
    {
      for (i in seq(from = start_idx, to = length(pulses))) {
        if (processed >= max_pulses) break

        ts <- pulses[[i]]
        ts_iso <- ledgr_normalize_ts_utc(ts)

        t_state <- 0
        t_feats <- 0
        t_strat <- 0
        t_exec <- 0

        DBI::dbWithTransaction(con, {
          bars <- DBI::dbGetQuery(
            con,
            sprintf(
              "
              SELECT instrument_id, ts_utc, open, high, low, close, volume, gap_type, is_synthetic
              FROM bars
              WHERE instrument_id IN (%s) AND ts_utc = ?
              ORDER BY instrument_id
              ",
              paste(DBI::dbQuoteString(con, instrument_ids), collapse = ", ")
            ),
            params = list(ts)
          )

          if (nrow(bars) != length(instrument_ids)) {
            rlang::abort(
              sprintf("Missing bars for universe at ts_utc=%s.", ts_iso),
              class = "ledgr_missing_bars"
            )
          }

          t_state_start <- ledgr_time_now()
          state_update <- ledgr_update_state_incremental(con, run_id, last_event_seq_applied, ts, current_state)
          current_state <<- state_update$state
          last_event_seq_applied <<- state_update$last_event_seq
          t_state <<- ledgr_time_elapsed(t_state_start, ledgr_time_now())

          feat_df <- data.frame()
          if (length(feature_defs) > 0) {
            t_feats_start <- ledgr_time_now()
            feat_df <- ledgr_features_at_pulse(con, run_id, instrument_ids, start_ts_utc, ts, feature_defs)
            t_feats <<- ledgr_time_elapsed(t_feats_start, ledgr_time_now())
          }

          positions_value <- 0
          if (!is.null(current_state$positions) && length(current_state$positions) > 0) {
            close_by_id <- stats::setNames(as.numeric(bars$close), bars$instrument_id)
            pos_ids <- intersect(names(current_state$positions), names(close_by_id))
            if (length(pos_ids) > 0) {
              positions_value <- sum(as.numeric(current_state$positions[pos_ids]) * close_by_id[pos_ids])
            }
          }

          state_prev <- ledgr_strategy_state_prev(con, run_id, ts_iso)

          ctx <- ledgr_pulse_context(
            run_id = run_id,
            ts_utc = ts_iso,
            universe = instrument_ids,
            bars = bars,
            features = feat_df,
            positions = current_state$positions,
            cash = current_state$cash,
            equity = current_state$cash + positions_value,
            state_prev = state_prev
          )

          t_strat_start <- ledgr_time_now()
          result <- strategy$on_pulse(ctx)
          t_strat <<- ledgr_time_elapsed(t_strat_start, ledgr_time_now())
          targets <- result$targets

          if (!is.null(result$state_update)) {
            state_json <- canonical_json(result$state_update)
            DBI::dbExecute(
              con,
              "INSERT INTO strategy_state (run_id, ts_utc, state_json) VALUES (?, ?, ?)",
              params = list(run_id, ts_iso, state_json)
            )
          }

          t_exec_start <- ledgr_time_now()
          for (instrument_id in instrument_ids) {
            cur_qty <- 0
            if (!is.null(current_state$positions) && length(current_state$positions) > 0 && instrument_id %in% names(current_state$positions)) {
              cur_qty <- as.numeric(current_state$positions[[instrument_id]])
            }
            target_qty <- as.numeric(targets[[instrument_id]])
            delta <- target_qty - cur_qty
            if (isTRUE(all.equal(delta, 0, tolerance = 0))) next

            next_bar <- DBI::dbGetQuery(
              con,
              "
              SELECT instrument_id, ts_utc, open
              FROM bars
              WHERE instrument_id = ? AND ts_utc > ?
              ORDER BY ts_utc
              LIMIT 1
              ",
              params = list(instrument_id, ts)
            )

            next_bar_row <- NULL
            if (nrow(next_bar) == 1) {
              next_bar_row <- list(
                instrument_id = next_bar$instrument_id[[1]],
                ts_utc = next_bar$ts_utc[[1]],
                open = next_bar$open[[1]]
              )
            }

            fill <- ledgr_fill_next_open(
              desired_qty_delta = delta,
              next_bar = next_bar_row,
              spread_bps = cfg$fill_model$spread_bps,
              commission_fixed = cfg$fill_model$commission_fixed
            )

            if (inherits(fill, "ledgr_fill_none") && is.character(fill$warn_code) && identical(fill$warn_code, "LEDGR_LAST_BAR_NO_FILL")) {
              warning("LEDGR_LAST_BAR_NO_FILL", call. = FALSE)
            }

            write_res <- ledgr_write_fill_events(con, run_id, fill, event_seq_start = next_event_seq, use_transaction = FALSE)
            if (inherits(write_res, "ledgr_ledger_write_result") && identical(write_res$status, "WROTE")) {
              next_event_seq <- write_res$next_event_seq
            }
          }
          t_exec <<- ledgr_time_elapsed(t_exec_start, ledgr_time_now())
        })

        if (telemetry_idx < length(telemetry$t_state)) {
          telemetry_idx <- telemetry_idx + 1L
          telemetry$t_state[[telemetry_idx]] <- t_state
          telemetry$t_feats[[telemetry_idx]] <- t_feats
          telemetry$t_strat[[telemetry_idx]] <- t_strat
          telemetry$t_exec[[telemetry_idx]] <- t_exec
        }

        processed <- processed + 1L
      }

      TRUE
    },
    error = function(e) {
      DBI::dbExecute(
        con,
        "UPDATE runs SET status = ?, error_msg = ? WHERE run_id = ?",
        params = list("FAILED", conditionMessage(e), run_id)
      )
      stop(e)
    }
  )

  finalize_telemetry <- function() {
    trimmed <- lapply(telemetry, function(x) {
      if (telemetry_idx > 0) x[seq_len(telemetry_idx)] else numeric(0)
    })
    ledgr_store_run_telemetry(run_id, trimmed)
    invisible(TRUE)
  }

  if (isTRUE(run_ok) && is.finite(max_pulses) && processed >= max_pulses) {
    # Simulated interruption for tests.
    finalize_telemetry()
    return(list(run_id = run_id, db_path = db_path))
  }

  ledgr_rebuild_derived_state(con, run_id, initial_cash)

  DBI::dbExecute(
    con,
    "UPDATE runs SET status = ?, error_msg = ? WHERE run_id = ?",
    params = list("DONE", NA_character_, run_id)
  )

  finalize_telemetry()

  list(run_id = run_id, db_path = db_path)
}

ledgr_pulse_timestamps <- function(con, instrument_ids, start_ts_utc, end_ts_utc) {
  start_iso <- ledgr_normalize_ts_utc(start_ts_utc)
  end_iso <- ledgr_normalize_ts_utc(end_ts_utc)
  start_str <- sub("Z$", "", sub("T", " ", start_iso))
  end_str <- sub("Z$", "", sub("T", " ", end_iso))

  ids_sql <- paste(DBI::dbQuoteString(con, instrument_ids), collapse = ", ")
  ts_raw <- DBI::dbGetQuery(
    con,
    paste0(
      "SELECT DISTINCT ts_utc FROM bars ",
      "WHERE instrument_id IN (", ids_sql, ") ",
      "AND ts_utc >= CAST(? AS TIMESTAMP) AND ts_utc <= CAST(? AS TIMESTAMP) ",
      "ORDER BY ts_utc"
    ),
    params = list(start_str, end_str)
  )$ts_utc

  if (length(ts_raw) == 0) {
    rlang::abort("No bars found for requested universe/time range.", class = "ledgr_missing_bars")
  }

  ts <- if (inherits(ts_raw, "POSIXt")) {
    as.POSIXct(ts_raw, tz = "UTC")
  } else if (is.numeric(ts_raw)) {
    as.POSIXct(ts_raw, origin = "1970-01-01", tz = "UTC")
  } else {
    as.POSIXct(ts_raw, tz = "UTC")
  }

  for (t in ts) {
    n <- DBI::dbGetQuery(
      con,
      paste0(
        "SELECT COUNT(*) AS n FROM bars WHERE instrument_id IN (",
        ids_sql,
        ") AND ts_utc = ?"
      ),
      params = list(as.POSIXct(t, tz = "UTC"))
    )$n[[1]]
    if (n != length(instrument_ids)) {
      rlang::abort("Bars are missing for some instruments at one or more pulse timestamps.", class = "ledgr_missing_bars")
    }
  }

  ts
}

ledgr_strategy_state_prev <- function(con, run_id, ts_utc) {
  if (!DBI::dbIsValid(con)) {
    rlang::abort("`con` must be a valid DBI connection.", class = "ledgr_invalid_con")
  }
  if (!is.character(run_id) || length(run_id) != 1 || is.na(run_id) || !nzchar(run_id)) {
    rlang::abort("`run_id` must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }

  ts_iso <- ledgr_normalize_ts_utc(ts_utc)

  row <- DBI::dbGetQuery(
    con,
    "
    SELECT state_json
    FROM strategy_state
    WHERE run_id = ? AND ts_utc < ?
    ORDER BY ts_utc DESC
    LIMIT 1
    ",
    params = list(run_id, ts_iso)
  )

  if (nrow(row) == 0) return(NULL)
  jsonlite::fromJSON(row$state_json[[1]], simplifyVector = FALSE)
}

ledgr_features_at_pulse <- function(con, run_id, instrument_ids, start_ts_utc, ts_utc, feature_defs) {
  if (!DBI::dbIsValid(con)) {
    rlang::abort("`con` must be a valid DBI connection.", class = "ledgr_invalid_con")
  }
  if (!is.character(run_id) || length(run_id) != 1 || is.na(run_id) || !nzchar(run_id)) {
    rlang::abort("`run_id` must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }
  if (!is.character(instrument_ids) || length(instrument_ids) < 1 || anyNA(instrument_ids) || any(!nzchar(instrument_ids))) {
    rlang::abort("`instrument_ids` must be a non-empty character vector of non-empty strings.", class = "ledgr_invalid_args")
  }

  ledgr_validate_feature_defs(feature_defs)
  feature_defs <- feature_defs[order(vapply(feature_defs, function(d) d$id, character(1)))]

  start_iso <- ledgr_normalize_ts_utc(start_ts_utc)
  start_ts <- as.POSIXct(start_iso, tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ")
  ts_iso <- ledgr_normalize_ts_utc(ts_utc)
  ts_posix <- as.POSIXct(ts_iso, tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ")
  if (is.na(start_ts) || is.na(ts_posix)) {
    rlang::abort("Invalid timestamps for feature computation.", class = "ledgr_invalid_args")
  }
  if (ts_posix < start_ts) {
    rlang::abort("`ts_utc` must be >= start_ts_utc.", class = "ledgr_invalid_args")
  }

  ids_sql <- paste(DBI::dbQuoteString(con, instrument_ids), collapse = ", ")
  max_lookback <- max(vapply(
    feature_defs,
    function(d) max(as.integer(d$requires_bars), as.integer(d$stable_after)),
    integer(1)
  ))

  bars <- DBI::dbGetQuery(
    con,
    paste0(
      "SELECT instrument_id, ts_utc, open, high, low, close, volume ",
      "FROM (",
      "  SELECT instrument_id, ts_utc, open, high, low, close, volume, ",
      "         ROW_NUMBER() OVER (PARTITION BY instrument_id ORDER BY ts_utc DESC) AS rn ",
      "  FROM bars ",
      "  WHERE instrument_id IN (", ids_sql, ") AND ts_utc <= ? AND ts_utc >= ?",
      ") sub ",
      "WHERE rn <= ? ",
      "ORDER BY instrument_id, ts_utc"
    ),
    params = list(ts_posix, start_ts, as.integer(max_lookback))
  )

  if (nrow(bars) == 0) {
    rlang::abort("No bars found for feature computation.", class = "ledgr_missing_bars")
  }

  out_rows <- vector("list", length(instrument_ids) * length(feature_defs))
  idx <- 1L

  for (instrument_id in instrument_ids) {
    b <- bars[bars$instrument_id == instrument_id, , drop = FALSE]
    b <- b[order(b$ts_utc), , drop = FALSE]
    if (nrow(b) == 0) {
      rlang::abort(sprintf("Missing bars for instrument_id=%s during feature computation.", instrument_id), class = "ledgr_missing_bars")
    }
    if (!isTRUE(all.equal(as.POSIXct(b$ts_utc[[nrow(b)]], tz = "UTC"), ts_posix, tolerance = 0))) {
      rlang::abort(sprintf("Missing bars for instrument_id=%s at ts_utc=%s.", instrument_id, ts_iso), class = "ledgr_missing_bars")
    }

    for (def in feature_defs) {
      value <- ledgr_compute_feature_latest(b, def)
      out_rows[[idx]] <- list(
        run_id = run_id,
        instrument_id = instrument_id,
        ts_utc = ts_posix,
        feature_name = def$id,
        feature_value = as.numeric(value)
      )
      idx <- idx + 1L
    }
  }

  out_rows <- out_rows[seq_len(idx - 1L)]
  out_df <- data.frame(
    run_id = vapply(out_rows, `[[`, character(1), "run_id"),
    instrument_id = vapply(out_rows, `[[`, character(1), "instrument_id"),
    ts_utc = as.POSIXct(vapply(out_rows, function(x) format(x$ts_utc, "%Y-%m-%d %H:%M:%S", tz = "UTC"), character(1)), tz = "UTC"),
    feature_name = vapply(out_rows, `[[`, character(1), "feature_name"),
    feature_value = vapply(out_rows, function(x) as.numeric(x$feature_value), numeric(1)),
    stringsAsFactors = FALSE
  )

  feature_ids <- vapply(feature_defs, function(d) d$id, character(1))
  features_sql <- paste(DBI::dbQuoteString(con, feature_ids), collapse = ", ")
  inst_sql <- paste(DBI::dbQuoteString(con, instrument_ids), collapse = ", ")

  DBI::dbExecute(
    con,
    paste0(
      "DELETE FROM features WHERE run_id = ? ",
      "AND instrument_id IN (", inst_sql, ") ",
      "AND feature_name IN (", features_sql, ") ",
      "AND ts_utc = ?"
    ),
    params = list(run_id, ts_posix)
  )
  DBI::dbAppendTable(con, "features", out_df)

  out_df[, c("instrument_id", "ts_utc", "feature_name", "feature_value")]
}

ledgr_state_asof <- function(con, run_id, initial_cash, ts_utc) {
  rows <- DBI::dbGetQuery(
    con,
    "
    SELECT instrument_id, meta_json
    FROM ledger_events
    WHERE run_id = ? AND ts_utc <= ?
    ORDER BY event_seq
    ",
    params = list(run_id, ts_utc)
  )

  cash <- as.numeric(initial_cash)
  pos <- numeric(0)
  if (nrow(rows) > 0) {
    for (i in seq_len(nrow(rows))) {
      meta <- jsonlite::fromJSON(rows$meta_json[[i]], simplifyVector = FALSE)
      cash <- cash + as.numeric(meta$cash_delta)
      instrument_id <- rows$instrument_id[[i]]
      if (!is.na(instrument_id) && nzchar(instrument_id)) {
        if (is.null(names(pos)) || !(instrument_id %in% names(pos))) pos[instrument_id] <- 0
        pos[instrument_id] <- pos[instrument_id] + as.numeric(meta$position_delta)
      }
    }
  }

  held <- pos[abs(pos) > 0]
  positions_value <- 0
  if (length(held) > 0) {
    instrument_ids <- names(held)
    ids_sql <- paste(DBI::dbQuoteString(con, instrument_ids), collapse = ", ")
    bars <- DBI::dbGetQuery(
      con,
      paste0(
        "SELECT instrument_id, close FROM bars WHERE instrument_id IN (",
        ids_sql,
        ") AND ts_utc = ?"
      ),
      params = list(ts_utc)
    )
    close_by_id <- stats::setNames(as.numeric(bars$close), bars$instrument_id)
    positions_value <- sum(as.numeric(held) * close_by_id[instrument_ids])
  }

  list(
    cash = cash,
    positions = pos,
    equity = cash + positions_value
  )
}

ledgr_update_state_incremental <- function(con, run_id, last_event_seq, ts_utc, current_state) {
  if (!is.list(current_state) || is.null(current_state$cash) || is.null(current_state$positions)) {
    rlang::abort("`current_state` must include cash and positions.", class = "ledgr_invalid_args")
  }

  rows <- DBI::dbGetQuery(
    con,
    "
    SELECT event_seq, instrument_id, meta_json
    FROM ledger_events
    WHERE run_id = ? AND event_seq > ? AND ts_utc <= ?
    ORDER BY event_seq
    ",
    params = list(run_id, as.integer(last_event_seq), ts_utc)
  )

  cash <- as.numeric(current_state$cash)
  pos <- current_state$positions
  if (!is.numeric(pos)) pos <- as.numeric(pos)
  if (is.null(names(pos))) names(pos) <- character(0)

  if (nrow(rows) > 0) {
    for (i in seq_len(nrow(rows))) {
      meta <- jsonlite::fromJSON(rows$meta_json[[i]], simplifyVector = FALSE)
      cash <- cash + as.numeric(meta$cash_delta)
      instrument_id <- rows$instrument_id[[i]]
      if (!is.na(instrument_id) && nzchar(instrument_id)) {
        if (is.null(names(pos)) || !(instrument_id %in% names(pos))) pos[instrument_id] <- 0
        pos[instrument_id] <- pos[instrument_id] + as.numeric(meta$position_delta)
      }
    }
    last_event_seq <- rows$event_seq[[nrow(rows)]]
  }

  list(
    state = list(cash = cash, positions = pos),
    last_event_seq = as.integer(last_event_seq)
  )
}

ledgr_feature_defs_from_config <- function(cfg) {
  feats <- cfg$features
  if (is.null(feats) || is.null(feats$enabled) || !isTRUE(feats$enabled)) {
    return(list())
  }

  defs <- feats$defs
  if (is.null(defs) || !is.list(defs) || length(defs) < 1) {
    rlang::abort("features.enabled is TRUE but features.defs is missing/empty.", class = "ledgr_invalid_config")
  }

  out <- list()
    for (d in defs) {
      if (!is.list(d)) {
        rlang::abort("Each entry in features.defs must be a list.", class = "ledgr_invalid_config")
      }

    id <- d$id
    if (is.null(id)) id <- d$name
    if (!is.character(id) || length(id) != 1 || is.na(id) || !nzchar(id)) {
      rlang::abort("Each feature def must include `id` (or `name`) as a non-empty string.", class = "ledgr_invalid_config")
    }

    if (identical(id, "return_1")) {
      out[[length(out) + 1L]] <- ledgr_feature_return_1()
      next
    }

    if (grepl("^sma_\\d+$", id)) {
      n <- as.integer(sub("^sma_", "", id))
      out[[length(out) + 1L]] <- ledgr_feature_sma_n(n)
      next
    }

    if (identical(id, "sma_n")) {
      n <- d$params$n
      if (!is.numeric(n) || length(n) != 1 || is.na(n) || !is.finite(n) || n < 1 || (n %% 1) != 0) {
        rlang::abort("features.defs entry 'sma_n' requires params$n as an integer >= 1.", class = "ledgr_invalid_config")
      }
      out[[length(out) + 1L]] <- ledgr_feature_sma_n(as.integer(n))
      next
    }

    if (exists("ledgr_get_indicator", mode = "function")) {
      ind <- tryCatch(ledgr_get_indicator(id), error = function(e) NULL)
      if (inherits(ind, "ledgr_indicator")) {
        out[[length(out) + 1L]] <- list(
          id = ind$id,
          fn = ind$fn,
          requires_bars = ind$requires_bars,
          stable_after = if (is.null(d$stable_after)) ind$stable_after else d$stable_after,
          params = d$params
        )
        next
      }
    }

      rlang::abort(sprintf("Unknown feature id in config: %s", id), class = "ledgr_invalid_config")
    }

  out
}

ledgr_strategy_from_config <- function(cfg) {
  id <- cfg$strategy$id
  params <- cfg$strategy$params
  if (is.null(params)) params <- list()
  if (!is.list(params)) {
    rlang::abort("strategy.params must be a list.", class = "ledgr_invalid_config")
  }

  if (identical(id, "hold_zero")) return(HoldZeroStrategy$new(params = params))
  if (identical(id, "echo")) return(EchoStrategy$new(params = params))
  if (identical(id, "ts_rule")) return(TsRuleStrategy$new(params = params))
  if (identical(id, "state_prev")) return(StatePrevStrategy$new(params = params))
  if (identical(id, "functional")) {
    key <- params$strategy_key
    return(ledgr_strategy_fn_from_key(key))
  }

  rlang::abort(sprintf("Unknown strategy.id: %s", id), class = "ledgr_invalid_config")
}

TsRuleStrategy <- R6::R6Class(
  "TsRuleStrategy",
  inherit = LedgrStrategy,
  private = list(
    on_pulse_impl = function(ctx) {
      cut <- self$params$cutover_ts_utc
      before <- self$params$targets_before
      after <- self$params$targets_after

      if (!is.character(cut) || length(cut) != 1 || is.na(cut) || !nzchar(cut)) {
        rlang::abort("TsRuleStrategy requires params$cutover_ts_utc as an ISO8601 UTC string.", class = "ledgr_invalid_strategy")
      }
      if (!is.numeric(before) || is.null(names(before))) {
        rlang::abort("TsRuleStrategy requires params$targets_before as a named numeric vector.", class = "ledgr_invalid_strategy")
      }
      if (!is.numeric(after) || is.null(names(after))) {
        rlang::abort("TsRuleStrategy requires params$targets_after as a named numeric vector.", class = "ledgr_invalid_strategy")
      }

      if (ctx$ts_utc < cut) {
        list(targets = before, state_update = list())
      } else {
        list(targets = after, state_update = list())
      }
    }
  )
)
