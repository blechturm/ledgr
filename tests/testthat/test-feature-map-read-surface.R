feature_map_read_surface_bars <- function(ids = c("AAA", "BBB"), n = 6L) {
  pulses <- as.POSIXct("2020-01-01", tz = "UTC") + 86400 * seq_len(n) - 86400
  data.frame(
    instrument_id = rep(ids, times = n),
    ts_utc = rep(pulses, each = length(ids)),
    open = rep(seq_len(n) + 99, each = length(ids)),
    high = rep(seq_len(n) + 100, each = length(ids)),
    low = rep(seq_len(n) + 98, each = length(ids)),
    close = rep(seq_len(n) + 99, each = length(ids)),
    volume = 1000,
    stringsAsFactors = FALSE
  )
}

testthat::test_that("[LTB-0183] singular reads share active-alias resolution", {
  projection <- list(
    instrument_index = c(AAA = 1L, BBB = 2L),
    feature_values = list(
      sma_2 = matrix(c(10, 20, 11, 21), nrow = 2L),
      sma_3 = matrix(c(30, 40, 31, 41), nrow = 2L)
    )
  )
  prepared <- ledgr:::ledgr_projection_feature_lookup_state(
    projection,
    feature_ids = c("sma_2", "sma_3"),
    universe = c("AAA", "BBB"),
    active_alias_map = c(short = "sma_2", long = "sma_3")
  )
  state <- new.env(parent = emptyenv())
  state$pulse_idx <- 2L
  scalar <- ledgr:::ledgr_projection_feature_accessor_state(
    projection,
    state,
    prepared = prepared
  )
  plane <- ledgr:::ledgr_projection_feature_vector_accessor(
    projection,
    2L,
    prepared = prepared
  )
  bundle <- ledgr:::ledgr_projection_feature_bundle_accessor_state(
    projection,
    state,
    universe = c("AAA", "BBB"),
    prepared = prepared
  )

  testthat::expect_identical(plane("short"), plane("sma_2"))
  testthat::expect_identical(scalar("AAA", "short"), scalar("AAA", "sma_2"))
  testthat::expect_identical(
    unname(vapply(c("AAA", "BBB"), scalar, numeric(1), feature_name = "short")),
    plane("short")
  )
  testthat::expect_identical(
    unname(vapply(c("AAA", "BBB"), function(id) bundle(id)[["short"]], numeric(1))),
    plane("short")
  )

  ctx <- list(
    universe = c("AAA", "BBB"),
    availability_active = FALSE,
    vec = list(feature = plane)
  )
  alias_signal <- ledgr_signal_feature(ctx, "short")
  id_signal <- ledgr_signal_feature(ctx, "sma_2")
  testthat::expect_identical(as.numeric(alias_signal), as.numeric(id_signal))
  testthat::expect_identical(attr(alias_signal, "eligible"), c(TRUE, TRUE))
  testthat::expect_identical(attr(alias_signal, "origin"), "short")
  testthat::expect_error(
    plane("missing"),
    "Unknown feature name `missing`. Active aliases: short, long. Concrete feature IDs: sma_2, sma_3.",
    class = "ledgr_unknown_feature_id",
    fixed = TRUE
  )

  empty_ctx <- list(
    universe = c("AAA", "BBB"),
    feature_table = data.frame(),
    features_wide = data.frame(),
    .positions = c(AAA = 0, BBB = 0),
    .pulse_lookup = new.env(parent = emptyenv())
  )
  empty_ctx <- ledgr:::ledgr_attach_feature_helpers(
    empty_ctx,
    projection = projection,
    pulse_idx = 2L,
    feature_ids = c("sma_2", "sma_3"),
    active_alias_map = c(short = "sma_2", long = "sma_3")
  )
  empty_ctx <- ledgr:::ledgr_refresh_pulse_context_lookup(
    empty_ctx,
    bars = data.frame(),
    positions = c(AAA = 0, BBB = 0),
    universe = c("AAA", "BBB")
  )
  empty_ctx <- ledgr:::ledgr_filter_pulse_context_features(
    empty_ctx,
    character(),
    c("AAA", "BBB")
  )
  testthat::expect_identical(empty_ctx$vec$feature("short"), numeric())
})

testthat::test_that("[LTB-0185] explicit maps cannot redefine known names", {
  bars <- feature_map_read_surface_bars("AAA", 4L)
  snapshot <- ledgr_snapshot_from_df(
    bars,
    db_path = tempfile(fileext = ".duckdb")
  )
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  features <- ledgr_feature_map(
    fast = ledgr_ind_sma(2L),
    slow = ledgr_ind_sma(3L)
  )
  pulse <- ledgr_pulse_snapshot(
    snapshot,
    universe = "AAA",
    ts_utc = max(bars$ts_utc),
    features = features
  )
  on.exit(close(pulse), add = TRUE)
  conflict <- c(fast = "sma_3")
  object_conflict <- ledgr_feature_map(fast = ledgr_ind_sma(3L))
  message <- paste(
    "Explicit feature alias `fast` requests `sma_3`, but that name",
    "already resolves to `sma_2` in this context."
  )
  consumers <- list(
    bundle_character = function() pulse$features("AAA", conflict),
    bundle_object = function() pulse$features("AAA", object_conflict),
    long_character = function() ledgr_pulse_features(pulse, conflict),
    long_object = function() ledgr_pulse_features(pulse, object_conflict),
    wide_character = function() ledgr_pulse_wide(pulse, conflict),
    wide_object = function() ledgr_pulse_wide(pulse, object_conflict)
  )
  for (consumer in consumers) {
    testthat::expect_error(
      consumer(),
      message,
      class = "ledgr_invalid_feature_map",
      fixed = TRUE
    )
  }
  testthat::expect_error(
    pulse$features("AAA", c(sma_2 = "sma_3")),
    "Explicit feature alias `sma_2` requests `sma_3`, but that name already resolves to `sma_2` in this context.",
    class = "ledgr_invalid_feature_map",
    fixed = TRUE
  )

  own <- pulse$features("AAA", c(fast = "sma_2"))
  local <- pulse$features("AAA", c(local_fast = "sma_2"))
  reused_local <- pulse$features("AAA", c(local_fast = "sma_3"))
  testthat::expect_identical(unname(own), unname(local))
  testthat::expect_false(identical(unname(local), unname(reused_local)))
  long <- ledgr_pulse_features(pulse, c(local_fast = "sma_2"))
  wide <- ledgr_pulse_wide(pulse, c(local_fast = "sma_2"))
  testthat::expect_identical(unique(long$alias), "local_fast")
  testthat::expect_identical(unique(long$feature_id), "sma_2")
  testthat::expect_true("AAA__feature_local_fast" %in% names(wide))

  unmapped <- ledgr_pulse_snapshot(
    snapshot,
    universe = "AAA",
    ts_utc = max(bars$ts_utc),
    features = list(ledgr_ind_sma(2L))
  )
  on.exit(close(unmapped), add = TRUE)
  testthat::expect_true(
    "AAA__feature_sma_2" %in% names(ledgr_pulse_wide(unmapped))
  )
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0184] public execution and pulse inspection agree on aliases", {
  bars <- feature_map_read_surface_bars()
  snapshot <- ledgr_snapshot_from_df(
    bars,
    db_path = tempfile(fileext = ".duckdb")
  )
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  features <- ledgr_feature_map(signal = ledgr_ind_sma(ledgr_param("n")))
  strategy <- function(ctx, params) {
    alias <- ctx$vec$feature("signal")
    feature_id <- paste0("sma_", params$n)
    exact <- ctx$vec$feature(feature_id)
    scalar <- vapply(ctx$universe, function(id) {
      ctx$feature(id, "signal")
    }, numeric(1))
    bundle <- vapply(ctx$universe, function(id) {
      ctx$features(id)[["signal"]]
    }, numeric(1))
    signal <- ledgr_signal_feature(ctx, "signal")
    if (!identical(as.numeric(alias), as.numeric(exact)) ||
        !identical(as.numeric(alias), as.numeric(scalar)) ||
        !identical(as.numeric(alias), as.numeric(bundle)) ||
        !identical(as.numeric(alias), as.numeric(signal)) ||
        !identical(attr(signal, "origin"), "signal")) {
      stop("singular feature reads diverged")
    }
    ctx$flat()
  }
  experiment <- ledgr_experiment(
    snapshot,
    strategy,
    features = features,
    cost_model = ledgr_cost_zero()
  )
  run <- ledgr_run(
    experiment,
    params = list(n = 2L),
    feature_params = list(n = 2L),
    run_id = "feature-read-surface"
  )
  on.exit(close(run), add = TRUE)
  testthat::expect_s3_class(run, "ledgr_backtest")

  pulse <- ledgr_pulse_snapshot(
    snapshot,
    universe = c("AAA", "BBB"),
    ts_utc = max(bars$ts_utc),
    features = features,
    feature_params = list(n = 2L)
  )
  on.exit(close(pulse), add = TRUE)
  testthat::expect_identical(
    pulse$vec$feature("signal"),
    pulse$vec$feature("sma_2")
  )

  sweep_experiment <- ledgr_experiment(
    snapshot,
    function(ctx, params) {
      alias <- ctx$vec$feature("signal")
      scalar <- vapply(ctx$universe, function(id) {
        ctx$feature(id, "signal")
      }, numeric(1))
      bundle <- vapply(ctx$universe, function(id) {
        ctx$features(id)[["signal"]]
      }, numeric(1))
      if (!identical(as.numeric(alias), as.numeric(scalar)) ||
          !identical(as.numeric(alias), as.numeric(bundle))) {
        stop("candidate-local alias resolution diverged")
      }
      ctx$flat()
    },
    features = features,
    cost_model = ledgr_cost_zero()
  )
  sweep <- ledgr_sweep(
    sweep_experiment,
    ledgr_grid_cross(
      features = ledgr_feature_grid(n = c(2L, 3L)),
      strategy = ledgr_strategy_grid(unused = 1L)
    ),
    workers = 1L,
    seed = 1L
  )
  testthat::expect_true(all(sweep$status == "DONE"))
  maps <- attr(sweep, "candidate_features")$alias_map
  testthat::expect_true(any(vapply(maps, identical, logical(1), c(signal = "sma_2"))))
  testthat::expect_true(any(vapply(maps, identical, logical(1), c(signal = "sma_3"))))

  folds <- ledgr:::ledgr_fold_list(
    list(ledgr_fold(
      "2020-01-01", "2020-01-04", "2020-01-05", "2020-01-06",
      fold_seq = 1L
    )),
    constructor = list(type_id = "explicit")
  )
  walk_experiment <- ledgr_experiment(
    snapshot,
    function(ctx, params) {
      value <- ctx$vec$feature("signal")
      target <- ctx$flat()
      target[is.finite(value)] <- 1
      target
    },
    features = features,
    opening = ledgr_opening(cash = 10000),
    cost_model = ledgr_cost_zero()
  )
  walk_forward <- suppressWarnings(ledgr_walk_forward(
    walk_experiment,
    grid = ledgr_grid_cross(
      features = ledgr_feature_grid(n = c(2L, 3L)),
      strategy = ledgr_strategy_grid(unused = 1L)
    ),
    folds = folds,
    selection_rule = ledgr_rule_argmax("sharpe_ratio"),
    seed = 1L
  ))
  on.exit(lapply(walk_forward$test_runs, close), add = TRUE)
  testthat::expect_s3_class(walk_forward, "ledgr_walk_forward_results")
  testthat::expect_identical(walk_forward$folds$status, "DONE")
})
