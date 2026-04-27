testthat::test_that("function(ctx, params) strategies receive strategy_params and persist provenance", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  strategy <- function(ctx, params) {
    targets <- ctx$targets()
    qty <- sum(abs(params$qty))
    id <- paste0("TEST", "_A")
    if (!is.na(qty)) {
      targets[id] <- qty
    }
    targets
  }

  bt <- ledgr_backtest(
    data = test_bars,
    strategy = strategy,
    strategy_params = list(qty = 2),
    start = "2020-01-01",
    end = "2020-01-05",
    initial_cash = 10000,
    db_path = db_path,
    run_id = "params-run"
  )
  on.exit(close(bt), add = TRUE)

  ledger <- tibble::as_tibble(bt, what = "ledger")
  fills <- ledger[ledger$event_type == "FILL" & ledger$instrument_id == "TEST_A", , drop = FALSE]
  testthat::expect_true(any(as.numeric(fills$qty) == 2))

  opened <- ledgr_test_open_duckdb(db_path)
  on.exit(ledgr_test_close_duckdb(opened$con, opened$drv), add = TRUE)
  provenance <- DBI::dbGetQuery(
    opened$con,
    "SELECT * FROM run_provenance WHERE run_id = 'params-run'"
  )

  testthat::expect_equal(nrow(provenance), 1L)
  testthat::expect_identical(provenance$strategy_type[[1]], "functional")
  testthat::expect_identical(provenance$reproducibility_level[[1]], "tier_1")
  testthat::expect_identical(provenance$strategy_source_capture_method[[1]], "deparse_function")
  testthat::expect_true(grepl("function", provenance$strategy_source[[1]], fixed = TRUE))
  testthat::expect_true(grepl("params", provenance$strategy_source[[1]], fixed = TRUE))
  testthat::expect_match(provenance$strategy_source_hash[[1]], "^[0-9a-f]{64}$")
  testthat::expect_match(provenance$strategy_params_hash[[1]], "^[0-9a-f]{64}$")
  testthat::expect_true(grepl("\"qty\":2", provenance$strategy_params_json[[1]], fixed = TRUE))
  testthat::expect_identical(provenance$ledgr_version[[1]], as.character(utils::packageVersion("ledgr")))
  testthat::expect_identical(provenance$R_version[[1]], as.character(getRversion()))

  created <- DBI::dbGetQuery(
    opened$con,
    "
    SELECT r.created_at_utc AS run_created_at_utc,
           p.created_at_utc AS provenance_created_at_utc
    FROM runs r
    JOIN run_provenance p ON p.run_id = r.run_id
    WHERE r.run_id = 'params-run'
    "
  )
  testthat::expect_identical(
    as.numeric(created$provenance_created_at_utc[[1]]),
    as.numeric(created$run_created_at_utc[[1]])
  )
})

testthat::test_that("function(ctx, params) with empty default strategy_params is valid", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  strategy <- function(ctx, params) {
    targets <- ctx$targets()
    targets["TEST_A"] <- if (identical(params, list())) 1 else 0
    targets
  }

  bt <- ledgr_backtest(
    data = test_bars,
    strategy = strategy,
    start = "2020-01-01",
    end = "2020-01-05",
    initial_cash = 10000,
    db_path = db_path,
    run_id = "empty-params-run"
  )
  on.exit(close(bt), add = TRUE)

  ledger <- tibble::as_tibble(bt, what = "ledger")
  fills <- ledger[ledger$event_type == "FILL" & ledger$instrument_id == "TEST_A", , drop = FALSE]
  testthat::expect_true(any(as.numeric(fills$qty) == 1))
})

testthat::test_that("function(ctx) strategies remain supported and are not Tier 1", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  strategy <- function(ctx) {
    targets <- ctx$targets()
    targets["TEST_A"] <- 1
    targets
  }

  bt <- ledgr_backtest(
    data = test_bars,
    strategy = strategy,
    start = "2020-01-01",
    end = "2020-01-05",
    initial_cash = 10000,
    db_path = db_path,
    run_id = "ctx-run"
  )
  on.exit(close(bt), add = TRUE)

  opened <- ledgr_test_open_duckdb(db_path)
  on.exit(ledgr_test_close_duckdb(opened$con, opened$drv), add = TRUE)
  provenance <- DBI::dbGetQuery(
    opened$con,
    "SELECT reproducibility_level FROM run_provenance WHERE run_id = 'ctx-run'"
  )
  testthat::expect_identical(provenance$reproducibility_level[[1]], "tier_2")
})

testthat::test_that("non-empty strategy_params warn when strategy only accepts ctx", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  strategy <- function(ctx) {
    targets <- ctx$targets()
    targets["TEST_A"] <- 1
    targets
  }

  testthat::expect_warning(
    bt <- ledgr_backtest(
      data = test_bars,
      strategy = strategy,
      strategy_params = list(qty = 5),
      start = "2020-01-01",
      end = "2020-01-05",
      initial_cash = 10000,
      db_path = db_path,
      run_id = "unused-params-run"
    ),
    class = "ledgr_unused_strategy_params"
  )
  on.exit(close(bt), add = TRUE)
})

testthat::test_that("strategy signature and params validation fail clearly", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  bad_signature <- function(ctx, params, extra) ctx$targets()
  testthat::expect_error(
    ledgr_backtest(
      data = test_bars,
      strategy = bad_signature,
      start = "2020-01-01",
      end = "2020-01-05",
      db_path = db_path
    ),
    class = "ledgr_invalid_strategy_signature"
  )

  strategy <- function(ctx, params) ctx$targets()
  testthat::expect_error(
    ledgr_backtest(
      data = test_bars,
      strategy = strategy,
      strategy_params = list(fn = function() 1),
      start = "2020-01-01",
      end = "2020-01-05",
      db_path = tempfile(fileext = ".duckdb")
    ),
    class = "ledgr_invalid_strategy_params"
  )
})

testthat::test_that("strategy params and source changes alter provenance hashes", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  strategy_a <- function(ctx, params) {
    targets <- ctx$targets()
    targets["TEST_A"] <- params$qty
    targets
  }
  strategy_b <- function(ctx, params) {
    targets <- ctx$targets()
    targets["TEST_A"] <- params$qty + 1
    targets
  }

  bt_a <- ledgr_backtest(
    data = test_bars,
    strategy = strategy_a,
    strategy_params = list(qty = 1),
    start = "2020-01-01",
    end = "2020-01-05",
    db_path = db_path,
    run_id = "hash-a"
  )
  on.exit(close(bt_a), add = TRUE)

  bt_b <- ledgr_backtest(
    data = test_bars,
    strategy = strategy_a,
    strategy_params = list(qty = 2),
    start = "2020-01-01",
    end = "2020-01-05",
    db_path = db_path,
    run_id = "hash-b"
  )
  on.exit(close(bt_b), add = TRUE)

  bt_c <- ledgr_backtest(
    data = test_bars,
    strategy = strategy_b,
    strategy_params = list(qty = 1),
    start = "2020-01-01",
    end = "2020-01-05",
    db_path = db_path,
    run_id = "hash-c"
  )
  on.exit(close(bt_c), add = TRUE)

  opened <- ledgr_test_open_duckdb(db_path)
  on.exit(ledgr_test_close_duckdb(opened$con, opened$drv), add = TRUE)
  provenance <- DBI::dbGetQuery(
    opened$con,
    "
    SELECT run_id, strategy_source_hash, strategy_params_hash
    FROM run_provenance
    WHERE run_id IN ('hash-a', 'hash-b', 'hash-c')
    ORDER BY run_id
    "
  )

  testthat::expect_false(identical(
    provenance$strategy_params_hash[provenance$run_id == "hash-a"],
    provenance$strategy_params_hash[provenance$run_id == "hash-b"]
  ))
  testthat::expect_false(identical(
    provenance$strategy_source_hash[provenance$run_id == "hash-a"],
    provenance$strategy_source_hash[provenance$run_id == "hash-c"]
  ))
})

testthat::test_that("R6 strategies are stored as Tier 2 provenance", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  bt <- ledgr_backtest(
    data = test_bars,
    strategy = ledgr:::HoldZeroStrategy$new(),
    start = "2020-01-01",
    end = "2020-01-05",
    initial_cash = 10000,
    db_path = db_path,
    run_id = "r6-run"
  )
  on.exit(close(bt), add = TRUE)

  opened <- ledgr_test_open_duckdb(db_path)
  on.exit(ledgr_test_close_duckdb(opened$con, opened$drv), add = TRUE)
  provenance <- DBI::dbGetQuery(
    opened$con,
    "SELECT strategy_type, reproducibility_level FROM run_provenance WHERE run_id = 'r6-run'"
  )

  testthat::expect_identical(provenance$strategy_type[[1]], "R6_object")
  testthat::expect_identical(provenance$reproducibility_level[[1]], "tier_2")
})
