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

# ledgr-test-profile: review
testthat::test_that("[LTB-0250] every content reader refuses a non-current hash rule", {
  expect_unsupported <- function(expr) {
    testthat::expect_error(
      force(expr),
      class = "ledgr_snapshot_hash_rule_unsupported"
    )
  }

  for (rule in list(NA_integer_, 1L, 99L)) {
    path <- tempfile(fileext = ".duckdb")
    snapshot <- ledgr_snapshot_from_df(
      ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:2),
      db_path = path
    )
    id <- snapshot$snapshot_id
    strategy <- function(ctx, params) ctx$flat()
    experiment <- ledgr_experiment(
      snapshot,
      strategy,
      cost_model = ledgr_cost_zero()
    )
    completed <- ledgr_run(
      experiment,
      run_id = paste0("rule3-completed-", ifelse(is.na(rule), "missing", rule))
    )
    initial_cash <- completed$config$backtest$initial_cash
    close(completed)

    incomplete_snapshot <- availability_runtime_fixture(
      days = 4L,
      bar_days = c(1L, 2L, 4L)
    )
    incomplete_experiment <- ledgr_experiment(
      incomplete_snapshot,
      function(ctx, params) {
        target <- ctx$hold()
        target[["AAA"]] <- 1
        target
      },
      valuation_policy = ledgr_valuation_stale(0L, exhausted = "refuse"),
      cost_model = ledgr_cost_zero()
    )
    incomplete <- ledgr_run(
      incomplete_experiment,
      run_id = paste0("rule3-incomplete-", ifelse(is.na(rule), "missing", rule))
    )
    incomplete_run_id <- incomplete$run_id
    close(incomplete)

    con <- ledgr:::get_connection(snapshot)
    DBI::dbExecute(
      con,
      "UPDATE snapshots SET hash_rule_version = ? WHERE snapshot_id = ?",
      params = list(rule, id)
    )
    incomplete_con <- ledgr:::get_connection(incomplete_snapshot)
    DBI::dbExecute(
      incomplete_con,
      "UPDATE snapshots SET hash_rule_version = ? WHERE snapshot_id = ?",
      params = list(rule, incomplete_snapshot$snapshot_id)
    )
    ledgr:::ledgr_snapshot_verified_reset()

    expect_unsupported(ledgr_snapshot_open(path, id, verify = TRUE))
    expect_unsupported(ledgr_snapshot_validate(snapshot))
    expect_unsupported(ledgr_snapshot_seal(snapshot))
    expect_unsupported(
      ledgr_facts_history(snapshot, "membership", "current-only-guard")
    )
    expect_unsupported(
      ledgr_pulse_snapshot(
        snapshot,
        universe = "AAA",
        ts_utc = "2020-01-03T00:00:00Z"
      )
    )
    expect_unsupported(
      ledgr_indicator_dev(
        snapshot,
        instrument_id = "AAA",
        ts_utc = "2020-01-03T00:00:00Z",
        lookback = 2L
      )
    )
    expect_unsupported(
      ledgr_run_open(incomplete_snapshot, incomplete_run_id)
    )
    expect_unsupported(
      ledgr_run(
        experiment,
        params = list(rule = rule),
        run_id = paste0("current-only-guard-", ifelse(is.na(rule), "missing", rule))
      )
    )
    expect_unsupported(
      ledgr:::ledgr_rebuild_derived_state(
        con,
        paste0("rule3-completed-", ifelse(is.na(rule), "missing", rule)),
        initial_cash = initial_cash
      )
    )

    ledgr_snapshot_close(incomplete_snapshot)
    ledgr_snapshot_close(snapshot)
  }
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
