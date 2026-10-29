# RNG isolation, kind pinning and RNG-neutral store writes (LDG-3158;
# inst/design/ledgr_v0_2_3_spec_packet/ws2_rng_design.md Sections 3-5).
# Each witness draws; the ticket evidence records that each fails when its
# fix is reverted.

# ---------------------------------------------------------------------------
# Section 4: source inventory
# ---------------------------------------------------------------------------

testthat::test_that("rng source inventory passes on the package source and reports injected sites", {
  root <- ledgr_test_source_root()
  testthat::skip_if_not(dir.exists(file.path(root, "R")), "package R sources unavailable")
  parsed <- ledgr_rng_src_parse_dir(root)
  clean <- ledgr_rng_source_inventory(parsed)
  testthat::expect_identical(nrow(clean), 0L, info = paste(capture.output(print(clean)), collapse = "\n"))

  # The owners themselves are present in the parsed source.
  owners <- vapply(parsed, function(exprs) {
    paste(vapply(as.list(exprs), ledgr_rng_src_top_name, character(1)), collapse = " ")
  }, character(1))
  for (owner in c("ledgr_store_append", "ledgr_rng_seed_pinned", "ledgr_rng_caller_state",
                  "ledgr_rng_restore", "ledgr_parallel_worker_rng_pin")) {
    testthat::expect_true(any(grepl(paste0("\\b", owner, "\\b"), owners)), info = owner)
  }

  inject <- function(text) {
    ledgr_rng_source_inventory(c(parsed, ledgr_rng_src_parse_text(text)))
  }
  hit <- inject("ledgr_injected_writer <- function(con, df) DBI::dbAppendTable(con, \"x\", df)")
  testthat::expect_identical(hit$rule, "unguarded_store_write")
  testthat::expect_identical(hit$function_name, "ledgr_injected_writer")

  hit <- inject("ledgr_rng_caller_state <- function() { RNGkind(\"L'Ecuyer-CMRG\"); RNGkind() }")
  testthat::expect_identical(hit$rule, "unowned_rngkind_mutation")

  hit <- inject("ledgr_injected_query <- function() RNGkind()")
  testthat::expect_identical(hit$rule, "unowned_rngkind_query")

  hit <- inject("ledgr_injected_mutation <- function() RNGkind(\"Mersenne-Twister\", \"Inversion\", \"Rejection\")")
  testthat::expect_identical(hit$rule, "unowned_rngkind_mutation")

  hit <- inject("ledgr_injected_seed <- function() set.seed(1L)")
  testthat::expect_identical(hit$rule, "unowned_set_seed")

  hit <- inject("ledgr_injected_workers <- function() mirai::daemons(2L)")
  testthat::expect_identical(hit$rule, "unowned_daemons")

  hit <- inject("ledgr_injected_table <- function(con, df) DBI::dbWriteTable(con, \"x\", df)")
  testthat::expect_identical(hit$rule, "unguarded_store_write")
})

# ---------------------------------------------------------------------------
# Section 5.4: wrapper-shape source check
# ---------------------------------------------------------------------------

testthat::test_that("rng wrapper source check passes on the package source and rejects broken shapes", {
  root <- ledgr_test_source_root()
  testthat::skip_if_not(dir.exists(file.path(root, "R")), "package R sources unavailable")
  parsed <- ledgr_rng_src_parse_dir(root)
  testthat::expect_identical(ledgr_rng_source_check(parsed), character())
  testthat::expect_length(ledgr_rng_wrapper_expected(), 18L)

  # Replace one top-level definition and rerun the check.
  replace_def <- function(name, text) {
    out <- parsed
    for (file in names(out)) {
      exprs <- as.list(out[[file]])
      at <- which(vapply(exprs, ledgr_rng_src_top_name, character(1)) == name)
      if (length(at)) {
        exprs[[at[[1L]]]] <- parse(text = text, keep.source = FALSE)[[1L]]
        out[[file]] <- as.expression(exprs)
      }
    }
    ledgr_rng_source_check(out)
  }
  expect_problem <- function(problems, pattern) {
    testthat::expect_true(any(grepl(pattern, problems)), info = paste(problems, collapse = "\n"))
  }

  expect_problem(replace_def("ledgr_run", "ledgr_run <- function(exp, params = list(), feature_params = list(), run_id = NULL, seed = NULL, compiled_accounting_model = NULL) { seed_missing <- missing(seed); ledgr_rng_preserve_caller(ledgr_run_impl(exp = exp, params = params, feature_params = feature_params, run_id = run_id, seed = seed, compiled_accounting_model = compiled_accounting_model)) }"),
    "ledgr_run: first statement is not ledgr_rng_force_args")
  expect_problem(replace_def("ledgr_run", "ledgr_run <- function(exp, params = list(), feature_params = list(), run_id = NULL, seed = NULL, compiled_accounting_model = NULL) { ledgr_rng_force_args(); on.exit(NULL); ledgr_rng_preserve_caller(ledgr_run_impl(exp = exp)) }"),
    "ledgr_run: on.exit")
  expect_problem(replace_def("ledgr_sweep_review", "ledgr_sweep_review <- function(sweep, rank_by, n = 5L) { ledgr_rng_force_args(); rank_missing <- missing(rank_by); rank_expr <- substitute(rank_by); rank_env <- parent.frame(); ledgr_rng_preserve_caller(ledgr_sweep_review_impl(sweep = sweep, n = n, rank_expr = rank_expr, rank_env = rank_env, rank_missing = rank_missing)) }"),
    "lazy set")
  expect_problem(replace_def("ledgr_promote", "ledgr_promote <- function(exp, candidate, run_id, note = NULL, require_same_snapshot = TRUE) { ledgr_rng_force_args(); x <- runif(1); ledgr_rng_preserve_caller(ledgr_promote_impl(exp = exp)) }"),
    "outside the permitted prologue")
  expect_problem(replace_def("ledgr_pbo_impl", "ledgr_pbo_impl <- function(x, candidates, S, metric, metric_label, metric_name, threshold) ledgr_pbo_metric(metric, substitute(metric), metric_name)"),
    "recaptures forwarded formal")
  expect_problem(replace_def("ledgr_sweep_review_impl", "ledgr_sweep_review_impl <- function(sweep, n, rank_expr, rank_env, rank_missing) eval(rank_expr, parent.frame())"),
    "ledgr_sweep_review_impl: parent.frame")
  expect_problem(replace_def("ledgr_candidate", "ledgr_candidate <- function(results, ...) { ledgr_rng_force_args(); UseMethod(\"ledgr_candidate\") }"),
    "unexpected wrapper-shape body: ledgr_candidate")
  expect_problem(replace_def("ledgr_utc", "ledgr_utc <- function(x) { ledgr_rng_force_args(); ledgr_rng_preserve_caller(ledgr_utc_impl(x)) }"),
    "unexpected wrapper-shape body: ledgr_utc")
  expect_problem(replace_def("ledgr_sim_bars", "ledgr_sim_bars <- function(n_instruments = 10L) ledgr_sim_bars_impl(n_instruments)"),
    "missing wrapper-shape body: ledgr_sim_bars")
  expect_problem(replace_def("ledgr_walk_forward", "ledgr_walk_forward <- function(exp, ...) { ledgr_rng_force_args(); ledgr_rng_preserve_caller(ledgr_walk_forward_impl(exp = exp)); ledgr_rng_preserve_caller(NULL) }"),
    "ledgr_walk_forward: 2 ledgr_rng_preserve_caller")
})

# ---------------------------------------------------------------------------
# Helpers: seeding, state, preserve, force, store append
# ---------------------------------------------------------------------------

testthat::test_that("rng helpers pin the kind and restore present and absent caller state", {
  ledgr_rng_test_local_restore()

  suppressWarnings(RNGkind("L'Ecuyer-CMRG", "Box-Muller", "Rounding"))
  ledgr:::ledgr_rng_seed_pinned(7L)
  testthat::expect_identical(RNGkind(), c("Mersenne-Twister", "Inversion", "Rejection"))
  pinned <- stats::runif(3)
  set.seed(7L, kind = "Mersenne-Twister", normal.kind = "Inversion", sample.kind = "Rejection")
  testthat::expect_identical(stats::runif(3), pinned)

  for (state in ledgr_rng_test_states()) {
    ledgr_rng_test_set_state(state)
    kind <- RNGkind()
    seed <- ledgr_rng_test_seed()
    saved <- ledgr:::ledgr_rng_caller_state()
    testthat::expect_identical(ledgr_rng_test_seed(), seed, info = "querying the state creates no seed")
    ledgr:::ledgr_rng_seed_pinned(99L)
    stats::runif(5)
    ledgr:::ledgr_rng_restore(saved)
    testthat::expect_identical(RNGkind(), kind, info = state)
    testthat::expect_identical(ledgr_rng_test_seed(), seed, info = state)
  }

  # preserve_caller restores on success, error and interrupt, and keeps visibility.
  for (state in ledgr_rng_test_states()) {
    ledgr_rng_test_set_state(state)
    kind <- RNGkind()
    seed <- ledgr_rng_test_seed()
    testthat::expect_identical(ledgr:::ledgr_rng_preserve_caller({ ledgr:::ledgr_rng_seed_pinned(1L); stats::runif(1); 3 }), 3)
    testthat::expect_identical(withVisible(ledgr:::ledgr_rng_preserve_caller(invisible(4)))$visible, FALSE)
    testthat::expect_error(ledgr:::ledgr_rng_preserve_caller({ ledgr:::ledgr_rng_seed_pinned(1L); stats::runif(1); stop("boom") }), "boom")
    caught <- tryCatch(ledgr:::ledgr_rng_preserve_caller({ ledgr:::ledgr_rng_seed_pinned(1L); stats::runif(1); rlang::interrupt() }),
      interrupt = function(e) "interrupted")
    testthat::expect_identical(caught, "interrupted")
    testthat::expect_identical(RNGkind(), kind, info = state)
    testthat::expect_identical(ledgr_rng_test_seed(), seed, info = state)
  }
})

testthat::test_that("rng force step forces supplied arguments and dots but not missing or lazy formals", {
  log <- character()
  note <- function(x) {
    log <<- c(log, x)
    x
  }
  probe <- function(a, b = note("b-default"), lazy_arg, ...) {
    ledgr:::ledgr_rng_force_args(lazy = "lazy_arg")
    log <<- c(log, "after-force")
    invisible(NULL)
  }
  probe(note("a"), lazy_arg = note("lazy"), note("dot"))
  testthat::expect_identical(log, c("a", "dot", "after-force"))

  log <- character()
  probe(note("a"), b = note("b"))
  testthat::expect_identical(log, c("a", "b", "after-force"))

  # An argument error surfaces from the force step, before any later work.
  log <- character()
  testthat::expect_error(probe(stop("arg failed")), "arg failed")
  testthat::expect_identical(log, character())
})

testthat::test_that("ledgr_store_append keeps the caller seed on normal and error exits", {
  ledgr_rng_test_local_restore()
  drv <- duckdb::duckdb()
  con <- DBI::dbConnect(drv, dbdir = ":memory:")
  on.exit({
    DBI::dbDisconnect(con, shutdown = TRUE)
  }, add = TRUE)
  DBI::dbExecute(con, "CREATE TABLE t (x INTEGER)")
  df <- data.frame(x = 1:3)

  # The raw append draws: it moves a present seed (the defect the helper fixes).
  set.seed(11L)
  raw_before <- ledgr_rng_test_seed()
  DBI::dbAppendTable(con, "t", df)
  testthat::expect_false(identical(ledgr_rng_test_seed(), raw_before))

  set.seed(11L)
  before <- ledgr_rng_test_seed()
  ledgr:::ledgr_store_append(con, "t", df)
  testthat::expect_identical(ledgr_rng_test_seed(), before)

  rm(".Random.seed", envir = globalenv())
  ledgr:::ledgr_store_append(con, "t", df)
  testthat::expect_false(exists(".Random.seed", envir = globalenv(), inherits = FALSE))

  # Error exit: the append draws its view name, then fails on the missing table.
  set.seed(12L)
  before <- ledgr_rng_test_seed()
  testthat::expect_error(ledgr:::ledgr_store_append(con, "missing_table", df))
  testthat::expect_identical(ledgr_rng_test_seed(), before)
  rm(".Random.seed", envir = globalenv())
  testthat::expect_error(ledgr:::ledgr_store_append(con, "missing_table", df))
  testthat::expect_false(exists(".Random.seed", envir = globalenv(), inherits = FALSE))
  testthat::expect_identical(DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM t")$n, 9)
})

# ---------------------------------------------------------------------------
# Decision (1): kind pinning
# ---------------------------------------------------------------------------

testthat::test_that("seeded folds and simulators do not depend on the caller's kind", {
  ledgr_rng_test_local_restore()
  fx <- ledgr_rng_test_experiment(ledgr_rng_test_ambient_strategy, ids = c("AAA", "BBB", "CCC"), snapshot_id = "rng_kind")
  on.exit(ledgr_snapshot_close(fx$snapshot), add = TRUE)
  fills <- list()
  for (state in c("mt", "lecuyer", "absent_lecuyer")) {
    ledgr_rng_test_set_state(state)
    bt <- suppressWarnings(ledgr_run(fx$exp, params = list(qty = 5), run_id = paste0("kind-", state), seed = 7L))
    fills[[state]] <- ledgr_rng_test_fills(bt)
    close(bt)
  }
  testthat::expect_gt(nrow(fills$mt), 2L)
  testthat::expect_identical(fills$lecuyer, fills$mt)
  testthat::expect_identical(fills$absent_lecuyer, fills$mt)

  sims <- list()
  pits <- list()
  for (state in c("mt", "lecuyer", "absent_lecuyer")) {
    ledgr_rng_test_set_state(state)
    sims[[state]] <- ledgr_sim_bars(n_instruments = 2, n_days = 15, seed = 3L)
    pits[[state]] <- ledgr_sim_pit_inputs(c("A1", "A2", "A3", "A4"), from = "2020-01-01", to = "2020-01-31", seed = 3L)$bars
  }
  testthat::expect_identical(sims$lecuyer, sims$mt)
  testthat::expect_identical(sims$absent_lecuyer, sims$mt)
  testthat::expect_identical(pits$lecuyer, pits$mt)
  testthat::expect_identical(pits$absent_lecuyer, pits$mt)
})

# ledgr-test-profile: review
testthat::test_that("the contract recipe gives identical fills with one and two workers", {
  testthat::skip_if_not_installed("mirai")
  testthat::skip_if_not_installed("withr")
  ledgr_rng_test_local_restore()
  fx <- ledgr_rng_test_experiment(ledgr_rng_test_recipe_strategy, ids = sprintf("S%02d", 1:6), snapshot_id = "rng_recipe")
  on.exit(ledgr_snapshot_close(fx$snapshot), add = TRUE)
  grid <- ledgr_grid_named(a = list(strategy = list(k = 2, qty = 10)), b = list(strategy = list(k = 3, qty = 5)))
  retain <- ledgr_sweep_retention(returns = "completed", trades = "closed")
  w1 <- suppressWarnings(ledgr_sweep(fx$exp, grid, seed = 7L, retain = retain, workers = 1L))
  w2 <- suppressWarnings(ledgr_sweep(fx$exp, grid, seed = 7L, retain = retain, workers = 2L))
  testthat::expect_identical(w1$status, c("DONE", "DONE"))
  testthat::expect_identical(w2$status, w1$status)
  t1 <- as.data.frame(ledgr_sweep_trades(w1))
  t2 <- as.data.frame(ledgr_sweep_trades(w2))
  testthat::expect_gte(nrow(t1), 10L)
  keep <- c("candidate_id", "trade_seq", "close_ts_utc", "realized_pnl", "win_loss")
  testthat::expect_identical(t2[keep], t1[keep])
  testthat::expect_identical(as.data.frame(ledgr_sweep_returns(w2))$equity, as.data.frame(ledgr_sweep_returns(w1))$equity)
  testthat::expect_identical(w2$final_equity, w1$final_equity)

  # The committed run on the same execution seed gives the same trades.
  bt <- suppressWarnings(ledgr_run(fx$exp, params = w1$params[[1L]], run_id = "recipe-run", seed = w1$execution_seed[[1L]]))
  on.exit(close(bt), add = TRUE)
  run_trades <- as.data.frame(ledgr_results(bt, "trades"))
  testthat::expect_identical(run_trades$realized_pnl, t1$realized_pnl[t1$candidate_id == w1$candidate_id[[1L]]])
})

# ---------------------------------------------------------------------------
# Decision (3): RNG-neutral store writes inside a fold
# ---------------------------------------------------------------------------

testthat::test_that("an ambient-RNG strategy gives identical results across store checkpoints and paths", {
  ledgr_rng_test_local_restore()
  fx <- ledgr_rng_test_experiment(ledgr_rng_test_ambient_strategy, ids = sprintf("S%02d", 1:4), snapshot_id = "rng_store")
  on.exit(ledgr_snapshot_close(fx$snapshot), add = TRUE)
  backtest_equity <- function(ck) {
    set.seed(1L, kind = "Mersenne-Twister", normal.kind = "Inversion", sample.kind = "Rejection")
    bt <- suppressWarnings(ledgr_backtest(snapshot = fx$snapshot, strategy = ledgr_rng_test_ambient_strategy,
      strategy_params = list(qty = 10), cost_model = ledgr_cost_zero(), checkpoint_every = ck,
      run_id = paste0("store-ck", ck)))
    on.exit(close(bt))
    list(equity = as.data.frame(ledgr_results(bt, "equity"))$equity, fills = ledgr_rng_test_fills(bt))
  }
  ck_large <- backtest_equity(10000L)
  ck_small <- backtest_equity(3L)
  testthat::expect_gt(nrow(ck_large$fills), 5L)
  testthat::expect_identical(ck_small$equity, ck_large$equity)
  testthat::expect_identical(ck_small$fills, ck_large$fills)

  set.seed(1L, kind = "Mersenne-Twister", normal.kind = "Inversion", sample.kind = "Rejection")
  run <- suppressWarnings(ledgr_run(fx$exp, params = list(qty = 10), run_id = "store-run"))
  run_fills <- ledgr_rng_test_fills(run)
  run_equity <- as.data.frame(ledgr_results(run, "equity"))$equity
  close(run)
  testthat::expect_identical(run_fills, ck_large$fills)

  set.seed(1L, kind = "Mersenne-Twister", normal.kind = "Inversion", sample.kind = "Rejection")
  sw <- suppressWarnings(ledgr_sweep(fx$exp, ledgr_grid_named(a = list(strategy = list(qty = 10))),
    retain = ledgr_sweep_retention(returns = "completed")))
  testthat::expect_identical(as.data.frame(ledgr_sweep_returns(sw))$equity, run_equity)
})

# ledgr-test-profile: review
testthat::test_that("a seeded ambient-RNG fold agrees between ledgr_run and ledgr_sweep past the default checkpoint", {
  ledgr_rng_test_local_restore()
  days <- 10010L
  ts <- as.POSIXct("1990-01-01", tz = "UTC") + 86400 * (seq_len(days) - 1L)
  close <- 100 + 5 * sin(seq_len(days) / 50)
  bars <- data.frame(instrument_id = "L01", ts_utc = ts, open = close, high = close + 1, low = close - 1,
    close = close, volume = 1e5)
  snapshot <- ledgr_snapshot_from_df(bars, db_path = tempfile(fileext = ".duckdb"), snapshot_id = "rng_store_long")
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  exp <- ledgr_experiment(snapshot, ledgr_rng_test_ambient_strategy, opening = ledgr_opening(cash = 1e5),
    cost_model = ledgr_cost_zero())
  sw <- suppressWarnings(ledgr_sweep(exp, ledgr_grid_named(a = list(strategy = list(qty = 10))), seed = 7L,
    retain = ledgr_sweep_retention(returns = "completed")))
  bt <- suppressWarnings(ledgr_run(exp, params = sw$params[[1L]], run_id = "store-long", seed = sw$execution_seed[[1L]]))
  on.exit(close(bt), add = TRUE)
  run_eq <- as.data.frame(ledgr_results(bt, "equity"))$equity
  sweep_eq <- as.data.frame(ledgr_sweep_returns(sw))$equity
  testthat::expect_length(run_eq, days)
  testthat::expect_identical(run_eq, sweep_eq)
})

# ---------------------------------------------------------------------------
# Decisions (4), (5), (14): caller-state witnesses for every W export
# ---------------------------------------------------------------------------

# ledgr-test-profile: review
testthat::test_that("every wrapped export restores the caller's RNG on success", {
  ledgr_rng_test_local_restore()
  draw_strategy <- function(ctx, params) {
    targets <- ctx$flat()
    targets[[1L]] <- floor(stats::runif(1) * 3)
    targets
  }
  fx <- ledgr_rng_test_experiment(draw_strategy, ids = c("AAA", "BBB"), n = 12L, snapshot_id = "rng_w")
  on.exit(ledgr_snapshot_close(fx$snapshot), add = TRUE)
  grid <- ledgr_grid_named(a = list(strategy = list(qty = 1)), b = list(strategy = list(qty = 2)))
  sw <- suppressWarnings(ledgr_sweep(fx$exp, grid, seed = 5L, retain = ledgr_sweep_retention(returns = "completed")))
  n <- 0L
  next_id <- function(prefix) {
    n <<- n + 1L
    sprintf("%s-%03d", prefix, n)
  }

  ledgr_rng_expect_caller_unchanged(function() close(suppressWarnings(ledgr_run(fx$exp, run_id = next_id("w-run")))), "ledgr_run unseeded")
  ledgr_rng_expect_caller_unchanged(function() close(suppressWarnings(ledgr_run(fx$exp, run_id = next_id("w-run"), seed = 3L))), "ledgr_run seeded")
  ledgr_rng_expect_caller_unchanged(function() close(suppressWarnings(ledgr_backtest(snapshot = fx$snapshot, strategy = draw_strategy,
    cost_model = ledgr_cost_zero(), run_id = next_id("w-bt")))), "ledgr_backtest")
  ledgr_rng_expect_caller_unchanged(function() suppressWarnings(ledgr_sweep(fx$exp, grid)), "ledgr_sweep unseeded")
  ledgr_rng_expect_caller_unchanged(function() suppressWarnings(ledgr_sweep(fx$exp, grid, seed = 9L)), "ledgr_sweep seeded")

  # A user subclass whose S3 methods draw after entry.
  as_tibble.rng_iso_draw <- function(x, ...) {
    stats::runif(1)
    NextMethod()
  }
  `$.rng_iso_draw` <- function(x, name) {
    stats::runif(1)
    NextMethod()
  }
  registerS3method("as_tibble", "rng_iso_draw", as_tibble.rng_iso_draw, envir = asNamespace("tibble"))
  registerS3method("$", "rng_iso_draw", `$.rng_iso_draw`)
  drawing_sweep <- structure(sw, class = c("rng_iso_draw", class(sw)))
  ledgr_rng_expect_caller_unchanged(function() ledgr_candidate(drawing_sweep, 1L), "ledgr_candidate.default")
  candidate <- ledgr_candidate(sw, 1L)
  drawing_candidate <- structure(candidate, class = c("rng_iso_draw", class(candidate)))
  ledgr_rng_expect_caller_unchanged(function() ledgr_candidate_reproduction_key(drawing_candidate), "ledgr_candidate_reproduction_key")
  ledgr_rng_expect_caller_unchanged(function() close(suppressWarnings(ledgr_promote(fx$exp, candidate, run_id = next_id("w-promote")))), "ledgr_promote")

  # sample.int is outside the static indicator purity list (decision (11)).
  draw_indicator <- ledgr_indicator(id = "rng_draw_mean", fn = function(window) mean(window$close) + 0 * sample.int(10L, 1L),
    requires_bars = 2L)
  feature_exp <- ledgr_experiment(fx$snapshot, ledgr_rng_test_flat_strategy, features = list(draw_indicator),
    opening = ledgr_opening(cash = 1e5), cost_model = ledgr_cost_zero())
  ledgr_rng_expect_caller_unchanged(function() ledgr_precompute_features(feature_exp, data.frame(qty = 1)), "ledgr_precompute_features")
  ledgr_rng_expect_caller_unchanged(function() close(ledgr_pulse_snapshot(fx$snapshot, universe = c("AAA", "BBB"),
    ts_utc = "2021-01-05T00:00:00Z", features = list(draw_indicator))), "ledgr_pulse_snapshot")

  ledgr_rng_expect_caller_unchanged(function() ledgr_sim_bars(n_instruments = 2, n_days = 10, seed = 4L), "ledgr_sim_bars")
  ledgr_rng_expect_caller_unchanged(function() ledgr_sim_pit_inputs(c("A1", "A2", "A3", "A4"), from = "2020-01-01",
    to = "2020-01-31", seed = 4L), "ledgr_sim_pit_inputs")

  ledgr_rng_expect_caller_unchanged(function() ledgr_sweep_review(sw, rank_by = desc(sharpe_ratio) + 0 * stats::runif(length(sharpe_ratio))),
    "ledgr_sweep_review")
  ledgr_rng_expect_caller_unchanged(function() ledgr_pbo(ledgr_rng_test_panel(), S = 4L,
    metric = function(m) colMeans(m) + 0 * stats::runif(ncol(m))), "ledgr_pbo")
  ledgr_rng_expect_caller_unchanged(function() ledgr_strategy_grid(qty = 1:3, .filter = qty > 1), "ledgr_strategy_grid")
  ledgr_rng_expect_caller_unchanged(function() ledgr_feature_grid(n = 1:3, .filter = n > 1), "ledgr_feature_grid")

  wf <- ledgr_rng_test_walk_forward(draw_strategy)
  on.exit(ledgr_snapshot_close(wf$snapshot), add = TRUE)
  ledgr_rng_expect_caller_unchanged(function() {
    out <- suppressWarnings(ledgr_walk_forward(wf$exp, wf$grid, wf$folds, ledgr_rule_argmax("sharpe_ratio"), seed = 3L))
    lapply(out$test_runs, close)
  }, "ledgr_walk_forward")
  wf_results <- suppressWarnings(ledgr_walk_forward(wf$exp, wf$grid, wf$folds, ledgr_rule_argmax("sharpe_ratio"), seed = 3L))
  lapply(wf_results$test_runs, close)
  drawing_wf <- structure(wf_results, class = c("rng_iso_draw", class(wf_results)))
  ledgr_rng_expect_caller_unchanged(function() ledgr_candidate(drawing_wf, fold_seq = 1L), "ledgr_candidate.ledgr_walk_forward_results")
})

# ledgr-test-profile: review
testthat::test_that("wrapped exports restore the caller's RNG on setup failure and interrupt", {
  ledgr_rng_test_local_restore()
  failing <- function(ctx, params) {
    stats::runif(1)
    rlang::abort("injected strategy failure", class = "ledgr_test_rng_failure")
  }
  interrupting <- function(ctx, params) {
    stats::runif(1)
    rlang::interrupt()
  }
  fx <- ledgr_rng_test_experiment(failing, ids = c("AAA", "BBB"), n = 8L, snapshot_id = "rng_fail")
  on.exit(ledgr_snapshot_close(fx$snapshot), add = TRUE)
  exp_interrupt <- ledgr_experiment(fx$snapshot, interrupting, opening = ledgr_opening(cash = 1e5), cost_model = ledgr_cost_zero())
  n <- 0L
  next_id <- function(prefix) {
    n <<- n + 1L
    sprintf("%s-%03d", prefix, n)
  }
  for (seed in list(NULL, 5L)) {
    label <- if (is.null(seed)) "unseeded" else "seeded"
    ledgr_rng_expect_caller_unchanged(function() ledgr_run(fx$exp, run_id = next_id("fail"), seed = seed),
      paste("ledgr_run failure", label), expect_condition = "error")
    ledgr_rng_expect_caller_unchanged(function() ledgr_run(exp_interrupt, run_id = next_id("intr"), seed = seed),
      paste("ledgr_run interrupt", label), expect_condition = "interrupt")
    ledgr_rng_expect_caller_unchanged(function() ledgr_sweep(fx$exp, ledgr_grid_named(a = list(strategy = list())),
      seed = seed, stop_on_error = TRUE), paste("ledgr_sweep failure", label), expect_condition = "error")
  }
  ledgr_rng_expect_caller_unchanged(function() ledgr_backtest(snapshot = fx$snapshot, strategy = failing,
    cost_model = ledgr_cost_zero(), run_id = next_id("bt-fail")), "ledgr_backtest failure", expect_condition = "error")
  ledgr_rng_expect_caller_unchanged(function() ledgr_sim_bars(n_instruments = 2, n_days = 10, seed = 4L, instrument_prefix = ""),
    "ledgr_sim_bars setup failure", expect_condition = "error")
})

# ledgr-test-profile: review
testthat::test_that("two-worker sweeps restore the caller's RNG after daemon start and stop", {
  testthat::skip_if_not_installed("mirai")
  testthat::skip_if_not_installed("withr")
  ledgr_rng_test_local_restore()
  fx <- ledgr_rng_test_experiment(ledgr_rng_test_recipe_strategy, ids = sprintf("S%02d", 1:4), n = 10L,
    snapshot_id = "rng_workers")
  on.exit(ledgr_snapshot_close(fx$snapshot), add = TRUE)
  grid <- ledgr_grid_named(a = list(strategy = list(k = 1, qty = 1)), b = list(strategy = list(k = 2, qty = 1)))
  ledgr_rng_expect_caller_unchanged(function() suppressWarnings(ledgr_sweep(fx$exp, grid, seed = 7L, workers = 2L)),
    "ledgr_sweep two workers")
  # A worker-side failure with stop_on_error: worker stop runs, then restore.
  failing_grid <- ledgr_grid_named(a = list(strategy = list(k = 99, qty = 1)))
  ledgr_rng_expect_caller_unchanged(function() suppressWarnings(ledgr_sweep(fx$exp, failing_grid, seed = 7L, workers = 2L,
    stop_on_error = TRUE)), "ledgr_sweep two workers failure", states = c("mt", "absent_lecuyer"), expect_condition = "error")
  # A setup failure after daemon start consumed caller RNG: a precomputed
  # payload from another snapshot is refused after the workers are up.
  ind <- ledgr_indicator(id = "rng_setup_mean", fn = function(window) mean(window$close), requires_bars = 2L)
  feature_exp <- ledgr_experiment(fx$snapshot, ledgr_rng_test_recipe_strategy, features = list(ind),
    opening = ledgr_opening(cash = 1e5), cost_model = ledgr_cost_zero())
  other <- ledgr_rng_test_experiment(ledgr_rng_test_recipe_strategy, ids = sprintf("S%02d", 1:4), n = 12L,
    snapshot_id = "rng_workers_other")
  on.exit(ledgr_snapshot_close(other$snapshot), add = TRUE)
  other_exp <- ledgr_experiment(other$snapshot, ledgr_rng_test_recipe_strategy, features = list(ind),
    opening = ledgr_opening(cash = 1e5), cost_model = ledgr_cost_zero())
  foreign <- ledgr_precompute_features(other_exp, grid)
  ledgr_rng_expect_caller_unchanged(function() suppressWarnings(ledgr_sweep(feature_exp, grid, seed = 7L, workers = 2L,
    precomputed_features = foreign)), "ledgr_sweep two workers setup failure", states = c("mt", "absent_lecuyer"),
    expect_condition = "error")
})

# ---------------------------------------------------------------------------
# H representatives (storage-facing exports, store helper only)
# ---------------------------------------------------------------------------

testthat::test_that("storage-facing exports leave the caller's RNG unchanged", {
  ledgr_rng_test_local_restore()
  fx <- ledgr_rng_test_experiment(ledgr_rng_test_flat_strategy, ids = c("AAA", "BBB"), n = 10L, snapshot_id = "rng_h")
  on.exit(ledgr_snapshot_close(fx$snapshot), add = TRUE)
  bt <- ledgr_run(fx$exp, params = list(qty = 2), run_id = "h-run")
  on.exit(close(bt), add = TRUE)
  sw <- ledgr_sweep(fx$exp, ledgr_grid_named(a = list(strategy = list(qty = 1))),
    retain = ledgr_sweep_retention(returns = "completed", trades = "closed"))
  n <- 0L
  # Point-in-time facts make the ingest append nonempty fact frames.
  pit <- ledgr_sim_pit_inputs(c("A1", "A2", "A3", "A4"), from = "2020-01-01", to = "2020-01-31", seed = 4L)
  facts <- ledgr_facts(ledgr_facts_sessions(pit$sessions, venue_id = "DEMO_VENUE", knowledge = "evidenced", timezone = "UTC"))
  ledgr_rng_expect_caller_unchanged(function() {
    n <<- n + 1L
    s <- ledgr_snapshot_from_df(pit$bars, instruments_df = pit$instruments, facts = facts,
      db_path = tempfile(fileext = ".duckdb"), snapshot_id = sprintf("rng_h_%d", n), price_basis = "split_adjusted")
    ledgr_snapshot_close(s)
  }, "ledgr_snapshot_from_df")
  ledgr_rng_expect_caller_unchanged(function() ledgr_results(bt, "fills"), "ledgr_results(bt, 'fills')")
  ledgr_rng_expect_caller_unchanged(function() utils::capture.output(print(bt)), "print(bt)")
  ledgr_rng_expect_caller_unchanged(function() {
    n <<- n + 1L
    ledgr_sweep_save(sw, fx$snapshot, sweep_id = sprintf("rng-h-save-%d", n))
  }, "ledgr_sweep_save")
  ledgr_rng_expect_caller_unchanged(function() {
    opened <- DBI::dbConnect(duckdb::duckdb(), dbdir = fx$db_path)
    on.exit(DBI::dbDisconnect(opened, shutdown = TRUE))
    ledgr_state_reconstruct("h-run", opened)
  }, "ledgr_state_reconstruct")
  ledgr_rng_expect_caller_unchanged(function() ledgr_snapshot_quarantine(fx$snapshot), "ledgr_snapshot_quarantine")
  ledgr_rng_expect_caller_unchanged(function() close(ledgr_indicator_dev(fx$snapshot, "AAA", "2021-01-08T00:00:00Z", lookback = 3)),
    "ledgr_indicator_dev constructor")
})

# ---------------------------------------------------------------------------
# Dynamic routes (review F1) and R helpers
# ---------------------------------------------------------------------------

# ledgr-test-profile: review
testthat::test_that("captured service expressions and returned helpers restore the caller's RNG", {
  testthat::skip_if_not_installed("mirai")
  ledgr_rng_test_local_restore()
  fx <- ledgr_rng_test_experiment(ledgr_rng_test_flat_strategy, ids = c("AAA", "BBB"), n = 10L, snapshot_id = "rng_dyn")
  on.exit(ledgr_snapshot_close(fx$snapshot), add = TRUE)
  sw <- ledgr_sweep(fx$exp, ledgr_grid_named(a = list(strategy = list(qty = 1)), b = list(strategy = list(qty = 2))),
    retain = ledgr_sweep_retention(returns = "completed"))

  ledgr_rng_expect_caller_unchanged(function() ledgr_sweep_review(sw, rank_by = { stats::runif(1); stop("boom") }),
    "rank_by error after a draw", expect_condition = "ledgr_invalid_sweep_review_rank")
  ledgr_rng_expect_caller_unchanged(function() ledgr_sweep_review(sw, rank_by = { stats::runif(1); rlang::interrupt() }),
    "rank_by interrupt after a draw", expect_condition = "interrupt")

  # A rank_by that calls a helper doing a real worker operation and store write.
  helper_db <- tempfile(fileext = ".duckdb")
  helper_fx <- ledgr_rng_test_experiment(ledgr_rng_test_flat_strategy, ids = c("AAA", "BBB"), n = 6L,
    db_path = helper_db, snapshot_id = "rng_dyn_helper")
  on.exit(ledgr_snapshot_close(helper_fx$snapshot), add = TRUE)
  saves <- 0L
  heavy_rank <- function(x) {
    stats::runif(1)
    inner <- suppressWarnings(ledgr_sweep(helper_fx$exp,
      ledgr_grid_named(a = list(strategy = list(qty = 1)), b = list(strategy = list(qty = 2))), workers = 2L))
    saves <<- saves + 1L
    ledgr_sweep_save(inner, helper_fx$snapshot, sweep_id = sprintf("rng-dyn-%d", saves))
    stats::runif(1)
    -x
  }
  ledgr_rng_expect_caller_unchanged(function() ledgr_sweep_review(sw, rank_by = heavy_rank(sharpe_ratio)),
    "rank_by helper with workers and a store write", states = c("mt", "absent_lecuyer"))

  dev <- ledgr_indicator_dev(fx$snapshot, "AAA", "2021-01-08T00:00:00Z", lookback = 3)
  on.exit(close(dev), add = TRUE)
  dates <- c("2021-01-05T00:00:00Z", "2021-01-07T00:00:00Z")
  ledgr_rng_expect_caller_unchanged(function() utils::capture.output(dev$test(function(w) sample.int(100, 1))), "dev$test")
  ledgr_rng_expect_caller_unchanged(function() dev$test_dates(function(w) sample.int(100, 1), dates), "dev$test_dates")
  ledgr_rng_expect_caller_unchanged(function() dev$test(function(w) { sample.int(100, 1); stop("boom") }),
    "dev$test error", expect_condition = "error")
  ledgr_rng_expect_caller_unchanged(function() dev$test_dates(function(w) { sample.int(100, 1); stop("boom") }, dates),
    "dev$test_dates error", expect_condition = "error")
  ledgr_rng_expect_caller_unchanged(function() dev$test(function(w) { sample.int(100, 1); rlang::interrupt() }),
    "dev$test interrupt", expect_condition = "interrupt")
  ledgr_rng_expect_caller_unchanged(function() dev$test_dates(function(w) { sample.int(100, 1); rlang::interrupt() }, dates),
    "dev$test_dates interrupt", expect_condition = "interrupt")

  testthat::expect_error(ledgr_strategy_grid(qty = 1:3, .filter = runif(1) > 0), class = "ledgr_grid_filter_invalid")
})

testthat::test_that("an unseeded run whose strategy draws leaves the caller's RNG unchanged", {
  ledgr_rng_test_local_restore()
  draw_strategy <- function(ctx, params) {
    targets <- ctx$flat()
    targets[[1L]] <- floor(stats::runif(1) * 3)
    targets
  }
  fx <- ledgr_rng_test_experiment(draw_strategy, n = 8L, snapshot_id = "rng_r3")
  on.exit(ledgr_snapshot_close(fx$snapshot), add = TRUE)
  n <- 0L
  ledgr_rng_expect_caller_unchanged(function() {
    n <<- n + 1L
    close(suppressWarnings(ledgr_run(fx$exp, run_id = sprintf("r3-%d", n), seed = NULL)))
  }, "unseeded ledgr_run with a drawing strategy")
})

# ---------------------------------------------------------------------------
# Boundary witnesses (Section 5.1): the caller's own code advances the stream
# ---------------------------------------------------------------------------

testthat::test_that("unwrapped exports evaluate draws in arguments and user methods as the caller's code", {
  ledgr_rng_test_local_restore()
  set.seed(1L)
  invisible(sample.int(100, 1))
  expected <- stats::runif(1)
  set.seed(1L)
  ledgr_utc({ invisible(sample.int(100, 1)); "2020-01-01T00:00:00Z" })
  testthat::expect_identical(stats::runif(1), expected)

  ledgr_metric_context.review_rng <- function(x, ...) {
    sample.int(100, 1)
    ledgr_metric_us_equity()
  }
  registerS3method("ledgr_metric_context", "review_rng", ledgr_metric_context.review_rng, envir = asNamespace("ledgr"))
  set.seed(1L)
  ledgr_metric_context(structure(list(), class = "review_rng"))
  testthat::expect_identical(stats::runif(1), expected)
})

# ---------------------------------------------------------------------------
# Decision (15): argument evaluation
# ---------------------------------------------------------------------------

testthat::test_that("draws in ordinary arguments advance the caller's stream", {
  ledgr_rng_test_local_restore()
  fx <- ledgr_rng_test_experiment(ledgr_rng_test_flat_strategy, n = 8L, snapshot_id = "rng_args")
  on.exit(ledgr_snapshot_close(fx$snapshot), add = TRUE)

  set.seed(1L)
  first <- sample.int(1e6, 1)
  second <- sample.int(1e6, 1)
  after_two <- stats::runif(1)

  set.seed(1L)
  a <- ledgr_run(fx$exp, run_id = "a", seed = sample.int(1e6, 1))
  b <- ledgr_run(fx$exp, run_id = "b", seed = sample.int(1e6, 1))
  testthat::expect_identical(stats::runif(1), after_two)
  testthat::expect_identical(a$config$engine$seed, first)
  testthat::expect_identical(b$config$engine$seed, second)
  testthat::expect_false(identical(a$config$engine$seed, b$config$engine$seed))
  close(a)
  close(b)

  set.seed(1L)
  invisible(stats::runif(1))
  expected <- stats::runif(1)
  set.seed(1L)
  invisible(ledgr_sweep(fx$exp, ledgr_grid_named(a = list(strategy = list(qty = 1))), seed = 7L,
    retain = { stats::runif(1); ledgr_sweep_retention() }))
  testthat::expect_identical(stats::runif(1), expected)

  # Missing arguments and defaults behave as before; an argument error comes
  # before any run row exists.
  plain <- ledgr_run(fx$exp, run_id = "defaults")
  testthat::expect_null(plain$config$engine$seed)
  close(plain)
  testthat::expect_error(ledgr_run(fx$exp, run_id = "never", seed = stop("bad seed")), "bad seed")
  testthat::expect_false("never" %in% ledgr_run_list(fx$snapshot)$run_id)

  # B-1: the indicator-dev helpers force their arguments before saving.
  dev <- ledgr_indicator_dev(fx$snapshot, "AAA", "2021-01-08T00:00:00Z", lookback = 3)
  on.exit(close(dev), add = TRUE)
  pool <- format(as.POSIXct("2021-01-02", tz = "UTC") + 86400 * 0:5, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  set.seed(1L)
  want_1 <- sample(pool, 3)
  want_2 <- sample(pool, 3)
  set.seed(1L)
  got_1 <- dev$test_dates(function(w) mean(w$close), dates = sample(pool, 3))
  got_2 <- dev$test_dates(function(w) mean(w$close), dates = sample(pool, 3))
  testthat::expect_identical(unname(got_1$ts_utc), want_1)
  testthat::expect_identical(unname(got_2$ts_utc), want_2)
})

testthat::test_that("a user S3 method dispatched after entry is restored", {
  ledgr_rng_test_local_restore()
  sw <- ledgr_rng_test_review_sweep()
  as_tibble.review_rng <- function(x, ...) {
    stats::runif(1)
    NextMethod()
  }
  registerS3method("as_tibble", "review_rng", as_tibble.review_rng, envir = asNamespace("tibble"))
  ledgr_rng_expect_caller_unchanged(function() {
    ledgr_sweep_review(structure(sw, class = c("review_rng", class(sw))), rank_by = desc(sharpe_ratio))
  }, "as_tibble method after entry")
})

# ---------------------------------------------------------------------------
# Capture transport (review round 2, N1)
# ---------------------------------------------------------------------------

testthat::test_that("rank_by keeps its behaviour across the wrapper", {
  sw <- ledgr_rng_test_review_sweep()
  review <- ledgr_sweep_review(sw, rank_by = desc(sharpe_ratio))
  testthat::expect_identical(review$ranked$candidate_id, c("high", "mid", "low"))
  testthat::expect_identical(review$rank_by, "desc(sharpe_ratio)")

  local_review <- function(sweep) {
    score <- function(x) -x
    ledgr_sweep_review(sweep, rank_by = score(sharpe_ratio))
  }
  testthat::expect_identical(local_review(sw)$ranked$candidate_id, c("high", "mid", "low"))
  testthat::expect_true("sharpe_ratio" %in% names(local_review(sw)$top))
  testthat::expect_error(ledgr_sweep_review(sw), class = "ledgr_invalid_args")
})

testthat::test_that(".filter keeps its behaviour across the wrapper", {
  feature_grid <- ledgr_feature_grid(n = 1:3, .filter = n > 1)
  strategy_grid <- ledgr_strategy_grid(qty = 1:3, .filter = qty > 1)
  testthat::expect_identical(vapply(feature_grid$params, `[[`, integer(1), "n"), 2:3)
  testthat::expect_identical(vapply(strategy_grid$params, `[[`, integer(1), "qty"), 2:3)
  testthat::expect_identical(vapply(ledgr_feature_grid(n = 1:3)$params, `[[`, integer(1), "n"), 1:3)
  testthat::expect_identical(vapply(ledgr_strategy_grid(qty = 1:3)$params, `[[`, integer(1), "qty"), 1:3)
})

testthat::test_that("the PBO metric label keeps its behaviour across the wrapper", {
  panel <- ledgr_rng_test_panel()
  fun <- function(m) colMeans(m)
  pbo <- ledgr_pbo(panel, S = 4L, metric = fun)
  testthat::expect_identical(tibble::as_tibble(pbo)$metric_name, "fun")
  testthat::expect_identical(tibble::as_tibble(ledgr_pbo(panel, S = 4L))$metric_name, "mean_return")
})

# ---------------------------------------------------------------------------
# Decision (16): callables ledgr builds and itself runs do not restore
# ---------------------------------------------------------------------------

testthat::test_that("signal strategies and adapter indicators draw like the caller's own code", {
  ledgr_rng_test_local_restore()
  strat <- ledgr_signal_strategy(function(ctx) if (stats::runif(1) > 0.5) c(AAA = "LONG") else c(AAA = "FLAT"))
  fx <- ledgr_rng_test_experiment(strat, n = 30L, snapshot_id = "rng_signal")
  on.exit(ledgr_snapshot_close(fx$snapshot), add = TRUE)
  set.seed(42L)
  before <- ledgr_rng_test_seed()
  run_1 <- suppressWarnings(ledgr_run(fx$exp, run_id = "signal-1", seed = 7L))
  testthat::expect_identical(ledgr_rng_test_seed(), before)
  run_2 <- suppressWarnings(ledgr_run(fx$exp, run_id = "signal-2", seed = 7L))
  fills_1 <- ledgr_rng_test_fills(run_1)
  testthat::expect_identical(ledgr_rng_test_fills(run_2), fills_1)
  # The signal varies across pulses: both sides trade more than once.
  testthat::expect_gte(nrow(fills_1), 4L)
  testthat::expect_true(all(c("BUY", "SELL") %in% toupper(fills_1$side)))
  close(run_1)
  close(run_2)

  set.seed(1L)
  invisible(stats::runif(1))
  second <- stats::runif(1)
  set.seed(1L)
  strat(list(universe = "AAA"), list())
  testthat::expect_identical(stats::runif(1), second)

  # sample.int passes the adapter's fingerprint purity check (decision (11)).
  drawing <- function(x) x + sample.int(10L, 1L)
  ind <- ledgr_adapter_r(drawing, id = "rng_adapter", requires_bars = 2)
  set.seed(1L)
  invisible(sample.int(10L, 1L))
  after_draw <- stats::runif(1)
  set.seed(1L)
  ind$fn(data.frame(close = c(1, 2, 3)))
  testthat::expect_identical(stats::runif(1), after_draw)
})

# ---------------------------------------------------------------------------
# Decisions (5) and (12): the documented Box-Muller limitation
# ---------------------------------------------------------------------------

testthat::test_that("a pending Box-Muller normal is not preserved, while kind and seed are", {
  ledgr_rng_test_local_restore()
  set.seed(123L, kind = "Mersenne-Twister", normal.kind = "Box-Muller", sample.kind = "Rejection")
  invisible(stats::rnorm(1))
  kind <- RNGkind()
  seed <- ledgr_rng_test_seed()
  untouched_next <- stats::rnorm(1)

  set.seed(123L, kind = "Mersenne-Twister", normal.kind = "Box-Muller", sample.kind = "Rejection")
  invisible(stats::rnorm(1))
  invisible(ledgr_sim_bars(n_instruments = 1, n_days = 5, seed = 1L))
  testthat::expect_identical(RNGkind(), kind)
  testthat::expect_identical(ledgr_rng_test_seed(), seed)
  testthat::expect_false(identical(stats::rnorm(1), untouched_next))
})

# ---------------------------------------------------------------------------
# Decision (6): walk-forward without a seed
# ---------------------------------------------------------------------------

testthat::test_that("ledgr_walk_forward runs without a seed", {
  ledgr_rng_test_local_restore()
  draw_strategy <- function(ctx, params) {
    targets <- ctx$flat()
    targets[[1L]] <- params$qty + floor(stats::runif(1) * 2)
    targets
  }
  wf <- ledgr_rng_test_walk_forward(draw_strategy)
  on.exit(ledgr_snapshot_close(wf$snapshot), add = TRUE)
  set.seed(3L)
  before <- ledgr_rng_test_seed()
  out <- suppressWarnings(ledgr_walk_forward(wf$exp, wf$grid, wf$folds, ledgr_rule_argmax("sharpe_ratio")))
  on.exit(lapply(out$test_runs, close), add = TRUE)
  testthat::expect_identical(ledgr_rng_test_seed(), before)
  testthat::expect_identical(out$status, "DONE")
  testthat::expect_length(out$test_runs, 2L)
  testthat::expect_true(all(is.na(out$scores$execution_seed)))
  for (test_run in out$test_runs) {
    testthat::expect_null(test_run$config$engine$seed)
  }
})

# ---------------------------------------------------------------------------
# Section 5.3: runtime tracer of the outermost ledgr frame
# ---------------------------------------------------------------------------

# ledgr-test-profile: review
testthat::test_that("rng-relevant sites run only under a wrapped export or a returned helper", {
  ledgr_rng_test_local_restore()
  fx <- ledgr_rng_test_experiment(ledgr_rng_test_flat_strategy, ids = c("AAA", "BBB"), n = 10L, snapshot_id = "rng_trace")
  on.exit(ledgr_snapshot_close(fx$snapshot), add = TRUE)
  ind <- ledgr_indicator(id = "rng_trace_mean", fn = function(window) mean(window$close), requires_bars = 2L)
  feature_exp <- ledgr_experiment(fx$snapshot, ledgr_rng_test_flat_strategy, features = list(ind),
    opening = ledgr_opening(cash = 1e5), cost_model = ledgr_cost_zero())
  wf <- ledgr_rng_test_walk_forward()
  on.exit(ledgr_snapshot_close(wf$snapshot), add = TRUE)
  observed <- ledgr_rng_with_tracer({
    close(ledgr_run(feature_exp, params = list(qty = 1), run_id = "trace-run", seed = 3L))
    sw <- ledgr_sweep(feature_exp, ledgr_grid_named(a = list(strategy = list(qty = 1))), seed = 3L,
      retain = ledgr_sweep_retention(returns = "completed"))
    close(ledgr_promote(feature_exp, ledgr_candidate(sw, 1L), run_id = "trace-promote"))
    close(ledgr_backtest(snapshot = fx$snapshot, strategy = ledgr_rng_test_flat_strategy, features = list(ind),
      cost_model = ledgr_cost_zero(), run_id = "trace-bt"))
    ledgr_precompute_features(feature_exp, data.frame(qty = 1))
    close(ledgr_pulse_snapshot(fx$snapshot, universe = c("AAA", "BBB"), ts_utc = "2021-01-05T00:00:00Z", features = list(ind)))
    ledgr_sim_bars(n_instruments = 1, n_days = 5, seed = 1L)
    ledgr_sweep_review(sw, rank_by = desc(sharpe_ratio))
    ledgr_pbo(ledgr_rng_test_panel(), S = 4L)
    ledgr_strategy_grid(qty = 1:3, .filter = qty > 1)
    out <- ledgr_walk_forward(wf$exp, wf$grid, wf$folds, ledgr_rule_argmax("sharpe_ratio"), seed = 2L)
    lapply(out$test_runs, close)
    dev <- ledgr_indicator_dev(fx$snapshot, "AAA", "2021-01-08T00:00:00Z", lookback = 3)
    dev$test_dates(function(w) mean(w$close), "2021-01-06T00:00:00Z")
    close(dev)
  })
  testthat::expect_true(all(c("ledgr_fold_envelope", "ledgr_rng_seed_pinned", "ledgr_call_feature_fn",
    "ledgr_sweep_review_rank", "ledgr_pbo_eval_metric", "ledgr_eval_grid_filter") %in% observed$site))
  testthat::expect_true(all(observed$ok), info = paste(capture.output(print(observed[!observed$ok, ])), collapse = "\n"))

  # Negative control: an internal entry reached directly is reported.
  direct <- ledgr_rng_with_tracer(
    ledgr:::ledgr_sweep_impl(feature_exp, ledgr_grid_named(a = list(strategy = list(qty = 1))), seed = 3L)
  )
  testthat::expect_true(any(!direct$ok))
})
