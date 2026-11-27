  avail <- function(position, target, open = c(10, 10), sub = FALSE, cost = ledgr_test_cost_resolver()) {
    ts <- t1 + if (sub) 0.25 else 0
    ns$ledgr_fold_build_availability_pulse_plan(1:2, target, position, 1:2, c(TRUE, TRUE),
      list(exec_ts = ts, has_next = TRUE, open = open),
      list(member = c(TRUE, TRUE), restricted = c(FALSE, FALSE), reason_offset = c(0L, 0L), reason_count = c(0L, 0L),
        reason_code = integer()), ns$ledgr_plan_epoch_valid(ts), cost, 1000, c("A", "B"))
  }
