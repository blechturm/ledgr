ledgr_test_replace_run_provenance <- function(db_path, run_id, values) {
  opened <- ledgr_test_open_duckdb(db_path)
  con <- opened$con
  drv <- opened$drv
  on.exit({
    suppressWarnings(try(DBI::dbExecute(con, "CHECKPOINT"), silent = TRUE))
    suppressWarnings(try(DBI::dbDisconnect(con, shutdown = TRUE), silent = TRUE))
    suppressWarnings(try(duckdb::duckdb_shutdown(drv), silent = TRUE))
  }, add = TRUE)

  row <- DBI::dbGetQuery(
    con,
    "SELECT * FROM run_provenance WHERE run_id = ?",
    params = list(run_id)
  )
  testthat::expect_identical(nrow(row), 1L)
  for (nm in names(values)) {
    testthat::expect_true(nm %in% names(row))
    changed <- DBI::dbExecute(
      con,
      sprintf("UPDATE run_provenance SET %s = ? WHERE run_id = ?", DBI::dbQuoteIdentifier(con, nm)),
      params = list(values[[nm]], run_id)
    )
    testthat::expect_identical(as.integer(changed), 1L)
  }

  updated <- DBI::dbGetQuery(
    con,
    "SELECT * FROM run_provenance WHERE run_id = ?",
    params = list(run_id)
  )
  testthat::expect_identical(nrow(updated), 1L)
  for (nm in names(values)) {
    testthat::expect_identical(updated[[nm]][[1]], values[[nm]])
  }
  invisible(TRUE)
}

testthat::test_that("ledgr_extract_strategy returns Tier 1 source metadata without evaluation", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  strategy <- function(ctx, params) {
    targets <- ctx$flat()
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
  close(bt)
  snapshot <- ledgr_test_snapshot_for_run(db_path, bt)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  extracted <- ledgr_extract_strategy(snapshot, "extract-tier-1")
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
    targets <- ctx$flat()
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
  close(bt)
  snapshot <- ledgr_test_snapshot_for_run(db_path, bt)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  extracted <- ledgr_extract_strategy(snapshot, "extract-trusted", trust = TRUE)
  testthat::expect_true(extracted$hash_verified)
  testthat::expect_true(extracted$trust)
  testthat::expect_true(is.function(extracted$strategy_function))
  testthat::expect_identical(names(formals(extracted$strategy_function)), c("ctx", "params"))
})

testthat::test_that("ledgr_extract_strategy detects source hash mismatch", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  external_qty <- 0
  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    targets["TEST_A"] <- external_qty
    targets
  }
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
  close(bt)
  snapshot <- ledgr_test_snapshot_for_run(db_path, bt)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  ledgr_test_replace_run_provenance(
    db_path,
    "extract-mismatch",
    list(
      strategy_source = "function(ctx, params) ctx$flat()",
      strategy_source_hash = "definitely-not-the-current-source-hash"
    )
  )

  testthat::expect_error(
    ledgr_extract_strategy(snapshot, "extract-mismatch"),
    class = "ledgr_strategy_hash_mismatch"
  )
})

testthat::test_that("ledgr_extract_strategy trust FALSE does not parse or evaluate source", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  external_qty <- 0
  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    targets["TEST_A"] <- external_qty
    targets
  }
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
  close(bt)
  snapshot <- ledgr_test_snapshot_for_run(db_path, bt)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  replacement <- "function(ctx, params) {"
  ledgr_test_replace_run_provenance(
    db_path,
    "extract-no-eval",
    list(
      strategy_source = replacement,
      strategy_source_hash = digest::digest(replacement, algo = "sha256")
    )
  )

  extracted <- ledgr_extract_strategy(snapshot, "extract-no-eval", trust = FALSE)
  testthat::expect_identical(extracted$strategy_source_text, replacement)
  testthat::expect_false("strategy_function" %in% names(extracted))
})

testthat::test_that("ledgr_extract_strategy trust TRUE reports parse failures", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    targets["TEST_A"] <- 1
    targets
  }
  bt <- ledgr_backtest(
    data = test_bars,
    strategy = strategy,
    start = "2020-01-01",
    end = "2020-01-05",
    db_path = db_path,
    run_id = "extract-parse-failed"
  )
  on.exit(close(bt), add = TRUE)
  close(bt)
  snapshot <- ledgr_test_snapshot_for_run(db_path, bt)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  replacement <- "function(ctx, params) {"
  ledgr_test_replace_run_provenance(
    db_path,
    "extract-parse-failed",
    list(
      strategy_source = replacement,
      strategy_source_hash = digest::digest(replacement, algo = "sha256")
    )
  )

  testthat::expect_error(
    ledgr_extract_strategy(snapshot, "extract-parse-failed", trust = TRUE),
    class = "ledgr_strategy_parse_failed"
  )
})

testthat::test_that("ledgr_extract_strategy surfaces Tier 2 warnings", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  external_qty <- 0
  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    targets["TEST_A"] <- external_qty
    targets
  }
  bt <- ledgr_backtest(
    data = test_bars,
    strategy = strategy,
    start = "2020-01-01",
    end = "2020-01-05",
    db_path = db_path,
    run_id = "extract-tier-2"
  )
  on.exit(close(bt), add = TRUE)
  close(bt)
  snapshot <- ledgr_test_snapshot_for_run(db_path, bt)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  source <- "function(ctx, params) { targets <- ctx$flat(); targets }"
  ledgr_test_replace_run_provenance(
    db_path,
    "extract-tier-2",
    list(
      strategy_source = source,
      strategy_source_hash = digest::digest(source, algo = "sha256"),
      strategy_source_capture_method = "deparse_function",
      reproducibility_level = "tier_2"
    )
  )

  extracted <- ledgr_extract_strategy(snapshot, "extract-tier-2")
  testthat::expect_identical(extracted$reproducibility_level, "tier_2")
  testthat::expect_true(any(grepl("may depend on external state", extracted$warnings, fixed = TRUE)))
  printed <- utils::capture.output(print(extracted))
  testthat::expect_true(any(grepl("Warnings:", printed, fixed = TRUE)))

  trusted <- ledgr_extract_strategy(snapshot, "extract-tier-2", trust = TRUE)
  testthat::expect_true(is.function(trusted$strategy_function))
  testthat::expect_true(any(grepl("may depend on external state", trusted$warnings, fixed = TRUE)))
})

testthat::test_that("ledgr_extract_strategy handles legacy pre-provenance runs without migration", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)
  opened <- ledgr_test_open_duckdb(db_path)
  con <- opened$con

  DBI::dbExecute(con, "
    CREATE TABLE snapshots (
      snapshot_id TEXT NOT NULL PRIMARY KEY,
      status TEXT NOT NULL,
      created_at_utc TIMESTAMP NOT NULL,
      sealed_at_utc TIMESTAMP,
      snapshot_hash TEXT,
      meta_json TEXT
    )
  ")
  DBI::dbExecute(con, "
    CREATE TABLE snapshot_instruments (
      snapshot_id TEXT NOT NULL,
      instrument_id TEXT NOT NULL,
      meta_json TEXT,
      PRIMARY KEY (snapshot_id, instrument_id)
    )
  ")
  DBI::dbExecute(con, "
    CREATE TABLE snapshot_bars (
      snapshot_id TEXT NOT NULL,
      instrument_id TEXT NOT NULL,
      ts_utc TIMESTAMP NOT NULL,
      open DOUBLE NOT NULL,
      high DOUBLE NOT NULL,
      low DOUBLE NOT NULL,
      close DOUBLE NOT NULL,
      volume DOUBLE,
      PRIMARY KEY (snapshot_id, instrument_id, ts_utc)
    )
  ")
  DBI::dbExecute(con, "
    INSERT INTO snapshots (
      snapshot_id, status, created_at_utc, sealed_at_utc, snapshot_hash, meta_json
    ) VALUES (
      'snap', 'SEALED', TIMESTAMP '2020-01-01 00:00:00',
      TIMESTAMP '2020-01-01 00:00:00', 'legacy-hash', '{}'
    )
  ")
  DBI::dbExecute(con, "
    INSERT INTO snapshot_instruments (snapshot_id, instrument_id, meta_json)
    VALUES ('snap', 'TEST_A', '{}')
  ")
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
  ledgr_test_close_duckdb(opened$con, opened$drv)
  snapshot <- new_ledgr_snapshot(db_path, "snap")
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  extracted <- ledgr_extract_strategy(snapshot, "legacy-extract")

  reopened <- ledgr_test_open_duckdb(db_path)
  after_tables <- DBI::dbGetQuery(reopened$con, "SELECT table_name FROM information_schema.tables WHERE table_schema = 'main' ORDER BY table_name")
  ledgr_test_close_duckdb(reopened$con, reopened$drv)

  testthat::expect_identical(after_tables, before_tables)
  testthat::expect_identical(extracted$reproducibility_level, "legacy")
  testthat::expect_true(is.na(extracted$strategy_source_text))
  testthat::expect_false(extracted$hash_verified)
  testthat::expect_true(any(grepl("No stored strategy source", extracted$warnings, fixed = TRUE)))
  testthat::expect_error(
    ledgr_extract_strategy(snapshot, "legacy-extract", trust = TRUE),
    class = "ledgr_strategy_source_unavailable"
  )
})
