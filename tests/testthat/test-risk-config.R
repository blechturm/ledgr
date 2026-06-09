ledgr_risk_test_timing_model <- function() {
  timing <- ledgr_timing_next_open()
  list(
    timing_schema_version = timing$timing_schema_version,
    type_id = timing$type_id,
    version = timing$version,
    args = timing$args
  )
}

ledgr_risk_test_cost_config <- function(cost_model = ledgr_cost_zero()) {
  list(
    cost_model_hash = ledgr:::ledgr_cost_model_hash(cost_model),
    cost_plan_json = ledgr:::ledgr_cost_plan_json(cost_model)
  )
}

testthat::test_that("experiment and run configs carry no-op risk identity by default", {
  bars <- ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:4)
  snapshot <- ledgr_snapshot_from_df(bars, db_path = tempfile(fileext = ".duckdb"))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  strategy <- function(ctx, params) ctx$flat()

  exp <- ledgr_experiment(snapshot, strategy, cost_model = ledgr_cost_zero())
  noop <- ledgr_risk_none()
  testthat::expect_s3_class(exp$risk_chain, "ledgr_risk_model")
  testthat::expect_identical(exp$risk_chain_hash, ledgr:::ledgr_risk_chain_hash(noop))
  testthat::expect_identical(exp$risk_plan_json, ledgr:::ledgr_risk_plan_json(noop))

  bt <- ledgr_run(exp, run_id = "risk-default-config", seed = 1L)
  on.exit(close(bt), add = TRUE)
  testthat::expect_identical(bt$config$risk_chain$risk_chain_hash, exp$risk_chain_hash)
  testthat::expect_identical(bt$config$risk_chain$risk_plan_json, exp$risk_plan_json)
})

testthat::test_that("risk identity participates in config_hash without a separate risk params layer", {
  cost <- ledgr_cost_zero()
  cfg <- list(
    db_path = "db.duckdb",
    engine = list(seed = 1L, tz = "UTC"),
    universe = list(instrument_ids = c("A")),
    backtest = list(
      start_ts_utc = "2020-01-01T00:00:00Z",
      end_ts_utc = "2020-01-02T00:00:00Z",
      pulse = "EOD",
      initial_cash = 1000
    ),
    timing_model = ledgr_risk_test_timing_model(),
    cost_model = ledgr_risk_test_cost_config(cost),
    risk_chain = list(
      risk_chain_hash = ledgr:::ledgr_risk_chain_hash(ledgr_risk_none()),
      risk_plan_json = ledgr:::ledgr_risk_plan_json(ledgr_risk_none())
    ),
    strategy = list(id = "x", params = list()),
    data = list(source = "snapshot", snapshot_id = "test-snapshot")
  )

  cfg_missing <- cfg
  cfg_missing$risk_chain <- NULL
  testthat::expect_identical(ledgr:::config_hash(cfg), ledgr:::config_hash(cfg_missing))

  cfg_null_equivalent <- cfg
  cfg_null_equivalent$risk_chain <- list(
    risk_chain_hash = ledgr:::ledgr_risk_chain_hash(NULL),
    risk_plan_json = ledgr:::ledgr_risk_plan_json(NULL)
  )
  testthat::expect_identical(ledgr:::config_hash(cfg), ledgr:::config_hash(cfg_null_equivalent))

  cfg_cost <- cfg
  cfg_cost$cost_model <- ledgr_risk_test_cost_config(ledgr_cost_spread_bps(5))
  testthat::expect_false(identical(ledgr:::config_hash(cfg), ledgr:::config_hash(cfg_cost)))

  cfg_risk <- cfg
  risk <- ledgr_risk_chain(ledgr_risk_long_only(), ledgr_risk_max_weight(0.5))
  cfg_risk$risk_chain <- list(
    risk_chain_hash = ledgr:::ledgr_risk_chain_hash(risk),
    risk_plan_json = ledgr:::ledgr_risk_plan_json(risk)
  )
  testthat::expect_false(identical(ledgr:::config_hash(cfg), ledgr:::config_hash(cfg_risk)))

})

testthat::test_that("risk config validation fails closed on mismatched or invalid plan identity", {
  cfg <- list(
    db_path = "db.duckdb",
    engine = list(seed = 1L, tz = "UTC"),
    universe = list(instrument_ids = c("A")),
    backtest = list(
      start_ts_utc = "2020-01-01T00:00:00Z",
      end_ts_utc = "2020-01-02T00:00:00Z",
      pulse = "EOD",
      initial_cash = 1000
    ),
    timing_model = ledgr_risk_test_timing_model(),
    cost_model = ledgr_risk_test_cost_config(),
    risk_chain = list(
      risk_chain_hash = ledgr:::ledgr_risk_chain_hash(ledgr_risk_none()),
      risk_plan_json = ledgr:::ledgr_risk_plan_json(ledgr_risk_none())
    ),
    strategy = list(id = "x", params = list()),
    data = list(source = "snapshot", snapshot_id = "test-snapshot")
  )

  testthat::expect_error(ledgr:::ledgr_validate_config(cfg), NA)

  cfg_bad_hash <- cfg
  cfg_bad_hash$risk_chain$risk_chain_hash <- "not-a-hash"
  testthat::expect_error(ledgr:::ledgr_validate_config(cfg_bad_hash), "risk_chain.risk_chain_hash", fixed = TRUE)

  cfg_bad_plan <- cfg
  cfg_bad_plan$risk_chain$risk_plan_json <- "{}"
  testthat::expect_error(ledgr:::ledgr_validate_config(cfg_bad_plan), "risk_chain.risk_chain_hash", fixed = TRUE)
})

testthat::test_that("stored pre-risk run config reopens with in-memory no-op risk identity only", {
  bars <- ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:4)
  db_path <- tempfile(fileext = ".duckdb")
  snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  strategy <- function(ctx, params) ctx$flat()
  exp <- ledgr_experiment(snapshot, strategy, cost_model = ledgr_cost_zero())
  bt <- ledgr_run(exp, run_id = "legacy-risk-reopen")
  close(bt)

  legacy_cfg <- bt$config
  legacy_cfg$risk_chain <- NULL
  legacy_cfg_json <- ledgr:::canonical_json(legacy_cfg)
  con <- ledgr:::get_connection(snapshot)
  DBI::dbExecute(
    con,
    "UPDATE runs SET config_json = ? WHERE run_id = ?",
    params = list(legacy_cfg_json, "legacy-risk-reopen")
  )

  reopened <- ledgr_run_open(snapshot, "legacy-risk-reopen")
  on.exit(close(reopened), add = TRUE)
  testthat::expect_identical(
    reopened$config$risk_chain$risk_chain_hash,
    ledgr:::ledgr_risk_chain_hash(ledgr_risk_none())
  )
  stored_json <- DBI::dbGetQuery(
    con,
    "SELECT config_json FROM runs WHERE run_id = ?",
    params = list("legacy-risk-reopen")
  )$config_json[[1]]
  testthat::expect_identical(as.character(stored_json), as.character(legacy_cfg_json))
})
