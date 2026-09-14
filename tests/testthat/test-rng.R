testthat::test_that("ledgr_derive_seed is stable and independent of ambient RNG", {
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

testthat::test_that("ledgr_derive_pulse_seed is stable and independent of ambient RNG", {
  set.seed(1)
  first <- ledgr:::ledgr_derive_pulse_seed(350931654L, 3L)
  stats::runif(10)
  second <- ledgr:::ledgr_derive_pulse_seed(350931654L, 3L)
  adjacent <- ledgr:::ledgr_derive_pulse_seed(350931654L, 4L)

  testthat::expect_identical(first, second)
  testthat::expect_false(identical(first, adjacent))
  testthat::expect_type(first, "integer")
  testthat::expect_true(first >= 1L)
  testthat::expect_true(first <= 2147483647L)
  testthat::expect_null(ledgr:::ledgr_derive_pulse_seed(NULL, 1L))
  testthat::expect_error(
    ledgr:::ledgr_derive_pulse_seed(350931654L, 0L),
    class = "ledgr_invalid_args"
  )
})

testthat::test_that("snapshot ingestion and nonempty fill reads preserve caller RNG", {
  seed_existed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  if (seed_existed) {
    old_seed <- get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  }
  on.exit({
    if (seed_existed) {
      assign(".Random.seed", old_seed, envir = .GlobalEnv)
    } else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
      rm(".Random.seed", envir = .GlobalEnv)
    }
  }, add = TRUE)

  bars <- ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:3)
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
