stage_m_axis <- function(n = 4L) {
  as.POSIXct("2020-01-01 16:00:00", tz = "UTC") +
    seq.int(0, length.out = n) * 86400
}

stage_m_bars <- function(axis) {
  data.frame(ts_utc = axis)
}

stage_m_replace_instant <- function(axis, position, value) {
  instants <- as.numeric(axis)
  instants[[position]] <- value
  structure(instants, class = c("POSIXct", "POSIXt"), tzone = "UTC")
}

stage_m_vector_timestamp_source <- function(fn) {
  source <- paste(deparse(body(fn), width.cutoff = 500L), collapse = "\n")
  forbidden <- c(
    "vapply(",
    "sapply(",
    "format.POSIXct(",
    "ledgr_normalize_ts_utc(",
    "ledgr_iso_utc("
  )
  !any(vapply(forbidden, grepl, logical(1L), x = source, fixed = TRUE))
}

testthat::test_that("dense timestamp keys use primitive whole-second instants", {
  axis <- stage_m_axis()
  other_tz <- structure(
    as.numeric(axis),
    class = c("POSIXct", "POSIXt"),
    tzone = "America/New_York"
  )
  dates <- as.Date("2020-01-01") + 0:3
  midnight <- as.POSIXct(dates, tz = "UTC")
  duplicate <- axis[c(1L, 2L, 2L, 4L)]

  testthat::expect_identical(
    ledgr:::ledgr_precompute_ts_key(axis),
    as.numeric(axis)
  )
  testthat::expect_identical(
    ledgr:::ledgr_precompute_ts_key(other_tz),
    as.numeric(axis)
  )
  testthat::expect_identical(
    ledgr:::ledgr_precompute_ts_key(dates),
    as.numeric(midnight)
  )
  testthat::expect_identical(
    ledgr:::ledgr_precompute_ts_key(duplicate),
    as.numeric(duplicate)
  )
})

testthat::test_that("dense coverage preserves the supported semantic matrix", {
  axis <- stage_m_axis()
  one <- list(A = stage_m_bars(axis))
  many <- list(A = stage_m_bars(axis), B = stage_m_bars(axis))
  duplicate <- axis[c(1L, 2L, 2L, 4L)]
  reordered <- axis[c(2L, 1L, 3L, 4L)]

  testthat::expect_identical(
    ledgr:::ledgr_precompute_validate_static_coverage(one, "A"),
    ledgr_stage_l_validate_static_coverage_oracle(one, "A")
  )
  testthat::expect_identical(
    ledgr:::ledgr_precompute_validate_static_coverage(many, c("A", "B")),
    ledgr_stage_l_validate_static_coverage_oracle(many, c("A", "B"))
  )
  testthat::expect_silent(ledgr:::ledgr_precompute_validate_static_coverage(
    list(A = stage_m_bars(duplicate), B = stage_m_bars(duplicate)),
    c("A", "B")
  ))
  testthat::expect_silent(ledgr:::ledgr_precompute_validate_static_coverage(
    list(A = stage_m_bars(reordered), B = stage_m_bars(reordered)),
    c("A", "B")
  ))

  timezone_axis <- structure(
    as.numeric(axis),
    class = c("POSIXct", "POSIXt"),
    tzone = "America/New_York"
  )
  testthat::expect_silent(ledgr:::ledgr_precompute_validate_static_coverage(
    list(A = stage_m_bars(axis), B = stage_m_bars(timezone_axis)),
    c("A", "B")
  ))
  date_axis <- as.Date("2020-01-01") + 0:3
  testthat::expect_silent(ledgr:::ledgr_precompute_validate_static_coverage(
    list(
      A = stage_m_bars(date_axis),
      B = stage_m_bars(as.POSIXct(date_axis, tz = "UTC"))
    ),
    c("A", "B")
  ))

  for (position in seq_along(axis)) {
    changed <- axis
    changed[[position]] <- changed[[position]] + 1
    testthat::expect_error(
      ledgr:::ledgr_precompute_validate_static_coverage(
        list(A = stage_m_bars(axis), B = stage_m_bars(changed)),
        c("A", "B")
      ),
      class = "ledgr_precomputed_coverage_error"
    )
  }
  testthat::expect_error(
    ledgr:::ledgr_precompute_validate_static_coverage(one, c("A", "B")),
    class = "ledgr_precomputed_coverage_error"
  )
  testthat::expect_error(
    ledgr:::ledgr_precompute_validate_static_coverage(
      list(A = stage_m_bars(axis), B = stage_m_bars(axis[FALSE])),
      c("A", "B")
    ),
    class = "ledgr_precomputed_coverage_error"
  )
  testthat::expect_error(
    ledgr:::ledgr_precompute_validate_static_coverage(
      list(A = stage_m_bars(axis), B = stage_m_bars(axis[-1L])),
      c("A", "B")
    ),
    class = "ledgr_precomputed_coverage_error"
  )
  testthat::expect_error(
    ledgr:::ledgr_precompute_validate_static_coverage(
      list(A = stage_m_bars(axis), B = stage_m_bars(rev(axis))),
      c("A", "B")
    ),
    class = "ledgr_precomputed_coverage_error"
  )
})

testthat::test_that("dense coverage fails closed on invalid primitive instants", {
  axis <- stage_m_axis()
  invalid_values <- list(NA_real_, NaN, Inf, -Inf)
  for (value in invalid_values) {
    invalid <- stage_m_replace_instant(axis, 2L, value)
    testthat::expect_error(
      ledgr:::ledgr_precompute_validate_static_coverage(
        list(A = stage_m_bars(axis), B = stage_m_bars(invalid)),
        c("A", "B")
      ),
      regexp = "non-missing finite",
      class = "ledgr_invalid_pulse_context"
    )
  }

  both_missing <- stage_m_replace_instant(axis, 2L, NA_real_)
  testthat::expect_error(
    ledgr:::ledgr_precompute_validate_static_coverage(
      list(A = stage_m_bars(both_missing), B = stage_m_bars(both_missing)),
      c("A", "B")
    ),
    class = "ledgr_invalid_pulse_context"
  )

  different_missing <- stage_m_replace_instant(axis, 3L, NA_real_)
  testthat::expect_error(
    ledgr:::ledgr_precompute_validate_static_coverage(
      list(A = stage_m_bars(both_missing), B = stage_m_bars(different_missing)),
      c("A", "B")
    ),
    class = "ledgr_invalid_pulse_context"
  )

  subsecond_a <- stage_m_replace_instant(
    axis,
    2L,
    as.numeric(axis)[[2L]] + 0.25
  )
  subsecond_b <- stage_m_replace_instant(
    axis,
    2L,
    as.numeric(axis)[[2L]] + 0.25
  )
  testthat::expect_error(
    ledgr:::ledgr_precompute_validate_static_coverage(
      list(A = stage_m_bars(subsecond_a), B = stage_m_bars(subsecond_b)),
      c("A", "B")
    ),
    regexp = "whole-second",
    class = "ledgr_invalid_pulse_context"
  )
  subsecond_b <- stage_m_replace_instant(
    axis,
    2L,
    as.numeric(axis)[[2L]] + 0.5
  )
  testthat::expect_error(
    ledgr:::ledgr_precompute_validate_static_coverage(
      list(A = stage_m_bars(subsecond_a), B = stage_m_bars(subsecond_b)),
      c("A", "B")
    ),
    class = "ledgr_invalid_pulse_context"
  )
})

testthat::test_that("dense validation has one vector conversion per axis", {
  key <- ledgr:::ledgr_precompute_ts_key
  validator <- ledgr:::ledgr_precompute_validate_static_coverage
  mutant <- function(x) {
    vapply(
      as.POSIXct(x, tz = "UTC"),
      ledgr_normalize_ts_utc,
      character(1L)
    )
  }
  testthat::expect_true(stage_m_vector_timestamp_source(key))
  testthat::expect_true(stage_m_vector_timestamp_source(validator))
  testthat::expect_false(stage_m_vector_timestamp_source(mutant))

  calls <- new.env(parent = emptyenv())
  calls$key_lengths <- integer()
  calls$formatter <- 0L
  axis <- stage_m_axis()
  bars <- list(
    A = stage_m_bars(axis),
    B = stage_m_bars(axis),
    C = stage_m_bars(axis)
  )
  original_normalizer <- ledgr:::ledgr_normalize_ts_utc
  testthat::local_mocked_bindings(
    ledgr_precompute_ts_key = function(x) {
      calls$key_lengths <- c(calls$key_lengths, length(x))
      key(x)
    },
    ledgr_normalize_ts_utc = function(x) {
      calls$formatter <- calls$formatter + 1L
      original_normalizer(x)
    },
    .package = "ledgr"
  )

  testthat::expect_silent(
    ledgr:::ledgr_precompute_validate_static_coverage(bars, names(bars))
  )
  testthat::expect_identical(calls$key_lengths, rep(length(axis), 3L))
  testthat::expect_identical(calls$formatter, 0L)
})

testthat::test_that("dense public consumers use the primitive validator", {
  bars <- ledgr_test_make_bars(
    c("AAA", "BBB"),
    as.Date("2020-01-01") + 0:7
  )
  snapshot <- ledgr_snapshot_from_df(bars)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  exp <- ledgr_experiment(
    snapshot,
    function(ctx, params) ctx$flat(),
    universe = c("AAA", "BBB"),
    features = list(ledgr_ind_sma(2)),
    cost_model = ledgr_cost_zero()
  )
  grid <- ledgr_param_grid(only = list())

  testthat::expect_s3_class(
    ledgr_precompute_features(exp, grid),
    "ledgr_precomputed_features"
  )
  testthat::expect_s3_class(
    ledgr_sweep(exp, grid, seed = 2742L),
    "ledgr_sweep_results"
  )
  testthat::expect_s3_class(
    ledgr:::ledgr_experiment_window(exp, "2020-01-02", "2020-01-06"),
    "ledgr_experiment_window"
  )

  walk_forward_exp <- ledgr_experiment(
    snapshot,
    function(ctx, params) {
      target <- ctx$flat()
      target[["AAA"]] <- params$quantity
      target
    },
    universe = c("AAA", "BBB"),
    features = list(ledgr_ind_sma(2)),
    cost_model = ledgr_cost_zero()
  )
  folds <- ledgr:::ledgr_fold_list(
    list(ledgr_fold(
      "2020-01-01",
      "2020-01-04",
      "2020-01-05",
      "2020-01-07"
    )),
    constructor = list(type_id = "explicit")
  )
  walk_forward <- ledgr_walk_forward(
    walk_forward_exp,
    grid = ledgr_param_grid(one = list(quantity = 1)),
    folds = folds,
    selection_rule = ledgr_select_argmax("sharpe_ratio"),
    seed = 2742L
  )
  on.exit(lapply(walk_forward$test_runs, close), add = TRUE)
  testthat::expect_s3_class(
    walk_forward,
    "ledgr_walk_forward_results"
  )
})

testthat::test_that("availability consumers bypass dense timestamp validation", {
  snapshot <- availability_runtime_fixture(days = 4L)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  exp <- ledgr_experiment(
    snapshot,
    function(ctx, params) ctx$flat(),
    valuation_policy = ledgr_valuation_stale(0),
    cost_model = ledgr_cost_zero()
  )
  testthat::local_mocked_bindings(
    ledgr_precompute_validate_static_coverage = function(...) {
      rlang::abort(
        "Availability entered the dense validator.",
        class = "ledgr_test_dense_validator_reached"
      )
    },
    .package = "ledgr"
  )

  testthat::expect_s3_class(
    ledgr_sweep(
      exp,
      ledgr_param_grid(only = list()),
      seed = 2742L
    ),
    "ledgr_sweep_results"
  )
  testthat::expect_s3_class(
    ledgr:::ledgr_experiment_window(exp, "2020-01-02", "2020-01-04"),
    "ledgr_experiment_window"
  )
})
