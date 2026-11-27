  observed <- new.env(parent = emptyenv())
  # The preparation sites, counted at the preparers the fold calls in E: the
  # fold service (one envelope entry), the feature resolver and the
  # fill-axis map.
  count <- function(name, f) {
    force(f)
    function(...) {
      observed[[name]] <- as.integer(observed[[name]] %||% 0L) + 1L
      f(...)
    }
  }
  testthat::local_mocked_bindings(
    ledgr_fold_envelope = count("service", ledgr:::ledgr_fold_envelope),
    ledgr_projection_feature_lookup_state = count("feature_resolver", ledgr:::ledgr_projection_feature_lookup_state),
    ledgr_position_fact_fill_axis = count("fill_axis_map", ledgr:::ledgr_position_fact_fill_axis),
    .package = "ledgr"
  )
