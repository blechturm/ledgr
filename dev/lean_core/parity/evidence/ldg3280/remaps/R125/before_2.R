  equity <- ledgr:::ledgr_fold_equity_append(
    equity,
    ts = pulses[[2L]],
    cash = 1000 + write_res$cash_delta,
    positions_value = -12,
    realized_pnl = lot_state$realized_pnl,
    cost_basis = lot_state$total_cost_basis
  )
