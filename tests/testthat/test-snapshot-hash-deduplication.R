stage_n_with_namespace_binding <- function(name, value, fn) {
  namespace <- asNamespace("ledgr")
  original <- get(name, envir = namespace, inherits = FALSE)
  unlockBinding(name, namespace)
  assign(name, value, envir = namespace)
  lockBinding(name, namespace)
  on.exit({
    unlockBinding(name, namespace)
    assign(name, original, envir = namespace)
    lockBinding(name, namespace)
  }, add = TRUE)
  fn()
}

# ledgr-test-profile: review
testthat::test_that("[LTB-0251] rule-3 blocks are fixed and order checked", {
  bars <- ledgr_test_make_bars(
    "AAA",
    as.Date("1990-01-01") + 0:10000
  )
  snapshot <- ledgr_snapshot_from_df(bars)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  con <- ledgr:::get_connection(snapshot)
  id <- snapshot$snapshot_id
  stored <- ledgr_snapshot_info(snapshot)$snapshot_hash[[1L]]

  testthat::expect_identical(
    ledgr:::ledgr_snapshot_hash(con, id, chunk_size = 4096L),
    stored
  )
  testthat::expect_identical(
    ledgr:::ledgr_snapshot_hash(con, id, chunk_size = 7777L),
    stored
  )

  hostile <- data.frame(
    instrument_id = c("BBB", "AAA"),
    stringsAsFactors = FALSE
  )
  testthat::expect_error(
    ledgr:::ledgr_snapshot_hash_block(
      hostile,
      1L,
      0L,
      c(instrument_id = "text"),
      "instrument_id"
    ),
    class = "ledgr_snapshot_hash_order_invalid"
  )

  source <- paste(
    deparse(body(ledgr:::ledgr_snapshot_hash_stream_section),
      width.cutoff = 500L
    ),
    collapse = "\n"
  )
  testthat::expect_match(source, "ledgr_snapshot_hash_rule3_block_rows")
  testthat::expect_match(source, "max_chunks")
  testthat::expect_match(source, "vector\\(\"list\", max_chunks\\)")
  testthat::expect_no_match(source, "c\\(pending")
  testthat::expect_no_match(source, "append\\(")
})

testthat::test_that("[LTB-0250] snapshots expose only hash rule 3", {
  snapshot <- ledgr_snapshot_from_df(
    ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:2),
    db_path = tempfile(fileext = ".duckdb")
  )
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  info <- ledgr_snapshot_info(snapshot)
  testthat::expect_identical(info$hash_rule_version[[1L]], 3L)
  testthat::expect_identical(info$verified_in_process[[1L]], TRUE)
  testthat::expect_identical(
    ledgr:::ledgr_snapshot_hash_rule_version(
      ledgr:::get_connection(snapshot),
      snapshot$snapshot_id
    ),
    ledgr:::ledgr_snapshot_content_hash_rule_version
  )
  testthat::expect_match(
    paste(capture.output(print(snapshot)), collapse = "\n"),
    "Hash rule:    3 \\(verified in this process\\)",
    perl = TRUE
  )
})
# ledgr-test-profile: heavy_protocol
testthat::test_that("run, timestamp, price, and stored-hash guards still detect tampering", {
  path <- tempfile(fileext = ".duckdb")
  bars <- ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:1)
  snapshot <- ledgr_snapshot_from_df(bars, db_path = path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  con <- ledgr:::get_connection(snapshot)
  id <- snapshot$snapshot_id
  stored <- ledgr_snapshot_info(snapshot)$snapshot_hash[[1L]]
  exp <- ledgr_experiment(
    snapshot,
    function(ctx, params) ctx$flat(),
    cost_model = ledgr_cost_zero()
  )

  DBI::dbExecute(
    con,
    "UPDATE snapshot_bars SET close = close + 0.01 WHERE snapshot_id = ?",
    params = list(id)
  )
  ledgr:::ledgr_snapshot_verified_reset()
  testthat::expect_error(ledgr_run(exp), class = "LEDGR_SNAPSHOT_CORRUPTED")
  DBI::dbExecute(
    con,
    "UPDATE snapshot_bars SET close = close - 0.01 WHERE snapshot_id = ?",
    params = list(id)
  )
  testthat::expect_silent(ledgr_snapshot_validate(snapshot))

  DBI::dbExecute(
    con,
    paste(
      "UPDATE snapshot_bars SET ts_utc = ts_utc + INTERVAL 1 SECOND",
      "WHERE snapshot_id = ? AND ts_utc =",
      "(SELECT MIN(ts_utc) FROM snapshot_bars WHERE snapshot_id = ?)"
    ),
    params = list(id, id)
  )
  testthat::expect_error(
    ledgr_snapshot_validate(snapshot),
    class = "ledgr_invalid_snapshot"
  )
  DBI::dbExecute(
    con,
    paste(
      "UPDATE snapshot_bars SET ts_utc = ts_utc - INTERVAL 1 SECOND",
      "WHERE snapshot_id = ? AND ts_utc =",
      "(SELECT MIN(ts_utc) FROM snapshot_bars WHERE snapshot_id = ?)"
    ),
    params = list(id, id)
  )
  testthat::expect_silent(ledgr_snapshot_validate(snapshot))

  DBI::dbExecute(
    con,
    "UPDATE snapshots SET snapshot_hash = ? WHERE snapshot_id = ?",
    params = list(strrep("0", 64L), id)
  )
  testthat::expect_error(
    ledgr_snapshot_validate(snapshot),
    class = "ledgr_invalid_snapshot"
  )
  DBI::dbExecute(
    con,
    "UPDATE snapshots SET snapshot_hash = ? WHERE snapshot_id = ?",
    params = list(stored, id)
  )
})
