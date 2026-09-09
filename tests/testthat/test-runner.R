make_runner_fixture_db <- function() {
  path <- tempfile(fileext = ".duckdb")

  drv <- duckdb::duckdb()
  con <- DBI::dbConnect(drv, dbdir = path)
  ledgr_create_schema(con)

  DBI::dbAppendTable(con, "instruments", data.frame(instrument_id = "AAA"))

  bars <- data.frame(
    instrument_id = "AAA",
    ts_utc = as.POSIXct(c("2020-01-01 00:00:00", "2020-01-02 00:00:00", "2020-01-03 00:00:00"), tz = "UTC"),
    open = c(100, 101, 102),
    high = c(100, 101, 102),
    low = c(100, 101, 102),
    close = c(100, 101, 102),
    volume = c(1, 1, 1),
    stringsAsFactors = FALSE
  )
  DBI::dbAppendTable(con, "bars", bars)

  DBI::dbDisconnect(con, shutdown = TRUE)
  duckdb::duckdb_shutdown(drv)
  attr(path, "bars") <- bars
  path
}

base_runner_config <- function(db_path) {
  cost <- ledgr_cost_zero()
  list(
    db_path = db_path,
    engine = list(seed = 1L, tz = "UTC"),
    universe = list(instrument_ids = c("AAA")),
    backtest = list(
      start_ts_utc = "2020-01-01T00:00:00Z",
      end_ts_utc = "2020-01-03T00:00:00Z",
      pulse = "EOD",
      initial_cash = 1000
    ),
    timing_model = {
      timing <- ledgr_timing_next_open()
      list(
        timing_schema_version = timing$timing_schema_version,
        type_id = timing$type_id,
        version = timing$version,
        args = timing$args
      )
    },
    cost_model = list(
      cost_model_hash = ledgr:::ledgr_cost_model_hash(cost),
      cost_plan_json = ledgr:::ledgr_cost_plan_json(cost)
    ),
    features = list(enabled = TRUE, defs = list(list(id = "return_1"))),
    strategy = list(id = "echo", params = list(targets = c(AAA = 1)))
  )
}

testthat::test_that("runner executes a minimal end-to-end run and writes outputs", {
  db_path <- make_runner_fixture_db()
  cfg <- ledgr_test_snapshot_backed_config(base_runner_config(db_path), attr(db_path, "bars"))

  out <- ledgr_run_config(cfg)
  testthat::expect_true(is.list(out))
  testthat::expect_true(nzchar(out$run_id))
  testthat::expect_identical(out$db_path, db_path)
  gc()
  Sys.sleep(0.05)

  drv <- duckdb::duckdb()
  con <- DBI::dbConnect(drv, dbdir = db_path)
  on.exit(duckdb::duckdb_shutdown(drv), add = TRUE)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  run <- DBI::dbGetQuery(con, "SELECT status, error_msg FROM runs WHERE run_id = ?", params = list(out$run_id))
  testthat::expect_equal(nrow(run), 1L)
  testthat::expect_identical(run$status[[1]], "DONE")
  testthat::expect_true(is.na(run$error_msg[[1]]))

  n_features <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM features WHERE run_id = ?", params = list(out$run_id))$n[[1]]
  testthat::expect_true(n_features > 0)

  n_ledger <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM ledger_events WHERE run_id = ?", params = list(out$run_id))$n[[1]]
  testthat::expect_true(n_ledger >= 0)

  n_eq <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM equity_curve WHERE run_id = ?", params = list(out$run_id))$n[[1]]
  testthat::expect_equal(n_eq, 3L)

  n_state <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM strategy_state WHERE run_id = ?", params = list(out$run_id))$n[[1]]
  testthat::expect_equal(n_state, 3L)
})

testthat::test_that("low-level runner rejects opening positions outside the universe", {
  db_path <- make_runner_fixture_db()
  cfg <- ledgr_test_snapshot_backed_config(base_runner_config(db_path), attr(db_path, "bars"))
  cfg$opening <- list(
    cash = 1000,
    date = NULL,
    positions = c(BBB = 1),
    cost_basis = c(BBB = 10)
  )

  testthat::expect_error(
    ledgr_run_config(cfg),
    "opening.positions contains instruments outside universe.instrument_ids",
    fixed = TRUE,
    class = "ledgr_invalid_config"
  )
})

testthat::test_that("runner resume appends ledger events without duplicate event_seq and rebuilds tail", {
  db_path <- make_runner_fixture_db()

  cfg <- ledgr_test_snapshot_backed_config(base_runner_config(db_path), attr(db_path, "bars"))
  cfg$features$defs <- list(list(id = "sma_2"))
  cfg$strategy <- list(
    id = "ts_rule",
    params = list(
      cutover_ts_utc = "2020-01-02T00:00:00Z",
      targets_before = c(AAA = 1),
      targets_after = c(AAA = 2)
    )
  )

  run_id <- "run-resume-1"
  ledgr:::ledgr_run_fold(cfg, run_id = run_id, control = list(max_pulses = 1L))
  gc()
  Sys.sleep(0.05)

  drv <- duckdb::duckdb()
  con <- DBI::dbConnect(drv, dbdir = db_path)
  on.exit(duckdb::duckdb_shutdown(drv), add = TRUE)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  before <- DBI::dbGetQuery(con, "SELECT event_seq, ts_utc FROM ledger_events WHERE run_id = ? ORDER BY event_seq", params = list(run_id))
  testthat::expect_equal(nrow(before), 1L)

  ledgr_run_config(cfg, run_id = run_id)

  after <- DBI::dbGetQuery(con, "SELECT event_seq, ts_utc FROM ledger_events WHERE run_id = ? ORDER BY event_seq", params = list(run_id))
  testthat::expect_equal(nrow(after), 2L)
  testthat::expect_identical(as.integer(after$event_seq), c(1L, 2L))

  n_eq <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM equity_curve WHERE run_id = ?", params = list(run_id))$n[[1]]
  testthat::expect_true(n_eq > 0)
})

testthat::test_that("runner refuses to resume on config hash mismatch", {
  db_path <- make_runner_fixture_db()
  cfg <- ledgr_test_snapshot_backed_config(base_runner_config(db_path), attr(db_path, "bars"))

  run_id <- "run-mismatch-1"
  ledgr_run_config(cfg, run_id = run_id)
  gc()
  Sys.sleep(0.05)

  cfg2 <- cfg
  changed_cost <- ledgr_cost_spread_bps(1)
  cfg2$cost_model <- list(
    cost_model_hash = ledgr:::ledgr_cost_model_hash(changed_cost),
    cost_plan_json = ledgr:::ledgr_cost_plan_json(changed_cost)
  )

  testthat::expect_error(
    ledgr_run_config(cfg2, run_id = run_id),
    class = "ledgr_run_hash_mismatch"
  )
})

testthat::test_that("strategy_state is persisted and restored across resume", {
  path <- tempfile(fileext = ".duckdb")

  drv <- duckdb::duckdb()
  con <- DBI::dbConnect(drv, dbdir = path)
  ledgr_create_schema(con)

  DBI::dbExecute(con, "INSERT INTO instruments (instrument_id) VALUES ('AAA')")
  bars <- data.frame(
    instrument_id = rep("AAA", 4),
    ts_utc = as.POSIXct(c("2020-01-01 00:00:00", "2020-01-02 00:00:00", "2020-01-03 00:00:00", "2020-01-04 00:00:00"), tz = "UTC"),
    open = c(100, 101, 102, 103),
    high = c(100, 101, 102, 103),
    low = c(100, 101, 102, 103),
    close = c(100, 101, 102, 103),
    volume = c(1, 1, 1, 1),
    stringsAsFactors = FALSE
  )
  DBI::dbAppendTable(
    con,
    "bars",
    bars
  )

  DBI::dbDisconnect(con, shutdown = TRUE)
  duckdb::duckdb_shutdown(drv)

  cost <- ledgr_cost_zero()
  cfg <- list(
    db_path = path,
    engine = list(seed = 1L, tz = "UTC"),
    universe = list(instrument_ids = c("AAA")),
    backtest = list(
      start_ts_utc = "2020-01-01T00:00:00Z",
      end_ts_utc = "2020-01-04T00:00:00Z",
      pulse = "EOD",
      initial_cash = 1000
    ),
    timing_model = {
      timing <- ledgr_timing_next_open()
      list(
        timing_schema_version = timing$timing_schema_version,
        type_id = timing$type_id,
        version = timing$version,
        args = timing$args
      )
    },
    cost_model = list(
      cost_model_hash = ledgr:::ledgr_cost_model_hash(cost),
      cost_plan_json = ledgr:::ledgr_cost_plan_json(cost)
    ),
    features = list(enabled = FALSE, defs = list()),
    strategy = list(id = "state_prev", params = list())
  )
  cfg <- ledgr_test_snapshot_backed_config(cfg, bars)

  run_id <- "run-state-prev"
  ledgr:::ledgr_run_fold(cfg, run_id = run_id, control = list(max_pulses = 2L))
  gc()
  Sys.sleep(0.05)

  drv <- duckdb::duckdb()
  con <- DBI::dbConnect(drv, dbdir = path)
  on.exit(duckdb::duckdb_shutdown(drv), add = TRUE)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  testthat::expect_warning(ledgr_run_config(cfg, run_id = run_id), "LEDGR_LAST_BAR_NO_FILL", fixed = TRUE)

  states <- DBI::dbGetQuery(
    con,
    "SELECT ts_utc, state_json FROM strategy_state WHERE run_id = ? ORDER BY ts_utc",
    params = list(run_id)
  )
  steps <- vapply(states$state_json, function(x) ledgr:::ledgr_json_read_nested(x)$step, numeric(1))
  testthat::expect_identical(states$ts_utc, c("2020-01-01T00:00:00Z", "2020-01-02T00:00:00Z", "2020-01-03T00:00:00Z", "2020-01-04T00:00:00Z"))
  testthat::expect_identical(as.integer(steps), c(1L, 2L, 3L, 4L))
})

testthat::test_that("db_live writes strategy_state only after pulse fill writes", {
  db_path <- make_runner_fixture_db()
  cfg <- ledgr_test_snapshot_backed_config(base_runner_config(db_path), attr(db_path, "bars"))
  cfg$engine$execution_mode <- "db_live"
  cfg$features <- list(enabled = FALSE, defs = list())

  ns <- asNamespace("ledgr")
  original <- get("ledgr_write_fill_events", envir = ns, inherits = FALSE)
  saw_state_before_fill <- FALSE
  unlockBinding("ledgr_write_fill_events", ns)
  assign(
    "ledgr_write_fill_events",
    function(con, run_id, fill_intent, event_seq_start = NULL, use_transaction = TRUE) {
      state_rows <- DBI::dbGetQuery(
        con,
        "SELECT COUNT(*) AS n FROM strategy_state WHERE run_id = ?",
        params = list(run_id)
      )$n[[1]]
      if (as.integer(state_rows) > 0L) saw_state_before_fill <<- TRUE
      original(con, run_id, fill_intent, event_seq_start = event_seq_start, use_transaction = use_transaction)
    },
    envir = ns
  )
  lockBinding("ledgr_write_fill_events", ns)
  on.exit(
    {
      unlockBinding("ledgr_write_fill_events", ns)
      assign("ledgr_write_fill_events", original, envir = ns)
      lockBinding("ledgr_write_fill_events", ns)
    },
    add = TRUE
  )

  run_id <- "run-db-live-state-order"
  ledgr:::ledgr_run_fold(cfg, run_id = run_id, control = list(max_pulses = 1L))
  testthat::expect_false(saw_state_before_fill)
  gc()
  Sys.sleep(0.05)

  drv <- duckdb::duckdb()
  con <- DBI::dbConnect(drv, dbdir = db_path)
  on.exit(duckdb::duckdb_shutdown(drv), add = TRUE)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  state_rows <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM strategy_state WHERE run_id = ?", params = list(run_id))$n[[1]]
  fill_rows <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM ledger_events WHERE run_id = ?", params = list(run_id))$n[[1]]
  testthat::expect_equal(as.integer(state_rows), 1L)
  testthat::expect_equal(as.integer(fill_rows), 1L)
})

testthat::test_that("run info projects recorded risk identity without side effects", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)
  bars <- data.frame(
    ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:5,
    instrument_id = "AAA",
    open = 100:105,
    high = 101:106,
    low = 99:104,
    close = 100:105,
    volume = 1000,
    stringsAsFactors = FALSE
  )
  snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  calls <- new.env(parent = emptyenv())
  calls$n <- 0L
  strategy <- function(ctx, params) {
    calls$n <- calls$n + 1L
    targets <- ctx$flat()
    targets["AAA"] <- params$qty
    targets
  }
  risk <- ledgr_risk_chain(
    ledgr_risk_long_only(),
    ledgr_risk_max_weight(0.50)
  )
  risk_hash <- ledgr:::ledgr_risk_chain_hash(risk)
  no_risk_hash <- ledgr:::ledgr_risk_chain_hash(ledgr_risk_none())

  direct_exp <- ledgr_experiment(
    snapshot,
    strategy,
    risk_chain = risk,
    cost_model = ledgr_cost_zero(),
    opening = ledgr_opening(cash = 1000)
  )
  direct <- ledgr_run(
    direct_exp,
    params = list(qty = 1),
    run_id = "risk-info-direct"
  )
  on.exit(close(direct), add = TRUE)

  no_risk_exp <- ledgr_experiment(
    snapshot,
    strategy,
    risk_chain = ledgr_risk_none(),
    cost_model = ledgr_cost_zero(),
    opening = ledgr_opening(cash = 1000)
  )
  no_risk <- ledgr_run(
    no_risk_exp,
    params = list(qty = 1),
    run_id = "risk-info-none"
  )
  on.exit(close(no_risk), add = TRUE)

  sweep <- ledgr_sweep(
    direct_exp,
    ledgr_param_grid(low = list(qty = 1), high = list(qty = 2)),
    seed = 123L
  )
  review <- ledgr_sweep_review(sweep, rank_by = -final_equity)
  candidate <- ledgr_candidate(review$ranked, 1L)
  promoted <- ledgr_promote(
    no_risk_exp,
    candidate,
    run_id = "risk-info-promoted"
  )
  on.exit(close(promoted), add = TRUE)
  calls_after_runs <- calls$n

  store_contents <- function() {
    opened <- ledgr:::ledgr_run_store_open(db_path)
    on.exit(ledgr:::ledgr_run_store_close(opened), add = TRUE)
    tables <- DBI::dbGetQuery(
      opened$con,
      paste(
        "SELECT table_name FROM information_schema.tables",
        "WHERE table_schema = 'main' AND table_type = 'BASE TABLE'",
        "ORDER BY table_name"
      )
    )$table_name
    stats::setNames(
      lapply(
        tables,
        function(table) {
          sql <- paste(
            "SELECT * FROM",
            DBI::dbQuoteIdentifier(opened$con, table),
            "ORDER BY ALL"
          )
          DBI::dbGetQuery(opened$con, sql)
        }
      ),
      tables
    )
  }

  before <- store_contents()
  direct_info <- ledgr_run_info(snapshot, "risk-info-direct")
  no_risk_info <- ledgr_run_info(snapshot, "risk-info-none")
  promoted_info <- ledgr_run_info(snapshot, "risk-info-promoted")
  after <- store_contents()

  testthat::expect_identical(direct_info$risk_chain_hash, risk_hash)
  testthat::expect_identical(promoted_info$risk_chain_hash, risk_hash)
  testthat::expect_identical(no_risk_info$risk_chain_hash, no_risk_hash)
  testthat::expect_type(direct_info$risk_chain_hash, "character")
  testthat::expect_false("risk_plan_json" %in% names(direct_info))
  testthat::expect_identical(after, before)
  testthat::expect_identical(calls$n, calls_after_runs)
  testthat::expect_output(print(direct_info), risk_hash, fixed = TRUE)

  opened <- ledgr:::ledgr_run_store_open(db_path)
  config_json <- DBI::dbGetQuery(
    opened$con,
    "SELECT config_json FROM runs WHERE run_id = 'risk-info-direct'"
  )$config_json[[1]]
  legacy_config <- ledgr:::ledgr_json_read_config(config_json)
  legacy_config$risk_chain <- NULL
  DBI::dbExecute(
    opened$con,
    "UPDATE runs SET config_json = ? WHERE run_id = 'risk-info-direct'",
    params = list(as.character(canonical_json(legacy_config)))
  )
  ledgr:::ledgr_run_store_close(opened)

  legacy_before <- store_contents()
  legacy_info <- ledgr_run_info(snapshot, "risk-info-direct")
  legacy_after <- store_contents()
  testthat::expect_identical(legacy_info$risk_chain_hash, NA_character_)
  testthat::expect_identical(legacy_after, legacy_before)
  testthat::expect_identical(calls$n, calls_after_runs)
})
