  ledgr:::ledgr_fold_build_availability_pulse_plan(
    context_pos = as.integer(context_pos),
    target_qty = as.numeric(delta),
    position = numeric(length(delta)),
    actionable_k = seq_along(delta),
    member = rep(TRUE, length(delta)),
    execution = list(
      exec_ts = if (has_next) exec_ts else NA_real_,
      has_next = isTRUE(has_next),
      open = next_open
    ),
