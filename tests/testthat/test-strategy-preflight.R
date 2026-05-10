testthat::test_that("strategy preflight classifies Tier 1 self-contained strategies", {
  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    targets["TEST_A"] <- params$qty
    targets
  }

  preflight <- ledgr_strategy_preflight(strategy)
  testthat::expect_s3_class(preflight, "ledgr_strategy_preflight")
  testthat::expect_identical(preflight$tier, "tier_1")
  testthat::expect_true(preflight$allowed)
  testthat::expect_identical(preflight$unresolved_symbols, character())
  testthat::expect_identical(preflight$package_dependencies, character())
})

testthat::test_that("strategy preflight classifies non-standard package-qualified calls as Tier 2", {
  strategy <- function(ctx, params) {
    jsonlite::toJSON(list(qty = params$qty), auto_unbox = TRUE)
    ctx$flat()
  }

  preflight <- ledgr_strategy_preflight(strategy)
  testthat::expect_identical(preflight$tier, "tier_2")
  testthat::expect_true(preflight$allowed)
  testthat::expect_identical(preflight$package_dependencies, "jsonlite")
  testthat::expect_identical(preflight$unresolved_symbols, character())
})

testthat::test_that("strategy preflight keeps base/recommended and ledgr exported calls Tier 1", {
  strategy <- function(ctx, params) {
    values <- c(1, 2, 3)
    signal <- signal_return(ctx, lookback = params$lookback)
    selected <- select_top_n(signal, n = 1)
    weights <- weight_equal(selected)
    if (passed_warmup(c(x = stats::sd(values)))) {
      return(target_rebalance(weights, ctx, equity_fraction = 0.5))
    }
    ctx$flat()
  }

  preflight <- ledgr_strategy_preflight(strategy)
  testthat::expect_identical(preflight$tier, "tier_1")
  testthat::expect_true(preflight$allowed)
  testthat::expect_identical(preflight$unresolved_symbols, character())
  testthat::expect_identical(preflight$package_dependencies, character())
})

testthat::test_that("strategy preflight classifies unresolved user helpers as Tier 3", {
  my_helper <- function(ctx) ctx$flat()
  strategy <- function(ctx, params) {
    my_helper(ctx)
  }

  preflight <- ledgr_strategy_preflight(strategy)
  testthat::expect_identical(preflight$tier, "tier_3")
  testthat::expect_false(preflight$allowed)
  testthat::expect_identical(preflight$unresolved_symbols, "my_helper")
  testthat::expect_match(preflight$reason, "my_helper", fixed = TRUE)
})

testthat::test_that("strategy preflight allows resolved external objects as Tier 2", {
  qty <- 1
  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    targets["TEST_A"] <- qty
    targets
  }

  preflight <- ledgr_strategy_preflight(strategy)
  testthat::expect_identical(preflight$tier, "tier_2")
  testthat::expect_true(preflight$allowed)
  testthat::expect_identical(preflight$unresolved_symbols, character())
  testthat::expect_true(any(grepl("qty", preflight$notes, fixed = TRUE)))
})

testthat::test_that("strategy preflight allows explicit ledgr_signal_strategy wrappers as Tier 2", {
  strategy <- ledgr_signal_strategy(function(ctx) c(TEST_A = "LONG"))

  preflight <- ledgr_strategy_preflight(strategy)
  testthat::expect_identical(preflight$tier, "tier_2")
  testthat::expect_true(preflight$allowed)
  testthat::expect_match(preflight$reason, "ledgr_signal_strategy", fixed = TRUE)
  testthat::expect_identical(preflight$unresolved_symbols, character())
})

testthat::test_that("ledgr_run stops Tier 3 strategies before execution", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  snapshot <- ledgr_snapshot_from_df(test_bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  my_helper <- function(ctx) ctx$flat()
  strategy <- function(ctx, params) {
    my_helper(ctx)
  }
  exp <- ledgr_experiment(snapshot, strategy)

  testthat::expect_error(
    ledgr_run(exp, params = list(), run_id = "tier-3-run"),
    "my_helper",
    fixed = TRUE,
    class = "ledgr_strategy_preflight_error"
  )

  opened <- ledgr_test_open_duckdb(db_path)
  on.exit(ledgr_test_close_duckdb(opened$con, opened$drv), add = TRUE)
  rows <- DBI::dbGetQuery(
    opened$con,
    "SELECT run_id FROM runs WHERE run_id = 'tier-3-run'"
  )
  testthat::expect_equal(nrow(rows), 0L)
})

testthat::test_that("single-run force override is not implemented in LDG-1803", {
  testthat::expect_false("force" %in% names(formals(ledgr_run)))
  testthat::expect_false("force" %in% names(formals(ledgr_strategy_preflight)))
})
