  record <- ledgr:::ledgr_fold_equity_record(n + 12L)
  for (i in seq_len(n)) {
    record <- ledgr:::ledgr_fold_equity_append(record, ts[[i]], cash[[i]], value[[i]], realized[[i]], basis[[i]])
  }
  kernel <- ledgr:::ledgr_metric_kernel(context = ledgr_metric_context(), pulses = ts)
  summary <- memory$inline_summary(
    run_id = "growth-memory",
    metric_kernel = kernel,
    equity = ledgr:::ledgr_fold_equity_prefix(record)
  )
