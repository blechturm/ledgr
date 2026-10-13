# ledgr-test-file-profile: review

testthat::test_that("[LTB-0151] fresh and reopened facts retain rule-3 identity and detect timestamp tampering", {
  manifest <- ws10_read_oracle_manifest()
  snapshot_record <- manifest[
    manifest$record_type == "snapshot",
    ,
    drop = FALSE
  ]
  db_path <- tempfile(fileext = ".duckdb")
  snapshot <- ws10_fact_snapshot(db_path)
  on.exit(try(ledgr_snapshot_close(snapshot), silent = TRUE), add = TRUE)
  snapshot_id <- snapshot$snapshot_id
  fresh_hash <- ledgr_snapshot_info(snapshot)$snapshot_hash[[1L]]
  fresh <- ledgr_facts_resolve(
    snapshot,
    "membership",
    "matrix",
    ws14_utc("2020-01-03 16:00:00"),
    c("AAA", "BBB", "CHILD")
  )
  testthat::expect_identical(fresh_hash, snapshot_record$identity_hash[[1L]])
  ledgr_snapshot_close(snapshot)

  reopened <- ledgr_snapshot_open(db_path, snapshot_id, verify = FALSE)
  on.exit(try(ledgr_snapshot_close(reopened), silent = TRUE), add = TRUE)
  reopened_hash <- ledgr_snapshot_info(reopened)$snapshot_hash[[1L]]
  reopened_result <- ledgr_facts_resolve(
    reopened,
    "membership",
    "matrix",
    ws14_utc("2020-01-03 16:00:00"),
    c("AAA", "BBB", "CHILD")
  )
  testthat::expect_identical(reopened_hash, fresh_hash)
  testthat::expect_identical(reopened_result$rows, fresh$rows)
  testthat::expect_identical(reopened_result$evidence, fresh$evidence)

  con <- ledgr:::get_connection(reopened)
  changed <- DBI::dbExecute(
    con,
    paste(
      "UPDATE snapshot_membership",
      "SET effective_from = effective_from + INTERVAL 1 SECOND",
      "WHERE snapshot_id = ? AND universe_id = 'matrix'",
      "AND instrument_id = 'AAA'"
    ),
    params = list(snapshot_id)
  )
  testthat::expect_true(changed > 0L)
  # The SQL write is outside the supported public workflow. Clear the proof
  # established by the earlier facts read so this models a cold process.
  ledgr:::ledgr_snapshot_verified_reset()
  condition <- tryCatch(
    ledgr_facts_resolve(
      reopened,
      "membership",
      "matrix",
      ws14_utc("2020-01-03 16:00:00")
    ),
    error = identity
  )
  testthat::expect_s3_class(
    condition,
    "ledgr_facts_snapshot_hash_mismatch"
  )
  testthat::expect_identical(
    condition$message,
    "Snapshot hash mismatch; facts inspection refuses corrupted evidence."
  )
  ledgr_snapshot_close(reopened)
})
