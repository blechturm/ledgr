  decide <- paste(deparse(body(ns$ledgr_fold_stage_decide), width.cutoff = 500L), collapse = "\n")
  testthat::expect_match(decide, "pulse_seed = ledgr_pulse_seed_at(services, pulse_idx)", fixed = TRUE)
