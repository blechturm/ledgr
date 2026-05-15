#!/usr/bin/env Rscript

`%||%` <- function(x, y) if (is.null(x)) y else x

file_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
script_path <- if (length(file_arg)) sub("^--file=", "", file_arg[[1]]) else ""
script_dir <- if (nzchar(script_path)) dirname(normalizePath(script_path, mustWork = TRUE)) else getwd()
root_candidate <- normalizePath(file.path(script_dir, "..", "..", ".."), mustWork = FALSE)
root <- if (file.exists(file.path(root_candidate, "DESCRIPTION"))) {
  root_candidate
} else {
  normalizePath(getwd(), mustWork = TRUE)
}
setwd(root)

if (requireNamespace("pkgload", quietly = TRUE)) {
  pkgload::load_all(".", quiet = TRUE)
} else {
  stop("Package 'pkgload' is required to run this benchmark from source.", call. = FALSE)
}

benchmark_timer <- function(expr) {
  gc(verbose = FALSE)
  start <- proc.time()[["elapsed"]]
  value <- suppressWarnings(force(expr))
  elapsed <- proc.time()[["elapsed"]] - start
  list(value = value, elapsed = as.numeric(elapsed))
}

make_grid <- function(n_candidates) {
  entries <- vector("list", n_candidates)
  names(entries) <- sprintf("candidate_%03d", seq_len(n_candidates))
  lookbacks <- rep(c(5L, 10L, 20L, 40L, 80L), length.out = n_candidates)
  for (i in seq_len(n_candidates)) {
    entries[[i]] <- list(
      lookback = lookbacks[[i]],
      threshold = 0.0005 + (i %% 5L) * 0.00025,
      qty = 1 + (i %% 3L)
    )
  }
  do.call(ledgr_param_grid, entries)
}

make_experiment <- function(n_instruments, n_days, temp_dir) {
  bars <- ledgr_sim_bars(
    n_instruments = n_instruments,
    n_days = n_days,
    seed = 2108L,
    instrument_prefix = "BENCH_"
  )
  db_path <- file.path(temp_dir, "benchmark.duckdb")
  snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path)

  features <- function(params) {
    list(ledgr_ind_returns(params$lookback))
  }

  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    feature_id <- sprintf("return_%d", params$lookback)
    for (instrument_id in names(targets)) {
      value <- ctx$feature(instrument_id, feature_id)
      targets[[instrument_id]] <- if (is.finite(value) && value > params$threshold) params$qty else 0
    }
    targets
  }

  exp <- ledgr_experiment(
    snapshot = snapshot,
    strategy = strategy,
    features = features,
    opening = ledgr_opening(cash = 100000)
  )

  list(snapshot = snapshot, exp = exp, bars = bars)
}

run_loop_baseline <- function(exp, grid, seed) {
  out <- vector("list", length(grid$params))
  for (i in seq_along(grid$params)) {
    bt <- ledgr_run(
      exp,
      params = grid$params[[i]],
      run_id = paste0("baseline_", grid$labels[[i]]),
      seed = seed
    )
    out[[i]] <- bt$run_id
    close(bt)
  }
  invisible(out)
}

run_scenario <- function(name, n_candidates, n_instruments, n_days) {
  temp_dir <- tempfile("ledgr-sweep-benchmark-")
  dir.create(temp_dir, recursive = TRUE)
  on.exit(unlink(temp_dir, recursive = TRUE, force = TRUE), add = TRUE)

  fixture <- make_experiment(n_instruments, n_days, temp_dir)
  on.exit(ledgr_snapshot_close(fixture$snapshot), add = TRUE)

  grid <- make_grid(n_candidates)
  seed <- 2108L

  warmup <- ledgr_sweep(fixture$exp, ledgr_param_grid(warmup = grid$params[[1]]), seed = seed)
  stopifnot(identical(warmup$status[[1]], "DONE"))

  sweep_plain <- benchmark_timer(ledgr_sweep(fixture$exp, grid, seed = seed))
  stopifnot(all(sweep_plain$value$status == "DONE"))

  precompute <- benchmark_timer(ledgr_precompute_features(fixture$exp, grid))
  sweep_precomputed <- benchmark_timer(ledgr_sweep(
    fixture$exp,
    grid,
    precomputed_features = precompute$value,
    seed = seed
  ))
  stopifnot(all(sweep_precomputed$value$status == "DONE"))

  run_loop <- benchmark_timer(run_loop_baseline(fixture$exp, grid, seed = seed))

  data.frame(
    scenario = name,
    n_candidates = n_candidates,
    n_instruments = n_instruments,
    n_days = n_days,
    n_bars = nrow(fixture$bars),
    sweep_plain_sec = sweep_plain$elapsed,
    precompute_sec = precompute$elapsed,
    sweep_precomputed_sec = sweep_precomputed$elapsed,
    sweep_precomputed_total_sec = precompute$elapsed + sweep_precomputed$elapsed,
    run_loop_sec = run_loop$elapsed,
    sweep_plain_candidates_per_sec = n_candidates / sweep_plain$elapsed,
    sweep_precomputed_candidates_per_sec = n_candidates / sweep_precomputed$elapsed,
    run_loop_candidates_per_sec = n_candidates / run_loop$elapsed,
    sweep_plain_speedup_vs_run_loop = run_loop$elapsed / sweep_plain$elapsed,
    sweep_precomputed_speedup_vs_run_loop = run_loop$elapsed / sweep_precomputed$elapsed,
    precomputed_total_speedup_vs_run_loop = run_loop$elapsed / (precompute$elapsed + sweep_precomputed$elapsed),
    stringsAsFactors = FALSE
  )
}

main <- function() {
  scenarios <- list(
    list(name = "small_5_candidates", n_candidates = 5L, n_instruments = 4L, n_days = 252L),
    list(name = "local_50_candidates", n_candidates = 50L, n_instruments = 4L, n_days = 252L)
  )

  results <- do.call(rbind, lapply(scenarios, function(x) {
    message("Running ", x$name, "...")
    run_scenario(x$name, x$n_candidates, x$n_instruments, x$n_days)
  }))

  print(results, row.names = FALSE)
  invisible(results)
}

if (identical(environment(), globalenv())) {
  main()
}
