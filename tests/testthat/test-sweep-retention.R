ledgr_sweep_retention_test_bars <- function() {
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

ledgr_sweep_retention_comparable_rows <- function(x) {
  volatile <- c("t_engine", "t_results", "t_fills_extract")
  out <- as.data.frame(x[, !names(x) %in% volatile, drop = FALSE])
  out$params <- vapply(out$params, ledgr:::canonical_json, character(1))
  out$feature_params <- vapply(out$feature_params, ledgr:::canonical_json, character(1))
  out$warnings <- vapply(out$warnings, ledgr:::canonical_json, character(1))
  out$feature_fingerprints <- vapply(out$feature_fingerprints, ledgr:::canonical_json, character(1))
  out$provenance <- vapply(out$provenance, ledgr:::canonical_json, character(1))
  attr(out, "sweep_id") <- NULL
  attr(out, "sweep_retention") <- NULL
  attr(out, "sweep_returns") <- NULL
  out
}

ledgr_sweep_retention_comparable_key <- function(key) {
  key$source_sweep$sweep_id <- "<sweep-id>"
  key
}

testthat::test_that("ledgr_sweep_retention constructs stable retention objects", {
  default <- ledgr_sweep_retention()
  explicit_none <- ledgr_sweep_retention("none")
  completed <- ledgr_sweep_retention("completed")

  testthat::expect_s3_class(default, "ledgr_sweep_retention")
  testthat::expect_identical(default, explicit_none)
  testthat::expect_identical(default$retention_schema_version, 1L)
  testthat::expect_identical(default$returns, "none")
  testthat::expect_identical(completed$returns, "completed")
  testthat::expect_identical(
    ledgr:::canonical_json(completed),
    ledgr:::canonical_json(ledgr_sweep_retention("completed"))
  )
})

testthat::test_that("ledgr_sweep_retention fails loudly on invalid values", {
  testthat::expect_error(
    ledgr_sweep_retention("bad"),
    class = "ledgr_invalid_sweep_retention"
  )
  testthat::expect_error(
    ledgr_sweep_retention(c("none", "completed")),
    class = "ledgr_invalid_sweep_retention"
  )
  testthat::expect_error(
    ledgr_sweep_retention(NA_character_),
    class = "ledgr_invalid_sweep_retention"
  )
  testthat::expect_error(
    ledgr_sweep_retention(1),
    class = "ledgr_invalid_sweep_retention"
  )
})

testthat::test_that("ledgr_sweep attaches retention metadata without changing default rows", {
  snapshot <- ledgr_snapshot_from_df(ledgr_sweep_retention_test_bars())
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    targets["AAA"] <- params$qty
    targets
  }
  exp <- ledgr_experiment(snapshot, strategy, cost_model = ledgr_cost_zero())
  grid <- ledgr_param_grid(a = list(qty = 1), b = list(qty = 2))

  out <- ledgr_sweep(exp, grid, seed = 123L)

  testthat::expect_s3_class(out, "ledgr_sweep_results")
  testthat::expect_identical(
    names(out),
    c(
      "candidate_id", "candidate_row", "status", "final_equity", "total_return",
      "annualized_return", "volatility", "sharpe_ratio", "max_drawdown",
      "n_trades", "win_rate", "avg_trade", "time_in_market",
      "execution_seed", "error_class", "error_msg", "params",
      "feature_params", "warnings", "feature_fingerprints", "provenance",
      "t_engine", "t_results", "t_fills_extract"
    )
  )
  testthat::expect_identical(attr(out, "sweep_retention"), ledgr_sweep_retention())
  testthat::expect_null(attr(out, "execution_assumptions")$sweep_retention)
})

testthat::test_that("completed retention is accepted without changing scalar identity", {
  snapshot <- ledgr_snapshot_from_df(ledgr_sweep_retention_test_bars())
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    targets["AAA"] <- params$qty
    targets
  }
  exp <- ledgr_experiment(snapshot, strategy, cost_model = ledgr_cost_zero())
  grid <- ledgr_param_grid(a = list(qty = 1), b = list(qty = 2))

  none <- ledgr_sweep(exp, grid, seed = 123L, retain = ledgr_sweep_retention("none"))
  completed <- ledgr_sweep(exp, grid, seed = 123L, retain = ledgr_sweep_retention("completed"))

  testthat::expect_identical(attr(none, "sweep_retention"), ledgr_sweep_retention("none"))
  testthat::expect_identical(attr(completed, "sweep_retention"), ledgr_sweep_retention("completed"))
  testthat::expect_equal(
    ledgr_sweep_retention_comparable_rows(completed),
    ledgr_sweep_retention_comparable_rows(none)
  )
  testthat::expect_identical(
    attr(completed, "execution_assumptions"),
    attr(none, "execution_assumptions")
  )
  testthat::expect_null(attr(completed, "execution_assumptions")$sweep_retention)

  key_none <- ledgr_candidate_reproduction_key(ledgr_candidate(none, "a"))
  key_completed <- ledgr_candidate_reproduction_key(ledgr_candidate(completed, "a"))
  testthat::expect_equal(
    ledgr_sweep_retention_comparable_key(key_completed),
    ledgr_sweep_retention_comparable_key(key_none)
  )
})

testthat::test_that("completed retention exposes long and wide return series", {
  snapshot <- ledgr_snapshot_from_df(ledgr_sweep_retention_test_bars())
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    targets["AAA"] <- params$qty
    targets
  }
  exp <- ledgr_experiment(snapshot, strategy, cost_model = ledgr_cost_zero())
  grid <- ledgr_param_grid(a = list(qty = 1), b = list(qty = 2))

  out <- ledgr_sweep(exp, grid, seed = 123L, retain = ledgr_sweep_retention("completed"))
  long <- ledgr_sweep_returns(out)

  testthat::expect_s3_class(long, "tbl_df")
  testthat::expect_identical(names(long), c("sweep_id", "candidate_id", "ts_utc", "equity", "period_return"))
  testthat::expect_identical(unique(long$sweep_id), attr(out, "sweep_id"))
  testthat::expect_identical(unique(long$candidate_id), c("a", "b"))
  testthat::expect_identical(nrow(long), length(unique(long$ts_utc)) * 2L)

  for (candidate_id in c("a", "b")) {
    rows <- long[long$candidate_id == candidate_id, , drop = FALSE]
    summary_row <- out[out$candidate_id == candidate_id, , drop = FALSE]
    testthat::expect_true(is.na(rows$period_return[[1]]))
    testthat::expect_equal(
      rows$period_return[-1],
      ledgr:::compute_period_returns(rows$equity),
      tolerance = 1e-12
    )
    testthat::expect_equal(rows$equity[[nrow(rows)]], summary_row$final_equity[[1]], tolerance = 1e-12)
  }

  only_b <- ledgr_sweep_returns(out, candidates = "b")
  testthat::expect_identical(unique(only_b$candidate_id), "b")

  wide_returns <- ledgr_sweep_returns_wide(out, candidates = c("b", "a"))
  testthat::expect_identical(names(wide_returns), c("ts_utc", "b", "a"))
  testthat::expect_true(is.na(wide_returns$b[[1]]))
  testthat::expect_equal(
    wide_returns$b,
    only_b$period_return,
    tolerance = 1e-12
  )

  wide_equity <- ledgr_sweep_returns_wide(out, candidates = c("b", "a"), value = "equity")
  testthat::expect_identical(names(wide_equity), c("ts_utc", "b", "a"))
  testthat::expect_equal(wide_equity$b, only_b$equity, tolerance = 1e-12)

  compiled <- ledgr_sweep(
    exp,
    grid,
    seed = 123L,
    retain = ledgr_sweep_retention("completed"),
    compiled_accounting_model = "spot_fifo"
  )
  compiled_long <- ledgr_sweep_returns(compiled)
  testthat::expect_equal(compiled_long$equity, long$equity, tolerance = 1e-12)
  testthat::expect_equal(compiled_long$period_return, long$period_return, tolerance = 1e-12)
})

testthat::test_that("retained return accessors fail loudly for unretained, missing, and failed candidates", {
  snapshot <- ledgr_snapshot_from_df(ledgr_sweep_retention_test_bars())
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) {
    if (isTRUE(params$fail)) {
      stop("candidate failed")
    }
    targets <- ctx$flat()
    targets["AAA"] <- params$qty
    targets
  }
  exp <- ledgr_experiment(snapshot, strategy, cost_model = ledgr_cost_zero())
  grid <- ledgr_param_grid(
    good = list(qty = 1, fail = FALSE),
    bad = list(qty = 1, fail = TRUE)
  )

  unretained <- ledgr_sweep(exp, grid, seed = 123L)
  retained <- ledgr_sweep(exp, grid, seed = 123L, retain = ledgr_sweep_retention("completed"))

  testthat::expect_error(
    ledgr_sweep_returns(unretained),
    class = "ledgr_sweep_returns_unretained"
  )
  testthat::expect_error(
    ledgr_sweep_returns(retained, candidates = "missing"),
    class = "ledgr_sweep_returns_candidate_not_found"
  )
  testthat::expect_error(
    ledgr_sweep_returns(retained, candidates = "bad"),
    class = "ledgr_sweep_returns_candidate_not_completed"
  )

  long <- ledgr_sweep_returns(retained)
  testthat::expect_identical(unique(long$candidate_id), "good")
  testthat::expect_false("bad" %in% long$candidate_id)
})

testthat::test_that("retained returns keep final equity row with final-bar no-fill warning", {
  snapshot <- ledgr_snapshot_from_df(ledgr_sweep_retention_test_bars())
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    if (identical(ctx$ts_utc, "2020-01-06T00:00:00Z")) {
      targets["AAA"] <- params$qty
    }
    targets
  }
  exp <- ledgr_experiment(snapshot, strategy, cost_model = ledgr_cost_zero())
  grid <- ledgr_param_grid(candidate = list(qty = 1))

  out <- ledgr_sweep(exp, grid, seed = 123L, retain = ledgr_sweep_retention("completed"))
  long <- ledgr_sweep_returns(out)

  testthat::expect_identical(nrow(long), 6L)
  testthat::expect_identical(long$ts_utc[[nrow(long)]], as.POSIXct("2020-01-06", tz = "UTC"))
  testthat::expect_equal(long$equity[[nrow(long)]], out$final_equity[[1]], tolerance = 1e-12)
  testthat::expect_true(any(grepl(
    "LEDGR_LAST_BAR_NO_FILL",
    vapply(out$warnings[[1]], conditionMessage, character(1)),
    fixed = TRUE
  )))
})

testthat::test_that("ledgr_sweep rejects invalid retain arguments before execution", {
  snapshot <- ledgr_snapshot_from_df(ledgr_sweep_retention_test_bars())
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) ctx$flat()
  exp <- ledgr_experiment(snapshot, strategy, cost_model = ledgr_cost_zero())
  grid <- ledgr_param_grid(candidate = list())

  testthat::expect_error(
    ledgr_sweep(exp, grid, retain = "completed"),
    class = "ledgr_invalid_sweep_retention"
  )
  invalid <- structure(list(retention_schema_version = 1L, returns = "bad"), class = "ledgr_sweep_retention")
  testthat::expect_error(
    ledgr_sweep(exp, grid, retain = invalid),
    class = "ledgr_invalid_sweep_retention"
  )
})
