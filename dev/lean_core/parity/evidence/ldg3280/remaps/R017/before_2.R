  before <- ctx$.pulse_lookup$preparation_counts$feature_resolver
  invisible(names(ctx))
  invisible(names(ctx))
  invisible(ctx$z_ret)
  invisible(ctx$return_1)
  testthat::expect_identical(
    ctx$.pulse_lookup$preparation_counts$feature_resolver,
    before
  )
  testthat::expect_identical(before, 1L)
