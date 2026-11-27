  fold_source <- paste(deparse(body(ledgr:::ledgr_fold_envelope)), collapse = "\n")
  testthat::expect_match(
    fold_source,
    "feature_name_state = availability_feature_name_state",
    fixed = TRUE
  )
