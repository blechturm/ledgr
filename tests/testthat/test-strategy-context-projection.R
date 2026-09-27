strategy_context_projection_capture <- function(ctx, params) {
  previous <- ctx$state_prev$history
  if (is.null(previous)) previous <- character()
  previous_exposure <- ctx$state_prev$projection_exposed
  if (is.null(previous_exposure)) previous_exposure <- logical()
  retired_names <- c(
    ".feature_projection", ".feature_pulse_idx", ".feature_ids"
  )
  context_values <- unclass(ctx)
  exposed_value <- function(value) {
    !is.function(value) && inherits(value, "ledgr_runtime_projection")
  }
  exposed_container <- function(value) {
    if (is.function(value)) return(FALSE)
    nested <- if (is.environment(value)) {
      as.list.environment(value, all.names = TRUE)
    } else if (is.list(value)) {
      unclass(value)
    } else {
      return(FALSE)
    }
    any(c(
      retired_names %in% names(nested),
      vapply(nested, exposed_value, logical(1))
    ))
  }
  projection_exposed <- any(c(
    retired_names %in% names(context_values),
    vapply(context_values, exposed_value, logical(1)),
    vapply(context_values, exposed_container, logical(1))
  ))
  scalar <- ctx$feature("AAA", "sma_2")
  plane <- ctx$vec$feature("sma_2")[[1L]]
  bundle <- ctx$features("AAA")[["signal"]]
  encode <- function(value) {
    if (is.na(value)) "NA" else format(value, digits = 17, trim = TRUE)
  }
  entry <- paste(vapply(c(scalar, plane, bundle), encode, character(1)),
                 collapse = "|")
  list(
    targets = ctx$hold(),
    state_update = list(
      history = c(as.character(previous), entry),
      projection_exposed = c(previous_exposure, projection_exposed)
    )
  )
}

testthat::test_that("[LTB-0089] strategy contexts expose only current feature values", {
  pulses <- as.POSIXct("2026-01-01", tz = "UTC") + 86400 * 0:2
  projection <- ledgr:::ledgr_runtime_projection(
    feature_values = list(
      signal = matrix(c(NA, NA, 11, 21, 12, 22), nrow = 2L)
    ),
    universe = c("AAA", "BBB"),
    pulses_posix = pulses
  )
  bars <- data.frame(
    instrument_id = c("AAA", "BBB"),
    ts_utc = rep(pulses[[1L]], 2L),
    open = c(10, 20), high = c(10, 20), low = c(10, 20),
    close = c(10, 20), volume = c(100, 100),
    stringsAsFactors = FALSE
  )
  ctx <- ledgr:::ledgr_pulse_context(
    "bounded", pulses[[1L]], c("AAA", "BBB"), bars,
    cash = 100, equity = 100
  )
  ctx <- ledgr:::ledgr_update_pulse_context_helpers(
    ctx,
    bars = bars,
    features = ledgr:::ledgr_projection_feature_table_schema(),
    universe = c("AAA", "BBB"),
    projection = projection,
    pulse_idx = 1L,
    feature_ids = "signal"
  )

  testthat::expect_null(ctx$.feature_projection)
  testthat::expect_null(ctx$.feature_pulse_idx)
  testthat::expect_null(ctx$.feature_ids)
  testthat::expect_false(any(vapply(
    unclass(ctx),
    function(value) inherits(value, "ledgr_runtime_projection"),
    logical(1)
  )))
  testthat::expect_true(is.function(ctx$.feature_table_current))
  testthat::expect_identical(ctx$feature("AAA", "signal"), NA_real_)
  testthat::expect_identical(ctx$vec$feature("signal"), c(NA_real_, NA_real_))
  first_table <- ledgr_pulse_features(ctx)
  testthat::expect_true(all(first_table$ts_utc == pulses[[1L]]))
  testthat::expect_equal(first_table$feature_value, c(NA_real_, NA_real_))
  testthat::expect_error(
    ctx$feature("AAA", "future_signal"),
    class = "ledgr_unknown_feature_id"
  )

  second_bars <- bars
  second_bars$ts_utc <- pulses[[2L]]
  second <- ledgr:::ledgr_update_pulse_context_helpers(
    ctx,
    bars = second_bars,
    features = ledgr:::ledgr_projection_feature_table_schema(),
    universe = c("AAA", "BBB"),
    projection = projection,
    pulse_idx = 2L,
    feature_ids = "signal"
  )
  testthat::expect_identical(second$vec$feature("signal"), c(11, 21))
  second_table <- ledgr_pulse_features(second)
  testthat::expect_true(all(second_table$ts_utc == pulses[[2L]]))
  testthat::expect_equal(second_table$feature_value, c(11, 21))

  filtered <- ledgr:::ledgr_filter_pulse_context_features(
    second,
    universe = "AAA",
    private_universe = c("AAA", "BBB")
  )
  filtered_table <- ledgr_pulse_features(filtered)
  testthat::expect_identical(unique(filtered_table$instrument_id), "AAA")

  dates <- as.Date("2026-01-01") + 0:4
  dense_bars <- data.frame(
    ts_utc = as.POSIXct(paste(dates, "21:00:00"), tz = "UTC"),
    instrument_id = "AAA",
    open = 101:105, high = 101:105, low = 101:105,
    close = 101:105, volume = 1000,
    stringsAsFactors = FALSE
  )
  dense_snapshot <- ledgr_snapshot_from_df(dense_bars)
  availability_snapshot <- availability_runtime_fixture(days = 5L)
  on.exit(ledgr_snapshot_close(dense_snapshot), add = TRUE)
  on.exit(ledgr_snapshot_close(availability_snapshot), add = TRUE)
  features <- ledgr_feature_map(signal = ledgr_ind_sma(2))
  dense_run <- ledgr_run(ledgr_experiment(
    dense_snapshot,
    strategy_context_projection_capture,
    features = features,
    cost_model = ledgr_cost_zero()
  ))
  availability_run <- ledgr_run(ledgr_experiment(
    availability_snapshot,
    strategy_context_projection_capture,
    features = features,
    valuation_policy = ledgr_valuation_stale(1),
    cost_model = ledgr_cost_zero()
  ))
  on.exit(close(dense_run), add = TRUE)
  on.exit(close(availability_run), add = TRUE)
  expected <- c(
    "NA|NA|NA", "101.5|101.5|101.5", "102.5|102.5|102.5",
    "103.5|103.5|103.5", "104.5|104.5|104.5"
  )
  dense_state <- availability_last_state(dense_run)
  availability_state <- availability_last_state(availability_run)
  testthat::expect_identical(dense_state$history, expected)
  testthat::expect_identical(
    availability_state$history,
    expected
  )
  testthat::expect_identical(
    dense_state$projection_exposed,
    rep(FALSE, length(expected))
  )
  testthat::expect_identical(
    availability_state$projection_exposed,
    rep(FALSE, length(expected))
  )
})
