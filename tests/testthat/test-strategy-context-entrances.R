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
    held = stats::setNames(ctx$position != 0, ids),
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
  ctx$members <- members
  ctx
}

strategy_context_override_plane <- function(ctx, name, value) {
  lookup <- unclass(ctx)[[".pulse_lookup"]]
  if (is.atomic(value) && length(value) == length(ctx$universe)) {
    names(value) <- ctx$universe
  }
  assign(name, value, envir = lookup$cache)
  ctx
}

strategy_target_values <- function(x) {
  stats::setNames(as.numeric(x), names(x))
}

strategy_context_empty_axis_fixture <- function() {
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
    .positions = stats::setNames(numeric(), character()),
    cash = 100,
    equity = 100,
    seed = NULL,
    pulse_seed = NULL,
    state = ledgr:::ledgr_strategy_state_view(list()),
    .safety_state = "GREEN",
    members = character()
  )
  class(empty_axis) <- "ledgr_pulse_context"
  ledgr:::ledgr_update_pulse_context_helpers(
    empty_axis,
    bars = empty_bars,
    features = data.frame(),
    positions = empty_axis$.positions,
    universe = character(),
    availability = NULL
  )
}

testthat::test_that("[LTB-0085] context entrances bind alignment and eligibility over the axis", {
  dense <- strategy_context_entrance_fixture()
  dense_ids <- names(ledgr_selection(dense))[as.logical(ledgr_selection(dense))]
  dense_target <- ledgr_target_rebalance(
    dense,
    weights = ledgr_weight_equal(dense_ids)
  )
  testthat::expect_identical(strategy_target_values(dense_target), c(AAA = 15, BBB = 7))

  dense_score <- ledgr_signal(dense, values = dense[["return_5"]])
  score_target <- ledgr_target_rebalance(
    dense,
    weights = ledgr_weight_equal(
      ledgr_select_top(dense_score, n = 1, within = attr(dense_score, "eligible"))
    )
  )
  testthat::expect_identical(strategy_target_values(score_target), c(AAA = 0, BBB = 15))

  named <- ledgr_signal(dense, values = c(BBB = 0.9, AAA = 0.2))
  positional <- ledgr_signal(dense, values = c(0.2, 0.9))
  testthat::expect_identical(named, positional)

  available <- strategy_context_entrance_fixture(
    availability = TRUE,
    positions = c(OLD = 2),
    equity = 100
  )
  available_ids <- names(ledgr_selection(available))[as.logical(ledgr_selection(available))]
  full <- ledgr_target_rebalance(
    available,
    weights = ledgr_weight_equal(available_ids),
    index_leavers = "keep",
    capital_base = "remaining_equity"
  )
  partial <- ledgr_target_rebalance(
    available,
    weights = ledgr_weight_equal(available_ids),
    index_leavers = "keep",
    capital_base = "remaining_equity",
    invest_fraction = 0.6
  )
  none <- ledgr_target_rebalance(available, index_leavers = "keep")
  testthat::expect_identical(strategy_target_values(full), c(AAA = 6, OLD = 2))
  testthat::expect_identical(strategy_target_values(partial), c(AAA = 3, OLD = 2))
  testthat::expect_identical(strategy_target_values(none), c(AAA = 0, OLD = 2))

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
    ids <- names(selection)[as.logical(selection)]
    ledgr_target_rebalance(
      available,
      weights = ledgr_weight_equal(ids),
      index_leavers = "keep",
      capital_base = "remaining_equity"
    )
  })
  testthat::expect_true(all(vapply(
    projected_targets,
    function(x) identical(strategy_target_values(x), c(AAA = 6, OLD = 2)),
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

  ranked_signal <- ledgr_signal(available, values = c(AAA = 1, OLD = 999))
  ranked <- ledgr_select_top(
    ranked_signal,
    n = 1,
    within = attr(ranked_signal, "eligible")
  )
  testthat::expect_identical(ranked, "AAA")

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
  raw <- ledgr_signal(ctx, values = ctx[["return_5"]])
  convenience <- ledgr_signal_return(ctx, lookback = 5)
  for (signal in list(raw, convenience)) {
    testthat::expect_identical(
      stats::setNames(as.numeric(signal), names(signal)),
      c(AAA = 0.2, OLD = 0.9)
    )
    testthat::expect_identical(attr(signal, "eligible"), c(FALSE, FALSE))
  }

  missing_signal <- ledgr_signal(ctx, values = c(AAA = NA_real_, OLD = 9))
  missing_scores <- ledgr_target_rebalance(
    ctx,
    weights = ledgr_weight_equal(ledgr_select_top(
      missing_signal,
      n = 1,
      within = attr(missing_signal, "eligible")
    )),
    index_leavers = "keep"
  )
  guarded <- ctx$hold()
  testthat::expect_identical(strategy_target_values(missing_scores), c(AAA = 4, OLD = 2))
  testthat::expect_identical(guarded, c(AAA = 4, OLD = 2))
})

testthat::test_that("[LTB-0095] feature signals carry the admissibility plane", {
  restricted <- strategy_context_entrance_fixture(
    availability = TRUE,
    members = c("AAA", "OLD"),
    restricted = c(TRUE, FALSE),
    priced = c(TRUE, TRUE)
  )
  feature <- restricted[["return_5"]]
  raw <- ledgr_signal(
    restricted,
    values = restricted[["return_5"]]
  )
  testthat::expect_identical(
    stats::setNames(as.numeric(feature), names(feature)),
    c(AAA = 0.2, OLD = 0.9)
  )
  testthat::expect_null(attr(feature, "eligible"))
  testthat::expect_identical(stats::setNames(as.numeric(raw), names(raw)), c(AAA = 0.2, OLD = 0.9))
  testthat::expect_identical(attr(raw, "eligible"), c(FALSE, TRUE))

  unpriced <- strategy_context_entrance_fixture(
    availability = TRUE,
    members = c("AAA", "OLD"),
    restricted = c(FALSE, FALSE),
    priced = c(FALSE, TRUE)
  )
  unpriced_signal <- unpriced[["return_5"]]
  testthat::expect_identical(
    stats::setNames(as.numeric(unpriced_signal), names(unpriced_signal)),
    c(AAA = 0.2, OLD = 0.9)
  )

  dense <- strategy_context_entrance_fixture()
  testthat::expect_identical(
    stats::setNames(as.numeric(ledgr_signal_return(dense, lookback = 5)), dense$universe),
    dense[["return_5"]]
  )
  testthat::expect_identical(
    stats::setNames(as.numeric(ledgr_signal_return(restricted, lookback = 5)), restricted$universe),
    restricted[["return_5"]]
  )
  testthat::expect_error(
    dense[["unknown_feature"]],
    class = "ledgr_unknown_context_field"
  )

  empty <- strategy_context_entrance_fixture(
    availability = TRUE,
    members = character()
  )
  signal <- empty[["return_5"]]
  testthat::expect_identical(stats::setNames(as.numeric(signal), names(signal)), c(AAA = 0.2, OLD = 0.9))
  testthat::expect_null(attr(signal, "eligible"))
  testthat::expect_null(attr(signal, "origin"))

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
  dense <- strategy_context_override_plane(dense, "close", c(10, NA_real_))
  with_zero <- testthat::expect_no_warning(ledgr_target_rebalance(
    dense, weights = c(AAA = 1, BBB = 0)
  ))
  omitted <- testthat::expect_no_warning(ledgr_target_rebalance(
    dense, weights = c(AAA = 1)
  ))
  testthat::expect_identical(
    strategy_target_values(with_zero),
    strategy_target_values(omitted)
  )
  zero_evidence <- attr(with_zero, "sizing_evidence", exact = TRUE)
  omitted_evidence <- attr(omitted, "sizing_evidence", exact = TRUE)
  testthat::expect_identical(zero_evidence$instrument_id, c("AAA", "BBB"))
  testthat::expect_identical(
    zero_evidence$reason_code,
    c("sizing_rounded", "sizing_zero_target")
  )
  testthat::expect_identical(omitted_evidence$instrument_id, "AAA")
  testthat::expect_identical(strategy_target_values(with_zero), c(AAA = 10, BBB = 0))
  positive_dense <- ledgr_target_rebalance(
    dense, weights = c(AAA = 0.5, BBB = 0.5)
  )
  testthat::expect_identical(
    stats::setNames(as.numeric(positive_dense), names(positive_dense)),
    c(AAA = 5, BBB = 0)
  )
  testthat::expect_identical(attr(positive_dense, "sizing_skipped"), "BBB")

  available <- strategy_context_entrance_fixture(
    availability = TRUE,
    members = c("AAA", "OLD"),
    positions = c(OLD = 2),
    restricted = c(FALSE, FALSE),
    equity = 100
  )
  available <- strategy_context_override_plane(available, "close", c(10, NA_real_))
  available_zero <- testthat::expect_no_condition(ledgr_target_rebalance(
    available, weights = c(AAA = 1, OLD = 0)
  ))
  available_omitted <- testthat::expect_no_condition(ledgr_target_rebalance(
    available, weights = c(AAA = 1)
  ))
  testthat::expect_identical(available_zero, available_omitted)
  testthat::expect_identical(strategy_target_values(available_zero), c(AAA = 10, OLD = 0))
  # Cut 10: a positive weight on an unpriced held member skips it at its
  # current quantity (E = 2 * 20 = 40, V = 50, V + E <= 100, so AAA keeps
  # floor(50 / 10) = 5); without a permissible mark it still fails closed.
  skipped <- ledgr_target_rebalance(
    available, weights = c(AAA = 0.5, OLD = 0.5)
  )
  testthat::expect_identical(c(skipped), c(AAA = 5, OLD = 2))
  testthat::expect_identical(attr(skipped, "sizing_skipped"), "OLD")
  unmarked <- strategy_context_override_plane(available, "holding_value", c(0, NA_real_))
  testthat::expect_error(
    ledgr_target_rebalance(unmarked, weights = c(AAA = 0.5, OLD = 0.5)),
    class = "ledgr_target_sizing_unavailable"
  )

  nonmember <- strategy_context_entrance_fixture(
    availability = TRUE,
    positions = c(OLD = 2),
    equity = 100
  )
  testthat::expect_error(
    ledgr_target_rebalance(nonmember, weights = c(OLD = 0), index_leavers = "keep"),
    class = "ledgr_invalid_strategy_helper"
  )
})

testthat::test_that("[LTB-0097] rebalance reserves explicitly kept positions", {
  legacy_ctx <- list(
    universe = c("AAA", "BBB"),
    equity = 1000,
    close = c(AAA = 50, BBB = 100),
    position = c(AAA = 0, BBB = 0),
    holding_value = c(AAA = 0, BBB = 0),
    buyable = c(AAA = TRUE, BBB = TRUE),
    member = c(AAA = TRUE, BBB = TRUE)
  )
  legacy_weights <- ledgr_weights(
    c(AAA = 0.5, BBB = 0.5),
    universe = legacy_ctx$universe
  )
  testthat::expect_identical(
    strategy_target_values(ledgr_target_rebalance(
      legacy_ctx, weights = unclass(legacy_weights), invest_fraction = 0.5
    )),
    c(AAA = 5, BBB = 2)
  )
  testthat::expect_identical(
    strategy_target_values(ledgr_target_rebalance(
      legacy_ctx, weights = c(BBB = 1), keep = "AAA",
      capital_base = "remaining_equity"
    )),
    c(AAA = 0, BBB = 10)
  )

  dense <- strategy_context_entrance_fixture(
    positions = c(AAA = 4),
    equity = 100
  )
  dense <- strategy_context_override_plane(dense, "close", c(10, 10))
  weights <- ledgr_weights(c(BBB = 1), universe = dense$universe)

  kept <- ledgr_target_rebalance(
    dense, weights = unclass(weights), keep = "AAA",
    capital_base = "remaining_equity"
  )
  half <- ledgr_target_rebalance(
    dense,
    weights = unclass(weights),
    invest_fraction = 0.5,
    keep = "AAA",
    capital_base = "remaining_equity"
  )
  testthat::expect_identical(strategy_target_values(kept), c(AAA = 4, BBB = 6))
  testthat::expect_identical(strategy_target_values(half), c(AAA = 4, BBB = 3))

  baseline <- ledgr_target_rebalance(dense, weights = unclass(weights))
  testthat::expect_identical(
    ledgr_target_rebalance(dense, weights = unclass(weights), keep = NULL),
    baseline
  )
  testthat::expect_identical(
    ledgr_target_rebalance(dense, weights = unclass(weights), keep = character()),
    baseline
  )

  available <- strategy_context_entrance_fixture(
    availability = TRUE,
    positions = c(OLD = 2),
    equity = 100
  )
  member_weights <- ledgr_weights(c(AAA = 1), universe = available$universe)
  testthat::expect_identical(
    ledgr_target_rebalance(
      available, weights = unclass(member_weights), keep = "OLD",
      capital_base = "remaining_equity"
    ),
    ledgr_target_rebalance(
      available, weights = unclass(member_weights), index_leavers = "keep",
      capital_base = "remaining_equity"
    )
  )

  testthat::expect_error(
    ledgr_target_rebalance(
      dense,
      weights = c(AAA = 0, BBB = 1),
      keep = "AAA",
      capital_base = "remaining_equity"
    ),
    regexp = "both weighted and kept",
    class = "ledgr_invalid_strategy_result"
  )
  for (invalid_keep in list("ZZZ", c("AAA", "AAA"), NA_character_)) {
    testthat::expect_error(
      ledgr_target_rebalance(
        dense, weights = unclass(weights), keep = invalid_keep,
        capital_base = "remaining_equity"
      ),
      class = "ledgr_invalid_strategy_type"
    )
  }

  unavailable <- strategy_context_entrance_fixture(
    positions = c(AAA = 4),
    equity = 100
  )
  unavailable <- strategy_context_override_plane(unavailable, "close", c(NA_real_, 20))
  unavailable <- strategy_context_override_plane(unavailable, "holding_value", c(NA_real_, 0))
  testthat::expect_error(
    ledgr_target_rebalance(
      unavailable, weights = unclass(weights), keep = "AAA",
      capital_base = "remaining_equity"
    ),
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
    features = data.frame(),
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
  testthat::expect_identical(
    ledgr_select_top(holdings_signal, n = 1, within = attr(holdings_signal, "eligible")),
    character()
  )
  testthat::expect_error(
    ledgr_signal_return(holdings_only, lookback = 0),
    class = "ledgr_invalid_strategy_helper"
  )
  held_selection <- ledgr_selection(holdings_only, where = c(FALSE, TRUE))
  held_target <- ledgr_target_rebalance(
    holdings_only,
    weights = ledgr_weight_equal(names(held_selection)[as.logical(held_selection)]),
    index_leavers = "keep"
  )
  testthat::expect_identical(strategy_target_values(held_target), c(AAA = 0, OLD = 2))

  empty_axis <- strategy_context_empty_axis_fixture()
  testthat::expect_error(ledgr:::ledgr_validate_pulse_context(empty_axis), NA)
  cash_before <- empty_axis$cash
  equity_before <- empty_axis$equity
  selection_target <- ledgr_target_rebalance(
    empty_axis,
    weights = ledgr_weight_equal(character())
  )
  signal_target <- ledgr_target_rebalance(
    empty_axis,
    weights = ledgr_weight_equal(ledgr_select_top(
      stats::setNames(numeric(), character()), n = 1
    ))
  )
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
  empty_score <- stats::setNames(numeric(), character())
  testthat::expect_identical(ledgr_select_top(empty_score, n = 1), character())
  testthat::expect_identical(ledgr_select_top(empty_score, n = 0), character())
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
      ledgr_selection(where = ctx[["return_5"]] > 0, missing = "exclude") |>
      ledgr_target_quantity(ctx, params$qty)
  }
  by_hand <- function(ctx, params) {
    ret <- ctx[["return_5"]]
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
    feature <- ctx[["return_5"]]
    signals <- list(
      ctx[["return_5"]],
      ledgr_signal_return(ctx, lookback = 5),
      ledgr_signal(ctx, values = feature),
      ledgr_signal(ctx, values = rev(stats::setNames(feature, ctx$universe)))
    )
    for (i in seq_along(signals)) {
      signal <- signals[[i]]
      testthat::expect_identical(names(signal), ctx$universe, info = name)
      testthat::expect_identical(as.numeric(signal), as.numeric(feature), info = name)
      if (i == 1L) {
        testthat::expect_null(attr(signal, "eligible"), info = name)
      } else {
        testthat::expect_identical(attr(signal, "eligible"), as.logical(ctx$buyable), info = name)
      }
    }
    target <- ctx$flat()
    target[ctx$buyable & signals[[2L]] > 0.1] <- 10
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

  ranked_signal <- ledgr_signal(restricted, values = c(5, 1))
  ranked <- testthat::expect_no_warning(
    ledgr_select_top(ranked_signal, n = 1, within = attr(ranked_signal, "eligible"))
  )
  testthat::expect_identical(ranked, "OLD")
  short <- testthat::expect_no_warning(
    ledgr_select_top(ranked_signal, n = 2, within = attr(ranked_signal, "eligible"))
  )
  testthat::expect_identical(short, "OLD")
  missing_rank_signal <- ledgr_signal(restricted, values = c(5, NA))
  empty <- testthat::expect_no_warning(
    ledgr_select_top(
      missing_rank_signal,
      n = 1,
      within = attr(missing_rank_signal, "eligible")
    )
  )
  testthat::expect_identical(empty, character())

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

  restricted_selection <- ledgr_selection(restricted)
  restricted_weights <- ledgr_weight_equal(
    names(restricted_selection)[as.logical(restricted_selection)]
  )
  rebalanced <- ledgr_target_rebalance(
    restricted,
    weights = restricted_weights,
    capital_base = "remaining_equity"
  )
  kept <- ledgr_target_rebalance(
    restricted,
    weights = restricted_weights,
    keep = "AAA",
    capital_base = "remaining_equity"
  )
  testthat::expect_identical(strategy_target_values(rebalanced), c(AAA = 3, OLD = 13))
  testthat::expect_identical(kept, rebalanced)
  testthat::expect_error(
    ledgr_target_rebalance(restricted, weights = c(AAA = 1)),
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
    .positions = stats::setNames(numeric(), character()),
    cash = 100,
    equity = 100,
    seed = NULL,
    pulse_seed = NULL,
    state = ledgr:::ledgr_strategy_state_view(list()),
    .safety_state = "GREEN",
    members = character()
  )
  class(empty_axis) <- "ledgr_pulse_context"
  empty_axis <- ledgr:::ledgr_update_pulse_context_helpers(
    empty_axis,
    bars = empty_bars,
    features = data.frame(),
    positions = empty_axis$.positions,
    universe = character(),
    availability = NULL
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

testthat::test_that("[LTB-0123] the context warmup form checks eligible instruments only", {
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
  # Expected results for a missing first and a missing second value, written
  # from each fixture's eligibility: dense AAA and BBB; AAA only beside the held
  # nonmember OLD; OLD only beside the restricted member AAA; nothing eligible.
  intended <- list(
    dense = c(missing_first = FALSE, missing_second = FALSE),
    held_nonmember = c(missing_first = FALSE, missing_second = TRUE),
    restricted_member = c(missing_first = TRUE, missing_second = FALSE),
    holdings_only = c(missing_first = TRUE, missing_second = TRUE)
  )
  for (name in names(contexts)) {
    ctx <- contexts[[name]]
    testthat::expect_true(ledgr_passed_warmup(ctx, ctx[["return_5"]]), info = name)
    testthat::expect_true(ledgr_passed_warmup(ctx, ctx[["return_5"]]), info = name)
    variants <- list(missing_first = c(NA_real_, 0.9), missing_second = c(0.2, NA_real_))
    for (variant in names(variants)) {
      values <- variants[[variant]]
      named <- stats::setNames(values, ctx$universe)
      expected <- intended[[name]][[variant]]
      label <- paste(name, variant)
      testthat::expect_identical(ledgr_passed_warmup(ctx, values), expected, info = label)
      testthat::expect_identical(ledgr_passed_warmup(ctx, rev(named)), expected, info = label)
      testthat::expect_identical(
        ledgr_passed_warmup(ctx, ledgr_signal(ctx, values = values)), expected, info = label
      )
      eligible_only <- named[as.logical(ctx$buyable)]
      testthat::expect_identical(ledgr_passed_warmup(ctx, eligible_only), expected, info = label)
    }
  }

  empty_axis <- strategy_context_empty_axis_fixture()
  testthat::expect_true(ledgr_passed_warmup(empty_axis, numeric()))
  testthat::expect_true(ledgr_passed_warmup(empty_axis, stats::setNames(numeric(), character())))

  restricted <- contexts$restricted_member
  testthat::expect_error(
    ledgr_passed_warmup(restricted, c(AAA = 0.2)),
    class = "ledgr_invalid_strategy_type"
  )
  testthat::expect_error(
    ledgr_passed_warmup(restricted, c(0.2, 0.9, 0.1)),
    class = "ledgr_invalid_strategy_type"
  )
  condition_classes <- function(expr) {
    setdiff(
      class(tryCatch(expr, error = identity)),
      c("rlang_error", "error", "condition")
    )
  }
  testthat::expect_identical(
    condition_classes(ledgr_passed_warmup(restricted, c("0.2", "0.9"))),
    "ledgr_invalid_warmup_input"
  )
  testthat::expect_identical(
    condition_classes(ledgr_passed_warmup(c(0.2, 0.9), c(0.2, 0.9))),
    "ledgr_invalid_warmup_input"
  )

  # The one-argument form is unchanged: all(!is.na(x)) over the whole vector.
  testthat::expect_true(ledgr_passed_warmup(c(ret_5 = 0.02, sma_10 = 101)))
  testthat::expect_false(ledgr_passed_warmup(c(ret_5 = NA_real_, sma_10 = 101)))
  testthat::expect_false(ledgr_passed_warmup(restricted[["return_5"]] * NA))
  testthat::expect_identical(
    condition_classes(ledgr_passed_warmup(numeric())),
    c("ledgr_empty_warmup_input", "ledgr_invalid_warmup_input", "ledgr_invalid_args")
  )
  testthat::expect_identical(
    condition_classes(ledgr_passed_warmup("x")),
    c("ledgr_invalid_warmup_input", "ledgr_invalid_args")
  )
  testthat::expect_identical(
    condition_classes(ledgr_passed_warmup(restricted)),
    c("ledgr_invalid_warmup_input", "ledgr_invalid_args")
  )
  # A classed numeric vector keeps its own is.na() method in the
  # one-argument form, which is all(!is.na(x)), even when its anyNA() method
  # disagrees.
  registerS3method("is.na", "ledgr_ltb0123_never_na", function(x) rep(FALSE, length(x)))
  registerS3method("anyNA", "ledgr_ltb0123_never_na", function(x, recursive = FALSE) TRUE)
  never_na <- structure(c(a = NA_real_, b = 1), class = "ledgr_ltb0123_never_na")
  testthat::expect_true(ledgr_passed_warmup(never_na))

  # A signal on the context's axis is read without a second entrance pass;
  # other payloads, and a signal carrying an infinite score, still take it.
  align_calls <- 0L
  align <- ledgr:::ledgr_strategy_context_align
  testthat::local_mocked_bindings(
    ledgr_strategy_context_align = function(...) {
      align_calls <<- align_calls + 1L
      align(...)
    },
    .package = "ledgr"
  )
  signal <- ledgr_signal(restricted, values = c(NA_real_, 0.9))
  align_calls <- 0L
  testthat::expect_true(ledgr_passed_warmup(restricted, signal))
  testthat::expect_false(ledgr_passed_warmup(restricted, signal * c(1, NA)))
  testthat::expect_identical(align_calls, 0L)
  testthat::expect_true(ledgr_passed_warmup(restricted, c(NA_real_, 0.9)))
  testthat::expect_identical(align_calls, 1L)
  testthat::expect_error(
    ledgr_passed_warmup(restricted, signal * c(1, Inf)),
    class = "ledgr_invalid_strategy_type"
  )
  testthat::expect_error(
    ledgr_passed_warmup(restricted, c(0.2, Inf)),
    class = "ledgr_invalid_strategy_type"
  )
})

testthat::test_that("[LTB-0124] a malformed eligibility plane fails closed in every helper", {
  restricted <- strategy_context_entrance_fixture(
    availability = TRUE, members = c("AAA", "OLD"), restricted = c(TRUE, FALSE),
    positions = c(AAA = 3)
  )
  wrapper <- ledgr_signal_strategy(
    function(ctx) stats::setNames(rep("LONG", length(ctx$universe)), ctx$universe),
    long_qty = 10
  )
  calls <- list(
    signal_values = function(ctx) ledgr_signal(ctx, values = c(0.2, 0.9)),
    selection = function(ctx) ledgr_selection(ctx),
    selection_ids = function(ctx) ledgr_selection(ctx, ids = c("AAA", "OLD")),
    quantity = function(ctx) ledgr_target_quantity(ledgr_selection(c(AAA = FALSE, OLD = TRUE)), ctx, qty = 10),
    rebalance = function(ctx) ledgr_target_rebalance(ctx, weights = c(OLD = 1)),
    warmup = function(ctx) ledgr_passed_warmup(ctx, c(0.2, 0.9)),
    wrapper = function(ctx) wrapper(ctx, list())
  )
  expected_class <- function(name) {
    if (identical(name, "wrapper")) "ledgr_invalid_strategy_result" else "ledgr_invalid_strategy_helper"
  }
  planes <- list(missing = NULL, short = FALSE, character = c("TRUE", "FALSE"), missing_value = c(NA, TRUE))
  for (plane in names(planes)) {
    broken <- strategy_context_override_plane(restricted, "buyable", planes[[plane]])
    for (name in names(calls)) {
      testthat::expect_error(calls[[name]](broken), class = expected_class(name), info = paste(plane, name))
    }
  }
  restricted <- strategy_context_override_plane(restricted, "buyable", c(FALSE, TRUE))

  # The well-formed context keeps the restricted member out.
  testthat::expect_identical(unclass(calls$selection(restricted)), c(AAA = FALSE, OLD = TRUE))
  testthat::expect_identical(wrapper(restricted, list()), c(AAA = 3, OLD = 10))

  # Every context uses the common eligibility plane, and malformed planes
  # fail closed.
  dense <- strategy_context_entrance_fixture()
  bare <- strategy_context_override_plane(dense, "buyable", NULL)
  testthat::expect_error(ledgr_selection(bare), class = "ledgr_invalid_strategy_helper")
  testthat::expect_error(wrapper(bare, list()), class = "ledgr_invalid_strategy_result")
  short <- strategy_context_override_plane(dense, "buyable", TRUE)
  testthat::expect_error(ledgr_selection(short), class = "ledgr_invalid_strategy_helper")
  testthat::expect_error(wrapper(short, list()), class = "ledgr_invalid_strategy_result")
})
