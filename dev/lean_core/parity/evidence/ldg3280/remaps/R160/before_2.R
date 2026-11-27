ws4a_d6_routed <- c(
  ledgr_fold_stage_observe_settle = "ledgr_availability_detail_json(affected$details[[k]])",
  ledgr_fold_stage_decide = "canonical_json(list(intent_reason))",
  ledgr_fold_stage_decide = "canonical_json(list(risk_step))",
  ledgr_fold_stage_plan = "canonical_json(list(cash_before,virtual_final_cash,recorded_final_cash))",
  ledgr_fold_stage_commit = paste0("canonical_json(list(cash_before,virtual_final_cash,recorded_final_cash,intended_gross_exposure,",
    "post_risk_gross_exposure,actual_gross_exposure,exposure_basis))")
)
ws4a_d6_hits <- function(fns) {
  unlist(lapply(names(fns), function(nm) {
    s <- ws4a_json_shapes(fns[[nm]])
    u <- unique(s)
    n <- vapply(u, function(v) sum(s == v) - sum(ws4a_d6_routed[names(ws4a_d6_routed) == nm] == v), 0)
    if (any(n > 0)) paste0(nm, ": ", u[n > 0])
  }))
}

testthat::test_that("[WS4a D6] the fold stages encode JSON only at the routed sites; P4 encodes none", {
  fns <- ws4a_sources()
  stages <- c(paste0("ledgr_fold_stage_", c("observe_settle", "decide", "plan", "apply", "commit")), "ledgr_fold_fill_candidate")
  testthat::expect_length(ws4a_d6_hits(fns[stages]), 0L)
  testthat::expect_length(ws4a_json_shapes(fns$ledgr_fold_stage_apply), 0L)
  hit <- function(nm, stmt) length(ws4a_d6_hits(ws4a_inject_into(fns, nm, stmt))) > 0L
  testthat::expect_true(hit("ledgr_fold_stage_apply", "encoded <- canonical_json(list(fee = fill$fee))"))
  testthat::expect_true(hit("ledgr_fold_stage_plan", "canonical_json(list(intent_reason = x))"))
  testthat::expect_true(hit(
    "ledgr_fold_stage_commit",
    "canonical_json(list(state_update = next_state))"
  ))
})
