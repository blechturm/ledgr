# fold_loop_diagnostic.R
#
# Current-source fold-loop bucket diagnostic for v0.1.8.8 / LDG-2470.
# This is a local development harness, not a public benchmark dashboard.
#
# Usage:
#   Rscript dev/bench/fold_loop_diagnostic.R --preset smoke --repeats 1
#   Rscript dev/bench/fold_loop_diagnostic.R --preset record --repeats 1 \
#     --scenarios peer_sma_crossover,wide_panel_no_features

`%||%` <- function(x, y) if (is.null(x)) y else x

diag_parse_args <- function(args = commandArgs(trailingOnly = TRUE)) {
  out <- list(
    preset = "smoke",
    out_dir = file.path("dev", "bench", "results"),
    packet_dir = file.path("inst", "design", "ledgr_v0_1_8_8_spec_packet"),
    repeats = 1L,
    scenarios = NULL,
    seed = 20260530L,
    telemetry_stride = 1L
  )
  i <- 1L
  while (i <= length(args)) {
    key <- args[[i]]
    val <- if (i < length(args)) args[[i + 1L]] else NA_character_
    if (identical(key, "--preset")) {
      out$preset <- val
      i <- i + 2L
    } else if (identical(key, "--out-dir")) {
      out$out_dir <- val
      i <- i + 2L
    } else if (identical(key, "--packet-dir")) {
      out$packet_dir <- val
      i <- i + 2L
    } else if (identical(key, "--repeats")) {
      out$repeats <- as.integer(val)
      i <- i + 2L
    } else if (identical(key, "--scenarios")) {
      out$scenarios <- strsplit(val, ",", fixed = TRUE)[[1L]]
      i <- i + 2L
    } else if (identical(key, "--seed")) {
      out$seed <- as.integer(val)
      i <- i + 2L
    } else if (identical(key, "--telemetry-stride")) {
      out$telemetry_stride <- as.integer(val)
      i <- i + 2L
    } else if (key %in% c("--help", "-h")) {
      cat(paste(
        "Usage: Rscript dev/bench/fold_loop_diagnostic.R [options]",
        "",
        "Options:",
        "  --preset smoke|record",
        "  --out-dir PATH",
        "  --packet-dir PATH",
        "  --repeats N",
        "  --scenarios comma,separated,names",
        "  --seed N",
        "  --telemetry-stride N",
        sep = "\n"
      ), "\n")
      quit(status = 0L)
    } else {
      stop("Unknown argument: ", key, call. = FALSE)
    }
  }
  if (!out$preset %in% c("smoke", "record")) {
    stop("`--preset` must be `smoke` or `record`.", call. = FALSE)
  }
  if (!is.finite(out$repeats) || out$repeats < 1L) {
    stop("`--repeats` must be a positive integer.", call. = FALSE)
  }
  if (!is.finite(out$telemetry_stride) || out$telemetry_stride < 1L) {
    stop("`--telemetry-stride` must be a positive integer.", call. = FALSE)
  }
  out
}

diag_source_benchmark_helpers <- function() {
  source(file.path("dev", "bench", "run_benchmarks.R"), local = globalenv())
  bench_load_ledgr_source()
}

diag_specs <- function(preset) {
  specs <- bench_specs(preset)
  specs[c("peer_sma_crossover", "wide_panel_no_features")]
}

diag_make_strategy <- function(name, spec) {
  sma <- identical(spec$strategy_kind, "sma_crossover")
  if (sma) {
    bench_sma_crossover_strategy(spec$trade %||% TRUE)
  } else {
    bench_strategy(name, spec$n_feat %||% 0L, spec$trade %||% FALSE)
  }
}

diag_make_features <- function(spec) {
  sma <- identical(spec$strategy_kind, "sma_crossover")
  if (sma) {
    bench_make_sma_features(spec$sma_fast %||% 20L, spec$sma_slow %||% 50L)
  } else {
    bench_make_features(spec$n_feat %||% 0L)
  }
}

diag_bucket_labels <- function() {
  data.frame(
    component = c(
      "t_feats",
      "t_bars",
      "t_ctx",
      "t_strat",
      "t_target",
      "t_fill",
      "t_event",
      "t_state",
      "t_unattributed"
    ),
    bucket = c(
      "feature_view_read",
      "bar_read_and_mark_to_market",
      "context_build",
      "strategy_callback",
      "target_order_conversion",
      "fill_resolution",
      "event_emission",
      "state_update",
      "unattributed_loop"
    ),
    boundary = c(
      "Read precomputed feature_table/features_wide pulse views and replace absent views with empty frames.",
      "Read current bars view and mark existing positions to current close prices.",
      "Construct ledgr_pulse_context and attach slow/fast helper accessors.",
      "Call strategy_fn(ctx, params) through the configured strategy-call wrapper.",
      "Normalize/validate strategy targets, apply current no-op risk layer, compute per-instrument deltas, select next bars, and create fill proposals.",
      "Resolve fill proposals through the cost resolver and validate fillability.",
      "Emit ordered fill events through the active output handler.",
      "Apply cash/position changes and persist or buffer strategy state updates.",
      "t_loop minus measured bucket totals; includes for-loop overhead, checkpoint checks, telemetry overhead, and any uninstrumented code."
    ),
    stringsAsFactors = FALSE
  )
}

diag_long_samples <- function(telemetry, scenario, iteration, spec, run_id) {
  components <- c(
    "t_pulse",
    "t_feats",
    "t_bars",
    "t_ctx",
    "t_strat",
    "t_target",
    "t_fill",
    "t_event",
    "t_state",
    "t_exec"
  )
  n <- length(telemetry$t_pulse)
  rows <- vector("list", length(components))
  for (k in seq_along(components)) {
    component <- components[[k]]
    values <- telemetry[[component]]
    rows[[k]] <- data.frame(
      scenario = scenario,
      iteration = iteration,
      run_id = run_id,
      n_inst = spec$n_inst,
      n_pulses = spec$n_pulses,
      n_feat = spec$n_feat %||% 0L,
      trade = isTRUE(spec$trade),
      sample_idx = seq_len(n),
      component = component,
      seconds = as.numeric(values),
      stringsAsFactors = FALSE
    )
  }
  do.call(rbind, rows)
}

diag_summarize <- function(samples, telemetry, scenario, iteration, spec, run_id, wall_sec) {
  labels <- diag_bucket_labels()
  bucket_components <- labels$component[labels$component != "t_unattributed"]
  one <- samples[samples$component %in% bucket_components, , drop = FALSE]
  split_values <- split(one$seconds, one$component)
  total <- vapply(split_values, function(x) sum(x, na.rm = TRUE), numeric(1))
  mean_v <- vapply(split_values, function(x) mean(x, na.rm = TRUE), numeric(1))
  median_v <- vapply(split_values, function(x) stats::median(x, na.rm = TRUE), numeric(1))
  p99_v <- vapply(split_values, function(x) stats::quantile(x, 0.99, na.rm = TRUE, names = FALSE), numeric(1))
  t_loop <- as.numeric(telemetry$t_loop)
  unattributed <- max(0, t_loop - sum(total, na.rm = TRUE))
  out <- data.frame(
    scenario = scenario,
    iteration = iteration,
    run_id = run_id,
    n_inst = spec$n_inst,
    n_pulses = spec$n_pulses,
    n_feat = spec$n_feat %||% 0L,
    trade = isTRUE(spec$trade),
    telemetry_stride = telemetry$telemetry_stride %||% NA_integer_,
    sampled_pulses = length(telemetry$t_pulse),
    wall_sec = as.numeric(wall_sec),
    t_loop_sec = t_loop,
    component = c(names(total), "t_unattributed"),
    total_sec = c(as.numeric(total), unattributed),
    mean_sec = c(as.numeric(mean_v), NA_real_),
    median_sec = c(as.numeric(median_v), NA_real_),
    p99_sec = c(as.numeric(p99_v), NA_real_),
    stringsAsFactors = FALSE
  )
  out$loop_share <- if (is.finite(t_loop) && t_loop > 0) out$total_sec / t_loop else NA_real_
  merge(out, labels, by = "component", all.x = TRUE, sort = FALSE)
}

diag_run_once <- function(name, spec, iteration, seed, telemetry_stride) {
  bars <- bench_make_bars(spec$n_inst, spec$n_pulses, seed + iteration)
  db_path <- tempfile(pattern = paste0("ledgr_fold_diag_", name, "_"), fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)
  snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  features <- diag_make_features(spec)
  strategy <- diag_make_strategy(name, spec)
  run_id <- sprintf(
    "fold_diag_%s_%03d_%s",
    name,
    iteration,
    paste(sample(c(0:9, letters), 6L, TRUE), collapse = "")
  )
  wall <- system.time({
    bt <- ledgr_backtest(
      snapshot = snapshot,
      strategy = strategy,
      strategy_params = list(qty = 1),
      initial_cash = 1e7,
      features = features,
      persist_features = spec$persist_features %||% FALSE,
      run_id = run_id,
      control = list(telemetry_stride = telemetry_stride)
    )
  })[["elapsed"]]
  on.exit(close(bt), add = TRUE)

  telemetry <- ledgr:::ledgr_get_run_telemetry(run_id)
  if (is.null(telemetry)) {
    stop("No telemetry captured for run: ", run_id, call. = FALSE)
  }
  samples <- diag_long_samples(telemetry, name, iteration, spec, run_id)
  summary <- diag_summarize(samples, telemetry, name, iteration, spec, run_id, wall)
  list(samples = samples, summary = summary)
}

diag_write_markdown <- function(summary, env, path, raw_samples_path, raw_summary_path) {
  con <- file(path, open = "w", encoding = "UTF-8")
  on.exit(close(con), add = TRUE)
  writeLines(c(
    "# Fold-Loop Diagnostic Profile",
    "",
    sprintf("Date: %s", env$created_at),
    sprintf("Package version label: `%s` loaded from current source.", env$package_version),
    sprintf("Git: `%s` on `%s`.", env$git_sha, env$git_branch),
    "",
    "Scope: LDG-2470 / v0.1.8.8 Batch 2. This is current-source, local-host,",
    "machine-specific diagnostic evidence. It is not an optimization claim and",
    "does not authorize implementation work.",
    "",
    sprintf("Raw samples: `%s`", raw_samples_path),
    sprintf("Raw summary: `%s`", raw_summary_path),
    "",
    "Method: run selected durable ledgr scenarios with `control$telemetry_stride = 1`",
    "and summarize sampled wall-clock buckets recorded inside `ledgr_execute_fold()`.",
    "Bucket totals are diagnostic attribution numbers; the `unattributed_loop` row is",
    "`t_loop` minus measured bucket totals and includes loop overhead, checkpoint checks,",
    "telemetry overhead, and uninstrumented code.",
    "`loop_share` is share of `t_loop`, not share of full wall time; `wall_sec` also",
    "includes setup, feature precompute, durable reconstruction, and teardown.",
    "Buckets below the timer floor may round to `0.0000` even though work occurred.",
    "",
    "| Scenario | Bucket | Total s | Loop share | Boundary |",
    "| --- | --- | ---: | ---: | --- |"
  ), con)
  rows <- summary[order(summary$scenario, -summary$total_sec), , drop = FALSE]
  for (i in seq_len(nrow(rows))) {
    writeLines(sprintf(
      "| `%s` | `%s` | %.4f | %.1f%% | %s |",
      rows$scenario[[i]],
      rows$bucket[[i]],
      rows$total_sec[[i]],
      100 * rows$loop_share[[i]],
      gsub("\\|", "/", rows$boundary[[i]])
    ), con)
  }
  writeLines(c(
    "",
    "Interpretation: keep these rows as profiler guidance. Future collapse,",
    "primitive-internal, or compiled-core work still needs its own ticket, profile,",
    "and parity gates."
  ), con)
}

diag_main <- function(args = diag_parse_args()) {
  diag_source_benchmark_helpers()
  dir.create(args$out_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(args$packet_dir, recursive = TRUE, showWarnings = FALSE)
  specs <- diag_specs(args$preset)
  if (!is.null(args$scenarios)) {
    specs <- specs[names(specs) %in% args$scenarios]
  }
  if (length(specs) == 0L) {
    stop("No scenarios selected.", call. = FALSE)
  }

  samples <- list()
  summaries <- list()
  for (name in names(specs)) {
    for (iteration in seq_len(args$repeats)) {
      message(sprintf("[fold-diagnostic] %s iteration %d", name, iteration))
      res <- diag_run_once(name, specs[[name]], iteration, args$seed, args$telemetry_stride)
      samples[[length(samples) + 1L]] <- res$samples
      summaries[[length(summaries) + 1L]] <- res$summary
    }
  }
  samples <- do.call(rbind, samples)
  summary <- do.call(rbind, summaries)

  stamp <- format(Sys.time(), tz = "UTC", "%Y%m%dT%H%M%SZ")
  stem <- file.path(args$out_dir, paste0("fold_loop_diagnostic_", args$preset, "_", stamp))
  samples_path <- paste0(stem, "_samples.csv")
  summary_path <- paste0(stem, "_summary.csv")
  packet_summary_path <- file.path(args$packet_dir, "fold_loop_diagnostic_summary.csv")
  packet_md_path <- file.path(args$packet_dir, "fold_loop_diagnostic_profile.md")

  utils::write.csv(samples, samples_path, row.names = FALSE)
  utils::write.csv(summary, summary_path, row.names = FALSE)
  utils::write.csv(summary, packet_summary_path, row.names = FALSE)
  env <- list(
    created_at = format(Sys.time(), tz = "UTC", "%Y-%m-%dT%H:%M:%SZ"),
    preset = args$preset,
    repeats = args$repeats,
    seed = args$seed,
    telemetry_stride = args$telemetry_stride,
    package_version = as.character(utils::packageVersion("ledgr")),
    git_sha = bench_git_value(c("rev-parse", "HEAD")),
    git_branch = bench_git_value(c("branch", "--show-current")),
    r_version = paste(R.version$major, R.version$minor, sep = "."),
    platform = R.version$platform
  )
  diag_write_markdown(summary, env, packet_md_path, samples_path, summary_path)

  message("[fold-diagnostic] wrote:")
  message("  ", samples_path)
  message("  ", summary_path)
  message("  ", packet_summary_path)
  message("  ", packet_md_path)
  invisible(summary)
}

if (sys.nframe() == 0L) {
  diag_main()
}
