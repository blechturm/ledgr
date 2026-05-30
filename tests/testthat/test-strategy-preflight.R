testthat::test_that("strategy preflight classifies Tier 1 self-contained strategies", {
  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    targets["TEST_A"] <- params$qty
    targets
  }

  preflight <- ledgr_strategy_preflight(strategy)
  testthat::expect_s3_class(preflight, "ledgr_strategy_preflight")
  testthat::expect_identical(preflight$tier, "tier_1")
  testthat::expect_true(preflight$allowed)
  testthat::expect_identical(preflight$unresolved_symbols, character())
  testthat::expect_identical(preflight$package_dependencies, character())
})

testthat::test_that("strategy preflight classifies non-standard package-qualified calls as Tier 2", {
  strategy <- function(ctx, params) {
    jsonlite::toJSON(list(qty = params$qty), auto_unbox = TRUE)
    ctx$flat()
  }

  preflight <- ledgr_strategy_preflight(strategy)
  testthat::expect_identical(preflight$tier, "tier_2")
  testthat::expect_true(preflight$allowed)
  testthat::expect_identical(preflight$package_dependencies, "jsonlite")
  testthat::expect_identical(preflight$unresolved_symbols, character())
})

testthat::test_that("strategy preflight keeps base/recommended and ledgr exported calls Tier 1", {
  strategy <- function(ctx, params) {
    values <- c(1, 2, 3)
    signal <- signal_return(ctx, lookback = params$lookback)
    selected <- select_top_n(signal, n = 1)
    weights <- weight_equal(selected)
    if (passed_warmup(c(x = stats::sd(values)))) {
      return(target_rebalance(weights, ctx, equity_fraction = 0.5))
    }
    ctx$flat()
  }

  preflight <- ledgr_strategy_preflight(strategy)
  testthat::expect_identical(preflight$tier, "tier_1")
  testthat::expect_true(preflight$allowed)
  testthat::expect_identical(preflight$unresolved_symbols, character())
  testthat::expect_identical(preflight$package_dependencies, character())
})

testthat::test_that("strategy preflight classifies unresolved user helpers as Tier 3", {
  my_helper <- function(ctx) ctx$flat()
  strategy <- function(ctx, params) {
    my_helper(ctx)
  }

  preflight <- ledgr_strategy_preflight(strategy)
  testthat::expect_identical(preflight$tier, "tier_3")
  testthat::expect_false(preflight$allowed)
  testthat::expect_identical(preflight$unresolved_symbols, "my_helper")
  testthat::expect_match(preflight$reason, "my_helper", fixed = TRUE)
})

testthat::test_that("strategy preflight allows resolved external objects as Tier 2", {
  qty <- 1
  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    targets["TEST_A"] <- qty
    targets
  }

  preflight <- ledgr_strategy_preflight(strategy)
  testthat::expect_identical(preflight$tier, "tier_2")
  testthat::expect_true(preflight$allowed)
  testthat::expect_identical(preflight$unresolved_symbols, character())
  testthat::expect_true(any(grepl("qty", preflight$notes, fixed = TRUE)))
})

testthat::test_that("strategy preflight allows explicit ledgr_signal_strategy wrappers as Tier 2", {
  strategy <- ledgr_signal_strategy(function(ctx) c(TEST_A = "LONG"))

  preflight <- ledgr_strategy_preflight(strategy)
  testthat::expect_identical(preflight$tier, "tier_2")
  testthat::expect_true(preflight$allowed)
  testthat::expect_match(preflight$reason, "ledgr_signal_strategy", fixed = TRUE)
  testthat::expect_identical(preflight$unresolved_symbols, character())
})

testthat::test_that("strategy preflight rejects RNG state mutation as Tier 3", {
  strategy <- function(ctx, params) {
    set.seed(1)
    ctx$flat()
  }

  preflight <- ledgr_strategy_preflight(strategy)
  testthat::expect_identical(preflight$tier, "tier_3")
  testthat::expect_false(preflight$allowed)
  testthat::expect_match(preflight$reason, "set.seed", fixed = TRUE)

  strategy_kind <- function(ctx, params) {
    base::RNGkind("Mersenne-Twister")
    ctx$flat()
  }
  preflight_kind <- ledgr_strategy_preflight(strategy_kind)
  testthat::expect_identical(preflight_kind$tier, "tier_3")
  testthat::expect_false(preflight_kind$allowed)
  testthat::expect_match(preflight_kind$reason, "RNGkind", fixed = TRUE)
})

testthat::test_that("strategy preflight rejects determinism-forbidden calls as Tier 3", {
  strategies <- list(
    Sys.time = function(ctx, params) {
      Sys.time()
      ctx$flat()
    },
    Sys.Date = function(ctx, params) {
      Sys.Date()
      ctx$flat()
    },
    Sys.getenv = function(ctx, params) {
      Sys.getenv("HOME")
      ctx$flat()
    }
  )

  for (name in names(strategies)) {
    preflight <- ledgr_strategy_preflight(strategies[[name]])
    testthat::expect_identical(preflight$tier, "tier_3", info = name)
    testthat::expect_false(preflight$allowed, info = name)
    testthat::expect_match(preflight$reason, name, fixed = TRUE, info = name)
    testthat::expect_match(preflight$reason, "forbidden nondeterministic", fixed = TRUE, info = name)
  }
})

testthat::test_that("strategy preflight rejects forbidden do.call indirection as Tier 3", {
  strategies <- list(
    `do.call("Sys.time")` = function(ctx, params) {
      do.call("Sys.time", list())
      ctx$flat()
    },
    `do.call(Sys.time)` = function(ctx, params) {
      do.call(Sys.time, list())
      ctx$flat()
    },
    `do.call("Sys.Date")` = function(ctx, params) {
      do.call("Sys.Date", list())
      ctx$flat()
    },
    `do.call("Sys.getenv")` = function(ctx, params) {
      do.call("Sys.getenv", list("HOME"))
      ctx$flat()
    },
    `do.call("get")` = function(ctx, params) {
      do.call("get", list("HOME"))
      ctx$flat()
    },
    `do.call("eval")` = function(ctx, params) {
      do.call("eval", list(quote(1 + 1)))
      ctx$flat()
    },
    `do.call("assign")` = function(ctx, params) {
      do.call("assign", list("x", 1, envir = .GlobalEnv))
      ctx$flat()
    }
  )

  for (label in names(strategies)) {
    preflight <- ledgr_strategy_preflight(strategies[[label]])
    testthat::expect_identical(preflight$tier, "tier_3", info = label)
    testthat::expect_false(preflight$allowed, info = label)
    testthat::expect_match(preflight$reason, "do.call", fixed = TRUE, info = label)
  }
})

testthat::test_that("strategy preflight rejects global assignment as Tier 3", {
  strategy <- function(ctx, params) {
    counter <<- counter + 1
    ctx$flat()
  }

  preflight <- ledgr_strategy_preflight(strategy)
  testthat::expect_identical(preflight$tier, "tier_3")
  testthat::expect_false(preflight$allowed)
  testthat::expect_match(preflight$reason, "<<-", fixed = TRUE)

  lhs_only <- function(ctx, params) {
    global_probe_value <<- 1
    ctx$flat()
  }
  lhs_preflight <- ledgr_strategy_preflight(lhs_only)
  testthat::expect_identical(lhs_preflight$tier, "tier_3")
  testthat::expect_false(lhs_preflight$allowed)
  testthat::expect_match(lhs_preflight$reason, "<<-", fixed = TRUE)
  testthat::expect_false("global_probe_value" %in% lhs_preflight$unresolved_symbols)
})

testthat::test_that("strategy preflight rejects context attribute mutation as Tier 3", {
  strategy <- function(ctx, params) {
    attr(ctx, "secret") <- 1
    ctx$flat()
  }

  preflight <- ledgr_strategy_preflight(strategy)
  testthat::expect_identical(preflight$tier, "tier_3")
  testthat::expect_false(preflight$allowed)
  testthat::expect_match(preflight$reason, "attr(ctx", fixed = TRUE)
  testthat::expect_match(preflight$reason, "context mutation", fixed = TRUE)
})

testthat::test_that("strategy preflight flags ambient RNG as Tier 2, not certified Tier 1", {
  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    if (stats::runif(1) > 0.5) {
      targets["TEST_A"] <- 1
    }
    targets
  }

  preflight <- ledgr_strategy_preflight(strategy)
  testthat::expect_identical(preflight$tier, "tier_2")
  testthat::expect_true(preflight$allowed)
  testthat::expect_identical(preflight$unresolved_symbols, character())
  testthat::expect_identical(preflight$ambient_rng_symbols, "runif")
  testthat::expect_true(ledgr:::ledgr_strategy_preflight_uses_ambient_rng(preflight))
  testthat::expect_true(any(grepl("Ambient RNG", preflight$notes, fixed = TRUE)))
})

testthat::test_that("ambient RNG preflight has a resume fail-loud helper", {
  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    if (stats::runif(1) > 0.5) {
      targets["TEST_A"] <- 1
    }
    targets
  }
  preflight <- ledgr_strategy_preflight(strategy)

  err <- testthat::capture_error(
    ledgr:::ledgr_abort_strategy_ambient_rng_for_resume(preflight)
  )
  testthat::expect_s3_class(err, "ledgr_strategy_ambient_rng_resume")
  testthat::expect_s3_class(err, "ledgr_strategy_preflight_error")
  testthat::expect_match(conditionMessage(err), "runif", fixed = TRUE)
  testthat::expect_match(conditionMessage(err), "ctx$pulse_seed", fixed = TRUE)
})

testthat::test_that("strategy preflight keeps resolved external scalars as Tier 2", {
  threshold <- 100
  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    if (threshold > 0) {
      targets["TEST_A"] <- params$qty
    }
    targets
  }

  preflight <- ledgr_strategy_preflight(strategy)
  testthat::expect_identical(preflight$tier, "tier_2")
  testthat::expect_true(preflight$allowed)
  testthat::expect_true(any(grepl("threshold", preflight$notes, fixed = TRUE)))
})

testthat::test_that("strategy preflight keeps captured mutable environments Tier 2 with an explicit note", {
  external_env <- new.env(parent = emptyenv())
  external_env$qty <- 1
  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    targets["TEST_A"] <- external_env$qty
    targets
  }

  preflight <- ledgr_strategy_preflight(strategy)
  testthat::expect_identical(preflight$tier, "tier_2")
  testthat::expect_true(preflight$allowed)
  testthat::expect_true(any(grepl("external_env", preflight$notes, fixed = TRUE)))
  testthat::expect_true(any(grepl("mutated externally", preflight$notes, fixed = TRUE)))
})

testthat::test_that("ledgr_run stops Tier 3 strategies before execution", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  snapshot <- ledgr_snapshot_from_df(test_bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  my_helper <- function(ctx) ctx$flat()
  strategy <- function(ctx, params) {
    my_helper(ctx)
  }
  exp <- ledgr_experiment(snapshot, strategy)

  err <- testthat::capture_error(
    ledgr_run(exp, params = list(), run_id = "tier-3-run"),
  )
  testthat::expect_s3_class(err, "ledgr_strategy_preflight_error")
  testthat::expect_s3_class(err, "ledgr_strategy_tier3")
  testthat::expect_match(conditionMessage(err), "my_helper", fixed = TRUE)
  testthat::expect_match(conditionMessage(err), "will not execute it", fixed = TRUE)
  testthat::expect_match(conditionMessage(err), "There is no force override", fixed = TRUE)
  testthat::expect_false(grepl("by default", conditionMessage(err), fixed = TRUE))

  opened <- ledgr_test_open_duckdb(db_path)
  on.exit(ledgr_test_close_duckdb(opened$con, opened$drv), add = TRUE)
  rows <- DBI::dbGetQuery(
    opened$con,
    "SELECT run_id FROM runs WHERE run_id = 'tier-3-run'"
  )
  testthat::expect_equal(nrow(rows), 0L)
})

testthat::test_that("ledgr_run rejects forbidden calls before fingerprinting or execution artifacts", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  snapshot <- ledgr_snapshot_from_df(test_bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) {
    Sys.time()
    ctx$flat()
  }
  exp <- ledgr_experiment(snapshot, strategy)

  err <- testthat::capture_error(
    ledgr_run(exp, params = list(), run_id = "sys-time-tier-3-run")
  )
  testthat::expect_s3_class(err, "ledgr_strategy_preflight_error")
  testthat::expect_s3_class(err, "ledgr_strategy_tier3")
  testthat::expect_match(conditionMessage(err), "Sys.time", fixed = TRUE)
  testthat::expect_false(inherits(err, "ledgr_config_non_deterministic"))

  opened <- ledgr_test_open_duckdb(db_path)
  on.exit(ledgr_test_close_duckdb(opened$con, opened$drv), add = TRUE)
  rows <- DBI::dbGetQuery(
    opened$con,
    "SELECT run_id FROM runs WHERE run_id = 'sys-time-tier-3-run'"
  )
  testthat::expect_equal(nrow(rows), 0L)
})

testthat::test_that("ledgr_run rejects do.call indirection and context mutation before artifacts", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  snapshot <- ledgr_snapshot_from_df(test_bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  do_call_strategy <- function(ctx, params) {
    do.call("Sys.time", list())
    ctx$flat()
  }
  do_call_exp <- ledgr_experiment(snapshot, do_call_strategy)
  do_call_err <- testthat::capture_error(
    ledgr_run(do_call_exp, params = list(), run_id = "do-call-tier-3-run")
  )
  testthat::expect_s3_class(do_call_err, "ledgr_strategy_preflight_error")
  testthat::expect_s3_class(do_call_err, "ledgr_strategy_tier3")
  testthat::expect_match(conditionMessage(do_call_err), "do.call", fixed = TRUE)
  testthat::expect_match(conditionMessage(do_call_err), "Sys.time", fixed = TRUE)
  testthat::expect_false(inherits(do_call_err, "ledgr_config_non_deterministic"))

  attr_strategy <- function(ctx, params) {
    attr(ctx, "secret") <- 1
    ctx$flat()
  }
  attr_exp <- ledgr_experiment(snapshot, attr_strategy)
  attr_err <- testthat::capture_error(
    ledgr_run(attr_exp, params = list(), run_id = "attr-ctx-tier-3-run")
  )
  testthat::expect_s3_class(attr_err, "ledgr_strategy_preflight_error")
  testthat::expect_s3_class(attr_err, "ledgr_strategy_tier3")
  testthat::expect_match(conditionMessage(attr_err), "attr(ctx", fixed = TRUE)

  opened <- ledgr_test_open_duckdb(db_path)
  on.exit(ledgr_test_close_duckdb(opened$con, opened$drv), add = TRUE)
  rows <- DBI::dbGetQuery(
    opened$con,
    "SELECT run_id FROM runs WHERE run_id IN ('do-call-tier-3-run', 'attr-ctx-tier-3-run')"
  )
  testthat::expect_equal(nrow(rows), 0L)
})

testthat::test_that("ledgr_run rejects global assignment before strategy execution", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  snapshot <- ledgr_snapshot_from_df(test_bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  counter <- 0L
  strategy <- function(ctx, params) {
    counter <<- counter + 1L
    ctx$flat()
  }
  exp <- ledgr_experiment(snapshot, strategy)

  err <- testthat::capture_error(
    ledgr_run(exp, params = list(), run_id = "global-assign-tier-3-run")
  )
  testthat::expect_s3_class(err, "ledgr_strategy_preflight_error")
  testthat::expect_s3_class(err, "ledgr_strategy_tier3")
  testthat::expect_match(conditionMessage(err), "<<-", fixed = TRUE)
  testthat::expect_identical(counter, 0L)

  opened <- ledgr_test_open_duckdb(db_path)
  on.exit(ledgr_test_close_duckdb(opened$con, opened$drv), add = TRUE)
  rows <- DBI::dbGetQuery(
    opened$con,
    "SELECT run_id FROM runs WHERE run_id = 'global-assign-tier-3-run'"
  )
  testthat::expect_equal(nrow(rows), 0L)
})

testthat::test_that("force override is not implemented for run or preflight", {
  testthat::expect_false("force" %in% names(formals(ledgr_run)))
  testthat::expect_false("force" %in% names(formals(ledgr_strategy_preflight)))
})
