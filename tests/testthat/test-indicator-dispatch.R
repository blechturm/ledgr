# ledgr-test-file-profile: review

ws43_dispatch_dense_snapshot <- function(n = 55L) {
  ts <- as.POSIXct("2021-01-04 21:00:00", tz = "UTC") + 86400 * (seq_len(n) - 1L)
  bars <- data.frame(ts_utc = ts, instrument_id = "AAA", close = 10 + seq_len(n))
  bars$open <- bars$high <- bars$low <- bars$close
  bars$volume <- 100
  ledgr_snapshot_from_df(bars, db_path = tempfile(fileext = ".duckdb"))
}

# The session registry as name -> fingerprint, to compare before and after.
ws43_registry_state <- function() {
  registry <- get(".ledgr_indicator_registry", asNamespace("ledgr"))
  ids <- sort(ls(registry))
  stats::setNames(
    vapply(ids, function(id) ledgr:::ledgr_indicator_fingerprint(get(id, envir = registry)), character(1)),
    ids
  )
}

testthat::test_that("[LTB-0321] a custom indicator with a built-in id runs its own function in both modes", {
  # Cut 16 decision (19): an indicator whose id matches a built-in pattern
  # (`sma_<n>`, `return_1`) but whose definition is not the built-in is
  # computed with its own function in dense and availability runs, in a
  # default session and in any call order; it is never replaced by the
  # built-in. A run resolves each id from the experiment's own definitions
  # and never writes the session indicator registry (close review S2).
  registry <- get(".ledgr_indicator_registry", asNamespace("ledgr"))
  saved_sma_200 <- get("sma_200", envir = registry)
  on.exit(assign("sma_200", saved_sma_200, envir = registry), add = TRUE)
  before <- ws43_registry_state()

  observe <- function(snapshot, features, availability, run_id, ids = c("sma_50", "return_1")) {
    seen <- new.env(parent = emptyenv())
    for (id in ids) seen[[id]] <- numeric()
    strategy <- function(ctx, params) {
      for (id in names(seen)) seen[[id]] <- c(seen[[id]], ctx$feature("AAA", id))
      ctx$hold()
    }
    args <- list(snapshot, strategy, features = features, cost_model = ledgr_cost_zero())
    if (isTRUE(availability)) args$valuation_policy <- ledgr_valuation_stale(1L)
    exp <- do.call(ledgr_experiment, args)
    close(ledgr_run(exp, run_id = run_id))
    lapply(as.list(seen), function(x) x[!is.na(x)])
  }
  sma_oracle <- function(base, width, sessions) {
    vapply(sessions, function(k) base + mean(seq.int(k - width + 1L, k)), numeric(1))
  }
  custom <- list(
    ledgr_indicator("sma_50", function(window) 42, requires_bars = 3L, gap_contract = "strict_window"),
    ledgr_indicator("return_1", function(window) -7, requires_bars = 2L, gap_contract = "strict_window")
  )
  builtins <- list(ledgr_ind_sma(50L), ledgr_ind_returns(1L))
  custom_3 <- list(ledgr_indicator("sma_3", function(window) 43, requires_bars = 3L, gap_contract = "strict_window"))
  builtin_3 <- list(ledgr_ind_sma(3L))

  dense <- ws43_dispatch_dense_snapshot()
  on.exit(ledgr_snapshot_close(dense), add = TRUE)
  availability <- availability_runtime_fixture(days = 55L)
  on.exit(ledgr_snapshot_close(availability), add = TRUE)

  # Default session: `return_1` and `sma_50` are registered by the package.
  for (mode in c("dense", "availability")) {
    snapshot <- if (identical(mode, "dense")) dense else availability
    active <- identical(mode, "availability")
    base <- if (active) 100 else 10
    mine <- observe(snapshot, custom, active, paste(mode, "custom"))
    testthat::expect_identical(mine$sma_50, rep(42, 53L), info = mode)
    testthat::expect_identical(mine$return_1, rep(-7, 54L), info = mode)
    theirs <- observe(snapshot, builtins, active, paste(mode, "builtin"))
    testthat::expect_identical(theirs$sma_50, sma_oracle(base, 50L, 50:55), info = mode)
    # A built-in pattern id with no package registration, in both orders.
    first <- observe(snapshot, builtin_3, active, paste(mode, "sma3-builtin-1"), "sma_3")
    second <- observe(snapshot, custom_3, active, paste(mode, "sma3-custom-1"), "sma_3")
    third <- observe(snapshot, builtin_3, active, paste(mode, "sma3-builtin-2"), "sma_3")
    testthat::expect_identical(first$sma_3, sma_oracle(base, 3L, 3:55), info = mode)
    testthat::expect_identical(second$sma_3, rep(43, 53L), info = mode)
    testthat::expect_identical(third$sma_3, first$sma_3, info = mode)
  }

  # An explicit user registration is never overwritten by a run.
  mine_200 <- ledgr_indicator("sma_200", function(window) 7, requires_bars = 2L)
  ledgr_indicator_register(mine_200, "sma_200", overwrite = TRUE)
  after_registration <- ws43_registry_state()
  observe(dense, list(ledgr_ind_sma(200L)), FALSE, "dense-sma200", "sma_200")
  testthat::expect_identical(ledgr_indicator_get("sma_200"), mine_200)

  # Runs, sweeps and two-worker sweeps leave the registry as they found it.
  grid <- ledgr_param_grid(one = list())
  sweep_exp <- ledgr_experiment(
    availability, function(ctx, params) ctx$hold(), features = c(custom, custom_3),
    valuation_policy = ledgr_valuation_stale(1L), cost_model = ledgr_cost_zero()
  )
  ledgr_sweep(sweep_exp, grid, stop_on_error = TRUE)
  if (requireNamespace("mirai", quietly = TRUE) && !ledgr_test_in_coverage()) {
    ledgr_sweep(sweep_exp, ledgr_param_grid(one = list(), two = list()), workers = 2L, stop_on_error = TRUE)
  }
  testthat::expect_identical(ws43_registry_state(), after_registration)
  assign("sma_200", saved_sma_200, envir = registry)
  testthat::expect_identical(ws43_registry_state(), before)

  # Two different definitions under one id in one experiment refuse, at
  # experiment construction and again when a config is built.
  clash <- list(custom_3[[1L]], ledgr_indicator("sma_3", function(window) 44, requires_bars = 3L))
  testthat::expect_error(
    ledgr_experiment(dense, function(ctx, params) ctx$hold(), features = clash, cost_model = ledgr_cost_zero()),
    class = "ledgr_duplicate_feature_id"
  )
  testthat::expect_error(ledgr:::ledgr_feature_indicator_index(clash), class = "ledgr_invalid_args")

  # A stored fingerprint that is neither the built-in's nor a resolvable
  # indicator's refuses instead of falling back to the built-in.
  testthat::expect_false(exists("sma_997", envir = registry, inherits = FALSE))
  testthat::expect_error(
    ledgr:::ledgr_feature_defs_from_config(list(
      features = list(enabled = TRUE, defs = list(list(id = "sma_997", fingerprint = "not-the-builtin")))
    )),
    class = "ledgr_run_hash_mismatch"
  )
})
