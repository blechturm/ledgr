  no_read <- ledgr_run(exp, params = list(read = FALSE), run_id = "facts-lazy-none")
  close(no_read)
  lookup <- unclass(counters$ctx)[[".pulse_lookup"]]
  testthat::expect_false(exists("entry_price", lookup$build_counts, inherits = FALSE))
  testthat::expect_identical(
    mget(c("service", "feature_resolver", "fill_axis_map"), lookup$preparation_counts),
    list(service = 1L, feature_resolver = 1L, fill_axis_map = 1L)
  )
