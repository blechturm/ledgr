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
  calls_after_run <- calls$n

  opened <- ledgr:::ledgr_backtest_read_connection(bt)
  on.exit(opened$close(), add = TRUE)
  physical <- DBI::dbGetQuery(
    opened$con,
    "SELECT * FROM run_diagnostics WHERE run_id = ? ORDER BY diagnostic_seq",
    params = list(bt$run_id)
  )
  absent <- physical$stage == "sizing" & !nzchar(physical$reasons)
  physical$reasons[absent] <- NA_character_
  decoded <- ledgr:::ledgr_diagnostic_decode(opened$con, bt$run_id)
  testthat::expect_identical(as.data.frame(decoded), physical)

  first_decision <- decoded$ts_utc[decoded$stage == "decision"][[1L]]
  bounded <- ledgr:::ledgr_diagnostic_decode(
    opened$con,
    bt$run_id,
    instrument_id = "AAA",
    explain_ts_utc = first_decision
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
      "diagnostic-decoder.R", "fold-engine.R", "output-handler.R",
      "run-resume.R"
    ), method = "radix")
  )
})
