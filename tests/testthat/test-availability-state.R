# ledgr-test-profile: review
testthat::test_that("dynamic membership drives the axis and stable asset state", {
  dates <- as.POSIXct(c("2020-01-01", "2020-01-02", "2020-01-03", "2020-01-04"), tz = "UTC")
  membership <- ledgr_facts_membership_snapshots(
    data.frame(
      instrument_id = c("AAA", NA_character_, "AAA", NA_character_),
      effective_from = dates,
      knowledge_time = dates - 1,
      stringsAsFactors = FALSE
    ),
    universe_id = "dynamic",
    complete = TRUE
  )
  snapshot <- availability_runtime_fixture(days = 4L, membership = membership)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  strategy <- function(ctx, params) {
    ledgr_strategy_result(
      stats::setNames(numeric(length(ctx$universe)), ctx$universe),
      portfolio = "kept",
      step = ctx$state$step + 1L,
      asset_value = 1
    )
  }
  exp <- ledgr_experiment(opening = ledgr_opening(cash = 100000),
    snapshot,
    strategy,
    universe = ledgr_universe_members("dynamic"),
    valuation_policy = ledgr_valuation_stale(1),
    cost_model = ledgr_cost_zero(),
    asset_state = list(asset_value = NA_real_),
    portfolio_state = list(portfolio = "kept", step = 0L)
  )
  bt <- ledgr_run(exp)
  on.exit(close(bt), add = TRUE)
  rows <- availability_state_rows(bt)
  decoded <- lapply(rows$state_json, ledgr:::ledgr_strategy_state_decode,
    declaration = exp$strategy_state)
  testthat::expect_identical(lapply(decoded, `[[`, "axis"), list("AAA", character(), "AAA", character()))
  testthat::expect_identical(vapply(decoded, function(x) x$values$step, integer(1L)), 1:4)
  testthat::expect_identical(decoded[[4L]]$values$portfolio, "kept")
  testthat::expect_equal(nrow(rows), 4L)
})

# ledgr-test-profile: review
testthat::test_that("provider orders members before stable held nonmembers", {
  dates <- as.Date("2020-01-01") + 0:2
  sessions <- ledgr_facts_sessions(
    data.frame(
      session_date = dates,
      status = "open",
      session_open = "09:30:00",
      session_close = "16:00:00",
      knowledge_time = as.POSIXct(dates, tz = "UTC") - 1
    ),
    venue_id = "XNYS"
  )
  member_ids <- c("zeta", "Alpha", "mike", "BRAVO", "alpha2")
  membership_snapshots <- ledgr_facts_membership_snapshots(
    data.frame(
      instrument_id = member_ids,
      effective_from = as.POSIXct(dates[[1L]], tz = "UTC"),
      knowledge_time = as.POSIXct(dates[[1L]], tz = "UTC") - 1,
      set_id = "complete_set"
    ),
    universe_id = "ordered",
    complete = TRUE
  )
  membership_intervals <- ledgr_facts_membership_intervals(
    data.frame(
      instrument_id = member_ids,
      effective_from = as.POSIXct(dates[[1L]], tz = "UTC"),
      knowledge_time = as.POSIXct(dates[[1L]], tz = "UTC") - 1,
      member = TRUE,
      fact_id = paste0("fact_", c(5L, 3L, 1L, 4L, 2L))
    ),
    universe_id = "ordered"
  )
  instrument_ids <- c(member_ids, "HOLD_Z", "HOLD_A")
  grid <- expand.grid(
    instrument_id = instrument_ids,
    ts_utc = as.POSIXct(paste(dates, "16:00:00"), tz = "UTC"),
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  grid$open <- grid$high <- grid$low <- grid$close <- 100
  grid$volume <- 1000
  views <- lapply(
    list(membership_snapshots, membership_intervals),
    function(membership) {
      snapshot <- ledgr_snapshot_from_df(
        grid,
        instruments_df = data.frame(instrument_id = instrument_ids),
        facts = ledgr_facts(sessions, membership), price_basis = "split_adjusted"
      )
      on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
      config <- list(
        data = list(snapshot_id = snapshot$snapshot_id),
        universe = list(instrument_ids = instrument_ids),
        availability = list(
          active = TRUE,
          declared_families = c("membership", "sessions"),
          universe_rule = unclass(ledgr_universe_members("ordered"))
        )
      )
      provider <- ledgr_availability_provider(
        get_connection(snapshot),
        config,
        ledgr_snapshot_info(snapshot)$snapshot_hash[[1L]]
      )
      positions <- stats::setNames(numeric(length(instrument_ids)), instrument_ids)
      positions[c("HOLD_Z", "HOLD_A")] <- 1
      provider$decision_view(
        as.POSIXct("2020-01-01 16:00:00", tz = "UTC"),
        positions
      )
    }
  )
  expected_members <- c("Alpha", "BRAVO", "alpha2", "mike", "zeta")
  expected_axis <- c(expected_members, "HOLD_A", "HOLD_Z")
  for (view in views) {
    testthat::expect_identical(view$members, expected_members)
    testthat::expect_identical(view$axis, expected_axis)
    testthat::expect_identical(
      unname(view$member),
      c(rep(TRUE, length(expected_members)), FALSE, FALSE)
    )
    testthat::expect_identical(
      unname(view$held),
      c(rep(FALSE, length(expected_members)), TRUE, TRUE)
    )
  }
})

testthat::test_that("asset state prunes exits and defaults re-entry", {
  declaration <- ledgr:::ledgr_strategy_state_normalize(
    asset_state = list(seen = NA), portfolio_state = list(step = 0L)
  )
  state <- list(seen = c(AAA = TRUE, EXIT = TRUE), step = 2L)
  pruned <- ledgr:::ledgr_strategy_state_align(state, declaration, c("AAA", "EXIT"), "AAA")
  testthat::expect_identical(pruned$seen, c(AAA = TRUE))
  empty <- ledgr:::ledgr_strategy_state_align(pruned, declaration, "AAA", character())
  testthat::expect_identical(empty$seen, stats::setNames(logical(), character()))
  reentered <- ledgr:::ledgr_strategy_state_align(empty, declaration, character(), "EXIT")
  testthat::expect_identical(reentered$seen, c(EXIT = NA))
  testthat::expect_identical(reentered$step, 2L)
})

testthat::test_that("prepared valuation advances finite closes without rescanning prefixes", {
  pulses <- as.POSIXct(paste(as.Date("2020-01-01") + 0:5, "16:00:00"), tz = "UTC")
  bars_mat <- list(
    close = rbind(
      AAA = c(NA, 100, NA, NA, 104, NA),
      BBB = rep(NA_real_, 6L),
      CCC = c(50, rep(NA_real_, 5L)),
      DDD = c(NA, NA, 30, NA, NA, 35)
    )
  )
  state <- ledgr:::ledgr_availability_valuation_state(
    bars_mat,
    rownames(bars_mat$close),
    pulses,
    2L
  )

  first <- state$advance(1L, c("CCC", "AAA", "BBB"))
  testthat::expect_identical(first$reference, c(CCC = 50, AAA = NA_real_, BBB = NA_real_))
  testthat::expect_identical(first$age, c(CCC = 0L, AAA = NA_integer_, BBB = NA_integer_))
  testthat::expect_identical(first$source, c(CCC = "current_close", AAA = "missing", BBB = "missing"))
  testthat::expect_identical(first$source_row, c(CCC = 3L, AAA = 1L, BBB = 2L))

  third <- state$advance(3L, c("AAA", "CCC", "DDD", "BBB"))
  testthat::expect_identical(third$reference, c(AAA = 100, CCC = 50, DDD = 30, BBB = NA_real_))
  testthat::expect_identical(third$age, c(AAA = 1L, CCC = 2L, DDD = 0L, BBB = NA_integer_))
  testthat::expect_identical(
    third$source,
    c(AAA = "stale_close", CCC = "stale_close", DDD = "current_close", BBB = "missing")
  )

  fourth <- state$advance(4L, c("AAA", "CCC", "DDD"))
  testthat::expect_identical(fourth$age, c(AAA = 2L, CCC = 3L, DDD = 1L))
  testthat::expect_identical(fourth$permissible, c(AAA = TRUE, CCC = FALSE, DDD = TRUE))
  testthat::expect_identical(fourth$mark, c(AAA = 100, CCC = NA_real_, DDD = 30))
  testthat::expect_identical(fourth$source, c(AAA = "stale_close", CCC = "expired_close", DDD = "stale_close"))

  repeated <- state$advance(4L, "AAA")
  testthat::expect_identical(repeated$age, c(AAA = 2L))
  testthat::expect_identical(
    as.numeric(repeated$source_ts),
    as.numeric(pulses[[2L]])
  )

  testthat::expect_error(
    state$advance(3L, "AAA"),
    class = "ledgr_availability_valuation_out_of_order"
  )
  testthat::expect_error(state$advance(4L, c("AAA", "AAA")), "unique prepared")
  testthat::expect_error(state$advance(4L, "UNKNOWN"), "unique prepared")

  stats <- state$stats()
  testthat::expect_identical(stats$row_index_builds, 1L)
  testthat::expect_identical(stats$row_index_cells, 4L)
  testthat::expect_equal(stats$close_cells_read, 4L * 4L)
  # The duplicate and unknown-axis calls also perform lookups before aborting.
  testthat::expect_equal(
    stats$source_index_lookups,
    3L + 4L + 3L + 1L + 2L + 1L
  )
})

testthat::test_that("prepared valuation work is exactly linear in source cells and emitted axis cells", {
  shapes <- list(
    c(source = 3L, axis = 2L, pulses = 5L),
    c(source = 31L, axis = 17L, pulses = 43L),
    c(source = 563L, axis = 505L, pulses = 757L)
  )
  observed <- lapply(shapes, function(shape) {
    ids <- sprintf("I%04d", seq_len(shape[["source"]]))
    pulses <- as.POSIXct("2020-01-01", tz = "UTC") + seq_len(shape[["pulses"]])
    close <- matrix(
      seq_len(shape[["source"]] * shape[["pulses"]]),
      nrow = shape[["source"]]
    )
    close[seq.int(2L, length(close), by = 11L)] <- NA_real_
    state <- ledgr:::ledgr_availability_valuation_state(
      list(close = close),
      ids,
      pulses,
      2L
    )
    axis <- ids[seq_len(shape[["axis"]])]
    for (pulse_idx in seq_len(shape[["pulses"]])) state$advance(pulse_idx, axis)
    state$stats()
  })
  for (i in seq_along(shapes)) {
    testthat::expect_identical(observed[[i]]$row_index_builds, 1L)
    testthat::expect_equal(
      observed[[i]]$row_index_cells,
      shapes[[i]][["source"]]
    )
    testthat::expect_equal(
      observed[[i]]$close_cells_read,
      shapes[[i]][["source"]] * shapes[[i]][["pulses"]]
    )
    testthat::expect_equal(
      observed[[i]]$source_index_lookups,
      shapes[[i]][["axis"]] * shapes[[i]][["pulses"]]
    )
  }
})

# ledgr-test-profile: review
testthat::test_that("retired valuation entry points remain unavailable", {
  namespace <- asNamespace("ledgr")
  retired <- c(
    "ledgr_availability_valuation_marks",
    "ledgr_availability_valuation_marks_reference",
    "ledgr_availability_valuation_state_reference",
    "ledgr_availability_valuation_state_prepared",
    "ledgr_fold_availability_mark_age"
  )
  testthat::expect_false(any(vapply(
    retired,
    exists,
    logical(1),
    envir = namespace,
    inherits = FALSE
  )))
  testthat::expect_false("valuation_state" %in% names(formals(ledgr:::ledgr_execution_spec)))
})

# ledgr-test-profile: heavy_protocol
testthat::test_that("fixed baskets use the canonical valuation-state service", {
  dates <- as.POSIXct(
    paste(as.Date("2020-01-01") + 0:1, "16:00:00"),
    tz = "UTC"
  )
  bars <- data.frame(
    ts_utc = dates,
    instrument_id = "AAA",
    open = 100,
    high = 101,
    low = 99,
    close = 100,
    volume = 1000
  )
  snapshot <- ledgr_snapshot_from_df(
    bars,
    instruments_df = data.frame(instrument_id = "AAA")
  )
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  experiment <- ledgr_experiment(opening = ledgr_opening(cash = 100000),
    snapshot,
    function(ctx, params) ctx$flat(),
    cost_model = ledgr_cost_zero()
  )
  calls <- 0L
  original <- ledgr:::ledgr_availability_valuation_state
  testthat::local_mocked_bindings(
    ledgr_availability_valuation_state = function(...) {
      calls <<- calls + 1L
      original(...)
    },
    .package = "ledgr"
  )
  bt <- ledgr_run(experiment, run_id = "dense-valuation-bypass")
  on.exit(close(bt), add = TRUE)
  testthat::expect_identical(
    ledgr_run_info(snapshot, "dense-valuation-bypass")$status,
    "DONE"
  )
  testthat::expect_gt(calls, 0L)
})
