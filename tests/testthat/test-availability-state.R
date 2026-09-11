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
    history <- if (is.null(ctx$state_prev$history)) list() else ctx$state_prev$history
    step <- if (is.null(ctx$state_prev$step)) 1L else as.integer(ctx$state_prev$step) + 1L
    history[[length(history) + 1L]] <- list(
      universe = ctx$universe,
      members = ctx$members,
      portfolio = ctx$state_prev$portfolio,
      asset_empty = length(ctx$state_prev$asset_state) == 0L ||
        ("AAA" %in% names(ctx$state_prev$asset_state) &&
         length(ctx$state_prev$asset_state$AAA) == 0L),
      plane_names = intersect(
        c(
          "member", "held", "target_restricted", "target_restriction_reason",
          "admissible", "priced", "mark_age"
        ),
        names(ctx$vec)
      )
    )
    asset_state <- stats::setNames(vector("list", length(ctx$universe)), ctx$universe)
    for (id in ctx$universe) asset_state[[id]] <- list(seen = TRUE)
    list(
      targets = stats::setNames(numeric(length(ctx$universe)), ctx$universe),
      state_update = list(
        portfolio = "kept",
        step = step,
        history = history,
        asset_state = asset_state
      )
    )
  }
  exp <- ledgr_experiment(
    snapshot,
    strategy,
    universe = ledgr_universe_members("dynamic"),
    valuation_policy = ledgr_valuation_stale(1),
    cost_model = ledgr_cost_zero()
  )
  bt <- ledgr_run(exp)
  on.exit(close(bt), add = TRUE)
  final_state <- availability_last_state(bt)
  seen <- final_state$history
  testthat::expect_identical(lapply(seen, `[[`, "universe"), list("AAA", list(), "AAA"))
  testthat::expect_identical(lapply(seen, `[[`, "members"), list("AAA", list(), "AAA"))
  testthat::expect_identical(final_state$step, 3L)
  testthat::expect_identical(seen[[2L]]$portfolio, "kept")
  testthat::expect_true(seen[[3L]]$asset_empty)
  testthat::expect_identical(
    seen[[1L]]$plane_names,
    c(
      "member", "held", "target_restricted", "target_restriction_reason",
      "admissible", "priced", "mark_age"
    )
  )
  testthat::expect_equal(nrow(availability_state_rows(bt)), 3L)
})

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
        facts = ledgr_facts(sessions, membership)
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

testthat::test_that("asset state prunes exits, resets re-entry, and fails closed", {
  state <- list(
    portfolio = "kept",
    asset_state = list(AAA = list(seen = TRUE), EXIT = list(old = TRUE))
  )
  pruned <- ledgr:::ledgr_fold_asset_state_normalize(state, "AAA", drop_exited = TRUE)
  testthat::expect_identical(names(pruned$asset_state), "AAA")
  testthat::expect_identical(pruned$asset_state$AAA, list(seen = TRUE))
  testthat::expect_identical(pruned$portfolio, "kept")

  empty <- ledgr:::ledgr_fold_asset_state_normalize(pruned, character(), drop_exited = TRUE)
  testthat::expect_identical(
    empty$asset_state,
    stats::setNames(vector("list", 0L), character())
  )
  reentered <- ledgr:::ledgr_fold_asset_state_normalize(empty, "EXIT", drop_exited = TRUE)
  testthat::expect_identical(reentered$asset_state, list(EXIT = list()))
  testthat::expect_identical(reentered$portfolio, "kept")

  testthat::expect_error(
    ledgr:::ledgr_fold_asset_state_normalize(state, "AAA"),
    class = "ledgr_invalid_strategy_state"
  )
  testthat::expect_error(
    ledgr:::ledgr_fold_asset_state_normalize(list(asset_state = 1), "AAA"),
    class = "ledgr_invalid_strategy_state"
  )
  testthat::expect_error(
    ledgr:::ledgr_fold_asset_state_normalize(list(asset_state = list(list())), "AAA"),
    class = "ledgr_invalid_strategy_state"
  )
})

testthat::test_that("mark age counts sessions since the latest finite close", {
  bars_mat <- list(
    close = rbind(
      c(100, NA, NA, 104),
      c(NA, NA, NA, NA)
    )
  )
  testthat::expect_identical(
    ledgr:::ledgr_fold_availability_mark_age(
      bars_mat,
      c("AAA", "BBB"),
      c("AAA", "BBB"),
      3L
    ),
    c(AAA = 2L, BBB = NA_integer_)
  )
  testthat::expect_identical(
    ledgr:::ledgr_fold_availability_mark_age(bars_mat, c("AAA", "BBB"), "AAA", 4L),
    c(AAA = 0L)
  )
})
