ledgr_sweep_test_bars <- function() {
  data.frame(
    ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:5,
    instrument_id = "AAA",
    open = 100:105,
    high = 101:106,
    low = 99:104,
    close = 100:105,
    volume = 1000,
    stringsAsFactors = FALSE
  )
}

ledgr_sweep_artifact_counts <- function(snapshot) {
  con <- get_connection(snapshot)
  tables <- c("runs", "ledger_events", "equity_curve", "features", "run_telemetry")
  stats::setNames(vapply(tables, function(table) {
    if (!DBI::dbExistsTable(con, table)) {
      return(0L)
    }
    as.integer(DBI::dbGetQuery(con, sprintf("SELECT COUNT(*) AS n FROM %s", table))$n[[1]])
  }, integer(1)), tables)
}

testthat::test_that("ledgr_sweep returns ordered summary rows without store writes", {
  snapshot <- ledgr_snapshot_from_df(ledgr_sweep_test_bars())
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    targets["AAA"] <- params$qty
    targets
  }
  exp <- ledgr_experiment(snapshot, strategy)
  grid <- ledgr_param_grid(a = list(qty = 1), b = list(qty = 2))

  before_counts <- ledgr_sweep_artifact_counts(snapshot)
  before_telemetry <- ls(ledgr:::.ledgr_telemetry_registry, all.names = TRUE)
  out <- ledgr_sweep(exp, grid, seed = 123L)
  after_counts <- ledgr_sweep_artifact_counts(snapshot)
  after_telemetry <- ls(ledgr:::.ledgr_telemetry_registry, all.names = TRUE)

  testthat::expect_s3_class(out, "ledgr_sweep_results")
  testthat::expect_identical(out$run_id, c("a", "b"))
  testthat::expect_identical(out$status, c("DONE", "DONE"))
  testthat::expect_true(all(is.finite(out$final_equity)))
  testthat::expect_true(all(is.finite(out$total_return)))
  testthat::expect_true(all(!is.na(out$execution_seed)))
  testthat::expect_identical(attr(out, "evaluation_scope"), "exploratory")
  testthat::expect_identical(before_counts, after_counts)
  testthat::expect_identical(before_telemetry, after_telemetry)
})

testthat::test_that("derived execution seeds are stable across sweep invocations", {
  snapshot <- ledgr_snapshot_from_df(ledgr_sweep_test_bars())
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    targets["AAA"] <- params$qty
    targets
  }
  exp <- ledgr_experiment(snapshot, strategy)
  grid <- ledgr_param_grid(a = list(qty = 1), b = list(qty = 2))

  one <- ledgr_sweep(exp, grid, seed = 123L)
  two <- ledgr_sweep(exp, grid, seed = 123L)

  testthat::expect_identical(one$execution_seed, two$execution_seed)
  testthat::expect_false(identical(one$execution_seed[[1]], one$execution_seed[[2]]))
  testthat::expect_identical(attr(one, "master_seed"), 123L)
  testthat::expect_false(identical(attr(one, "sweep_id"), attr(two, "sweep_id")))
})

testthat::test_that("ledgr_sweep captures candidate failures and stop_on_error rethrows", {
  snapshot <- ledgr_snapshot_from_df(ledgr_sweep_test_bars())
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) ctx$flat()
  features <- function(params) {
    if (params$n < 1) {
      rlang::abort("bad feature params", class = "ledgr_test_bad_feature")
    }
    list(ledgr_indicator("custom_close", function(window) tail(window$close, 1), requires_bars = 1))
  }
  exp <- ledgr_experiment(snapshot, strategy, features = features)
  grid <- ledgr_param_grid(good = list(n = 1), bad = list(n = 0))

  out <- ledgr_sweep(exp, grid)
  testthat::expect_identical(out$status, c("DONE", "FAILED"))
  testthat::expect_identical(out$error_class[[2]], "ledgr_test_bad_feature")
  testthat::expect_error(
    ledgr_sweep(exp, grid, stop_on_error = TRUE),
    class = "ledgr_test_bad_feature"
  )
})

testthat::test_that("feature-consuming sweep strategies see the same feature values as ledgr_run", {
  snapshot <- ledgr_snapshot_from_df(ledgr_sweep_test_bars())
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  observed <- new.env(parent = emptyenv())
  observed$mode <- "sweep"
  observed$sweep <- numeric()
  observed$run <- numeric()
  ind <- ledgr_indicator(
    id = "custom_close",
    fn = function(window) tail(window$close, 1),
    requires_bars = 1
  )
  strategy <- function(ctx, params) {
    value <- ctx$feature("AAA", "custom_close")
    observed[[observed$mode]] <- c(observed[[observed$mode]], value)
    targets <- ctx$flat()
    targets["AAA"] <- if (value > 101) 1 else 0
    targets
  }
  exp <- ledgr_experiment(snapshot, strategy, features = list(ind))
  grid <- ledgr_param_grid(candidate = list())

  out <- ledgr_sweep(exp, grid)
  observed$mode <- "run"
  bt <- ledgr_run(exp, params = list(), run_id = "feature-parity-run")
  on.exit(close(bt), add = TRUE)

  testthat::expect_identical(out$status[[1]], "DONE")
  testthat::expect_equal(observed$sweep, observed$run)
})

testthat::test_that("precomputed features are consumed without calling the feature factory during sweep", {
  snapshot <- ledgr_snapshot_from_df(ledgr_sweep_test_bars())
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  calls <- new.env(parent = emptyenv())
  calls$n <- 0L
  features <- function(params) {
    calls$n <- calls$n + 1L
    list(ledgr_indicator("custom_close", function(window) tail(window$close, 1), requires_bars = 1))
  }
  strategy <- function(ctx, params) {
    value <- ctx$feature("AAA", "custom_close")
    targets <- ctx$flat()
    targets["AAA"] <- if (value > 101) 1 else 0
    targets
  }
  exp <- ledgr_experiment(snapshot, strategy, features = features)
  grid <- ledgr_param_grid(a = list(), b = list())
  precomputed <- ledgr_precompute_features(exp, grid)

  calls$n <- 0L
  out <- ledgr_sweep(exp, grid, precomputed_features = precomputed)
  testthat::expect_identical(out$status, c("DONE", "DONE"))
  testthat::expect_identical(calls$n, 0L)
})

testthat::test_that("the shared fold core is private and DB-free", {
  exports <- getNamespaceExports("ledgr")
  testthat::expect_false("ledgr_execute_fold" %in% exports)
  testthat::expect_true(exists("ledgr_execute_fold", envir = asNamespace("ledgr"), inherits = FALSE))

  core_body <- paste(deparse(body(ledgr:::ledgr_execute_fold)), collapse = "\n")
  testthat::expect_false(grepl("DBI::|dbGetQuery|dbExecute|dbAppendTable|dbWithTransaction|duckdb", core_body))
  testthat::expect_true(grepl("ledgr_execute_fold", paste(deparse(body(ledgr:::ledgr_run_fold)), collapse = "\n")))
  testthat::expect_true(grepl("ledgr_execute_fold", paste(deparse(body(ledgr:::ledgr_sweep_run_candidate)), collapse = "\n")))
})
