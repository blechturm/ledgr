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

# Whether a native batch result may hide a lot-accounting overflow (cut 5
# amendment_overflow): the native call refused, a returned realized total,
# net or compensation is non-finite, or the batch's reachable cost basis is
# not bounded below half the double range. The bound is |total basis| plus
# twice the touched instruments' bases, every live lot's basis and the
# fills' notionals. The native kernel's dust rule scales with the value and
# snaps an infinite basis to zero, so its outputs alone cannot show an
# opened-basis overflow. A suspicion only asks the canonical oracle; it never
# changes a result.
ledgr_compiled_spot_fifo_suspect <- function(batch, fills, book, lot_pack) {
  if (inherits(batch, "error")) return(TRUE)
  pos <- fills$pos
  bound <- abs(book$total_cost_basis) + 2 * sum(abs(book$cost_basis_by_inst[pos])) +
    sum(abs(lot_pack$lot_qty * lot_pack$lot_price)) + sum(fills$qty * fills$price)
  !is.finite(2 * bound) || !all(is.finite(batch$event_realized)) ||
    !all(is.finite(batch$event_cost_basis)) || !all(is.finite(batch$net_by_inst[pos])) ||
    !is.finite(batch$realized_comp[[1L]])
}

# The compiled wrapper's input is P3's typed fill group: run-axis positions,
# side codes, quantities, prices, fees and execution epochs, read as columns.
ledgr_run_compiled_spot_fifo_batch <- function(run_id,
                                               fills,
                                               state,
                                               instrument_ids,
                                               event_seq_start) {
  n <- length(fills$k)
  if (n == 0L) {
    return(NULL)
  }

  if (any(!(fills$side %in% c(1L, -1L)))) {
    rlang::abort(
      "`compiled_accounting_model = \"spot_fifo\"` supports BUY and SELL fills only.",
      class = c("ledgr_compiled_spot_fifo_invalid_input", "ledgr_invalid_fold_execution")
    )
  }
  fill_inst_idx <- fills$pos
  fill_instrument_id <- instrument_ids[fill_inst_idx]
  fill_side <- c("SELL", "BUY")[(fills$side > 0L) + 1L]
  fill_qty <- fills$qty
  fill_price <- fills$price
  fill_fee <- fills$fee
  fill_ts_utc <- fills$exec_ts

  book <- state$lot_state
  lot_pack <- ledgr_carrier_compiled_pack(book)

  # The unchanged native batch over the first `m` fills; it holds no state.
  native <- function(m) {
    j <- seq_len(m)
    tryCatch(ledgr_cpp_spot_fifo_batch(
      as.character(run_id),
      as.integer(fill_inst_idx[j]),
      as.character(fill_instrument_id[j]),
      as.character(fill_side[j]),
      as.numeric(fill_qty[j]),
      as.numeric(fill_price[j]),
      as.numeric(fill_fee[j]),
      as.numeric(fill_ts_utc[j]),
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
    ), error = identity)
  }
  batch <- native(n)
  if (ledgr_compiled_spot_fifo_suspect(batch, fills, book, lot_pack)) {
    # On suspicion, retain the canonical operation's earliest refusal and its
    # condition. A native input refusal wins when its row is earlier or the
    # same. If canonical evaluation succeeds, retain the native outcome.
    # Nothing is installed or published for a refused batch.
    oracle <- ledgr_fold_fill_candidate(book, fills)
    failure <- if (!is.null(oracle$failed)) {
      oracle$failed
    } else {
      n + 1L
    }
    if (inherits(batch, "error")) {
      error <- batch
      ok <- 0L
      failed <- n
      while (failed - ok > 1L) {
        mid <- (ok + failed) %/% 2L
        out <- native(mid)
        if (inherits(out, "error")) {
          failed <- mid
          error <- out
        } else {
          ok <- mid
        }
      }
      if (failed <= failure) stop(error)
    }
    if (failure <= n) stop(oracle$error)
  }
  batch$positions <- as.numeric(batch$positions)
  # The output boundary publishes P3's carried effects and installs the cash
  # they imply, in fill order; native lot positions stay authoritative and
  # the native calculation is unchanged.
  batch$cash_delta <- fills$cash_delta
  batch$position_delta <- fills$position_delta
  batch$cash <- ledgr_cash_scan(state$cash, fills$cash_delta)[[n]]
  batch$lot_state <- ledgr_carrier_compiled_unpack(batch, length(instrument_ids))
  batch$next_event_seq <- as.integer(batch$next_event_seq[[1]])
  batch
}
