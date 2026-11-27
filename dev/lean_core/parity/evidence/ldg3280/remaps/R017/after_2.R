  before <- lookup_preparations
  testthat::with_mocked_bindings(
    {
      invisible(names(ctx))
      invisible(names(ctx))
      invisible(ctx$z_ret)
      invisible(ctx$return_1)
    },
    ledgr_projection_feature_lookup_state = count_lookup_state,
    .package = "ledgr"
  )
  testthat::expect_identical(
    lookup_preparations,
    before
  )
  testthat::expect_identical(before, 1L)
