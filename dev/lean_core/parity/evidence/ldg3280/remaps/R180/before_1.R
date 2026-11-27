availability_plan <- function(ids, current, target, price, cash, blocked = character()) {
  n <- length(ids)
  restricted <- ids %in% blocked
  view <- ledgr:::ledgr_carrier_segments(n, which(restricted), rep(5L, sum(restricted)))
  ledgr:::ledgr_fold_build_availability_pulse_plan(
    context_pos = seq_len(n), target_qty = target, position = current, actionable_k = seq_len(n),
    member = rep(TRUE, n),
    execution = list(exec_ts = 1577923200, has_next = TRUE, open = price, high = price, low = price,
      close = price, volume = rep(1, n)),
    execution_view = list(member = rep(TRUE, n), restricted = restricted, reason_offset = view$offset,
