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
      for (id in names(seen)) seen[[id]] <- c(seen[[id]], ctx[[id]][["AAA"]])
      ctx$hold()
    }
    args <- list(
      snapshot, strategy, features = features,
      opening = ledgr_opening(cash = 1000),
      cost_model = ledgr_cost_zero()
    )
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
    # Built-in one-session returns of closes base + k: 1 / (base + k - 1).
    testthat::expect_equal(theirs$return_1, 1 / (base + seq.int(2L, 55L) - 1), info = mode)
    testthat::expect_false(any(theirs$return_1 == -7), info = mode)
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
  grid <- ledgr_grid_named(one = list(strategy = list()))
  sweep_exp <- ledgr_experiment(opening = ledgr_opening(cash = 100000),
    availability, function(ctx, params) ctx$hold(),
    features = c(custom, custom_3),
    valuation_policy = ledgr_valuation_stale(1L), cost_model = ledgr_cost_zero()
  )
  ledgr_sweep(sweep_exp, grid, stop_on_error = TRUE)
  if (requireNamespace("mirai", quietly = TRUE) && !ledgr_test_in_coverage()) {
    ledgr_sweep(sweep_exp, ledgr_grid_named(one = list(strategy = list()), two = list(strategy = list())), workers = 2L, stop_on_error = TRUE)
  }
  testthat::expect_identical(ws43_registry_state(), after_registration)
  assign("sma_200", saved_sma_200, envir = registry)
  testthat::expect_identical(ws43_registry_state(), before)

  # Two different definitions under one id in one experiment refuse, at
  # experiment construction and again when a config is built.
  clash <- list(custom_3[[1L]], ledgr_indicator("sma_3", function(window) 44, requires_bars = 3L))
  testthat::expect_error(
    ledgr_experiment(opening = ledgr_opening(cash = 100000), dense, function(ctx, params) ctx$hold(), features = clash, cost_model = ledgr_cost_zero()),
    class = "ledgr_duplicate_feature_id"
  )
  testthat::expect_error(ledgr:::ledgr_feature_indicator_index(clash), class = "ledgr_invalid_args")

  # A reopened or JSON-parsed config carries no indicator objects: dispatch
  # reads the registry, and a registered definition whose fingerprint differs
  # from the stored one refuses.
  registered_b2 <- ledgr_indicator("ws43_registered_b2", function(window) 1, requires_bars = 1L)
  ledgr_indicator_register(registered_b2)
  on.exit(ledgr_indicator_remove("ws43_registered_b2"), add = TRUE)
  reopened <- list(
    features = list(enabled = TRUE, defs = list(list(id = "ws43_registered_b2", fingerprint = "stale")))
  )
  testthat::expect_null(attr(reopened, "ledgr_feature_indicators"))
  testthat::expect_error(
    ledgr:::ledgr_feature_defs_from_config(reopened),
    class = "ledgr_run_hash_mismatch"
  )

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

# Cut 23 (LDG-3256): a stored built-in id (`sma_<n>`, `return_1`) that is not
# shadowed rebuilds from the built-in constructor, with the stored overlay and
# the stored fingerprint, on both clocks (decision 4). The configs are the
# ones real runs build (ledgr_config()), captured at the rebuild.
cut23_builtins <- function() {
  list(sma_1 = ledgr_ind_sma(1L), sma_3 = ledgr_ind_sma(3L),
       sma_200 = ledgr_ind_sma(200L), return_1 = ledgr_ind_returns(1L))
}

cut23_configs <- function() {
  rebuild <- ledgr:::ledgr_feature_defs_from_config
  capture <- function(snapshot, availability) {
    seen <- new.env(parent = emptyenv())
    testthat::local_mocked_bindings(
      ledgr_feature_defs_from_config = function(cfg) {
        seen$cfg <- cfg
        rebuild(cfg)
      },
      .package = "ledgr"
    )
    args <- list(snapshot, function(ctx, params) ctx$hold(), features = unname(cut23_builtins()),
                 opening = ledgr_opening(cash = 1000), cost_model = ledgr_cost_zero())
    if (availability) args$valuation_policy <- ledgr_valuation_stale(1L)
    close(ledgr_run(do.call(ledgr_experiment, args), run_id = paste0("cut23_", availability)))
    seen$cfg
  }
  dense <- ws43_dispatch_dense_snapshot()
  on.exit(ledgr_snapshot_close(dense), add = TRUE)
  active <- availability_runtime_fixture(days = 55L)
  on.exit(ledgr_snapshot_close(active), add = TRUE)
  list(bar_native = capture(dense, FALSE), availability = capture(active, TRUE))
}

# The expected rebuild, assembled from the constructor's conversion with each
# stored declaration and the stored fingerprint applied explicitly.
cut23_expected <- function(builtin, stored) {
  def <- ledgr:::ledgr_precompute_feature_def_from_indicator(builtin)
  for (field in c("gap_contract", "history_class", "required_fields", "input_carry", "tolerance")) {
    if (!is.null(stored[[field]])) def[[field]] <- stored[[field]]
  }
  if (!is.null(stored$fingerprint)) def$fingerprint <- stored$fingerprint
  def
}

# Non-function fields exactly; functions by code, formals and captures.
cut23_expect_same_def <- function(actual, expected, info) {
  fp <- function(f) ledgr:::ledgr_function_fingerprint(f, include_captures = TRUE)
  testthat::expect_setequal(names(actual), names(expected))
  for (field in names(expected)) {
    if (is.function(expected[[field]])) {
      testthat::expect_true(is.function(actual[[field]]), info = paste(info, field))
      if (is.function(actual[[field]])) {
        testthat::expect_identical(fp(actual[[field]]), fp(expected[[field]]), info = paste(info, field))
      }
    } else {
      testthat::expect_identical(actual[[field]], expected[[field]], info = paste(info, field))
    }
  }
}

cut23_rebuilt <- function(cfg) {
  out <- ledgr:::ledgr_feature_defs_from_config(cfg)
  stats::setNames(out, vapply(out, function(d) d$id, character(1)))
}

cut23_stored <- function(cfg) {
  stats::setNames(cfg$features$defs, vapply(cfg$features$defs, function(d) d$id, character(1)))
}

cut23_without_fingerprints <- function(cfg) {
  cfg$features$defs <- lapply(cfg$features$defs, function(d) {
    d$fingerprint <- NULL
    d
  })
  cfg
}

testthat::test_that("[Cut 23 (a)] a stored built-in id rebuilds as the built-in with the stored overlay", {
  configs <- cut23_configs()
  builtins <- cut23_builtins()
  for (clock in names(configs)) {
    cfg <- configs[[clock]]
    stored <- cut23_stored(cfg)
    rebuilt <- cut23_rebuilt(cfg)
    testthat::expect_setequal(names(rebuilt), names(builtins))
    for (id in names(builtins)) {
      cut23_expect_same_def(rebuilt[[id]], cut23_expected(builtins[[id]], stored[[id]]), paste(clock, id))
      testthat::expect_identical(rebuilt[[id]]$fingerprint, stored[[id]]$fingerprint, info = paste(clock, id))
    }
  }
  # The availability clock stores the active fingerprint, not the base one,
  # and the rebuild keeps it.
  stored <- cut23_stored(configs$availability)
  for (id in names(builtins)) {
    testthat::expect_false(identical(stored[[id]]$fingerprint, ledgr:::ledgr_indicator_fingerprint(builtins[[id]])))
    testthat::expect_identical(
      stored[[id]]$fingerprint,
      ledgr:::ledgr_active_feature_fingerprint(ledgr:::ledgr_precompute_feature_def_from_indicator(builtins[[id]]))
    )
  }
  # Non-default stored declarations are applied, so an omitted overlay fails.
  cfg <- configs$availability
  cfg$features$defs <- lapply(cfg$features$defs, function(d) {
    d$required_fields <- c("open", "close")
    d$tolerance <- 1e-9
    d
  })
  rebuilt <- cut23_rebuilt(cfg)
  for (id in names(builtins)) {
    testthat::expect_identical(rebuilt[[id]]$required_fields, c("open", "close"), info = id)
    testthat::expect_identical(rebuilt[[id]]$tolerance, 1e-9, info = id)
    cut23_expect_same_def(rebuilt[[id]], cut23_expected(builtins[[id]], cut23_stored(cfg)[[id]]), paste("overlay", id))
  }
})

testthat::test_that("[Cut 23 (b)] the rebuilt built-in certifies as the canonical built-in under its stored fingerprint", {
  configs <- cut23_configs()
  builtins <- cut23_builtins()
  for (clock in names(configs)) {
    stored <- cut23_stored(configs[[clock]])
    rebuilt <- cut23_rebuilt(configs[[clock]])
    for (id in names(builtins)) {
      cert <- ledgr:::ledgr_feature_certify(rebuilt[[id]])
      canonical <- ledgr:::ledgr_precompute_feature_def_from_indicator(builtins[[id]])
      canonical$fingerprint <- stored[[id]]$fingerprint
      testthat::expect_identical(cert$certification, "builtin", info = paste(clock, id))
      cut23_expect_same_def(cert$def, canonical, paste(clock, id))
      testthat::expect_identical(cert$declarations, ledgr:::ledgr_feature_def_declarations(canonical),
                                 info = paste(clock, id))
    }
  }
})

testthat::test_that("[Cut 23 (c)] a stored built-in id without a fingerprint rebuilds and certifies as the built-in", {
  configs <- cut23_configs()
  builtins <- cut23_builtins()
  for (clock in names(configs)) {
    cfg <- cut23_without_fingerprints(configs[[clock]])
    stored <- cut23_stored(cfg)
    rebuilt <- cut23_rebuilt(cfg)
    for (id in names(builtins)) {
      own <- ledgr:::ledgr_precompute_feature_def_from_indicator(builtins[[id]])$fingerprint
      testthat::expect_identical(rebuilt[[id]]$fingerprint, own, info = paste(clock, id))
      cut23_expect_same_def(rebuilt[[id]], cut23_expected(builtins[[id]], stored[[id]]), paste(clock, id))
      testthat::expect_identical(ledgr:::ledgr_feature_certify(rebuilt[[id]])$certification, "builtin",
                                 info = paste(clock, id))
    }
  }
})

testthat::test_that("[Cut 23 (d)] rebuilt built-ins keep their history-read widths on both clocks", {
  configs <- cut23_configs()
  widths <- c(sma_1 = 1L, sma_3 = 3L, sma_200 = 200L, return_1 = 2L)
  for (clock in names(configs)) {
    rebuilt <- cut23_rebuilt(configs[[clock]])
    got <- vapply(names(widths), function(id) ledgr:::ledgr_history_feature_width(rebuilt[[id]]), integer(1))
    testthat::expect_identical(got, widths, info = clock)
  }
})

cut23_config <- function(...) list(features = list(enabled = TRUE, defs = list(list(...))))

testthat::test_that("[Cut 23 (e)] a fingerprint-free malformed SMA id refuses as the built-in constructor does", {
  testthat::expect_error(ledgr:::ledgr_feature_defs_from_config(cut23_config(id = "sma_0")),
                         class = "ledgr_invalid_args")
  testthat::expect_warning(
    testthat::expect_error(ledgr:::ledgr_feature_defs_from_config(cut23_config(id = "sma_2147483648")),
                           class = "ledgr_invalid_args"),
    "integer range"
  )
})

testthat::test_that("[Cut 23 (e)] fingerprint-bearing and other malformed ids keep their refusals", {
  testthat::expect_error(
    ledgr:::ledgr_feature_defs_from_config(cut23_config(id = "sma_0", fingerprint = "unknown")),
    class = "ledgr_invalid_args"
  )
  testthat::expect_warning(
    testthat::expect_error(
      ledgr:::ledgr_feature_defs_from_config(cut23_config(id = "sma_2147483648", fingerprint = "unknown")),
      class = "ledgr_invalid_args"
    ),
    "integer range"
  )
  testthat::expect_error(ledgr:::ledgr_feature_defs_from_config(cut23_config(id = "sma_1.5")),
                         class = "ledgr_invalid_config")
  testthat::expect_error(
    ledgr:::ledgr_feature_defs_from_config(cut23_config(id = "sma_997", fingerprint = "not-the-builtin")),
    class = "ledgr_run_hash_mismatch"
  )
})

testthat::test_that("[Cut 23 (f)] the v0.1.4 list definitions and their validator are gone", {
  ns <- asNamespace("ledgr")
  for (name in c("ledgr_feature_sma_n", "ledgr_feature_return_1", "ledgr_validate_feature_def")) {
    testthat::expect_false(exists(name, envir = ns, inherits = FALSE), info = name)
  }
})
