strategy_context_entrance_fixture <- function(availability = FALSE,
                                              members = NULL,
                                              positions = NULL,
                                              restricted = NULL,
                                              priced = NULL,
                                              equity = 300) {
  ids <- if (isTRUE(availability)) c("AAA", "OLD") else c("AAA", "BBB")
  ts <- as.POSIXct("2026-01-02 21:00:00", tz = "UTC")
  bars <- data.frame(
    instrument_id = ids,
    ts_utc = rep(ts, length(ids)),
    open = c(10, 20),
    high = c(10, 20),
    low = c(10, 20),
    close = c(10, 20),
    volume = c(100, 100),
    stringsAsFactors = FALSE
  )
  features <- data.frame(
    instrument_id = ids,
    ts_utc = rep(ts, length(ids)),
    feature_name = rep("return_5", length(ids)),
    feature_value = c(0.2, 0.9),
    stringsAsFactors = FALSE
  )
  if (is.null(positions)) positions <- stats::setNames(numeric(), character())
  ctx <- ledgr:::ledgr_pulse_context(
    run_id = "entrance",
    ts_utc = ts,
    universe = ids,
    bars = bars,
    features = features,
    positions = positions,
    cash = equity,
    equity = equity
  )
  if (!isTRUE(availability)) return(ctx)

  if (is.null(members)) members <- "AAA"
  if (is.null(restricted)) restricted <- c(FALSE, TRUE)
  if (is.null(priced)) priced <- c(TRUE, TRUE)
  availability_view <- list(
    member = stats::setNames(ids %in% members, ids),
    held = stats::setNames(ctx$vec$position != 0, ids),
    target_restricted = stats::setNames(restricted, ids),
    target_restriction_reason = stats::setNames(c("", "nonmember"), ids),
    priced = stats::setNames(priced, ids),
    mark_age = stats::setNames(c(0L, 0L), ids),
    risk_mark = stats::setNames(c(10, 20), ids),
    mark_source = stats::setNames(c("current_close", "current_close"), ids)
  )
  ctx <- ledgr:::ledgr_update_pulse_context_helpers(
    ctx,
    bars = bars,
    features = features,
    positions = ctx$.positions,
    universe = ids,
    availability = availability_view
  )
  ctx$availability_active <- TRUE
  ctx$members <- members
  ctx
}

testthat::test_that("[LTB-0085] context entrances bind alignment and membership projection", {
  dense <- strategy_context_entrance_fixture()
  dense_target <- dense |>
    ledgr_selection() |>
    ledgr_weight_equal() |>
    ledgr_target_rebalance(dense)
  testthat::expect_identical(unclass(dense_target), c(AAA = 15, BBB = 7))

  score_target <- dense |>
    ledgr_signal(values = dense$vec$feature("return_5")) |>
    ledgr_select_top_n(1) |>
    ledgr_weight_equal() |>
    ledgr_target_rebalance(dense)
  testthat::expect_identical(unclass(score_target), c(AAA = 0, BBB = 15))

  named <- ledgr_signal(dense, values = c(BBB = 0.9, AAA = 0.2))
  positional <- ledgr_signal(dense, values = c(0.2, 0.9))
  testthat::expect_identical(named, positional)

  available <- strategy_context_entrance_fixture(
    availability = TRUE,
    positions = c(OLD = 2),
    equity = 100
  )
  full <- available |>
    ledgr_selection() |>
    ledgr_weight_equal() |>
    ledgr_target_rebalance(available)
  partial <- ledgr_target_rebalance(
    ledgr_weight_equal(ledgr_selection(available)),
    available,
    equity_fraction = 0.6
  )
  none <- available |>
    ledgr_selection(ids = character()) |>
    ledgr_weight_equal() |>
    ledgr_target_rebalance(available)
  testthat::expect_identical(unclass(full), c(AAA = 6, OLD = 2))
  testthat::expect_identical(unclass(partial), c(AAA = 3, OLD = 2))
  testthat::expect_identical(unclass(none), c(AAA = 0, OLD = 2))

  projected <- lapply(
    list(c(TRUE, TRUE), c(TRUE, FALSE), c(TRUE, NA)),
    function(where) ledgr_selection(available, where = where)
  )
  named_projected <- lapply(
    list(c(OLD = TRUE, AAA = TRUE), c(OLD = FALSE, AAA = TRUE),
         c(OLD = NA, AAA = TRUE)),
    function(where) ledgr_selection(available, where = where)
  )
  testthat::expect_true(all(vapply(
    projected,
    function(x) identical(unclass(x), c(AAA = TRUE)),
    logical(1)
  )))
  testthat::expect_identical(projected, named_projected)
  projected_targets <- lapply(projected, function(selection) {
    ledgr_target_rebalance(ledgr_weight_equal(selection), available)
  })
  testthat::expect_true(all(vapply(
    projected_targets,
    function(x) identical(unclass(x), c(AAA = 6, OLD = 2)),
    logical(1)
  )))
  testthat::expect_error(
    ledgr_selection(available, where = c(NA, FALSE)),
    class = "ledgr_invalid_strategy_type"
  )
  testthat::expect_error(
    ledgr_selection(available, ids = "OLD"),
    class = "ledgr_invalid_strategy_helper"
  )

  ranked <- ledgr_signal(available, values = c(AAA = 1, OLD = 999)) |>
    ledgr_select_top_n(1)
  testthat::expect_identical(unclass(ranked), c(AAA = TRUE))

  empty_members <- strategy_context_entrance_fixture(
    availability = TRUE,
    members = character(),
    positions = c(OLD = 2),
    equity = 100
  )
  empty_selection <- ledgr_selection(empty_members, where = c(FALSE, TRUE))
  testthat::expect_s3_class(empty_selection, "ledgr_selection")
  testthat::expect_length(empty_selection, 0L)
})

testthat::test_that("[LTB-0086] context payload failures are classed before projection", {
  ctx <- strategy_context_entrance_fixture(
    availability = TRUE,
    positions = c(OLD = 2),
    equity = 100
  )
  helper_error <- function(expr) {
    testthat::expect_error(expr, class = "ledgr_invalid_strategy_helper")
  }
  type_error <- function(expr) {
    testthat::expect_error(expr, class = "ledgr_invalid_strategy_type")
  }

  helper_error(ledgr_signal(ctx))
  helper_error(ledgr_selection(ctx, ids = "AAA", where = c(TRUE, FALSE)))
  helper_error(ledgr_signal(ctx, values = NULL))
  helper_error(ledgr_signal(c(AAA = 1), values = c(AAA = 1)))
  helper_error(ledgr_signal(ctx, universe = NULL, values = c(1, 2)))
  helper_error(ledgr_selection(ctx, values = c(TRUE, FALSE)))

  type_error(ledgr_signal(ctx, values = c(AAA = 1, ZZZ = 2)))
  type_error(ledgr_signal(ctx, values = c(AAA = 1, AAA = 2)))
  type_error(ledgr_signal(ctx, values = c(OLD = 2)))
  type_error(ledgr_signal(ctx, values = c(AAA = 1, OLD = Inf)))
  type_error(ledgr_signal(ctx, values = matrix(c(1, 2), ncol = 1)))
  type_error(ledgr_signal(ctx, values = list(1, 2)))
  type_error(ledgr_signal(ctx, values = factor(c("1", "2"))))
  type_error(ledgr_selection(ctx, where = c(TRUE)))
  type_error(ledgr_selection(ctx, ids = "ZZZ"))

  malformed <- structure(
    list(universe = c("AAA", "OLD")),
    class = "ledgr_pulse_context"
  )
  helper_error(ledgr_selection(malformed))
})

testthat::test_that("[LTB-0087] raw and convenience signals keep distinct policies", {
  ctx <- strategy_context_entrance_fixture(
    availability = TRUE,
    positions = c(AAA = 4, OLD = 2),
    restricted = c(TRUE, TRUE),
    priced = c(FALSE, TRUE),
    equity = 140
  )
  raw <- ledgr_signal(ctx, values = ctx$vec$feature("return_5"))
  convenience <- ledgr_signal_return(ctx, lookback = 5)
  testthat::expect_identical(unclass(raw), c(AAA = 0.2))
  testthat::expect_identical(
    stats::setNames(as.numeric(convenience), names(convenience)),
    c(AAA = NA_real_)
  )

  missing_scores <- ledgr_signal(ctx, values = c(AAA = NA_real_, OLD = 9)) |>
    ledgr_select_top_n(1) |>
    ledgr_weight_equal() |>
    ledgr_target_rebalance(ctx)
  guarded <- ctx$hold()
  testthat::expect_identical(unclass(missing_scores), c(AAA = 0, OLD = 2))
  testthat::expect_identical(guarded, c(AAA = 4, OLD = 2))
})
