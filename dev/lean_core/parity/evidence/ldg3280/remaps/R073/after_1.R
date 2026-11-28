  # The run's preparation sites, counted at the preparers the fold calls in
  # E: the fold service (its schedule query), the feature resolver and the
  # fill-axis map.
  preparations <- new.env(parent = emptyenv())
  count <- function(name, f) {
    force(f)
    function(...) {
      preparations[[name]] <- as.integer(preparations[[name]] %||% 0L) + 1L
      f(...)
    }
  }
  no_read <- testthat::with_mocked_bindings(
    ledgr_run(exp, params = list(read = FALSE), run_id = "facts-lazy-none"),
    ledgr_strategy_schedule_query = count("service", ledgr:::ledgr_strategy_schedule_query),
    ledgr_projection_feature_lookup_state = count("feature_resolver", ledgr:::ledgr_projection_feature_lookup_state),
    ledgr_position_fact_fill_axis = count("fill_axis_map", ledgr:::ledgr_position_fact_fill_axis),
    .package = "ledgr"
  )
  close(no_read)
  lookup <- unclass(counters$ctx)[[".pulse_lookup"]]
  testthat::expect_false(exists("entry_price", lookup$build_counts, inherits = FALSE))
  testthat::expect_identical(
    mget(c("service", "feature_resolver", "fill_axis_map"), preparations),
    list(service = 1L, feature_resolver = 1L, fill_axis_map = 1L)
  )
