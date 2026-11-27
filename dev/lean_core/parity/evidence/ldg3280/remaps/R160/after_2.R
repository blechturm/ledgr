ws4a_d6_routed <- c(
  # The lean stages encode one routed detail themselves: P3's affordability
  # stop. P1's valuation-stop detail and P2's risk-gate detail are encoded in
  # the marks.R helpers the stages call; P2's intent reason is stored raw and
  # P5's reconciliation detail is encoded at the terminal transfer
  # (lean_loop_expand).
  lean_p3_plan = "canonical_json(list(cash_before,virtual_final_cash,recorded_final_cash))"
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
  stages <- c(paste0("lean_p", 1:5, c("_value", "_decide", "_plan", "_apply", "_commit")), "lean_lot_first_failure")
  testthat::expect_length(ws4a_d6_hits(fns[stages]), 0L)
  testthat::expect_length(ws4a_json_shapes(fns$lean_p4_apply), 0L)
  hit <- function(nm, stmt) length(ws4a_d6_hits(ws4a_inject_into(fns, nm, stmt))) > 0L
  testthat::expect_true(hit("lean_p4_apply", "encoded <- canonical_json(list(fee = fill$fee))"))
  testthat::expect_true(hit("lean_p3_plan", "canonical_json(list(intent_reason = x))"))
  testthat::expect_true(hit(
    "lean_p5_commit",
    "canonical_json(list(state_update = next_state))"
  ))
})
