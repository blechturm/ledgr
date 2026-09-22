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

ledgr_internal_compiled_accounting_model <- function() {
  # Internal benchmark/test harness hook only. Public callers should use the
  # explicit `compiled_accounting_model` argument on supported entry points.
  ledgr_normalize_compiled_accounting_model(
    getOption("ledgr.internal.compiled_accounting_model", NULL)
  )
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

ledgr_compiled_spot_fifo_pack_lots <- function(lot_state, instrument_ids) {
  state_idx <- unname(lot_state$instrument_index[instrument_ids])
  lot_counts <- vapply(state_idx, function(idx) {
    if (is.na(idx)) return(0L)
    max(0L, as.integer(lot_state$lot_tail[[idx]]) -
      as.integer(lot_state$lot_head[[idx]]) + 1L)
  }, integer(1))
  n_lots <- sum(lot_counts)
  lot_inst_idx <- integer(n_lots)
  lot_qty <- numeric(n_lots)
  lot_price <- numeric(n_lots)
  out_idx <- 0L
  for (inst_idx in seq_along(instrument_ids)) {
    state_i <- state_idx[[inst_idx]]
    count <- lot_counts[[inst_idx]]
    if (is.na(state_i) || count == 0L) next
    live <- seq.int(
      as.integer(lot_state$lot_head[[state_i]]),
      as.integer(lot_state$lot_tail[[state_i]])
    )
    target <- seq.int(out_idx + 1L, out_idx + count)
    lot_inst_idx[target] <- as.integer(inst_idx)
    lot_qty[target] <- as.numeric(lot_state$lot_qty[[state_i]][live])
    lot_price[target] <- as.numeric(lot_state$lot_price[[state_i]][live])
    out_idx <- out_idx + count
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
    grouped <- split(
      seq_along(batch$lot_inst_idx),
      factor(batch$lot_inst_idx, levels = seq_along(instrument_ids)),
      drop = FALSE
    )
    for (inst_idx in seq_along(grouped)) {
      rows <- grouped[[inst_idx]]
      if (length(rows) == 0L) next
      state$lot_qty[[inst_idx]] <- as.numeric(batch$lot_qty[rows])
      state$lot_price[[inst_idx]] <- as.numeric(batch$lot_price[rows])
      state$lot_head[[inst_idx]] <- 1L
      state$lot_tail[[inst_idx]] <- length(rows)
      state$net_by_inst[[inst_idx]] <- sum(state$lot_qty[[inst_idx]])
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
