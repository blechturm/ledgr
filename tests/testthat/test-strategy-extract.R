testthat::test_that("ledgr_extract_strategy returns Tier 1 source metadata without evaluation", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  strategy <- function(ctx, params) {
    targets <- ctx$targets()
    targets["TEST_A"] <- params$qty
    targets
  }

  bt <- ledgr_backtest(
    data = test_bars,
    strategy = strategy,
    strategy_params = list(qty = 2),
    start = "2020-01-01",
    end = "2020-01-05",
    db_path = db_path,
    run_id = "extract-tier-1"
  )
  on.exit(close(bt), add = TRUE)

  extracted <- ledgr_extract_strategy(db_path, "extract-tier-1")
  testthat::expect_s3_class(extracted, "ledgr_extracted_strategy")
  testthat::expect_false("strategy_function" %in% names(extracted))
  testthat::expect_identical(extracted$reproducibility_level, "tier_1")
  testthat::expect_equal(extracted$strategy_params$qty, 2)
  testthat::expect_true(grepl("function", extracted$strategy_source_text, fixed = TRUE))
  testthat::expect_true(extracted$hash_verified)
  testthat::expect_identical(extracted$trust, FALSE)

  printed <- utils::capture.output(print(extracted))
  testthat::expect_true(any(grepl("ledgr Extracted Strategy", printed, fixed = TRUE)))
  testthat::expect_false(any(grepl("targets <- ctx", printed, fixed = TRUE)))
})

testthat::test_that("ledgr_extract_strategy trust TRUE verifies hash and returns a function", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  strategy <- function(ctx, params) {
    targets <- ctx$targets()
    targets["TEST_A"] <- params$qty
    targets
  }
  bt <- ledgr_backtest(
    data = test_bars,
    strategy = strategy,
    strategy_params = list(qty = 1),
    start = "2020-01-01",
    end = "2020-01-05",
    db_path = db_path,
    run_id = "extract-trusted"
  )
  on.exit(close(bt), add = TRUE)

  extracted <- ledgr_extract_strategy(db_path, "extract-trusted", trust = TRUE)
  testthat::expect_true(extracted$hash_verified)
  testthat::expect_true(extracted$trust)
  testthat::expect_true(is.function(extracted$strategy_function))
  testthat::expect_identical(names(formals(extracted$strategy_function)), c("ctx", "params"))
})

testthat::test_that("ledgr_extract_strategy detects source hash mismatch", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  strategy <- function(ctx, params) ctx$targets()
  bt <- ledgr_backtest(
    data = test_bars,
    strategy = strategy,
    strategy_params = list(),
    start = "2020-01-01",
    end = "2020-01-05",
    db_path = db_path,
    run_id = "extract-mismatch"
  )
  on.exit(close(bt), add = TRUE)

  opened <- ledgr_test_open_duckdb(db_path)
  on.exit(ledgr_test_close_duckdb(opened$con, opened$drv), add = TRUE)
  DBI::dbExecute(
    opened$con,
    "UPDATE run_provenance SET strategy_source = ? WHERE run_id = ?",
    params = list("function(ctx, params) ctx$targets()", "extract-mismatch")
  )

  testthat::expect_error(
    ledgr_extract_strategy(db_path, "extract-mismatch"),
    class = "ledgr_strategy_hash_mismatch"
  )
})

testthat::test_that("ledgr_extract_strategy trust FALSE does not parse or evaluate source", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  strategy <- function(ctx, params) ctx$targets()
  bt <- ledgr_backtest(
    data = test_bars,
    strategy = strategy,
    strategy_params = list(),
    start = "2020-01-01",
    end = "2020-01-05",
    db_path = db_path,
    run_id = "extract-no-eval"
  )
  on.exit(close(bt), add = TRUE)

  replacement <- "function(ctx, params) {"
  opened <- ledgr_test_open_duckdb(db_path)
  on.exit(ledgr_test_close_duckdb(opened$con, opened$drv), add = TRUE)
  DBI::dbExecute(
    opened$con,
    "UPDATE run_provenance SET strategy_source = ?, strategy_source_hash = ? WHERE run_id = ?",
    params = list(replacement, digest::digest(replacement, algo = "sha256"), "extract-no-eval")
  )

  extracted <- ledgr_extract_strategy(db_path, "extract-no-eval", trust = FALSE)
  testthat::expect_identical(extracted$strategy_source_text, replacement)
  testthat::expect_false("strategy_function" %in% names(extracted))
  testthat::expect_error(
    ledgr_extract_strategy(db_path, "extract-no-eval", trust = TRUE),
    class = "ledgr_strategy_parse_failed"
  )
})

testthat::test_that("ledgr_extract_strategy surfaces Tier 2 warnings", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  strategy <- function(ctx) ctx$targets()
  bt <- ledgr_backtest(
    data = test_bars,
    strategy = strategy,
    start = "2020-01-01",
    end = "2020-01-05",
    db_path = db_path,
    run_id = "extract-tier-2"
  )
  on.exit(close(bt), add = TRUE)

  extracted <- ledgr_extract_strategy(db_path, "extract-tier-2")
  testthat::expect_identical(extracted$reproducibility_level, "tier_2")
  testthat::expect_true(any(grepl("may depend on external state", extracted$warnings, fixed = TRUE)))
  printed <- utils::capture.output(print(extracted))
  testthat::expect_true(any(grepl("Warnings:", printed, fixed = TRUE)))

  trusted <- ledgr_extract_strategy(db_path, "extract-tier-2", trust = TRUE)
  testthat::expect_true(is.function(trusted$strategy_function))
  testthat::expect_true(any(grepl("may depend on external state", trusted$warnings, fixed = TRUE)))
})

testthat::test_that("ledgr_extract_strategy handles legacy pre-provenance runs without migration", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)
  opened <- ledgr_test_open_duckdb(db_path)
  on.exit(ledgr_test_close_duckdb(opened$con, opened$drv), add = TRUE)
  con <- opened$con

  DBI::dbExecute(con, "
    CREATE TABLE runs (
      run_id TEXT NOT NULL PRIMARY KEY,
      created_at_utc TIMESTAMP,
      engine_version TEXT,
      config_json TEXT,
      config_hash TEXT,
      data_hash TEXT,
      snapshot_id TEXT,
      status TEXT,
      error_msg TEXT
    )
  ")
  DBI::dbExecute(
    con,
    "INSERT INTO runs (run_id, created_at_utc, engine_version, config_json, config_hash, data_hash, snapshot_id, status, error_msg)
     VALUES ('legacy-extract', '2020-01-01 00:00:00', 'legacy', '{}', 'cfg', 'data', 'snap', 'DONE', NULL)"
  )

  before_tables <- DBI::dbGetQuery(con, "SELECT table_name FROM information_schema.tables WHERE table_schema = 'main' ORDER BY table_name")
  extracted <- ledgr_extract_strategy(db_path, "legacy-extract")
  after_tables <- DBI::dbGetQuery(con, "SELECT table_name FROM information_schema.tables WHERE table_schema = 'main' ORDER BY table_name")

  testthat::expect_identical(after_tables, before_tables)
  testthat::expect_identical(extracted$reproducibility_level, "legacy")
  testthat::expect_true(is.na(extracted$strategy_source_text))
  testthat::expect_false(extracted$hash_verified)
  testthat::expect_true(any(grepl("No stored strategy source", extracted$warnings, fixed = TRUE)))
  testthat::expect_error(
    ledgr_extract_strategy(db_path, "legacy-extract", trust = TRUE),
    class = "ledgr_strategy_source_unavailable"
  )
})
