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

testthat::test_that("[LTB-0250] old hash rules are readable but not executable", {
  path <- tempfile(fileext = ".duckdb")
  snapshot <- ledgr_snapshot_from_df(
    ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:2),
    db_path = path
  )
  id <- snapshot$snapshot_id
  current <- ledgr_snapshot_info(snapshot)
  testthat::expect_identical(current$hash_rule_version[[1L]], 3L)
  testthat::expect_identical(current$verified_in_process[[1L]], TRUE)
  testthat::expect_match(
    paste(capture.output(print(snapshot)), collapse = "\n"),
    "Hash rule:    3 \\(verified in this process\\)",
    perl = TRUE
  )

  strategy <- function(ctx, params) ctx$flat()
  experiment <- ledgr_experiment(
    snapshot,
    strategy,
    cost_model = ledgr_cost_zero()
  )
  completed <- ledgr_run(experiment, run_id = "rule3-completed")
  initial_cash <- completed$config$backtest$initial_cash
  close(completed)
  ledgr_snapshot_close(snapshot)

  expect_rebuild <- function(expr, rule) {
    shown <- if (is.na(rule)) "missing" else as.character(rule)
    message <- paste0(
      "Snapshot hash rule ", shown,
      " is not executable. Rebuild the snapshot from source under hash rule 3."
    )
    testthat::expect_error(
      force(expr),
      message,
      class = "ledgr_snapshot_rebuild_required",
      fixed = TRUE
    )
  }

  for (rule in list(NA_integer_, 1L, 2L)) {
    con <- ledgr_db_init(path)
    DBI::dbExecute(
      con,
      "UPDATE snapshots SET hash_rule_version = ? WHERE snapshot_id = ?",
      params = list(rule, id)
    )
    DBI::dbDisconnect(con, shutdown = TRUE)
    reopened <- ledgr_snapshot_open(path, id, verify = FALSE)
    info <- ledgr_snapshot_info(reopened)
    testthat::expect_identical(info$hash_rule_version[[1L]], rule)
    expect_rebuild(ledgr_snapshot_open(path, id, verify = TRUE), rule)
    expect_rebuild(ledgr_snapshot_validate(reopened), rule)
    expect_rebuild(ledgr_snapshot_seal(reopened), rule)
    expect_rebuild(
      ledgr_facts_history(reopened, "membership", "legacy-guard"),
      rule
    )
    expect_rebuild(
      ledgr_run(
        experiment,
        params = list(rule = rule),
        run_id = paste0("legacy-guard-", ifelse(is.na(rule), "missing", rule))
      ),
      rule
    )

    con <- ledgr_db_init(path)
    expect_rebuild(
      ledgr:::ledgr_rebuild_derived_state(
        con,
        completed$run_id,
        initial_cash = initial_cash
      ),
      rule
    )
    DBI::dbDisconnect(con, shutdown = TRUE)
    ledgr_snapshot_close(reopened)
  }

  con <- ledgr_db_init(path)
  DBI::dbExecute(
    con,
    "UPDATE snapshots SET hash_rule_version = 99 WHERE snapshot_id = ?",
    params = list(id)
  )
  testthat::expect_error(
    ledgr:::ledgr_snapshot_hash(con, id),
    class = "ledgr_snapshot_hash_rule_unsupported"
  )
  DBI::dbDisconnect(con, shutdown = TRUE)
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
