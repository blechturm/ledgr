ledgr_sweep_persistence_api_bars <- function(offset = 0) {
  data.frame(
    instrument_id = rep("AAA", 6L),
    ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:5,
    open = c(100, 101, 102, 103, 104, 105) + offset,
    high = c(101, 102, 103, 104, 105, 106) + offset,
    low = c(99, 100, 101, 102, 103, 104) + offset,
    close = c(100, 102, 101, 104, 103, 106) + offset,
    volume = 1000,
    stringsAsFactors = FALSE
  )
}

ledgr_sweep_persistence_api_sweep <- function(snapshot) {
  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    targets["AAA"] <- params$qty
    targets
  }
  exp <- ledgr_experiment(snapshot, strategy, cost_model = ledgr_cost_zero())
  grid <- ledgr_param_grid(a = list(qty = 1), b = list(qty = 2))
  ledgr_sweep(
    exp,
    grid,
    seed = 123L,
    retain = ledgr_sweep_retention("completed")
  )
}

testthat::test_that("saved sweeps save, list, open, and inspect compact artifacts", {
  snapshot <- ledgr_snapshot_from_df(
    ledgr_sweep_persistence_api_bars(),
    db_path = tempfile(fileext = ".duckdb"),
    snapshot_id = "api_snapshot"
  )
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  sweep <- ledgr_sweep_persistence_api_sweep(snapshot)
  original_sweep_id <- attr(sweep, "sweep_id")

  saved_id <- ledgr_sweep_save(sweep, snapshot, sweep_id = "saved_api", note = "reviewed")
  testthat::expect_identical(saved_id, "saved_api")
  testthat::expect_identical(attr(sweep, "sweep_id"), original_sweep_id)
  default_id <- ledgr_sweep_save(sweep, snapshot)
  testthat::expect_identical(default_id, original_sweep_id)

  con <- ledgr:::get_connection(snapshot)
  DBI::dbExecute(
    con,
    "UPDATE sweeps SET created_at_utc = CAST('2020-01-01 00:00:00' AS TIMESTAMP) WHERE sweep_id = ?",
    params = list("saved_api")
  )
  DBI::dbExecute(
    con,
    "UPDATE sweeps SET created_at_utc = CAST('2020-01-02 00:00:00' AS TIMESTAMP) WHERE sweep_id = ?",
    params = list(original_sweep_id)
  )

  saved <- ledgr_sweep_list(snapshot)
  testthat::expect_s3_class(saved, "ledgr_sweep_list")
  testthat::expect_identical(
    names(saved),
    c(
      "sweep_id", "created_at_utc", "engine_version", "sweep_schema_version",
      "n_candidates", "n_completed", "retention_returns", "note"
    )
  )
  testthat::expect_identical(saved$sweep_id, c(original_sweep_id, "saved_api"))
  testthat::expect_identical(saved$n_candidates, c(2L, 2L))
  testthat::expect_identical(saved$n_completed, c(2L, 2L))
  testthat::expect_identical(saved$retention_returns, c("completed", "completed"))
  testthat::expect_identical(saved$note, c(NA_character_, "reviewed"))

  reopened <- ledgr_sweep_open(snapshot, "saved_api")
  testthat::expect_s3_class(reopened, "ledgr_sweep_results")
  testthat::expect_s3_class(reopened, "ledgr_saved_sweep_results")
  testthat::expect_identical(attr(reopened, "sweep_id"), "saved_api")
  testthat::expect_identical(reopened$candidate_id, sweep$candidate_id)
  testthat::expect_identical(reopened$candidate_row, sweep$candidate_row)
  testthat::expect_identical(reopened$status, sweep$status)
  testthat::expect_equal(reopened$total_return, sweep$total_return)
  testthat::expect_identical(attr(reopened, "snapshot_id"), attr(sweep, "snapshot_id"))
  testthat::expect_identical(attr(reopened, "snapshot_hash"), attr(sweep, "snapshot_hash"))
  testthat::expect_identical(attr(reopened, "cost_model_hash"), attr(sweep, "cost_model_hash"))
  testthat::expect_identical(attr(reopened, "metric_context_hash"), attr(sweep, "metric_context_hash"))
  testthat::expect_identical(attr(reopened, "sweep_retention"), ledgr_sweep_retention("completed"))

  original_returns <- ledgr_sweep_returns(sweep)
  reopened_returns <- ledgr_sweep_returns(reopened)
  testthat::expect_identical(unique(reopened_returns$sweep_id), "saved_api")
  original_returns$sweep_id <- "saved_api"
  testthat::expect_equal(reopened_returns, original_returns)
  testthat::expect_true(is.na(reopened_returns$period_return[[1]]))

  info <- ledgr_sweep_info(reopened)
  testthat::expect_s3_class(info, "ledgr_sweep_info")
  testthat::expect_identical(info$sweep_id, "saved_api")
  testthat::expect_identical(info$n_candidates, 2L)
  testthat::expect_identical(info$n_completed, 2L)
  testthat::expect_identical(info$retention_returns, "completed")
  testthat::expect_true(isTRUE(info$saved_artifact$saved))
  testthat::expect_error(ledgr_sweep_info("saved_api"), class = "ledgr_invalid_args")
})

testthat::test_that("saved sweep validation fails before partial writes", {
  snapshot <- ledgr_snapshot_from_df(
    ledgr_sweep_persistence_api_bars(),
    db_path = tempfile(fileext = ".duckdb"),
    snapshot_id = "validation_snapshot"
  )
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  sweep <- ledgr_sweep_persistence_api_sweep(snapshot)

  bad_ids <- list(
    NA_character_,
    "",
    "   ",
    c("a", "b"),
    paste(rep("x", 257L), collapse = ""),
    paste0("bad", intToUtf8(233L))
  )
  for (bad_id in bad_ids) {
    testthat::expect_error(
      ledgr_sweep_save(sweep, snapshot, sweep_id = bad_id),
      class = "ledgr_invalid_sweep_id"
    )
  }
  testthat::expect_error(
    ledgr_sweep_save(sweep, snapshot, sweep_id = "bad-note", note = c("a", "b")),
    class = "ledgr_invalid_args"
  )
  testthat::expect_identical(nrow(ledgr_sweep_list(snapshot)), 0L)

  ledgr_sweep_save(sweep, snapshot, sweep_id = "dup")
  testthat::expect_error(
    ledgr_sweep_save(sweep, snapshot, sweep_id = "dup"),
    class = "ledgr_sweep_id_exists"
  )
  testthat::expect_error(
    ledgr_sweep_open(snapshot, "missing"),
    class = "ledgr_sweep_not_found"
  )
})

testthat::test_that("saved sweep open validates snapshot identity and schema compatibility", {
  db_path <- tempfile(fileext = ".duckdb")
  snapshot <- ledgr_snapshot_from_df(
    ledgr_sweep_persistence_api_bars(),
    db_path = db_path,
    snapshot_id = "open_snapshot"
  )
  other_snapshot <- ledgr_snapshot_from_df(
    ledgr_sweep_persistence_api_bars(offset = 10),
    db_path = db_path,
    snapshot_id = "other_snapshot"
  )
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  on.exit(ledgr_snapshot_close(other_snapshot), add = TRUE)
  sweep <- ledgr_sweep_persistence_api_sweep(snapshot)
  ledgr_sweep_save(sweep, snapshot, sweep_id = "open_me")

  testthat::expect_error(
    ledgr_sweep_open(other_snapshot, "open_me"),
    class = "ledgr_sweep_snapshot_not_found"
  )

  con <- ledgr:::get_connection(snapshot)
  DBI::dbExecute(
    con,
    "UPDATE snapshots SET snapshot_hash = 'not-the-saved-hash' WHERE snapshot_id = 'open_snapshot'"
  )
  testthat::expect_error(
    ledgr_sweep_open(snapshot, "open_me"),
    class = "ledgr_sweep_snapshot_hash_mismatch"
  )
  DBI::dbExecute(
    con,
    "UPDATE snapshots SET snapshot_hash = ? WHERE snapshot_id = 'open_snapshot'",
    params = list(attr(sweep, "snapshot_hash"))
  )

  DBI::dbExecute(
    con,
    "UPDATE sweeps SET sweep_schema_version = ? WHERE sweep_id = 'open_me'",
    params = list(ledgr:::ledgr_saved_sweep_schema_version + 1L)
  )
  testthat::expect_error(
    ledgr_sweep_open(snapshot, "open_me"),
    class = "ledgr_sweep_schema_incompatible"
  )
})

testthat::test_that("saved sweep print methods expose retention and identity summary", {
  snapshot <- ledgr_snapshot_from_df(
    ledgr_sweep_persistence_api_bars(),
    db_path = tempfile(fileext = ".duckdb"),
    snapshot_id = "print_snapshot"
  )
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  sweep <- ledgr_sweep_persistence_api_sweep(snapshot)
  ledgr_sweep_save(sweep, snapshot, sweep_id = "print_me")
  reopened <- ledgr_sweep_open(snapshot, "print_me")

  printed <- utils::capture.output(print(reopened))
  testthat::expect_true(any(grepl("Retention returns: completed", printed, fixed = TRUE)))
  testthat::expect_true(any(grepl("Snapshot hash:", printed, fixed = TRUE)))
  testthat::expect_true(any(grepl("Cost model hash:", printed, fixed = TRUE)))
  testthat::expect_true(any(grepl("Saved artifact: schema", printed, fixed = TRUE)))

  info_print <- utils::capture.output(print(ledgr_sweep_info(reopened)))
  testthat::expect_true(any(grepl("ledgr Sweep Info", info_print, fixed = TRUE)))
  testthat::expect_true(any(grepl("Saved artifact", info_print, fixed = TRUE)))
})
