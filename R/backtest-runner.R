.ledgr_telemetry_registry <- new.env(parent = emptyenv())
.ledgr_preflight_registry <- new.env(parent = emptyenv())

ledgr_strategy_error_classes <- function(error) {
  original <- setdiff(class(error), c("rlang_error", "error", "condition"))
  unique(c("ledgr_strategy_error", original))
}

ledgr_strategy_context_list <- function(x, max_items = 8L) {
  x <- as.character(x)
  x <- x[!is.na(x) & nzchar(x)]
  if (length(x) == 0L) return("<none>")
  if (length(x) <= max_items) return(paste(x, collapse = ", "))
  paste(c(x[seq_len(max_items)], sprintf("... (%d more)", length(x) - max_items)), collapse = ", ")
}

ledgr_strategy_error_features <- function(ctx) {
  feature_table <- ctx$feature_table
  if (is.null(feature_table) && is.data.frame(ctx$features)) {
    feature_table <- ctx$features
  }
  if (!is.data.frame(feature_table)) {
    feature_table <- data.frame()
  }
  features <- tryCatch(ledgr_feature_names(feature_table), error = function(e) character())
  if (length(features) == 0L && is.data.frame(ctx$features_wide)) {
    features <- setdiff(names(ctx$features_wide), c("instrument_id", "ts_utc"))
  }
  ledgr_strategy_context_list(features)
}

ledgr_strategy_error_message <- function(error, ctx) {
  sprintf(
    paste(
      "Strategy error at ts_utc=%s for run_id=%s.",
      "Instruments: %s.",
      "Available feature IDs: %s.",
      "Original error: %s"
    ),
    if (!is.null(ctx$ts_utc)) as.character(ctx$ts_utc) else "<unknown>",
    if (!is.null(ctx$run_id)) as.character(ctx$run_id) else "<unknown>",
    ledgr_strategy_context_list(ctx$universe),
    ledgr_strategy_error_features(ctx),
    conditionMessage(error)
  )
}

ledgr_abort_strategy_error <- function(error, ctx) {
  rlang::abort(
    ledgr_strategy_error_message(error, ctx),
    class = ledgr_strategy_error_classes(error),
    original_error = error,
    parent = error
  )
}

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

ledgr_fill_event_payload <- function(run_id,
                                     fill_intent,
                                     event_seq,
                                     serialize_meta_json = TRUE) {
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
  fee <- fill_intent$fee
  ts_exec_utc <- fill_intent$ts_exec_utc

  signed_qty <- if (side == "BUY") as.numeric(qty) else -as.numeric(qty)
  cash_delta <- if (side == "BUY") {
    -(as.numeric(qty) * as.numeric(fill_price) + as.numeric(fee))
  } else {
    +(as.numeric(qty) * as.numeric(fill_price) - as.numeric(fee))
  }

  ts_exec_posix <- ledgr_ts_utc_posix(
    ts_exec_utc,
    label = "`fill_intent$ts_exec_utc`",
    class = "ledgr_invalid_fill_intent"
  )

  meta <- list(
    fee = as.numeric(fee),
    cash_delta = as.numeric(cash_delta),
    position_delta = as.numeric(signed_qty),
    realized_pnl = NULL
  )
  meta_json <- if (isTRUE(serialize_meta_json)) ledgr_canonical_json_encode(meta) else NA_character_

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
    fee = as.numeric(fee),
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
      meta = meta,
      row = row
    ),
    class = "ledgr_ledger_write_result"
  )
}

ledgr_fill_event_row <- function(run_id, fill_intent, event_seq) {
  ledgr_fill_event_payload(
    run_id = run_id,
    fill_intent = fill_intent,
    event_seq = event_seq,
    serialize_meta_json = TRUE
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

ledgr_write_run_telemetry <- function(con,
                                      run_id,
                                      status,
                                      execution_mode,
                                      elapsed_sec,
                                      pulse_count,
                                      decision_pulse_count = NA_integer_,
                                      scheduled_skip_count = NA_integer_) {
  DBI::dbExecute(
    con,
    "
    INSERT OR REPLACE INTO run_telemetry (
      run_id,
      status,
      execution_mode,
      elapsed_sec,
      pulse_count,
      decision_pulse_count,
      scheduled_skip_count,
      updated_at_utc
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ",
    params = list(
      run_id,
      status,
      execution_mode,
      elapsed_sec,
      pulse_count,
      as.integer(decision_pulse_count),
      as.integer(scheduled_skip_count),
      as.POSIXct(Sys.time(), tz = "UTC")
    )
  )
  invisible(TRUE)
}

ledgr_next_diagnostic_seq <- function(con, run_id) {
  as.integer(DBI::dbGetQuery(
    con,
    paste0(
      "SELECT COALESCE(MAX(diagnostic_seq), 0) + 1 AS next_seq ",
      "FROM run_diagnostics WHERE run_id = ?"
    ),
    params = list(run_id)
  )$next_seq[[1L]])
}

ledgr_persistent_output_handler <- function(con,
                                            run_id,
                                            run_wall_start,
                                            execution_mode,
                                            .event_initial_capacity = 1024L) {
  state <- new.env(parent = emptyenv())
  state$pending_idx <- 0L
  state$pending_cols <- NULL
  state$pending_initial_capacity <- ledgr_event_buffer_checked_capacity(
    .event_initial_capacity,
    "`.event_initial_capacity`"
  )
  state$pending_states <- vector("list", 0)
  state$pending_states_idx <- 0L
  state$next_diagnostic_seq <- NULL
  state$decision_pulse_count <- NA_integer_
  state$scheduled_skip_count <- NA_integer_
  pulse_fill_rows <- vector("list", 256L)
  pulse_fill_n <- 0L

  next_diagnostic_seq <- function(refresh = FALSE) {
    if (isTRUE(refresh) || is.null(state$next_diagnostic_seq)) {
      state$next_diagnostic_seq <- ledgr_next_diagnostic_seq(con, run_id)
    }
    state$next_diagnostic_seq
  }

  handler <- list()

  # DBI::dbWithTransaction() rolls back on an interrupt but then returns
  # normally, which would let a run finalize as if its rolled-back pulses had
  # never existed. Re-raise the interrupt after the rollback instead.
  handler$run_transaction <- function(fn) {
    interrupted <- FALSE
    result <- DBI::dbWithTransaction(
      con,
      withCallingHandlers(fn(), interrupt = function(cnd) interrupted <<- TRUE)
    )
    if (interrupted) rlang::interrupt()
    result
  }

  handler$record_run_status <- function(status, error_msg = NA_character_) {
    if (status %in% c("FAILED", "DONE", "INCOMPLETE")) state$terminal_status_written <- TRUE
    DBI::dbExecute(
      con,
      "UPDATE runs SET status = ?, error_msg = ? WHERE run_id = ?",
      params = list(status, error_msg, run_id)
    )
    invisible(TRUE)
  }

  handler$terminal_status_written <- function() isTRUE(state$terminal_status_written)

  handler$set_schedule_counts <- function(decision_pulse_count, scheduled_skip_count) {
    state$decision_pulse_count <- as.integer(decision_pulse_count)
    state$scheduled_skip_count <- as.integer(scheduled_skip_count)
    invisible(TRUE)
  }

  handler$write_telemetry <- function(status,
                                      strict = TRUE,
                                      telemetry = NULL,
                                      processed = NA_integer_) {
    elapsed_sec <- ledgr_time_elapsed(run_wall_start, ledgr_time_now())
    err <- tryCatch(
      {
        ledgr_write_run_telemetry(
          con = con,
          run_id = run_id,
          status = status,
          execution_mode = execution_mode,
          elapsed_sec = elapsed_sec,
          pulse_count = as.integer(processed),
          decision_pulse_count = state$decision_pulse_count,
          scheduled_skip_count = state$scheduled_skip_count
        )
        NULL
      },
      error = function(e) e
    )
    if (!is.null(err) && isTRUE(strict)) {
      rlang::abort("Failed to persist run telemetry.", class = "ledgr_run_telemetry_failed", parent = err)
    }
    invisible(is.null(err))
  }

  handler$store_session_telemetry <- function(telemetry) {
    ledgr_store_run_telemetry(run_id, telemetry)
    invisible(TRUE)
  }

  handler$record_failure <- function(msg) {
    handler$record_run_status("FAILED", msg)
    invisible(TRUE)
  }

  handler$abort_run <- function(msg, class = "ledgr_run_failed") {
    handler$record_failure(msg)
    try(handler$write_telemetry("FAILED", strict = FALSE), silent = TRUE)
    rlang::abort(msg, class = class)
  }

  init_pending_cols <- function(capacity) {
    capacity <- as.integer(capacity)
    state$pending_capacity <- capacity
    pending_cols <- new.env(parent = emptyenv())
    pending_cols$event_id <- character(capacity)
    pending_cols$run_id <- character(capacity)
    pending_cols$ts_utc <- as.POSIXct(rep(NA_character_, capacity), tz = "UTC")
    pending_cols$event_type <- character(capacity)
    pending_cols$instrument_id <- character(capacity)
    pending_cols$side <- character(capacity)
    pending_cols$qty <- numeric(capacity)
    pending_cols$price <- numeric(capacity)
    pending_cols$fee <- numeric(capacity)
    pending_cols$meta_json <- character(capacity)
    pending_cols$event_seq <- integer(capacity)
    state$pending_cols <- pending_cols
    invisible(TRUE)
  }

  ensure_pending_capacity <- function(required) {
    next_capacity <- ledgr_event_buffer_next_capacity(
      current_capacity = state$pending_capacity %||% 0L,
      required = required,
      max_events = state$pending_max_events,
      initial_capacity = state$pending_initial_capacity
    )
    if (!is.null(state$pending_cols) && next_capacity <= state$pending_capacity) {
      return(invisible(TRUE))
    }
    old_cols <- state$pending_cols
    old_count <- as.integer(state$pending_idx %||% 0L)
    init_pending_cols(next_capacity)
    if (!is.null(old_cols) && old_count > 0L) {
      idx <- seq_len(old_count)
      for (name in ls(old_cols, all.names = TRUE)) {
        ledgr_event_buffer_setv(state$pending_cols, name, idx, old_cols[[name]][idx])
      }
    }
    invisible(TRUE)
  }

  handler$init_buffers <- function(max_events) {
    state$pending_idx <- 0L
    state$pending_max_events <- ledgr_event_buffer_checked_capacity(max_events, "`max_events`")
    init_pending_cols(ledgr_event_buffer_initial_capacity(
      state$pending_max_events,
      state$pending_initial_capacity
    ))
    state$pending_states <- vector("list", 0)
    state$pending_states_idx <- 0L
    pulse_fill_n <<- 0L
    invisible(TRUE)
  }

  set_pending_value <- function(name, i, value) {
    col <- state$pending_cols[[name]]
    value <- if (inherits(col, "POSIXct")) {
      as.POSIXct(value, tz = "UTC")[[1]]
    } else if (is.character(col)) {
      as.character(value)[[1]]
    } else if (is.integer(col)) {
      as.integer(value)[[1]]
    } else {
      as.numeric(value)[[1]]
    }
    ledgr_event_buffer_setv(state$pending_cols, name, i, value)
  }

  handler$buffer_event <- function(write_res) {
    if (!inherits(write_res, "ledgr_ledger_write_result") || !identical(write_res$status, "WROTE")) {
      return(invisible(FALSE))
    }
    if (is.null(state$pending_cols)) {
      rlang::abort("Ledger event buffer has not been initialized.", class = "ledgr_invalid_state")
    }
    i <- state$pending_idx + 1L
    ensure_pending_capacity(i)
    set_pending_value("event_id", i, write_res$row$event_id)
    set_pending_value("run_id", i, write_res$row$run_id)
    set_pending_value("ts_utc", i, write_res$row$ts_utc)
    set_pending_value("event_type", i, write_res$row$event_type)
    set_pending_value("instrument_id", i, write_res$row$instrument_id)
    set_pending_value("side", i, write_res$row$side)
    set_pending_value("qty", i, write_res$row$qty)
    set_pending_value("price", i, write_res$row$price)
    set_pending_value("fee", i, write_res$row$fee)
    set_pending_value("meta_json", i, write_res$row$meta_json)
    set_pending_value("event_seq", i, write_res$row$event_seq)
    state$pending_idx <- i
    invisible(TRUE)
  }

  stage_fill_event <- function(write_res) {
    if (!inherits(write_res, "ledgr_ledger_write_result") ||
        !identical(write_res$status, "WROTE")) {
      return(invisible(FALSE))
    }
    if (is.null(state$pending_cols)) {
      rlang::abort(
        "Ledger event buffer has not been initialized.",
        class = "ledgr_invalid_state"
      )
    }
    i <- pulse_fill_n + 1L
    if (i > length(pulse_fill_rows)) {
      pulse_fill_rows <<- c(
        pulse_fill_rows,
        vector("list", length(pulse_fill_rows))
      )
    }
    pulse_fill_rows[[i]] <<- write_res$row
    pulse_fill_n <<- i
    invisible(TRUE)
  }

  handler$flush_pulse_events <- function() {
    n <- pulse_fill_n
    if (n == 0L) {
      return(invisible(TRUE))
    }
    start <- state$pending_idx + 1L
    end <- state$pending_idx + n
    ensure_pending_capacity(end)
    ledgr_event_buffer_write_rows(
      state$pending_cols,
      start:end,
      pulse_fill_rows[seq_len(n)]
    )
    state$pending_idx <- end
    pulse_fill_n <<- 0L
    invisible(TRUE)
  }

  handler$pending_event_count <- function() {
    as.integer(state$pending_idx)
  }

  handler$write_run_diagnostics <- function(diagnostics) {
    if (!is.null(diagnostics) && nrow(diagnostics) > 0L) {
      diagnostics$diagnostic_seq <- seq.int(
        from = next_diagnostic_seq(),
        length.out = nrow(diagnostics)
      )
      DBI::dbAppendTable(con, "run_diagnostics", diagnostics)
      state$next_diagnostic_seq <- state$next_diagnostic_seq + nrow(diagnostics)
    }
    invisible(TRUE)
  }

  handler$write_run_evidence <- function(completion, diagnostics) {
    DBI::dbExecute(con, "DELETE FROM run_completion WHERE run_id = ?", params = list(run_id))
    DBI::dbAppendTable(con, "run_completion", completion)
    handler$write_run_diagnostics(diagnostics)
    invisible(TRUE)
  }

  handler$write_exception_diagnostic <- function(diagnostic) {
    # A failed fold transaction may advance the in-memory counter before the
    # database rolls its writes back. Re-read once for the terminal diagnostic.
    diagnostic$diagnostic_seq <- next_diagnostic_seq(refresh = TRUE)
    DBI::dbAppendTable(con, "run_diagnostics", diagnostic)
    invisible(TRUE)
  }

  handler$pending_state_count <- function() {
    as.integer(state$pending_states_idx)
  }

  handler$buffer_strategy_state <- function(ts_utc, state_json) {
    state$pending_states_idx <- state$pending_states_idx + 1L
    if (state$pending_states_idx > length(state$pending_states)) {
      state$pending_states <- c(state$pending_states, vector("list", max(1000L, length(state$pending_states))))
    }
    state$pending_states[[state$pending_states_idx]] <- data.frame(
      run_id = run_id,
      ts_utc = ts_utc,
      state_json = state_json,
      stringsAsFactors = FALSE
    )
    invisible(TRUE)
  }

  handler$write_fill_events <- function(fill_intent, event_seq, use_transaction = FALSE) {
    if (isTRUE(use_transaction)) {
      # The fold is already inside handler$run_transaction(); live mode writes
      # immediately without opening a nested DuckDB transaction.
      return(ledgr_write_fill_events(
        con = con,
        run_id = run_id,
        fill_intent = fill_intent,
        event_seq_start = event_seq,
        use_transaction = FALSE
      ))
    }
    write_res <- ledgr_fill_event_row(run_id, fill_intent, event_seq)
    stage_fill_event(write_res)
    write_res
  }

  handler$append_event_rows <- function(rows) {
    if (!is.null(rows) && nrow(rows) > 0L) {
      DBI::dbAppendTable(con, "ledger_events", rows)
    }
    invisible(TRUE)
  }

  handler$write_strategy_state <- function(ts_utc, state_json) {
    DBI::dbExecute(
      con,
      "INSERT INTO strategy_state (run_id, ts_utc, state_json) VALUES (?, ?, ?)",
      params = list(run_id, ts_utc, state_json)
    )
    invisible(TRUE)
  }

  handler$flush_pending <- function() {
    if (state$pending_idx > 0) {
      cols <- state$pending_cols
      out <- data.frame(
        event_id = cols$event_id[seq_len(state$pending_idx)],
        run_id = cols$run_id[seq_len(state$pending_idx)],
        ts_utc = cols$ts_utc[seq_len(state$pending_idx)],
        event_type = cols$event_type[seq_len(state$pending_idx)],
        instrument_id = cols$instrument_id[seq_len(state$pending_idx)],
        side = cols$side[seq_len(state$pending_idx)],
        qty = cols$qty[seq_len(state$pending_idx)],
        price = cols$price[seq_len(state$pending_idx)],
        fee = cols$fee[seq_len(state$pending_idx)],
        meta_json = cols$meta_json[seq_len(state$pending_idx)],
        event_seq = cols$event_seq[seq_len(state$pending_idx)],
        stringsAsFactors = FALSE
      )
      DBI::dbAppendTable(con, "ledger_events", out)
      state$pending_idx <- 0L
    }
    if (state$pending_states_idx > 0) {
      DBI::dbAppendTable(con, "strategy_state", do.call(rbind, state$pending_states[seq_len(state$pending_states_idx)]))
      state$pending_states_idx <- 0L
      state$pending_states <- vector("list", 0)
    }
    invisible(TRUE)
  }

  structure(handler, class = "ledgr_persistent_output_handler")
}

ledgr_config_opening_positions <- function(cfg) {
  positions <- ledgr_config_named_numeric(cfg$opening$positions)
  positions[positions != 0]
}

# The economic state a carried test window inherits beyond positions and
# cash: FIFO lots, corporate-action entitlements its predecessor bound but did
# not settle, and holdings its predecessor left frozen. NULL fields when the
# opening is not carried.
ledgr_config_opening_carried <- function(cfg) {
  ledgr_opening_carried_normalize(cfg$opening$carried)
}

ledgr_config_opening_cost_basis <- function(cfg, positions) {
  basis <- ledgr_config_named_numeric(cfg$opening$cost_basis)
  if (length(positions) < 1L || length(basis) < 1L) {
    return(stats::setNames(rep(NA_real_, length(positions)), names(positions)))
  }
  out <- stats::setNames(rep(NA_real_, length(positions)), names(positions))
  matched <- intersect(names(positions), names(basis))
  out[matched] <- as.numeric(basis[matched])
  out
}

ledgr_write_opening_position_events <- function(con,
                                                run_id,
                                                ts_utc,
                                                positions,
                                                cost_basis,
                                                event_seq_start,
                                                lots = NULL) {
  rows <- ledgr_opening_position_event_rows(
    run_id = run_id,
    ts_utc = ts_utc,
    positions = positions,
    cost_basis = cost_basis,
    event_seq_start = event_seq_start,
    lots = lots
  )
  if (nrow(rows) > 0L) {
    DBI::dbAppendTable(con, "ledger_events", rows)
  }
  as.integer(event_seq_start) + as.integer(nrow(rows))
}

# Observe, without catching, the condition that ends a run so the body's exit
# guard can record it. Calling handlers run before the body unwinds, so the
# guard sees the condition while the run store is still open.
ledgr_run_fold <- function(config,
                           run_id = NULL,
                           control = list(),
                           metric_context = NULL,
                           history_substrate = NULL) {
  exit_state <- new.env(parent = emptyenv())
  exit_state$condition <- NULL
  exit_state$returned <- FALSE
  observe <- function(cnd) exit_state$condition <- cnd
  withCallingHandlers(
    ledgr_run_fold_impl(
      config, run_id, control, metric_context, exit_state,
      history_substrate = history_substrate
    ),
    error = observe,
    interrupt = observe
  )
}

ledgr_run_fold_return <- function(exit_state, run_id, db_path) {
  exit_state$returned <- TRUE
  list(run_id = run_id, db_path = db_path)
}

# A run that exits by a condition after its row exists, without this
# invocation having written a terminal status, is recorded FAILED. DONE and
# INCOMPLETE rows are never touched. The guard never masks the condition.
ledgr_run_fold_exit_guard <- function(exit_state, con, run_id, output_handler = NULL) {
  if (isTRUE(exit_state$returned) || is.null(exit_state$condition)) {
    return(invisible(FALSE))
  }
  if (is.function(output_handler$terminal_status_written) &&
      isTRUE(output_handler$terminal_status_written())) {
    return(invisible(FALSE))
  }
  cnd <- exit_state$condition
  msg <- if (inherits(cnd, "interrupt")) {
    "Run interrupted before completion."
  } else {
    conditionMessage(cnd)
  }
  if (!is.character(msg) || length(msg) != 1L || is.na(msg) || !nzchar(msg)) {
    msg <- sprintf("Run exited before completion (%s).", class(cnd)[[1L]])
  }
  try(
    DBI::dbExecute(
      con,
      "UPDATE runs SET status = 'FAILED', error_msg = ? WHERE run_id = ? AND status IN ('CREATED', 'RUNNING', 'FAILED')",
      params = list(msg, run_id)
    ),
    silent = TRUE
  )
  invisible(TRUE)
}

ledgr_run_snapshot_history_start <- function(con, snapshot_id) {
  seconds <- DBI::dbGetQuery(
    con,
    paste(
      "SELECT epoch(MIN(ts_utc)) AS epoch_seconds",
      "FROM snapshot_bars WHERE snapshot_id = ?"
    ),
    params = list(snapshot_id)
  )$epoch_seconds[[1L]]
  as.POSIXct(seconds, origin = "1970-01-01", tz = "UTC")
}

ledgr_run_fold_impl <- function(config,
                                run_id,
                                control,
                                metric_context,
                                exit_state,
                                history_substrate = NULL) {
  prepared <- ledgr_run_prepare_config(config)
  cfg <- prepared$config
  db_path <- prepared$db_path
  instrument_ids <- prepared$instrument_ids
  start_ts_utc <- prepared$start_ts_utc
  end_ts_utc <- prepared$end_ts_utc
  initial_cash <- prepared$initial_cash
  opening_positions <- prepared$opening_positions
  opening_cost_basis <- prepared$opening_cost_basis
  opening_carried <- prepared$opening_carried
  final_execution_ts_utc <- prepared$final_execution_ts_utc
  seed <- prepared$seed
  compiled_accounting_model <- prepared$compiled_accounting_model
  availability_active <- ledgr_availability_config_active(cfg)
  run_wall_start <- ledgr_time_now()

  if (!is.null(seed)) {
    had_seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
    old_seed <- if (had_seed) {
      get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
    } else {
      NULL
    }
    on.exit({
      if (had_seed) {
        assign(".Random.seed", old_seed, envir = .GlobalEnv)
      } else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
        rm(".Random.seed", envir = .GlobalEnv)
      }
    }, add = TRUE)
  }

  engine <- ledgr_run_prepare_engine(cfg, db_path)
  execution_mode <- engine$execution_mode
  checkpoint_every <- engine$checkpoint_every
  snapshot_id <- engine$snapshot_id
  snapshot_db_path <- engine$snapshot_db_path
  snapshot_hash_for_features <- NULL

  opened <- ledgr_store_open(db_path, mode = "create")
  drv <- opened$drv
  con <- opened$con
  on.exit({
    ledgr_checkpoint_duckdb(con)
    suppressWarnings(try(DBI::dbDisconnect(con, shutdown = TRUE), silent = TRUE))
    suppressWarnings(try(duckdb::duckdb_shutdown(drv), silent = TRUE))
  }, add = TRUE)

  ledgr_validate_schema_once(con)
  # Refused on the run's own connection before the run is registered (Cut 16
  # decision 23).
  ledgr_availability_require_fact_knowledge(con, snapshot_id)

  registration <- ledgr_run_registration(
    con = con,
    cfg = cfg,
    run_id = run_id,
    seed = seed,
    snapshot_id = snapshot_id,
    metric_context = metric_context
  )
  run_id <- registration$run_id
  is_resume <- registration$is_resume
  metric_context <- registration$metric_context
  if (isTRUE(registration$is_done)) {
    return(ledgr_run_fold_return(exit_state, run_id, db_path))
  }
  guard_handler <- NULL
  # Registered after the connection-closing handler but run before it.
  on.exit(ledgr_run_fold_exit_guard(exit_state, con, run_id, guard_handler), add = TRUE, after = FALSE)

  output_handler <- ledgr_persistent_output_handler(
    con = con,
    run_id = run_id,
    run_wall_start = run_wall_start,
    execution_mode = execution_mode
  )
  guard_handler <- output_handler
  fail_run <- output_handler$abort_run

  ledgr_run_registration_provenance(
    con = con,
    output_handler = output_handler,
    run_id = run_id,
    cfg = cfg,
    is_resume = is_resume
  )

  # Snapshot integration:
  # - verify snapshot status SEALED
  # - ensure one PID-bound complete current-rule verification
  # - enforce universe subset and inclusive start/end coverage
  # - create TEMP VIEW instruments/bars so the fold reads sealed snapshot data
  snapshot <- ledgr_run_snapshot_guard(
    con = con,
    snapshot_db_path = snapshot_db_path,
    db_path = db_path,
    snapshot_id = snapshot_id,
    instrument_ids = instrument_ids,
    start_ts_utc = start_ts_utc,
    end_ts_utc = end_ts_utc,
    run_id = run_id,
    fail_run = fail_run,
    availability_active = availability_active
  )
  snapshot_hash_for_features <- snapshot$snapshot_hash
  history_policy <- ledgr_history_identity_require_current(cfg$history)
  corporate_action_rows <- ledgr_corporate_action_rows(con, snapshot_id)
  availability_data <- if (availability_active && is.null(history_substrate)) {
    ledgr_availability_provider_data(con, snapshot_id)
  } else {
    NULL
  }
  availability_provider <- NULL
  # A continued carry window executes its final decision at the next session
  # open, so its history reaches that session's close.
  continuation <- NULL
  history_end_ts_utc <- end_ts_utc
  availability_sessions <- if (availability_active) {
    sessions <- if (is.null(history_substrate)) {
      availability_data$sessions
    } else {
      history_substrate$sessions
    }
    continuation <- ledgr_availability_continuation(sessions, final_execution_ts_utc)
    if (!is.null(continuation)) history_end_ts_utc <- continuation$close
    if (!is.null(history_substrate)) {
      history_start <- ledgr_run_snapshot_history_start(con, snapshot_id)
      ledgr_history_substrate_validate_owner(
        history_substrate,
        snapshot_hash = snapshot_hash_for_features,
        history_policy = history_policy,
        instrument_ids = instrument_ids,
        required_start = as.POSIXct(history_start, tz = "UTC"),
        required_end = history_end_ts_utc
      )
    }
    sessions
  } else {
    NULL
  }

  if (availability_active) {
    ledgr_availability_require_coverage(
      list(sessions = availability_sessions),
      ledgr_snapshot_bar_range(con, snapshot_id, start_ts_utc, end_ts_utc)
    )
  }
  calendar <- if (availability_active) {
    ledgr_availability_run_calendar(
      list(sessions = availability_sessions),
      start_ts_utc,
      end_ts_utc,
      final_execution_ts_utc
    )
  } else {
    ledgr_run_snapshot_calendar(
      con,
      instrument_ids,
      start_ts_utc,
      end_ts_utc
    )
  }
  pulses <- calendar$pulses
  pulses_posix <- calendar$pulses_posix
  pulses_iso <- calendar$pulses_iso
  history_axis <- pulses_posix
  if (availability_active) {
    history_axis <- if (is.null(history_substrate)) {
      history_start <- ledgr_run_snapshot_history_start(con, snapshot_id)
      ledgr_availability_calendar(
        list(sessions = availability_sessions),
        as.POSIXct(history_start, tz = "UTC"),
        history_end_ts_utc
      )$pulses_posix
    } else {
      history_substrate$axis
    }
  }

  terminal_completion <- if (availability_active && is_resume) {
    ledgr_run_completion_read(
      con,
      run_id,
      required = identical(registration$status, "INCOMPLETE")
    )
  } else {
    NULL
  }
  if (!is.null(terminal_completion)) {
    terminal_completion <- ledgr_run_completion_validate(
      terminal_completion,
      run_id,
      calendar,
      stored_status = registration$status
    )
  }
  if (identical(registration$status, "INCOMPLETE")) {
    ledgr_run_completion_validate_finalized(
      con,
      terminal_completion,
      run_id,
      calendar
    )
    return(ledgr_run_fold_return(exit_state, run_id, db_path))
  }
  terminal_recovery <- !is.null(terminal_completion) &&
    registration$status %in% c("RUNNING", "FAILED")

  feature_defs <- ledgr_feature_defs_from_config(cfg)
  active_alias_map <- ledgr_alias_map_from_config(cfg)
  run_feature_matrix <- list()
  if (length(feature_defs) > 0) {
    feature_defs <- feature_defs[order(
      vapply(feature_defs, function(d) d$id, character(1)),
      method = "radix"
    )]
  }
  DBI::dbExecute(
    con,
    "UPDATE runs SET execution_mode = ?, schema_version = ? WHERE run_id = ?",
    params = list(execution_mode, ledgr_experiment_store_schema_version, run_id)
  )
  if (!is.finite(checkpoint_every) || is.na(checkpoint_every) || checkpoint_every < 1 || (checkpoint_every %% 1) != 0) {
    rlang::abort("engine.checkpoint_every must be an integer >= 1.", class = "ledgr_invalid_config")
  }

  resume <- if (isTRUE(terminal_recovery)) {
    list(
      resume_posix = pulses_posix[[1L]],
      resume_iso = pulses_iso[[1L]],
      start_idx = length(pulses_posix) + 1L,
      next_event_seq = NA_integer_
    )
  } else {
    ledgr_run_resume(
      con = con,
      output_handler = output_handler,
      run_id = run_id,
      is_resume = is_resume,
      calendar = calendar,
      start_ts_utc = start_ts_utc,
      opening_positions = opening_positions,
      opening_cost_basis = opening_cost_basis,
      opening_lots = opening_carried$lots
    )
  }
  resume_posix <- resume$resume_posix
  resume_iso <- resume$resume_iso
  start_idx <- resume$start_idx
  next_event_seq <- resume$next_event_seq

  prepared_control <- ledgr_run_prepare_control(control)
  fast_context <- prepared_control$fast_context
  max_pulses <- prepared_control$max_pulses
  cost_resolver <- ledgr_cost_resolver_from_plan_json(cfg$cost_model$cost_plan_json)

  processed <- 0L
  total_pulses <- length(pulses) - start_idx + 1L
  if (total_pulses < 0) total_pulses <- 0L
  telemetry_stride <- ledgr_run_prepare_telemetry_stride(control)
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
  telemetry$t_target <- if (telemetry_cap > 0) rep(NA_real_, telemetry_cap) else numeric(0)
  telemetry$t_event <- if (telemetry_cap > 0) rep(NA_real_, telemetry_cap) else numeric(0)
  telemetry$t_exec <- if (telemetry_cap > 0) rep(NA_real_, telemetry_cap) else numeric(0)
  telemetry_idx <- 0L

  state_env <- new.env(parent = emptyenv())
  initial_lot_state <- ledgr_lot_state_from_opening(
    instrument_ids = instrument_ids,
    positions = opening_positions,
    cost_basis = opening_cost_basis,
    lots = opening_carried$lots
  )
  if (identical(execution_mode, "audit_log")) {
    initial_positions <- rep(0, length(instrument_ids))
    names(initial_positions) <- instrument_ids
    if (length(opening_positions) > 0L) {
      initial_positions[names(opening_positions)] <- as.numeric(opening_positions)
    }
    state_env$current <- list(cash = as.numeric(initial_cash), positions = initial_positions, lot_state = initial_lot_state)
  } else {
    state_env$current <- list(cash = as.numeric(initial_cash), positions = opening_positions, lot_state = initial_lot_state)
  }
  instrument_index <- seq_along(instrument_ids)
  names(instrument_index) <- instrument_ids
  if (is_resume && !isTRUE(terminal_recovery) && length(pulses) > 0) {
    resume_state <- ledgr_state_asof(con, run_id, initial_cash, resume_posix, instrument_ids = instrument_ids)
    if (identical(execution_mode, "audit_log")) {
      pos_vec <- rep(0, length(instrument_ids))
      names(pos_vec) <- instrument_ids
      if (!is.null(resume_state$positions) && length(resume_state$positions) > 0) {
        pos_vec[names(resume_state$positions)] <- as.numeric(resume_state$positions)
      }
      state_env$current <- list(cash = resume_state$cash, positions = pos_vec, lot_state = resume_state$lot_state)
    } else {
      state_env$current <- list(cash = resume_state$cash, positions = resume_state$positions, lot_state = resume_state$lot_state)
    }
  }

  preflight_start <- ledgr_take_preflight_start()
  if (is.null(preflight_start)) {
    preflight_start <- ledgr_time_now()
  }
  run_feature_series <- NULL
  run_feature_matrix <- NULL
  runtime_projection <- NULL
  bars_by_id <- NULL
  bars_cols_by_id <- NULL
  bars_mat <- NULL
  static_bars_views <- NULL
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
  use_bars_cache <- TRUE
  use_fast_context <- !availability_active
  if (isTRUE(use_bars_cache)) {
    bars_all <- NULL
    if (!availability_active || is.null(history_substrate)) {
      preparation_start <- if (availability_active) history_axis[[1L]] else start_ts_utc
      preparation_end <- if (availability_active) {
        history_axis[[length(history_axis)]]
      } else {
        end_ts_utc
      }
      start_iso <- ledgr_normalize_ts_utc(preparation_start)
      end_iso <- ledgr_normalize_ts_utc(preparation_end)
      start_ts <- as.POSIXct(start_iso, tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ")
      end_ts <- as.POSIXct(end_iso, tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ")
      ids_sql <- paste(DBI::dbQuoteString(con, instrument_ids), collapse = ", ")
      bars_all <- DBI::dbGetQuery(
        con,
        paste0(
          "SELECT instrument_id, ts_utc, open, high, low, close, volume, ",
          "CAST('NONE' AS TEXT) AS gap_type, ",
          "CAST(FALSE AS BOOLEAN) AS is_synthetic ",
          "FROM snapshot_bars ",
          "WHERE snapshot_id = ? ",
          "AND instrument_id IN (", ids_sql, ") ",
          "AND ts_utc >= ? AND ts_utc <= ? ",
          "ORDER BY instrument_id, ts_utc"
        ),
        params = list(snapshot_id, start_ts, end_ts)
      )
      if (nrow(bars_all) == 0) {
        fail_run("No bars found for feature hydration.", class = "ledgr_missing_bars")
      }
    }

    if (availability_active) {
      if (is.null(history_substrate)) {
        availability_config <- cfg
        availability_config$history_policy <- history_policy
        history_substrate <- ledgr_history_substrate(
          bars = bars_all,
          instrument_ids = instrument_ids,
          axis = history_axis,
          availability_data = availability_data,
          availability_config = availability_config,
          snapshot_hash = snapshot_hash_for_features,
          source_start_utc = as.POSIXct(history_start, tz = "UTC")
        )
      }
      bars_all <- NULL
    } else {
      raw_bars_by_id <- split(bars_all, as.character(bars_all$instrument_id))
      bars_all <- NULL
      bars_by_id <- list()
      for (instrument_id in instrument_ids) {
        b <- raw_bars_by_id[[instrument_id]]
        if (is.null(b) || nrow(b) == 0) {
        fail_run(sprintf("Missing bars for instrument_id=%s during feature hydration.", instrument_id), class = "ledgr_missing_bars")
      }
        if (nrow(b) != length(pulses)) {
        fail_run("Feature hydration requires complete per-instrument coverage.", class = "ledgr_missing_bars")
      }
      ts_match <- as.POSIXct(b$ts_utc, tz = "UTC")
      if (any(ts_match != pulses_posix)) {
        fail_run("Feature hydration bars are misaligned with pulse timestamps.", class = "ledgr_missing_bars")
      }
        bars_by_id[[instrument_id]] <- b
      }
      raw_bars_by_id <- NULL
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
      bars_cols_by_id <- NULL
      static_bars_views <- ledgr_bars_pulse_views(
        bars_mat = bars_mat,
        instrument_ids = instrument_ids,
        pulses_posix = pulses_posix
      )
    }
  }

  feature_engine_version <- ledgr_feature_engine_version(availability_active)
  if (length(feature_defs) > 0) {
    def_ids <- vapply(feature_defs, function(d) d$id, character(1))
    if (availability_active) {
      # One preparation treats each instrument's inputs once and calculates
      # every definition on the substrate axis.
      run_feature_matrix <- ledgr_history_compute_feature_series(
        substrate = history_substrate,
        definitions = stats::setNames(feature_defs, def_ids),
        calculation_start = ledgr_history_calculation_start(history_substrate),
        calculation_end = end_ts_utc
      )
    } else {
      run_feature_series <- stats::setNames(
        lapply(feature_defs, function(...) list()),
        def_ids
      )
      for (def in feature_defs) {
        for (instrument_id in instrument_ids) {
          b <- bars_by_id[[instrument_id]]
          values <- ledgr_compute_feature_series(b, def)
          if (length(values) != nrow(b)) {
            fail_run(sprintf("Feature hydration length mismatch for %s/%s.", def$id, instrument_id))
          }
          run_feature_series[[def$id]][[instrument_id]] <- as.numeric(values)
        }
      }
      n_inst <- length(instrument_ids)
      n_def <- length(def_ids)
      run_feature_matrix <- vector("list", n_def)
      for (d in seq_len(n_def)) {
        id <- def_ids[[d]]
        mat <- matrix(NA_real_, nrow = n_inst, ncol = length(pulses_posix))
        for (j in seq_along(instrument_ids)) {
          mat[j, ] <- as.numeric(run_feature_series[[id]][[instrument_ids[[j]]]])
        }
        run_feature_matrix[[d]] <- mat
      }
      names(run_feature_matrix) <- def_ids
      run_feature_series <- NULL
    }
    bars_by_id <- NULL
  } else {
    bars_by_id <- NULL
  }
  runtime_projection <- ledgr_projection_from_feature_matrix(
    feature_matrix = run_feature_matrix %||% list(),
    universe = instrument_ids,
    pulses_posix = if (availability_active) history_axis else pulses_posix,
    feature_engine_version = feature_engine_version,
    alias_index = NULL
  )
  if (availability_active) {
    history_substrate <- ledgr_history_substrate_bind_features(
      history_substrate,
      runtime_projection
    )
    availability_provider <- ledgr_availability_provider_from_substrate(
      history_substrate,
      cfg,
      snapshot_hash_for_features
    )
  }
  run_feature_matrix <- NULL
  telemetry$t_pre <- ledgr_time_elapsed(preflight_start, ledgr_time_now())

  schedule_params <- if (identical(cfg$strategy$id, "functional")) {
    cfg$strategy_params %||% list()
  } else {
    cfg$strategy$params %||% list()
  }
  schedule <- ledgr_compile_strategy_schedule(
    declaration = cfg$strategy_schedule,
    strategy_params = schedule_params,
    sessions = availability_sessions,
    pulses_posix = pulses_posix
  )
  output_handler$set_schedule_counts(
    schedule$decision_pulse_count,
    schedule$scheduled_skip_count
  )

  if (isTRUE(terminal_recovery)) {
    recovery_equity <- ledgr_run_terminal_recovery_equity(
      con = con,
      run_id = run_id,
      completion = terminal_completion,
      calendar = calendar,
      bars_mat = if (availability_active) history_substrate$bars else bars_mat,
      instrument_ids = instrument_ids,
      initial_cash = initial_cash,
      availability_provider = availability_provider,
      source_pulses_posix = if (availability_active) history_axis else pulses_posix,
      pulse_columns = if (availability_active) {
        unname(history_substrate$pulse_index[ledgr_projection_pulse_names(pulses_posix)])
      } else {
        NULL
      }
    )
    ledgr_run_finalize(
      con = con,
      output_handler = output_handler,
      run = list(
        run_id = run_id,
        start_ts_utc = start_ts_utc,
        end_ts_utc = end_ts_utc,
        instrument_ids = instrument_ids,
        initial_cash = initial_cash,
        availability_active = availability_active
      ),
      calendar = calendar,
      projection = list(
        bars_mat = bars_mat
      ),
      fold = list(
        telemetry = telemetry,
        processed = length(recovery_equity),
        status = as.character(terminal_completion$intended_terminal_status[[1L]]),
        equity_facts = recovery_equity
      )
    )
    return(ledgr_run_fold_return(exit_state, run_id, db_path))
  }

  strategy <- ledgr_strategy_from_config(cfg)
  strategy_fn <- strategy$fn
  strategy_is_functional <- TRUE
  if (!is.function(strategy_fn)) {
    rlang::abort("Strategy is not a function; check strategy configuration.", class = "ledgr_invalid_strategy")
  }
  strategy_params <- strategy$params
  strategy_call_signature <- strategy$signature
  if (!is.null(schedule$decision_due) &&
      identical(schedule$decision_pulse_count, 0L) &&
      !any(as.numeric(state_env$current$positions) != 0)) {
    ledgr_schedule_abort(
      "The resolved strategy schedule has no decision pulse and the run has no opening or carried position.",
      "ledgr_schedule_no_decision"
    )
  }
  strategy_preflight <- ledgr_strategy_preflight(strategy_fn)
  ledgr_run_resume_preflight(is_resume, strategy_preflight)
  output_handler$record_run_status("RUNNING", NA_character_)

  state_prev_mem <- NULL
  if (is_resume) {
    state_prev_mem <- ledgr_strategy_state_prev(con, run_id, resume_iso)
  }
  current_positions <- state_env$current$positions
  full_positions <- stats::setNames(rep(0, length(instrument_ids)), instrument_ids)
  if (!is.null(current_positions) && length(current_positions) > 0L) {
    matched_positions <- intersect(names(current_positions), instrument_ids)
    full_positions[matched_positions] <- as.numeric(current_positions[matched_positions])
  }
  state_env$current$positions <- full_positions
  risk_chain <- ledgr_risk_plan_reconstruct(cfg$risk_chain$risk_plan_json)
  risk_plan <- ledgr_risk_plan_compile(risk_chain, params = strategy_params)
  corporate_action_plan <- ledgr_corporate_action_plan(
    rows = corporate_action_rows,
    policy_identity = cfg$corporate_actions %||% NULL,
    pulses_posix = pulses_posix,
    instrument_ids = instrument_ids,
    existing_events = ledgr_corporate_action_existing_events(con, run_id),
    start_idx = start_idx,
    dispositions_active = availability_active,
    carried = opening_carried$pending
  )

  fold_execution <- ledgr_execution_spec(
    run_id = run_id,
    instrument_ids = instrument_ids,
    strategy_fn = strategy_fn,
    strategy_params = strategy_params,
    strategy_call_signature = strategy_call_signature,
    strategy_is_functional = strategy_is_functional,
    pulses_posix = pulses_posix,
    pulses_iso = pulses_iso,
    start_idx = start_idx,
    max_pulses = max_pulses,
    checkpoint_every = checkpoint_every,
    telemetry_stride = telemetry_stride,
    state = state_env$current,
    state_prev = state_prev_mem,
    bars_by_id = list(),
    bars_mat = bars_mat,
    static_bars_views = static_bars_views,
    history_substrate = history_substrate,
    static_feature_views = NULL,
    feature_defs = feature_defs,
    runtime_projection = if (availability_active) NULL else runtime_projection,
    active_alias_map = active_alias_map,
    risk_plan = risk_plan,
    cost_resolver = cost_resolver,
    event_seq_start = next_event_seq,
    telemetry = telemetry,
    seed = seed,
    event_mode = if (identical(execution_mode, "db_live")) "live" else "buffered",
    use_fast_context = use_fast_context,
    compiled_accounting_model = compiled_accounting_model,
    availability_provider = availability_provider,
    execution_opportunities_posix = if (availability_active) {
      calendar$execution_opportunities_posix
    } else {
      NULL
    },
    corporate_action_plan = corporate_action_plan,
    corporate_action_policy = if (is.null(cfg$corporate_actions)) {
      NULL
    } else {
      ledgr_corporate_action_identity_decode(cfg$corporate_actions)$policy
    },
    frozen_at_resume = if (availability_active && is_resume && start_idx > 1L) {
      ledgr_availability_frozen_at(
        con, run_id, initial_cash, availability_provider,
        history_substrate$bars,
        instrument_ids, pulses_posix, start_idx - 1L,
        source_pulses_posix = history_axis,
        pulse_columns = unname(history_substrate$pulse_index[
          ledgr_projection_pulse_names(pulses_posix)
        ])
      )
    } else if (length(opening_carried$frozen) > 0L) {
      # A carried test window opens with the holdings its predecessor left
      # frozen, so freeze entry is not recorded twice across the boundary.
      as.character(opening_carried$frozen)
    } else {
      NULL
    },
    final_execution_posix = calendar$final_execution_posix,
    last_executed_at_resume = if (availability_active && is_resume && start_idx > 1L) {
      DBI::dbGetQuery(
        con,
        "SELECT MAX(ts_utc) AS ts_utc FROM ledger_events WHERE run_id = ? AND event_type = 'FILL'",
        params = list(run_id)
      )$ts_utc
    } else {
      NULL
    },
    decision_due = schedule$decision_due,
    decision_pulse_count = schedule$decision_pulse_count,
    scheduled_skip_count = schedule$scheduled_skip_count
  )

  fold_result <- tryCatch(
    ledgr_execute_fold(fold_execution, output_handler),
    error = function(e) {
      output_handler$record_failure(conditionMessage(e))
      ledgr_finalize_fold_telemetry(
        output_handler = output_handler,
        status = "FAILED",
        telemetry = telemetry,
        processed = 0L,
        strict = FALSE
      )
      rlang::cnd_signal(e)
    }
  )

  processed <- fold_result$processed
  full_run <- fold_result$full_run
  telemetry <- fold_result$telemetry

  if (!isTRUE(full_run)) {
    if (availability_active && length(fold_result$equity_facts) > 0L) {
      partial_error <- tryCatch({
        ledgr_run_equity_prefix_commit(
          con = con,
          run_id = run_id,
          current = ledgr_run_fold_equity_frame(
            run_id,
            fold_result$equity_facts
          ),
          calendar = calendar
        )
        NULL
      }, error = identity)
      if (!is.null(partial_error)) {
        output_handler$record_failure(conditionMessage(partial_error))
        ledgr_finalize_fold_telemetry(
          output_handler = output_handler,
          status = "FAILED",
          telemetry = telemetry,
          processed = processed,
          strict = FALSE
        )
        rlang::cnd_signal(partial_error)
      }
    }
    ledgr_finalize_fold_telemetry(
      output_handler = output_handler,
      status = "RUNNING",
      telemetry = telemetry,
      processed = processed
    )
    return(ledgr_run_fold_return(exit_state, run_id, db_path))
  }
  finalized <- ledgr_run_finalize(
    con = con,
    output_handler = output_handler,
    run = list(
      run_id = run_id,
      start_ts_utc = start_ts_utc,
      end_ts_utc = end_ts_utc,
      instrument_ids = instrument_ids,
      initial_cash = initial_cash,
      availability_active = availability_active
    ),
    calendar = calendar,
    projection = list(
      bars_mat = bars_mat
    ),
    fold = list(
      telemetry = telemetry,
      processed = processed,
      status = fold_result$status,
      equity_facts = fold_result$equity_facts
    )
  )
  telemetry <- finalized$telemetry

  ledgr_run_fold_return(exit_state, run_id, db_path)
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
  ledgr_json_read_nested(row$state_json[[1]])
}

ledgr_state_asof <- function(con, run_id, initial_cash, ts_utc, instrument_ids = character()) {
  rows <- DBI::dbGetQuery(
    con,
    "
    SELECT event_id, run_id, ts_utc, event_type, instrument_id, side, qty, price, fee, meta_json, event_seq
    FROM ledger_events
    WHERE run_id = ? AND ts_utc <= ?
    ORDER BY event_seq
    ",
    params = list(run_id, ts_utc)
  )

  prepared <- ledgr_prepare_accounting_events(rows, instrument_ids)
  replay <- ledgr_replay_accounting_events(prepared, initial_cash = initial_cash)
  cash <- replay$cash
  pos <- replay$positions

  held <- pos[abs(pos) > 0]
  positions_value <- 0
  if (length(held) > 0) {
    held_ids <- names(held)
    ids_sql <- paste(DBI::dbQuoteString(con, held_ids), collapse = ", ")
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
    positions_value <- sum(as.numeric(held) * close_by_id[held_ids])
  }

  list(
    cash = cash,
    positions = pos,
    equity = cash + positions_value,
    lot_state = replay$lot_state
  )
}

# A config built by ledgr_config() carries the experiment's own indicator
# objects by id (attribute `ledgr_feature_indicators`, outside identity and
# storage). Dispatch resolves a custom definition from them; the session
# registry is only read for an id the config does not carry (for example a
# config read back from JSON) and is never written by a run.
ledgr_feature_defs_from_config <- function(cfg) {
  feature_indicators <- attr(cfg, "ledgr_feature_indicators", exact = TRUE)
  feats <- cfg$features
  if (is.null(feats) || is.null(feats$enabled) || !isTRUE(feats$enabled)) {
    return(list())
  }

  defs <- feats$defs
  if (is.null(defs) || !is.list(defs) || length(defs) < 1) {
    rlang::abort("features.enabled is TRUE but features.defs is missing/empty.", class = "ledgr_invalid_config")
  }

  availability_active <- ledgr_availability_config_active(cfg)
  stored_fingerprint <- function(ind) {
    fingerprint <- ledgr_indicator_fingerprint(ind)
    if (availability_active) {
      fingerprint <- ledgr_active_feature_fingerprint(
        ledgr_precompute_feature_def_from_indicator(ind)
      )
    }
    fingerprint
  }
  add_def <- function(def, stored) {
    for (field in c("gap_contract", "history_class", "required_fields",
                    "input_carry", "tolerance")) {
      if (!is.null(stored[[field]])) def[[field]] <- stored[[field]]
    }
    def$fingerprint <- stored$fingerprint %||% ledgr_feature_def_fingerprint(def)
    def
  }
  registered <- function(id) {
    own <- feature_indicators[[id]]
    if (inherits(own, "ledgr_indicator")) return(own)
    if (!exists("ledgr_indicator_get", mode = "function")) return(NULL)
    ind <- tryCatch(ledgr_indicator_get(id), error = function(e) NULL)
    if (inherits(ind, "ledgr_indicator")) ind else NULL
  }
  # A stored fingerprint that is not the package built-in's identity names a
  # user indicator whose id matches a built-in id pattern; it runs its own
  # function (Cut 16 decision 19), never the built-in. `registered()` resolves
  # it from the experiment's own indicators carried with the config first and
  # reads the session registry only for an id the config does not carry; an
  # id resolvable by neither refuses.
  shadowed <- function(d, builtin) {
    if (is.null(d$fingerprint) || identical(d$fingerprint, stored_fingerprint(builtin))) {
      return(FALSE)
    }
    if (is.null(registered(d$id))) {
      rlang::abort(
        sprintf(
          paste0(
            "Feature '%s' in the run config matches neither the built-in of ",
            "that id nor a registered indicator."
          ),
          d$id
        ),
        class = "ledgr_run_hash_mismatch"
      )
    }
    TRUE
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

    if (identical(id, "return_1") && !shadowed(d, ledgr_ind_returns(1L))) {
      out[[length(out) + 1L]] <- add_def(ledgr_feature_return_1(), d)
      next
    }

    if (grepl("^sma_\\d+$", id) &&
        !shadowed(d, ledgr_ind_sma(as.integer(sub("^sma_", "", id))))) {
      n <- as.integer(sub("^sma_", "", id))
      out[[length(out) + 1L]] <- add_def(ledgr_feature_sma_n(n), d)
      next
    }

    ind <- registered(id)
    if (!is.null(ind)) {
      current_fingerprint <- stored_fingerprint(ind)
      if (!is.null(d$fingerprint) && !identical(d$fingerprint, current_fingerprint)) {
        rlang::abort(
          sprintf("Registered indicator '%s' no longer matches the fingerprint stored in the run config.", id),
          class = "ledgr_run_hash_mismatch"
        )
      }
      def <- ledgr_precompute_feature_def_from_indicator(ind)
      if (!is.null(d$stable_after)) def$stable_after <- d$stable_after
      if (!is.null(d$params)) def$params <- d$params
      def$fingerprint <- current_fingerprint
      if (!is.null(d$gap_contract)) def$gap_contract <- d$gap_contract
      out[[length(out) + 1L]] <- def
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

  strategy <- function(fn, params) {
    list(fn = fn, params = params, signature = "ctx_params")
  }

  if (identical(id, "hold_zero")) return(strategy(ledgr_strategy_hold_zero, params))
  if (identical(id, "echo")) return(strategy(ledgr_strategy_echo, params))
  if (identical(id, "ts_rule")) return(strategy(ledgr_strategy_ts_rule, params))
  if (identical(id, "state_prev")) return(strategy(ledgr_strategy_state_prev_targets, params))
  if (identical(id, "functional")) {
    key <- params$strategy_key
    signature <- params$call_signature
    strategy_params <- if (is.null(cfg$strategy_params)) list() else cfg$strategy_params
    return(list(fn = ledgr_get_strategy_fn(key), params = strategy_params, signature = signature))
  }

  rlang::abort(sprintf("Unknown strategy.id: %s", id), class = "ledgr_invalid_config")
}

ledgr_strategy_ts_rule <- function(ctx, params) {
  cut <- params$cutover_ts_utc
  before <- params$targets_before
  after <- params$targets_after

  if (!is.character(cut) || length(cut) != 1 || is.na(cut) || !nzchar(cut)) {
    rlang::abort("ts_rule strategy requires params$cutover_ts_utc as an ISO8601 UTC string.", class = "ledgr_invalid_strategy")
  }
  if (!is.numeric(before) || is.null(names(before))) {
    rlang::abort("ts_rule strategy requires params$targets_before as a named numeric vector.", class = "ledgr_invalid_strategy")
  }
  if (!is.numeric(after) || is.null(names(after))) {
    rlang::abort("ts_rule strategy requires params$targets_after as a named numeric vector.", class = "ledgr_invalid_strategy")
  }

  if (ctx$ts_utc < cut) {
    list(targets = before, state_update = list())
  } else {
    list(targets = after, state_update = list())
  }
}

