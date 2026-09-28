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

testthat::test_that("[LTB-0095] feature signals apply only the admissibility mask", {
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
    c(AAA = NA_real_, OLD = 0.9)
  )
  testthat::expect_identical(unclass(raw), c(AAA = 0.2, OLD = 0.9))

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
  empty$vec$feature <- function(...) {
    rlang::abort("empty membership must not read a feature")
  }
  signal <- ledgr_signal_feature(empty, "return_5")
  testthat::expect_s3_class(signal, "ledgr_signal")
  testthat::expect_length(signal, 0L)
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
    c(AAA = TRUE)
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
  holdings_only$vec$feature <- function(...) {
    rlang::abort("empty membership must not read a feature")
  }
  empty_signal <- ledgr_signal_return(holdings_only, lookback = 5)
  testthat::expect_s3_class(empty_signal, "ledgr_signal")
  testthat::expect_length(empty_signal, 0L)
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
