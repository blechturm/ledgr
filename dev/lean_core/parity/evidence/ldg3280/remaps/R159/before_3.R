ws4a_d3_3167 <- c(
  "ledgr_write_fill_publication_row" = "publication[[name]]",
  "ledgr_write_fill_publication_row" = "names(values) <- columns",
  "ledgr_output_handler/stage_fill_block" = "pending_fills[[name]]",
  "ledgr_output_handler/stage_fill_block" = "block[[name]]",
  "ledgr_output_handler/handler$flush_pulse_events" = "block[[name]]",
  "ledgr_output_handler/handler$append_event_rows" = "rows[[name]]",
  "ledgr_output_sink_memory/sink$stage_legs" = "pending_legs[[name]]",
  "ledgr_output_sink_memory/sink$stage_legs" = "legs[[name]]"
)

testthat::test_that("[WS4a D3 3167] P4 and publication index instruments by position", {
  pub <- ws4a_publication(ws4a_sources())
  found <- function(e) {
    c(ws4a_name_keyed(e), vapply(Filter(function(x) ws4a_head(x) == "%in%", ws4a_calls(e)),
      function(x) substr(ws4a_txt(x), 1L, 70L), ""))
  }
  hits <- function(f) {
    unlist(lapply(names(f), function(nm) {
      h <- setdiff(unique(found(f[[nm]])), ws4a_d3_3167[names(ws4a_d3_3167) == nm])
      if (length(h)) paste0(nm, ": ", h)
    }))
  }
  testthat::expect_length(hits(pub), 0L)
  census <- unlist(lapply(unique(names(ws4a_d3_3167)), function(nm) paste(nm, unique(found(pub[[nm]])))))
  testthat::expect_setequal(census, paste(names(ws4a_d3_3167), ws4a_d3_3167))
  inject <- function(nm, stmt) hits(ws4a_inject_into(pub, nm, stmt))
  testthat::expect_gt(length(inject("ledgr_fold_stage_apply", "net <- candidate$book$net_by_inst[instrument_id]")), 0L)
  testthat::expect_gt(length(inject("ledgr_fill_leg_block", "row <- match(block$instrument_id, names(applied$close_qty))")), 0L)
  testthat::expect_gt(length(inject("ledgr_output_handler/handler$record_accounting_fact", "keep <- block$instrument_id %in% held_ids")), 0L)
})
