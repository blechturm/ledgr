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
  feature_vector <- ledgr:::ledgr_projection_feature_vector_accessor(
    projection,
    2L,
    feature_ids = c("sma_2", "sma_3"),
    prepared = prepared
  )

  testthat::expect_identical(feature("AAA", "sma_2"), 11)
  testthat::expect_identical(feature("AAA", "short"), 11)
  testthat::expect_identical(feature("BBB", "sma_3"), 41)
  testthat::expect_identical(feature_vector("short"), c(11, 21))
  testthat::expect_identical(feature_vector("sma_2"), c(11, 21))
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
    "Unknown feature name `missing` for instrument_id `AAA`. Active aliases: short, long. Concrete feature IDs: sma_2, sma_3.",
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
    testthat::expect_identical(fast$feature("AAA", "short"), 10)
    testthat::expect_identical(fast$features("BBB"), c(short = 20, long = 40))
  }
  testthat::expect_identical(calls, 1L)
  testthat::expect_identical(normalize_calls, 1L)

  scalar_source <- paste(deparse(body(
    ledgr:::ledgr_projection_feature_accessor_state
  )), collapse = "\n")
  bundle_source <- paste(deparse(body(
    ledgr:::ledgr_projection_feature_bundle_accessor_state
  )), collapse = "\n")
  testthat::expect_match(
    scalar_source,
    "ledgr_resolve_feature_name(",
    fixed = TRUE
  )
  testthat::expect_match(
    scalar_source,
    "inst_idx <- instrument_rows[[instrument_id]]",
    fixed = TRUE
  )
  testthat::expect_match(
    bundle_source,
    "is.null(members[[instrument_id]])",
    fixed = TRUE
  )
  testthat::expect_false(grepl("%in%", scalar_source, fixed = TRUE))
  testthat::expect_false(grepl("%in%", bundle_source, fixed = TRUE))

  invalid_alias <- ledgr:::ledgr_fast_context_state(
    c("AAA", "BBB"),
    projection = projection,
    feature_ids = c("sma_2", "sma_3"),
    active_alias_map = stats::setNames(1L, "fast")
  )
  testthat::expect_error(
    invalid_alias$features("AAA"),
    "`alias_map` must be a named character vector of concrete feature IDs.",
    class = "ledgr_invalid_alias_map",
    fixed = TRUE
  )
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
  result <- ledgr_sweep(experiment, grid, workers = 1L, seed = 1L)

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

testthat::test_that("[LTB-0141] explicit map memo is exact and forgets failures", {
  projection <- workstream7_projection()
  state <- new.env(parent = emptyenv())
  state$pulse_idx <- 2L
  prepared <- ledgr:::ledgr_projection_feature_lookup_state(
    projection,
    feature_ids = c("sma_2", "sma_3"),
    universe = c("AAA", "BBB")
  )
  accessor <- ledgr:::ledgr_projection_feature_bundle_accessor_state(
    projection,
    state,
    universe = c("AAA", "BBB"),
    feature_ids = c("sma_2", "sma_3"),
    prepared = prepared
  )
  concrete <- ledgr_feature_map(
    fast = ledgr_ind_sma(2L),
    slow = ledgr_ind_sma(3L)
  )
  rebuilt <- ledgr_feature_map(
    fast = ledgr_ind_sma(2L),
    slow = ledgr_ind_sma(3L)
  )
  reordered <- ledgr_feature_map(
    slow = ledgr_ind_sma(3L),
    fast = ledgr_ind_sma(2L)
  )
  parameterized <- ledgr_feature_map(
    fast = ledgr_ind_sma(ledgr_param("n")),
    slow = ledgr_ind_sma(3L)
  )
  tampered <- concrete
  tampered$feature_ids[["fast"]] <- "sma_3"
  swapped <- concrete
  swapped$aliases <- rev(swapped$aliases)
  unknown <- ledgr_feature_map(missing = ledgr_ind_sma(99L))

  testthat::expect_false(identical(concrete, rebuilt))
  testthat::expect_identical(accessor("AAA", concrete), c(fast = 11, slow = 31))
  testthat::expect_identical(accessor("AAA", rebuilt), c(fast = 11, slow = 31))
  testthat::expect_identical(accessor("AAA", reordered), c(slow = 31, fast = 11))
  testthat::expect_identical(
    accessor("AAA", c(second = "sma_3", first = "sma_2")),
    c(second = 31, first = 11)
  )
  testthat::expect_error(
    accessor("AAA", parameterized),
    "`ledgr_feature_id()` requires concrete features. Resolve parameterized declarations with concrete `feature_params` first.",
    class = "ledgr_unresolved_feature_id",
    fixed = TRUE
  )
  testthat::expect_error(
    accessor("AAA", tampered),
    "`x$feature_ids` does not match the mapped indicator IDs.",
    class = "ledgr_invalid_feature_map",
    fixed = TRUE
  )
  testthat::expect_error(
    accessor("AAA", swapped),
    "`x$indicators` names must match `x$aliases`.",
    class = "ledgr_invalid_feature_map",
    fixed = TRUE
  )
  testthat::expect_error(
    accessor("AAA", unknown),
    "Unknown feature name `sma_99` for instrument_id `AAA`. Active aliases: <none>. Concrete feature IDs: sma_2, sma_3.",
    class = "ledgr_unknown_feature_id",
    fixed = TRUE
  )
  testthat::expect_error(
    accessor("AAA", list(fast = "sma_2")),
    "`x` must be a ledgr_feature_map object.",
    class = "ledgr_invalid_feature_map",
    fixed = TRUE
  )

  validation_calls <- 0L
  original_validate <- ledgr:::ledgr_validate_feature_map_object
  testthat::local_mocked_bindings(
    ledgr_validate_feature_map_object = function(x) {
      validation_calls <<- validation_calls + 1L
      original_validate(x)
    },
    .package = "ledgr"
  )
  counted <- ledgr:::ledgr_projection_feature_bundle_accessor_state(
    projection,
    state,
    universe = c("AAA", "BBB"),
    feature_ids = c("sma_2", "sma_3"),
    prepared = prepared
  )
  counted("AAA", concrete)
  counted("BBB", concrete)
  counted("AAA", rebuilt)
  counted("AAA", reordered)
  testthat::expect_error(counted("AAA", tampered))
  counted("AAA", reordered)
  testthat::expect_error(counted("AAA", parameterized))
  testthat::expect_error(counted("AAA", parameterized))
  testthat::expect_error(counted("AAA", list(fast = "sma_2")))
  testthat::expect_error(counted("AAA", list(fast = "sma_2")))
  testthat::expect_identical(validation_calls, 9L)
})
