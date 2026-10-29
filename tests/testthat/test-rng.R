testthat::test_that("derived run and pulse seeds are stable and ambient-RNG independent", {
  local({
    set.seed(1)
    first <- ledgr:::ledgr_derive_seed(2026L, list(run_id = "grid_abc", params = list(n = 20L)))
    stats::runif(10)
    second <- ledgr:::ledgr_derive_seed(2026L, list(params = list(n = 20L), run_id = "grid_abc"))

    testthat::expect_identical(first, second)
    testthat::expect_type(first, "integer")
    testthat::expect_true(first >= 1L)
    testthat::expect_true(first <= 2147483647L)
    testthat::expect_identical(first, 350931654L)
  })

  # Also covers: ledgr_pulse_seeds is stable and independent of ambient RNG
  # (LDG-3159 replaced the deleted per-pulse helper with the rule-v2 vector)
  local({
    set.seed(1)
    first <- ledgr:::ledgr_pulse_seeds(350931654L, 3L)
    stats::runif(10)
    second <- ledgr:::ledgr_pulse_seeds(350931654L, 3L)
    adjacent <- ledgr:::ledgr_pulse_seeds(350931654L, 4L)

    testthat::expect_identical(first, second)
    testthat::expect_false(identical(first, adjacent))
    testthat::expect_type(first, "integer")
    testthat::expect_true(first >= 1L)
    testthat::expect_true(first <= 2147483647L)
    testthat::expect_null(ledgr:::ledgr_pulse_seeds(NULL, 1L))
    testthat::expect_error(
      ledgr:::ledgr_pulse_seeds(350931654L, 0L),
      class = "ledgr_invalid_args"
    )
  })
})


# ledgr-test-profile: heavy_protocol
testthat::test_that("[LTB-0009] snapshot ingestion and nonempty fill reads preserve caller RNG", {
  seed_existed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  if (seed_existed) {
    old_seed <- get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  }
  on.exit(
    {
      if (seed_existed) {
        assign(".Random.seed", old_seed, envir = .GlobalEnv)
      } else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
        rm(".Random.seed", envir = .GlobalEnv)
      }
    },
    add = TRUE
  )

  bars <- ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:1)
  assert_preserves_rng <- function(code) {
    set.seed(8675309L)
    before <- get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
    expected_next <- stats::runif(1L)
    assign(".Random.seed", before, envir = .GlobalEnv)
    force(code)
    testthat::expect_identical(
      get(".Random.seed", envir = .GlobalEnv, inherits = FALSE),
      before
    )
    testthat::expect_identical(stats::runif(1L), expected_next)
  }
  assert_preserves_absent_seed <- function(code) {
    if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
      rm(".Random.seed", envir = .GlobalEnv)
    }
    force(code)
    testthat::expect_false(exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE))
  }

  ingest_a <- tempfile(fileext = ".duckdb")
  ingest_b <- tempfile(fileext = ".duckdb")
  on.exit(unlink(c(ingest_a, ingest_b)), add = TRUE)
  assert_preserves_rng({
    snapshot <- ledgr_snapshot_from_df(bars, db_path = ingest_a, snapshot_id = "rng-ingest-a")
    ledgr_snapshot_close(snapshot)
  })
  assert_preserves_absent_seed({
    snapshot <- ledgr_snapshot_from_df(bars, db_path = ingest_b, snapshot_id = "rng-ingest-b")
    ledgr_snapshot_close(snapshot)
  })

  run_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(run_path), add = TRUE)
  snapshot <- ledgr_snapshot_from_df(bars, db_path = run_path, snapshot_id = "rng-fills")
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  exp <- ledgr_experiment(
    snapshot,
    function(ctx, params) {
      targets <- ctx$flat()
      targets[["AAA"]] <- 1
      targets
    },
    cost_model = ledgr_cost_zero()
  )
  bt <- ledgr_run(exp, run_id = "rng-fill-reader")
  on.exit(close(bt), add = TRUE)
  testthat::expect_gt(nrow(ledgr_run_fills(bt)), 0L)
  assert_preserves_rng(testthat::expect_gt(nrow(ledgr_run_fills(bt)), 0L))
  assert_preserves_absent_seed(testthat::expect_gt(nrow(ledgr_run_fills(bt)), 0L))
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0268] seeded ledgr_run preserves caller RNG", {
  seed_existed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  if (seed_existed) {
    old_seed <- get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  }
  on.exit(
    {
      if (seed_existed) {
        assign(".Random.seed", old_seed, envir = .GlobalEnv)
      } else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
        rm(".Random.seed", envir = .GlobalEnv)
      }
    },
    add = TRUE
  )

  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)
  bars <- ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:29)
  snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path, snapshot_id = "rng-run")
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  experiment <- ledgr_experiment(
    snapshot,
    function(ctx, params) {
      targets <- ctx$hold()
      if (all(targets == 0)) {
        targets[["AAA"]] <- floor(stats::runif(1L) * 100) + 1
      }
      targets
    },
    cost_model = ledgr_cost_zero()
  )

  set.seed(8675309L)
  before <- get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  seeded <- ledgr_run(experiment, run_id = "rng-run-present", seed = 2026L)
  on.exit(close(seeded), add = TRUE)
  testthat::expect_identical(
    get(".Random.seed", envir = .GlobalEnv, inherits = FALSE),
    before
  )

  rm(".Random.seed", envir = .GlobalEnv)
  absent <- ledgr_run(experiment, run_id = "rng-run-absent", seed = 2026L)
  on.exit(close(absent), add = TRUE)
  testthat::expect_false(
    exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  )

  failing_experiment <- ledgr_experiment(
    snapshot,
    function(ctx, params) {
      stats::runif(1L)
      rlang::abort("injected seeded strategy failure", class = "ledgr_test_rng_failure")
    },
    cost_model = ledgr_cost_zero()
  )
  set.seed(2468L)
  failure_before <- get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  testthat::expect_error(
    ledgr_run(failing_experiment, run_id = "rng-run-error", seed = 2026L),
    class = "ledgr_test_rng_failure"
  )
  testthat::expect_identical(
    get(".Random.seed", envir = .GlobalEnv, inherits = FALSE),
    failure_before
  )

  interrupt_experiment <- ledgr_experiment(
    snapshot,
    function(ctx, params) {
      stats::runif(1L)
      options(ledgr.interrupt = TRUE)
      ctx$hold()
    },
    cost_model = ledgr_cost_zero()
  )
  old_interrupt <- getOption("ledgr.interrupt")
  on.exit(options(ledgr.interrupt = old_interrupt), add = TRUE)
  options(ledgr.interrupt = FALSE)
  set.seed(1357L)
  interrupt_before <- get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  interrupted <- ledgr_run(
    interrupt_experiment,
    run_id = "rng-run-interrupted",
    seed = 2026L
  )
  on.exit(close(interrupted), add = TRUE)
  testthat::expect_identical(
    get(".Random.seed", envir = .GlobalEnv, inherits = FALSE),
    interrupt_before
  )
  testthat::expect_identical(
    ledgr_run_info(snapshot, "rng-run-interrupted")$status,
    "RUNNING"
  )
  options(ledgr.interrupt = FALSE)

  grid <- ledgr_grid_named(candidate = list(strategy = list(unused = 1L)))
  set.seed(1L)
  sweep_before_1 <- get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  sweep_1 <- ledgr_sweep(experiment, grid, seed = 2026L)
  testthat::expect_identical(
    get(".Random.seed", envir = .GlobalEnv, inherits = FALSE),
    sweep_before_1
  )

  set.seed(2L)
  sweep_before_2 <- get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  sweep_2 <- ledgr_sweep(experiment, grid, seed = 2026L)
  testthat::expect_identical(
    get(".Random.seed", envir = .GlobalEnv, inherits = FALSE),
    sweep_before_2
  )
  compared <- c(
    "status", "final_equity", "total_return", "annualized_return",
    "volatility", "sharpe_ratio", "max_drawdown", "n_trades", "win_rate",
    "avg_trade", "time_in_market"
  )
  for (field in compared) {
    testthat::expect_equal(
      sweep_1[[field]], sweep_2[[field]],
      tolerance = 0,
      info = paste("ambient-seed sweep field", field)
    )
  }

  candidate <- ledgr_candidate(sweep_1, "candidate")
  direct <- ledgr_run(
    experiment,
    params = candidate$params,
    run_id = "rng-sweep-direct",
    seed = candidate$execution_seed
  )
  on.exit(close(direct), add = TRUE)
  metrics <- ledgr_compute_metrics(direct)
  equity <- ledgr_results(direct, "equity")
  testthat::expect_equal(
    sweep_1$final_equity[[1L]], equity$equity[[nrow(equity)]],
    tolerance = 1e-10
  )
  for (field in setdiff(compared, c("status", "final_equity"))) {
    testthat::expect_equal(
      sweep_1[[field]][[1L]], metrics[[field]],
      tolerance = 1e-10,
      info = field
    )
  }
})
