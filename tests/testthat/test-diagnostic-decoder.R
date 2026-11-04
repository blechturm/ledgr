# ledgr-test-profile: review
testthat::test_that("[LTB-0554] logical diagnostics own every production read", {
  bars <- data.frame(
    ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:3,
    instrument_id = "AAA",
    open = 10:13,
    high = 11:14,
    low = 9:12,
    close = 10:13,
    volume = 1000
  )
  calls <- new.env(parent = emptyenv())
  calls$n <- 0L
  strategy <- function(ctx, params) {
    calls$n <- calls$n + 1L
    if (ctx$ts_utc == "2020-01-01T00:00:00Z") c(AAA = 1) else ctx$hold()
  }
  snapshot <- ledgr_snapshot_from_df(bars)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  bt <- ledgr_run(
    ledgr_experiment(
      snapshot,
      strategy,
      opening = ledgr_opening(cash = 1000),
      cost_model = ledgr_cost_zero()
    ),
    run_id = "decoder-boundary"
  )
  on.exit(close(bt), add = TRUE)
  testthat::local_mocked_bindings(
    ledgr_diagnostic_clean_fill = function(decision, risk, fill, fill_reason) {
      rep(FALSE, length(fill$k))
    },
    ledgr_diagnostic_clean_hold = function(decision, risk, excluded_k = integer()) {
      rep(FALSE, decision$n)
    },
    .package = "ledgr"
  )
  bt_explicit <- ledgr_run(
    ledgr_experiment(
      snapshot,
      strategy,
      opening = ledgr_opening(cash = 1000),
      cost_model = ledgr_cost_zero()
    ),
    run_id = "decoder-all-explicit"
  )
  on.exit(close(bt_explicit), add = TRUE)
  calls_after_run <- calls$n

  opened <- ledgr:::ledgr_backtest_read_connection(bt)
  on.exit(opened$close(), add = TRUE)
  physical <- DBI::dbGetQuery(
    opened$con,
    "SELECT * FROM run_diagnostics WHERE run_id = ? ORDER BY diagnostic_seq",
    params = list(bt_explicit$run_id)
  )
  absent <- physical$stage == "sizing" & !nzchar(physical$reasons)
  physical$reasons[absent] <- NA_character_
  decoded <- ledgr:::ledgr_diagnostic_decode(opened$con, bt$run_id)
  physical$run_id <- bt$run_id
  testthat::expect_identical(as.data.frame(decoded), physical)
  compact <- DBI::dbGetQuery(
    opened$con,
    "SELECT * FROM run_diagnostic_implicit WHERE run_id = ? ORDER BY decision_seq",
    params = list(bt$run_id)
  )
  testthat::expect_gt(nrow(compact), 0L)
  testthat::expect_lt(
    DBI::dbGetQuery(opened$con,
      "SELECT COUNT(*) AS n FROM run_diagnostics WHERE run_id = ?",
      params = list(bt$run_id))$n[[1L]],
    nrow(decoded)
  )
  sizing <- ledgr:::ledgr_run_sizing_summary(bt, con = opened$con)
  testthat::expect_false(sizing$available)
  testthat::expect_true(sizing$raw_intent_unavailable)
  testthat::expect_identical(sizing$unavailable_decisions, 4L)
  compact_flags <- ledgr:::ledgr_diagnostic_flag_counts(opened$con, bt$run_id)
  testthat::expect_identical(compact_flags$decisions[[1L]],
                             as.integer(sum(decoded$stage == "decision")))
  testthat::expect_no_error(testthat::with_mocked_bindings(
    ledgr:::ledgr_diagnostic_summary_from_store(opened$con, bt$run_id),
    ledgr_diagnostic_decode = function(...) {
      stop("terminal summary materialized the full logical trace")
    },
    .package = "ledgr"
  ))

  first_decision <- decoded$ts_utc[decoded$stage == "decision"][[1L]]
  coverage_call <- new.env(parent = emptyenv())
  original_coverage <- ledgr:::ledgr_diagnostic_require_coverage
  bounded <- testthat::with_mocked_bindings(
    ledgr:::ledgr_diagnostic_decode(
      opened$con,
      bt$run_id,
      instrument_id = "AAA",
      explain_ts_utc = first_decision
    ),
    ledgr_diagnostic_require_coverage = function(
      con, run_ids, instrument_id = NULL, explain_ts_utc = NULL
    ) {
      coverage_call$instrument_id <- instrument_id
      coverage_call$explain_ts_utc <- explain_ts_utc
      original_coverage(
        con, run_ids,
        instrument_id = instrument_id,
        explain_ts_utc = explain_ts_utc
      )
    },
    .package = "ledgr"
  )
  testthat::expect_identical(coverage_call$instrument_id, "AAA")
  testthat::expect_identical(
    as.numeric(coverage_call$explain_ts_utc),
    as.numeric(first_decision)
  )
  expected <- decoded[
    decoded$instrument_id == "AAA" &
      ((decoded$stage == "decision" & decoded$ts_utc == first_decision) |
         (decoded$stage == "execution" & decoded$decision_ts_utc == first_decision)),
    ,
    drop = FALSE
  ]
  testthat::expect_identical(bounded, expected)
  testthat::expect_identical(calls$n, calls_after_run)

  # Stored summaries are derived evidence, not a second authority: missing
  # or mutated rows refuse even while the logical trace remains intact.
  summary_row <- DBI::dbGetQuery(
    opened$con,
    "SELECT * FROM run_diagnostic_summary WHERE run_id = ?",
    params = list(bt$run_id)
  )
  DBI::dbExecute(
    opened$con,
    "UPDATE run_diagnostic_summary SET decisions = decisions + 1 WHERE run_id = ?",
    params = list(bt$run_id)
  )
  testthat::expect_error(
    ledgr:::ledgr_diagnostic_flag_counts(opened$con, bt$run_id),
    class = "ledgr_diagnostic_corrupt"
  )
  testthat::expect_error(
    ledgr:::ledgr_run_sizing_summary(bt, con = opened$con),
    class = "ledgr_diagnostic_corrupt"
  )
  DBI::dbExecute(
    opened$con,
    "DELETE FROM run_diagnostic_summary WHERE run_id = ?",
    params = list(bt$run_id)
  )
  testthat::expect_error(
    ledgr:::ledgr_diagnostic_flag_counts(opened$con, bt$run_id),
    class = "ledgr_diagnostic_corrupt"
  )
  ledgr:::ledgr_store_append(opened$con, "run_diagnostic_summary", summary_row)

  # Coverage and association evidence fail closed. A value mutation breaks
  # the exact clean-pair relation; deleting a pair leaves sequence holes.
  first <- compact[1L, , drop = FALSE]
  DBI::dbExecute(
    opened$con,
    "UPDATE run_diagnostic_implicit SET target = target + 1 WHERE run_id = ? AND decision_seq = ?",
    params = list(bt$run_id, first$decision_seq[[1L]])
  )
  testthat::expect_error(
    ledgr:::ledgr_diagnostic_decode(opened$con, bt$run_id),
    class = "ledgr_diagnostic_corrupt"
  )
  DBI::dbExecute(
    opened$con,
    "UPDATE run_diagnostic_implicit SET target = ? WHERE run_id = ? AND decision_seq = ?",
    params = list(first$target[[1L]], bt$run_id, first$decision_seq[[1L]])
  )
  DBI::dbExecute(
    opened$con,
    "DELETE FROM run_diagnostic_implicit WHERE run_id = ? AND decision_seq = ?",
    params = list(bt$run_id, first$decision_seq[[1L]])
  )
  testthat::expect_error(
    ledgr:::ledgr_diagnostic_decode(opened$con, bt$run_id),
    class = "ledgr_diagnostic_corrupt"
  )
  ledgr:::ledgr_store_append(opened$con, "run_diagnostic_implicit", first)

  r_files <- list.files(
    testthat::test_path("..", "..", "R"),
    pattern = "[.]R$",
    full.names = TRUE
  )
  hits <- vapply(r_files, function(path) {
    any(grepl("run_diagnostics", readLines(path, warn = FALSE), fixed = TRUE))
  }, logical(1))
  readers <- sort(basename(r_files[hits]), method = "radix")
  testthat::expect_identical(
    readers,
    sort(c(
      "availability-diagnostic-writer.R", "db-schema-current.R",
      "backtest-runner.R", "diagnostic-codec.R", "diagnostic-decoder.R",
      "fold-engine.R", "output-handler.R",
      "run-resume.R"
    ), method = "radix")
  )
})

testthat::test_that("[LTB-0556] implicit certification is exact and missing-safe", {
  decision <- ledgr:::ledgr_fold_diagnostic_segment(list(
    n = 1L,
    instrument_id = "AAA",
    stage = "decision",
    outcome = "recorded",
    reason_code = "decision_recorded",
    reasons = "decision_recorded",
    target = 1,
    quantity = 0,
    price = 10,
    mark_source = "current_close",
    mark_age = 0L,
    target_before_risk = 1,
    target_after_risk = 1,
    position_before = 0,
    position_after = 0
  ), as.POSIXct("2020-01-01", tz = "UTC"))
  fill <- list(
    k = 1L, position_before = 0, planned_position_after = 1,
    qty = 1, price = 11, exec_ts = as.numeric(as.POSIXct("2020-01-02", tz = "UTC"))
  )
  reason <- list(reason = "", reasons = "")
  testthat::expect_true(ledgr:::ledgr_diagnostic_clean_fill(decision, NULL, fill, reason))
  changed <- decision
  changed$target_after_risk <- 1 + 1e-12
  testthat::expect_false(ledgr:::ledgr_diagnostic_clean_fill(changed, NULL, fill, reason))
  missing <- decision
  missing$target_after_risk <- NA_real_
  clean <- ledgr:::ledgr_diagnostic_clean_fill(missing, NULL, fill, reason)
  clean[is.na(clean)] <- FALSE
  testthat::expect_false(clean)
})
