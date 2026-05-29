# run_benchmarks.R
#
# Structured local benchmark suite for ledgr v0.1.8.6.
#
# This is a development benchmark harness, not a public performance dashboard.
# It runs named package-owned scenarios from current source, writes
# machine-readable outputs, and emits a small caveated LEAN/QuantConnect
# side-by-side for scenarios with a reasonable published analogue.
#
# Usage:
#   Rscript dev/bench/run_benchmarks.R --preset smoke --repeats 1 --warmup 1
#   Rscript dev/bench/run_benchmarks.R --preset record --repeats 3 --warmup 1

`%||%` <- function(x, y) if (is.null(x)) y else x

bench_parse_args <- function(args = commandArgs(trailingOnly = TRUE)) {
  out <- list(
    preset = "smoke",
    out_dir = file.path("dev", "bench", "results"),
    repeats = 3L,
    warmup = 1L,
    scenarios = NULL,
    seed = 20260528L,
    lean_ref = file.path("dev", "bench", "lean_reference.csv")
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
    } else if (identical(key, "--repeats")) {
      out$repeats <- as.integer(val)
      i <- i + 2L
    } else if (identical(key, "--warmup")) {
      out$warmup <- as.integer(val)
      i <- i + 2L
    } else if (identical(key, "--scenarios")) {
      out$scenarios <- strsplit(val, ",", fixed = TRUE)[[1L]]
      i <- i + 2L
    } else if (identical(key, "--seed")) {
      out$seed <- as.integer(val)
      i <- i + 2L
    } else if (identical(key, "--lean-ref")) {
      out$lean_ref <- val
      i <- i + 2L
    } else if (key %in% c("--help", "-h")) {
      cat(paste(
        "Usage: Rscript dev/bench/run_benchmarks.R [options]",
        "",
        "Options:",
        "  --preset smoke|record",
        "  --out-dir PATH",
        "  --repeats N",
        "  --warmup N",
        "  --scenarios comma,separated,names",
        "  --seed N",
        "  --lean-ref PATH",
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
  if (!is.finite(out$warmup) || out$warmup < 0L) {
    stop("`--warmup` must be a non-negative integer.", call. = FALSE)
  }
  out
}

bench_load_ledgr_source <- function() {
  suppressWarnings(suppressMessages({
    desc_is_ledgr <- file.exists("DESCRIPTION") &&
      identical(unname(read.dcf("DESCRIPTION")[1L, "Package"]), "ledgr")
    if (desc_is_ledgr) {
      if (!requireNamespace("pkgload", quietly = TRUE)) {
        stop("Run from source with pkgload installed; refusing to benchmark an installed package from a source tree.")
      }
      pkgload::load_all(".", quiet = TRUE)
    } else if (requireNamespace("ledgr", quietly = TRUE)) {
      library(ledgr)
    } else {
      stop("ledgr must be installed, or run this script from the package root.")
    }
  }))
  loaded <- as.character(utils::packageVersion("ledgr"))
  src <- if (file.exists("DESCRIPTION")) unname(read.dcf("DESCRIPTION")[1L, "Version"]) else NA_character_
  if (!is.na(src) && !identical(src, loaded)) {
    stop(sprintf(
      "Stale ledgr benchmark: loaded build is %s but source DESCRIPTION is %s.",
      loaded,
      src
    ))
  }
  message(sprintf("[bench] benchmarking ledgr %s from current source guard", loaded))
  invisible(loaded)
}

bench_git_value <- function(args) {
  out <- tryCatch(
    system2("git", args, stdout = TRUE, stderr = FALSE),
    error = function(e) NA_character_,
    warning = function(w) NA_character_
  )
  if (length(out) == 0L) NA_character_ else out[[1L]]
}

bench_environment <- function(args) {
  list(
    benchmark_schema = "ledgr_benchmark_v1",
    created_at = format(Sys.time(), tz = "UTC", "%Y-%m-%dT%H:%M:%SZ"),
    package_version = as.character(utils::packageVersion("ledgr")),
    git_sha = bench_git_value(c("rev-parse", "HEAD")),
    git_branch = bench_git_value(c("branch", "--show-current")),
    r_version = paste(R.version$major, R.version$minor, sep = "."),
    platform = R.version$platform,
    os = Sys.info()[["sysname"]],
    preset = args$preset,
    repeats = args$repeats,
    warmup = args$warmup,
    seed = args$seed
  )
}

bench_specs <- function(preset = "smoke") {
  if (identical(preset, "record")) {
    return(list(
      baseline_single_run = list(kind = "run", n_inst = 1L, n_pulses = 252L, n_feat = 0L, trade = TRUE),
      pulse_loop_empty = list(kind = "run", n_inst = 1L, n_pulses = 1000L, n_feat = 0L, trade = FALSE),
      wide_panel_no_features = list(kind = "run", n_inst = 400L, n_pulses = 252L, n_feat = 0L, trade = FALSE),
      feature_read_score = list(kind = "run", n_inst = 100L, n_pulses = 252L, n_feat = 20L, trade = FALSE),
      feature_turnover = list(kind = "run", n_inst = 100L, n_pulses = 252L, n_feat = 20L, trade = TRUE),
      indicator_payload = list(kind = "run", n_inst = 5L, n_pulses = 504L, n_feat = 50L, trade = FALSE),
      sweep_memory_summary = list(kind = "sweep", n_inst = 10L, n_pulses = 126L, n_feat = 2L, candidates = 5L),
      persistent_replay = list(kind = "run", n_inst = 25L, n_pulses = 252L, n_feat = 5L, trade = TRUE, replay = TRUE),
      peer_sma_crossover = list(kind = "run", n_inst = 500L, n_pulses = 1260L, n_feat = 2L, trade = TRUE, strategy_kind = "sma_crossover", sma_fast = 20L, sma_slow = 50L, persist_features = FALSE)
    ))
  }
  list(
    baseline_single_run = list(kind = "run", n_inst = 1L, n_pulses = 30L, n_feat = 0L, trade = TRUE),
    pulse_loop_empty = list(kind = "run", n_inst = 1L, n_pulses = 60L, n_feat = 0L, trade = FALSE),
    wide_panel_no_features = list(kind = "run", n_inst = 20L, n_pulses = 40L, n_feat = 0L, trade = FALSE),
    feature_read_score = list(kind = "run", n_inst = 20L, n_pulses = 40L, n_feat = 5L, trade = FALSE),
    feature_turnover = list(kind = "run", n_inst = 20L, n_pulses = 40L, n_feat = 5L, trade = TRUE),
    indicator_payload = list(kind = "run", n_inst = 3L, n_pulses = 60L, n_feat = 10L, trade = FALSE),
    sweep_memory_summary = list(kind = "sweep", n_inst = 3L, n_pulses = 30L, n_feat = 2L, candidates = 3L),
    persistent_replay = list(kind = "run", n_inst = 5L, n_pulses = 50L, n_feat = 3L, trade = TRUE, replay = TRUE),
    peer_sma_crossover = list(kind = "run", n_inst = 20L, n_pulses = 80L, n_feat = 2L, trade = TRUE, strategy_kind = "sma_crossover", sma_fast = 5L, sma_slow = 10L, persist_features = FALSE)
  )
}

bench_make_bars <- function(n_inst, n_pulses, seed) {
  as.data.frame(ledgr_sim_bars(
    n_instruments = n_inst,
    n_days = n_pulses,
    seed = seed,
    instrument_prefix = "BENCH_"
  ))
}

bench_make_features <- function(n_feat) {
  if (n_feat <= 0L) return(list())
  lapply(seq_len(n_feat), function(i) {
    force(i)
    ledgr_indicator(
      id = sprintf("bench_f_%03d", i),
      fn = function(window) tail(window$close, 1L),
      requires_bars = 1L,
      series_fn = function(bars, params) as.numeric(bars$close) * (i * 1e-4) + i
    )
  })
}

bench_make_sma_features <- function(fast = 20L, slow = 50L) {
  if (!requireNamespace("TTR", quietly = TRUE)) {
    stop("The peer_sma_crossover scenario needs the 'TTR' package (optimized C SMA). Install TTR to run it.")
  }
  mk <- function(id, w) {
    force(w)
    ledgr_indicator(
      id = id,
      fn = function(window) {
        x <- as.numeric(window$close)
        if (length(x) < w) return(NA_real_)
        as.numeric(TTR::SMA(x, n = w))[[length(x)]]
      },
      requires_bars = w,
      series_fn = function(bars, params) as.numeric(TTR::SMA(as.numeric(bars$close), n = w))
    )
  }
  list(mk("sma_fast", fast), mk("sma_slow", slow))
}

bench_sma_crossover_strategy <- function(trade) {
  TRADE <- isTRUE(trade)
  function(ctx, params) {
    targets <- ctx$flat()
    if (!TRADE) return(targets)
    fw <- ctx$features_wide
    fast <- fw$sma_fast
    slow <- fw$sma_slow
    long <- !is.na(fast) & !is.na(slow) & fast > slow
    if (any(long)) {
      targets[fw$instrument_id[long]] <- params$qty
    }
    targets
  }
}

bench_strategy <- function(name, n_feat, trade) {
  FEATURE_COLS <- if (n_feat > 0L) sprintf("bench_f_%03d", seq_len(n_feat)) else character()
  TRADE <- isTRUE(trade)
  BASELINE <- identical(name, "baseline_single_run")
  function(ctx, params) {
    targets <- ctx$flat()
    if (BASELINE) {
      targets[[ctx$universe[[1L]]]] <- params$qty
      return(targets)
    }
    if (length(FEATURE_COLS) > 0L) {
      fw <- ctx$features_wide
      score <- .rowSums(as.matrix(fw[FEATURE_COLS]), nrow(fw), length(FEATURE_COLS))
      if (TRADE && length(score) > 0L) {
        targets[[fw$instrument_id[[which.max(score)]]]] <- params$qty
      }
    }
    targets
  }
}

bench_read_telemetry <- function(run_id) {
  tel <- tryCatch(ledgr:::ledgr_get_run_telemetry(run_id), error = function(e) NULL)
  pick <- function(x) if (is.null(x) || !is.finite(x)) NA_real_ else as.numeric(x)
  list(
    t_pre = if (is.null(tel)) NA_real_ else pick(tel$t_pre),
    t_loop = if (is.null(tel)) NA_real_ else pick(tel$t_loop)
  )
}

bench_count_rows <- function(bt, what) {
  tryCatch(nrow(ledgr_results(bt, what)), error = function(e) NA_integer_)
}

bench_capture_warnings <- function(expr) {
  warnings <- character()
  value <- withCallingHandlers(
    expr,
    warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  list(value = value, warnings = warnings)
}

bench_run_scenario_once <- function(name, spec, iter, seed, is_warmup) {
  bars <- bench_make_bars(spec$n_inst, spec$n_pulses, seed + iter)
  db_path <- tempfile(pattern = paste0("ledgr_bench_", name, "_"), fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  snapshot_sec <- system.time(
    snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path)
  )[["elapsed"]]
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  sma <- identical(spec$strategy_kind, "sma_crossover")
  features <- if (sma) {
    bench_make_sma_features(spec$sma_fast %||% 20L, spec$sma_slow %||% 50L)
  } else {
    bench_make_features(spec$n_feat %||% 0L)
  }
  strategy <- if (sma) {
    bench_sma_crossover_strategy(spec$trade %||% TRUE)
  } else {
    bench_strategy(name, spec$n_feat %||% 0L, spec$trade %||% FALSE)
  }
  exp <- ledgr_experiment(
    snapshot = snapshot,
    strategy = strategy,
    features = features,
    opening = ledgr_opening(cash = 1e7),
    persist_features = spec$persist_features %||% TRUE
  )
  run_id <- sprintf("bench_%s_%03d_%s", name, iter, paste(sample(c(0:9, letters), 6L, TRUE), collapse = ""))
  warnings <- character()
  elapsed <- system.time({
    captured <- bench_capture_warnings(
      ledgr_run(exp, params = list(qty = 1), run_id = run_id, seed = seed + iter)
    )
    bt <- captured$value
    warnings <- captured$warnings
  })[["elapsed"]]
  on.exit(if (!is.null(bt)) close(bt), add = TRUE)

  tel <- bench_read_telemetry(run_id)
  info <- tryCatch(ledgr_run_info(snapshot, run_id), error = function(e) NULL)
  n_pulses <- if (is.null(info)) spec$n_pulses else as.integer(info$pulse_count)
  ledger_rows <- bench_count_rows(bt, "ledger")
  fill_rows <- bench_count_rows(bt, "fills")
  replay_sec <- NA_real_
  if (isTRUE(spec$replay)) {
    close(bt)
    bt <- NULL
    replay_sec <- system.time({
      reopened <- ledgr_run_open(snapshot, run_id)
      on.exit(close(reopened), add = TRUE)
      invisible(ledgr_results(reopened, "fills"))
      invisible(ledgr_results(reopened, "equity"))
    })[["elapsed"]]
  }

  t_pre <- tel$t_pre
  t_loop <- tel$t_loop
  t_residual <- elapsed -
    (if (is.finite(t_pre)) t_pre else 0) -
    (if (is.finite(t_loop)) t_loop else 0)
  feature_cells <- if ((spec$n_feat %||% 0L) > 0L) spec$n_inst * n_pulses * spec$n_feat else NA_real_

  data.frame(
    scenario = name,
    iteration = iter,
    is_warmup = isTRUE(is_warmup),
    kind = spec$kind,
    n_inst = spec$n_inst,
    n_pulses = n_pulses,
    n_feat = spec$n_feat %||% 0L,
    n_candidates = 1L,
    trade = isTRUE(spec$trade),
    snapshot_sec = as.numeric(snapshot_sec),
    t_pre_sec = as.numeric(t_pre),
    t_residual_sec = as.numeric(t_residual),
    t_loop_sec = as.numeric(t_loop),
    t_wall_sec = as.numeric(elapsed),
    replay_sec = as.numeric(replay_sec),
    security_bars = spec$n_inst * n_pulses,
    feature_cells = feature_cells,
    security_bars_sec = spec$n_inst * n_pulses / elapsed,
    feature_cells_sec = if (is.finite(feature_cells)) feature_cells / elapsed else NA_real_,
    events = ledger_rows,
    fills = fill_rows,
    events_sec = if (is.finite(ledger_rows) && elapsed > 0) ledger_rows / elapsed else NA_real_,
    warnings = length(warnings),
    failures = 0L,
    comparability_note = bench_comparability_note(name),
    stringsAsFactors = FALSE
  )
}

bench_run_sweep_once <- function(name, spec, iter, seed, is_warmup) {
  bars <- bench_make_bars(spec$n_inst, spec$n_pulses, seed + iter)
  db_path <- tempfile(pattern = paste0("ledgr_bench_", name, "_"), fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)
  snapshot_sec <- system.time(
    snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path)
  )[["elapsed"]]
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  features <- bench_make_features(spec$n_feat %||% 0L)
  FEATURE_COLS <- if ((spec$n_feat %||% 0L) > 0L) sprintf("bench_f_%03d", seq_len(spec$n_feat)) else character()
  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    if (length(FEATURE_COLS) > 0L) {
      fw <- ctx$features_wide
      score <- .rowSums(as.matrix(fw[FEATURE_COLS]), nrow(fw), length(FEATURE_COLS))
      targets[[fw$instrument_id[[which.max(score)]]]] <- params$qty
    }
    targets
  }
  exp <- ledgr_experiment(snapshot, strategy, features = features, opening = ledgr_opening(cash = 1e7))
  candidate_list <- stats::setNames(
    lapply(seq_len(spec$candidates), function(i) list(qty = i)),
    sprintf("candidate_%02d", seq_len(spec$candidates))
  )
  grid <- do.call(ledgr_param_grid, candidate_list)
  warnings <- character()
  elapsed <- system.time({
    captured <- bench_capture_warnings(ledgr_sweep(exp, grid, seed = seed + iter))
    sweep <- captured$value
    warnings <- captured$warnings
  })[["elapsed"]]
  result_warnings <- tryCatch(sum(vapply(sweep$warnings, length, integer(1))), error = function(e) 0L)
  failures <- tryCatch(sum(sweep$status != "DONE", na.rm = TRUE), error = function(e) 0L)
  security_bars <- spec$n_inst * spec$n_pulses * spec$candidates
  feature_cells <- if ((spec$n_feat %||% 0L) > 0L) security_bars * spec$n_feat else NA_real_

  data.frame(
    scenario = name,
    iteration = iter,
    is_warmup = isTRUE(is_warmup),
    kind = spec$kind,
    n_inst = spec$n_inst,
    n_pulses = spec$n_pulses,
    n_feat = spec$n_feat %||% 0L,
    n_candidates = spec$candidates,
    trade = TRUE,
    snapshot_sec = as.numeric(snapshot_sec),
    t_pre_sec = NA_real_,
    t_residual_sec = NA_real_,
    t_loop_sec = NA_real_,
    t_wall_sec = as.numeric(elapsed),
    replay_sec = NA_real_,
    security_bars = security_bars,
    feature_cells = feature_cells,
    security_bars_sec = security_bars / elapsed,
    feature_cells_sec = if (is.finite(feature_cells)) feature_cells / elapsed else NA_real_,
    events = NA_integer_,
    fills = tryCatch(sum(sweep$n_trades, na.rm = TRUE), error = function(e) NA_real_),
    events_sec = NA_real_,
    warnings = length(warnings) + result_warnings,
    failures = failures,
    comparability_note = bench_comparability_note(name),
    stringsAsFactors = FALSE
  )
}

bench_comparability_note <- function(name) {
  switch(
    name,
    baseline_single_run = "QC Basic Template analogue; side-by-side throughput only, not engine parity.",
    pulse_loop_empty = "QC one-symbol empty OnData analogue; no feature, no trade pressure.",
    wide_panel_no_features = "QC 400-symbol empty OnData analogue when record preset is used.",
    indicator_payload = "Partial QC indicator-ribbon analogue; ledgr stresses feature width, not chained depth.",
    feature_read_score = "ledgr-only cross-sectional feature scoring; no published LEAN analogue.",
    feature_turnover = "ledgr-only feature plus fills/events stress.",
    sweep_memory_summary = "ledgr-only in-memory sweep summary path.",
    persistent_replay = "ledgr-only persistent replay/read-back path.",
    peer_sma_crossover = "Matched Ziplime/Zipline/Backtrader workload (500 assets, 5yr daily, SMA crossover via TTR, persist off); orientation only -- vendor numbers are Apple M3, a different host.",
    "No external benchmark analogue."
  )
}

bench_run_suite <- function(args) {
  bench_load_ledgr_source()
  set.seed(args$seed)
  specs <- bench_specs(args$preset)
  if (!is.null(args$scenarios)) {
    missing <- setdiff(args$scenarios, names(specs))
    if (length(missing) > 0L) stop("Unknown scenarios: ", paste(missing, collapse = ", "), call. = FALSE)
    specs <- specs[args$scenarios]
  }

  rows <- list()
  k <- 0L
  for (name in names(specs)) {
    spec <- specs[[name]]
    message(sprintf("[bench] scenario %s", name))
    total <- args$warmup + args$repeats
    for (iter in seq_len(total)) {
      is_warmup <- iter <= args$warmup
      k <- k + 1L
      rows[[k]] <- if (identical(spec$kind, "sweep")) {
        bench_run_sweep_once(name, spec, iter, args$seed, is_warmup)
      } else {
        bench_run_scenario_once(name, spec, iter, args$seed, is_warmup)
      }
    }
  }
  raw <- do.call(rbind, rows)
  measured <- raw[!raw$is_warmup, , drop = FALSE]
  summary <- bench_summarize_results(measured)
  env <- bench_environment(args)
  bench_write_outputs(raw, summary, env, args)
  invisible(list(raw = raw, summary = summary, environment = env))
}

bench_median <- function(x) {
  x <- x[is.finite(x)]
  if (!length(x)) return(NA_real_)
  stats::median(x)
}

bench_summarize_results <- function(measured) {
  split_rows <- split(measured, measured$scenario)
  out <- lapply(split_rows, function(df) {
    first <- df[1L, , drop = FALSE]
    data.frame(
      scenario = first$scenario,
      kind = first$kind,
      n_inst = first$n_inst,
      n_pulses = first$n_pulses,
      n_feat = first$n_feat,
      n_candidates = first$n_candidates,
      measured_iterations = nrow(df),
      median_t_wall_sec = bench_median(df$t_wall_sec),
      median_t_pre_sec = bench_median(df$t_pre_sec),
      median_t_residual_sec = bench_median(df$t_residual_sec),
      median_t_loop_sec = bench_median(df$t_loop_sec),
      median_replay_sec = bench_median(df$replay_sec),
      median_security_bars_sec = bench_median(df$security_bars_sec),
      median_feature_cells_sec = bench_median(df$feature_cells_sec),
      median_events_sec = bench_median(df$events_sec),
      warnings = sum(df$warnings, na.rm = TRUE),
      failures = sum(df$failures, na.rm = TRUE),
      comparability_note = first$comparability_note,
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, out)
  rownames(out) <- NULL
  order_idx <- match(names(bench_specs("smoke")), out$scenario)
  order_idx <- order_idx[!is.na(order_idx)]
  out[order_idx, , drop = FALSE]
}

bench_write_outputs <- function(raw, summary, env, args) {
  dir.create(args$out_dir, recursive = TRUE, showWarnings = FALSE)
  stamp <- format(Sys.time(), tz = "UTC", "%Y%m%dT%H%M%SZ")
  stem <- file.path(args$out_dir, paste0("ledgr_bench_", args$preset, "_", stamp))
  raw_path <- paste0(stem, "_raw.csv")
  summary_path <- paste0(stem, "_summary.csv")
  env_path <- paste0(stem, "_environment.json")
  json_path <- paste0(stem, "_results.json")
  md_path <- paste0(stem, "_summary.md")
  qc_path <- paste0(stem, "_lean_side_by_side.csv")

  utils::write.csv(raw, raw_path, row.names = FALSE)
  utils::write.csv(summary, summary_path, row.names = FALSE)
  jsonlite::write_json(env, env_path, auto_unbox = TRUE, pretty = TRUE, na = "null")
  jsonlite::write_json(list(environment = env, raw = raw, summary = summary), json_path, dataframe = "rows", pretty = TRUE, na = "null")
  bench_write_markdown(summary, env, md_path)
  if (file.exists(args$lean_ref)) {
    comparison <- bench_write_lean_comparison(summary, args$lean_ref, qc_path)
    message(sprintf("[bench] wrote LEAN side-by-side rows: %d", nrow(comparison)))
  } else {
    message(sprintf("[bench] LEAN reference not found: %s", args$lean_ref))
  }

  message("[bench] wrote:")
  message("  ", raw_path)
  message("  ", summary_path)
  message("  ", env_path)
  message("  ", json_path)
  message("  ", md_path)
  invisible(summary_path)
}

bench_write_markdown <- function(summary, env, path) {
  con <- file(path, open = "w", encoding = "UTF-8")
  on.exit(close(con), add = TRUE)
  writeLines(c(
    "# ledgr Benchmark Summary",
    "",
    sprintf("- Created: `%s`", env$created_at),
    sprintf("- Preset: `%s`", env$preset),
    sprintf("- Git: `%s` on `%s`", env$git_sha, env$git_branch),
    "",
    "This is a local development benchmark. QuantConnect/LEAN comparisons are",
    "caveated side-by-side throughput references, not parity or speed-ranking claims.",
    "",
    "| Scenario | Wall s | Bars/sec | Feature cells/sec | Loop s | Notes |",
    "| --- | ---: | ---: | ---: | ---: | --- |"
  ), con)
  for (i in seq_len(nrow(summary))) {
    writeLines(sprintf(
      "| `%s` | %.4f | %.1f | %.1f | %.4f | %s |",
      summary$scenario[[i]],
      summary$median_t_wall_sec[[i]],
      summary$median_security_bars_sec[[i]],
      summary$median_feature_cells_sec[[i]],
      summary$median_t_loop_sec[[i]],
      gsub("\\|", "/", summary$comparability_note[[i]])
    ), con)
  }
}

bench_write_lean_comparison <- function(summary, lean_ref, path) {
  lean <- utils::read.csv(lean_ref, stringsAsFactors = FALSE)
  lean <- lean[lean$comparable %in% c("yes", "partial") & !is.na(lean$ledgr_scenario), , drop = FALSE]
  cmp <- merge(
    lean,
    summary[, c("scenario", "median_t_wall_sec", "median_security_bars_sec", "n_inst", "n_pulses", "n_feat", "comparability_note")],
    by.x = "ledgr_scenario",
    by.y = "scenario",
    all.x = TRUE,
    sort = FALSE
  )
  cmp$ledgr_to_lean_dps_ratio <- cmp$median_security_bars_sec / cmp$dps_median
  cmp$comparison_policy <- "side-by-side throughput only; not LEAN parity, not a speed ranking"
  utils::write.csv(cmp, path, row.names = FALSE)
  cmp
}

if (sys.nframe() == 0L) {
  args <- bench_parse_args()
  bench_run_suite(args)
}
