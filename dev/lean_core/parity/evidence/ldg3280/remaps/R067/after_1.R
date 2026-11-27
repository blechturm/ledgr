  # The valued rows as the lean fold hands them to the runner: one equity
  # carrier of fresh columns (the fold's return in dev/lean_core/loop.R).
  equity <- ledgr:::ledgr_carrier_new(list(
    ts = as.numeric(ts), cash = as.numeric(cash), positions_value = as.numeric(value),
    realized_pnl = as.numeric(realized), cost_basis = as.numeric(basis), n = n
  ), "equity", NA_integer_)
  kernel <- ledgr:::ledgr_metric_kernel(context = ledgr_metric_context(), pulses = ts)
  summary <- memory$inline_summary(
    run_id = "growth-memory",
    metric_kernel = kernel,
    equity = equity
  )
