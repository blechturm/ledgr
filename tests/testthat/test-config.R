ledgr_test_cost_identity <- function(cost_model = ledgr_cost_zero()) {
  list(
    cost_model_hash = ledgr:::ledgr_cost_model_hash(cost_model),
    cost_plan_json = ledgr:::ledgr_cost_plan_json(cost_model)
  )
}

ledgr_test_timing_model <- function() {
  timing <- ledgr_timing_next_open()
  list(
    timing_schema_version = timing$timing_schema_version,
    type_id = timing$type_id,
    version = timing$version,
    args = timing$args
  )
}

ledgr_test_cost_config <- function(cost_model = ledgr_cost_zero()) {
  ledgr_test_cost_identity(cost_model)
}

testthat::test_that("canonicalization is stable across key ordering (including nested lists)", {
  cost_cfg <- ledgr_test_cost_config(ledgr_cost_spread_bps(1))
  cfg1 <- list(
    db_path = "db.duckdb",
    engine = list(seed = 1L, tz = "UTC"),
    universe = list(instrument_ids = c("B", "A")),
    backtest = list(
      start_ts_utc = "2020-01-01T00:00:00Z",
      end_ts_utc = "2020-01-10T00:00:00Z",
      pulse = "EOD",
      initial_cash = 1000
    ),
    timing_model = ledgr_test_timing_model(),
    cost_model = cost_cfg,
    strategy = list(id = "buy_and_hold", params = list(z = 1, a = 2))
  )

  cfg2 <- list(
    strategy = list(params = list(a = 2, z = 1), id = "buy_and_hold"),
    cost_model = cost_cfg,
    timing_model = ledgr_test_timing_model(),
    backtest = list(
      initial_cash = 1000,
      pulse = "EOD",
      end_ts_utc = "2020-01-10T00:00:00Z",
      start_ts_utc = "2020-01-01T00:00:00Z"
    ),
    universe = list(instrument_ids = c("B", "A")),
    engine = list(tz = "UTC", seed = 1L),
    db_path = "db.duckdb"
  )

  j1 <- ledgr:::canonical_json(cfg1)
  j2 <- ledgr:::canonical_json(cfg2)
  testthat::expect_identical(j1, j2)

  h1 <- ledgr:::config_hash(cfg1)
  h2 <- ledgr:::config_hash(cfg2)
  testthat::expect_identical(h1, h2)
})

testthat::test_that("hash is deterministic and sensitive to small changes", {
  cost_cfg <- ledgr_test_cost_config(ledgr_cost_spread_bps(1))
  cfg <- list(
    db_path = "db.duckdb",
    engine = list(seed = 1L, tz = "UTC"),
    universe = list(instrument_ids = c("A")),
    backtest = list(
      start_ts_utc = "2020-01-01T00:00:00Z",
      end_ts_utc = "2020-01-01T00:00:00Z",
      pulse = "EOD",
      initial_cash = 1000
    ),
    timing_model = ledgr_test_timing_model(),
    cost_model = cost_cfg,
    strategy = list(id = "x")
  )

  testthat::expect_identical(ledgr:::config_hash(cfg), ledgr:::config_hash(cfg))

  cfg2 <- cfg
  cfg2$engine$seed <- 2L
  testthat::expect_false(identical(ledgr:::config_hash(cfg), ledgr:::config_hash(cfg2)))
})

testthat::test_that("config hash excludes storage paths and run-local diagnostics", {
  cost_cfg <- ledgr_test_cost_config(ledgr_cost_spread_bps(1))
  cfg <- list(
    db_path = "store-a.duckdb",
    run_id = "run-a",
    engine = list(seed = 1L, tz = "UTC"),
    universe = list(instrument_ids = c("A")),
    backtest = list(
      start_ts_utc = "2020-01-01T00:00:00Z",
      end_ts_utc = "2020-01-01T00:00:00Z",
      pulse = "EOD",
      initial_cash = 1000
    ),
    timing_model = ledgr_test_timing_model(),
    cost_model = cost_cfg,
    alias_map_order = c("slow", "fast"),
    data = list(
      source = "snapshot",
      snapshot_id = "snap-a",
      snapshot_db_path = "snapshot-a.duckdb"
    ),
    strategy = list(id = "x")
  )

  cfg2 <- cfg
  cfg2$db_path <- "store-b.duckdb"
  cfg2$run_id <- "run-b"
  cfg2$alias_map_order <- rev(cfg$alias_map_order)
  cfg2$data$snapshot_db_path <- "snapshot-b.duckdb"

  testthat::expect_false(identical(ledgr:::canonical_json(cfg), ledgr:::canonical_json(cfg2)))
  testthat::expect_identical(ledgr:::config_hash(cfg), ledgr:::config_hash(cfg2))

  cfg3 <- cfg
  cfg3$data$snapshot_id <- "snap-b"
  testthat::expect_false(identical(ledgr:::config_hash(cfg), ledgr:::config_hash(cfg3)))
})

testthat::test_that("config hash excludes derived feature-set hash surface", {
  cost_cfg <- ledgr_test_cost_config(ledgr_cost_spread_bps(1))
  cfg <- list(
    db_path = "db.duckdb",
    engine = list(seed = 1L, tz = "UTC"),
    universe = list(instrument_ids = c("A")),
    backtest = list(
      start_ts_utc = "2020-01-01T00:00:00Z",
      end_ts_utc = "2020-01-01T00:00:00Z",
      pulse = "EOD",
      initial_cash = 1000
    ),
    timing_model = ledgr_test_timing_model(),
    cost_model = cost_cfg,
    features = list(
      enabled = TRUE,
      defs = list(list(id = "sma_2", fingerprint = "feature-fingerprint")),
      feature_set_hash = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
      persist = TRUE
    ),
    strategy = list(id = "x")
  )

  cfg2 <- cfg
  cfg2$features$feature_set_hash <- "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
  testthat::expect_identical(ledgr:::config_hash(cfg), ledgr:::config_hash(cfg2))

  cfg3 <- cfg
  cfg3$features$defs[[1]]$fingerprint <- "changed-feature-fingerprint"
  testthat::expect_false(identical(ledgr:::config_hash(cfg), ledgr:::config_hash(cfg3)))
})

testthat::test_that("config hash excludes sweep retention policy", {
  cost_cfg <- ledgr_test_cost_config(ledgr_cost_spread_bps(1))
  cfg <- list(
    db_path = "db.duckdb",
    engine = list(seed = 1L, tz = "UTC"),
    universe = list(instrument_ids = c("A")),
    backtest = list(
      start_ts_utc = "2020-01-01T00:00:00Z",
      end_ts_utc = "2020-01-01T00:00:00Z",
      pulse = "EOD",
      initial_cash = 1000
    ),
    timing_model = ledgr_test_timing_model(),
    cost_model = cost_cfg,
    strategy = list(id = "x")
  )

  cfg_top_level <- cfg
  cfg_top_level$sweep_retention <- ledgr_sweep_retention("completed")

  cfg_nested <- cfg
  cfg_nested$sweep <- list(retention = ledgr_sweep_retention("completed"))

  testthat::expect_identical(ledgr:::config_hash(cfg), ledgr:::config_hash(cfg_top_level))
  testthat::expect_identical(ledgr:::config_hash(cfg), ledgr:::config_hash(cfg_nested))

  cfg_identity_change <- cfg
  cfg_identity_change$engine$seed <- 2L
  testthat::expect_false(identical(ledgr:::config_hash(cfg), ledgr:::config_hash(cfg_identity_change)))
})

testthat::test_that("cost-model config hash is stable across internal cost-boundary refactors", {
  cost_cfg <- ledgr_test_cost_config(
    ledgr_cost_chain(ledgr_cost_spread_bps(5), ledgr_cost_fixed_fee(1.25))
  )
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
    timing_model = ledgr_test_timing_model(),
    cost_model = cost_cfg,
    strategy = list(id = "x", params = list())
  )

  testthat::expect_identical(
    ledgr:::config_hash(cfg),
    "23838c7297b9ec8a09b422f9f4a29933fb61b7cdbd8b030789ff4b2f441ae57b"
  )
})

testthat::test_that("instrument_ids ordering affects canonical JSON and hash", {
  cost_cfg <- ledgr_test_cost_config(ledgr_cost_spread_bps(1))
  cfg1 <- list(
    db_path = "db.duckdb",
    engine = list(seed = 1L, tz = "UTC"),
    universe = list(instrument_ids = c("A", "B")),
    backtest = list(
      start_ts_utc = "2020-01-01T00:00:00Z",
      end_ts_utc = "2020-01-02T00:00:00Z",
      pulse = "EOD",
      initial_cash = 1000
    ),
    timing_model = ledgr_test_timing_model(),
    cost_model = cost_cfg,
    strategy = list(id = "x")
  )

  cfg2 <- cfg1
  cfg2$universe$instrument_ids <- c("B", "A")

  testthat::expect_false(identical(ledgr:::canonical_json(cfg1), ledgr:::canonical_json(cfg2)))
  testthat::expect_false(identical(ledgr:::config_hash(cfg1), ledgr:::config_hash(cfg2)))
})

testthat::test_that("validation fails loud on required fields and constraints", {
  cost_cfg <- ledgr_test_cost_config(ledgr_cost_spread_bps(1))
  base_cfg <- list(
    db_path = "db.duckdb",
    engine = list(seed = 1L, tz = "UTC"),
    universe = list(instrument_ids = c("A")),
    backtest = list(
      start_ts_utc = "2020-01-01T00:00:00Z",
      end_ts_utc = "2020-01-02T00:00:00Z",
      pulse = "EOD",
      initial_cash = 1000
    ),
    timing_model = ledgr_test_timing_model(),
    cost_model = cost_cfg,
    strategy = list(id = "x")
  )

  cfg_missing_cash <- base_cfg
  cfg_missing_cash$backtest$initial_cash <- NULL
  testthat::expect_error(ledgr:::ledgr_validate_config(cfg_missing_cash), "backtest.initial_cash", fixed = TRUE)

  cfg_empty_universe <- base_cfg
  cfg_empty_universe$universe$instrument_ids <- character()
  testthat::expect_error(ledgr:::ledgr_validate_config(cfg_empty_universe), "universe.instrument_ids", fixed = TRUE)

  cfg_bad_range <- base_cfg
  cfg_bad_range$backtest$start_ts_utc <- "2020-01-03T00:00:00Z"
  cfg_bad_range$backtest$end_ts_utc <- "2020-01-02T00:00:00Z"
  testthat::expect_error(ledgr:::ledgr_validate_config(cfg_bad_range), "start_ts_utc", fixed = TRUE)

  cfg_bad_tz <- base_cfg
  cfg_bad_tz$engine$tz <- "Europe/Vienna"
  testthat::expect_error(ledgr:::ledgr_validate_config(cfg_bad_tz), "engine.tz", fixed = TRUE)

  cfg_bad_cost_hash <- base_cfg
  cfg_bad_cost_hash$cost_model$cost_model_hash <- "not-a-hash"
  testthat::expect_error(ledgr:::ledgr_validate_config(cfg_bad_cost_hash), "cost_model.cost_model_hash", fixed = TRUE)

  cfg_bad_cost_plan <- base_cfg
  cfg_bad_cost_plan$cost_model$cost_plan_json <- "{}"
  testthat::expect_error(ledgr:::ledgr_validate_config(cfg_bad_cost_plan), "cost_model.cost_model_hash", fixed = TRUE)

  cfg_bad_timing <- base_cfg
  cfg_bad_timing$timing_model$type_id <- "market"
  testthat::expect_error(ledgr:::ledgr_validate_config(cfg_bad_timing), "timing_model.type_id", fixed = TRUE)

  cfg_legacy_fill <- base_cfg
  cfg_legacy_fill$fill_model <- list(type = "next_open", spread_bps = 1, commission_fixed = 0)
  testthat::expect_error(ledgr:::ledgr_validate_config(cfg_legacy_fill), class = "ledgr_legacy_config_shape")

  cfg_bad_pulse <- base_cfg
  cfg_bad_pulse$backtest$pulse <- "INTRADAY"
  testthat::expect_error(ledgr:::ledgr_validate_config(cfg_bad_pulse), "backtest.pulse", fixed = TRUE)

  cfg_bad_seed <- base_cfg
  cfg_bad_seed$engine$seed <- 1.2
  testthat::expect_error(ledgr:::ledgr_validate_config(cfg_bad_seed), "engine.seed", fixed = TRUE)
})

testthat::test_that("canonical JSON does not include environment addresses or environment serialization", {
  cfg <- list(a = 1, z = 2)
  j <- ledgr:::canonical_json(cfg)
  testthat::expect_false(grepl("0x[0-9a-fA-F]+", j))
  testthat::expect_false(grepl("<environment", j, fixed = TRUE))

  cfg_env <- list(strategy = list(id = "x", params = list(env = environment())))
  testthat::expect_error(ledgr:::canonical_json(cfg_env), "unsupported", ignore.case = TRUE)
})

testthat::test_that("validation passes for a minimal valid config (list and JSON string)", {
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
    timing_model = ledgr_test_timing_model(),
    cost_model = ledgr_test_cost_config(),
    strategy = list(id = "x", params = list()),
    data = list(source = "snapshot", snapshot_id = "test-snapshot")
  )

  testthat::expect_error(ledgr:::ledgr_validate_config(cfg), NA)

  cfg_json <- ledgr:::canonical_json(cfg)
  testthat::expect_error(ledgr:::ledgr_validate_config(cfg_json), NA)
})
