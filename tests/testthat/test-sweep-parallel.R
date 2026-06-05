ledgr_parallel_sweep_test_bars <- function() {
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

ledgr_parallel_sweep_artifact_counts <- function(snapshot) {
  con <- get_connection(snapshot)
  tables <- c("runs", "ledger_events", "equity_curve", "features", "run_telemetry")
  stats::setNames(vapply(tables, function(table) {
    if (!DBI::dbExistsTable(con, table)) {
      return(0L)
    }
    as.integer(DBI::dbGetQuery(con, sprintf("SELECT COUNT(*) AS n FROM %s", table))$n[[1]])
  }, integer(1)), tables)
}

ledgr_parallel_sweep_comparable <- function(x) {
  volatile <- c("warnings", "provenance", "t_engine", "t_results", "t_fills_extract")
  out <- as.data.frame(x[, !names(x) %in% volatile, drop = FALSE])
  out$params <- vapply(out$params, ledgr:::canonical_json, character(1))
  out$feature_params <- vapply(out$feature_params, ledgr:::canonical_json, character(1))
  out$feature_fingerprints <- vapply(out$feature_fingerprints, ledgr:::canonical_json, character(1))
  attr(out, "sweep_id") <- NULL
  attr(out, "snapshot_id") <- NULL
  attr(out, "snapshot_hash") <- NULL
  attr(out, "strategy_hash") <- NULL
  out
}

ledgr_parallel_sweep_reproduction_key_comparable <- function(key) {
  key$source_sweep$sweep_id <- "<sweep-id>"
  key
}

ledgr_skip_parallel_sweep_under_covr <- function() {
  testthat::skip_if(
    requireNamespace("covr", quietly = TRUE) && covr::in_covr(),
    paste(
      "mirai-backed parallel sweep is covered by ordinary CI;",
      "covr subprocess tracing can corrupt coverage shard readback."
    )
  )
}

testthat::test_that("ledgr_sweep workers = 1 equals sequential reference", {
  snapshot <- ledgr_snapshot_from_df(ledgr_parallel_sweep_test_bars())
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    targets["AAA"] <- params$qty
    targets
  }
  exp <- ledgr_experiment(snapshot, strategy, cost_model = ledgr_cost_zero())
  grid <- ledgr_param_grid(a = list(qty = 1), b = list(qty = 2))

  reference <- ledgr_sweep(exp, grid, seed = 123L)
  explicit_one <- ledgr_sweep(exp, grid, seed = 123L, workers = 1L)

  testthat::expect_equal(
    ledgr_parallel_sweep_comparable(explicit_one),
    ledgr_parallel_sweep_comparable(reference)
  )
})

testthat::test_that("parallel sweep matches sequential deterministic candidate rows", {
  testthat::skip_if_not_installed("mirai")
  ledgr_skip_parallel_sweep_under_covr()
  snapshot <- ledgr_snapshot_from_df(ledgr_parallel_sweep_test_bars())
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    targets["AAA"] <- if (!is.null(ctx$pulse_seed) && ctx$pulse_seed %% params$modulus == 0L) {
      params$qty
    } else {
      0
    }
    targets
  }
  exp <- ledgr_experiment(snapshot, strategy, cost_model = ledgr_cost_zero())
  grid <- ledgr_param_grid(
    a = list(qty = 1, modulus = 2L),
    b = list(qty = 2, modulus = 3L),
    c = list(qty = 3, modulus = 5L)
  )

  sequential <- ledgr_sweep(exp, grid, seed = 123L)
  parallel_two <- ledgr_sweep(exp, grid, seed = 123L, workers = 2L)
  parallel_three <- ledgr_sweep(exp, grid, seed = 123L, workers = 3L)

  testthat::expect_equal(
    ledgr_parallel_sweep_comparable(parallel_two),
    ledgr_parallel_sweep_comparable(sequential)
  )
  testthat::expect_equal(
    ledgr_parallel_sweep_comparable(parallel_three),
    ledgr_parallel_sweep_comparable(sequential)
  )
  testthat::expect_identical(parallel_two$run_id, c("a", "b", "c"))
  testthat::expect_identical(parallel_three$run_id, c("a", "b", "c"))
})

testthat::test_that("parallel sweep preserves warning and failure row association", {
  testthat::skip_if_not_installed("mirai")
  ledgr_skip_parallel_sweep_under_covr()
  snapshot <- ledgr_snapshot_from_df(ledgr_parallel_sweep_test_bars())
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) {
    if (isTRUE(params$fail)) {
      stop(sprintf("boom-%s", params$id))
    }
    if (isTRUE(params$warn)) {
      warning(sprintf("warn-%s", params$id))
    }
    targets <- ctx$flat()
    targets["AAA"] <- params$qty
    targets
  }
  exp <- ledgr_experiment(snapshot, strategy, cost_model = ledgr_cost_zero())
  grid <- ledgr_param_grid(
    ok = list(id = "ok", qty = 1, warn = FALSE, fail = FALSE),
    noisy = list(id = "noisy", qty = 1, warn = TRUE, fail = FALSE),
    bad = list(id = "bad", qty = 1, warn = FALSE, fail = TRUE),
    tail = list(id = "tail", qty = 2, warn = FALSE, fail = FALSE)
  )

  out <- ledgr_sweep(exp, grid, seed = 123L, workers = 2L)

  testthat::expect_identical(out$run_id, c("ok", "noisy", "bad", "tail"))
  testthat::expect_identical(out$status, c("DONE", "DONE", "FAILED", "DONE"))
  testthat::expect_true(length(out$warnings[[1]]) == 0L)
  testthat::expect_true(any(grepl("warn-noisy", vapply(out$warnings[[2]], conditionMessage, character(1)), fixed = TRUE)))
  testthat::expect_true(length(out$warnings[[3]]) == 0L)
  testthat::expect_match(out$error_msg[[3]], "boom-bad", fixed = TRUE)
})

testthat::test_that("parallel sweep keeps reproduction key stable modulo sweep id", {
  testthat::skip_if_not_installed("mirai")
  ledgr_skip_parallel_sweep_under_covr()
  snapshot <- ledgr_snapshot_from_df(ledgr_parallel_sweep_test_bars())
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    targets["AAA"] <- params$qty
    targets
  }
  exp <- ledgr_experiment(snapshot, strategy, cost_model = ledgr_cost_zero())
  grid <- ledgr_param_grid(candidate = list(qty = 1))

  sequential <- ledgr_sweep(exp, grid, seed = 123L)
  parallel <- ledgr_sweep(exp, grid, seed = 123L, workers = 2L)
  seq_key <- ledgr_candidate_reproduction_key(ledgr_candidate(sequential, "candidate"))
  par_key <- ledgr_candidate_reproduction_key(ledgr_candidate(parallel, "candidate"))

  testthat::expect_identical(
    ledgr_parallel_sweep_reproduction_key_comparable(par_key),
    ledgr_parallel_sweep_reproduction_key_comparable(seq_key)
  )
})

testthat::test_that("parallel sweep workers do not write persistent artifacts", {
  testthat::skip_if_not_installed("mirai")
  ledgr_skip_parallel_sweep_under_covr()
  snapshot <- ledgr_snapshot_from_df(ledgr_parallel_sweep_test_bars())
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    targets["AAA"] <- params$qty
    targets
  }
  exp <- ledgr_experiment(snapshot, strategy, cost_model = ledgr_cost_zero())
  grid <- ledgr_param_grid(a = list(qty = 1), b = list(qty = 2))

  before <- ledgr_parallel_sweep_artifact_counts(snapshot)
  out <- ledgr_sweep(exp, grid, seed = 123L, workers = 2L)
  after <- ledgr_parallel_sweep_artifact_counts(snapshot)

  testthat::expect_identical(out$status, c("DONE", "DONE"))
  testthat::expect_identical(after, before)
})

testthat::test_that("parallel sweep rejects ambient RNG strategies", {
  testthat::skip_if_not_installed("mirai")
  ledgr_skip_parallel_sweep_under_covr()
  snapshot <- ledgr_snapshot_from_df(ledgr_parallel_sweep_test_bars())
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    if (stats::runif(1) > 0.5) {
      targets["AAA"] <- 1
    }
    targets
  }
  exp <- ledgr_experiment(snapshot, strategy, cost_model = ledgr_cost_zero())
  grid <- ledgr_param_grid(candidate = list())

  err <- testthat::capture_error(ledgr_sweep(exp, grid, workers = 2L))
  testthat::expect_s3_class(err, "ledgr_strategy_ambient_rng_parallel")
  testthat::expect_s3_class(err, "ledgr_strategy_preflight_error")
  testthat::expect_match(conditionMessage(err), "ctx$pulse_seed", fixed = TRUE)
})

testthat::test_that("parallel task interruption discards partial results", {
  stopped <- FALSE
  tasks <- list(
    list(run_id = "first"),
    list(run_id = "second")
  )
  submit <- function(task) task
  value <- function(promise) {
    signalCondition(structure(
      list(message = "simulated interrupt", call = NULL),
      class = c("interrupt", "condition")
    ))
    list(row = NULL, warnings = list(), error = NULL)
  }
  cleanup <- function() {
    stopped <<- TRUE
  }

  err <- testthat::capture_error(
    ledgr:::ledgr_sweep_eval_candidate_tasks_parallel(
      tasks = tasks,
      workers = 2L,
      submit = submit,
      value = value,
      cleanup = cleanup
    )
  )

  testthat::expect_s3_class(err, "ledgr_parallel_sweep_interrupted")
  testthat::expect_s3_class(err, "ledgr_parallel_error")
  testthat::expect_match(conditionMessage(err), "Discarding partial worker results", fixed = TRUE)
  testthat::expect_true(stopped)
})
