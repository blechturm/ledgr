ws4a_d3_3165 <- c(
  # LDG-3195 removed the P2 frame/table input and its three membership scans.
  # P2 return still notes skipped sizing by instrument ID.
  ledgr_fold_stage_decide = "context_ids %in% services$pulse_notes$sizing_skipped",
  # Mark-source tokens of the decoded dictionary, not instruments.
  ledgr_fold_scheduled_skip_decision = "mark_source %in% c(\"stale_close\", \"frozen_close\")"
)
ws4a_d3_3165_hits <- function(fns) {
  unlist(lapply(names(fns), function(nm) {
    e <- fns[[nm]]
    found <- c(ws4a_name_keyed(e), vapply(Filter(function(x) ws4a_head(x) == "%in%", ws4a_calls(e)),
      function(x) substr(ws4a_txt(x), 1L, 70L), ""))
    h <- setdiff(unique(found), ws4a_d3_3165[names(ws4a_d3_3165) == nm])
    if (length(h)) paste0(nm, ": ", h)
  }))
}

testthat::test_that("[WS4a D3 3165] P2, P3, P5 and the skip read the decision by position", {
  fns <- ws4a_sources()
  examined <- c("ledgr_fold_stage_decide", "ledgr_fold_stage_plan", "ledgr_fold_stage_commit",
    "ledgr_fold_scheduled_skip_decision")
  testthat::expect_length(ws4a_d3_3165_hits(fns[examined]), 0L)
  # The census is exact: every entry is still present.
  found <- unlist(lapply(unique(names(ws4a_d3_3165)), function(nm) paste(nm, vapply(Filter(function(x)
    ws4a_head(x) == "%in%", ws4a_calls(fns[[nm]])), function(x) substr(ws4a_txt(x), 1L, 70L), ""))))
  testthat::expect_setequal(found, paste(names(ws4a_d3_3165), ws4a_d3_3165))
  inject <- function(nm, stmt) {
    bad <- fns[nm]
    bad[[nm]] <- ws4a_inject(bad[[nm]], stmt)
    ws4a_d3_3165_hits(bad)
  }
  testthat::expect_gt(length(inject("ledgr_fold_stage_decide", "k <- match(id, context_ids)")), 0L)
  testthat::expect_gt(length(inject("ledgr_fold_stage_decide", "m <- packet$mark[context_ids]")), 0L)
  testthat::expect_gt(length(inject("ledgr_fold_stage_plan", "idx <- services$id_to_idx[target_names]")), 0L)
  testthat::expect_gt(length(inject("ledgr_fold_stage_commit", "keep <- context_ids %in% held")), 0L)
})
