  fold_source <- ledgr_test_candidate_source("lean_fold_envelope_plain")
  testthat::expect_match(
    fold_source,
    "ledgr_projection_feature_lookup_state(projection, feature_ids = def_ids, universe = ids, active_alias_map = active_alias_map, feature_name_state = feature_name_state)",
    fixed = TRUE
  )
