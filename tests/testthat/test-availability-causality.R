# ledgr-test-file-profile: review
testthat::test_that("provider resolves facts only after effective and knowledge time", {
  status <- ledgr_facts_trading_status(data.frame(
    instrument_id = "AAA",
    effective_from = as.POSIXct(rep("2020-01-01", 3), tz = "UTC"),
    knowledge_time = as.POSIXct(c("2019-12-31", "2019-12-31", "2020-01-03"), tz = "UTC"),
    status = c("active", "halted", "active"),
    source = c("low_a", "low_b", "high"),
    precedence = c(1L, 1L, 5L)
  ))
  snapshot <- availability_runtime_fixture(status = status)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  seen <- new.env(parent = emptyenv())
  seen$observed <- logical()
  strategy <- function(ctx, params) {
    seen$observed <- c(seen$observed, unname(ctx$buyable[["AAA"]]))
    ledgr_strategy_result(ctx$hold(), observed = unname(ctx$buyable[["AAA"]]))
  }
  exp <- ledgr_experiment(opening = ledgr_opening(cash = 100000),
    snapshot,
    strategy,
    valuation_policy = ledgr_valuation_stale(1),
    cost_model = ledgr_cost_zero(),
    portfolio_state = list(observed = NA)
  )
  bt <- ledgr_run(exp)
  on.exit(close(bt), add = TRUE)
  testthat::expect_identical(seen$observed[1:3], c(FALSE, FALSE, TRUE))

  config <- list(
    data = list(snapshot_id = snapshot$snapshot_id),
    universe = list(instrument_ids = "AAA"),
    availability = list(
      active = TRUE,
      declared_families = c("sessions", "trading_status"),
      universe_rule = NULL
    )
  )
  provider <- ledgr_availability_provider(
    get_connection(snapshot),
    config,
    ledgr_snapshot_info(snapshot)$snapshot_hash[[1L]]
  )
  # LDG-3075: the provider's bar-history closure had no product reader and
  # is removed; history is read only from the shared substrate.
  testthat::expect_named(
    provider,
    c(
      "facts", "decision_view", "execution_view", "identity",
      "sessions", "valuation_policy"
    )
  )
  testthat::expect_identical(
    unname(provider$facts(as.POSIXct("2020-01-02", tz = "UTC"))$status),
    "conflicting"
  )
  testthat::expect_identical(
    unname(provider$execution_view(as.POSIXct("2020-01-03", tz = "UTC"), "AAA")$status),
    "active"
  )
  testthat::expect_identical(
    provider$decision_view(
      as.POSIXct("2020-01-02", tz = "UTC"),
      c(AAA = 0)
    )$axis,
    "AAA"
  )
  testthat::expect_identical(
    provider$identity()$provider_version,
    ledgr_availability_provider_version()
  )
})

testthat::test_that("future facts change identity without rewriting prior context", {
  base_rows <- data.frame(
    instrument_id = c("AAA", "AAA"),
    effective_from = as.POSIXct(rep("2020-01-01", 2), tz = "UTC"),
    knowledge_time = as.POSIXct(rep("2019-12-31", 2), tz = "UTC"),
    status = c("active", "halted"),
    source = c("a", "b"),
    precedence = c(1L, 1L)
  )
  future_rows <- rbind(
    base_rows,
    data.frame(
      instrument_id = "AAA",
      effective_from = as.POSIXct("2020-02-01", tz = "UTC"),
      knowledge_time = as.POSIXct("2020-02-01", tz = "UTC"),
      status = "active",
      source = "future",
      precedence = 5L
    )
  )
  snapshots <- list(
    availability_runtime_fixture(status = ledgr_facts_trading_status(base_rows)),
    availability_runtime_fixture(status = ledgr_facts_trading_status(future_rows))
  )
  on.exit(lapply(snapshots, ledgr_snapshot_close), add = TRUE)
  seen <- lapply(seq_along(snapshots), function(i) {
    out <- new.env(parent = emptyenv())
    out$observed <- logical()
    out
  })
  strategy_for <- function(index) function(ctx, params) {
    seen[[index]]$observed <- c(
      seen[[index]]$observed, unname(ctx$buyable[["AAA"]])
    )
    ledgr_strategy_result(ctx$hold(), observed = unname(ctx$buyable[["AAA"]]))
  }
  runs <- lapply(seq_along(snapshots), function(index) {
    snapshot <- snapshots[[index]]
    ledgr_run(ledgr_experiment(opening = ledgr_opening(cash = 100000),
      snapshot,
      strategy_for(index),
      valuation_policy = ledgr_valuation_stale(1),
      cost_model = ledgr_cost_zero(),
      portfolio_state = list(observed = NA)
    ))
  })
  on.exit(lapply(runs, close), add = TRUE)
  testthat::expect_identical(
    seen[[1L]]$observed,
    seen[[2L]]$observed
  )
  testthat::expect_false(identical(
    ledgr_snapshot_info(snapshots[[1L]])$snapshot_hash[[1L]],
    ledgr_snapshot_info(snapshots[[2L]])$snapshot_hash[[1L]]
  ))
  testthat::expect_false(identical(
    ledgr_run_info(snapshots[[1L]], runs[[1L]]$run_id)$config_hash[[1L]],
    ledgr_run_info(snapshots[[2L]], runs[[2L]]$run_id)$config_hash[[1L]]
  ))
})
