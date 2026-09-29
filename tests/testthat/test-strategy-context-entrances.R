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

testthat::test_that("[LTB-0085] context entrances bind alignment and eligibility over the axis", {
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
    function(x) identical(unclass(x), c(AAA = TRUE, OLD = FALSE)),
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
  testthat::expect_identical(
    unclass(ledgr_selection(available, ids = "OLD")),
    c(AAA = FALSE, OLD = FALSE)
  )
  testthat::expect_error(
    ledgr_selection(available, ids = "ZZZ"),
    class = "ledgr_invalid_strategy_type"
  )

  ranked <- ledgr_signal(available, values = c(AAA = 1, OLD = 999)) |>
    ledgr_select_top_n(1)
  testthat::expect_identical(unclass(ranked), c(AAA = TRUE, OLD = FALSE))

  empty_members <- strategy_context_entrance_fixture(
    availability = TRUE,
    members = character(),
    positions = c(OLD = 2),
    equity = 100
  )
  empty_selection <- ledgr_selection(empty_members, where = c(FALSE, TRUE))
  testthat::expect_s3_class(empty_selection, "ledgr_selection")
  testthat::expect_identical(unclass(empty_selection), c(AAA = FALSE, OLD = FALSE))
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

testthat::test_that("[LTB-0087] raw and convenience signals share raw values and eligibility", {
  ctx <- strategy_context_entrance_fixture(
    availability = TRUE,
    positions = c(AAA = 4, OLD = 2),
    restricted = c(TRUE, TRUE),
    priced = c(FALSE, TRUE),
    equity = 140
  )
  raw <- ledgr_signal(ctx, values = ctx$vec$feature("return_5"))
  convenience <- ledgr_signal_return(ctx, lookback = 5)
  for (signal in list(raw, convenience)) {
    testthat::expect_identical(
      stats::setNames(as.numeric(signal), names(signal)),
      c(AAA = 0.2, OLD = 0.9)
    )
    testthat::expect_identical(attr(signal, "eligible"), c(FALSE, FALSE))
  }

  missing_scores <- ledgr_signal(ctx, values = c(AAA = NA_real_, OLD = 9)) |>
    ledgr_select_top_n(1) |>
    ledgr_weight_equal() |>
    ledgr_target_rebalance(ctx)
  guarded <- ctx$hold()
  testthat::expect_identical(unclass(missing_scores), c(AAA = 4, OLD = 2))
  testthat::expect_identical(guarded, c(AAA = 4, OLD = 2))
})

testthat::test_that("[LTB-0095] feature signals carry the admissibility plane", {
  restricted <- strategy_context_entrance_fixture(
    availability = TRUE,
    members = c("AAA", "OLD"),
    restricted = c(TRUE, FALSE),
    priced = c(TRUE, TRUE)
  )
  feature <- ledgr_signal_feature(restricted, "return_5")
  raw <- ledgr_signal(
    restricted,
    values = restricted$vec$feature("return_5")
  )
  testthat::expect_identical(
    stats::setNames(as.numeric(feature), names(feature)),
    c(AAA = 0.2, OLD = 0.9)
  )
  testthat::expect_identical(attr(feature, "eligible"), c(FALSE, TRUE))
  testthat::expect_identical(stats::setNames(as.numeric(raw), names(raw)), c(AAA = 0.2, OLD = 0.9))
  testthat::expect_identical(attr(raw, "eligible"), c(FALSE, TRUE))

  unpriced <- strategy_context_entrance_fixture(
    availability = TRUE,
    members = c("AAA", "OLD"),
    restricted = c(FALSE, FALSE),
    priced = c(FALSE, TRUE)
  )
  unpriced_signal <- ledgr_signal_feature(unpriced, "return_5")
  testthat::expect_identical(
    stats::setNames(as.numeric(unpriced_signal), names(unpriced_signal)),
    c(AAA = 0.2, OLD = 0.9)
  )

  dense <- strategy_context_entrance_fixture()
  testthat::expect_identical(
    ledgr_signal_return(dense, lookback = 5),
    ledgr_signal_feature(dense, "return_5")
  )
  testthat::expect_identical(
    ledgr_signal_return(restricted, lookback = 5),
    ledgr_signal_feature(restricted, "return_5")
  )
  testthat::expect_error(
    ledgr_signal_feature(dense, "unknown_feature"),
    class = "ledgr_unknown_feature_id"
  )

  empty <- strategy_context_entrance_fixture(
    availability = TRUE,
    members = character()
  )
  signal <- ledgr_signal_feature(empty, "return_5")
  testthat::expect_s3_class(signal, "ledgr_signal")
  testthat::expect_identical(stats::setNames(as.numeric(signal), names(signal)), c(AAA = 0.2, OLD = 0.9))
  testthat::expect_identical(attr(signal, "eligible"), c(FALSE, FALSE))
  testthat::expect_identical(attr(signal, "origin"), "return_5")

  validation_calls <- 0L
  original_validate <- ledgr:::ledgr_validate_strategy_helper_ctx
  testthat::local_mocked_bindings(
    ledgr_validate_strategy_helper_ctx = function(ctx, helper) {
      validation_calls <<- validation_calls + 1L
      original_validate(ctx, helper)
    },
    .package = "ledgr"
  )
  ledgr_signal_return(dense, lookback = 5)
  testthat::expect_identical(validation_calls, 1L)
})

testthat::test_that("[LTB-0088] explicit zero weights never require sizing prices", {
  dense <- strategy_context_entrance_fixture(equity = 100)
  dense$vec$close[[2L]] <- NA_real_
  with_zero <- testthat::expect_no_warning(ledgr_target_rebalance(
    ledgr_weights(c(AAA = 1, BBB = 0), universe = dense$universe),
    dense
  ))
  omitted <- testthat::expect_no_warning(ledgr_target_rebalance(
    ledgr_weights(c(AAA = 1), universe = dense$universe),
    dense
  ))
  testthat::expect_identical(with_zero, omitted)
  testthat::expect_identical(unclass(with_zero), c(AAA = 10, BBB = 0))
  testthat::expect_warning(
    positive_dense <- ledgr_target_rebalance(
      ledgr_weights(c(AAA = 0.5, BBB = 0.5), universe = dense$universe),
      dense
    ),
    class = "ledgr_invalid_target_price"
  )
  testthat::expect_identical(unclass(positive_dense), c(AAA = 5, BBB = 0))

  available <- strategy_context_entrance_fixture(
    availability = TRUE,
    members = c("AAA", "OLD"),
    positions = c(OLD = 2),
    restricted = c(FALSE, FALSE),
    equity = 100
  )
  available$vec$close[[2L]] <- NA_real_
  available_zero <- testthat::expect_no_condition(ledgr_target_rebalance(
    ledgr_weights(c(AAA = 1, OLD = 0), universe = available$universe),
    available
  ))
  available_omitted <- testthat::expect_no_condition(ledgr_target_rebalance(
    ledgr_weights(c(AAA = 1), universe = available$universe),
    available
  ))
  testthat::expect_identical(available_zero, available_omitted)
  testthat::expect_identical(unclass(available_zero), c(AAA = 10, OLD = 0))
  testthat::expect_error(
    ledgr_target_rebalance(
      ledgr_weights(c(AAA = 0.5, OLD = 0.5), universe = available$universe),
      available
    ),
    class = "ledgr_target_sizing_unavailable"
  )

  nonmember <- strategy_context_entrance_fixture(
    availability = TRUE,
    positions = c(OLD = 2),
    equity = 100
  )
  testthat::expect_error(
    ledgr_target_rebalance(ledgr_weights(c(OLD = 0)), nonmember),
    class = "ledgr_invalid_strategy_helper"
  )
})

testthat::test_that("[LTB-0097] rebalance reserves explicitly kept positions", {
  legacy_ctx <- list(
    universe = c("AAA", "BBB"),
    equity = 1000,
    vec = list(close = c(AAA = 50, BBB = 100))
  )
  legacy_weights <- ledgr_weights(
    c(AAA = 0.5, BBB = 0.5),
    universe = legacy_ctx$universe
  )
  testthat::expect_identical(
    unclass(ledgr_target_rebalance(
      legacy_weights,
      legacy_ctx,
      equity_fraction = 0.5
    )),
    c(AAA = 5, BBB = 2)
  )
  no_position_read <- legacy_ctx
  no_position_read$vec <- new.env(parent = emptyenv())
  no_position_read$vec$close <- legacy_ctx$vec$close
  makeActiveBinding(
    "position",
    function(value) {
      rlang::abort("dense sizing without keep must not read positions")
    },
    no_position_read$vec
  )
  testthat::expect_identical(
    unclass(ledgr_target_rebalance(
      legacy_weights,
      no_position_read,
      equity_fraction = 0.5
    )),
    c(AAA = 5, BBB = 2)
  )
  testthat::expect_error(
    ledgr_target_rebalance(
      ledgr_weights(c(BBB = 1), universe = legacy_ctx$universe),
      legacy_ctx,
      keep = "AAA"
    ),
    class = "ledgr_invalid_strategy_helper"
  )

  dense <- strategy_context_entrance_fixture(
    positions = c(AAA = 4),
    equity = 100
  )
  dense$vec$close[[2L]] <- 10
  weights <- ledgr_weights(c(BBB = 1), universe = dense$universe)

  kept <- ledgr_target_rebalance(weights, dense, keep = "AAA")
  half <- ledgr_target_rebalance(
    weights,
    dense,
    equity_fraction = 0.5,
    keep = "AAA"
  )
  testthat::expect_identical(unclass(kept), c(AAA = 4, BBB = 6))
  testthat::expect_identical(unclass(half), c(AAA = 4, BBB = 3))

  baseline <- ledgr_target_rebalance(weights, dense)
  testthat::expect_identical(
    ledgr_target_rebalance(weights, dense, keep = NULL),
    baseline
  )
  testthat::expect_identical(
    ledgr_target_rebalance(weights, dense, keep = character()),
    baseline
  )

  available <- strategy_context_entrance_fixture(
    availability = TRUE,
    positions = c(OLD = 2),
    equity = 100
  )
  member_weights <- ledgr_weights(c(AAA = 1), universe = available$universe)
  testthat::expect_identical(
    ledgr_target_rebalance(member_weights, available, keep = "OLD"),
    ledgr_target_rebalance(member_weights, available)
  )

  testthat::expect_error(
    ledgr_target_rebalance(
      ledgr_weights(c(AAA = 0, BBB = 1), universe = dense$universe),
      dense,
      keep = "AAA"
    ),
    regexp = "both `keep` and `weights`",
    class = "ledgr_invalid_strategy_helper"
  )
  for (invalid_keep in list("ZZZ", c("AAA", "AAA"), NA_character_)) {
    testthat::expect_error(
      ledgr_target_rebalance(weights, dense, keep = invalid_keep),
      class = "ledgr_invalid_strategy_helper"
    )
  }

  unavailable <- strategy_context_entrance_fixture(
    positions = c(AAA = 4),
    equity = 100
  )
  unavailable$vec$close[[1L]] <- NA_real_
  testthat::expect_error(
    ledgr_target_rebalance(weights, unavailable, keep = "AAA"),
    class = "ledgr_target_sizing_unavailable"
  )
})

testthat::test_that("[LTB-0098] missing selection decisions require an explicit policy", {
  ids <- c("AAA", "BBB", "CCC")
  ts <- as.POSIXct("2026-01-02 21:00:00", tz = "UTC")
  bars <- data.frame(
    instrument_id = ids,
    ts_utc = rep(ts, length(ids)),
    open = c(10, 20, 30),
    high = c(10, 20, 30),
    low = c(10, 20, 30),
    close = c(10, 20, 30),
    volume = c(100, 100, 100),
    stringsAsFactors = FALSE
  )
  ctx <- ledgr:::ledgr_pulse_context(
    run_id = "missing-decisions",
    ts_utc = ts,
    universe = ids,
    bars = bars,
    features = ledgr:::ledgr_projection_feature_table_schema(),
    positions = c(AAA = 2),
    cash = 80,
    equity = 100
  )
  expected <- c(AAA = TRUE, BBB = FALSE, CCC = FALSE)

  named <- ledgr_selection(
    ctx,
    where = c(CCC = NA, BBB = FALSE, AAA = TRUE),
    missing = "exclude"
  )
  positional <- ledgr_selection(
    ctx,
    where = c(TRUE, FALSE, NA),
    missing = "exclude"
  )
  testthat::expect_identical(unclass(named), expected)
  testthat::expect_identical(named, positional)

  strict <- tryCatch(
    ledgr_selection(ctx, where = c(TRUE, FALSE, NA)),
    error = identity
  )
  testthat::expect_s3_class(strict, "ledgr_invalid_strategy_type")
  testthat::expect_match(
    conditionMessage(strict),
    "`where` contains missing decisions for current members: CCC.",
    fixed = TRUE
  )
  testthat::expect_match(conditionMessage(strict), 'missing = "exclude"', fixed = TRUE)
  testthat::expect_match(conditionMessage(strict), "targets those instruments to zero", fixed = TRUE)

  available <- strategy_context_entrance_fixture(
    availability = TRUE,
    positions = c(OLD = 2),
    equity = 100
  )
  nonmember_missing <- c(OLD = NA, AAA = TRUE)
  testthat::expect_identical(
    ledgr_selection(available, where = nonmember_missing),
    ledgr_selection(
      available,
      where = nonmember_missing,
      missing = "exclude"
    )
  )
  testthat::expect_identical(
    unclass(ledgr_selection(available, where = c(TRUE, NA))),
    c(AAA = TRUE, OLD = FALSE)
  )

  testthat::expect_error(
    ledgr_selection(c(AAA = NA)),
    class = "ledgr_invalid_strategy_type"
  )
  testthat::expect_error(
    ledgr_selection(c(AAA = TRUE), missing = "exclude"),
    class = "ledgr_invalid_strategy_helper"
  )
  testthat::expect_error(
    ledgr_selection(ctx, where = c(TRUE, FALSE, NA), missing = "ignore"),
    class = "ledgr_invalid_strategy_helper"
  )
})

testthat::test_that("[LTB-0090] empty helper domains keep their distinct meanings", {
  holdings_only <- strategy_context_entrance_fixture(
    availability = TRUE,
    members = character(),
    positions = c(OLD = 2),
    equity = 100
  )
  holdings_signal <- ledgr_signal_return(holdings_only, lookback = 5)
  testthat::expect_s3_class(holdings_signal, "ledgr_signal")
  testthat::expect_identical(names(holdings_signal), c("AAA", "OLD"))
  testthat::expect_identical(attr(holdings_signal, "eligible"), c(FALSE, FALSE))
  testthat::expect_s3_class(ledgr_select_top_n(holdings_signal, 1), "ledgr_empty_selection")
  testthat::expect_error(
    ledgr_signal_return(holdings_only, lookback = 0),
    class = "ledgr_invalid_strategy_helper"
  )
  held_target <- holdings_only |>
    ledgr_selection(where = c(FALSE, TRUE)) |>
    ledgr_weight_equal() |>
    ledgr_target_rebalance(holdings_only)
  testthat::expect_identical(unclass(held_target), c(AAA = 0, OLD = 2))

  empty_bars <- data.frame(
    instrument_id = character(),
    ts_utc = as.POSIXct(character(), tz = "UTC"),
    open = numeric(), high = numeric(), low = numeric(), close = numeric(),
    volume = numeric(),
    stringsAsFactors = FALSE
  )
  empty_axis <- list(
    run_id = "empty-axis",
    ts_utc = "2026-01-02T21:00:00Z",
    universe = character(),
    bars = empty_bars,
    feature_table = ledgr:::ledgr_projection_feature_table_schema(),
    .positions = stats::setNames(numeric(), character()),
    cash = 100,
    equity = 100,
    seed = NULL,
    pulse_seed = NULL,
    state_prev = NULL,
    .safety_state = "GREEN",
    availability_active = TRUE,
    members = character()
  )
  class(empty_axis) <- "ledgr_pulse_context"
  empty_axis <- ledgr:::ledgr_update_pulse_context_helpers(
    empty_axis,
    bars = empty_bars,
    features = empty_axis$feature_table,
    positions = empty_axis$.positions,
    universe = character(),
    availability = list()
  )
  testthat::expect_error(ledgr:::ledgr_validate_pulse_context(empty_axis), NA)
  cash_before <- empty_axis$cash
  equity_before <- empty_axis$equity
  selection_target <- empty_axis |>
    ledgr_selection() |>
    ledgr_weight_equal() |>
    ledgr_target_rebalance(empty_axis)
  signal_target <- empty_axis |>
    ledgr_signal(values = numeric()) |>
    ledgr_select_top_n(1) |>
    ledgr_weight_equal() |>
    ledgr_target_rebalance(empty_axis)
  for (target in list(selection_target, signal_target)) {
    testthat::expect_s3_class(target, "ledgr_target")
    testthat::expect_length(target, 0L)
    testthat::expect_identical(names(target), character())
  }
  testthat::expect_identical(empty_axis$cash, cash_before)
  testthat::expect_identical(empty_axis$equity, equity_before)

  testthat::expect_s3_class(ledgr_signal(numeric(), universe = character()), "ledgr_signal")
  testthat::expect_s3_class(ledgr_selection(logical(), universe = character()), "ledgr_selection")
  testthat::expect_s3_class(ledgr_weights(numeric(), universe = character()), "ledgr_weights")
  testthat::expect_s3_class(ledgr_target(numeric(), universe = character()), "ledgr_target")
  testthat::expect_s3_class(
    ledgr_select_top_n(ledgr_signal(numeric()), n = 1),
    "ledgr_empty_selection"
  )
  testthat::expect_error(
    ledgr_select_top_n(ledgr_signal(numeric()), n = 0),
    class = "ledgr_invalid_strategy_helper"
  )
  testthat::expect_error(
    ledgr_target(numeric(), universe = "AAA"),
    class = "ledgr_invalid_strategy_type"
  )
  testthat::expect_error(
    ledgr:::ledgr_validate_strategy_targets(
      numeric(), "AAA", allow_empty = TRUE
    ),
    class = "ledgr_invalid_strategy_result"
  )
  testthat::expect_error(
    ledgr:::ledgr_validate_strategy_targets(
      stats::setNames(numeric(), character()), character(), allow_empty = TRUE
    ),
    NA
  )
})

testthat::test_that("[LTB-0117] fixed-quantity targets follow the selection", {
  dense <- strategy_context_entrance_fixture()
  pick <- ledgr_selection(dense, where = c(TRUE, FALSE))
  testthat::expect_identical(
    unclass(ledgr_target_quantity(pick, dense, qty = 10)),
    c(AAA = 10, BBB = 0)
  )
  none <- ledgr_selection(dense, ids = character())
  testthat::expect_identical(
    unclass(ledgr_target_quantity(none, dense, qty = 10)),
    c(AAA = 0, BBB = 0)
  )
  warmup <- ledgr_selection(dense, where = c(NA, TRUE), missing = "exclude")
  testthat::expect_identical(
    unclass(ledgr_target_quantity(warmup, dense, qty = 7)),
    c(AAA = 0, BBB = 7)
  )

  available <- strategy_context_entrance_fixture(
    availability = TRUE,
    positions = c(OLD = 2)
  )
  testthat::expect_identical(
    unclass(ledgr_target_quantity(ledgr_selection(available), available, qty = 5)),
    c(AAA = 5, OLD = 2)
  )

  for (bad in list(-1, NA_real_, Inf, c(1, 2), "10")) {
    testthat::expect_error(
      ledgr_target_quantity(pick, dense, qty = bad),
      class = "ledgr_invalid_strategy_helper"
    )
  }
  testthat::expect_error(
    ledgr_target_quantity(ledgr_selection(c(AAA = TRUE, OLD = TRUE)), available, qty = 1),
    class = "ledgr_invalid_strategy_helper"
  )
  testthat::expect_error(
    ledgr_target_quantity(c(AAA = TRUE, BBB = FALSE), dense, qty = 1),
    class = "ledgr_invalid_strategy_helper"
  )

  bars <- ledgr_test_make_bars(c("AAA", "BBB"), as.Date("2020-01-01") + 0:29)
  snapshot <- ledgr_snapshot_from_df(bars, db_path = tempfile(fileext = ".duckdb"))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  pipeline <- function(ctx, params) {
    ctx |>
      ledgr_selection(where = ctx$vec$feature("return_5") > 0, missing = "exclude") |>
      ledgr_target_quantity(ctx, params$qty)
  }
  by_hand <- function(ctx, params) {
    ret <- ctx$vec$feature("return_5")
    targets <- ctx$flat()
    targets[which(ret > 0)] <- params$qty
    targets
  }
  run_fills <- function(strategy, run_id) {
    exp <- ledgr_experiment(
      snapshot,
      strategy,
      features = list(ledgr_ind_returns(5)),
      opening = ledgr_opening(cash = 10000),
      cost_model = ledgr_cost_zero()
    )
    bt <- suppressWarnings(ledgr_run(exp, params = list(qty = 3), run_id = run_id))
    on.exit(close(bt), add = TRUE)
    fills <- as.data.frame(ledgr_results(bt, what = "fills"))
    fills[, intersect(c("ts_utc", "instrument_id", "side", "qty", "price", "fee"), names(fills))]
  }
  from_pipeline <- run_fills(pipeline, "quantity_pipeline")
  from_hand <- run_fills(by_hand, "quantity_by_hand")
  testthat::expect_gt(nrow(from_pipeline), 0L)
  testthat::expect_equal(from_pipeline, from_hand)
})

testthat::test_that("[LTB-0120] signals cover the decision axis and carry eligibility", {
  contexts <- list(
    dense = strategy_context_entrance_fixture(),
    held_nonmember = strategy_context_entrance_fixture(
      availability = TRUE, positions = c(OLD = 2), restricted = c(FALSE, FALSE)
    ),
    restricted_member = strategy_context_entrance_fixture(
      availability = TRUE, members = c("AAA", "OLD"), restricted = c(TRUE, FALSE)
    ),
    holdings_only = strategy_context_entrance_fixture(
      availability = TRUE, members = character(), positions = c(OLD = 2),
      restricted = c(FALSE, FALSE)
    )
  )
  intended <- list(
    dense = c(AAA = 10, BBB = 10),
    held_nonmember = c(AAA = 10, OLD = 0),
    restricted_member = c(AAA = 0, OLD = 10),
    holdings_only = c(AAA = 0, OLD = 0)
  )
  for (name in names(contexts)) {
    ctx <- contexts[[name]]
    feature <- ctx$vec$feature("return_5")
    signals <- list(
      ledgr_signal_feature(ctx, "return_5"),
      ledgr_signal_return(ctx, lookback = 5),
      ledgr_signal(ctx, values = feature),
      ledgr_signal(ctx, values = rev(stats::setNames(feature, ctx$universe)))
    )
    for (signal in signals) {
      testthat::expect_identical(names(signal), ctx$universe, info = name)
      testthat::expect_identical(as.numeric(signal), as.numeric(feature), info = name)
      testthat::expect_identical(attr(signal, "eligible"), as.logical(ctx$vec$admissible), info = name)
    }
    target <- ctx$flat()
    target[ctx$vec$admissible & signals[[2L]] > 0.1] <- 10
    testthat::expect_identical(target, intended[[name]], info = name)
  }

  restricted <- contexts$restricted_member
  both_missing <- ledgr_signal(restricted, values = c(NA_real_, NA_real_))
  eligible_missing <- is.na(both_missing) & attr(both_missing, "eligible")
  testthat::expect_identical(unname(eligible_missing), c(FALSE, TRUE))
  testthat::expect_error(
    ledgr_selection(restricted, where = both_missing > 0.1),
    class = "ledgr_invalid_strategy_type"
  )
  ineligible_missing <- ledgr_signal(restricted, values = c(NA_real_, 0.9))
  testthat::expect_identical(
    unclass(ledgr_selection(restricted, where = ineligible_missing > 0.1)),
    c(AAA = FALSE, OLD = TRUE)
  )
})

testthat::test_that("[LTB-0121] selections, rankings and target helpers apply eligibility", {
  restricted <- strategy_context_entrance_fixture(
    availability = TRUE, members = c("AAA", "OLD"), restricted = c(TRUE, FALSE),
    positions = c(AAA = 3)
  )
  testthat::expect_identical(unclass(ledgr_selection(restricted)), c(AAA = FALSE, OLD = TRUE))
  testthat::expect_identical(
    unclass(ledgr_selection(restricted, ids = c("AAA", "OLD"))),
    c(AAA = FALSE, OLD = TRUE)
  )
  testthat::expect_identical(
    unclass(ledgr_selection(restricted, where = c(NA, TRUE))),
    c(AAA = FALSE, OLD = TRUE)
  )
  testthat::expect_error(
    ledgr_selection(restricted, where = c(TRUE, NA)),
    class = "ledgr_invalid_strategy_type"
  )
  testthat::expect_identical(
    unclass(ledgr_selection(restricted, where = c(TRUE, NA), missing = "exclude")),
    c(AAA = FALSE, OLD = FALSE)
  )

  ranked <- testthat::expect_no_warning(
    ledgr_select_top_n(ledgr_signal(restricted, values = c(5, 1)), 1)
  )
  testthat::expect_identical(unclass(ranked), c(AAA = FALSE, OLD = TRUE))
  testthat::expect_warning(
    short <- ledgr_select_top_n(ledgr_signal(restricted, values = c(5, 1)), 2),
    class = "ledgr_partial_selection"
  )
  testthat::expect_identical(unclass(short), c(AAA = FALSE, OLD = TRUE))
  empty <- testthat::expect_no_warning(
    ledgr_select_top_n(ledgr_signal(restricted, values = c(5, NA)), 1)
  )
  testthat::expect_s3_class(empty, "ledgr_empty_selection")
  testthat::expect_identical(as.logical(empty), c(FALSE, FALSE))

  quantity <- ledgr_target_quantity(ledgr_selection(restricted), restricted, qty = 10)
  testthat::expect_identical(unclass(quantity), c(AAA = 3, OLD = 10))
  testthat::expect_identical(
    unclass(ledgr_target_quantity(ledgr_selection(c(AAA = FALSE, OLD = TRUE)), restricted, qty = 10)),
    c(AAA = 3, OLD = 10)
  )
  testthat::expect_error(
    ledgr_target_quantity(ledgr_selection(c(AAA = TRUE, OLD = FALSE)), restricted, qty = 10),
    class = "ledgr_invalid_strategy_helper"
  )

  rebalanced <- restricted |>
    ledgr_selection() |>
    ledgr_weight_equal() |>
    ledgr_target_rebalance(restricted)
  kept <- ledgr_target_rebalance(
    ledgr_weight_equal(ledgr_selection(restricted)), restricted, keep = "AAA"
  )
  testthat::expect_identical(unclass(rebalanced), c(AAA = 3, OLD = 13))
  testthat::expect_identical(kept, rebalanced)
  testthat::expect_error(
    ledgr_target_rebalance(ledgr_weights(c(AAA = 1), universe = restricted$universe), restricted),
    class = "ledgr_invalid_strategy_helper"
  )

  dense <- strategy_context_entrance_fixture()
  testthat::expect_identical(unclass(ledgr_selection(dense)), c(AAA = TRUE, BBB = TRUE))
  testthat::expect_identical(
    unclass(ledgr_target_quantity(ledgr_selection(dense, ids = "BBB"), dense, qty = 10)),
    c(AAA = 0, BBB = 10)
  )
})

testthat::test_that("[LTB-0122] the signal wrapper maps eligible instruments and holds the rest", {
  long_all <- ledgr_signal_strategy(
    function(ctx) stats::setNames(rep("LONG", length(ctx$universe)), ctx$universe),
    long_qty = 10
  )
  long_members <- ledgr_signal_strategy(
    function(ctx) stats::setNames(rep("LONG", length(ctx$members)), ctx$members),
    long_qty = 10
  )
  testthat::expect_identical(ledgr_strategy_preflight(long_all)$tier, "tier_2")

  dense <- strategy_context_entrance_fixture()
  mixed <- ledgr_signal_strategy(function(ctx) c(AAA = "LONG", BBB = "FLAT"), long_qty = 10)
  testthat::expect_identical(mixed(dense, list()), c(AAA = 10, BBB = 0))

  held <- strategy_context_entrance_fixture(
    availability = TRUE, positions = c(OLD = 2), restricted = c(FALSE, FALSE)
  )
  testthat::expect_identical(long_all(held, list()), c(AAA = 10, OLD = 2))
  testthat::expect_identical(long_members(held, list()), c(AAA = 10, OLD = 2))

  halted <- strategy_context_entrance_fixture(
    availability = TRUE, members = c("AAA", "OLD"), restricted = c(TRUE, FALSE),
    positions = c(AAA = 3)
  )
  testthat::expect_identical(long_all(halted, list()), c(AAA = 3, OLD = 10))
  omit_eligible <- ledgr_signal_strategy(function(ctx) c(AAA = "LONG"), long_qty = 10)
  testthat::expect_error(omit_eligible(halted, list()), class = "ledgr_invalid_strategy_result")
  unknown_id <- ledgr_signal_strategy(function(ctx) c(OLD = "LONG", ZZZ = "LONG"), long_qty = 10)
  testthat::expect_error(unknown_id(halted, list()), class = "ledgr_invalid_strategy_result")
  bad_code <- ledgr_signal_strategy(function(ctx) c(AAA = "MAYBE", OLD = "LONG"), long_qty = 10)
  testthat::expect_error(bad_code(halted, list()), class = "ledgr_invalid_strategy_result")

  holdings_only <- strategy_context_entrance_fixture(
    availability = TRUE, members = character(), positions = c(OLD = 2),
    restricted = c(FALSE, FALSE)
  )
  testthat::expect_identical(long_members(holdings_only, list()), c(AAA = 0, OLD = 2))

  empty_bars <- data.frame(
    instrument_id = character(),
    ts_utc = as.POSIXct(character(), tz = "UTC"),
    open = numeric(), high = numeric(), low = numeric(), close = numeric(),
    volume = numeric(),
    stringsAsFactors = FALSE
  )
  empty_axis <- list(
    run_id = "empty-axis",
    ts_utc = "2026-01-02T21:00:00Z",
    universe = character(),
    bars = empty_bars,
    feature_table = ledgr:::ledgr_projection_feature_table_schema(),
    .positions = stats::setNames(numeric(), character()),
    cash = 100,
    equity = 100,
    seed = NULL,
    pulse_seed = NULL,
    state_prev = NULL,
    .safety_state = "GREEN",
    availability_active = TRUE,
    members = character()
  )
  class(empty_axis) <- "ledgr_pulse_context"
  empty_axis <- ledgr:::ledgr_update_pulse_context_helpers(
    empty_axis,
    bars = empty_bars,
    features = empty_axis$feature_table,
    positions = empty_axis$.positions,
    universe = character(),
    availability = list()
  )
  calls <- 0L
  counting <- ledgr_signal_strategy(function(ctx) {
    calls <<- calls + 1L
    stats::setNames(character(), character())
  }, long_qty = 10)
  empty_target <- counting(empty_axis, list())
  testthat::expect_identical(calls, 1L)
  testthat::expect_identical(empty_target, stats::setNames(numeric(), character()))
})
