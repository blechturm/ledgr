  for (stage in c(
    "ledgr_fold_stage_observe_settle", "ledgr_fold_stage_decide",
    "ledgr_fold_stage_plan", "ledgr_fold_stage_apply", "ledgr_fold_stage_commit"
  )) {
    stage_source <- paste(deparse(body(getFromNamespace(stage, "ledgr"))), collapse = "\n")
