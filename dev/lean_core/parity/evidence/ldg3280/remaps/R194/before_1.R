  ns$ledgr_fold_build_availability_pulse_plan(
    context_pos = context_pos,
    target_qty = target_qty,
    position = position,
    actionable_k = actionable_k,
    member = rep(TRUE, length(context_pos)),
    execution = list(
      exec_ts = if (isTRUE(has_next)) exec_ts else NA_real_,
      has_next = isTRUE(has_next),
      open = open
    ),
    execution_view = list(
      member = rep(TRUE, n),
      restricted = rep(FALSE, n),
      reason_offset = rep(0L, n),
      reason_count = rep(0L, n),
      reason_code = integer()
    ),
    epoch_valid = epoch_valid,
    cost_resolver = cost_resolver,
    cash = 1e300,
    instrument_ids = paste0("I", seq_len(n_run))
  )
