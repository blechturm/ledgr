testthat::test_that("cost primitive constructors validate and store canonical fields", {
  spread <- ledgr_cost_spread_bps(5)
  fixed <- ledgr_cost_fixed_fee(1.25)
  notional <- ledgr_cost_notional_bps_fee(2)
  zero <- ledgr_cost_zero()

  testthat::expect_s3_class(spread, "ledgr_cost_model")
  testthat::expect_identical(spread$type_id, "spread_bps")
  testthat::expect_identical(spread$stage, "price_transform")
  testthat::expect_equal(spread$args$bps, 5)

  testthat::expect_identical(fixed$type_id, "fixed_fee")
  testthat::expect_identical(fixed$stage, "fee_adder")
  testthat::expect_equal(fixed$args$amount, 1.25)

  testthat::expect_identical(notional$type_id, "notional_bps_fee")
  testthat::expect_identical(notional$stage, "fee_adder")
  testthat::expect_equal(notional$args$bps, 2)

  testthat::expect_identical(zero$type_id, "zero")
  testthat::expect_identical(zero$stage, "identity")

  testthat::expect_error(ledgr_cost_spread_bps(-1), class = "ledgr_invalid_cost_model")
  testthat::expect_error(ledgr_cost_fixed_fee(NA_real_), class = "ledgr_invalid_cost_model")
  testthat::expect_error(ledgr_cost_notional_bps_fee(Inf), class = "ledgr_invalid_cost_model")
})

testthat::test_that("cost chains preserve order and reject fee before price transform", {
  cost <- ledgr_cost_chain(
    ledgr_cost_spread_bps(5),
    ledgr_cost_fixed_fee(1),
    ledgr_cost_notional_bps_fee(2)
  )

  testthat::expect_s3_class(cost, "ledgr_cost_model")
  testthat::expect_identical(cost$type_id, "chain")

  steps <- ledgr_cost_steps(cost)
  testthat::expect_length(steps, 3)
  testthat::expect_identical(vapply(steps, `[[`, character(1), "type_id"), c("spread_bps", "fixed_fee", "notional_bps_fee"))
  testthat::expect_identical(vapply(steps, `[[`, character(1), "stage"), c("price_transform", "fee_adder", "fee_adder"))

  testthat::expect_error(
    ledgr_cost_chain(ledgr_cost_fixed_fee(1), ledgr_cost_spread_bps(5)),
    class = "ledgr_invalid_cost_chain_order"
  )
  testthat::expect_s3_class(ledgr_cost_chain(), "ledgr_cost_model")
  testthat::expect_length(ledgr_cost_steps(ledgr_cost_chain()), 0)
})

testthat::test_that("nested chains flatten deterministically and preserve hash identity", {
  flat <- ledgr_cost_chain(
    ledgr_cost_spread_bps(5),
    ledgr_cost_fixed_fee(1),
    ledgr_cost_notional_bps_fee(2)
  )
  nested <- ledgr_cost_chain(
    ledgr_cost_chain(ledgr_cost_spread_bps(5), ledgr_cost_fixed_fee(1)),
    ledgr_cost_notional_bps_fee(2)
  )
  zero_interleaved <- ledgr_cost_chain(
    ledgr_cost_spread_bps(5),
    ledgr_cost_zero(),
    ledgr_cost_fixed_fee(1),
    ledgr_cost_notional_bps_fee(2)
  )

  testthat::expect_length(ledgr_cost_steps(nested), 3)
  testthat::expect_length(ledgr_cost_steps(zero_interleaved), 3)
  testthat::expect_identical(
    ledgr:::ledgr_cost_model_hash(flat),
    ledgr:::ledgr_cost_model_hash(nested)
  )
  testthat::expect_identical(
    ledgr:::ledgr_cost_model_hash(flat),
    ledgr:::ledgr_cost_model_hash(zero_interleaved)
  )
})

testthat::test_that("cost identity is deterministic and content-sensitive", {
  a <- ledgr_cost_chain(ledgr_cost_spread_bps(5), ledgr_cost_fixed_fee(1))
  b <- ledgr_cost_chain(ledgr_cost_spread_bps(5), ledgr_cost_fixed_fee(1))
  c <- ledgr_cost_chain(ledgr_cost_spread_bps(6), ledgr_cost_fixed_fee(1))
  d <- ledgr_cost_chain(ledgr_cost_fixed_fee(1), ledgr_cost_notional_bps_fee(2))

  hash_a <- ledgr:::ledgr_cost_model_hash(a)
  hash_b <- ledgr:::ledgr_cost_model_hash(b)
  hash_c <- ledgr:::ledgr_cost_model_hash(c)
  hash_d <- ledgr:::ledgr_cost_model_hash(d)

  testthat::expect_match(hash_a, "^[0-9a-f]{64}$")
  testthat::expect_identical(hash_a, hash_b)
  testthat::expect_false(identical(hash_a, hash_c))
  testthat::expect_false(identical(hash_a, hash_d))

  plan <- ledgr:::ledgr_cost_plan_json(a)
  testthat::expect_true(is.character(plan))
  testthat::expect_match(plan, '"cost_schema_version":1', fixed = TRUE)
  testthat::expect_match(plan, '"type_id":"chain"', fixed = TRUE)
  testthat::expect_match(plan, '"type_id":"spread_bps"', fixed = TRUE)
})

testthat::test_that("cost describe is stable and includes step content", {
  cost <- ledgr_cost_chain(ledgr_cost_spread_bps(5), ledgr_cost_fixed_fee(1))
  desc <- ledgr_cost_describe(cost)

  testthat::expect_type(desc, "character")
  testthat::expect_length(desc, 1)
  testthat::expect_match(desc, "ledgr cost model: 2 step\\(s\\)")
  testthat::expect_match(desc, "spread_bps")
  testthat::expect_match(desc, "fixed_fee")
  testthat::expect_match(ledgr_cost_describe(ledgr_cost_zero()), "zero cost")
})

testthat::test_that("timing constructor is accepted by ledgr_experiment", {
  bars <- ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:4)
  snapshot <- ledgr_snapshot_from_df(bars, db_path = tempfile(fileext = ".duckdb"))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  strategy <- function(ctx, params) ctx$flat()

  timing <- ledgr_timing_next_open()
  exp <- ledgr_experiment(
    snapshot = snapshot,
    strategy = strategy,
    timing_model = timing,
    cost_model = ledgr_cost_zero()
  )

  testthat::expect_s3_class(timing, "ledgr_timing_model")
  testthat::expect_s3_class(exp$timing_model, "ledgr_timing_model")
  testthat::expect_identical(exp$timing_model$type_id, "next_open")
  testthat::expect_error(
    ledgr_experiment(
      snapshot = snapshot,
      strategy = strategy,
      timing_model = list(type_id = "next_open"),
      cost_model = ledgr_cost_zero()
    ),
    class = "ledgr_invalid_timing_model"
  )
})

testthat::test_that("optional cost identity is stored on experiments and configs", {
  bars <- ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:4)
  snapshot <- ledgr_snapshot_from_df(bars, db_path = tempfile(fileext = ".duckdb"))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  strategy <- function(ctx, params) ctx$flat()
  cost <- ledgr_cost_chain(ledgr_cost_spread_bps(5), ledgr_cost_fixed_fee(1))

  exp <- ledgr_experiment(
    snapshot = snapshot,
    strategy = strategy,
    cost_model = cost
  )

  testthat::expect_s3_class(exp$cost_model, "ledgr_cost_model")
  testthat::expect_identical(exp$cost_model_hash, ledgr:::ledgr_cost_model_hash(cost))
  testthat::expect_identical(exp$cost_plan_json, ledgr:::ledgr_cost_plan_json(cost))

  bt <- ledgr_run(exp, run_id = "cost-identity-config", seed = 1L)
  on.exit(close(bt), add = TRUE)
  testthat::expect_identical(bt$config$cost_model$cost_model_hash, exp$cost_model_hash)
  testthat::expect_identical(bt$config$cost_model$cost_plan_json, exp$cost_plan_json)

  prov <- ledgr:::ledgr_sweep_provenance(
    snapshot_hash = "snapshot",
    strategy_hash = "strategy",
    feature_set_hash = "features",
    cost_model_hash = exp$cost_model_hash,
    cost_plan_json = exp$cost_plan_json,
    master_seed = 1L
  )
  testthat::expect_identical(prov$cost_model_hash, exp$cost_model_hash)
  testthat::expect_identical(prov$cost_plan_json, exp$cost_plan_json)
})

testthat::test_that("cost model is required and legacy fill_model fails loudly", {
  bars <- ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:4)
  snapshot <- ledgr_snapshot_from_df(bars, db_path = tempfile(fileext = ".duckdb"))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  strategy <- function(ctx, params) ctx$flat()

  testthat::expect_error(
    ledgr_experiment(snapshot = snapshot, strategy = strategy),
    class = "ledgr_cost_model_unspecified"
  )
  testthat::expect_error(
    ledgr_experiment(
      snapshot = snapshot,
      strategy = strategy,
      cost_model = ledgr_cost_zero(),
      fill_model = list(type = "next_open", spread_bps = 0, commission_fixed = 0)
    ),
    class = "ledgr_legacy_fill_model_shape"
  )
})

testthat::test_that("cost model applies half-spread price transforms and explicit fees", {
  bars <- ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:4)
  bars$open <- c(100, 110, 120, 130, 140)
  bars$high <- bars$open
  bars$low <- bars$open
  bars$close <- bars$open
  snapshot <- ledgr_snapshot_from_df(bars, db_path = tempfile(fileext = ".duckdb"))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    targets[["AAA"]] <- 1
    targets
  }
  cost <- ledgr_cost_chain(ledgr_cost_spread_bps(100), ledgr_cost_fixed_fee(2))
  exp <- ledgr_experiment(snapshot, strategy, cost_model = cost)
  bt <- ledgr_run(exp, run_id = "cost-arithmetic")
  on.exit(close(bt), add = TRUE)
  fills <- ledgr_results(bt, "fills")
  equity <- ledgr_results(bt, "equity")

  testthat::expect_equal(nrow(fills), 1L)
  testthat::expect_equal(fills$price[[1]], 110 * (1 + 100 / 20000))
  testthat::expect_equal(fills$fee[[1]], 2)
  testthat::expect_equal(equity$cash[[length(equity$cash)]], equity$cash[[1]] - fills$price[[1]] - 2)
})

testthat::test_that("notional fees use spread-adjusted pre-rounding price", {
  proposal <- ledgr:::ledgr_next_open_fill_proposal(
    desired_qty_delta = 3,
    next_bar = list(
      instrument_id = "AAA",
      ts_utc = "2020-01-02T00:00:00Z",
      open = 100.123456789
    )
  )
  resolver <- ledgr:::ledgr_cost_resolver_from_model(
    ledgr_cost_chain(
      ledgr_cost_spread_bps(7),
      ledgr_cost_notional_bps_fee(10)
    ),
    price_round_digits = 2L
  )
  fill <- ledgr:::ledgr_resolve_fill_proposal(proposal, resolver)
  spread_adjusted <- 100.123456789 * (1 + 7 / 20000)

  testthat::expect_equal(fill$fill_price, round(spread_adjusted, 2))
  testthat::expect_equal(fill$fee, abs(3 * spread_adjusted) * 10 / 10000)
})

testthat::test_that("direct run, sweep candidate, and promotion preserve cost identity", {
  bars <- ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:5)
  snapshot <- ledgr_snapshot_from_df(bars, db_path = tempfile(fileext = ".duckdb"))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    targets[["AAA"]] <- params$qty
    targets
  }
  cost <- ledgr_cost_chain(ledgr_cost_spread_bps(25), ledgr_cost_fixed_fee(1))
  exp <- ledgr_experiment(snapshot, strategy, cost_model = cost)
  grid <- ledgr_param_grid(candidate = list(qty = 1))

  sweep <- ledgr_sweep(exp, grid, seed = 123L)
  candidate <- ledgr_candidate(sweep, "candidate")
  promoted <- ledgr_promote(exp, candidate, run_id = "cost-promoted")
  on.exit(close(promoted), add = TRUE)
  direct <- ledgr_run(exp, params = candidate$params, seed = candidate$execution_seed, run_id = "cost-direct")
  on.exit(close(direct), add = TRUE)

  eq_promoted <- ledgr_results(promoted, "equity")
  eq_direct <- ledgr_results(direct, "equity")
  testthat::expect_equal(eq_promoted$equity, eq_direct$equity)
  testthat::expect_identical(attr(sweep, "cost_model_hash"), ledgr:::ledgr_cost_model_hash(cost))
  testthat::expect_identical(attr(sweep, "cost_plan_json"), ledgr:::ledgr_cost_plan_json(cost))
  testthat::expect_identical(promoted$config$cost_model$cost_model_hash, ledgr:::ledgr_cost_model_hash(cost))
  testthat::expect_identical(promoted$config$cost_model$cost_plan_json, ledgr:::ledgr_cost_plan_json(cost))
})

testthat::test_that("ledgr_backtest shares required cost and legacy fill_model behavior", {
  bars <- ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:4)
  strategy <- function(ctx, params) ctx$flat()
  testthat::expect_error(
    ledgr_backtest(data = bars, strategy = strategy),
    class = "ledgr_cost_model_unspecified"
  )
  testthat::expect_error(
    ledgr_backtest(
      data = bars,
      strategy = strategy,
      cost_model = ledgr_cost_zero(),
      fill_model = list(type = "next_open", spread_bps = 0, commission_fixed = 0)
    ),
    class = "ledgr_legacy_fill_model_shape"
  )
})

testthat::test_that("ledgr_run_open rejects stored legacy fill_model config", {
  bars <- ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:4)
  db_path <- tempfile(fileext = ".duckdb")
  snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  strategy <- function(ctx, params) ctx$flat()
  exp <- ledgr_experiment(snapshot, strategy, cost_model = ledgr_cost_zero())
  bt <- ledgr_run(exp, run_id = "legacy-reopen-fixture")
  close(bt)

  legacy_cfg <- bt$config
  legacy_cfg$fill_model <- list(type = "next_open", spread_bps = 0, commission_fixed = 0)
  legacy_cfg$timing_model <- NULL
  legacy_cfg$cost_model <- NULL
  con <- ledgr:::get_connection(snapshot)
  DBI::dbExecute(
    con,
    "UPDATE runs SET config_json = ? WHERE run_id = ?",
    params = list(ledgr:::canonical_json(legacy_cfg), "legacy-reopen-fixture")
  )

  testthat::expect_error(
    ledgr_run_open(snapshot, "legacy-reopen-fixture"),
    class = "ledgr_legacy_config_shape"
  )
})
