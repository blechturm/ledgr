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
  resolve_calls <- 0L
  original_prepare <- ledgr:::ledgr_projection_feature_lookup_state
  original_normalize <- ledgr:::ledgr_normalize_alias_map
  original_resolve <- ledgr:::ledgr_resolve_feature_name
  testthat::local_mocked_bindings(
    ledgr_projection_feature_lookup_state = function(...) {
      calls <<- calls + 1L
      original_prepare(...)
    },
    ledgr_normalize_alias_map = function(...) {
      normalize_calls <<- normalize_calls + 1L
      original_normalize(...)
    },
    ledgr_resolve_feature_name = function(...) {
      resolve_calls <<- resolve_calls + 1L
      original_resolve(...)
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
  testthat::expect_identical(resolve_calls, 40L)

  name_state <- ledgr:::ledgr_projection_feature_name_state(
    projection,
    feature_ids = c("sma_2", "sma_3"),
    active_alias_map = c(short = "sma_2", long = "sma_3")
  )
  lookup_a <- ledgr:::ledgr_projection_feature_lookup_state(
    projection,
    universe = "AAA",
    feature_name_state = name_state
  )
  lookup_b <- ledgr:::ledgr_projection_feature_lookup_state(
    projection,
    universe = "BBB",
    feature_name_state = name_state
  )
  testthat::expect_identical(lookup_a$name_lookup, lookup_b$name_lookup)
  testthat::expect_identical(lookup_a$known_features, lookup_b$known_features)
  fold_source <- paste(deparse(body(ledgr:::ledgr_fold_envelope)), collapse = "\n")
  testthat::expect_match(
    fold_source,
    "feature_name_state = availability_feature_name_state",
    fixed = TRUE
  )

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

  lookup_calls <- 0L
  original_lookup <- ledgr:::ledgr_explicit_feature_lookup
  testthat::local_mocked_bindings(
    ledgr_explicit_feature_lookup = function(feature_map,
                                             name_lookup,
                                             instrument_id = NULL) {
      lookup_calls <<- lookup_calls + 1L
      original_lookup(
        feature_map,
        name_lookup,
        instrument_id = instrument_id
      )
    },
    .package = "ledgr"
  )
  character_map <- c(second = "sma_3", first = "sma_2")
  rebuilt_character_map <- stats::setNames(
    unname(character_map),
    names(character_map)
  )
  reordered_character_map <- c(first = "sma_2", second = "sma_3")
  testthat::expect_identical(
    counted("AAA", character_map),
    c(second = 31, first = 11)
  )
  counted("BBB", character_map)
  counted("AAA", rebuilt_character_map)
  counted("AAA", reordered_character_map)
  testthat::expect_error(counted("AAA", c(missing = "sma_99")))
  counted("AAA", reordered_character_map)
  testthat::expect_identical(lookup_calls, 4L)
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0189] availability folds prepare hashed feature lookups once", {
  snapshot <- terminal_outcome_snapshot(list(
    AAA = c(100, 101, 102, 103, 104),
    BBB = c(50, 49, 51, 52, 53)
  ))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  feature_map <- ledgr_feature_map(
    signal = ledgr_ind_sma(ledgr_param("n"))
  )
  strategy <- function(ctx, params) {
    signal <- ctx$vec$feature("signal")
    target <- ctx$flat()
    target[is.finite(signal) & signal > 51] <- 1
    target
  }
  experiment <- ledgr_experiment(
    snapshot,
    strategy,
    features = feature_map,
    valuation_policy = ledgr_valuation_stale(1L),
    cost_model = ledgr_cost_zero()
  )

  prepare_calls <- 0L
  fold_prepare_calls <- 0L
  original_prepare <- ledgr:::ledgr_projection_feature_lookup_state
  testthat::local_mocked_bindings(
    ledgr_projection_feature_lookup_state = function(...) {
      prepare_calls <<- prepare_calls + 1L
      calls <- vapply(
        sys.calls(),
        function(x) paste(deparse(x), collapse = ""),
        character(1)
      )
      if (any(grepl("ledgr_execute_fold", calls, fixed = TRUE))) {
        fold_prepare_calls <<- fold_prepare_calls + 1L
      }
      original_prepare(...)
    },
    .package = "ledgr"
  )
  direct <- ledgr_run(
    experiment,
    feature_params = list(n = 2L),
    run_id = "availability-lookup-once"
  )
  on.exit(close(direct), add = TRUE)
  testthat::expect_identical(prepare_calls, 1L)
  testthat::expect_identical(fold_prepare_calls, 1L)

  prepare_calls <- 0L
  fold_prepare_calls <- 0L
  swept <- ledgr_sweep(
    experiment,
    ledgr_grid_cross(
      features = ledgr_feature_grid(n = 2L),
      strategy = ledgr_strategy_grid(unused = 1)
    ),
    workers = 1L,
    seed = 1L
  )
  testthat::expect_lte(prepare_calls, 2L)
  testthat::expect_identical(fold_prepare_calls, 1L)
  testthat::expect_identical(swept$status, "DONE")
  direct_equity <- ledgr_results(direct, "equity")
  testthat::expect_identical(
    swept$final_equity[[1L]],
    direct_equity$equity[[nrow(direct_equity)]]
  )

  fold_source <- paste(deparse(body(ledgr:::ledgr_fold_envelope)), collapse = "\n")
  testthat::expect_match(
    fold_source,
    "feature_lookup_state = availability_feature_lookup_state",
    fixed = TRUE
  )
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0191] availability feature reads enforce the current decision axis", {
  dates <- as.Date("2020-01-01") + 0:3
  pulses <- as.POSIXct(paste(dates, "16:00:00"), tz = "UTC")
  sessions <- ledgr_facts_sessions(
    data.frame(
      session_date = dates,
      status = "open",
      session_open = "09:30:00",
      session_close = "16:00:00",
      knowledge_time = as.POSIXct(dates, tz = "UTC") - 1,
      stringsAsFactors = FALSE
    ),
    venue_id = "XNYS"
  )
  membership_input <- data.frame(
    effective_from = pulses[c(1L, 3L)],
    knowledge_time = pulses[c(1L, 3L)] - 1,
    source = "decision-axis-witness",
    stringsAsFactors = FALSE
  )
  membership_input$members <- I(list(c("AAA", "BBB"), "AAA"))
  membership <- ledgr_facts_membership_snapshots(
    membership_input,
    universe_id = "shrinking",
    complete = TRUE
  )
  snapshot <- ledgr_snapshot_from_df(
    ledgr_test_make_bars(c("AAA", "BBB"), pulses),
    facts = ledgr_facts(sessions, membership), price_basis = "split_adjusted"
  )
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  observed <- new.env(parent = emptyenv())
  strategy <- function(ctx, params) {
    capture <- function(call) {
      tryCatch(
        {
          call()
          list(class = NA_character_, message = NA_character_)
        },
        error = function(err) {
          list(class = class(err)[[1L]], message = conditionMessage(err))
        }
      )
    }
    if (identical(ctx$ts_utc, "2020-01-03T16:00:00Z")) {
      observed$universe <- ctx$universe
      observed$checks <- list(
        scalar = capture(function() ctx$feature("BBB", "signal")),
        bundle = capture(function() ctx$features("BBB")),
        explicit = capture(function() {
          ctx$features("BBB", c(local_signal = "sma_2"))
        }),
        scalar_na = capture(function() ctx$feature(NA_character_, "signal")),
        scalar_empty = capture(function() ctx$feature("", "signal")),
        bundle_numeric = capture(function() ctx$features(1L))
      )
    }
    ctx$flat()
  }
  experiment <- ledgr_experiment(
    snapshot,
    strategy,
    universe = ledgr_universe_members("shrinking"),
    features = ledgr_feature_map(signal = ledgr_ind_sma(2L)),
    valuation_policy = ledgr_valuation_stale(1L),
    cost_model = ledgr_cost_zero()
  )
  backtest <- ledgr_run(experiment, run_id = "shrinking-feature-axis")
  on.exit(close(backtest), add = TRUE)

  testthat::expect_identical(observed$universe, "AAA")
  outside_message <- "Unknown instrument_id 'BBB'. Available ctx$universe: AAA."
  for (name in c("scalar", "bundle", "explicit")) {
    testthat::expect_identical(
      observed$checks[[name]],
      list(class = "ledgr_invalid_pulse_context", message = outside_message)
    )
  }
  testthat::expect_identical(
    observed$checks$scalar_na,
    list(
      class = "ledgr_invalid_pulse_context",
      message = "Unknown instrument_id 'NA'. Available ctx$universe: AAA."
    )
  )
  testthat::expect_identical(
    observed$checks$scalar_empty,
    list(
      class = "ledgr_invalid_pulse_context",
      message = "Unknown instrument_id ''. Available ctx$universe: AAA."
    )
  )
  testthat::expect_identical(
    observed$checks$bundle_numeric,
    list(
      class = "ledgr_invalid_args",
      message = "`instrument_id` must be a non-empty character scalar."
    )
  )
})
