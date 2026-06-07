ledgr_sweep_persistence_schema_bars <- function() {
  data.frame(
    instrument_id = rep("AAA", 6L),
    ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:5,
    open = c(100, 101, 102, 103, 104, 105),
    high = c(101, 102, 103, 104, 105, 106),
    low = c(99, 100, 101, 102, 103, 104),
    close = c(100, 102, 101, 104, 103, 106),
    volume = 1000,
    stringsAsFactors = FALSE
  )
}

ledgr_sweep_persistence_schema_sweep <- function() {
  snapshot <- ledgr_snapshot_from_df(ledgr_sweep_persistence_schema_bars())
  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    targets["AAA"] <- params$qty
    targets
  }
  exp <- ledgr_experiment(snapshot, strategy, cost_model = ledgr_cost_zero())
  grid <- ledgr_param_grid(a = list(qty = 1), b = list(qty = 2))
  list(
    snapshot = snapshot,
    sweep = ledgr_sweep(
      exp,
      grid,
      seed = 123L,
      retain = ledgr_sweep_retention("completed")
    )
  )
}

testthat::test_that("saved sweep schema is created and validated", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  testthat::expect_true(ledgr_create_schema(con))
  testthat::expect_true(ledgr_validate_schema(con))

  tables <- DBI::dbGetQuery(
    con,
    "
    SELECT table_name
    FROM information_schema.tables
    WHERE table_schema = 'main'
    "
  )$table_name
  testthat::expect_true(all(c("sweeps", "sweep_candidates", "sweep_returns") %in% tables))

  indexes <- DBI::dbGetQuery(
    con,
    "SELECT index_name, table_name, expressions FROM duckdb_indexes()"
  )
  sweep_return_index <- indexes[
    indexes$index_name == "idx_sweep_returns_timestamp",
    ,
    drop = FALSE
  ]
  testthat::expect_identical(nrow(sweep_return_index), 1L)
  testthat::expect_identical(sweep_return_index$table_name[[1]], "sweep_returns")
  testthat::expect_match(sweep_return_index$expressions[[1]], "sweep_id", fixed = TRUE)
  testthat::expect_match(sweep_return_index$expressions[[1]], "candidate_row", fixed = TRUE)
  testthat::expect_match(sweep_return_index$expressions[[1]], "ts_utc", fixed = TRUE)

  sweep_candidate_cols <- DBI::dbGetQuery(
    con,
    "
    SELECT column_name
    FROM information_schema.columns
    WHERE table_schema = 'main'
      AND table_name = 'sweep_candidates'
    "
  )$column_name
  testthat::expect_true("candidate_id" %in% sweep_candidate_cols)
  testthat::expect_true("candidate_row" %in% sweep_candidate_cols)
  testthat::expect_false("run_id" %in% sweep_candidate_cols)

  version <- DBI::dbGetQuery(
    con,
    "SELECT value FROM ledgr_schema_metadata WHERE key = 'experiment_store_schema_version'"
  )$value[[1]]
  testthat::expect_identical(as.integer(version), ledgr:::ledgr_experiment_store_schema_version)
})

testthat::test_that("saved sweep schema enforces compact keys and nullable first returns", {
  fixture <- ledgr_sweep_persistence_schema_sweep()
  on.exit(ledgr_snapshot_close(fixture$snapshot), add = TRUE)
  sweep <- fixture$sweep

  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  ledgr_create_schema(con)

  parent <- ledgr:::ledgr_sweep_storage_parent_row(sweep)
  candidates <- ledgr:::ledgr_sweep_storage_candidate_rows(sweep)
  returns <- ledgr:::ledgr_sweep_storage_return_rows(sweep)

  DBI::dbAppendTable(con, "sweeps", parent)
  DBI::dbAppendTable(con, "sweep_candidates", candidates)
  DBI::dbAppendTable(con, "sweep_returns", returns)

  first_returns <- DBI::dbGetQuery(
    con,
    "
    SELECT candidate_row, pulse_index, period_return
    FROM sweep_returns
    WHERE pulse_index = 1
    ORDER BY candidate_row
    "
  )
  testthat::expect_identical(first_returns$pulse_index, c(1L, 1L))
  testthat::expect_true(all(is.na(first_returns$period_return)))

  testthat::expect_error(
    DBI::dbAppendTable(con, "sweep_returns", returns[1, , drop = FALSE])
  )
  try(DBI::dbExecute(con, "ROLLBACK"), silent = TRUE)

  bad_candidate <- candidates[1, , drop = FALSE]
  bad_candidate$candidate_row <- 99L
  bad_candidate$candidate_id <- "bad-status"
  bad_candidate$status <- "RUNNING"
  testthat::expect_error(DBI::dbAppendTable(con, "sweep_candidates", bad_candidate))
})

testthat::test_that("saved sweep storage projections use canonical JSON and validate denormalized identity", {
  fixture <- ledgr_sweep_persistence_schema_sweep()
  on.exit(ledgr_snapshot_close(fixture$snapshot), add = TRUE)
  sweep <- fixture$sweep

  parent <- ledgr:::ledgr_sweep_storage_parent_row(sweep)
  candidates <- ledgr:::ledgr_sweep_storage_candidate_rows(sweep)
  returns <- ledgr:::ledgr_sweep_storage_return_rows(sweep)

  json_cols <- intersect(ledgr:::ledgr_sweep_storage_json_columns, names(parent))
  for (col in json_cols) {
    testthat::expect_identical(
      parent[[col]][[1]],
      as.character(ledgr:::canonical_json(parent[[col]][[1]])),
      info = col
    )
  }
  candidate_json_cols <- intersect(ledgr:::ledgr_sweep_storage_json_columns, names(candidates))
  for (col in candidate_json_cols) {
    testthat::expect_identical(
      candidates[[col]][[1]],
      as.character(ledgr:::canonical_json(candidates[[col]][[1]])),
      info = col
    )
  }

  testthat::expect_identical(candidates$candidate_row, c(1L, 2L))
  testthat::expect_identical(candidates$cost_model_hash, rep(attr(sweep, "cost_model_hash"), 2L))
  testthat::expect_identical(candidates$metric_context_hash, rep(attr(sweep, "metric_context_hash"), 2L))
  testthat::expect_identical(
    candidates$params_json[[1]],
    as.character(ledgr:::canonical_json(list(qty = 1)))
  )
  testthat::expect_identical(
    returns$pulse_index[returns$candidate_row == 1L],
    seq_len(sum(returns$candidate_row == 1L))
  )

  corrupted <- sweep
  candidate_features <- attr(corrupted, "candidate_features", exact = TRUE)
  candidate_features$feature_set_hash[[1]] <- "not-the-provenance-hash"
  attr(corrupted, "candidate_features") <- candidate_features
  testthat::expect_error(
    ledgr:::ledgr_sweep_storage_candidate_rows(corrupted),
    class = "ledgr_sweep_storage_identity_mismatch"
  )
})
