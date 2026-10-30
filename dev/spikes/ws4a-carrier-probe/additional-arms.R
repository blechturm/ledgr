# Additional probe arms. Canonical R delegates every FIFO transition to the
# package oracle. Its sequential loop preserves event-order cash and Kahan P&L;
# the cost of those per-fill canonical calls is deliberately included.
carrier_lots_canonical <- function(input, ix, quantity, price, fee, direction, cash) {
  state <- input
  n <- length(ix)
  closed <- opened <- close_pnl <- event_realized <- event_basis <- numeric(n)
  ids <- input$instrument_ids[ix]
  for (k in seq_len(n)) {
    result <- ledgr_lot_apply_fill(state, instrument_id = ids[[k]],
      side = if (direction[[k]] > 0L) 'BUY' else 'SELL', qty = quantity[[k]],
      price = price[[k]], fee = fee[[k]])
    state <- result$state
    closed[[k]] <- result$close_qty; opened[[k]] <- result$open_qty
    close_pnl[[k]] <- result$realized_close
    event_realized[[k]] <- state$realized_pnl
    event_basis[[k]] <- state$total_cost_basis
    delta <- if (direction[[k]] > 0L) -(quantity[[k]] * price[[k]] + fee[[k]]) else
      quantity[[k]] * price[[k]] - fee[[k]]
    cash <- cash + delta
  }
  list(state = state, cash = cash, close_qty = closed, open_qty = opened,
    realized_close = close_pnl, event_realized = event_realized, event_basis = event_basis)
}
# Avoid loading carrier.cpp at all in the canonical-R arm, including affordability.
carrier_afford_canonical <- function(delta, order, blocked, cash, tolerance) {
  accepted <- logical(length(delta))
  for (k in order) {
    next_cash <- cash + delta[[k]]
    if (!blocked[[k]] && (delta[[k]] >= 0 || next_cash >= -tolerance)) {
      accepted[[k]] <- TRUE; cash <- next_cash
    }
  }
  list(accepted = accepted, cash = cash)
}
carrier_retained_indexed <- function(sink, batch) {
  # Reuse the existing typed fill buffer; capacity doubles only at a growth
  # boundary. Each pulse writes a block by index, without whole-column [<-.
  buffer <- environment(sink$add_legs_many)$inline_fills
  n <- length(batch$fill_event_seq)
  if (!n) return(invisible(NULL))
  end <- buffer$n + n
  if (end > buffer$capacity) ledgr_fill_row_buffer_grow(buffer, end)
  index <- buffer$n + seq_len(n)
  values <- list(event_seq = batch$fill_event_seq, ts_utc = .POSIXct(batch$fill_ts_utc, tz = 'UTC'),
    instrument_id = batch$fill_instrument_id, side = batch$fill_side, qty = batch$fill_qty,
    price = batch$fill_price, fee = batch$fill_fee, realized_pnl = batch$fill_realized_pnl,
    action = batch$fill_action)
  # Fixed schema traversal; no loop over fills.
  for (name in names(values)) ledgr_event_buffer_setv(buffer, name, index, values[[name]])
  buffer$n <- end
  invisible(NULL)
}
