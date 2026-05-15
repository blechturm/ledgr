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

testthat::test_that("ledgr_sweep_results has the v0.1.8 column and metadata contract", {
  snapshot <- ledgr_snapshot_from_df(ledgr_sweep_test_bars())
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    targets["AAA"] <- params$qty
    targets
  }
  exp <- ledgr_experiment(snapshot, strategy)
  grid <- ledgr_param_grid(a = list(qty = 1), b = list(qty = 2))

  unseeded <- ledgr_sweep(exp, grid)
  seeded <- ledgr_sweep(exp, grid, seed = 123L)

  testthat::expect_identical(
    names(seeded),
    c(
      "run_id", "status", "final_equity", "total_return",
      "annualized_return", "volatility", "sharpe_ratio", "max_drawdown",
      "n_trades", "win_rate", "avg_trade", "time_in_market",
      "execution_seed", "error_class", "error_msg", "params",
      "warnings", "feature_fingerprints", "provenance"
    )
  )
  testthat::expect_type(unseeded$execution_seed, "integer")
  testthat::expect_true(all(is.na(unseeded$execution_seed)))
  testthat::expect_type(seeded$execution_seed, "integer")
  testthat::expect_true(all(!is.na(seeded$execution_seed)))

  versions <- vapply(seeded$provenance, `[[`, character(1), "provenance_version")
  testthat::expect_identical(versions, rep("ledgr_provenance_v1", 2L))
  testthat::expect_true(all(vapply(seeded$provenance, function(row) {
    all(c(
      "snapshot_hash", "strategy_hash", "feature_set_hash", "master_seed",
      "seed_contract", "evaluation_scope"
    ) %in% names(row))
  }, logical(1))))

  testthat::expect_match(attr(seeded, "sweep_id"), "^sweep_[0-9a-f]{16}$")
  testthat::expect_identical(attr(seeded, "master_seed"), 123L)
  testthat::expect_identical(attr(seeded, "seed_contract"), "ledgr_seed_v1")
  testthat::expect_identical(attr(seeded, "evaluation_scope"), "exploratory")
  testthat::expect_identical(attr(seeded, "snapshot_id"), snapshot$snapshot_id)
  testthat::expect_match(attr(seeded, "snapshot_hash"), "^[0-9a-f]{64}$")
  testthat::expect_identical(attr(seeded, "scoring_range")$start, "2020-01-01T00:00:00Z")
  testthat::expect_identical(attr(seeded, "scoring_range")$end, "2020-01-06T00:00:00Z")
  testthat::expect_identical(attr(seeded, "universe"), "AAA")
  testthat::expect_match(attr(seeded, "strategy_hash"), "^[0-9a-f]{64}$")
  testthat::expect_identical(attr(seeded, "strategy_source_capture_method"), "deparse_function")
  testthat::expect_s3_class(attr(seeded, "strategy_preflight"), "ledgr_strategy_preflight")
  testthat::expect_type(attr(seeded, "feature_union"), "character")
  testthat::expect_match(attr(seeded, "feature_union_hash"), "^[0-9a-f]{64}$")
  testthat::expect_identical(
    attr(seeded, "feature_union_hash"),
    ledgr:::ledgr_feature_set_hash(attr(seeded, "feature_union"))
  )
  testthat::expect_s3_class(attr(seeded, "candidate_features"), "tbl_df")
  testthat::expect_true(is.list(attr(seeded, "execution_assumptions")))

  for (row in seeded$provenance) {
    testthat::expect_identical(row$snapshot_hash, attr(seeded, "snapshot_hash"))
    testthat::expect_identical(row$strategy_hash, attr(seeded, "strategy_hash"))
    testthat::expect_match(row$feature_set_hash, "^[0-9a-f]{64}$")
    testthat::expect_identical(row$master_seed, 123L)
    testthat::expect_identical(row$seed_contract, "ledgr_seed_v1")
    testthat::expect_identical(row$evaluation_scope, "exploratory")
  }
})

testthat::test_that("ledgr_sweep preserves warning conditions", {
  snapshot <- ledgr_snapshot_from_df(ledgr_sweep_test_bars())
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) {
    rlang::warn("candidate warning", class = "ledgr_test_sweep_warning")
    ctx$flat()
  }
  exp <- ledgr_experiment(snapshot, strategy)
  grid <- ledgr_param_grid(candidate = list())
  out <- ledgr_sweep(exp, grid, seed = 123L)

  testthat::expect_true(length(out$warnings[[1]]) > 0L)
  testthat::expect_s3_class(out$warnings[[1]][[1]], "ledgr_test_sweep_warning")
})

testthat::test_that("ledgr_sweep_results prints a curated view", {
  snapshot <- ledgr_snapshot_from_df(ledgr_sweep_test_bars())
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) ctx$flat()
  exp <- ledgr_experiment(snapshot, strategy)
  grid <- ledgr_param_grid(candidate = list())
  out <- ledgr_sweep(exp, grid, seed = 123L)

  printed <- utils::capture.output(print(out))
  testthat::expect_true(any(grepl("ledgr sweep", printed, fixed = TRUE)))
  testthat::expect_true(any(grepl("execution_seed", printed, fixed = TRUE)))
  testthat::expect_true(any(grepl("Hidden columns", printed, fixed = TRUE)))
  testthat::expect_true(any(grepl("win_rate", printed, fixed = TRUE)))
  testthat::expect_true(any(grepl("params", printed, fixed = TRUE)))
  testthat::expect_true(any(grepl("warnings", printed, fixed = TRUE)))
  testthat::expect_true(any(grepl("feature_fingerprints", printed, fixed = TRUE)))
  testthat::expect_true(any(grepl("provenance", printed, fixed = TRUE)))
})

testthat::test_that("ledgr_candidate selects by label or position and handles failures", {
  snapshot <- ledgr_snapshot_from_df(ledgr_sweep_test_bars())
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    targets["AAA"] <- params$qty
    targets
  }
  exp <- ledgr_experiment(snapshot, strategy)
  grid <- ledgr_param_grid(a = list(qty = 1), b = list(qty = 2))
  out <- ledgr_sweep(exp, grid, seed = 123L)

  by_label <- ledgr_candidate(out, "b")
  by_position <- ledgr_candidate(out, 1)
  testthat::expect_s3_class(by_label, "ledgr_sweep_candidate")
  testthat::expect_identical(by_label$run_id, "b")
  testthat::expect_identical(by_label$params, list(qty = 2))
  testthat::expect_identical(by_position$run_id, "a")
  testthat::expect_identical(by_position$params, list(qty = 1))
  testthat::expect_identical(by_label$sweep_meta$sweep_id, attr(out, "sweep_id"))
  testthat::expect_s3_class(by_label$selection_view, "tbl_df")
  testthat::expect_identical(nrow(by_label$selection_view), 2L)
  testthat::expect_identical(by_label$selection_view$run_id, c("a", "b"))

  features <- function(params) {
    if (params$n < 1) {
      rlang::abort("bad feature params", class = "ledgr_test_bad_feature")
    }
    list(ledgr_indicator("custom_close", function(window) tail(window$close, 1), requires_bars = 1))
  }
  failed_exp <- ledgr_experiment(snapshot, function(ctx, params) ctx$flat(), features = features)
  failed_grid <- ledgr_param_grid(good = list(n = 1), bad = list(n = 0))
  failed <- ledgr_sweep(failed_exp, failed_grid)
  testthat::expect_error(ledgr_candidate(failed, "bad"), class = "ledgr_failed_sweep_candidate")
  diagnostic <- ledgr_candidate(failed, "bad", allow_failed = TRUE)
  testthat::expect_identical(diagnostic$status, "FAILED")
  testthat::expect_error(
    ledgr_promote(exp, diagnostic, run_id = "should-not-promote"),
    class = "ledgr_promote_failed_candidate"
  )
})

testthat::test_that("ledgr_candidate supports degraded tibble-like inputs", {
  snapshot <- ledgr_snapshot_from_df(ledgr_sweep_test_bars())
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) ctx$flat()
  exp <- ledgr_experiment(snapshot, strategy)
  grid <- ledgr_param_grid(candidate = list())
  out <- ledgr_sweep(exp, grid, seed = 123L)
  plain <- tibble::as_tibble(out)

  candidate <- NULL
  testthat::expect_message(
    candidate <- ledgr_candidate(plain, "candidate"),
    "not a `ledgr_sweep_results` object",
    fixed = TRUE
  )
  testthat::expect_s3_class(candidate, "ledgr_sweep_candidate")
  testthat::expect_null(candidate$sweep_meta)
  testthat::expect_identical(candidate$params, list())
})

testthat::test_that("ledgr_promote forwards candidate params and execution seed", {
  snapshot <- ledgr_snapshot_from_df(ledgr_sweep_test_bars())
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    targets["AAA"] <- params$qty
    targets
  }
  exp <- ledgr_experiment(snapshot, strategy)
  grid <- ledgr_param_grid(a = list(qty = 1), b = list(qty = 2))
  out <- ledgr_sweep(exp, grid, seed = 123L)
  candidate <- ledgr_candidate(out, "b")

  bt <- ledgr_promote(
    exp,
    candidate,
    run_id = "promoted-candidate-run",
    note = "reviewed candidate",
    require_same_snapshot = TRUE
  )
  on.exit(close(bt), add = TRUE)

  testthat::expect_s3_class(bt, "ledgr_backtest")
  testthat::expect_identical(bt$config$strategy_params, list(qty = 2))
  testthat::expect_identical(bt$config$engine$seed, candidate$execution_seed)
  testthat::expect_identical(attr(bt, "promotion_note"), "reviewed candidate")

  bt_no_note <- ledgr_promote(
    exp,
    candidate,
    run_id = "promoted-candidate-run-no-note",
    require_same_snapshot = TRUE
  )
  on.exit(close(bt_no_note), add = TRUE)
  testthat::expect_null(attr(bt_no_note, "promotion_note", exact = TRUE))
  testthat::expect_error(
    ledgr_promote(exp, candidate, run_id = "empty-note", note = ""),
    class = "ledgr_invalid_args"
  )
})

testthat::test_that("ledgr_promote validates same-snapshot provenance when requested", {
  snapshot <- ledgr_snapshot_from_df(ledgr_sweep_test_bars())
  other_bars <- ledgr_sweep_test_bars()
  other_bars$open <- other_bars$open + 10
  other_bars$high <- other_bars$high + 10
  other_bars$low <- other_bars$low + 10
  other_bars$close <- other_bars$close + 10
  other_snapshot <- ledgr_snapshot_from_df(other_bars)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  on.exit(ledgr_snapshot_close(other_snapshot), add = TRUE)

  strategy <- function(ctx, params) ctx$flat()
  exp <- ledgr_experiment(snapshot, strategy)
  other_exp <- ledgr_experiment(other_snapshot, strategy)
  grid <- ledgr_param_grid(candidate = list())
  candidate <- ledgr_candidate(ledgr_sweep(exp, grid), "candidate")

  testthat::expect_error(
    ledgr_promote(other_exp, candidate, run_id = "wrong-snapshot"),
    class = "ledgr_candidate_snapshot_mismatch"
  )

  bt_cross <- ledgr_promote(
    other_exp,
    candidate,
    run_id = "cross-snapshot-explicit",
    require_same_snapshot = FALSE
  )
  on.exit(close(bt_cross), add = TRUE)
  testthat::expect_s3_class(bt_cross, "ledgr_backtest")

  candidate$provenance$snapshot_hash <- NULL
  testthat::expect_error(
    ledgr_promote(exp, candidate, run_id = "missing-snapshot"),
    class = "ledgr_candidate_missing_snapshot_hash"
  )
})

testthat::test_that("ledgr_sweep_candidate print shows strategy name and hash when available", {
  snapshot <- ledgr_snapshot_from_df(ledgr_sweep_test_bars())
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) ctx$flat()
  attr(strategy, "name") <- "named_strategy"
  exp <- ledgr_experiment(snapshot, strategy)
  grid <- ledgr_param_grid(candidate = list())
  candidate <- ledgr_candidate(ledgr_sweep(exp, grid, seed = 123L), "candidate")

  printed <- utils::capture.output(print(candidate))
  testthat::expect_true(any(grepl("named_strategy", printed, fixed = TRUE)))
  testthat::expect_true(any(grepl("Execution seed:", printed, fixed = TRUE)))
  testthat::expect_true(any(grepl("Feature-set hash:", printed, fixed = TRUE)))
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
