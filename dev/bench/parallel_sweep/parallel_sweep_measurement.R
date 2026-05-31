# parallel_sweep_measurement.R
#
# Current-source parallel sweep attribution harness for v0.1.8.8 / LDG-2475.
# This is a local development benchmark, not a public performance dashboard.
#
# Usage:
#   Rscript dev/bench/parallel_sweep/parallel_sweep_measurement.R --preset smoke --repeats 1 --warmup 0
#   Rscript dev/bench/parallel_sweep/parallel_sweep_measurement.R --preset record --repeats 3 --warmup 1

`%||%` <- function(x, y) if (is.null(x)) y else x

psm_parse_args <- function(args = commandArgs(trailingOnly = TRUE)) {
  out <- list(
    preset = "smoke",
    out_dir = file.path("dev", "bench", "results"),
    repeats = 1L,
    warmup = 0L,
    candidate_counts = NULL,
    workers = NULL,
    workloads = NULL,
    seed = 20260530L
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
    } else if (identical(key, "--candidate-counts")) {
      out$candidate_counts <- as.integer(strsplit(val, ",", fixed = TRUE)[[1L]])
      i <- i + 2L
    } else if (identical(key, "--workers")) {
      out$workers <- as.integer(strsplit(val, ",", fixed = TRUE)[[1L]])
      i <- i + 2L
    } else if (identical(key, "--workloads")) {
      out$workloads <- strsplit(val, ",", fixed = TRUE)[[1L]]
      i <- i + 2L
    } else if (identical(key, "--seed")) {
      out$seed <- as.integer(val)
      i <- i + 2L
    } else if (key %in% c("--help", "-h")) {
      cat(paste(
        "Usage: Rscript dev/bench/parallel_sweep/parallel_sweep_measurement.R [options]",
        "",
        "Options:",
        "  --preset smoke|record",
        "  --out-dir PATH",
        "  --repeats N",
        "  --warmup N",
        "  --candidate-counts comma,separated,integers",
        "  --workers comma,separated,integers",
        "  --workloads comma,separated,names",
        "  --seed N",
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

psm_load_ledgr_source <- function() {
  source(file.path("dev", "bench", "run_benchmarks.R"), local = globalenv())
  bench_load_ledgr_source()
}

psm_specs <- function(preset) {
  if (identical(preset, "record")) {
    return(list(
      cheap_sma = list(n_inst = 100L, n_pulses = 252L, n_feat = 2L, kind = "cheap_sma"),
      feature_heavy = list(n_inst = 80L, n_pulses = 252L, n_feat = 20L, kind = "feature_heavy")
    ))
  }
  list(
    cheap_sma = list(n_inst = 20L, n_pulses = 80L, n_feat = 2L, kind = "cheap_sma"),
    feature_heavy = list(n_inst = 20L, n_pulses = 80L, n_feat = 8L, kind = "feature_heavy")
  )
}

psm_default_candidate_counts <- function(preset) {
  if (identical(preset, "record")) c(1L, 2L, 4L, 8L, 16L) else c(1L, 2L, 4L)
}

psm_default_workers <- function(preset) {
  if (identical(preset, "record")) c(1L, 2L, 4L) else c(1L, 2L)
}

psm_make_grid <- function(n_candidates) {
  candidates <- stats::setNames(
    lapply(seq_len(n_candidates), function(i) list(qty = i)),
    sprintf("candidate_%03d", seq_len(n_candidates))
  )
  do.call(ledgr_param_grid, candidates)
}

psm_make_exp <- function(spec, seed) {
  bars <- bench_make_bars(spec$n_inst, spec$n_pulses, seed)
  db_path <- tempfile(pattern = "ledgr_parallel_sweep_", fileext = ".duckdb")
  snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path)
  if (identical(spec$kind, "cheap_sma")) {
    features <- bench_make_sma_features(5L, 10L)
    strategy <- bench_sma_crossover_strategy(TRUE)
  } else {
    features <- bench_make_features(spec$n_feat)
    strategy <- bench_strategy("feature_turnover", spec$n_feat, TRUE)
  }
  exp <- ledgr_experiment(
    snapshot = snapshot,
    strategy = strategy,
    features = features,
    opening = ledgr_opening(cash = 1e7)
  )
  list(exp = exp, snapshot = snapshot, db_path = db_path)
}

psm_sweep_comparable <- function(x) {
  out <- as.data.frame(x[, !names(x) %in% c("warnings", "provenance"), drop = FALSE])
  for (col in intersect(c("params", "feature_params", "feature_fingerprints"), names(out))) {
    out[[col]] <- vapply(out[[col]], ledgr:::canonical_json, character(1))
  }
  attr(out, "sweep_id") <- NULL
  attr(out, "snapshot_id") <- NULL
  attr(out, "snapshot_hash") <- NULL
  attr(out, "strategy_hash") <- NULL
  out
}

psm_results_equal <- function(a, b) {
  isTRUE(all.equal(psm_sweep_comparable(a), psm_sweep_comparable(b), check.attributes = FALSE))
}

psm_measure_worker_setup <- function(exp, workers) {
  if (workers <= 1L) {
    return(0)
  }
  if (!requireNamespace("mirai", quietly = TRUE)) {
    return(NA_real_)
  }
  preflight <- ledgr:::ledgr_strategy_preflight(exp$strategy)
  elapsed <- system.time({
    ledgr:::ledgr_parallel_worker_setup(
      workers = workers,
      preflight = preflight,
      dry_run = FALSE
    )
    ledgr:::ledgr_parallel_mirai_stop()
  })[["elapsed"]]
  as.numeric(elapsed)
}

psm_count_result_warnings <- function(out) {
  tryCatch(sum(vapply(out$warnings, length, integer(1))), error = function(e) NA_integer_)
}

psm_run_one <- function(workload, spec, n_candidates, workers, iter, is_warmup,
                        seed, reference = NULL) {
  if (workers > 1L && !requireNamespace("mirai", quietly = TRUE)) {
    return(data.frame(
      workload = workload, iteration = iter, is_warmup = isTRUE(is_warmup),
      n_inst = spec$n_inst, n_pulses = spec$n_pulses, n_feat = spec$n_feat,
      n_candidates = n_candidates, workers = workers, setup_sec = NA_real_,
      wall_sec = NA_real_, candidate_sec = NA_real_, security_bars_sec = NA_real_,
      status = "SKIPPED", equality_to_sequential = NA, failures = NA_integer_,
      warnings = NA_integer_, note = "mirai not installed",
      stringsAsFactors = FALSE
    ))
  }

  fixture <- psm_make_exp(spec, seed + iter)
  on.exit({
    try(ledgr_snapshot_close(fixture$snapshot), silent = TRUE)
    try(unlink(fixture$db_path), silent = TRUE)
  }, add = TRUE)
  grid <- psm_make_grid(n_candidates)
  setup_sec <- psm_measure_worker_setup(fixture$exp, workers)
  err <- NULL
  out <- NULL
  elapsed <- system.time({
    out <- tryCatch(
      ledgr_sweep(fixture$exp, grid, seed = seed + iter, workers = workers),
      error = function(e) {
        err <<- e
        NULL
      }
    )
  })[["elapsed"]]

  done <- is.null(err)
  equality <- if (done && !is.null(reference)) psm_results_equal(out, reference) else if (done && workers <= 1L) TRUE else NA
  security_bars <- spec$n_inst * spec$n_pulses * n_candidates
  data.frame(
    workload = workload,
    iteration = iter,
    is_warmup = isTRUE(is_warmup),
    n_inst = spec$n_inst,
    n_pulses = spec$n_pulses,
    n_feat = spec$n_feat,
    n_candidates = n_candidates,
    workers = workers,
    setup_sec = setup_sec,
    wall_sec = if (done) as.numeric(elapsed) else NA_real_,
    candidate_sec = if (done) as.numeric(elapsed) / n_candidates else NA_real_,
    security_bars_sec = if (done) security_bars / as.numeric(elapsed) else NA_real_,
    status = if (done) "DONE" else "FAILED",
    equality_to_sequential = equality,
    failures = if (done) sum(out$status != "DONE", na.rm = TRUE) else NA_integer_,
    warnings = if (done) psm_count_result_warnings(out) else NA_integer_,
    note = if (done) "local current-source measurement; not a public speed claim" else conditionMessage(err),
    stringsAsFactors = FALSE
  )
}

psm_measure <- function(args) {
  psm_load_ledgr_source()
  specs <- psm_specs(args$preset)
  if (!is.null(args$workloads)) {
    missing <- setdiff(args$workloads, names(specs))
    if (length(missing) > 0L) stop("Unknown workloads: ", paste(missing, collapse = ", "), call. = FALSE)
    specs <- specs[args$workloads]
  }
  candidate_counts <- args$candidate_counts %||% psm_default_candidate_counts(args$preset)
  workers <- sort(unique(c(1L, args$workers %||% psm_default_workers(args$preset))))
  rows <- list()
  k <- 0L
  total <- args$warmup + args$repeats
  for (workload in names(specs)) {
    spec <- specs[[workload]]
    if (identical(spec$kind, "cheap_sma") && !requireNamespace("TTR", quietly = TRUE)) {
      message("[parallel-bench] skipping cheap_sma: TTR not installed")
      next
    }
    for (n_candidates in candidate_counts) {
      for (iter in seq_len(total)) {
        is_warmup <- iter <= args$warmup
        ref_fixture <- psm_make_exp(spec, args$seed + iter)
        ref <- tryCatch(
          ledgr_sweep(ref_fixture$exp, psm_make_grid(n_candidates), seed = args$seed + iter, workers = 1L),
          finally = {
            try(ledgr_snapshot_close(ref_fixture$snapshot), silent = TRUE)
            try(unlink(ref_fixture$db_path), silent = TRUE)
          }
        )
        for (worker_count in workers) {
          k <- k + 1L
          message(sprintf(
            "[parallel-bench] workload=%s candidates=%d workers=%d iter=%d",
            workload, n_candidates, worker_count, iter
          ))
          rows[[k]] <- psm_run_one(
            workload = workload,
            spec = spec,
            n_candidates = n_candidates,
            workers = worker_count,
            iter = iter,
            is_warmup = is_warmup,
            seed = args$seed,
            reference = ref
          )
        }
      }
    }
  }
  do.call(rbind, rows)
}

psm_summarize <- function(raw) {
  measured <- raw[!raw$is_warmup, , drop = FALSE]
  measured <- measured[measured$status == "DONE", , drop = FALSE]
  if (nrow(measured) == 0L) {
    return(data.frame())
  }
  groups <- unique(measured[, c("workload", "n_candidates", "workers"), drop = FALSE])
  rows <- vector("list", nrow(groups))
  for (i in seq_len(nrow(groups))) {
    g <- groups[i, , drop = FALSE]
    m <- measured[
      measured$workload == g$workload[[1]] &
        measured$n_candidates == g$n_candidates[[1]] &
        measured$workers == g$workers[[1]],
      ,
      drop = FALSE
    ]
    seq_m <- measured[
      measured$workload == g$workload[[1]] &
        measured$n_candidates == g$n_candidates[[1]] &
        measured$workers == 1L,
      ,
      drop = FALSE
    ]
    seq_wall <- if (nrow(seq_m) > 0L) stats::median(seq_m$wall_sec, na.rm = TRUE) else NA_real_
    wall <- stats::median(m$wall_sec, na.rm = TRUE)
    rows[[i]] <- data.frame(
      workload = g$workload[[1]],
      n_candidates = g$n_candidates[[1]],
      workers = g$workers[[1]],
      median_setup_sec = stats::median(m$setup_sec, na.rm = TRUE),
      median_wall_sec = wall,
      median_candidate_sec = stats::median(m$candidate_sec, na.rm = TRUE),
      median_security_bars_sec = stats::median(m$security_bars_sec, na.rm = TRUE),
      speedup_vs_workers_1 = if (is.finite(seq_wall) && is.finite(wall) && wall > 0) seq_wall / wall else NA_real_,
      equality_all = all(isTRUE(m$equality_to_sequential) | m$workers == 1L),
      stringsAsFactors = FALSE
    )
  }
  do.call(rbind, rows)
}

psm_environment <- function(args) {
  git_head <- function() {
    head_path <- file.path(".git", "HEAD")
    head <- tryCatch(readLines(head_path, n = 1L, warn = FALSE), error = function(e) NA_character_)
    if (length(head) == 0L || is.na(head[[1L]])) {
      return(list(sha = NA_character_, branch = NA_character_))
    }
    if (!grepl("^ref: ", head[[1L]])) {
      return(list(sha = head[[1L]], branch = NA_character_))
    }
    ref <- sub("^ref: ", "", head[[1L]])
    sha <- tryCatch(readLines(file.path(".git", ref), n = 1L, warn = FALSE), error = function(e) NA_character_)
    if (length(sha) == 0L) sha <- NA_character_
    list(sha = sha[[1L]], branch = sub("^refs/heads/", "", ref))
  }
  git <- git_head()
  list(
    created_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    preset = args$preset,
    args = args,
    R = R.version.string,
    platform = R.version$platform,
    git_sha = git$sha,
    git_branch = git$branch,
    ledgr_version = as.character(utils::packageVersion("ledgr")),
    mirai_installed = requireNamespace("mirai", quietly = TRUE),
    mirai_version = if (requireNamespace("mirai", quietly = TRUE)) as.character(utils::packageVersion("mirai")) else NA_character_,
    TTR_installed = requireNamespace("TTR", quietly = TRUE),
    machine_specific = TRUE,
    claim_policy = "local current-source attribution only; no public speedup claim from one shape"
  )
}

psm_write_markdown <- function(summary, env, path) {
  con <- file(path, open = "w", encoding = "UTF-8")
  on.exit(close(con), add = TRUE)
  writeLines(c(
    "# Parallel Sweep Measurement Summary",
    "",
    sprintf("- Created: `%s`", env$created_at),
    sprintf("- Preset: `%s`", env$preset),
    sprintf("- Git: `%s` on `%s`", env$git_sha, env$git_branch),
    sprintf("- mirai installed: `%s`", env$mirai_installed),
    "",
    "This is local-host current-source attribution for LDG-2475. It separates",
    "worker setup overhead from full sweep wall time and reports candidate-count",
    "and worker-count rows. It is not a public speedup claim.",
    "",
    "| Workload | Candidates | Workers | Setup s | Wall s | Candidate s | Bars/sec | Speedup vs 1 | Equality |",
    "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |"
  ), con)
  for (i in seq_len(nrow(summary))) {
    writeLines(sprintf(
      "| `%s` | %d | %d | %.4f | %.4f | %.4f | %.1f | %.3f | `%s` |",
      summary$workload[[i]],
      summary$n_candidates[[i]],
      summary$workers[[i]],
      summary$median_setup_sec[[i]],
      summary$median_wall_sec[[i]],
      summary$median_candidate_sec[[i]],
      summary$median_security_bars_sec[[i]],
      summary$speedup_vs_workers_1[[i]],
      summary$equality_all[[i]]
    ), con)
  }
}

psm_write_outputs <- function(raw, summary, env, args) {
  dir.create(args$out_dir, recursive = TRUE, showWarnings = FALSE)
  stamp <- format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
  stem <- file.path(args$out_dir, sprintf("parallel_sweep_%s_%s", args$preset, stamp))
  raw_path <- paste0(stem, "_raw.csv")
  summary_path <- paste0(stem, "_summary.csv")
  env_path <- paste0(stem, "_environment.json")
  json_path <- paste0(stem, "_results.json")
  md_path <- paste0(stem, "_summary.md")
  utils::write.csv(raw, raw_path, row.names = FALSE)
  utils::write.csv(summary, summary_path, row.names = FALSE)
  jsonlite::write_json(env, env_path, auto_unbox = TRUE, pretty = TRUE, na = "null")
  jsonlite::write_json(list(environment = env, raw = raw, summary = summary), json_path, dataframe = "rows", pretty = TRUE, na = "null")
  psm_write_markdown(summary, env, md_path)
  message("[parallel-bench] wrote:")
  message("  ", raw_path)
  message("  ", summary_path)
  message("  ", env_path)
  message("  ", json_path)
  message("  ", md_path)
  invisible(list(raw = raw_path, summary = summary_path, environment = env_path, json = json_path, markdown = md_path))
}

psm_main <- function(args = psm_parse_args()) {
  raw <- psm_measure(args)
  summary <- psm_summarize(raw)
  env <- psm_environment(args)
  psm_write_outputs(raw, summary, env, args)
}

if (sys.nframe() == 0L) {
  psm_main()
}
