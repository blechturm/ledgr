ws4a_3166_plan <- function(cash = 0) {
  ns <- ws4a_ns()
  view <- ns$ledgr_carrier_segments(4L, 4L, 5L)
  ns$ledgr_fold_build_availability_pulse_plan(
    context_pos = c(4L, 1L, 3L, 2L), target_qty = c(0, 2, 1, 1), position = c(5, 0, 0, 0),
    actionable_k = 1:4, member = rep(TRUE, 4L),
    execution = list(exec_ts = 1704292200, has_next = TRUE, open = c(10, 10, NA, 10)),
    execution_view = list(member = c(TRUE, FALSE, TRUE, TRUE), restricted = c(FALSE, FALSE, FALSE, TRUE),
      reason_offset = view$offset, reason_count = view$count, reason_code = view$code),
    epoch_valid = TRUE,
    cost_resolver = ns$ledgr_cost_resolver_from_model(ledgr_cost_fixed_fee(0.5)),
    cash = cash, instrument_ids = c("A", "B", "C", "D")
  )
}
