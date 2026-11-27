  equity <- ledgr:::ledgr_fold_equity_record(2L)
  equity <- ledgr:::ledgr_fold_equity_append(
    equity,
    ts = pulses[[1L]],
    cash = 1000,
    positions_value = 20,
    realized_pnl = lot_state$realized_pnl,
    cost_basis = lot_state$total_cost_basis
  )
