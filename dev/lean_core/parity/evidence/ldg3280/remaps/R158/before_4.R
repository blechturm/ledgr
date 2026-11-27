testthat::test_that("[WS4a D1 publication] P4 and publication build no per-fill object, list or timestamp", {
  fns <- ws4a_sources()
  pub <- ws4a_publication(fns)
  testthat::expect_true(all(c(ws4a_pub_fns, paste0(names(ws4a_pub_closures), "/", ws4a_pub_closures)) %in% names(pub)))
  testthat::expect_length(ws4a_d1_pub_hits(pub), 0L)
  # The retired per-fill publication helpers are gone.
  testthat::expect_length(intersect(names(fns), c("ledgr_fill_event_row", "ledgr_event_buffer_write_rows")), 0L)
  hit <- function(nm, stmt) length(ws4a_d1_pub_hits(ws4a_inject_into(pub, nm, stmt))) > 0L
  testthat::expect_true(hit("ledgr_output_handler/handler$write_fill_events", "pulse_fill_rows <- vector(\"list\", 256L)"))
  testthat::expect_true(hit("ledgr_fill_event_payload", "for (k in seq_along(i)) row <- list(qty = fill$qty[[k]])"))
  testthat::expect_true(hit("ledgr_fill_event_payload", "res <- structure(list(), class = \"ledgr_ledger_write_result\")"))
  testthat::expect_true(hit("ledgr_output_handler/handler$flush_pulse_events", "cash <- vapply(staged, `[[`, numeric(1), \"cash_delta\")"))
  testthat::expect_true(hit("ledgr_output_handler/handler$record_accounting_fact", "ts <- as.POSIXct(block$ts_utc, tz = \"UTC\")"))
  testthat::expect_true(hit("ledgr_fold_stage_apply", paste("for (i in seq_along(fill$k)) lot_res <- ledgr_lot_fill(",
    "fold_state$lot_state, fill$pos[[i]], fill$side[[i]], fill$qty[[i]], fill$price[[i]], fill$fee[[i]])")))
})
