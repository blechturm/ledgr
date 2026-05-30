testthat::test_that("parallel worker setup with workers = 1 does not require mirai", {
  strategy <- function(ctx, params) ctx$flat()
  preflight <- ledgr_strategy_preflight(strategy)

  plan <- ledgr:::ledgr_parallel_worker_setup(
    workers = 1L,
    preflight = preflight,
    backend_available = FALSE
  )

  testthat::expect_s3_class(plan, "ledgr_parallel_worker_setup")
  testthat::expect_identical(plan$workers, 1L)
  testthat::expect_identical(plan$backend, "sequential")
  testthat::expect_false(plan$initialized)
  testthat::expect_identical(plan$actions, "sequential")
})

testthat::test_that("workers > 1 without mirai fails loudly and actionably", {
  strategy <- function(ctx, params) ctx$flat()
  preflight <- ledgr_strategy_preflight(strategy)

  err <- testthat::capture_error(
    ledgr:::ledgr_parallel_worker_setup(
      workers = 2L,
      preflight = preflight,
      backend_available = FALSE
    )
  )

  testthat::expect_s3_class(err, "ledgr_parallel_backend_missing")
  testthat::expect_match(conditionMessage(err), "install.packages(\"mirai\")", fixed = TRUE)
  testthat::expect_match(conditionMessage(err), "workers = 1", fixed = TRUE)
})

testthat::test_that("worker dependencies distinguish qualified and attached packages", {
  qualified_strategy <- function(ctx, params) {
    jsonlite::toJSON(list(qty = 1), auto_unbox = TRUE)
    ctx$flat()
  }
  qualified_preflight <- ledgr_strategy_preflight(qualified_strategy)
  qualified_deps <- ledgr:::ledgr_parallel_worker_dependencies(
    qualified_preflight,
    worker_packages = "jsonlite"
  )

  testthat::expect_identical(qualified_deps$require_namespace, "jsonlite")
  testthat::expect_identical(qualified_deps$attach, "jsonlite")
  testthat::expect_identical(qualified_deps$all_packages, "jsonlite")

  testthat::skip_if_not_installed("TTR")
  unqualified_strategy <- local({
    SMA <- getExportedValue("TTR", "SMA")
    function(ctx, params) {
      SMA(c(1, 2, 3), n = 2)
      ctx$flat()
    }
  })
  unqualified_preflight <- ledgr_strategy_preflight(unqualified_strategy)
  unqualified_deps <- ledgr:::ledgr_parallel_worker_dependencies(unqualified_preflight)

  testthat::expect_identical(unqualified_deps$require_namespace, character())
  testthat::expect_identical(unqualified_deps$attach, "TTR")
  testthat::expect_identical(unqualified_deps$all_packages, "TTR")
})

testthat::test_that("worker setup dry run reports ledgr and package setup actions", {
  strategy <- function(ctx, params) {
    jsonlite::toJSON(list(qty = 1), auto_unbox = TRUE)
    ctx$flat()
  }
  preflight <- ledgr_strategy_preflight(strategy)

  plan <- ledgr:::ledgr_parallel_worker_setup(
    workers = 2L,
    preflight = preflight,
    worker_packages = "jsonlite",
    backend_available = TRUE,
    dry_run = TRUE
  )

  testthat::expect_s3_class(plan, "ledgr_parallel_worker_setup")
  testthat::expect_identical(plan$workers, 2L)
  testthat::expect_identical(plan$backend, "mirai")
  testthat::expect_false(plan$initialized)
  testthat::expect_true(any(plan$actions %in% c("pkgload::load_all", "library:ledgr")))
  testthat::expect_true("requireNamespace:jsonlite" %in% plan$actions)
  testthat::expect_true("library:jsonlite" %in% plan$actions)
})

testthat::test_that("worker setup reports missing worker packages", {
  strategy <- function(ctx, params) ctx$flat()
  preflight <- ledgr_strategy_preflight(strategy)

  err <- testthat::capture_error(
    ledgr:::ledgr_parallel_worker_setup(
      workers = 2L,
      preflight = preflight,
      worker_packages = "ledgrDefinitelyMissingPkg",
      backend_available = TRUE,
      dry_run = TRUE
    )
  )

  testthat::expect_s3_class(err, "ledgr_parallel_worker_package_missing")
  testthat::expect_match(conditionMessage(err), "ledgrDefinitelyMissingPkg", fixed = TRUE)
})

testthat::test_that("worker setup rejects Tier 3 helper smuggling", {
  my_helper <- function(ctx) ctx$flat()
  strategy <- function(ctx, params) my_helper(ctx)
  preflight <- ledgr_strategy_preflight(strategy)

  testthat::expect_identical(preflight$tier, "tier_3")
  err <- testthat::capture_error(
    ledgr:::ledgr_parallel_worker_setup(
      workers = 2L,
      preflight = preflight,
      backend_available = TRUE,
      dry_run = TRUE
    )
  )

  testthat::expect_s3_class(err, "ledgr_parallel_strategy_not_allowed")
  testthat::expect_match(conditionMessage(err), ".GlobalEnv", fixed = TRUE)
})
