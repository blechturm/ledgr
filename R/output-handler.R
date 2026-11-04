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

ledgr_output_event_columns <- ledgr_accounting_event_columns()

ledgr_memory_diagnostic_keep <- function(diagnostics, n = NULL) {
  if (is.null(n)) {
    n <- if (is.data.frame(diagnostics)) nrow(diagnostics) else length(diagnostics$stage)
  }
  if (n == 0L) return(logical())
  take <- function(name, default) {
    value <- diagnostics[[name]]
    if (is.null(value)) value <- default
    rep_len(value, n)
  }
  stage <- as.character(take("stage", NA_character_))
  outcome <- as.character(take("outcome", NA_character_))
  quantity <- as.numeric(take("quantity", NA_real_))
  mark_source <- as.character(take("mark_source", ""))
  reason_code <- as.character(take("reason_code", ""))
  valued <- stage %in% "decision" |
    (stage %in% "valuation" & outcome %in% "marked")
  (valued & !is.na(quantity) & quantity != 0 &
    mark_source %in% c("stale_close", "frozen_close")) |
    (stage %in% "valuation" & reason_code %in% "terminal_disposition") |
    reason_code %in% "final_pulse_no_execution" |
    outcome %in% "stopped"
}

# The legs of a published fill block (Synthesis Section 4, leg group): per
# fill, a CLOSE leg for its closed quantity and then an OPEN leg for its
# opened quantity, in event order, with the canonical leg-fee split; an
# opening leg realizes nothing. `applied` holds the block's applied lot rows
# in block order. Columns are gathered by row index once per block.
ledgr_fill_leg_block <- function(block, applied) {
  closing <- applied$close_qty > 0
  opening <- applied$open_qty > 0
  fees <- ledgr_fill_leg_fees(block$fee, applied$close_qty, applied$open_qty)
  # Row r's CLOSE leg sorts before its OPEN leg.
  row <- c(which(closing), which(opening))
  open <- rep(c(FALSE, TRUE), c(sum(closing), sum(opening)))
  ord <- order(2L * row + open, method = "radix")
  row <- row[ord]
  open <- open[ord]
  qty <- applied$close_qty[row]
  qty[open] <- applied$open_qty[row[open]]
  fee <- fees$close[row]
  fee[open] <- fees$open[row[open]]
  realized_pnl <- applied$realized_close[row]
  realized_pnl[open] <- 0
  ledgr_carrier_new(list(
    event_seq = block$event_seq[row],
    instrument_id = block$instrument_id[row],
    side = block$side[row],
    action = c("CLOSE", "OPEN")[open + 1L],
    ts_utc = block$ts_utc[row],
    qty = qty,
    price = block$price[row],
    fee = fee,
    realized_pnl = realized_pnl
  ), "leg", NA_integer_)
}

# DuckDB sink: the run store of one run. Durable appends, transactions with
# interrupt re-raise, db_live immediate writes, diagnostic sequence seeding
# from the store and telemetry persistence.
ledgr_output_sink_duckdb <- function(con, run_id, run_wall_start, execution_mode) {
  state <- new.env(parent = emptyenv())
  state$decision_pulse_count <- NA_integer_
  state$scheduled_skip_count <- NA_integer_

  sink <- list(run_id = run_id)
  sink$drains <- TRUE
  sink$requires_init <- TRUE
  sink$nonwrote_buffer_result <- FALSE
  sink$refresh_seq_on_exception <- TRUE
  # Physical rows retain their logical sequence positions; the codec may
  # leave certified holes which the decoder fills from implicit evidence.
  sink$diagnostic_keep <- function(diagnostics, n = NULL) {
    if (is.null(n)) n <- if (is.data.frame(diagnostics)) nrow(diagnostics) else length(diagnostics$stage)
    rep(TRUE, n)
  }

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
  sink$keep_diagnostic_implicit <- function(rows) {
    ledgr_store_append(con, "run_diagnostic_implicit", rows)
    invisible(TRUE)
  }
  sink$write_diagnostic_coverage <- function(logical_count) {
    DBI::dbExecute(
      con,
      paste(
        "INSERT INTO run_diagnostic_coverage",
        "(run_id, logical_count, codec_rule_version) VALUES (?, ?, ?)",
        "ON CONFLICT(run_id) DO UPDATE SET",
        "logical_count = excluded.logical_count,",
        "codec_rule_version = excluded.codec_rule_version"
      ),
      params = list(run_id, as.integer(logical_count), ledgr_diagnostic_codec_rule_version)
    )
    invisible(TRUE)
  }
  sink$write_diagnostic_summary <- function() {
    row <- ledgr_diagnostic_summary_from_store(con, run_id)
    row$summary_hash <- ledgr_diagnostic_summary_hash(row)
    DBI::dbExecute(con, "DELETE FROM run_diagnostic_summary WHERE run_id = ?", params = list(run_id))
    ledgr_store_append(con, "run_diagnostic_summary", row)
    invisible(TRUE)
  }
  sink$append_events <- function(rows) {
    ledgr_store_append(con, "ledger_events", rows)
    invisible(TRUE)
  }
  # db_live publishes the rows `i` of a fill block at once: one INSERT per
  # fill, in event order, through the db_live writer with its own validation
  # and sequence (one statement per fill is the immediate-write contract).
  # The fold is already inside
  # run_transaction(), so no nested DuckDB transaction is opened. Returns the
  # writer's result for the last row, or its no-op for an empty block.
  sink$write_fill_live <- function(publication) {
    if (!identical(publication$status, "WROTE")) {
      return(structure(
        list(status = "NO_OP", next_event_seq = publication$next_event_seq),
        class = "ledgr_ledger_write_result"
      ))
    }
    for (k in seq_along(publication$event_seq)) {
      res <- ledgr_write_fill_publication_row(
        con = con,
        publication = publication,
        row = k,
        use_transaction = FALSE
      )
    }
    res
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
  sink$nonwrote_buffer_result <- TRUE
  sink$refresh_seq_on_exception <- FALSE

  # The fill legs of the pulse's published blocks: leg columns (the leg
  # group of ledgr_fill_leg_block()), held closure-local until flush_legs()
  # writes them by index into the result buffer; NULL when none is pending.
  pending_legs <- NULL
  inline_fills <- ledgr_fill_row_buffer(1024L)

  sink$reset_legs <- function() {
    pending_legs <<- NULL
    invisible(TRUE)
  }
  sink$stage_legs <- function(legs) {
    if (is.null(pending_legs)) {
      pending_legs <<- legs
    } else {
      # A second block before the flush: its columns appended once.
      for (name in names(legs)) pending_legs[[name]] <<- c(pending_legs[[name]], legs[[name]])
    }
    invisible(TRUE)
  }
  add_legs <- function(legs) {
    ledgr_fill_row_buffer_add_many(
      inline_fills,
      event_seq = legs$event_seq,
      ts_utc = legs$ts_utc,
      instrument_id = legs$instrument_id,
      side = legs$side,
      qty = legs$qty,
      price = legs$price,
      fee = legs$fee,
      realized_pnl = legs$realized_pnl,
      action = legs$action
    )
  }
  sink$add_legs <- add_legs
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
    if (!is.null(pending_legs)) {
      add_legs(pending_legs)
      pending_legs <<- NULL
    }
    invisible(TRUE)
  }

  # The candidate's summary: `equity` is the frozen equity record the fold
  # envelope hands out (one row per valued pulse, Synthesis 3.6); the sink
  # holds no equity of its own and replays none.
  sink$inline_summary <- function(run_id, metric_kernel, equity) {
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
      ts_utc = as.POSIXct(equity$ts[keep], origin = "1970-01-01", tz = "UTC"),
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
  sink$diagnostic_keep <- ledgr_memory_diagnostic_keep
  sink$keep_diagnostics <- function(diagnostics) {
    keep <- sink$diagnostic_keep(diagnostics)
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
  state <- new.env(parent = emptyenv())
  state$event_cols <- NULL
  state$event_count <- 0L
  state$last_event_seq <- NULL
  state$last_event_ts_utc <- NULL
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
  # The pulse's published fill block (publication columns), held
  # closure-local until flush_pulse_events() writes it by index into the
  # event buffer; NULL when none is pending.
  pending_fills <- NULL
  handler <- list()
  handler$diagnostic_keep <- sink$diagnostic_keep

  # Install the durable append boundary after opening rows are written. The
  # first fill block must still be checked against their final sequence and
  # timestamp.
  handler$seed_event_boundary <- function(event_seq, ts_utc) {
    event_seq_value <- as.numeric(event_seq)
    if (length(event_seq_value) != 1L || is.na(event_seq_value) ||
        !is.finite(event_seq_value) || event_seq_value < 1 ||
        event_seq_value > .Machine$integer.max || event_seq_value %% 1 != 0) {
      rlang::abort("`event_seq` must be an integer >= 1.", class = "ledgr_invalid_args")
    }
    ts <- ledgr_assert_whole_second_utc(
      ledgr_utc(ts_utc),
      label = "`ts_utc`",
      class = "ledgr_invalid_args"
    )
    if (length(ts) != 1L || is.na(ts)) {
      rlang::abort("`ts_utc` must be one finite UTC timestamp.", class = "ledgr_invalid_args")
    }
    state$last_event_seq <- as.integer(event_seq_value)
    state$last_event_ts_utc <- ts
    invisible(TRUE)
  }

  # -- Event column buffer and capacity growth -------------------------------

  init_event_cols <- function(capacity) {
    capacity <- as.integer(max(0L, capacity))
    state$event_capacity <- capacity
    cols <- new.env(parent = emptyenv())
    template <- ledgr_accounting_empty_columns(capacity)
    for (name in names(template)) cols[[name]] <- template[[name]]
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

  validate_append <- function(rows,
                              commit_boundary = TRUE) {
    prepared <- ledgr_validate_accounting_append(
      rows,
      prior_event_seq = state$last_event_seq,
      prior_ts_utc = state$last_event_ts_utc
    )
    if (isTRUE(commit_boundary) && length(prepared$event_seq) > 0L) {
      state$last_event_seq <- utils::tail(prepared$event_seq, 1L)
      state$last_event_ts_utc <- utils::tail(prepared$ts_utc, 1L)
    }
    prepared
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
    pending_fills <<- NULL
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
    state$event_count <- i
    invisible(TRUE)
  }

  # -- Pulse fill publication ------------------------------------------------

  # Holds a published block until the pulse flush. A second block before the
  # flush (handler-level writes) has its columns appended once.
  stage_fill_block <- function(block) {
    if (!identical(block$status, "WROTE")) {
      return(invisible(FALSE))
    }
    require_initialized()
    if (is.null(pending_fills)) {
      pending_fills <<- block
    } else {
      for (name in setdiff(names(block), c("status", "next_event_seq"))) {
        pending_fills[[name]] <<- c(pending_fills[[name]], block[[name]])
      }
      pending_fills$next_event_seq <<- block$next_event_seq
    }
    invisible(TRUE)
  }

  # Fill input: rows `i` of P3's typed fill group with one instrument ID per
  # row, published as one block with contiguous sequences from `event_seq`;
  # the computed effects are reused by every sink. Returns the published
  # block (db_live: the writer's result). With `stage = FALSE` the block is
  # built and checked as this sink would publish it, but neither staged nor
  # written (the fold's refusal order, ledgr_fold_stage_apply()).
  handler$write_fill_events <- function(fill, i, instrument_id, event_seq, use_transaction = FALSE, stage = TRUE) {
    block <- ledgr_fill_event_payload(
      run_id = run_id,
      fill = fill,
      i = i,
      instrument_id = instrument_id,
      event_seq = event_seq
    )
    if (isTRUE(stage) && isTRUE(use_transaction) && is.function(sink$write_fill_live)) {
      if (identical(block$status, "WROTE")) {
        validate_append(block[ledgr_output_event_columns], commit_boundary = FALSE)
      }
      result <- sink$write_fill_live(block)
      if (identical(block$status, "WROTE")) {
        state$last_event_seq <- utils::tail(block$event_seq, 1L)
        state$last_event_ts_utc <- .POSIXct(
          utils::tail(block$ts_utc, 1L),
          tz = "UTC"
        )
      }
      return(result)
    }
    if (identical(block$status, "WROTE")) {
      validate_append(
        block[ledgr_output_event_columns],
        commit_boundary = isTRUE(stage)
      )
    }
    if (isTRUE(stage)) stage_fill_block(block)
    block
  }

  # Writes the pending block by index into the event buffer, column by
  # column; the execution epochs become POSIXct here.
  handler$flush_pulse_events <- function() {
    block <- pending_fills
    if (!is.null(block)) {
      n <- length(block$event_seq)
      start <- state$event_count + 1L
      end <- state$event_count + n
      ensure_event_capacity(end)
      index <- start:end
      cols <- state$event_cols
      for (name in setdiff(ledgr_output_event_columns, "ts_utc")) {
        ledgr_event_buffer_setv(cols, name, index, block[[name]])
      }
      ledgr_event_buffer_setv(cols, "ts_utc", index, .POSIXct(block$ts_utc, tz = "UTC"))
      state$event_count <- end
      pending_fills <<- NULL
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
      sink$keep_diagnostics(diagnostics)
      state$next_diagnostic_seq <- max(diagnostics$diagnostic_seq) + 1L
    }
    invisible(TRUE)
  }
  if (is.function(sink$keep_diagnostic_implicit)) {
    handler$write_run_diagnostic_implicit <- function(rows) {
      if (!is.null(rows) && nrow(rows) > 0L) sink$keep_diagnostic_implicit(rows)
      invisible(TRUE)
    }
  }
  if (is.function(sink$write_diagnostic_coverage)) {
    handler$write_diagnostic_coverage <- sink$write_diagnostic_coverage
  }
  if (is.function(sink$write_diagnostic_summary)) {
    handler$write_diagnostic_summary <- sink$write_diagnostic_summary
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
    if (is.function(sink$write_diagnostic_coverage)) {
      sink$write_diagnostic_coverage(diagnostic$diagnostic_seq[[1L]])
    }
    if (is.function(sink$write_diagnostic_summary)) {
      sink$write_diagnostic_summary()
    }
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
    handler$append_event_rows <- function(rows) {
      if (!is.null(rows) && nrow(rows) > 0L) {
        validate_append(rows)
        sink$append_events(rows)
      }
      invisible(TRUE)
    }
    handler$flush_pending <- function() {
      n <- state$event_count
      if (n > 0L) {
        keep <- seq_len(n)
        cols <- state$event_cols
        values <- lapply(ledgr_output_event_columns, function(name) cols[[name]][keep])
        names(values) <- ledgr_output_event_columns
        sink$append_events(as.data.frame(values, stringsAsFactors = FALSE))
        state$event_count <- 0L
      }
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
  handler$flush_pending <- function() invisible(TRUE)
  handler$completion <- function() state$completion
  handler$diagnostics <- sink$diagnostics
  handler$inline_summary <- sink$inline_summary

  handler$append_event_rows <- function(rows) {
    if (!is.null(rows) && nrow(rows) > 0L) {
      validate_append(rows)
      n <- nrow(rows)
      start <- state$event_count + 1L
      end <- state$event_count + n
      ensure_event_capacity(end)
      idx <- start:end
      for (name in ledgr_output_event_columns) {
        ledgr_event_buffer_setv(state$event_cols, name, idx, rows[[name]])
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
    rows <- ledgr_accounting_rows(
      event_id = batch$event_id,
      run_id = batch$event_run_id,
      ts_utc = .POSIXct(batch$event_ts_utc, tz = "UTC"),
      event_type = batch$event_type,
      instrument_id = batch$event_instrument_id,
      side = batch$event_side,
      qty = batch$event_qty,
      price = batch$event_price,
      fee = batch$event_fee,
      event_seq = batch$event_seq,
      cash_delta = batch$cash_delta,
      position_delta = batch$position_delta
    )
    validate_append(rows)
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
    ledgr_event_buffer_setv(cols, "event_seq", idx, batch$event_seq)
    ledgr_event_buffer_setv(cols, "cash_delta", idx, batch$cash_delta)
    ledgr_event_buffer_setv(cols, "position_delta", idx, batch$position_delta)
    state$event_count <- end
    sink$add_legs_many(batch)
    invisible(TRUE)
  }

  # The accounting facts of the most recently published `block`: durable
  # effects already live in the typed block. Only the fill-leg projection is
  # retained for the memory candidate's inline summary.
  handler$record_accounting_fact <- function(block, applied) {
    staged <- !is.null(pending_fills)
    if (!identical(block$status, "WROTE") || (!staged && state$event_count == 0L)) {
      return(invisible(FALSE))
    }
    legs <- ledgr_fill_leg_block(block, applied)
    if (staged) sink$stage_legs(legs) else sink$add_legs(legs)
    invisible(TRUE)
  }

  materialize_events <- function() {
    if (is.null(state$event_cols) || state$event_count == 0L) {
      return(ledgr_empty_event_table())
    }
    idx <- seq_len(state$event_count)
    cols <- state$event_cols
    values <- lapply(ledgr_output_event_columns, function(name) cols[[name]][idx])
    names(values) <- ledgr_output_event_columns
    out <- tibble::as_tibble(as.data.frame(values, stringsAsFactors = FALSE))
    class(out) <- unique(c("ledgr_memory_events", class(out)))
    out
  }
  handler$typed_events <- materialize_events
  handler$events <- materialize_events
  structure(handler, class = "ledgr_output_handler")
}
