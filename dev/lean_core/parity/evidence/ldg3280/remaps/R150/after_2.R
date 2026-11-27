ws4a_d3_3166_fns <- c("lean_p3_plan", "lean_plan_pulse", "lean_plan_result", "lean_plan_affordability",
  "lean_plan_groups", "lean_plan_segments", "lean_plan_segment_rows", "ledgr_carrier_segments", "ledgr_carrier_segment_rows",
  "lean_plan_execution_view", "ledgr_cost_model_resolve", "ledgr_fill_publication_deltas", "ledgr_fold_plan_event_kinds",
  "ledgr_fill_event_payload", "ledgr_write_fill_events", "ledgr_fill_input_check")
ws4a_d3_3166 <- c(
  lean_plan_pulse = "stats::setNames(resulting[[i]], id)",
  lean_plan_pulse = "stats::setNames(before[[i]], id)",
  # The run-long radix ID permutation walked by the candidates' integer axis
  # positions (positions matched to positions, not names).
  lean_plan_affordability = "match(id_perm, axis_pos, 0L)",
  lean_plan_execution_view = "match(unlist(tokens, use.names = FALSE), .ledgr_plan_reason_levels)",
  # Debug only: the provider's execution view compared field by field.
  lean_p3_plan = "unclass(pv_view)[names(view)]",
  ledgr_fold_plan_event_kinds = "1L %in% kinds",
  ledgr_write_fill_events = "side %in% c(1L, -1L)",
  ledgr_fill_input_check = "columns %in% names(fill)"
)
ws4a_d3_3166_found <- function(e) {
  c(ws4a_name_keyed(e), vapply(Filter(function(x) ws4a_head(x) == "%in%", ws4a_calls(e)),
    function(x) substr(ws4a_txt(x), 1L, 70L), ""))
}

testthat::test_that("[WS4a D3 3166] the planners and publication inputs index by position", {
  fns <- ws4a_sources()
  hits <- function(f) {
    unlist(lapply(names(f), function(nm) {
      h <- setdiff(unique(ws4a_d3_3166_found(f[[nm]])), ws4a_d3_3166[names(ws4a_d3_3166) == nm])
      if (length(h)) paste0(nm, ": ", h)
    }))
  }
  testthat::expect_true(all(ws4a_d3_3166_fns %in% names(fns)))
  testthat::expect_length(hits(fns[ws4a_d3_3166_fns]), 0L)
  found <- unlist(lapply(unique(names(ws4a_d3_3166)), function(nm) paste(nm, ws4a_d3_3166_found(fns[[nm]]))))
  testthat::expect_setequal(found, paste(names(ws4a_d3_3166), ws4a_d3_3166))
  inject <- function(nm, stmt) {
    bad <- fns[nm]
    bad[[nm]] <- ws4a_inject(bad[[nm]], stmt)
    hits(bad)
  }
  testthat::expect_gt(length(inject("lean_plan_pulse", "open <- execution$open[instrument_ids]")), 0L)
  testthat::expect_gt(length(inject("lean_plan_pulse", "pos <- match(ids, rownames(execution$open))")), 0L)
  testthat::expect_gt(length(inject("ledgr_fill_event_payload", "keep <- instrument_id %in% held")), 0L)
})
