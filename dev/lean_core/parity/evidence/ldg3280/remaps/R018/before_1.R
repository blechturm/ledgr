  decide_source <- paste(deparse(ledgr:::ledgr_fold_stage_decide), collapse = "\n")
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
    grepl("cutoff_num = packet$ts", decide_source, fixed = TRUE)
  )
