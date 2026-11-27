  # Pulse 1's valued row (cash 1000, positions value 20); the equity carrier
  # is built after the fill, as the lean fold hands it to the runner.
  opening_realized <- as.numeric(lot_state$realized_pnl)
  opening_basis <- as.numeric(lot_state$total_cost_basis)
