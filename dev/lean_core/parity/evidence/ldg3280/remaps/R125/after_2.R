  equity <- ledgr:::ledgr_carrier_new(list(
    ts = as.numeric(pulses),
    cash = c(1000, as.numeric(1000 + write_res$cash_delta)),
    positions_value = c(20, -12),
    realized_pnl = c(opening_realized, as.numeric(lot_state$realized_pnl)),
    cost_basis = c(opening_basis, as.numeric(lot_state$total_cost_basis)),
    n = 2L
  ), "equity", NA_integer_)
