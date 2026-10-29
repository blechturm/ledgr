# One output handler (v0.2.3 cut 1, WS1). The fold, ledgr_run() and
# ledgr_sweep() materialize fold output through one handler whose storage
# differs only by sink: a DuckDB sink for the audit_log and db_live stores and
# a memory sink for sweep candidates. The handler owns the mechanisms both
# storage kinds share: the typed event column buffer, pulse fill staging,
# capacity growth, status and completion bookkeeping, and diagnostic
# numbering. A sink owns only what differs by storage. Each handler exposes
# exactly the methods its storage kind supports; an unsupported optional
# capability is absent, never a callable stub, so `is.function()` guards and
# ledgr_require_compiled_spot_fifo_dispatch() see the true capability set.
# Design: inst/design/ledgr_v0_2_3_spec_packet/ws1_output_handler_design.md.

ledgr_output_event_columns <- c(
  "event_id", "run_id", "ts_utc", "event_type", "instrument_id", "side",
  "qty", "price", "fee", "meta_json", "event_seq"
)

ledgr_output_typed_columns <- c(
  "cash_delta", "position_delta", "event_realized", "event_cost_basis", "meta"
)

# DuckDB sink: the run store of one run. Durable appends, transactions with
# interrupt re-raise, db_live immediate writes, diagnostic sequence seeding
# from the store, telemetry and strategy-state persistence.
ledgr_output_sink_duckdb <- function(con, run_id, run_wall_start, execution_mode) {
  state <- new.env(parent = emptyenv())
  state$decision_pulse_count <- NA_integer_
  state$scheduled_skip_count <- NA_integer_
  state$state_ts <- character(0)
  state$state_json <- character(0)
  state$state_n <- 0L

  sink <- list(run_id = run_id)
  sink$drains <- TRUE
  sink$requires_init <- TRUE
  sink$serialize_meta_json <- TRUE
  sink$typed_columns <- character(0)
  sink$nonwrote_buffer_result <- FALSE
  sink$refresh_seq_on_exception <- TRUE

  # DBI::dbWithTransaction() rolls back on an interrupt but then returns
  # normally, which would let a run finalize as if its rolled-back pulses had
  # never existed. Re-raise the interrupt after the rollback instead.
  sink$transaction <- function(fn) {
    interrupted <- FALSE
    result <- DBI::dbWithTransaction(
      con,
      withCallingHandlers(fn(), interrupt = function(cnd) interrupted <<- TRUE)
    )
    if (interrupted) rlang::interrupt()
    result
  }
  sink$write_status <- function(status, error_msg) {
    DBI::dbExecute(
      con,
      "UPDATE runs SET status = ?, error_msg = ? WHERE run_id = ?",
      params = list(status, error_msg, run_id)
    )
    invisible(TRUE)
  }
  sink$write_completion <- function(completion) {
    DBI::dbExecute(con, "DELETE FROM run_completion WHERE run_id = ?", params = list(run_id))
    ledgr_store_append(con, "run_completion", completion)
    invisible(TRUE)
  }
  # A failed fold transaction may advance the in-memory counter before the
  # database discards its writes, so the exception row re-reads the store.
  sink$seed_diagnostic_seq <- function() ledgr_next_diagnostic_seq(con, run_id)
  sink$keep_diagnostics <- function(diagnostics) {
    ledgr_store_append(con, "run_diagnostics", diagnostics)
    invisible(TRUE)
  }
  sink$append_events <- function(rows) {
    ledgr_store_append(con, "ledger_events", rows)
    invisible(TRUE)
  }
  sink$write_fill_live <- function(fill_intent, event_seq) {
    # The fold is already inside run_transaction(); live mode writes
    # immediately without opening a nested DuckDB transaction.
    ledgr_write_fill_events(
      con = con,
      run_id = run_id,
      fill_intent = fill_intent,
      event_seq_start = event_seq,
      use_transaction = FALSE
    )
  }
  sink$set_schedule_counts <- function(decision_pulse_count, scheduled_skip_count) {
    state$decision_pulse_count <- as.integer(decision_pulse_count)
    state$scheduled_skip_count <- as.integer(scheduled_skip_count)
    invisible(TRUE)
  }
  sink$write_telemetry <- function(status, strict = TRUE, telemetry = NULL, processed = NA_integer_) {
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
  sink$store_session_telemetry <- function(telemetry) {
    ledgr_store_run_telemetry(run_id, telemetry)
    invisible(TRUE)
  }
  # Strategy-state rows staged between flushes: two typed columns written by
  # index, manifested as one frame at the flush.
  sink$reset_states <- function() {
    state$state_ts <- character(0)
    state$state_json <- character(0)
    state$state_n <- 0L
    invisible(TRUE)
  }
  sink$buffer_state <- function(ts_utc, state_json) {
    i <- state$state_n + 1L
    if (i > length(state$state_ts)) {
      capacity <- max(1000L, length(state$state_ts) * 2L)
      grown_ts <- character(capacity)
      grown_json <- character(capacity)
      if (state$state_n > 0L) {
        keep <- seq_len(state$state_n)
        grown_ts[keep] <- state$state_ts[keep]
        grown_json[keep] <- state$state_json[keep]
      }
      state$state_ts <- grown_ts
      state$state_json <- grown_json
    }
    collapse::setv(state$state_ts, i, as.character(ts_utc), vind1 = TRUE)
    collapse::setv(state$state_json, i, as.character(state_json), vind1 = TRUE)
    state$state_n <- i
    invisible(TRUE)
  }
  sink$pending_state_count <- function() as.integer(state$state_n)
  sink$flush_states <- function() {
    n <- state$state_n
    if (n > 0L) {
      keep <- seq_len(n)
      ledgr_store_append(con, "strategy_state", data.frame(
        run_id = rep(run_id, n),
        ts_utc = state$state_ts[keep],
        state_json = state$state_json[keep],
        stringsAsFactors = FALSE
      ))
      sink$reset_states()
    }
    invisible(TRUE)
  }
  sink$write_state <- function(ts_utc, state_json) {
    DBI::dbExecute(
      con,
      "INSERT INTO strategy_state (run_id, ts_utc, state_json) VALUES (?, ?, ?)",
      params = list(run_id, ts_utc, state_json)
    )
    invisible(TRUE)
  }
  structure(sink, class = "ledgr_output_sink_duckdb")
}

# Memory sink: one sweep candidate. Retains the event buffer with typed
# columns, keeps only the diagnostic rows a candidate row reads, and projects
# accounting and equity facts inline. It never persists telemetry or
# strategy state.
ledgr_output_sink_memory <- function(run_id) {
  sink <- list(run_id = run_id)
  sink$drains <- FALSE
  sink$requires_init <- FALSE
  sink$serialize_meta_json <- FALSE
  sink$typed_columns <- ledgr_output_typed_columns
  sink$nonwrote_buffer_result <- TRUE
  sink$refresh_seq_on_exception <- FALSE

  # Closed and opened fill legs staged during a pulse, closure-local so a
  # write never copies the list (LTB-0188).
  pulse_fill_legs <- vector("list", 256L)
  pulse_fill_leg_n <- 0L
  inline_fills <- ledgr_fill_row_buffer(1024L)

  sink$reset_legs <- function() {
    pulse_fill_leg_n <<- 0L
    invisible(TRUE)
  }
  sink$stage_leg <- function(row, qty, fee, realized_pnl, action) {
    i <- pulse_fill_leg_n + 1L
    if (i > length(pulse_fill_legs)) {
      pulse_fill_legs <<- c(
        pulse_fill_legs,
        vector("list", length(pulse_fill_legs))
      )
    }
    pulse_fill_legs[[i]] <<- list(
      event_seq = row$event_seq,
      ts_utc = row$ts_utc,
      instrument_id = row$instrument_id,
      side = row$side,
      qty = as.numeric(qty),
      price = row$price,
      fee = as.numeric(fee),
      realized_pnl = as.numeric(realized_pnl),
      action = action
    )
    pulse_fill_leg_n <<- i
    invisible(TRUE)
  }
  sink$add_leg <- function(row, qty, fee, realized_pnl, action) {
    ledgr_fill_row_buffer_add(
      inline_fills,
      row$event_seq,
      row$ts_utc,
      row$instrument_id,
      row$side,
      qty,
      row$price,
      fee,
      realized_pnl,
      action
    )
  }
  sink$add_legs_many <- function(batch) {
    ledgr_fill_row_buffer_add_many(
      inline_fills,
      event_seq = batch$fill_event_seq,
      ts_utc = batch$fill_ts_utc,
      instrument_id = batch$fill_instrument_id,
      side = batch$fill_side,
      qty = batch$fill_qty,
      price = batch$fill_price,
      fee = batch$fill_fee,
      realized_pnl = batch$fill_realized_pnl,
      action = batch$fill_action
    )
  }
  sink$flush_legs <- function() {
    n_legs <- pulse_fill_leg_n
    if (n_legs > 0L) {
      legs <- pulse_fill_legs[seq_len(n_legs)]
      start <- inline_fills$n + 1L
      end <- inline_fills$n + n_legs
      ledgr_fill_row_buffer_grow(inline_fills, end)
      index <- start:end
      field <- function(name, type) vapply(legs, `[[`, type, name)
      collapse::setv(inline_fills$event_seq, index, field("event_seq", integer(1)), vind1 = TRUE)
      collapse::setv(
        inline_fills$ts_utc,
        index,
        .POSIXct(field("ts_utc", numeric(1)), tz = "UTC"),
        vind1 = TRUE
      )
      collapse::setv(
        inline_fills$instrument_id,
        index,
        field("instrument_id", character(1)),
        vind1 = TRUE
      )
      collapse::setv(inline_fills$side, index, field("side", character(1)), vind1 = TRUE)
      collapse::setv(inline_fills$qty, index, field("qty", numeric(1)), vind1 = TRUE)
      collapse::setv(inline_fills$price, index, field("price", numeric(1)), vind1 = TRUE)
      collapse::setv(inline_fills$fee, index, field("fee", numeric(1)), vind1 = TRUE)
      collapse::setv(
        inline_fills$realized_pnl,
        index,
        field("realized_pnl", numeric(1)),
        vind1 = TRUE
      )
      collapse::setv(inline_fills$action, index, field("action", character(1)), vind1 = TRUE)
      inline_fills$n <- end
      pulse_fill_leg_n <<- 0L
    }
    invisible(TRUE)
  }

  # Equity facts, one per valued pulse, in five typed columns written by
  # index with doubling growth.
  equity <- new.env(parent = emptyenv())
  equity$n <- 0L
  equity$ts_utc <- numeric(0)
  equity$cash <- numeric(0)
  equity$positions_value <- numeric(0)
  equity$realized_pnl <- numeric(0)
  equity$cost_basis <- numeric(0)
  equity_fields <- c("ts_utc", "cash", "positions_value", "realized_pnl", "cost_basis")
  sink$record_equity_fact <- function(ts_utc, cash, positions_value, realized_pnl, cost_basis) {
    i <- equity$n + 1L
    if (i > length(equity$cash)) {
      capacity <- max(256L, length(equity$cash) * 2L)
      for (name in equity_fields) {
        grown <- numeric(capacity)
        if (equity$n > 0L) grown[seq_len(equity$n)] <- equity[[name]][seq_len(equity$n)]
        equity[[name]] <- grown
      }
    }
    collapse::setv(equity$ts_utc, i, as.numeric(as.POSIXct(ts_utc, tz = "UTC")), vind1 = TRUE)
    collapse::setv(equity$cash, i, as.numeric(cash), vind1 = TRUE)
    collapse::setv(equity$positions_value, i, as.numeric(positions_value), vind1 = TRUE)
    collapse::setv(equity$realized_pnl, i, as.numeric(realized_pnl), vind1 = TRUE)
    collapse::setv(equity$cost_basis, i, as.numeric(cost_basis), vind1 = TRUE)
    equity$n <- i
    invisible(TRUE)
  }
  sink$inline_summary <- function(run_id, metric_kernel) {
    if (equity$n == 0L) {
      equity_curve <- ledgr_empty_equity_curve()
      fills <- ledgr_fill_row_buffer_tibble(inline_fills)
      fills <- ledgr_fills_add_recording_pulse(fills, fills$ts_utc)
      metrics <- ledgr_metrics_from_equity_fills(
        equity = equity_curve,
        fills = fills,
        metric_kernel = metric_kernel
      )
      return(list(equity = equity_curve, fills = fills, metrics = metrics, final_equity = NA_real_))
    }
    keep <- seq_len(equity$n)
    cash <- equity$cash[keep]
    positions_value <- equity$positions_value[keep]
    equity_curve <- data.frame(
      run_id = rep(run_id, equity$n),
      ts_utc = as.POSIXct(equity$ts_utc[keep], origin = "1970-01-01", tz = "UTC"),
      cash = cash,
      positions_value = positions_value,
      equity = cash + positions_value,
      realized_pnl = equity$realized_pnl[keep],
      unrealized_pnl = positions_value - equity$cost_basis[keep],
      stringsAsFactors = FALSE
    )
    fills <- ledgr_fill_row_buffer_tibble(inline_fills)
    fills <- ledgr_fills_add_recording_pulse(fills, fills$ts_utc)
    metrics <- ledgr_metrics_from_equity_fills(
      equity = equity_curve,
      fills = fills,
      metric_kernel = metric_kernel
    )
    list(
      equity = equity_curve,
      fills = fills,
      metrics = metrics,
      final_equity = equity_curve$equity[[nrow(equity_curve)]]
    )
  }

  # A memory candidate keeps only the diagnostic rows its candidate row reads:
  # held decision or scheduled-skip valuation rows on stale or frozen marks
  # (valuation summary), terminal dispositions (assumed outcomes) and stopped
  # rows (stopped instrument IDs). The full decision trace grows with members
  # times pulses and is never held. The handler numbers rows as if every row
  # were kept, so diagnostic_seq is unchanged; kept chunks are bound once
  # when read.
  diagnostic_parts <- vector("list", 64L)
  diagnostic_part_n <- 0L
  sink$keep_diagnostics <- function(diagnostics) {
    valued <- diagnostics$stage %in% "decision" |
      (diagnostics$stage %in% "valuation" & diagnostics$outcome %in% "marked")
    keep <- (valued & !is.na(diagnostics$quantity) & diagnostics$quantity != 0 &
      diagnostics$mark_source %in% c("stale_close", "frozen_close")) |
      (diagnostics$stage %in% "valuation" & diagnostics$reason_code %in% "terminal_disposition") |
      diagnostics$outcome %in% "stopped"
    if (any(keep)) {
      i <- diagnostic_part_n + 1L
      if (i > length(diagnostic_parts)) {
        diagnostic_parts <<- c(diagnostic_parts, vector("list", length(diagnostic_parts)))
      }
      diagnostic_parts[[i]] <<- diagnostics[keep, , drop = FALSE]
      diagnostic_part_n <<- i
    }
    invisible(TRUE)
  }
  # The kept summary rows, in emission order; NULL when nothing was kept.
  sink$diagnostics <- function() {
    if (diagnostic_part_n == 0L) {
      return(NULL)
    }
    do.call(rbind, diagnostic_parts[seq_len(diagnostic_part_n)])
  }
  sink$seed_diagnostic_seq <- function() 1L
  structure(sink, class = "ledgr_output_sink_memory")
}

ledgr_output_handler <- function(sink, .event_initial_capacity = 1024L) {
  run_id <- sink$run_id
  typed <- length(sink$typed_columns) > 0L
  state <- new.env(parent = emptyenv())
  state$event_cols <- NULL
  state$event_count <- 0L
  state$event_capacity <- 0L
  state$event_max_capacity <- .Machine$integer.max
  state$event_initial_capacity <- ledgr_event_buffer_checked_capacity(
    .event_initial_capacity,
    "`.event_initial_capacity`"
  )
  state$status <- "RUNNING"
  state$error_msg <- NA_character_
  state$terminal_status_written <- FALSE
  state$completion <- NULL
  state$next_diagnostic_seq <- NULL
  # Fill rows staged during a pulse, closure-local so a write never copies
  # the list (LTB-0188); flush_pulse_events() writes them by index.
  pulse_fill_rows <- vector("list", 256L)
  pulse_fill_n <- 0L
  handler <- list()

  # -- Event column buffer and capacity growth -------------------------------

  init_event_cols <- function(capacity) {
    capacity <- as.integer(max(0L, capacity))
    state$event_capacity <- capacity
    cols <- new.env(parent = emptyenv())
    cols$event_id <- character(capacity)
    cols$run_id <- character(capacity)
    cols$ts_utc <- as.POSIXct(rep(NA_character_, capacity), tz = "UTC")
    cols$event_type <- character(capacity)
    cols$instrument_id <- character(capacity)
    cols$side <- character(capacity)
    cols$qty <- numeric(capacity)
    cols$price <- numeric(capacity)
    cols$fee <- numeric(capacity)
    cols$meta_json <- character(capacity)
    cols$event_seq <- integer(capacity)
    if (typed) {
      cols$cash_delta <- numeric(capacity)
      cols$position_delta <- numeric(capacity)
      cols$event_realized <- numeric(capacity)
      cols$event_cost_basis <- numeric(capacity)
      cols$meta <- vector("list", capacity)
    }
    state$event_cols <- cols
    invisible(TRUE)
  }

  ensure_event_capacity <- function(required) {
    required <- as.integer(required)
    next_capacity <- ledgr_event_buffer_next_capacity(
      current_capacity = state$event_capacity,
      required = required,
      max_events = state$event_max_capacity,
      initial_capacity = state$event_initial_capacity
    )
    if (!is.null(state$event_cols) && required <= state$event_capacity) {
      return(invisible(TRUE))
    }
    old_cols <- state$event_cols
    old_count <- state$event_count
    init_event_cols(next_capacity)
    if (!is.null(old_cols) && old_count > 0L) {
      idx <- seq_len(old_count)
      for (name in ls(old_cols, all.names = TRUE)) {
        ledgr_event_buffer_setv(state$event_cols, name, idx, old_cols[[name]][idx])
      }
    }
    invisible(TRUE)
  }

  set_event_value <- function(name, i, value) {
    col <- state$event_cols[[name]]
    if (is.list(col)) {
      return(ledgr_event_buffer_setv(state$event_cols, name, i, list(value)))
    }
    value <- if (inherits(col, "POSIXct")) {
      as.POSIXct(value, tz = "UTC")[[1]]
    } else if (is.character(col)) {
      as.character(value)[[1]]
    } else if (is.integer(col)) {
      as.integer(value)[[1]]
    } else {
      as.numeric(value)[[1]]
    }
    ledgr_event_buffer_setv(state$event_cols, name, i, value)
  }

  require_initialized <- function() {
    if (isTRUE(sink$requires_init) && is.null(state$event_cols)) {
      rlang::abort("Ledger event buffer has not been initialized.", class = "ledgr_invalid_state")
    }
    invisible(TRUE)
  }

  is_wrote <- function(write_res) {
    inherits(write_res, "ledgr_ledger_write_result") && identical(write_res$status, "WROTE")
  }

  handler$init_buffers <- function(max_events) {
    if (isTRUE(sink$drains)) {
      # A draining sink starts every fold with an empty buffer.
      state$event_count <- 0L
      state$event_cols <- NULL
      state$event_capacity <- 0L
      if (is.function(sink$reset_states)) sink$reset_states()
    }
    state$event_max_capacity <- ledgr_event_buffer_checked_capacity(
      if (isTRUE(sink$drains)) max_events else state$event_count + as.integer(max_events),
      "`max_events`"
    )
    ensure_event_capacity(state$event_count + 1L)
    pulse_fill_n <<- 0L
    if (is.function(sink$reset_legs)) sink$reset_legs()
    invisible(TRUE)
  }

  handler$buffer_event <- function(write_res) {
    if (!is_wrote(write_res)) {
      return(invisible(isTRUE(sink$nonwrote_buffer_result)))
    }
    require_initialized()
    i <- state$event_count + 1L
    ensure_event_capacity(i)
    row <- write_res$row
    for (name in ledgr_output_event_columns) set_event_value(name, i, row[[name]])
    if (typed) {
      set_event_value("cash_delta", i, write_res$cash_delta)
      set_event_value("position_delta", i, write_res$position_delta)
      set_event_value("event_realized", i, NA_real_)
      set_event_value("event_cost_basis", i, NA_real_)
      set_event_value("meta", i, write_res$meta)
    }
    state$event_count <- i
    invisible(TRUE)
  }

  # -- Pulse fill staging ----------------------------------------------------

  stage_fill_event <- function(write_res) {
    if (!is_wrote(write_res)) {
      return(invisible(FALSE))
    }
    require_initialized()
    i <- pulse_fill_n + 1L
    if (i > length(pulse_fill_rows)) {
      pulse_fill_rows <<- c(
        pulse_fill_rows,
        vector("list", length(pulse_fill_rows))
      )
    }
    entry <- if (typed) {
      list(
        row = write_res$row,
        cash_delta = write_res$cash_delta,
        position_delta = write_res$position_delta,
        meta = write_res$meta,
        event_realized = NA_real_,
        event_cost_basis = NA_real_
      )
    } else {
      write_res$row
    }
    pulse_fill_rows[[i]] <<- entry
    pulse_fill_n <<- i
    invisible(TRUE)
  }

  handler$write_fill_events <- function(fill_intent, event_seq, use_transaction = FALSE) {
    if (isTRUE(use_transaction) && is.function(sink$write_fill_live)) {
      return(sink$write_fill_live(fill_intent, event_seq))
    }
    write_res <- ledgr_fill_event_payload(
      run_id = run_id,
      fill_intent = fill_intent,
      event_seq = event_seq,
      serialize_meta_json = sink$serialize_meta_json
    )
    stage_fill_event(write_res)
    write_res
  }

  handler$flush_pulse_events <- function() {
    n <- pulse_fill_n
    if (n > 0L) {
      staged <- pulse_fill_rows[seq_len(n)]
      start <- state$event_count + 1L
      end <- state$event_count + n
      ensure_event_capacity(end)
      index <- start:end
      if (typed) {
        ledgr_event_buffer_write_rows(state$event_cols, index, lapply(staged, `[[`, "row"))
        ledgr_event_buffer_setv(state$event_cols, "cash_delta", index,
          vapply(staged, `[[`, numeric(1), "cash_delta"))
        ledgr_event_buffer_setv(state$event_cols, "position_delta", index,
          vapply(staged, `[[`, numeric(1), "position_delta"))
        ledgr_event_buffer_setv(state$event_cols, "event_realized", index,
          vapply(staged, `[[`, numeric(1), "event_realized"))
        ledgr_event_buffer_setv(state$event_cols, "event_cost_basis", index,
          vapply(staged, `[[`, numeric(1), "event_cost_basis"))
        ledgr_event_buffer_setv(state$event_cols, "meta", index, lapply(staged, `[[`, "meta"))
      } else {
        ledgr_event_buffer_write_rows(state$event_cols, index, staged)
      }
      state$event_count <- end
      pulse_fill_n <<- 0L
    }
    if (is.function(sink$flush_legs)) sink$flush_legs()
    invisible(TRUE)
  }

  # -- Status and completion bookkeeping -------------------------------------

  handler$record_run_status <- function(status, error_msg = NA_character_) {
    state$status <- status
    state$error_msg <- error_msg
    if (status %in% c("FAILED", "DONE", "INCOMPLETE")) state$terminal_status_written <- TRUE
    if (is.function(sink$write_status)) sink$write_status(status, error_msg)
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

  # -- Diagnostic numbering --------------------------------------------------

  next_diagnostic_seq <- function(refresh = FALSE) {
    if (isTRUE(refresh) || is.null(state$next_diagnostic_seq)) {
      state$next_diagnostic_seq <- sink$seed_diagnostic_seq()
    }
    state$next_diagnostic_seq
  }
  handler$write_run_diagnostics <- function(diagnostics) {
    if (!is.null(diagnostics) && nrow(diagnostics) > 0L) {
      diagnostics$diagnostic_seq <- seq.int(
        from = next_diagnostic_seq(),
        length.out = nrow(diagnostics)
      )
      sink$keep_diagnostics(diagnostics)
      state$next_diagnostic_seq <- state$next_diagnostic_seq + nrow(diagnostics)
    }
    invisible(TRUE)
  }
  handler$write_run_evidence <- function(completion, diagnostics) {
    state$completion <- completion
    if (is.function(sink$write_completion)) sink$write_completion(completion)
    handler$write_run_diagnostics(diagnostics)
    invisible(TRUE)
  }
  handler$write_exception_diagnostic <- function(diagnostic) {
    refresh <- isTRUE(sink$refresh_seq_on_exception)
    diagnostic$diagnostic_seq <- next_diagnostic_seq(refresh = refresh)
    sink$keep_diagnostics(diagnostic)
    if (!refresh) state$next_diagnostic_seq <- state$next_diagnostic_seq + 1L
    invisible(TRUE)
  }

  # -- Storage capabilities ---------------------------------------------------

  if (isTRUE(sink$drains)) {
    handler$run_transaction <- sink$transaction
    handler$terminal_status_written <- function() isTRUE(state$terminal_status_written)
    handler$set_schedule_counts <- sink$set_schedule_counts
    handler$write_telemetry <- sink$write_telemetry
    handler$store_session_telemetry <- sink$store_session_telemetry
    handler$pending_event_count <- function() as.integer(state$event_count)
    handler$pending_state_count <- sink$pending_state_count
    handler$buffer_strategy_state <- sink$buffer_state
    handler$write_strategy_state <- sink$write_state
    handler$append_event_rows <- function(rows) {
      if (!is.null(rows) && nrow(rows) > 0L) sink$append_events(rows)
      invisible(TRUE)
    }
    handler$flush_pending <- function() {
      n <- state$event_count
      if (n > 0L) {
        keep <- seq_len(n)
        cols <- state$event_cols
        sink$append_events(data.frame(
          event_id = cols$event_id[keep],
          run_id = cols$run_id[keep],
          ts_utc = cols$ts_utc[keep],
          event_type = cols$event_type[keep],
          instrument_id = cols$instrument_id[keep],
          side = cols$side[keep],
          qty = cols$qty[keep],
          price = cols$price[keep],
          fee = cols$fee[keep],
          meta_json = cols$meta_json[keep],
          event_seq = cols$event_seq[keep],
          stringsAsFactors = FALSE
        ))
        state$event_count <- 0L
      }
      sink$flush_states()
      invisible(TRUE)
    }
    return(structure(handler, class = "ledgr_output_handler"))
  }

  # A retaining sink keeps every event in the buffer and never persists
  # telemetry or strategy state.
  handler$run_transaction <- function(fn) fn()
  handler$write_telemetry <- function(...) invisible(TRUE)
  handler$store_session_telemetry <- function(...) invisible(TRUE)
  handler$pending_event_count <- function() 0L
  handler$pending_state_count <- function() 0L
  handler$flush_pending <- function() invisible(TRUE)
  handler$buffer_strategy_state <- function(...) invisible(TRUE)
  handler$write_strategy_state <- function(...) invisible(TRUE)
  handler$completion <- function() state$completion
  handler$diagnostics <- sink$diagnostics
  handler$record_equity_fact <- sink$record_equity_fact
  handler$inline_summary <- sink$inline_summary

  handler$append_event_rows <- function(rows) {
    if (!is.null(rows) && nrow(rows) > 0L) {
      n <- nrow(rows)
      start <- state$event_count + 1L
      end <- state$event_count + n
      ensure_event_capacity(end)
      idx <- start:end
      for (name in ledgr_output_event_columns) {
        ledgr_event_buffer_setv(state$event_cols, name, idx, rows[[name]])
      }
      for (j in seq_len(n)) {
        meta <- ledgr_lot_parse_meta(rows$meta_json[[j]])
        pos <- start + j - 1L
        set_event_value("meta", pos, meta)
        set_event_value("cash_delta", pos, meta$cash_delta %||% NA_real_)
        set_event_value("position_delta", pos, meta$position_delta %||% NA_real_)
        set_event_value("event_realized", pos, NA_real_)
        set_event_value("event_cost_basis", pos, NA_real_)
      }
      state$event_count <- end
    }
    invisible(TRUE)
  }

  handler$append_compiled_spot_batch <- function(batch) {
    n <- length(batch$event_seq)
    if (n == 0L) {
      return(invisible(TRUE))
    }
    start <- state$event_count + 1L
    end <- state$event_count + n
    ensure_event_capacity(end)
    idx <- start:end
    cols <- state$event_cols
    ledgr_event_buffer_setv(cols, "event_id", idx, batch$event_id)
    ledgr_event_buffer_setv(cols, "run_id", idx, batch$event_run_id)
    ledgr_event_buffer_setv(cols, "ts_utc", idx, as.POSIXct(
      as.numeric(batch$event_ts_utc),
      origin = "1970-01-01",
      tz = "UTC"
    ))
    ledgr_event_buffer_setv(cols, "event_type", idx, batch$event_type)
    ledgr_event_buffer_setv(cols, "instrument_id", idx, batch$event_instrument_id)
    ledgr_event_buffer_setv(cols, "side", idx, batch$event_side)
    ledgr_event_buffer_setv(cols, "qty", idx, batch$event_qty)
    ledgr_event_buffer_setv(cols, "price", idx, batch$event_price)
    ledgr_event_buffer_setv(cols, "fee", idx, batch$event_fee)
    ledgr_event_buffer_setv(cols, "meta_json", idx, rep(NA_character_, n))
    ledgr_event_buffer_setv(cols, "event_seq", idx, batch$event_seq)
    ledgr_event_buffer_setv(cols, "cash_delta", idx, batch$cash_delta)
    ledgr_event_buffer_setv(cols, "position_delta", idx, batch$position_delta)
    ledgr_event_buffer_setv(cols, "event_realized", idx, batch$event_realized)
    ledgr_event_buffer_setv(cols, "event_cost_basis", idx, batch$event_cost_basis)
    # Keep field order aligned with ledgr_fill_event_payload(); meta_json
    # materialization is byte-compared against the canonical R path.
    ledgr_event_buffer_setv(cols, "meta", idx, Map(
      function(fee, cash_delta, position_delta) {
        list(
          fee = as.numeric(fee),
          cash_delta = as.numeric(cash_delta),
          position_delta = as.numeric(position_delta),
          realized_pnl = NULL
        )
      },
      as.numeric(batch$event_fee),
      as.numeric(batch$cash_delta),
      as.numeric(batch$position_delta)
    ))
    state$event_count <- end
    sink$add_legs_many(batch)
    invisible(TRUE)
  }

  handler$record_accounting_fact <- function(write_res, lot_res, lot_state) {
    if (!is_wrote(write_res) || pulse_fill_n == 0L && state$event_count == 0L) {
      return(invisible(FALSE))
    }
    staged <- pulse_fill_n > 0L
    if (staged) {
      i <- pulse_fill_n
      entry <- pulse_fill_rows[[i]]
      entry$event_realized <- as.numeric(lot_state$realized_pnl)[[1L]]
      entry$event_cost_basis <- as.numeric(lot_state$total_cost_basis)[[1L]]
      pulse_fill_rows[[i]] <<- entry
    } else {
      i <- state$event_count
      set_event_value("event_realized", i, as.numeric(lot_state$realized_pnl))
      set_event_value("event_cost_basis", i, as.numeric(lot_state$total_cost_basis))
    }
    leg_fees <- ledgr_fill_leg_fees(
      write_res$row$fee,
      lot_res$close_qty,
      lot_res$open_qty
    )
    add <- if (staged) sink$stage_leg else sink$add_leg
    if (isTRUE(lot_res$close_qty > 0)) {
      add(write_res$row, lot_res$close_qty, leg_fees[["close"]], lot_res$realized_close, "CLOSE")
    }
    if (isTRUE(lot_res$open_qty > 0)) {
      add(write_res$row, lot_res$open_qty, leg_fees[["open"]], 0, "OPEN")
    }
    invisible(TRUE)
  }

  event_meta_json <- function(i, include_meta_json) {
    value <- state$event_cols$meta_json[[i]]
    # Typed consumers keep fill metadata as parsed lists; rows serialize those
    # lists only when a caller asks for them.
    if (!isTRUE(include_meta_json) || (is.character(value) && length(value) == 1L && !is.na(value) && nzchar(value))) {
      return(value)
    }
    meta <- state$event_cols$meta[[i]]
    if (is.null(meta)) {
      meta <- list(
        fee = as.numeric(state$event_cols$fee[[i]]),
        cash_delta = as.numeric(state$event_cols$cash_delta[[i]]),
        position_delta = as.numeric(state$event_cols$position_delta[[i]]),
        realized_pnl = NULL
      )
    }
    canonical_json(meta)
  }

  materialize_events <- function(include_meta_json = TRUE) {
    if (is.null(state$event_cols) || state$event_count == 0L) {
      return(ledgr_empty_event_table())
    }
    idx <- seq_len(state$event_count)
    cols <- state$event_cols
    meta_json <- vapply(idx, event_meta_json, character(1), include_meta_json = include_meta_json)
    out <- tibble::as_tibble(data.frame(
      event_id = cols$event_id[idx],
      run_id = cols$run_id[idx],
      ts_utc = cols$ts_utc[idx],
      event_type = cols$event_type[idx],
      instrument_id = cols$instrument_id[idx],
      side = cols$side[idx],
      qty = cols$qty[idx],
      price = cols$price[idx],
      fee = cols$fee[idx],
      meta_json = meta_json,
      event_seq = cols$event_seq[idx],
      stringsAsFactors = FALSE
    ))
    attr(out, "ledgr_event_cash_delta") <- cols$cash_delta[idx]
    attr(out, "ledgr_event_position_delta") <- cols$position_delta[idx]
    attr(out, "ledgr_event_meta") <- cols$meta[idx]
    attr(out, "ledgr_event_realized") <- cols$event_realized[idx]
    attr(out, "ledgr_event_cost_basis") <- cols$event_cost_basis[idx]
    class(out) <- unique(c("ledgr_memory_events", class(out)))
    out
  }
  handler$typed_events <- function() materialize_events(include_meta_json = FALSE)
  handler$events <- function() materialize_events(include_meta_json = TRUE)
  structure(handler, class = "ledgr_output_handler")
}
