  name_preparations <- 0L
  original_name_state <- ledgr:::ledgr_projection_feature_name_state
  run <- testthat::with_mocked_bindings(
    ledgr_run(experiment, run_id = "ws20-frame-retirement"),
    ledgr_projection_feature_name_state = function(...) {
      name_preparations <<- name_preparations + 1L
      original_name_state(...)
    },
    .package = "ledgr"
  )
  on.exit(close(run), add = TRUE)
  testthat::expect_identical(name_preparations, 1L)
