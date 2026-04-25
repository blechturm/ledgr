testthat::test_that("timing helpers handle numeric and difftime paths", {
  testthat::expect_true(length(ledgr:::ledgr_time_now()) == 1L)
  testthat::expect_equal(ledgr:::ledgr_time_elapsed(1, 3), 2)
  testthat::expect_true(is.na(ledgr:::ledgr_time_elapsed(numeric(), 1)))

  start <- as.POSIXct("2020-01-01 00:00:00", tz = "UTC")
  end <- as.POSIXct("2020-01-01 00:00:02", tz = "UTC")
  testthat::expect_equal(ledgr:::ledgr_time_elapsed(start, end), 2)
})

testthat::test_that("fill event row helper covers no-op and validation branches", {
  none <- structure(list(status = "NO_FILL"), class = "ledgr_fill_none")
  out <- ledgr:::ledgr_fill_event_row("run-1", none, 1L)
  testthat::expect_s3_class(out, "ledgr_ledger_write_result")
  testthat::expect_identical(out$status, "NO_OP")

  testthat::expect_error(
    ledgr:::ledgr_fill_event_row("run-1", list(), 1L),
    class = "ledgr_invalid_fill_intent"
  )
  fill <- structure(
    list(
      instrument_id = "AAA",
      side = "BUY",
      qty = 2,
      fill_price = 10,
      commission_fixed = 1,
      ts_exec_utc = "2020-01-02T00:00:00Z"
    ),
    class = "ledgr_fill_intent"
  )
  testthat::expect_error(
    ledgr:::ledgr_fill_event_row("run-1", fill, 0L),
    class = "ledgr_invalid_args"
  )

  row <- ledgr:::ledgr_fill_event_row("run-1", fill, 3L)
  testthat::expect_identical(row$status, "WROTE")
  testthat::expect_equal(row$cash_delta, -21)
  testthat::expect_equal(row$position_delta, 2)

  fill$side <- "SELL"
  row <- ledgr:::ledgr_fill_event_row("run-1", fill, 4L)
  testthat::expect_equal(row$cash_delta, 19)
  testthat::expect_equal(row$position_delta, -2)
})

testthat::test_that("fill extraction handles semantic, malformed, and close/open branches", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  opened <- ledgr_test_open_duckdb(db_path)
  con <- opened$con
  drv <- opened$drv
  on.exit({
    if (!is.null(con) && !is.null(drv)) ledgr_test_close_duckdb(con, drv)
  }, add = TRUE)
  DBI::dbExecute(
    con,
    "
    CREATE TABLE ledger_events (
      event_id TEXT,
      run_id TEXT,
      ts_utc TIMESTAMP,
      event_type TEXT,
      instrument_id TEXT,
      side TEXT,
      qty DOUBLE,
      price DOUBLE,
      fee DOUBLE,
      meta_json TEXT,
      event_seq INTEGER
    )
    "
  )

  rows <- data.frame(
    event_id = paste0("e", 1:9),
    run_id = "run-coverage",
    ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + seq_len(9) * 86400,
    event_type = "FILL",
    instrument_id = "AAA",
    side = c("BUY_TO_COVER", "HOLD", "BUY", "SELL", "SELL", "BUY_TO_COVER", "SELL_SHORT", "BUY", "BUY"),
    qty = c(1, 1, 10, 4, 10, 2, 1, 1, NA),
    price = c(100, 100, 100, 110, 105, 100, 100, 99, 100),
    fee = rep(0, 9),
    meta_json = c(
      NA_character_,
      NA_character_,
      "not-json",
      "{\"realized_pnl\":999}",
      NA_character_,
      NA_character_,
      NA_character_,
      "{\"realized_pnl\":\"bad\"}",
      NA_character_
    ),
    event_seq = 1:9,
    stringsAsFactors = FALSE
  )
  DBI::dbAppendTable(con, "ledger_events", rows)
  ledgr_test_close_duckdb(con, drv)
  con <- NULL
  drv <- NULL

  bt <- ledgr:::new_ledgr_backtest("run-coverage", db_path, config = list())
  warnings <- character()
  fills <- withCallingHandlers(
    ledgr_extract_fills(bt),
    warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  close(bt)

  testthat::expect_s3_class(fills, "tbl_df")
  testthat::expect_true(any(fills$action == "REJECTED"))
  testthat::expect_true(any(fills$action == "OPEN", na.rm = TRUE))
  testthat::expect_true(any(fills$action == "CLOSE", na.rm = TRUE))
  testthat::expect_true(any(is.na(fills$action)))
  testthat::expect_true(any(grepl("Semantic Violation", warnings)))
  testthat::expect_true(any(grepl("Malformed meta_json", warnings)))
  testthat::expect_true(any(grepl("FIFO Mismatch", warnings)))
})

testthat::test_that("indicator validation and fingerprint helpers fail loud on invalid inputs", {
  good_fn <- function(window) 1

  testthat::expect_error(ledgr_indicator("", good_fn, 1), class = "ledgr_invalid_args")
  testthat::expect_error(ledgr_indicator("x", 1, 1), class = "ledgr_invalid_args")
  testthat::expect_error(ledgr_indicator("x", good_fn, NA_real_), class = "ledgr_invalid_args")
  testthat::expect_error(ledgr_indicator("x", good_fn, 0), class = "ledgr_invalid_args")
  testthat::expect_error(ledgr_indicator("x", good_fn, 2, stable_after = 1), class = "ledgr_invalid_args")
  testthat::expect_error(ledgr_indicator("x", good_fn, 1, params = 1), class = "ledgr_invalid_args")
  testthat::expect_error(ledgr_indicator("x", good_fn, 1, params = list(1)), class = "ledgr_invalid_args")
  testthat::expect_error(ledgr_indicator("x", good_fn, 1, params = list(ts = Sys.Date())), class = "ledgr_invalid_args")
  testthat::expect_error(ledgr_indicator("x", function(window) { x <<- 1; 1 }, 1), class = "ledgr_invalid_args")
  testthat::expect_error(ledgr_indicator("x", function(window) runif(1), 1), class = "ledgr_purity_violation")

  testthat::expect_error(ledgr:::ledgr_static_function_signature(1), class = "ledgr_invalid_args")
  sig <- ledgr:::ledgr_static_function_signature(function(x) x + 1)
  testthat::expect_true(all(c("body", "formals", "environment_name") %in% names(sig)))

  testthat::expect_identical(ledgr:::ledgr_stable_payload(factor("a")), "a")
  payload <- ledgr:::ledgr_stable_payload(data.frame(a = 1, b = "x"))
  testthat::expect_identical(names(payload), c("a", "b"))
  testthat::expect_error(ledgr:::ledgr_stable_payload(as.Date("2020-01-01")), class = "ledgr_config_non_deterministic")
  testthat::expect_error(ledgr:::ledgr_stable_payload(new.env()), class = "ledgr_config_non_deterministic")
  testthat::expect_error(ledgr:::ledgr_stable_payload(Inf), class = "ledgr_config_non_deterministic")
  testthat::expect_error(ledgr:::ledgr_stable_payload(quote(runif(1))), class = "ledgr_config_non_deterministic")

  testthat::expect_error(ledgr:::ledgr_function_fingerprint(1), class = "ledgr_invalid_args")
  testthat::expect_error(ledgr:::ledgr_function_fingerprint(function() Sys.time()), class = "ledgr_config_non_deterministic")
  testthat::expect_error(ledgr:::ledgr_indicator_fingerprint(list()), class = "ledgr_invalid_args")

  testthat::expect_error(ledgr_register_indicator(1), class = "ledgr_invalid_args")
  testthat::expect_error(ledgr_register_indicator(ledgr_ind_sma(2), name = ""), class = "ledgr_invalid_args")
  testthat::expect_error(ledgr_register_indicator(ledgr_ind_sma(2), name = "coverage_sma_2", overwrite = NA), class = "ledgr_invalid_args")
  testthat::expect_error(ledgr_get_indicator(""), class = "ledgr_invalid_args")
  testthat::expect_error(ledgr_get_indicator("missing_coverage_indicator"), class = "ledgr_invalid_args")
  testthat::expect_error(ledgr_list_indicators(""), class = "ledgr_invalid_args")
})
