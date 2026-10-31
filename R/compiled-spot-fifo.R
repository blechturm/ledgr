ledgr_unsupported_accounting_model_error <- function(value, message = NULL) {
  value_label <- if (is.null(value)) {
    "NULL"
  } else {
    paste0("'", paste(as.character(value), collapse = "', '"), "'")
  }
  if (is.null(message)) {
    message <- paste0(
      "`compiled_accounting_model` must be NULL or one of: 'spot_fifo'. ",
      "Got ", value_label, ". Future accounting models require a separate RFC ",
      "with their own parity gates; the spot-FIFO kernel must not be extended."
    )
  }
  rlang::abort(
    message,
    class = c(
      "ledgr_unsupported_accounting_model",
      "ledgr_invalid_execution_spec",
      "ledgr_invalid_fold_execution"
    )
  )
}

ledgr_normalize_compiled_accounting_model <- function(value) {
  if (is.null(value)) {
    return(NULL)
  }
  if (is.character(value) && length(value) == 1L && !is.na(value) &&
      identical(value, "spot_fifo")) {
    return("spot_fifo")
  }
  ledgr_unsupported_accounting_model_error(value)
}

ledgr_public_compiled_accounting_model <- function(value) {
  ledgr_normalize_compiled_accounting_model(value)
}

ledgr_compiled_spot_fifo_unavailable_error <- function(message = NULL) {
  if (is.null(message)) {
    message <- paste0(
      "Compiled spot-FIFO accelerator is unavailable on this install. ",
      "Default execution (compiled_accounting_model = NULL) uses canonical R ",
      "and works everywhere. To enable compiled execution, install ledgr from ",
      "source with a C++ toolchain available."
    )
  }
  rlang::abort(
    message,
    class = c("ledgr_compiled_spot_fifo_unavailable", "ledgr_invalid_fold_execution")
  )
}

ledgr_require_compiled_spot_fifo_dispatch <- function(execution, output_handler) {
  model <- ledgr_normalize_compiled_accounting_model(execution$compiled_accounting_model)
  if (!identical(model, "spot_fifo")) {
    return(invisible(FALSE))
  }
  if (!identical(execution$event_mode, "buffered")) {
    ledgr_compiled_spot_fifo_unavailable_error(
      paste0(
        "`compiled_accounting_model = \"spot_fifo\"` currently supports ",
        "buffered ephemeral folds only. Durable compiled integration is ",
        "deferred. Default execution (compiled_accounting_model = NULL) uses ",
        "canonical R and works everywhere."
      )
    )
  }
  if (!is.function(output_handler$append_compiled_spot_batch)) {
    ledgr_compiled_spot_fifo_unavailable_error(
      paste0(
        "`compiled_accounting_model = \"spot_fifo\"` requires a memory output ",
        "handler with compiled spot-batch append support. Default execution ",
        "(compiled_accounting_model = NULL) uses canonical R and works ",
        "everywhere."
      )
    )
  }
  if (!exists("ledgr_cpp_spot_fifo_batch", envir = asNamespace("ledgr"), mode = "function")) {
    ledgr_compiled_spot_fifo_unavailable_error()
  }
  invisible(TRUE)
}

ledgr_require_compiled_spot_fifo_event_kinds <- function(event_kinds) {
  event_kinds <- unique(as.character(event_kinds))
  if (anyNA(event_kinds) || any(!nzchar(event_kinds))) {
    rlang::abort(
      "Pulse-plan economic-event kinds must be non-empty strings.",
      class = c("ledgr_invalid_pulse_plan", "ledgr_invalid_fold_execution")
    )
  }
  unsupported <- setdiff(event_kinds, "FILL")
  if (length(unsupported) > 0L) {
    ledgr_compiled_spot_fifo_unavailable_error(paste0(
      "Compiled spot-FIFO cannot execute pulse-plan economic event kind(s): ",
      paste(unsupported, collapse = ", "),
      ". Canonical R is required for every non-FILL economic event."
    ))
  }
  invisible(TRUE)
}

# Compiled boundary adapters (transitional; remover: the compiled-envelope
# RFC). Pack gathers the typed book's live lots in run-axis order, FIFO order
# within an instrument, as the unchanged C++ batch expects. Unpack gathers the
# returned lots back into a typed book whose segments hold exactly the live
# lots, and carries the aggregates and Kahan state as returned.
ledgr_carrier_compiled_pack <- function(book) {
  live <- ledgr_lot_book_live(book)
  list(
    lot_inst_idx = as.integer(live$pos),
    lot_qty = as.numeric(live$qty),
    lot_price = as.numeric(live$price)
  )
}

ledgr_carrier_compiled_unpack <- function(batch, n) {
  inst <- as.integer(batch$lot_inst_idx)
  count <- tabulate(inst, nbins = n)
  # A stable order by instrument keeps each instrument's FIFO order.
  ord <- order(inst, method = "radix")
  book <- ledgr_lot_book(n)
  book$offset <- c(0L, cumsum(count))[seq_len(n)]
  book$capacity <- as.integer(count)
  book$tail <- as.integer(count)
  book$lot_qty <- as.numeric(batch$lot_qty)[ord]
  book$lot_price <- as.numeric(batch$lot_price)[ord]
  book$net_by_inst <- as.numeric(batch$net_by_inst)
  book$cost_basis_by_inst <- as.numeric(batch$cost_basis_by_inst)
  book$total_cost_basis <- as.numeric(batch$total_cost_basis[[1]])
  book$realized_pnl <- as.numeric(batch$realized_pnl[[1]])
  book$realized_comp <- as.numeric(batch$realized_comp[[1]])
  ledgr_lot_book_validate(book, n, reduction = FALSE)
}

ledgr_run_compiled_spot_fifo_batch <- function(run_id,
                                               fills,
                                               state,
                                               instrument_ids,
                                               event_seq_start) {
  n <- length(fills)
  if (n == 0L) {
    return(NULL)
  }

  fill_inst_idx <- vapply(fills, function(fill) as.integer(fill$inst_idx), integer(1))
  fill_instrument_id <- vapply(fills, function(fill) fill$instrument_id, character(1))
  fill_side <- vapply(fills, function(fill) fill$side, character(1))
  fill_qty <- vapply(fills, function(fill) as.numeric(fill$qty), numeric(1))
  fill_price <- vapply(fills, function(fill) as.numeric(fill$fill_price), numeric(1))
  fill_fee <- vapply(fills, function(fill) as.numeric(fill$fee), numeric(1))
  fill_ts_utc <- vapply(
    fills,
    function(fill) {
      as.numeric(ledgr_ts_utc_posix(
        fill$ts_exec_utc,
        label = "`fill$ts_exec_utc`",
        class = "ledgr_invalid_fill_intent"
      ))
    },
    numeric(1)
  )

  if (any(!(fill_side %in% c("BUY", "SELL")))) {
    rlang::abort(
      "`compiled_accounting_model = \"spot_fifo\"` supports BUY and SELL fills only.",
      class = c("ledgr_compiled_spot_fifo_invalid_input", "ledgr_invalid_fold_execution")
    )
  }

  book <- state$lot_state
  lot_pack <- ledgr_carrier_compiled_pack(book)

  batch <- ledgr_cpp_spot_fifo_batch(
    as.character(run_id),
    as.integer(fill_inst_idx),
    as.character(fill_instrument_id),
    as.character(fill_side),
    as.numeric(fill_qty),
    as.numeric(fill_price),
    as.numeric(fill_fee),
    as.numeric(fill_ts_utc),
    as.integer(event_seq_start),
    as.numeric(state$positions),
    as.numeric(book$net_by_inst),
    as.numeric(state$cash),
    as.integer(lot_pack$lot_inst_idx),
    as.numeric(lot_pack$lot_qty),
    as.numeric(lot_pack$lot_price),
    as.numeric(book$cost_basis_by_inst),
    as.numeric(book$total_cost_basis),
    as.numeric(book$realized_pnl),
    as.numeric(book$realized_comp)
  )
  batch$positions <- as.numeric(batch$positions)
  batch$cash <- as.numeric(batch$cash[[1]])
  batch$lot_state <- ledgr_carrier_compiled_unpack(batch, length(instrument_ids))
  batch$next_event_seq <- as.integer(batch$next_event_seq[[1]])
  batch
}
