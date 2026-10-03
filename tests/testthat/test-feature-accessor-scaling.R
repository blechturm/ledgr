workstream7_projection <- function() {
  list(
    instrument_index = c(AAA = 1L, BBB = 2L),
    feature_values = list(
      sma_2 = matrix(c(10, 20, 11, 21), nrow = 2L),
      sma_3 = matrix(c(30, 40, 31, 41), nrow = 2L)
    )
  )
}

testthat::test_that("[LTB-0139] prepared feature accessors preserve calls and prepare once", {
  projection <- workstream7_projection()
  state <- new.env(parent = emptyenv())
  state$pulse_idx <- 2L
  prepared <- ledgr:::ledgr_projection_feature_lookup_state(
    projection,
    feature_ids = c("sma_2", "sma_3"),
    universe = c("AAA", "BBB"),
    active_alias_map = c(short = "sma_2", long = "sma_3")
  )
  feature <- ledgr:::ledgr_projection_feature_accessor_state(
    projection,
    state,
    feature_ids = c("sma_2", "sma_3"),
    prepared = prepared
  )
  features <- ledgr:::ledgr_projection_feature_bundle_accessor_state(
    projection,
    state,
    universe = c("AAA", "BBB"),
    feature_ids = c("sma_2", "sma_3"),
    active_alias_map = c(short = "sma_2", long = "sma_3"),
    prepared = prepared
  )

  testthat::expect_identical(feature("AAA", "sma_2"), 11)
  testthat::expect_identical(feature("BBB", "sma_3"), 41)
  testthat::expect_identical(feature("NOPE", "sma_2"), NA_real_)
  testthat::expect_identical(feature("NOPE", "sma_2", default = -1), -1)
  testthat::expect_identical(
    features("AAA"),
    c(short = 11, long = 31)
  )
  testthat::expect_identical(
    features("BBB", c(first = "sma_3", second = "sma_2")),
    c(first = 41, second = 21)
  )
  testthat::expect_error(
    feature("AAA", "missing"),
    "Unknown feature ID `missing` for instrument_id `AAA`. Available feature IDs: sma_2, sma_3.",
    class = "ledgr_unknown_feature_id",
    fixed = TRUE
  )
  testthat::expect_error(
    features("NOPE"),
    "Unknown instrument_id 'NOPE'. Available ctx$universe: AAA, BBB.",
    class = "ledgr_invalid_pulse_context",
    fixed = TRUE
  )

  calls <- 0L
  normalize_calls <- 0L
  original_prepare <- ledgr:::ledgr_projection_feature_lookup_state
  original_normalize <- ledgr:::ledgr_normalize_alias_map
  testthat::local_mocked_bindings(
    ledgr_projection_feature_lookup_state = function(...) {
      calls <<- calls + 1L
      original_prepare(...)
    },
    ledgr_normalize_alias_map = function(...) {
      normalize_calls <<- normalize_calls + 1L
      original_normalize(...)
    },
    .package = "ledgr"
  )
  fast <- ledgr:::ledgr_fast_context_state(
    c("AAA", "BBB"),
    projection = projection,
    feature_ids = c("sma_2", "sma_3"),
    active_alias_map = c(short = "sma_2", long = "sma_3")
  )
  for (i in seq_len(20L)) {
    testthat::expect_identical(fast$feature("AAA", "sma_2"), 10)
    testthat::expect_identical(fast$features("BBB"), c(short = 20, long = 40))
  }
  testthat::expect_identical(calls, 1L)
  testthat::expect_identical(normalize_calls, 1L)
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0140] prepared feature state stays inside one sweep candidate", {
  bars <- ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:5)
  snapshot <- ledgr_snapshot_from_df(
    bars,
    db_path = tempfile(fileext = ".duckdb")
  )
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  features <- ledgr_feature_map(signal = ledgr_ind_sma(ledgr_param("n")))
  strategy <- function(ctx, params) {
    value <- ctx$features("AAA")[["signal"]]
    targets <- ctx$flat()
    if (is.finite(value)) targets[["AAA"]] <- 1
    targets
  }
  experiment <- ledgr_experiment(
    snapshot,
    strategy,
    features = features,
    cost_model = ledgr_cost_zero()
  )
  grid <- ledgr_grid_cross(
    features = ledgr_feature_grid(n = c(2L, 3L)),
    strategy = ledgr_strategy_grid(unused = 1)
  )

  seen <- list()
  original_prepare <- ledgr:::ledgr_projection_feature_lookup_state
  testthat::local_mocked_bindings(
    ledgr_projection_feature_lookup_state = function(...) {
      value <- original_prepare(...)
      seen[[length(seen) + 1L]] <<- value
      value
    },
    .package = "ledgr"
  )
  result <- ledgr_sweep(experiment, grid, seed = 1L)

  testthat::expect_true(all(result$status == "DONE"))
  maps <- lapply(seen, function(x) x$active_lookup$value)
  testthat::expect_true(any(vapply(maps, identical, logical(1), c(signal = "sma_2"))))
  testthat::expect_true(any(vapply(maps, identical, logical(1), c(signal = "sma_3"))))
  environments <- lapply(seen, function(x) x$instrument_rows)
  if (length(environments) > 1L) {
    testthat::expect_false(any(vapply(
      environments[-1L],
      identical,
      logical(1),
      environments[[1L]]
    )))
  }
})
