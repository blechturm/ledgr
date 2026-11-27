  decide_source <- paste(c(ledgr_test_candidate_source("lean_p2_decide"), ledgr_test_candidate_source("lean_context")), collapse = "\n")
  for (forbidden in c(
    "ledgr_history_bar_packet_frame", "ledgr_projection_feature_table",
    "ledgr_projection_features_wide", "feature_table =", "features_wide ="
  )) {
    testthat::expect_false(grepl(forbidden, decide_source, fixed = TRUE), info = forbidden)
  }
  for (forbidden in c("ledgr_utc", "as.POSIXct", "as.POSIXlt", "strptime", "regex")) {
    testthat::expect_false(grepl(forbidden, decide_source, fixed = TRUE), info = forbidden)
  }
  testthat::expect_true(
    grepl("cutoff_num = ts_num[[i]]", decide_source, fixed = TRUE)
  )
