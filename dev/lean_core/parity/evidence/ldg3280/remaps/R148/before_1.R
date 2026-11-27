  short <- function(order, epoch_valid = TRUE, open = c(10, 10)) {
    ns$ledgr_fold_build_availability_pulse_plan(
      context_pos = order, target_qty = c(-1, -2), position = c(0, 0), actionable_k = 1:2, member = c(TRUE, TRUE),
      execution = list(exec_ts = if (epoch_valid) 1704292200 else 1704292200.25, has_next = TRUE, open = open),
      execution_view = list(member = c(TRUE, TRUE), restricted = c(FALSE, FALSE), reason_offset = c(0L, 0L),
        reason_count = c(0L, 0L), reason_code = integer()),
      epoch_valid = epoch_valid, cost_resolver = ledgr_test_cost_resolver(), cash = 100, instrument_ids = c("A", "B"))
  }
