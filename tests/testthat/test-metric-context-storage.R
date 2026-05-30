testthat::test_that("ledgr_run stores recoverable metric context outside execution identity", {
  bars <- ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:4)
  db_path <- tempfile(fileext = ".duckdb")
  snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  strategy <- function(ctx, params) ctx$flat()
  context <- ledgr_metric_us_equity(
    risk_free_rate = ledgr_risk_free_rate(0.04, label = "policy label", source = "manual", as_of = "2026-05-24")
  )
  exp <- ledgr_experiment(snapshot, strategy, metric_context = context)

  bt <- ledgr_run(exp, params = list(), run_id = "metric-context-run")
  on.exit(close(bt), add = TRUE)

  opened <- ledgr_test_open_duckdb(db_path)
  on.exit(ledgr_test_close_duckdb(opened$con, opened$drv), add = TRUE)
  row <- DBI::dbGetQuery(
    opened$con,
    "
    SELECT config_json, config_hash, metric_context_json, metric_context_hash,
           metric_context_version
    FROM runs
    WHERE run_id = 'metric-context-run'
    "
  )
  testthat::expect_identical(nrow(row), 1L)
  testthat::expect_false(grepl("metric_context", row$config_json[[1]], fixed = TRUE))
  testthat::expect_identical(row$metric_context_hash[[1]], ledgr_metric_context_hash(context))
  testthat::expect_identical(as.integer(row$metric_context_version[[1]]), 1L)
  testthat::expect_match(row$metric_context_json[[1]], "policy label", fixed = TRUE)

  recovered <- ledgr_metric_context(bt)
  testthat::expect_s3_class(recovered, "ledgr_metric_context")
  testthat::expect_identical(recovered$risk_free_rate$label, "policy label")
  testthat::expect_identical(recovered$risk_free_rate$as_of, as.Date("2026-05-24"))
  testthat::expect_identical(ledgr_metric_context_hash(recovered), ledgr_metric_context_hash(context))
})

testthat::test_that("metric context changes do not change execution config hashes", {
  bars <- ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:4)
  snapshot <- ledgr_snapshot_from_df(bars, db_path = tempfile(fileext = ".duckdb"))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  strategy <- function(ctx, params) ctx$flat()

  exp_zero <- ledgr_experiment(snapshot, strategy, metric_context = ledgr_metric_context(risk_free_rate = 0))
  exp_rf <- ledgr_experiment(snapshot, strategy, metric_context = ledgr_metric_context(risk_free_rate = 0.05))

  build_config <- function(exp) {
    ledgr_config(
      snapshot = exp$snapshot,
      universe = exp$universe,
      strategy = exp$strategy,
      strategy_params = list(),
      backtest = ledgr_backtest_config(
        start = exp$snapshot$metadata$start_date,
        end = exp$snapshot$metadata$end_date,
        initial_cash = exp$opening$cash
      ),
      features = ledgr_experiment_materialize_features(exp, list()),
      persist_features = exp$persist_features,
      execution_mode = exp$execution_mode,
      fill_model = exp$fill_model,
      db_path = exp$snapshot$db_path,
      opening = exp$opening,
      seed = 123L
    )
  }

  cfg_zero <- build_config(exp_zero)
  cfg_rf <- build_config(exp_rf)
  testthat::expect_identical(ledgr:::config_hash(cfg_zero), ledgr:::config_hash(cfg_rf))
  testthat::expect_false("metric_context" %in% names(cfg_zero))
})

testthat::test_that("legacy runs without stored metric context fall back to default context", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  ledgr_create_schema(con)
  DBI::dbExecute(
    con,
    "
    INSERT INTO runs (
      run_id, created_at_utc, engine_version, config_json, config_hash,
      status, error_msg
    ) VALUES (
      'legacy-context-run', TIMESTAMP '2020-01-01 00:00:00', '0.1.8.1',
      '{}', 'config-hash', 'DONE', NULL
    )
    "
  )

  context <- ledgr:::ledgr_run_metric_context_from_db(con, "legacy-context-run")
  testthat::expect_s3_class(context, "ledgr_metric_context")
  testthat::expect_equal(context$risk_free_rate$annual_rate, 0)
  testthat::expect_identical(context$calendar$source, "us_equity")
})
