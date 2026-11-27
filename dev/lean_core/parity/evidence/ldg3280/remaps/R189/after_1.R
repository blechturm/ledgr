ws4a_3166_plan <- function(cash = 0) {
  ns <- ws4a_ns()
  view <- ns$ledgr_carrier_segments(4L, 4L, 5L)
  cost_resolver <- ns$ledgr_cost_resolver_from_model(ledgr_cost_fixed_fee(0.5))
  lean_plan_pulse(
    context_pos = c(4L, 1L, 3L, 2L), target_qty = c(0, 2, 1, 1), position = c(5, 0, 0, 0),
    actionable_k = 1:4, member = rep(TRUE, 4L),
    exec_ts = 1704292200, next_open = c(10, 10, NA, 10),
    execution_view = list(member = c(TRUE, FALSE, TRUE, TRUE), restricted = c(FALSE, FALSE, FALSE, TRUE),
      reason_offset = view$offset, reason_count = view$count, reason_code = view$code),
    epoch_valid = TRUE,
    cost_resolver = cost_resolver,
    cash = cash, instrument_ids = c("A", "B", "C", "D"), cost_steps = lean_cost_steps(cost_resolver)
  )
}
