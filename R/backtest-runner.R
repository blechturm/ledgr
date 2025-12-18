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

ledgr_backtest_run_internal <- function(config, run_id = NULL, control = list()) {
  ledgr_validate_config(config)

  cfg <- if (is.character(config)) jsonlite::fromJSON(config, simplifyVector = FALSE) else config
  if (!is.list(cfg)) {
    rlang::abort("`config` must be a list (or JSON string).", class = "ledgr_invalid_config")
  }

  db_path <- cfg$db_path
  instrument_ids <- cfg$universe$instrument_ids
  start_ts_utc <- cfg$backtest$start_ts_utc
  end_ts_utc <- cfg$backtest$end_ts_utc
  initial_cash <- as.numeric(cfg$backtest$initial_cash)
  seed <- as.integer(cfg$engine$seed)

  set.seed(seed)

  drv <- duckdb::duckdb()
  con <- DBI::dbConnect(drv, dbdir = db_path)
  on.exit(suppressWarnings(try(duckdb::duckdb_shutdown(drv), silent = TRUE)), add = TRUE)
  on.exit(suppressWarnings(try(DBI::dbDisconnect(con, shutdown = TRUE), silent = TRUE)), add = TRUE)

  ledgr_create_schema(con)
  ledgr_validate_schema(con)

  config_json <- canonical_json(cfg)
  cfg_hash <- config_hash(cfg)
  data_hash <- ledgr_data_hash(con, instrument_ids, start_ts_utc, end_ts_utc)

  if (is.null(run_id)) {
    if (!is.null(cfg$run_id) && is.character(cfg$run_id) && length(cfg$run_id) == 1 && nzchar(cfg$run_id) && !is.na(cfg$run_id)) {
      run_id <- cfg$run_id
    } else {
      run_id <- paste0(
        "run_",
        substr(digest::digest(paste0(cfg_hash, ":", data_hash, ":", seed), algo = "sha256"), 1, 16)
      )
    }
  }

  if (!is.character(run_id) || length(run_id) != 1 || is.na(run_id) || !nzchar(run_id)) {
    rlang::abort("`run_id` must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }

  engine_version <- as.character(utils::packageVersion("ledgr"))

  run_row <- DBI::dbGetQuery(
    con,
    "SELECT run_id, status, config_hash, data_hash FROM runs WHERE run_id = ?",
    params = list(run_id)
  )

  is_resume <- nrow(run_row) > 0
  resume_ts <- ledgr_normalize_ts_utc(start_ts_utc)

  if (!is_resume) {
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
        status,
        error_msg
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ",
      params = list(
        run_id,
        as.POSIXct(Sys.time(), tz = "UTC"),
        engine_version,
        config_json,
        cfg_hash,
        data_hash,
        "CREATED",
        NA_character_
      )
    )
  } else {
    stored_cfg_hash <- run_row$config_hash[[1]]
    stored_data_hash <- run_row$data_hash[[1]]
    if (!identical(stored_cfg_hash, cfg_hash)) {
      rlang::abort("Refusing to resume: config_hash does not match stored run.", class = "ledgr_run_hash_mismatch")
    }
    if (!identical(stored_data_hash, data_hash)) {
      rlang::abort("Refusing to resume: data_hash does not match stored run.", class = "ledgr_run_hash_mismatch")
    }
    if (identical(run_row$status[[1]], "DONE")) {
      return(list(run_id = run_id, db_path = db_path))
    }

    last_ts <- DBI::dbGetQuery(
      con,
      "SELECT MAX(ts_utc) AS last_ts FROM ledger_events WHERE run_id = ?",
      params = list(run_id)
    )$last_ts[[1]]

    if (!is.na(last_ts)) {
      resume_ts <- ledgr_normalize_ts_utc(last_ts)
    }

    resume_posix <- as.POSIXct(resume_ts, tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ")
    DBI::dbWithTransaction(con, {
      DBI::dbExecute(con, "DELETE FROM features WHERE run_id = ? AND ts_utc >= ?", params = list(run_id, resume_posix))
      DBI::dbExecute(con, "DELETE FROM equity_curve WHERE run_id = ? AND ts_utc >= ?", params = list(run_id, resume_posix))
    })
  }

  feature_defs <- ledgr_feature_defs_from_config(cfg)
  if (length(feature_defs) > 0) {
    if (!is_resume) {
      ledgr_compute_features(con, run_id, instrument_ids, start_ts_utc, end_ts_utc, feature_defs)
    } else {
      # Recompute deterministically for the whole range after tail cleanup.
      ledgr_compute_features(con, run_id, instrument_ids, start_ts_utc, end_ts_utc, feature_defs)
    }
  }

  strategy <- ledgr_strategy_from_config(cfg)

  pulses <- ledgr_pulse_timestamps(con, instrument_ids, start_ts_utc, end_ts_utc)
  resume_posix <- as.POSIXct(resume_ts, tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ")
  start_idx <- which(pulses >= resume_posix)[1]
  if (is.na(start_idx)) start_idx <- length(pulses) + 1L

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

  run_ok <- tryCatch(
    {
      for (i in seq(from = start_idx, to = length(pulses))) {
        if (processed >= max_pulses) break

        ts <- pulses[[i]]
        ts_iso <- ledgr_normalize_ts_utc(ts)

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

        feat_df <- data.frame()
        if (length(feature_defs) > 0) {
          feat_df <- DBI::dbGetQuery(
            con,
            "
            SELECT instrument_id, ts_utc, feature_name, feature_value
            FROM features
            WHERE run_id = ? AND ts_utc = ?
            ORDER BY instrument_id, feature_name
            ",
            params = list(run_id, ts)
          )
        }

        st <- ledgr_state_asof(con, run_id, initial_cash, ts)
        ctx <- ledgr_pulse_context(
          run_id = run_id,
          ts_utc = ts_iso,
          universe = instrument_ids,
          bars = bars,
          features = feat_df,
          positions = st$positions,
          cash = st$cash,
          equity = st$equity
        )

        result <- strategy$on_pulse(ctx)
        targets <- result$targets

        for (instrument_id in instrument_ids) {
          cur_qty <- 0
          if (!is.null(st$positions) && length(st$positions) > 0 && instrument_id %in% names(st$positions)) {
            cur_qty <- as.numeric(st$positions[[instrument_id]])
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

          write_res <- ledgr_write_fill_events(con, run_id, fill, event_seq_start = next_event_seq)
          if (inherits(write_res, "ledgr_ledger_write_result") && identical(write_res$status, "WROTE")) {
            next_event_seq <- write_res$next_event_seq
          }
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

  if (isTRUE(run_ok) && is.finite(max_pulses) && processed >= max_pulses) {
    # Simulated interruption for tests.
    return(list(run_id = run_id, db_path = db_path))
  }

  ledgr_rebuild_derived_state(con, run_id, initial_cash)

  DBI::dbExecute(
    con,
    "UPDATE runs SET status = ?, error_msg = ? WHERE run_id = ?",
    params = list("DONE", NA_character_, run_id)
  )

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
