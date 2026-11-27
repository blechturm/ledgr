testthat::test_that("[WS4b D12d D13 successor] the fold has one substrate and one planner", {
  fns <- ws4a_sources()
  retired <- c(
    "ledgr_fold_build_pulse_plan",
    "ledgr_dense_eligibility_planes",
    "ledgr_bars_pulse_views",
    "ledgr_projection_pulse_views",
    "ledgr_fast_context_state",
    "ledgr_update_fast_pulse_context_helpers"
  )
  testthat::expect_length(intersect(retired, names(fns)), 0L)
  testthat::expect_true("lean_plan_pulse" %in% names(fns))

  hot <- c(
    "ledgr_execute_fold",
    "lean_fold_envelope_plain",
    "lean_p1_value",
    "lean_p2_decide",
    "lean_p3_plan",
    "lean_p4_apply",
    "lean_p5_commit",
    "lean_e_advance",
    "ledgr_pulse_context"
  )
  mode_hits <- function(x) {
    grep(
      "availability_active|fast_context|dense_eligibility|bars_pulse_views|projection_pulse_views",
      vapply(x, ws4a_txt, ""),
      value = TRUE
    )
  }
  testthat::expect_length(mode_hits(fns[hot]), 0L)
  changed <- fns["lean_p5_commit"]
  changed[[1L]] <- ws4a_inject(
    changed[[1L]],
    "if (services$availability_active) NULL"
  )
  testthat::expect_length(mode_hits(changed), 1L)
})
