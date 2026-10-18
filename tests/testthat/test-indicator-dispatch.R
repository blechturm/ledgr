# ledgr-test-file-profile: review

ws43_dispatch_dense_snapshot <- function(n = 55L) {
  ts <- as.POSIXct("2021-01-04 21:00:00", tz = "UTC") + 86400 * (seq_len(n) - 1L)
  bars <- data.frame(ts_utc = ts, instrument_id = "AAA", close = 10 + seq_len(n))
  bars$open <- bars$high <- bars$low <- bars$close
  bars$volume <- 100
  ledgr_snapshot_from_df(bars, db_path = tempfile(fileext = ".duckdb"))
}

testthat::test_that("[LTB-0321] a custom indicator with a built-in id runs its own function in both modes", {
  # Cut 16 decision (19): an indicator whose id matches a built-in pattern
  # (`sma_<n>`, `return_1`) but whose definition is not the built-in is
  # computed with its own function in dense and availability runs; it is
  # never silently replaced by the built-in. `return_1` and `sma_50` are also
  # registered by the package at load; in a default session the experiment's
  # own definition replaces that default, and the built-in replaces it back.
  registry <- get(".ledgr_indicator_registry", asNamespace("ledgr"))
  defaults <- get(".ledgr_indicator_package_defaults", asNamespace("ledgr"))
  testthat::expect_true(all(c("return_1", "sma_50") %in% ls(defaults)))
  on.exit({
    # Leave the session as the package loaded it.
    for (id in c("return_1", "sma_50")) {
      assign(id, get(id, envir = defaults), envir = registry)
    }
  }, add = TRUE)
  custom <- list(
    ledgr_indicator("sma_50", function(window) 42, requires_bars = 3L, gap_contract = "strict_window"),
    ledgr_indicator("return_1", function(window) -7, requires_bars = 2L, gap_contract = "strict_window")
  )
  builtins <- list(ledgr_ind_sma(50L), ledgr_ind_returns(1L))
  observe <- function(snapshot, features, availability, run_id) {
    seen <- new.env(parent = emptyenv())
    seen$sma <- numeric()
    seen$ret <- numeric()
    strategy <- function(ctx, params) {
      seen$sma <- c(seen$sma, ctx$feature("AAA", "sma_50"))
      seen$ret <- c(seen$ret, ctx$feature("AAA", "return_1"))
      ctx$hold()
    }
    args <- list(snapshot, strategy, features = features, cost_model = ledgr_cost_zero())
    if (isTRUE(availability)) args$valuation_policy <- ledgr_valuation_stale(1L)
    exp <- do.call(ledgr_experiment, args)
    close(ledgr_run(exp, run_id = run_id))
    list(sma = seen$sma[!is.na(seen$sma)], ret = seen$ret[!is.na(seen$ret)])
  }
  sma_oracle <- function(base, sessions) {
    vapply(sessions, function(k) base + mean(seq.int(k - 49L, k)), numeric(1))
  }

  dense <- ws43_dispatch_dense_snapshot()
  on.exit(ledgr_snapshot_close(dense), add = TRUE)
  custom_dense <- observe(dense, custom, FALSE, "dense-custom")
  testthat::expect_identical(custom_dense$sma, rep(42, 53L))
  testthat::expect_identical(custom_dense$ret, rep(-7, 54L))
  builtin_dense <- observe(dense, builtins, FALSE, "dense-builtin")
  testthat::expect_identical(builtin_dense$sma, sma_oracle(10, 50:55))
  testthat::expect_false(any(builtin_dense$ret == -7))

  availability <- availability_runtime_fixture(days = 55L)
  on.exit(ledgr_snapshot_close(availability), add = TRUE)
  custom_availability <- observe(availability, custom, TRUE, "availability-custom")
  testthat::expect_identical(custom_availability$sma, rep(42, 53L))
  testthat::expect_identical(custom_availability$ret, rep(-7, 54L))
  builtin_availability <- observe(availability, builtins, TRUE, "availability-builtin")
  testthat::expect_identical(builtin_availability$sma, sma_oracle(100, 50:55))

  # Two different user definitions under one id still refuse.
  other <- ledgr_indicator("sma_50", function(window) 43, requires_bars = 3L, gap_contract = "strict_window")
  ledgr:::ledgr_indicator_register_config(custom[[1L]])
  testthat::expect_error(
    ledgr:::ledgr_indicator_register_config(other),
    class = "ledgr_invalid_args"
  )

  # A stored fingerprint that is neither the built-in's nor a registered
  # indicator's refuses instead of falling back to the built-in.
  testthat::expect_false(exists("sma_997", envir = registry, inherits = FALSE))
  testthat::expect_error(
    ledgr:::ledgr_feature_defs_from_config(list(
      features = list(enabled = TRUE, defs = list(list(id = "sma_997", fingerprint = "not-the-builtin")))
    )),
    class = "ledgr_run_hash_mismatch"
  )
})
