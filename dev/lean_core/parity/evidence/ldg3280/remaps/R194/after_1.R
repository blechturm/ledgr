  lean_plan_pulse(
    context_pos = context_pos,
    target_qty = target_qty,
    position = position,
    actionable_k = actionable_k,
    member = rep(TRUE, length(context_pos)),
    exec_ts = if (isTRUE(has_next)) exec_ts else NA_real_,
    next_open = open,
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
    instrument_ids = paste0("I", seq_len(n_run)),
    cost_steps = lean_cost_steps(cost_resolver)
  )
