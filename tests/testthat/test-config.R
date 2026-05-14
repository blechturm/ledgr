testthat::test_that("canonicalization is stable across key ordering (including nested lists)", {
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
    fill_model = list(type = "next_open", spread_bps = 1, commission_fixed = 0),
    strategy = list(id = "buy_and_hold", params = list(z = 1, a = 2))
  )

  cfg2 <- list(
    strategy = list(params = list(a = 2, z = 1), id = "buy_and_hold"),
    fill_model = list(commission_fixed = 0, spread_bps = 1, type = "next_open"),
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
    fill_model = list(type = "next_open", spread_bps = 1, commission_fixed = 0),
    strategy = list(id = "x")
  )

  testthat::expect_identical(ledgr:::config_hash(cfg), ledgr:::config_hash(cfg))

  cfg2 <- cfg
  cfg2$engine$seed <- 2L
  testthat::expect_false(identical(ledgr:::config_hash(cfg), ledgr:::config_hash(cfg2)))
})

testthat::test_that("scalar fill-model config hash is stable across internal cost-boundary refactors", {
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
    fill_model = list(type = "next_open", spread_bps = 5, commission_fixed = 1.25),
    strategy = list(id = "x", params = list())
  )

  testthat::expect_identical(
    ledgr:::config_hash(cfg),
    "948146c214583b5bf2e200113d0bc5c065d834624b0701b1d099157b15833b3f"
  )
})

testthat::test_that("instrument_ids ordering affects canonical JSON and hash", {
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
    fill_model = list(type = "next_open", spread_bps = 1, commission_fixed = 0),
    strategy = list(id = "x")
  )

  cfg2 <- cfg1
  cfg2$universe$instrument_ids <- c("B", "A")

  testthat::expect_false(identical(ledgr:::canonical_json(cfg1), ledgr:::canonical_json(cfg2)))
  testthat::expect_false(identical(ledgr:::config_hash(cfg1), ledgr:::config_hash(cfg2)))
})

testthat::test_that("validation fails loud on required fields and constraints", {
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
    fill_model = list(type = "next_open", spread_bps = 1, commission_fixed = 0),
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

  cfg_neg_spread <- base_cfg
  cfg_neg_spread$fill_model$spread_bps <- -1
  testthat::expect_error(ledgr:::ledgr_validate_config(cfg_neg_spread), "fill_model.spread_bps", fixed = TRUE)

  cfg_neg_commission <- base_cfg
  cfg_neg_commission$fill_model$commission_fixed <- -0.01
  testthat::expect_error(ledgr:::ledgr_validate_config(cfg_neg_commission), "fill_model.commission_fixed", fixed = TRUE)

  cfg_bad_fill <- base_cfg
  cfg_bad_fill$fill_model$type <- "market"
  testthat::expect_error(ledgr:::ledgr_validate_config(cfg_bad_fill), "fill_model.type", fixed = TRUE)

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
    fill_model = list(type = "next_open", spread_bps = 1, commission_fixed = 0),
    strategy = list(id = "x", params = list())
  )

  testthat::expect_error(ledgr:::ledgr_validate_config(cfg), NA)

  cfg_json <- jsonlite::toJSON(cfg, auto_unbox = TRUE, null = "null", digits = NA)
  testthat::expect_error(ledgr:::ledgr_validate_config(cfg_json), NA)
})
