#!/usr/bin/env Rscript

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

bench_env <- new.env(parent = globalenv())
sys.source(file.path("dev", "spikes", "ledgr_sweep_performance", "run_benchmark.R"), envir = bench_env)

ns <- asNamespace("ledgr")

elapsed_time <- function(expr) {
  gc(verbose = FALSE)
  start <- proc.time()[["elapsed"]]
  value <- suppressWarnings(force(expr))
  elapsed <- proc.time()[["elapsed"]] - start
  list(value = value, elapsed = as.numeric(elapsed))
}

wrap_namespace_functions <- function(names) {
  timings <- new.env(parent = emptyenv())
  originals <- list()

  for (name in names) {
    timings[[name]] <- list(calls = 0L, elapsed = 0)
    originals[[name]] <- get(name, envir = ns, inherits = FALSE)
    replacement <- local({
      fn_name <- name
      original <- originals[[name]]
      function(...) {
        start <- proc.time()[["elapsed"]]
        on.exit({
          timing <- timings[[fn_name]]
          timing$calls <- timing$calls + 1L
          timing$elapsed <- timing$elapsed + as.numeric(proc.time()[["elapsed"]] - start)
          timings[[fn_name]] <- timing
        }, add = TRUE)
        original(...)
      }
    })
    unlockBinding(name, ns)
    assign(name, replacement, envir = ns)
    lockBinding(name, ns)
  }

  restore <- function() {
    for (name in names) {
      unlockBinding(name, ns)
      assign(name, originals[[name]], envir = ns)
      lockBinding(name, ns)
    }
    invisible(TRUE)
  }

  list(
    timings = timings,
    restore = restore
  )
}

timing_table <- function(timings, total_elapsed) {
  names <- sort(ls(timings, all.names = TRUE))
  rows <- lapply(names, function(name) {
    x <- timings[[name]]
    data.frame(
      phase = name,
      calls = x$calls,
      elapsed_sec = x$elapsed,
      pct_total = if (total_elapsed > 0) 100 * x$elapsed / total_elapsed else NA_real_,
      avg_ms = if (x$calls > 0L) 1000 * x$elapsed / x$calls else NA_real_,
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  out[order(out$elapsed_sec, decreasing = TRUE), , drop = FALSE]
}

profile_sweep <- function(exp, grid, precomputed_features = NULL, seed = 2108L) {
  profile_file <- tempfile("ledgr-rprof-", fileext = ".out")
  on.exit(unlink(profile_file, force = TRUE), add = TRUE)

  Rprof(profile_file, interval = 0.01)
  on.exit(Rprof(NULL), add = TRUE)
  suppressWarnings(ledgr_sweep(exp, grid, precomputed_features = precomputed_features, seed = seed))
  Rprof(NULL)

  summary <- summaryRprof(profile_file)
  list(
    by_total = utils::head(summary$by.total, 20L),
    by_self = utils::head(summary$by.self, 20L),
    sample_interval = summary$sample.interval,
    sampling_time = summary$sampling.time
  )
}

mean_elapsed <- function(n, expr) {
  times <- numeric(n)
  for (i in seq_len(n)) {
    times[[i]] <- elapsed_time(expr)$elapsed
  }
  data.frame(
    reps = n,
    mean_sec = mean(times),
    median_sec = stats::median(times),
    min_sec = min(times),
    max_sec = max(times),
    stringsAsFactors = FALSE
  )
}

micro_timings <- function(fixture, grid) {
  meta <- ledgr:::ledgr_precompute_snapshot_meta(fixture$exp$snapshot)
  range <- ledgr:::ledgr_precompute_scoring_range(meta)
  bars_by_id <- ledgr:::ledgr_precompute_fetch_bars(
    fixture$exp$snapshot,
    fixture$exp$universe,
    range$warmup_start,
    range$scoring_end
  )
  bars_by_id <- ledgr:::ledgr_sweep_normalize_bars_by_id(bars_by_id, fixture$exp$universe)
  bars_mat <- ledgr:::ledgr_sweep_bars_matrix(bars_by_id, fixture$exp$universe)
  resolved <- ledgr:::ledgr_resolve_feature_candidates(fixture$exp, grid, stop_on_error = FALSE)
  candidate <- resolved$candidates[[1L]]
  run_feature_matrix <- ledgr:::ledgr_sweep_compute_feature_matrix(candidate$feature_defs, bars_by_id, fixture$exp$universe)
  precomputed <- ledgr_precompute_features(fixture$exp, grid)
  feature_fingerprints <- resolved$candidate_features$feature_fingerprints[[1L]]
  pulse_idx <- 100L
  instrument_ids <- fixture$exp$universe
  def_ids <- vapply(candidate$feature_defs, function(def) def$id, character(1))
  bars_current <- data.frame(
    instrument_id = instrument_ids,
    ts_utc = as.POSIXct(bars_by_id[[instrument_ids[[1L]]]]$ts_utc[[pulse_idx]], tz = "UTC"),
    open = bars_mat$open[, pulse_idx],
    high = bars_mat$high[, pulse_idx],
    low = bars_mat$low[, pulse_idx],
    close = bars_mat$close[, pulse_idx],
    volume = bars_mat$volume[, pulse_idx],
    gap_type = bars_mat$gap_type[, pulse_idx],
    is_synthetic = bars_mat$is_synthetic[, pulse_idx],
    stringsAsFactors = FALSE
  )
  features_current <- data.frame(
    instrument_id = rep(instrument_ids, times = length(def_ids)),
    ts_utc = as.POSIXct(bars_by_id[[instrument_ids[[1L]]]]$ts_utc[[pulse_idx]], tz = "UTC"),
    feature_name = rep(def_ids, each = length(instrument_ids)),
    feature_value = unlist(lapply(def_ids, function(def_id) run_feature_matrix[[def_id]][, pulse_idx]), use.names = FALSE),
    stringsAsFactors = FALSE
  )
  positions <- stats::setNames(rep(0, length(instrument_ids)), instrument_ids)
  ctx <- list(
    run_id = "micro",
    ts_utc = ledgr:::ledgr_normalize_ts_utc(bars_current$ts_utc[[1L]]),
    universe = instrument_ids,
    bars = bars_current,
    feature_table = features_current,
    positions = positions,
    cash = 100000,
    equity = 100000,
    seed = 2108L,
    state_prev = NULL,
    safety_state = "GREEN"
  )
  class(ctx) <- "ledgr_pulse_context"
  targets <- stats::setNames(rep(1, length(instrument_ids)), instrument_ids)

  rows <- list(
    bars_matrix = cbind(
      operation = "ledgr_sweep_bars_matrix",
      mean_elapsed(10L, ledgr:::ledgr_sweep_bars_matrix(bars_by_id, fixture$exp$universe))
    ),
    feature_matrix_compute = cbind(
      operation = "ledgr_sweep_compute_feature_matrix",
      mean_elapsed(10L, ledgr:::ledgr_sweep_compute_feature_matrix(candidate$feature_defs, bars_by_id, fixture$exp$universe))
    ),
    feature_matrix_from_precomputed = cbind(
      operation = "ledgr_sweep_feature_matrix_from_precomputed",
      mean_elapsed(10L, ledgr:::ledgr_sweep_feature_matrix_from_precomputed(precomputed, feature_fingerprints, bars_by_id, fixture$exp$universe))
    ),
    features_wide = cbind(
      operation = "ledgr_features_wide",
      mean_elapsed(1000L, ledgr:::ledgr_features_wide(features_current))
    ),
    context_helpers = cbind(
      operation = "ledgr_update_pulse_context_helpers",
      mean_elapsed(1000L, ledgr:::ledgr_update_pulse_context_helpers(ctx, bars_current, features_current, positions, instrument_ids))
    ),
    target_validation = cbind(
      operation = "ledgr_validate_strategy_targets",
      mean_elapsed(1000L, ledgr:::ledgr_validate_strategy_targets(targets, instrument_ids))
    )
  )
  do.call(rbind, rows)
}

main <- function() {
  temp_dir <- tempfile("ledgr-sweep-profile-")
  dir.create(temp_dir, recursive = TRUE)
  on.exit(unlink(temp_dir, recursive = TRUE, force = TRUE), add = TRUE)

  fixture <- bench_env$make_experiment(n_instruments = 4L, n_days = 252L, temp_dir = temp_dir)
  on.exit(ledgr_snapshot_close(fixture$snapshot), add = TRUE)
  grid <- bench_env$make_grid(50L)

  wrapped_names <- c(
    "ledgr_precompute_snapshot_meta",
    "ledgr_precompute_fetch_bars",
    "ledgr_sweep_normalize_bars_by_id",
    "ledgr_precompute_validate_static_coverage",
    "ledgr_sweep_bars_matrix",
    "ledgr_resolve_feature_candidates",
    "ledgr_sweep_run_candidate",
    "ledgr_sweep_compute_feature_matrix",
    "ledgr_sweep_feature_matrix_from_precomputed",
    "ledgr_execute_fold",
    "ledgr_equity_from_events",
    "ledgr_fills_from_events",
    "ledgr_metrics_from_equity_fills"
  )

  wrappers <- wrap_namespace_functions(wrapped_names)
  on.exit(wrappers$restore(), add = TRUE)
  plain <- elapsed_time(ledgr_sweep(fixture$exp, grid, seed = 2108L))
  plain_timings <- timing_table(wrappers$timings, plain$elapsed)
  wrappers$restore()

  precomputed <- ledgr_precompute_features(fixture$exp, grid)
  wrappers <- wrap_namespace_functions(wrapped_names)
  on.exit(wrappers$restore(), add = TRUE)
  pre <- elapsed_time(ledgr_sweep(fixture$exp, grid, precomputed_features = precomputed, seed = 2108L))
  pre_timings <- timing_table(wrappers$timings, pre$elapsed)
  wrappers$restore()

  rprof_plain <- profile_sweep(fixture$exp, grid, seed = 2108L)
  rprof_precomputed <- profile_sweep(fixture$exp, grid, precomputed_features = precomputed, seed = 2108L)
  micro <- micro_timings(fixture, grid)

  cat("\nPLAIN SWEEP ELAPSED\n")
  print(plain$elapsed)
  cat("\nPLAIN PHASE TIMINGS\n")
  print(plain_timings, row.names = FALSE)
  cat("\nPRECOMPUTED SWEEP ELAPSED\n")
  print(pre$elapsed)
  cat("\nPRECOMPUTED PHASE TIMINGS\n")
  print(pre_timings, row.names = FALSE)
  cat("\nRPROF PLAIN BY TOTAL\n")
  print(rprof_plain$by_total)
  cat("\nRPROF PLAIN BY SELF\n")
  print(rprof_plain$by_self)
  cat("\nRPROF PRECOMPUTED BY TOTAL\n")
  print(rprof_precomputed$by_total)
  cat("\nRPROF PRECOMPUTED BY SELF\n")
  print(rprof_precomputed$by_self)
  cat("\nMICRO TIMINGS\n")
  print(micro, row.names = FALSE)

  invisible(list(
    plain_elapsed = plain$elapsed,
    plain_timings = plain_timings,
    precomputed_elapsed = pre$elapsed,
    precomputed_timings = pre_timings,
    rprof_plain = rprof_plain,
    rprof_precomputed = rprof_precomputed,
    micro = micro
  ))
}

if (identical(environment(), globalenv())) {
  main()
}
