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

ledgr_internal_compiled_accounting_model <- function() {
  # Internal benchmark/test harness hook only. Public callers should not set
  # this option; production APIs keep NULL as the canonical R fold path.
  ledgr_normalize_compiled_accounting_model(
    getOption("ledgr.internal.compiled_accounting_model", NULL)
  )
}

ledgr_require_compiled_spot_fifo_dispatch <- function(execution, output_handler) {
  model <- ledgr_normalize_compiled_accounting_model(execution$compiled_accounting_model)
  if (!identical(model, "spot_fifo")) {
    return(invisible(FALSE))
  }
  if (!identical(execution$event_mode, "buffered")) {
    ledgr_unsupported_accounting_model_error(
      model,
      "`compiled_accounting_model = \"spot_fifo\"` currently supports buffered/ephemeral folds only; durable compiled integration is deferred."
    )
  }
  if (!is.function(output_handler$append_compiled_spot_batch)) {
    rlang::abort(
      "`compiled_accounting_model = \"spot_fifo\"` requires a memory output handler with compiled spot-batch append support.",
      class = c("ledgr_compiled_spot_fifo_unavailable", "ledgr_invalid_fold_execution")
    )
  }
  if (!exists("ledgr_cpp_spot_fifo_batch", envir = asNamespace("ledgr"), mode = "function")) {
    rlang::abort(
      "`compiled_accounting_model = \"spot_fifo\"` was requested, but the compiled spot-FIFO kernel is unavailable.",
      class = c("ledgr_compiled_spot_fifo_unavailable", "ledgr_invalid_fold_execution")
    )
  }
  invisible(TRUE)
}

ledgr_compiled_spot_fifo_pack_lots <- function(lot_state, instrument_ids) {
  lots <- lot_state$lots %||% stats::setNames(vector("list", length(instrument_ids)), instrument_ids)
  lot_inst_idx <- integer()
  lot_qty <- numeric()
  lot_price <- numeric()
  for (inst_idx in seq_along(instrument_ids)) {
    instrument_id <- instrument_ids[[inst_idx]]
    inst_lots <- lots[[instrument_id]]
    if (length(inst_lots) == 0L) {
      next
    }
    for (lot in inst_lots) {
      lot_inst_idx <- c(lot_inst_idx, as.integer(inst_idx))
      lot_qty <- c(lot_qty, as.numeric(lot$qty))
      lot_price <- c(lot_price, as.numeric(lot$price))
    }
  }
  list(
    lot_inst_idx = lot_inst_idx,
    lot_qty = lot_qty,
    lot_price = lot_price
  )
}

ledgr_compiled_spot_fifo_unpack_lots <- function(batch, instrument_ids) {
  state <- ledgr_lot_state(instrument_ids)
  if (length(batch$lot_inst_idx) > 0L) {
    for (i in seq_along(batch$lot_inst_idx)) {
      inst_idx <- as.integer(batch$lot_inst_idx[[i]])
      instrument_id <- instrument_ids[[inst_idx]]
      state$lots[[instrument_id]][[length(state$lots[[instrument_id]]) + 1L]] <- list(
        qty = as.numeric(batch$lot_qty[[i]]),
        price = as.numeric(batch$lot_price[[i]])
      )
    }
  }
  state$cost_basis_by_inst <- stats::setNames(
    as.numeric(batch$cost_basis_by_inst),
    instrument_ids
  )
  state$total_cost_basis <- as.numeric(batch$total_cost_basis[[1]])
  state$realized_pnl <- as.numeric(batch$realized_pnl[[1]])
  state$realized_comp <- as.numeric(batch$realized_comp[[1]])
  state
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
  fill_fee <- vapply(fills, function(fill) as.numeric(fill$commission_fixed), numeric(1))
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

  lot_pack <- ledgr_compiled_spot_fifo_pack_lots(state$lot_state, instrument_ids)
  cost_basis <- state$lot_state$cost_basis_by_inst
  cost_basis_vec <- rep(0, length(instrument_ids))
  names(cost_basis_vec) <- instrument_ids
  if (!is.null(names(cost_basis))) {
    matched <- intersect(names(cost_basis), instrument_ids)
    cost_basis_vec[matched] <- as.numeric(cost_basis[matched])
  } else if (length(cost_basis) == length(instrument_ids)) {
    cost_basis_vec <- as.numeric(cost_basis)
  }

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
    as.numeric(state$cash),
    as.integer(lot_pack$lot_inst_idx),
    as.numeric(lot_pack$lot_qty),
    as.numeric(lot_pack$lot_price),
    as.numeric(cost_basis_vec),
    as.numeric(state$lot_state$total_cost_basis),
    as.numeric(state$lot_state$realized_pnl),
    as.numeric(state$lot_state$realized_comp)
  )
  batch$positions <- as.numeric(batch$positions)
  batch$cash <- as.numeric(batch$cash[[1]])
  batch$lot_state <- ledgr_compiled_spot_fifo_unpack_lots(batch, instrument_ids)
  batch$next_event_seq <- as.integer(batch$next_event_seq[[1]])
  batch
}
