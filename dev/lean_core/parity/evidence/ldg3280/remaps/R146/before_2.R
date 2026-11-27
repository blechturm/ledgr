  final <- ws4a_ns()$ledgr_fold_build_availability_pulse_plan(
    context_pos = c(4L, 1L, 3L, 2L), target_qty = c(0, 2, 1, 1), position = c(5, 0, 0, 0), actionable_k = 1:4,
    member = rep(TRUE, 4L), execution = list(exec_ts = NA_real_, has_next = FALSE, open = rep(NA_real_, 4L)),
    execution_view = NULL, epoch_valid = TRUE, cost_resolver = ledgr_test_cost_resolver(), cash = 0,
    instrument_ids = c("A", "B", "C", "D"))
