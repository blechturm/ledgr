  lean_plan_pulse(
    context_pos = as.integer(context_pos),
    target_qty = as.numeric(delta),
    position = numeric(length(delta)),
    actionable_k = seq_along(delta),
    member = rep(TRUE, length(delta)),
    exec_ts = if (has_next) exec_ts else NA_real_,
    next_open = next_open,
