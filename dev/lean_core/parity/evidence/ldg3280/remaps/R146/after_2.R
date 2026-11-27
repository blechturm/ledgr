  final_resolver <- ledgr_test_cost_resolver()
  final <- lean_plan_pulse(
    context_pos = c(4L, 1L, 3L, 2L), target_qty = c(0, 2, 1, 1), position = c(5, 0, 0, 0), actionable_k = 1:4,
    member = rep(TRUE, 4L), exec_ts = NA_real_, next_open = rep(NA_real_, 4L),
    execution_view = NULL, epoch_valid = TRUE, cost_resolver = final_resolver, cash = 0,
    instrument_ids = c("A", "B", "C", "D"), cost_steps = lean_cost_steps(final_resolver))
