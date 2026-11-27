availability_plan <- function(ids, current, target, price, cash, blocked = character()) {
  n <- length(ids)
  restricted <- ids %in% blocked
  view <- ledgr:::ledgr_carrier_segments(n, which(restricted), rep(5L, sum(restricted)))
  lean_plan_pulse(
    context_pos = seq_len(n), target_qty = target, position = current, actionable_k = seq_len(n),
    member = rep(TRUE, n),
    exec_ts = 1577923200, next_open = price,
    execution_view = list(member = rep(TRUE, n), restricted = restricted, reason_offset = view$offset,
