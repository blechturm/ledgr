#' Run a deterministic EOD backtest (v0.1.0)
#'
#' Executes the v0.1.0 EOD pulse loop against a DuckDB database preloaded with
#' `instruments` and `bars`, writing derived outputs back to the same database.
#'
#' @param config A config list (or JSON string) matching the v0.1.0 config contract.
#' @param run_id Optional run identifier to resume or reuse.
#' @return A list with `run_id` and `db_path`.
#' @details
#' This is a low-level internal runner. Most users should call
#' `ledgr_backtest()`, which builds the config and then delegates here. Direct
#' use is not recommended; the example is illustrative only.
#'
#' @examples
#' if (FALSE) {
#'   # Most users should call ledgr_backtest(); it builds this config and calls
#'   # ledgr_backtest_run() internally.
#'   result <- ledgr_backtest_run(config, run_id = "manual-run")
#' }
#' @export
ledgr_backtest_run <- function(config, run_id = NULL) {
  control <- list()
  if (is.list(config) && is.list(config$engine) && is.list(config$engine$control)) {
    control <- config$engine$control
  }
  ledgr_backtest_run_internal(config = config, run_id = run_id, control = control)
}

.ledgr_telemetry_registry <- new.env(parent = emptyenv())
.ledgr_preflight_registry <- new.env(parent = emptyenv())

ledgr_time_now <- function() {
  candidate <- proc.time()[["elapsed"]]
  if (length(candidate) == 1L && !is.na(candidate)) {
    return(as.numeric(candidate))
  }
  if (requireNamespace("nanotime", quietly = TRUE)) {
    candidate <- nanotime::nanotime()
    if (length(candidate) == 1L && !is.na(candidate)) {
      return(candidate)
    }
  }
  if (requireNamespace("microbenchmark", quietly = TRUE)) {
    candidate <- microbenchmark::get_nanotime()
    if (length(candidate) == 1L && !is.na(candidate)) {
      return(candidate)
    }
  }
  Sys.time()
}

ledgr_time_elapsed <- function(start, end) {
  if (length(start) == 0 || length(end) == 0) {
    return(NA_real_)
  }
  if (inherits(start, "nanotime")) {
    return(as.numeric(end - start) / 1e9)
  }
  if (inherits(start, "integer64")) {
    return(as.numeric(end - start) / 1e9)
  }
  delta <- end - start
  if (inherits(delta, "difftime")) {
    return(as.numeric(delta))
  }
  if (is.numeric(delta)) {
    if (abs(delta) > 1e3) return(as.numeric(delta) / 1e9)
    return(as.numeric(delta))
  }
  as.numeric(difftime(end, start, units = "secs"))
}

ledgr_set_preflight_start <- function(value) {
  assign("start", value, envir = .ledgr_preflight_registry)
  invisible(TRUE)
}

ledgr_take_preflight_start <- function() {
  if (!exists("start", envir = .ledgr_preflight_registry, inherits = FALSE)) return(NULL)
  val <- get("start", envir = .ledgr_preflight_registry, inherits = FALSE)
  rm("start", envir = .ledgr_preflight_registry)
  val
}

ledgr_fill_event_row <- function(run_id, fill_intent, event_seq) {
  if (inherits(fill_intent, "ledgr_fill_none")) {
    return(structure(
      list(
        status = "NO_OP",
        next_event_seq = event_seq
      ),
      class = "ledgr_ledger_write_result"
    ))
  }

  if (!inherits(fill_intent, "ledgr_fill_intent") || !is.list(fill_intent)) {
    rlang::abort("`fill_intent` must be a `ledgr_fill_intent`.", class = "ledgr_invalid_fill_intent")
  }
  if (!is.numeric(event_seq) || length(event_seq) != 1 || is.na(event_seq) || !is.finite(event_seq) ||
    event_seq < 1 || (event_seq %% 1) != 0) {
    rlang::abort("`event_seq` must be an integer >= 1.", class = "ledgr_invalid_args")
  }

  instrument_id <- fill_intent$instrument_id
  side <- fill_intent$side
  qty <- fill_intent$qty
  fill_price <- fill_intent$fill_price
  commission_fixed <- fill_intent$commission_fixed
  ts_exec_utc <- fill_intent$ts_exec_utc

  signed_qty <- if (side == "BUY") as.numeric(qty) else -as.numeric(qty)
  cash_delta <- if (side == "BUY") {
    -(as.numeric(qty) * as.numeric(fill_price) + as.numeric(commission_fixed))
  } else {
    +(as.numeric(qty) * as.numeric(fill_price) - as.numeric(commission_fixed))
  }

  ts_exec_iso <- ledgr_normalize_ts_utc(ts_exec_utc)
  ts_exec_posix <- as.POSIXct(ts_exec_iso, tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ")
  if (is.na(ts_exec_posix)) {
    rlang::abort("`fill_intent$ts_exec_utc` must be a valid UTC timestamp.", class = "ledgr_invalid_fill_intent")
  }

  meta_json <- canonical_json(
    list(
      commission_fixed = as.numeric(commission_fixed),
      cash_delta = as.numeric(cash_delta),
      position_delta = as.numeric(signed_qty),
      realized_pnl = NULL
    )
  )

  event_id <- paste0(run_id, "_", sprintf("%08d", as.integer(event_seq)))
  row <- list(
    event_id = event_id,
    run_id = run_id,
    ts_utc = ts_exec_posix,
    event_type = "FILL",
    instrument_id = instrument_id,
    side = side,
    qty = as.numeric(qty),
    price = as.numeric(fill_price),
    fee = as.numeric(commission_fixed),
    meta_json = meta_json,
    event_seq = as.integer(event_seq)
  )

  structure(
    list(
      status = "WROTE",
      event_id = event_id,
      event_seq = as.integer(event_seq),
      next_event_seq = as.integer(event_seq) + 1L,
      cash_delta = as.numeric(cash_delta),
      position_delta = as.numeric(signed_qty),
      row = row
    ),
    class = "ledgr_ledger_write_result"
  )
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
  validate_ledgr_config(config)

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
  snapshot_db_path <- NULL
  if (!is.null(snapshot_id)) {
    snapshot_db_path <- ledgr_snapshot_db_path_from_config(cfg, db_path)
  }
  snapshot_hash_for_features <- NULL

  set.seed(seed)

  opened <- ledgr_open_duckdb_with_retry(db_path)
  drv <- opened$drv
  con <- opened$con
  on.exit({
    ledgr_checkpoint_duckdb(con)
    suppressWarnings(try(DBI::dbDisconnect(con, shutdown = TRUE), silent = TRUE))
    suppressWarnings(try(duckdb::duckdb_shutdown(drv), silent = TRUE))
  }, add = TRUE)

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
  if (nrow(run_row) > 0) {
    found_run_ids <- as.character(run_row$run_id)
    if (length(found_run_ids) != 1L || !identical(found_run_ids[[1]], run_id)) {
      rlang::abort(
        sprintf(
          "Run lookup returned unexpected run_id. Requested %s, got %s.",
          run_id,
          paste(found_run_ids, collapse = ", ")
        ),
        class = "ledgr_run_lookup_mismatch"
      )
    }
  }

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
    inserted_run <- DBI::dbGetQuery(
      con,
      "SELECT run_id FROM runs WHERE run_id = ?",
      params = list(run_id)
    )
    if (nrow(inserted_run) != 1L || !identical(as.character(inserted_run$run_id[[1]]), run_id)) {
      rlang::abort(
        sprintf("Run registration verification failed for run_id=%s.", run_id),
        class = "ledgr_run_registration_failed"
      )
    }
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
    tryCatch(
      ledgr_prepare_snapshot_source_tables(con, snapshot_db_path, db_path),
      error = function(e) {
        fail_run(conditionMessage(e), class = "LEDGR_SNAPSHOT_SOURCE_ERROR")
      }
    )

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
    snapshot_hash_for_features <- stored_snapshot_hash

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
    ledgr_prepare_snapshot_runtime_views(con, snapshot_id, instrument_ids, start_ts_utc, end_ts_utc)

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
      ledgr_run_data_subset_hash(con, instrument_ids, start_ts_utc, end_ts_utc)
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
  if (length(feature_defs) > 0) {
    feature_defs <- feature_defs[order(vapply(feature_defs, function(d) d$id, character(1)))]
  }
  persist_features <- TRUE
  if (!is.null(cfg$features) && is.list(cfg$features) && !is.null(cfg$features$persist)) {
    persist_features <- isTRUE(cfg$features$persist)
  }
  execution_mode <- "audit_log"
  checkpoint_every <- 10000L
  if (!is.null(cfg$engine) && is.list(cfg$engine)) {
    if (!is.null(cfg$engine$execution_mode)) {
      execution_mode <- cfg$engine$execution_mode
    }
    if (!is.null(cfg$engine$checkpoint_every)) {
      checkpoint_every <- as.integer(cfg$engine$checkpoint_every)
    }
  }
  if (!execution_mode %in% c("db_live", "audit_log")) {
    rlang::abort("engine.execution_mode must be \"db_live\" or \"audit_log\".", class = "ledgr_invalid_config")
  }
  DBI::dbExecute(
    con,
    "UPDATE runs SET execution_mode = ?, schema_version = ? WHERE run_id = ?",
    params = list(execution_mode, ledgr_experiment_store_schema_version, run_id)
  )
  if (!is.finite(checkpoint_every) || is.na(checkpoint_every) || checkpoint_every < 1 || (checkpoint_every %% 1) != 0) {
    rlang::abort("engine.checkpoint_every must be an integer >= 1.", class = "ledgr_invalid_config")
  }

  strategy <- ledgr_strategy_from_config(cfg)
  strategy_fn <- NULL
  strategy_is_functional <- FALSE
  if (!is.null(cfg$strategy) && is.list(cfg$strategy) && identical(cfg$strategy$id, "functional")) {
    strategy_is_functional <- TRUE
    key <- cfg$strategy$params$strategy_key
    strategy_fn <- ledgr_get_strategy_fn(key)
  } else if (is.function(strategy$on_pulse)) {
    strategy_fn <- strategy$on_pulse
  }
  if (!is.function(strategy_fn)) {
    rlang::abort("Strategy on_pulse is not a function; check strategy configuration.", class = "ledgr_invalid_strategy")
  }

  pulses <- ledgr_pulse_timestamps(con, instrument_ids, start_ts_utc, end_ts_utc)
  pulses_posix <- as.POSIXct(pulses, tz = "UTC")
  pulses_iso <- format(pulses_posix, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")

  resume_posix <- pulses_posix[[1]]
  resume_iso <- pulses_iso[[1]]
  resume_exec_posix <- pulses_posix[[2]]
  start_idx <- 1L

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
        resume_exec_posix <- as.POSIXct(NA_real_, origin = "1970-01-01", tz = "UTC")
      }
    } else {
      start_idx <- 1L
      resume_posix <- pulses_posix[[1]]
      resume_iso <- pulses_iso[[1]]
      resume_exec_posix <- if (length(pulses_posix) >= 2) pulses_posix[[2]] else as.POSIXct(NA_real_, origin = "1970-01-01", tz = "UTC")
    }

    # Resume cleanup: remove any previously written tail rows to avoid alternate-reality outputs.
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

  next_event_seq <- DBI::dbGetQuery(
    con,
    "SELECT COALESCE(MAX(event_seq), 0) + 1 AS next_seq FROM ledger_events WHERE run_id = ?",
    params = list(run_id)
  )$next_seq[[1]]
  next_event_seq <- as.integer(next_event_seq)

  fast_context <- control$fast_context
  if (is.null(fast_context)) fast_context <- FALSE
  if (!is.logical(fast_context) || length(fast_context) != 1 || is.na(fast_context)) {
    rlang::abort("`control$fast_context` must be TRUE or FALSE.", class = "ledgr_invalid_args")
  }

  max_pulses <- control$max_pulses
  if (is.null(max_pulses)) max_pulses <- Inf

  DBI::dbExecute(con, "UPDATE runs SET status = ?, error_msg = ? WHERE run_id = ?", params = list("RUNNING", NA_character_, run_id))

  processed <- 0L
  total_pulses <- length(pulses) - start_idx + 1L
  if (total_pulses < 0) total_pulses <- 0L
  telemetry_stride <- control$telemetry_stride
  if (is.null(telemetry_stride)) telemetry_stride <- 100L
  if (!is.numeric(telemetry_stride) || length(telemetry_stride) != 1 || is.na(telemetry_stride) ||
      !is.finite(telemetry_stride) || telemetry_stride < 0 || (telemetry_stride %% 1) != 0) {
    rlang::abort("`control$telemetry_stride` must be an integer >= 0.", class = "ledgr_invalid_args")
  }
  pulse_limit <- total_pulses
  if (is.finite(max_pulses)) {
    pulse_limit <- min(pulse_limit, as.integer(max_pulses))
  }
  telemetry_cap <- if (telemetry_stride > 0) {
    as.integer(ceiling(pulse_limit / telemetry_stride))
  } else {
    0L
  }
  telemetry <- new.env(parent = emptyenv())
  telemetry$t_pre <- NA_real_
  telemetry$t_post <- NA_real_
  telemetry$t_loop <- NA_real_
  telemetry$telemetry_stride <- as.integer(telemetry_stride)
  telemetry$telemetry_samples <- 0L
  telemetry$t_pulse <- if (telemetry_cap > 0) rep(NA_real_, telemetry_cap) else numeric(0)
  telemetry$t_bars <- if (telemetry_cap > 0) rep(NA_real_, telemetry_cap) else numeric(0)
  telemetry$t_ctx <- if (telemetry_cap > 0) rep(NA_real_, telemetry_cap) else numeric(0)
  telemetry$t_fill <- if (telemetry_cap > 0) rep(NA_real_, telemetry_cap) else numeric(0)
  telemetry$t_state <- if (telemetry_cap > 0) rep(NA_real_, telemetry_cap) else numeric(0)
  telemetry$t_feats <- if (telemetry_cap > 0) rep(NA_real_, telemetry_cap) else numeric(0)
  telemetry$t_strat <- if (telemetry_cap > 0) rep(NA_real_, telemetry_cap) else numeric(0)
  telemetry$t_exec <- if (telemetry_cap > 0) rep(NA_real_, telemetry_cap) else numeric(0)
  telemetry$feature_cache_hits <- 0L
  telemetry$feature_cache_misses <- 0L
  telemetry_idx <- 0L

  state_env <- new.env(parent = emptyenv())
  if (identical(execution_mode, "audit_log")) {
    state_env$current <- list(cash = as.numeric(initial_cash), positions = rep(0, length(instrument_ids)))
    names(state_env$current$positions) <- instrument_ids
  } else {
    state_env$current <- list(cash = as.numeric(initial_cash), positions = numeric(0))
  }
  instrument_index <- seq_along(instrument_ids)
  names(instrument_index) <- instrument_ids
  if (is_resume && length(pulses) > 0) {
    resume_state <- ledgr_state_asof(con, run_id, initial_cash, resume_posix)
    if (identical(execution_mode, "audit_log")) {
      pos_vec <- rep(0, length(instrument_ids))
      names(pos_vec) <- instrument_ids
      if (!is.null(resume_state$positions) && length(resume_state$positions) > 0) {
        pos_vec[names(resume_state$positions)] <- as.numeric(resume_state$positions)
      }
      state_env$current <- list(cash = resume_state$cash, positions = pos_vec)
    } else {
      state_env$current <- list(cash = resume_state$cash, positions = resume_state$positions)
    }
  }

  preflight_start <- ledgr_take_preflight_start()
  if (is.null(preflight_start)) {
    preflight_start <- ledgr_time_now()
  }
  run_feature_series <- NULL
  run_feature_matrix <- NULL
  bars_by_id <- NULL
  bars_cols_by_id <- NULL
  bars_mat <- NULL
  bars_df <- NULL
  features_df <- NULL
  bar_col_map <- list(
    instrument_id = 1L,
    ts_utc = 2L,
    open = 3L,
    high = 4L,
    low = 5L,
    close = 6L,
    volume = 7L,
    gap_type = 8L,
    is_synthetic = 9L
  )
  use_bars_cache <- length(feature_defs) > 0 || identical(execution_mode, "audit_log")
  use_fast_context <- isTRUE(fast_context) && identical(execution_mode, "audit_log") && isTRUE(strategy_is_functional)
  if (isTRUE(use_bars_cache)) {
    start_iso <- ledgr_normalize_ts_utc(start_ts_utc)
    end_iso <- ledgr_normalize_ts_utc(end_ts_utc)
    start_ts <- as.POSIXct(start_iso, tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ")
    end_ts <- as.POSIXct(end_iso, tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ")
    ids_sql <- paste(DBI::dbQuoteString(con, instrument_ids), collapse = ", ")
    bars_all <- DBI::dbGetQuery(
      con,
      paste0(
        "SELECT instrument_id, ts_utc, open, high, low, close, volume, gap_type, is_synthetic ",
        "FROM bars ",
        "WHERE instrument_id IN (", ids_sql, ") ",
        "AND ts_utc >= ? AND ts_utc <= ? ",
        "ORDER BY instrument_id, ts_utc"
      ),
      params = list(start_ts, end_ts)
    )
    if (nrow(bars_all) == 0) {
      fail_run("No bars found for feature hydration.", class = "ledgr_missing_bars")
    }

    bars_by_id <- split(bars_all, as.character(bars_all$instrument_id))
    for (instrument_id in instrument_ids) {
      b <- bars_by_id[[instrument_id]]
      if (is.null(b) || nrow(b) == 0) {
        fail_run(sprintf("Missing bars for instrument_id=%s during feature hydration.", instrument_id), class = "ledgr_missing_bars")
      }
      b <- b[order(b$ts_utc), , drop = FALSE]
      if (nrow(b) != length(pulses)) {
        fail_run("Feature hydration requires complete per-instrument coverage.", class = "ledgr_missing_bars")
      }
      ts_match <- as.POSIXct(b$ts_utc, tz = "UTC")
      if (any(ts_match != pulses_posix)) {
        fail_run("Feature hydration bars are misaligned with pulse timestamps.", class = "ledgr_missing_bars")
      }
      bars_by_id[[instrument_id]] <- b
    }
    bars_cols_by_id <- lapply(
      bars_by_id,
      function(b) {
        list(
          b$instrument_id,
          b$ts_utc,
          b$open,
          b$high,
          b$low,
          b$close,
          b$volume,
          b$gap_type,
          b$is_synthetic
        )
      }
    )
    n_inst <- length(instrument_ids)
    n_pulses <- length(pulses)
    bars_mat <- list(
      open = matrix(NA_real_, nrow = n_inst, ncol = n_pulses),
      high = matrix(NA_real_, nrow = n_inst, ncol = n_pulses),
      low = matrix(NA_real_, nrow = n_inst, ncol = n_pulses),
      close = matrix(NA_real_, nrow = n_inst, ncol = n_pulses),
      volume = matrix(NA_real_, nrow = n_inst, ncol = n_pulses),
      gap_type = matrix("", nrow = n_inst, ncol = n_pulses),
      is_synthetic = matrix(FALSE, nrow = n_inst, ncol = n_pulses)
    )
    for (j in seq_along(instrument_ids)) {
      id <- instrument_ids[[j]]
      cols <- bars_cols_by_id[[id]]
      bars_mat$open[j, ] <- as.numeric(cols[[bar_col_map$open]])
      bars_mat$high[j, ] <- as.numeric(cols[[bar_col_map$high]])
      bars_mat$low[j, ] <- as.numeric(cols[[bar_col_map$low]])
      bars_mat$close[j, ] <- as.numeric(cols[[bar_col_map$close]])
      bars_mat$volume[j, ] <- as.numeric(cols[[bar_col_map$volume]])
      bars_mat$gap_type[j, ] <- as.character(cols[[bar_col_map$gap_type]])
      bars_mat$is_synthetic[j, ] <- as.logical(cols[[bar_col_map$is_synthetic]])
    }
    bars_df <- data.frame(
      instrument_id = instrument_ids,
      ts_utc = as.POSIXct(rep(NA_character_, length(instrument_ids)), tz = "UTC"),
      open = numeric(length(instrument_ids)),
      high = numeric(length(instrument_ids)),
      low = numeric(length(instrument_ids)),
      close = numeric(length(instrument_ids)),
      volume = numeric(length(instrument_ids)),
      gap_type = character(length(instrument_ids)),
      is_synthetic = logical(length(instrument_ids)),
      stringsAsFactors = FALSE
    )
  }
  bars_proxy <- NULL
  if (isTRUE(use_fast_context) && isTRUE(use_bars_cache)) {
    bars_proxy <- list(
      instrument_id = instrument_ids,
      ts_utc = rep(pulses_posix[[1]], length(instrument_ids)),
      open = numeric(length(instrument_ids)),
      high = numeric(length(instrument_ids)),
      low = numeric(length(instrument_ids)),
      close = numeric(length(instrument_ids)),
      volume = numeric(length(instrument_ids)),
      gap_type = character(length(instrument_ids)),
      is_synthetic = logical(length(instrument_ids))
    )
  }

  if (length(feature_defs) > 0) {
    run_feature_series <- list()
    for (def in feature_defs) {
      per_inst <- list()
      for (instrument_id in instrument_ids) {
        b <- bars_by_id[[instrument_id]]
        cache_key <- ledgr_feature_cache_key(
          snapshot_hash = snapshot_hash_for_features,
          instrument_id = instrument_id,
          feature_def = def,
          start_ts_utc = start_ts_utc,
          end_ts_utc = end_ts_utc
        )
        values <- ledgr_feature_cache_get(cache_key, expected_len = nrow(b))
        if (is.null(values)) {
          values <- ledgr_compute_feature_series(b, def)
          ledgr_feature_cache_set(cache_key, values)
          if (!is.null(cache_key)) telemetry$feature_cache_misses <- telemetry$feature_cache_misses + 1L
        } else {
          telemetry$feature_cache_hits <- telemetry$feature_cache_hits + 1L
        }
        if (length(values) != nrow(b)) {
          fail_run(sprintf("Feature hydration length mismatch for %s/%s.", def$id, instrument_id))
        }
        per_inst[[instrument_id]] <- as.numeric(values)
      }
      run_feature_series[[def$id]] <- per_inst
    }
    def_ids <- vapply(feature_defs, function(d) d$id, character(1))
    n_inst <- length(instrument_ids)
    n_def <- length(def_ids)
    run_feature_matrix <- vector("list", n_def)
    for (d in seq_len(n_def)) {
      id <- def_ids[[d]]
      mat <- matrix(NA_real_, nrow = n_inst, ncol = length(pulses))
      for (j in seq_along(instrument_ids)) {
        mat[j, ] <- as.numeric(run_feature_series[[id]][[instrument_ids[[j]]]])
      }
      run_feature_matrix[[d]] <- mat
    }
    features_df <- data.frame(
      instrument_id = rep(instrument_ids, each = n_def),
      ts_utc = as.POSIXct(rep(NA_character_, n_inst * n_def), tz = "UTC"),
      feature_name = rep(def_ids, times = n_inst),
      feature_value = numeric(n_inst * n_def),
      stringsAsFactors = FALSE
    )
  }
  features_proxy <- NULL
  if (isTRUE(use_fast_context) && length(feature_defs) > 0) {
    features_proxy <- list(
      instrument_id = rep(instrument_ids, each = n_def),
      ts_utc = rep(pulses_posix[[1]], n_inst * n_def),
      feature_name = rep(def_ids, times = n_inst),
      feature_value = numeric(n_inst * n_def)
    )
  }
  telemetry$t_pre <- ledgr_time_elapsed(preflight_start, ledgr_time_now())

  pending_idx <- 0L
  max_events <- as.integer(max(1L, total_pulses * length(instrument_ids)))
  pending_cols <- list(
    event_id = character(max_events),
    run_id = character(max_events),
    ts_utc = as.POSIXct(rep(NA_character_, max_events), tz = "UTC"),
    event_type = character(max_events),
    instrument_id = character(max_events),
    side = character(max_events),
    qty = numeric(max_events),
    price = numeric(max_events),
    fee = numeric(max_events),
    meta_json = character(max_events),
    event_seq = integer(max_events)
  )
  pending_states <- vector("list", 0)
  pending_states_idx <- 0L
  flush_pending <- function() {
    if (pending_idx > 0) {
      out <- data.frame(
        event_id = pending_cols$event_id[seq_len(pending_idx)],
        run_id = pending_cols$run_id[seq_len(pending_idx)],
        ts_utc = pending_cols$ts_utc[seq_len(pending_idx)],
        event_type = pending_cols$event_type[seq_len(pending_idx)],
        instrument_id = pending_cols$instrument_id[seq_len(pending_idx)],
        side = pending_cols$side[seq_len(pending_idx)],
        qty = pending_cols$qty[seq_len(pending_idx)],
        price = pending_cols$price[seq_len(pending_idx)],
        fee = pending_cols$fee[seq_len(pending_idx)],
        meta_json = pending_cols$meta_json[seq_len(pending_idx)],
        event_seq = pending_cols$event_seq[seq_len(pending_idx)],
        stringsAsFactors = FALSE
      )
      DBI::dbAppendTable(con, "ledger_events", out)
      pending_idx <<- 0L
    }
    if (pending_states_idx > 0) {
      DBI::dbAppendTable(con, "strategy_state", do.call(rbind, pending_states[seq_len(pending_states_idx)]))
      pending_states_idx <<- 0L
      pending_states <<- vector("list", 0)
    }
    invisible(TRUE)
  }
  empty_df <- data.frame()
  ctx <- list(
    run_id = run_id,
    ts_utc = "",
    universe = instrument_ids,
    bars = if (isTRUE(use_bars_cache)) bars_df else empty_df,
    features = if (length(feature_defs) > 0) features_df else empty_df,
    features_wide = empty_df,
    feature = ledgr_feature_accessor(empty_df),
    positions = state_env$current$positions,
    cash = state_env$current$cash,
    equity = state_env$current$cash,
    state_prev = NULL,
    safety_state = "GREEN"
  )
  class(ctx) <- "ledgr_pulse_context"
  ctx <- ledgr_update_pulse_context_helpers(
    ctx,
    bars = empty_df,
    features = empty_df,
    positions = state_env$current$positions,
    universe = instrument_ids
  )

  lot_map <- stats::setNames(vector("list", length(instrument_ids)), instrument_ids)
  cost_basis_by_inst <- stats::setNames(rep(0, length(instrument_ids)), instrument_ids)
  realized_pnl <- 0
  realized_comp <- 0
  kahan_add <- function(delta) {
    y <- delta - realized_comp
    t <- realized_pnl + y
    realized_comp <<- (t - realized_pnl) - y
    realized_pnl <<- t
  }

  total_pulses_len <- length(pulses)
  eq_cash <- numeric(total_pulses_len)
  eq_positions_value <- numeric(total_pulses_len)
  eq_equity <- numeric(total_pulses_len)
  eq_realized <- numeric(total_pulses_len)
  eq_unrealized <- numeric(total_pulses_len)
  eq_ts <- vector("list", total_pulses_len)

  state_prev_mem <- NULL
  existing_events_all <- NULL
  if (identical(execution_mode, "audit_log") && is_resume) {
    state_prev_mem <- ledgr_strategy_state_prev(con, run_id, resume_iso)
  }
  if (is_resume) {
    existing_events <- DBI::dbGetQuery(
      con,
      "SELECT event_seq, ts_utc, instrument_id, side, qty, price, fee, meta_json, event_type FROM ledger_events WHERE run_id = ? ORDER BY event_seq",
      params = list(run_id)
    )
    existing_events_all <- existing_events
    if (nrow(existing_events) > 0) {
      for (i in seq_len(nrow(existing_events))) {
        if (!identical(existing_events$event_type[[i]], "FILL")) next
        instrument_id <- as.character(existing_events$instrument_id[[i]])
        side <- as.character(existing_events$side[[i]])
        qty <- as.numeric(existing_events$qty[[i]])
        price <- as.numeric(existing_events$price[[i]])
        fee <- as.numeric(existing_events$fee[[i]])
        inst_lots <- lot_map[[instrument_id]]
        if (is.null(inst_lots)) inst_lots <- list()
        if (side == "BUY") {
          qty_to_buy <- qty
          trade_pnl <- 0
          while (qty_to_buy > 0 && length(inst_lots) > 0 && as.numeric(inst_lots[[1]]$qty) < 0) {
            lot_qty <- abs(as.numeric(inst_lots[[1]]$qty))
            lot_price <- as.numeric(inst_lots[[1]]$price)
            take <- min(lot_qty, qty_to_buy)
            trade_pnl <- trade_pnl + (lot_price - price) * take
            lot_qty <- lot_qty - take
            qty_to_buy <- qty_to_buy - take
            if (lot_qty <= 0) {
              inst_lots <- inst_lots[-1]
            } else {
              inst_lots[[1]]$qty <- -lot_qty
            }
          }
          if (qty_to_buy > 0) {
            inst_lots[[length(inst_lots) + 1L]] <- list(qty = qty_to_buy, price = price)
          }
          lot_map[[instrument_id]] <- inst_lots
          kahan_add(trade_pnl - fee)
        } else {
          qty_to_sell <- qty
          trade_pnl <- 0
          while (qty_to_sell > 0 && length(inst_lots) > 0 && as.numeric(inst_lots[[1]]$qty) > 0) {
            lot_qty <- as.numeric(inst_lots[[1]]$qty)
            lot_price <- as.numeric(inst_lots[[1]]$price)
            take <- min(lot_qty, qty_to_sell)
            trade_pnl <- trade_pnl + (price - lot_price) * take
            lot_qty <- lot_qty - take
            qty_to_sell <- qty_to_sell - take
            if (lot_qty <= 0) {
              inst_lots <- inst_lots[-1]
            } else {
              inst_lots[[1]]$qty <- lot_qty
            }
          }
          if (qty_to_sell > 0) {
            inst_lots[[length(inst_lots) + 1L]] <- list(qty = -qty_to_sell, price = price)
          }
          lot_map[[instrument_id]] <- inst_lots
          kahan_add(trade_pnl - fee)
        }
        if (length(inst_lots) > 0) {
          cost_basis_by_inst[[instrument_id]] <- sum(vapply(inst_lots, function(l) as.numeric(l$qty) * as.numeric(l$price), numeric(1)))
        } else {
          cost_basis_by_inst[[instrument_id]] <- 0
        }
      }
    }
  }

  full_run <- TRUE
  run_ok <- tryCatch(
    {
      process_pulse <- function(i, sample_now) {
        sample_now <- isTRUE(sample_now)
        time_start <- function(active) {
          if (active) proc.time()[["elapsed"]] else NA_real_
        }
        time_end <- function(start, active) {
          if (!active) return(NA_real_)
          proc.time()[["elapsed"]] - start
        }
        t_pulse_start <- time_start(sample_now)
        ts <- pulses_posix[[i]]
        ts_iso <- pulses_iso[[i]]

        t_bars <- NA_real_
        t_ctx <- NA_real_
        t_fill <- NA_real_
        t_state <- NA_real_
        t_feats <- NA_real_
        t_strat <- NA_real_
        t_exec <- NA_real_

        state <- state_env$current

        t_bars_start <- time_start(sample_now)
        if (isTRUE(use_bars_cache)) {
          if (isTRUE(use_fast_context) && !is.null(bars_proxy)) {
            bars_proxy$ts_utc <- rep(pulses_posix[[i]], length(instrument_ids))
            bars_proxy$open <- bars_mat$open[, i]
            bars_proxy$high <- bars_mat$high[, i]
            bars_proxy$low <- bars_mat$low[, i]
            bars_proxy$close <- bars_mat$close[, i]
            bars_proxy$volume <- bars_mat$volume[, i]
            bars_proxy$gap_type <- bars_mat$gap_type[, i]
            bars_proxy$is_synthetic <- bars_mat$is_synthetic[, i]
            bars <- bars_proxy
          } else {
            bars_df$ts_utc[] <- pulses_posix[[i]]
            bars_df$open[] <- bars_mat$open[, i]
            bars_df$high[] <- bars_mat$high[, i]
            bars_df$low[] <- bars_mat$low[, i]
            bars_df$close[] <- bars_mat$close[, i]
            bars_df$volume[] <- bars_mat$volume[, i]
            bars_df$gap_type[] <- bars_mat$gap_type[, i]
            bars_df$is_synthetic[] <- bars_mat$is_synthetic[, i]
            bars <- bars_df
          }
        } else {
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
        }
        if (sample_now) {
          t_bars <- time_end(t_bars_start, TRUE)
        }

        bars_n <- if (is.data.frame(bars)) nrow(bars) else length(bars$instrument_id)
        if (is.na(bars_n) || bars_n != length(instrument_ids)) {
          rlang::abort(
            sprintf("Missing bars for universe at ts_utc=%s.", ts_iso),
            class = "ledgr_missing_bars"
          )
        }

        feat_df <- empty_df
        if (length(feature_defs) > 0) {
          t_feats_start <- time_start(sample_now)
          if (identical(execution_mode, "audit_log")) {
            n_inst <- length(instrument_ids)
            n_def <- length(feature_defs)
            if (isTRUE(use_fast_context) && !is.null(features_proxy)) {
              features_proxy$ts_utc <- rep(pulses_posix[[i]], n_inst * n_def)
              for (d in seq_len(n_def)) {
                idx <- seq(from = d, by = n_def, length.out = n_inst)
                features_proxy$feature_value[idx] <- run_feature_matrix[[d]][, i]
              }
              feat_df <- features_proxy
            } else {
              features_df$ts_utc[] <- pulses_posix[[i]]
              for (d in seq_len(n_def)) {
                idx <- seq(from = d, by = n_def, length.out = n_inst)
                features_df$feature_value[idx] <- run_feature_matrix[[d]][, i]
              }
              feat_df <- features_df
            }
          } else {
            feat_df <- ledgr_features_at_pulse_cached(
              con,
              run_id,
              instrument_ids,
              ts,
              feature_defs,
              run_feature_series,
              i,
              persist_features
            )
          }
          if (sample_now) {
            t_feats <- time_end(t_feats_start, TRUE)
          }
        }

        t_ctx_start <- time_start(sample_now)
        positions_value <- 0
        if (!is.null(state$positions) && length(state$positions) > 0) {
          if (identical(execution_mode, "audit_log")) {
            positions_value <- sum(as.numeric(state$positions) * bars_mat$close[, i])
          } else {
            close_by_id <- stats::setNames(as.numeric(bars$close), bars$instrument_id)
            pos_ids <- intersect(names(state$positions), names(close_by_id))
            if (length(pos_ids) > 0) {
              positions_value <- sum(as.numeric(state$positions[pos_ids]) * close_by_id[pos_ids])
            }
          }
        }

        state_prev <- if (identical(execution_mode, "audit_log")) state_prev_mem else ledgr_strategy_state_prev(con, run_id, ts)

        ctx$ts_utc <- ts_iso
        ctx$bars <- bars
        ctx$features <- feat_df
        ctx$positions <- state$positions
        ctx$cash <- state$cash
        ctx$equity <- state$cash + positions_value
        ctx$state_prev <- state_prev
        ctx <- ledgr_update_pulse_context_helpers(
          ctx,
          bars = bars,
          features = feat_df,
          positions = state$positions,
          universe = instrument_ids
        )
        if (sample_now) {
          t_ctx <- time_end(t_ctx_start, TRUE)
        }

        t_strat_start <- time_start(sample_now)
        result <- strategy_fn(ctx)
        if (sample_now) {
          t_strat <- time_end(t_strat_start, TRUE)
        }
        numeric_result <- is.numeric(result)
        if (numeric_result) {
          result <- list(targets = result, state_update = NULL)
        }
        if (!is.list(result) || is.null(result$targets)) {
          rlang::abort(
            sprintf(
              "Strategy must return %s or a list with `targets`.",
              ledgr_strategy_targets_contract()
            ),
            class = "ledgr_invalid_strategy_result"
          )
        }
        targets <- ledgr_validate_strategy_targets(result$targets, instrument_ids)

        db_live_state_json <- NULL
        if (!is.null(result$state_update)) {
          state_json <- canonical_json(result$state_update)
          if (identical(execution_mode, "audit_log")) {
            pending_states_idx <<- pending_states_idx + 1L
            if (pending_states_idx > length(pending_states)) {
              pending_states <<- c(pending_states, vector("list", max(1000L, length(pending_states))))
            }
            pending_states[[pending_states_idx]] <<- data.frame(
              run_id = run_id,
              ts_utc = ts_iso,
              state_json = state_json,
              stringsAsFactors = FALSE
            )
            state_prev_mem <<- result$state_update
          } else {
            db_live_state_json <- state_json
          }
        }

        t_exec_start <- time_start(sample_now)
        for (instrument_id in instrument_ids) {
          cur_qty <- 0
          if (!is.null(state$positions) && length(state$positions) > 0) {
            if (identical(execution_mode, "audit_log")) {
              cur_qty <- as.numeric(state$positions[[instrument_index[[instrument_id]]]])
            } else {
              pos <- state$positions
              if (!is.null(names(pos)) && instrument_id %in% names(pos)) {
                cur_qty <- as.numeric(pos[instrument_id])
              }
            }
          }
          target_qty <- as.numeric(targets[[instrument_id]])
          delta <- target_qty - cur_qty
          if (delta == 0) next

          t_fill_start <- time_start(sample_now)
          next_bar_row <- NULL
          if (isTRUE(use_bars_cache)) {
            b <- bars_by_id[[instrument_id]]
            if (i < nrow(b)) {
              next_row <- b[i + 1L, , drop = FALSE]
              if (nrow(next_row) == 1) {
                next_bar_row <- list(
                  instrument_id = next_row$instrument_id[[1]],
                  ts_utc = next_row$ts_utc[[1]],
                  open = next_row$open[[1]]
                )
              }
            }
          } else {
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
            if (nrow(next_bar) == 1) {
              next_bar_row <- list(
                instrument_id = next_bar$instrument_id[[1]],
                ts_utc = next_bar$ts_utc[[1]],
                open = next_bar$open[[1]]
              )
            }
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

          if (identical(execution_mode, "audit_log")) {
            write_res <- ledgr_fill_event_row(run_id, fill, event_seq = next_event_seq)
            if (inherits(write_res, "ledgr_ledger_write_result") && identical(write_res$status, "WROTE")) {
              pending_idx <<- pending_idx + 1L
              if (pending_idx > length(pending_cols$event_id)) {
                rlang::abort("Ledger buffer exceeded preallocated capacity.", class = "ledgr_invalid_state")
              }
              pending_cols$event_id[[pending_idx]] <<- write_res$row$event_id
              pending_cols$run_id[[pending_idx]] <<- write_res$row$run_id
              pending_cols$ts_utc[[pending_idx]] <<- write_res$row$ts_utc
              pending_cols$event_type[[pending_idx]] <<- write_res$row$event_type
              pending_cols$instrument_id[[pending_idx]] <<- write_res$row$instrument_id
              pending_cols$side[[pending_idx]] <<- write_res$row$side
              pending_cols$qty[[pending_idx]] <<- as.numeric(write_res$row$qty)
              pending_cols$price[[pending_idx]] <<- as.numeric(write_res$row$price)
              pending_cols$fee[[pending_idx]] <<- as.numeric(write_res$row$fee)
              pending_cols$meta_json[[pending_idx]] <<- write_res$row$meta_json
              pending_cols$event_seq[[pending_idx]] <<- as.integer(write_res$row$event_seq)
            }
          } else {
            write_res <- ledgr_write_fill_events(con, run_id, fill, event_seq_start = next_event_seq, use_transaction = FALSE)
          }
          if (sample_now) {
            if (is.na(t_fill)) t_fill <- 0
            t_fill <- t_fill + time_end(t_fill_start, TRUE)
          }

          if (inherits(write_res, "ledgr_ledger_write_result") && identical(write_res$status, "WROTE")) {
            t_state_start <- time_start(sample_now)
            state$cash <- as.numeric(state$cash) + as.numeric(write_res$cash_delta)
            if (identical(execution_mode, "audit_log")) {
              idx <- instrument_index[[instrument_id]]
              state$positions[[idx]] <- as.numeric(state$positions[[idx]]) + as.numeric(write_res$position_delta)
            } else {
              pos <- state$positions
              if (is.null(pos)) pos <- numeric(0)
              if (is.null(names(pos))) names(pos) <- character(0)
              prev <- pos[instrument_id]
              if (length(prev) == 0 || is.na(prev)) prev <- 0
              pos[instrument_id] <- as.numeric(prev) + as.numeric(write_res$position_delta)
              state$positions <- pos
            }
            if (sample_now) {
              if (is.na(t_state)) t_state <- 0
              t_state <- t_state + time_end(t_state_start, TRUE)
            }
            next_event_seq <<- write_res$next_event_seq
            if (identical(write_res$row$event_type, "FILL")) {
              side <- write_res$row$side
              qty <- as.numeric(write_res$row$qty)
              price <- as.numeric(write_res$row$price)
              fee <- as.numeric(write_res$row$fee)
              inst_lots <- lot_map[[instrument_id]]
              if (is.null(inst_lots)) inst_lots <- list()
              if (side == "BUY") {
                qty_to_buy <- qty
                trade_pnl <- 0
                while (qty_to_buy > 0 && length(inst_lots) > 0 && as.numeric(inst_lots[[1]]$qty) < 0) {
                  lot_qty <- abs(as.numeric(inst_lots[[1]]$qty))
                  lot_price <- as.numeric(inst_lots[[1]]$price)
                  take <- min(lot_qty, qty_to_buy)
                  trade_pnl <- trade_pnl + (lot_price - price) * take
                  lot_qty <- lot_qty - take
                  qty_to_buy <- qty_to_buy - take
                  if (lot_qty <= 0) {
                    inst_lots <- inst_lots[-1]
                  } else {
                    inst_lots[[1]]$qty <- -lot_qty
                  }
                }
                if (qty_to_buy > 0) {
                  inst_lots[[length(inst_lots) + 1L]] <- list(qty = qty_to_buy, price = price)
                }
                lot_map[[instrument_id]] <- inst_lots
                kahan_add(trade_pnl - fee)
              } else {
                qty_to_sell <- qty
                trade_pnl <- 0
                while (qty_to_sell > 0 && length(inst_lots) > 0 && as.numeric(inst_lots[[1]]$qty) > 0) {
                  lot_qty <- as.numeric(inst_lots[[1]]$qty)
                  lot_price <- as.numeric(inst_lots[[1]]$price)
                  take <- min(lot_qty, qty_to_sell)
                  trade_pnl <- trade_pnl + (price - lot_price) * take
                  lot_qty <- lot_qty - take
                  qty_to_sell <- qty_to_sell - take
                  if (lot_qty <= 0) {
                    inst_lots <- inst_lots[-1]
                  } else {
                    inst_lots[[1]]$qty <- lot_qty
                  }
                }
                if (qty_to_sell > 0) {
                  inst_lots[[length(inst_lots) + 1L]] <- list(qty = -qty_to_sell, price = price)
                }
                lot_map[[instrument_id]] <- inst_lots
                kahan_add(trade_pnl - fee)
              }
              if (length(inst_lots) > 0) {
                cost_basis_by_inst[[instrument_id]] <- sum(vapply(inst_lots, function(l) as.numeric(l$qty) * as.numeric(l$price), numeric(1)))
              } else {
                cost_basis_by_inst[[instrument_id]] <- 0
              }
            }
          }
        }
        if (!is.null(db_live_state_json)) {
          t_state_start <- time_start(sample_now)
          DBI::dbExecute(
            con,
            "INSERT INTO strategy_state (run_id, ts_utc, state_json) VALUES (?, ?, ?)",
            params = list(run_id, ts_iso, db_live_state_json)
          )
          if (sample_now) {
            if (is.na(t_state)) t_state <- 0
            t_state <- t_state + time_end(t_state_start, TRUE)
          }
        }
        if (sample_now) {
          t_exec <- time_end(t_exec_start, TRUE)
        }
        state_env$current <- state
        idx <- processed + 1L
        eq_ts[[idx]] <<- ts
        eq_cash[[idx]] <<- as.numeric(state$cash)
        eq_positions_value[[idx]] <<- positions_value
        eq_equity[[idx]] <<- as.numeric(state$cash) + positions_value
        eq_realized[[idx]] <<- realized_pnl
        eq_unrealized[[idx]] <<- positions_value - sum(cost_basis_by_inst)

        t_pulse <- NA_real_
        if (sample_now) {
          t_pulse <- time_end(t_pulse_start, TRUE)
        }
        list(
          t_pulse = t_pulse,
          t_bars = t_bars,
          t_ctx = t_ctx,
          t_fill = t_fill,
          t_state = t_state,
          t_feats = t_feats,
          t_strat = t_strat,
          t_exec = t_exec
        )
      }

      run_loop <- function() {
        for (i in seq(from = start_idx, to = length(pulses))) {
          if (processed >= max_pulses) break

          sample_now <- isTRUE(telemetry_stride > 0 && (((i - start_idx + 1L) %% telemetry_stride) == 0L))
          pulse_res <- process_pulse(i, sample_now)

          if (isTRUE(sample_now) && telemetry_idx < length(telemetry$t_state)) {
            telemetry_idx <<- telemetry_idx + 1L
            telemetry$telemetry_samples <- telemetry_idx
            telemetry$t_pulse[[telemetry_idx]] <- pulse_res$t_pulse
            telemetry$t_bars[[telemetry_idx]] <- pulse_res$t_bars
            telemetry$t_ctx[[telemetry_idx]] <- pulse_res$t_ctx
            telemetry$t_fill[[telemetry_idx]] <- pulse_res$t_fill
            telemetry$t_state[[telemetry_idx]] <- pulse_res$t_state
            telemetry$t_feats[[telemetry_idx]] <- pulse_res$t_feats
            telemetry$t_strat[[telemetry_idx]] <- pulse_res$t_strat
            telemetry$t_exec[[telemetry_idx]] <- pulse_res$t_exec
          }

          processed <<- processed + 1L
          if (identical(execution_mode, "audit_log") && checkpoint_every > 0 &&
              (processed %% checkpoint_every) == 0L && pending_idx > 0) {
            flush_pending()
          }

        }
      }

      flush_time <- 0
      loop_start <- ledgr_time_now()
      DBI::dbWithTransaction(con, {
        run_loop()
        if (identical(execution_mode, "audit_log")) {
          flush_start <- ledgr_time_now()
          flush_pending()
          flush_time <<- ledgr_time_elapsed(flush_start, ledgr_time_now())
        }
      })
      telemetry$t_loop <- ledgr_time_elapsed(loop_start, ledgr_time_now())
      if (is.finite(max_pulses) && processed >= max_pulses) {
        full_run <<- FALSE
      }
      if (flush_time > 0 && telemetry_idx > 0) {
        telemetry$t_exec[[telemetry_idx]] <- telemetry$t_exec[[telemetry_idx]] + flush_time
        telemetry$t_pulse[[telemetry_idx]] <- telemetry$t_pulse[[telemetry_idx]] + flush_time
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
    telemetry_names <- ls(telemetry, all.names = TRUE)
    telemetry_scalars <- c(
      "t_pre",
      "t_post",
      "t_loop",
      "telemetry_stride",
      "telemetry_samples",
      "feature_cache_hits",
      "feature_cache_misses"
    )
    trimmed <- lapply(telemetry_names, function(name) {
      x <- telemetry[[name]]
      if (name %in% telemetry_scalars) return(x)
      if (telemetry_idx > 0) x[seq_len(telemetry_idx)] else numeric(0)
    })
    names(trimmed) <- telemetry_names
    ledgr_store_run_telemetry(run_id, trimmed)
    invisible(TRUE)
  }

  if (isTRUE(run_ok) && is.finite(max_pulses) && processed >= max_pulses) {
    # Simulated interruption for tests.
    finalize_telemetry()
    return(list(run_id = run_id, db_path = db_path))
  }

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
  if (n_events > 0) {
    for (i in seq_len(n_events)) {
      meta <- jsonlite::fromJSON(events_df$meta_json[[i]], simplifyVector = FALSE)
      cash_delta[[i]] <- as.numeric(meta$cash_delta)
      position_delta[[i]] <- as.numeric(meta$position_delta)
    }
  }

  cash_cum <- if (n_events > 0) cumsum(cash_delta) else numeric(0)
  idx <- findInterval(pulse_ts_num, event_ts_num)
  cash_at <- as.numeric(initial_cash) + ifelse(idx > 0, cash_cum[idx], 0)

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
      positions_mat[j, ] <- ifelse(idx_inst > 0, pos_cum[idx_inst], 0)
    }
  }

  positions_value <- if (n_pulses > 0) colSums(positions_mat * close_mat) else numeric(0)

  realized_pnl <- 0
  realized_comp <- 0
  kahan_add <- function(delta) {
    y <- delta - realized_comp
    t <- realized_pnl + y
    realized_comp <<- (t - realized_pnl) - y
    realized_pnl <<- t
  }
  lots <- list()
  cost_basis_by_inst <- stats::setNames(rep(0, n_inst), instrument_ids)
  total_cost_basis <- 0
  event_realized <- numeric(n_events)
  event_cost_basis <- numeric(n_events)

  if (n_events > 0) {
    for (i in seq_len(n_events)) {
      instrument_id <- events_df$instrument_id[[i]]
      if (!is.na(instrument_id) && nzchar(instrument_id)) {
        if (is.null(lots[[instrument_id]])) lots[[instrument_id]] <- list()
      }

      if (!identical(events_df$event_type[[i]], "FILL") || is.na(instrument_id) || !nzchar(instrument_id)) {
        event_realized[[i]] <- realized_pnl
        event_cost_basis[[i]] <- total_cost_basis
        next
      }

      side <- events_df$side[[i]]
      qty <- as.numeric(events_df$qty[[i]])
      price <- as.numeric(events_df$price[[i]])
      fee <- as.numeric(events_df$fee[[i]])

      inst_lots <- lots[[instrument_id]]
      old_basis <- cost_basis_by_inst[[instrument_id]]
      trade_pnl <- 0

      if (side == "BUY") {
        qty_to_buy <- qty
        while (qty_to_buy > 0 && length(inst_lots) > 0 && as.numeric(inst_lots[[1]]$qty) < 0) {
          lot_qty <- abs(as.numeric(inst_lots[[1]]$qty))
          lot_price <- as.numeric(inst_lots[[1]]$price)
          take <- min(lot_qty, qty_to_buy)
          trade_pnl <- trade_pnl + (lot_price - price) * take
          lot_qty <- lot_qty - take
          qty_to_buy <- qty_to_buy - take
          if (lot_qty <= 0) {
            inst_lots <- inst_lots[-1]
          } else {
            inst_lots[[1]]$qty <- -lot_qty
          }
        }
        if (qty_to_buy > 0) {
          inst_lots[[length(inst_lots) + 1L]] <- list(qty = qty_to_buy, price = price)
        }
      } else {
        qty_to_sell <- qty
        while (qty_to_sell > 0 && length(inst_lots) > 0 && as.numeric(inst_lots[[1]]$qty) > 0) {
          lot_qty <- as.numeric(inst_lots[[1]]$qty)
          lot_price <- as.numeric(inst_lots[[1]]$price)
          take <- min(lot_qty, qty_to_sell)
          trade_pnl <- trade_pnl + (price - lot_price) * take
          lot_qty <- lot_qty - take
          qty_to_sell <- qty_to_sell - take
          if (lot_qty <= 0) {
            inst_lots <- inst_lots[-1]
          } else {
            inst_lots[[1]]$qty <- lot_qty
          }
        }
        if (qty_to_sell > 0) {
          inst_lots[[length(inst_lots) + 1L]] <- list(qty = -qty_to_sell, price = price)
        }
      }

      lots[[instrument_id]] <- inst_lots
      kahan_add(trade_pnl - fee)

      if (length(inst_lots) > 0) {
        new_basis <- sum(vapply(inst_lots, function(l) as.numeric(l$qty) * as.numeric(l$price), numeric(1)))
      } else {
        new_basis <- 0
      }
      cost_basis_by_inst[[instrument_id]] <- new_basis
      total_cost_basis <- total_cost_basis - old_basis + new_basis

      event_realized[[i]] <- realized_pnl
      event_cost_basis[[i]] <- total_cost_basis
    }
  }

  realized_at <- ifelse(idx > 0, event_realized[idx], 0)
  cost_basis_at <- ifelse(idx > 0, event_cost_basis[idx], 0)

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
  if (identical(execution_mode, "audit_log") && isTRUE(persist_features) && length(feature_defs) > 0) {
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
            feat_vals[d, ] <- run_feature_matrix[[d]][j, ]
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
    DBI::dbExecute(
      con,
      "UPDATE runs SET status = ?, error_msg = ? WHERE run_id = ?",
      params = list("DONE", NA_character_, run_id)
    )
  })
  telemetry$t_post <- ledgr_time_elapsed(post_start, ledgr_time_now())

  finalize_telemetry()

  list(run_id = run_id, db_path = db_path)
}

ledgr_pulse_timestamps <- function(con, instrument_ids, start_ts_utc, end_ts_utc) {
  start_iso <- ledgr_normalize_ts_utc(start_ts_utc)
  end_iso <- ledgr_normalize_ts_utc(end_ts_utc)
  start_str <- sub("Z$", "", sub("T", " ", start_iso))
  end_str <- sub("Z$", "", sub("T", " ", end_iso))

  ids_sql <- paste(DBI::dbQuoteString(con, instrument_ids), collapse = ", ")
  res <- DBI::dbGetQuery(
    con,
    paste0(
      "WITH inst AS (",
      "  SELECT UNNEST([", ids_sql, "]) AS instrument_id",
      "), pulses AS (",
      "  SELECT DISTINCT ts_utc FROM bars ",
      "  WHERE instrument_id IN (", ids_sql, ") ",
      "  AND ts_utc >= CAST(? AS TIMESTAMP) AND ts_utc <= CAST(? AS TIMESTAMP)",
      "), missing AS (",
      "  SELECT COUNT(*) AS missing_count FROM (",
      "    SELECT i.instrument_id, p.ts_utc ",
      "    FROM inst i CROSS JOIN pulses p ",
      "    LEFT JOIN bars b ",
      "      ON b.instrument_id = i.instrument_id AND b.ts_utc = p.ts_utc ",
      "    WHERE b.ts_utc IS NULL",
      "  ) sub",
      ") ",
      "SELECT p.ts_utc, m.missing_count ",
      "FROM pulses p CROSS JOIN missing m ",
      "ORDER BY p.ts_utc"
    ),
    params = list(start_str, end_str)
  )

  ts_raw <- res$ts_utc
  if (length(ts_raw) == 0) {
    rlang::abort("No bars found for requested universe/time range.", class = "ledgr_missing_bars")
  }

  missing <- unique(res$missing_count)
  if (length(missing) != 1 || is.na(missing) || missing > 0) {
    rlang::abort("Bars are missing for some instruments at one or more pulse timestamps.", class = "ledgr_missing_bars")
  }

  if (inherits(ts_raw, "POSIXt")) {
    as.POSIXct(ts_raw, tz = "UTC")
  } else if (is.numeric(ts_raw)) {
    as.POSIXct(ts_raw, origin = "1970-01-01", tz = "UTC")
  } else {
    as.POSIXct(ts_raw, tz = "UTC")
  }
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

ledgr_features_at_pulse <- function(con,
                                    run_id,
                                    instrument_ids,
                                    start_ts_utc,
                                    ts_utc,
                                    feature_defs,
                                    persist_features = TRUE) {
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

  if (isTRUE(persist_features)) {
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
  }

  out_df[, c("instrument_id", "ts_utc", "feature_name", "feature_value")]
}

ledgr_features_at_pulse_cached <- function(con,
                                           run_id,
                                           instrument_ids,
                                           ts_utc,
                                           feature_defs,
                                           run_feature_series,
                                           pulse_idx,
                                           persist_features = TRUE) {
  if (!DBI::dbIsValid(con)) {
    rlang::abort("`con` must be a valid DBI connection.", class = "ledgr_invalid_con")
  }
  if (!is.character(run_id) || length(run_id) != 1 || is.na(run_id) || !nzchar(run_id)) {
    rlang::abort("`run_id` must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }
  if (!is.character(instrument_ids) || length(instrument_ids) < 1 || anyNA(instrument_ids) || any(!nzchar(instrument_ids))) {
    rlang::abort("`instrument_ids` must be a non-empty character vector of non-empty strings.", class = "ledgr_invalid_args")
  }
  if (!is.list(run_feature_series) || length(run_feature_series) < 1) {
    rlang::abort("`run_feature_series` must be a non-empty list.", class = "ledgr_invalid_args")
  }
  if (!is.numeric(pulse_idx) || length(pulse_idx) != 1 || is.na(pulse_idx) || pulse_idx < 1) {
    rlang::abort("`pulse_idx` must be a positive integer.", class = "ledgr_invalid_args")
  }

  ledgr_validate_feature_defs(feature_defs)
  feature_defs <- feature_defs[order(vapply(feature_defs, function(d) d$id, character(1)))]

  ts_iso <- ledgr_normalize_ts_utc(ts_utc)
  ts_posix <- as.POSIXct(ts_iso, tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ")
  if (is.na(ts_posix)) {
    rlang::abort("Invalid timestamp for feature cache lookup.", class = "ledgr_invalid_args")
  }

  out_rows <- vector("list", length(instrument_ids) * length(feature_defs))
  idx <- 1L

  for (instrument_id in instrument_ids) {
    for (def in feature_defs) {
      cache <- run_feature_series[[def$id]]
      if (is.null(cache) || is.null(cache[[instrument_id]])) {
        rlang::abort(sprintf("Missing feature cache for %s/%s.", def$id, instrument_id), class = "ledgr_invalid_args")
      }
      values <- cache[[instrument_id]]
      value <- if (pulse_idx <= length(values)) values[[pulse_idx]] else NA_real_
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

  if (isTRUE(persist_features)) {
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
  }

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
        current_fingerprint <- ledgr_indicator_fingerprint(ind)
        if (!is.null(d$fingerprint) && !identical(d$fingerprint, current_fingerprint)) {
          rlang::abort(
            sprintf("Registered indicator '%s' no longer matches the fingerprint stored in the run config.", id),
            class = "ledgr_run_hash_mismatch"
          )
        }
        out[[length(out) + 1L]] <- list(
          id = ind$id,
          fn = ind$fn,
          series_fn = ind$series_fn,
          requires_bars = ind$requires_bars,
          stable_after = if (is.null(d$stable_after)) ind$stable_after else d$stable_after,
          params = if (is.null(d$params)) ind$params else d$params,
          fingerprint = current_fingerprint
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

