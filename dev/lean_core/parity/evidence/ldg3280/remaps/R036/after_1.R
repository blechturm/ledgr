  fold_source <- ledgr_test_candidate_source("lean_fold_envelope_plain")
  testthat::expect_match(
    fold_source,
    "feature_lookup_state <- ledgr_projection_feature_lookup_state(",
    fixed = TRUE
  )
  testthat::expect_match(
    ledgr_test_candidate_source("lean_context"),
    "feature_lookup = feature_lookup_state",
    fixed = TRUE
  )
