pfb_memory_peak_mb <- function() sum(gc()[, 6L])

pfb_benchmark_serial <- function(case, spike_root, repeats) {
  generation_start <- proc.time()[[3L]]
  market <- pfb_generate_market(case$n_sessions, case$n_instruments, seed = case$seed)
  params <- pfb_make_params(
    case$n_configs, case$family, case$feature_mode, case$fee_rate
  )
  generation_sec <- proc.time()[[3L]] - generation_start
  prepare_start <- proc.time()[[3L]]
  prepared <- pfb_prepare(market, params)
  preparation_sec <- proc.time()[[3L]] - prepare_start
  variants <- list(
    strategy_first = function() pfb_run_strategy_first(prepared, params),
    pulse_first_naive = function() pfb_run_pulse_first(prepared, params, share_pulse = FALSE),
    pulse_first_shared = function() pfb_run_pulse_first(prepared, params, share_pulse = TRUE)
  )
  rows <- list()
  semantic <- NULL
  for (variant in names(variants)) {
    for (repeat_id in seq_len(repeats)) {
      gc(full = TRUE, reset = TRUE)
      started <- proc.time()[[3L]]
      out <- variants[[variant]]()
      elapsed <- proc.time()[[3L]] - started
      peak_mb <- pfb_memory_peak_mb()
      if (is.null(semantic)) semantic <- out$results
      stopifnot(pfb_results_identical(semantic, out$results))
      rows[[length(rows) + 1L]] <- data.frame(
        case_id = case$case_id, family = case$family,
        feature_mode = case$feature_mode, n_sessions = case$n_sessions,
        n_instruments = case$n_instruments, n_configs = case$n_configs,
        variant = variant, repeat_id = repeat_id,
        generation_sec = generation_sec, preparation_sec = preparation_sec,
        evaluation_sec = elapsed, r_heap_peak_mb = peak_mb,
        candidate_initialization_sec = out$initialization_sec,
        pulse_loop_sec = out$pulse_loop_sec,
        result_collection_sec = out$result_collection_sec,
        state_bytes = out$state_bytes,
        output_bytes = as.numeric(object.size(out$results)),
        market_preparations = unname(out$counters[["market_preparations"]]),
        feature_extractions = unname(out$counters[["feature_extractions"]]),
        context_builds = unname(out$counters[["context_builds"]]),
        stringsAsFactors = FALSE
      )
    }
  }
  do.call(rbind, rows)
}

pfb_benchmark_parallel <- function(case, spike_root) {
  market <- pfb_generate_market(case$n_sessions, case$n_instruments, seed = case$seed)
  params <- pfb_make_params(
    case$n_configs, case$family, case$feature_mode, case$fee_rate
  )
  prepared <- pfb_prepare(market, params)
  expected <- pfb_run_pulse_first(prepared, params, share_pulse = TRUE)$results
  rows <- list()
  for (workers in case$workers) {
    for (batch_size in case$batch_sizes) {
      out <- pfb_run_parallel(
        prepared, params, workers, batch_size, spike_root,
        loop = "pulse_first"
      )
      stopifnot(pfb_results_identical(expected, out$results))
      rows[[length(rows) + 1L]] <- data.frame(
        case_id = case$case_id, n_sessions = case$n_sessions,
        n_instruments = case$n_instruments, n_configs = case$n_configs,
        family = case$family, feature_mode = case$feature_mode,
        workers = workers, batch_size = as.character(batch_size),
        n_batches = out$n_batches, elapsed_sec = out$elapsed_sec,
        worker_init_sec = out$worker_init_sec,
        dispatch_sec = out$dispatch_sec,
        collect_sec = out$collect_sec,
        merge_sec = out$merge_sec,
        worker_max_sec = out$worker_max_sec,
        worker_peak_r_heap_mb = out$worker_peak_r_heap_mb %||% NA_real_,
        peak_total_rss_bytes = out$peak_total_rss_bytes %||% NA_real_,
        peak_child_rss_bytes = out$peak_child_rss_bytes %||% NA_real_,
        staged_bytes = out$staged_bytes,
        serialized_staged_bytes = out$serialized_staged_bytes,
        output_bytes = as.numeric(object.size(out$results)),
        stringsAsFactors = FALSE
      )
    }
  }
  do.call(rbind, rows)
}

pfb_market_to_bars <- function(market) {
  n_sessions <- nrow(market$close)
  n_instruments <- ncol(market$close)
  sessions <- as.POSIXct("2010-01-01", tz = "UTC") + 86400 * (seq_len(n_sessions) - 1L)
  data.frame(
    ts_utc = rep(sessions, times = n_instruments),
    instrument_id = rep(market$instrument_ids, each = n_sessions),
    open = as.vector(market$open),
    high = as.vector(pmax(market$open, market$close) * 1.001),
    low = as.vector(pmin(market$open, market$close) * 0.999),
    close = as.vector(market$close),
    volume = 100000,
    stringsAsFactors = FALSE
  )
}

pfb_ledgr_contextual_baseline <- function(case, repo_root, profile_output = NULL) {
  pkgload::load_all(repo_root, quiet = TRUE, compile = FALSE)
  market <- pfb_generate_market(case$n_sessions, case$n_instruments, case$seed)
  bars <- pfb_market_to_bars(market)
  cold_start <- proc.time()[[3L]]
  snapshot <- ledgr_snapshot_from_df(bars)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  cold_prepare_sec <- proc.time()[[3L]] - cold_start
  strategy <- function(ctx, params) {
    stats::setNames(rep(params$qty, length(ctx$universe)), ctx$universe)
  }
  exp <- ledgr_experiment(
    snapshot, strategy, opening = ledgr_opening(cash = 1e6),
    cost_model = ledgr_cost_zero()
  )
  specs <- stats::setNames(lapply(seq_len(case$n_configs), function(i) {
    list(strategy = list(qty = (i - 1L) %% 3L))
  }), sprintf("candidate_%04d", seq_len(case$n_configs)))
  grid <- do.call(ledgr_grid_named, specs)
  gc(full = TRUE, reset = TRUE)
  if (!is.null(profile_output)) Rprof(profile_output, interval = 0.001)
  started <- proc.time()[[3L]]
  result <- suppressWarnings(
    ledgr_sweep(exp, grid, seed = 41L, workers = case$workers)
  )
  warm_sec <- proc.time()[[3L]] - started
  if (!is.null(profile_output)) Rprof(NULL)
  data.frame(
    case_id = case$case_id, n_sessions = case$n_sessions,
    n_instruments = case$n_instruments, n_configs = case$n_configs,
    workers = case$workers, snapshot_prepare_sec = cold_prepare_sec,
    warm_sweep_sec = warm_sec,
    candidate_engine_sum_sec = sum(result$t_engine),
    candidate_results_sum_sec = sum(result$t_results),
    serial_residual_sec = if (case$workers == 1L) {
      warm_sec - sum(result$t_engine) - sum(result$t_results)
    } else {
      NA_real_
    },
    r_heap_peak_mb = pfb_memory_peak_mb(),
    output_bytes = as.numeric(object.size(result)),
    completed = sum(result$status == "DONE"), stringsAsFactors = FALSE
  )
}

pfb_profile <- function(fn, output) {
  file <- tempfile(fileext = ".out")
  Rprof(file, interval = 0.001)
  on.exit(Rprof(NULL), add = TRUE)
  fn()
  Rprof(NULL)
  profile <- summaryRprof(file)$by.self
  if (is.null(profile) || nrow(profile) == 0L) return(invisible(NULL))
  profile$function_name <- rownames(profile)
  rownames(profile) <- NULL
  utils::write.csv(profile, output, row.names = FALSE)
  invisible(profile)
}

`%||%` <- function(x, y) if (is.null(x)) y else x
