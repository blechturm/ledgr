ws4a_d3_3165 <- c(
  # P2 input boundary: the context's positions snapshot is named by the
  # decision axis for the strategy context and the target checks.
  lean_p2_decide = "names(positions_snapshot) <- ids",
  # Debug only: the post-risk quantity check takes the targets by ID.
  lean_p2_decide = "stats::setNames(tq, ids)",
  # Debug only: the provider's execution view compared field by field (names
  # of fields, not instruments).
  lean_p3_plan = "unclass(pv_view)[names(view)]",
  # Mark-source tokens of the decoded dictionary, not instruments.
  lean_marks_skip_rows = "src %in% c(\"stale_close\", \"frozen_close\")"
)
ws4a_d3_3165_found <- function(e) {
  c(ws4a_name_keyed(e), vapply(Filter(function(x) ws4a_head(x) == "%in%", ws4a_calls(e)),
    function(x) substr(ws4a_txt(x), 1L, 70L), ""))
}
ws4a_d3_3165_hits <- function(fns) {
  unlist(lapply(names(fns), function(nm) {
    h <- setdiff(unique(ws4a_d3_3165_found(fns[[nm]])), ws4a_d3_3165[names(ws4a_d3_3165) == nm])
    if (length(h)) paste0(nm, ": ", h)
  }))
}

testthat::test_that("[WS4a D3 3165] P2, P3, P5 and the skip read the decision by position", {
  fns <- ws4a_sources()
  examined <- c("lean_p2_decide", "lean_p3_plan", "lean_p5_commit", "lean_marks_skip_rows")
  testthat::expect_length(ws4a_d3_3165_hits(fns[examined]), 0L)
  # The census is exact: every entry is still present.
  found <- unlist(lapply(unique(names(ws4a_d3_3165)), function(nm) paste(nm, unique(ws4a_d3_3165_found(fns[[nm]])))))
  testthat::expect_setequal(found, paste(names(ws4a_d3_3165), ws4a_d3_3165))
  inject <- function(nm, stmt) {
    bad <- fns[nm]
    bad[[nm]] <- ws4a_inject(bad[[nm]], stmt)
    ws4a_d3_3165_hits(bad)
  }
  testthat::expect_gt(length(inject("lean_p2_decide", "k <- match(id, context_ids)")), 0L)
  testthat::expect_gt(length(inject("lean_p2_decide", "m <- packet$mark[context_ids]")), 0L)
  testthat::expect_gt(length(inject("lean_p3_plan", "idx <- services$id_to_idx[target_names]")), 0L)
  testthat::expect_gt(length(inject("lean_p5_commit", "keep <- context_ids %in% held")), 0L)
})
