  for (stage in c(
    "lean_fold_envelope_plain", "lean_p1_value", "lean_p2_decide",
    "lean_p3_plan", "lean_p4_apply", "lean_p5_commit"
  )) {
    stage_source <- ledgr_test_candidate_source(stage)
