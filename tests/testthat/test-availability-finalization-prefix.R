availability_prefix_calendar <- function(n = 5L) {
  pulses <- as.POSIXct(
    paste(as.Date("2020-01-01") + seq_len(n) - 1L, "16:00:00"),
    tz = "UTC"
  )
  list(
    pulses = format(pulses, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    pulses_posix = pulses,
    pulses_iso = format(pulses, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  )
}

availability_prefix_rows <- function(calendar,
                                     index,
                                     run_id = "prefix-run",
                                     offset = 0) {
  index <- as.integer(index)
  value <- as.numeric(index) + as.numeric(offset)
  data.frame(
    run_id = rep(run_id, length(index)),
    ts_utc = calendar$pulses_posix[index],
    cash = 1000 + value,
    positions_value = 10 + value,
    equity = 1010 + 2 * value,
    realized_pnl = value,
    unrealized_pnl = 10 + value,
    stringsAsFactors = FALSE
  )
}

availability_prefix_store <- function(db_path, run_id) {
  opened <- ledgr_test_open_duckdb(db_path)
  on.exit(ledgr_test_close_duckdb(opened$con, opened$drv), add = TRUE)
  list(
    status = DBI::dbGetQuery(
      opened$con,
      "SELECT status FROM runs WHERE run_id = ?",
      params = list(run_id)
    )$status[[1L]],
    equity = ledgr:::ledgr_run_equity_prefix_read(opened$con, run_id),
    completion = DBI::dbGetQuery(
      opened$con,
      "SELECT * FROM run_completion WHERE run_id = ?",
      params = list(run_id)
    )
  )
}

testthat::test_that("equity-prefix merge collapses only identical overlap", {
  calendar <- availability_prefix_calendar()
  prior <- availability_prefix_rows(calendar, 1:3)
  current <- availability_prefix_rows(calendar, 3:5)
  merged <- ledgr:::ledgr_run_equity_prefix_merge(
    prior,
    current,
    "prefix-run",
    calendar,
    calendar$pulses_posix[[5L]]
  )
  testthat::expect_identical(as.numeric(merged$ts_utc), as.numeric(calendar$pulses_posix))
  testthat::expect_equal(nrow(merged), 5L)

  repeated <- rbind(current[1L, , drop = FALSE], current)
  collapsed <- ledgr:::ledgr_run_equity_prefix_merge(
    prior,
    repeated,
    "prefix-run",
    calendar,
    calendar$pulses_posix[[5L]]
  )
  testthat::expect_identical(collapsed, merged)

  conflicting <- current
  conflicting$cash[[1L]] <- conflicting$cash[[1L]] + 1
  testthat::expect_error(
    ledgr:::ledgr_run_equity_prefix_merge(
      prior,
      conflicting,
      "prefix-run",
      calendar,
      calendar$pulses_posix[[5L]]
    ),
    "conflicting duplicate pulses",
    class = "ledgr_run_terminal_evidence_invalid"
  )
})

testthat::test_that("equity-prefix merge rejects every malformed pulse shape", {
  calendar <- availability_prefix_calendar()
  prior <- availability_prefix_rows(calendar, 1:2)
  cases <- list(
    missing = availability_prefix_rows(calendar, 4:5),
    extra = availability_prefix_rows(calendar, 3:4),
    non_monotone = availability_prefix_rows(calendar, c(4L, 3L, 5L)),
    out_of_calendar = transform(
      availability_prefix_rows(calendar, 3:5),
      ts_utc = ts_utc + c(0, 0, 86400 * 10)
    )
  )
  ends <- list(
    missing = calendar$pulses_posix[[5L]],
    extra = calendar$pulses_posix[[3L]],
    non_monotone = calendar$pulses_posix[[5L]],
    out_of_calendar = calendar$pulses_posix[[5L]]
  )
  messages <- c(
    missing = "does not contain its exact achieved prefix",
    extra = "does not contain its exact achieved prefix",
    non_monotone = "is not monotone",
    out_of_calendar = "contains an out-of-calendar pulse"
  )
  for (name in names(cases)) {
    testthat::expect_error(
      ledgr:::ledgr_run_equity_prefix_merge(
        prior,
        cases[[name]],
        "prefix-run",
        calendar,
        ends[[name]]
      ),
      messages[[name]],
      class = "ledgr_run_terminal_evidence_invalid",
      info = name
    )
  }

  foreign <- availability_prefix_rows(
    calendar,
    3:5,
    run_id = "another-run"
  )
  testthat::expect_error(
    ledgr:::ledgr_run_equity_prefix_merge(
      prior,
      foreign,
      "prefix-run",
      calendar,
      calendar$pulses_posix[[5L]]
    ),
    "belongs to a different run",
    class = "ledgr_run_terminal_evidence_invalid"
  )
})

testthat::test_that("invalid terminal merge preserves prior rows and status", {
  db <- tempfile("availability_prefix_atomic_", fileext = ".duckdb")
  opened <- ledgr_test_open_duckdb(db)
  on.exit({
    ledgr_test_close_duckdb(opened$con, opened$drv)
    unlink(c(db, paste0(db, ".wal")), force = TRUE)
  }, add = TRUE)
  DBI::dbExecute(opened$con, paste(
    "CREATE TABLE equity_curve (run_id TEXT NOT NULL, ts_utc TIMESTAMP NOT NULL,",
    "cash DOUBLE, positions_value DOUBLE, equity DOUBLE, realized_pnl DOUBLE,",
    "unrealized_pnl DOUBLE, PRIMARY KEY (run_id, ts_utc))"
  ))
  DBI::dbExecute(
    opened$con,
    "CREATE TABLE runs (run_id TEXT PRIMARY KEY, status TEXT NOT NULL)"
  )
  DBI::dbExecute(
    opened$con,
    "INSERT INTO runs VALUES ('prefix-run', 'RUNNING')"
  )
  calendar <- availability_prefix_calendar()
  prior <- availability_prefix_rows(calendar, 1:2)
  DBI::dbAppendTable(opened$con, "equity_curve", prior)
  current <- availability_prefix_rows(calendar, 2:5)
  current$equity[[1L]] <- current$equity[[1L]] + 1

  testthat::expect_error(
    ledgr:::ledgr_run_equity_prefix_commit(
      con = opened$con,
      run_id = "prefix-run",
      current = current,
      calendar = calendar,
      achieved_end_utc = calendar$pulses_posix[[5L]],
      record_status = function() {
        DBI::dbExecute(
          opened$con,
          "UPDATE runs SET status = 'DONE' WHERE run_id = 'prefix-run'"
        )
      }
    ),
    "conflicting duplicate pulses",
    class = "ledgr_run_terminal_evidence_invalid"
  )
  stored <- ledgr:::ledgr_run_equity_prefix_read(opened$con, "prefix-run")
  testthat::expect_identical(as.numeric(stored$ts_utc), as.numeric(prior$ts_utc))
  testthat::expect_equal(stored[, setdiff(names(stored), "ts_utc")], prior[, setdiff(names(prior), "ts_utc")])
  status <- DBI::dbGetQuery(
    opened$con,
    "SELECT status FROM runs WHERE run_id = 'prefix-run'"
  )$status[[1L]]
  testthat::expect_identical(status, "RUNNING")
})

testthat::test_that("dense resume keeps full recomputation and bypasses prefix merge", {
  dates <- as.Date("2020-01-01") + 0:4
  bars <- data.frame(
    ts_utc = as.POSIXct(paste(dates, "16:00:00"), tz = "UTC"),
    instrument_id = "AAA",
    open = 100 + seq_along(dates),
    high = 101 + seq_along(dates),
    low = 99 + seq_along(dates),
    close = 100 + seq_along(dates),
    volume = 1000,
    stringsAsFactors = FALSE
  )
  snapshot <- ledgr_snapshot_from_df(
    bars,
    instruments_df = data.frame(instrument_id = "AAA")
  )
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  prior <- options(
    ledgr.interrupt = FALSE,
    ledgr.v201.prefix_interrupt_at = "2020-01-02T16:00:00Z"
  )
  on.exit(options(prior), add = TRUE)
  strategy <- function(ctx, params) {
    if (identical(
      ctx$ts_utc,
      getOption("ledgr.v201.prefix_interrupt_at", "")
    )) {
      options(ledgr.interrupt = TRUE)
    }
    list(targets = ctx$flat(), state_update = list(ts_utc = ctx$ts_utc))
  }
  experiment <- ledgr_experiment(
    snapshot,
    strategy,
    cost_model = ledgr_cost_zero()
  )
  calls <- new.env(parent = emptyenv())
  calls$n <- 0L
  original <- ledgr:::ledgr_run_equity_prefix_commit
  testthat::local_mocked_bindings(
    ledgr_run_equity_prefix_commit = function(...) {
      calls$n <- calls$n + 1L
      original(...)
    },
    .package = "ledgr"
  )

  first <- ledgr_run(experiment, run_id = "dense-prefix-bypass")
  close(first)
  first_store <- availability_prefix_store(
    snapshot$db_path,
    "dense-prefix-bypass"
  )
  testthat::expect_identical(first_store$status, "RUNNING")
  testthat::expect_equal(nrow(first_store$equity), 0L)

  options(
    ledgr.interrupt = FALSE,
    ledgr.v201.prefix_interrupt_at = ""
  )
  resumed <- ledgr_run(experiment, run_id = "dense-prefix-bypass")
  close(resumed)
  final_store <- availability_prefix_store(
    snapshot$db_path,
    "dense-prefix-bypass"
  )
  testthat::expect_identical(final_store$status, "DONE")
  testthat::expect_equal(nrow(final_store$equity), 5L)
  testthat::expect_identical(calls$n, 0L)
  reopened <- ledgr_run_open(snapshot, "dense-prefix-bypass")
  on.exit(close(reopened), add = TRUE)
  testthat::expect_equal(nrow(ledgr_compute_equity_curve(reopened)), 5L)
})
