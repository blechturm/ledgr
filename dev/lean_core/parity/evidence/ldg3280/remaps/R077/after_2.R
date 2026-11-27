  decide <- ledgr_test_candidate_source("lean_context")
  testthat::expect_match(decide, "pulse_seed = if (is.null(pulse_seeds)) NULL else pulse_seeds[[i]]", fixed = TRUE)
