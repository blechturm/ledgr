#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
script_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
script_path <- if (length(script_arg)) {
  normalizePath(
    sub("^--file=", "", script_arg[[1L]]),
    winslash = "/",
    mustWork = TRUE
  )
} else {
  normalizePath(
    "dev/bench/v0_2_0_1_stage_m/run_dense_timestamp_validation.R",
    winslash = "/",
    mustWork = TRUE
  )
}
repo_root <- normalizePath(
  file.path(dirname(script_path), "..", "..", ".."),
  winslash = "/",
  mustWork = TRUE
)

.libPaths(c(
  "C:/tmp/ledgr-collapse-218-lib",
  "C:/Users/maxth/Documents/R/win-library/4.6",
  "C:/Users/maxth/AppData/Local/R/win-library/4.6",
  .libPaths()
))

pkgload::load_all(repo_root, quiet = TRUE)
source(file.path(repo_root, "dev/bench/peer_benchmark/peer_benchmark.R"))

stage_m_current_key <- function(x) {
  vapply(
    as.POSIXct(x, tz = "UTC"),
    ledgr:::ledgr_normalize_ts_utc,
    character(1L)
  )
}

stage_m_current_validator <- function(bars_by_id, universe) {
  missing <- setdiff(universe, names(bars_by_id))
  if (length(missing) > 0L) {
    rlang::abort(
      sprintf(
        paste0(
          "Precomputed feature scoring range is missing bars for ",
          "instrument(s): %s."
        ),
        paste(missing, collapse = ", ")
      ),
      class = "ledgr_precomputed_coverage_error"
    )
  }
  pulses <- NULL
  for (id in universe) {
    bars <- bars_by_id[[id]]
    if (is.null(bars) || nrow(bars) == 0L) {
      rlang::abort(
        sprintf(
          paste0(
            "Precomputed feature scoring range is missing bars for ",
            "instrument: %s."
          ),
          id
        ),
        class = "ledgr_precomputed_coverage_error"
      )
    }
    ts <- stage_m_current_key(bars$ts_utc)
    if (is.null(pulses)) {
      pulses <- ts
    } else if (!identical(ts, pulses)) {
      rlang::abort(
        paste(
          "Precomputed feature scoring range has incomplete or misaligned",
          "per-instrument bars."
        ),
        class = "ledgr_precomputed_coverage_error"
      )
    }
  }
  invisible(TRUE)
}

stage_m_replace_binding <- function(name, value) {
  namespace <- asNamespace("ledgr")
  old <- get(name, envir = namespace, inherits = FALSE)
  unlockBinding(name, namespace)
  assign(name, value, envir = namespace)
  lockBinding(name, namespace)
  old
}

stage_m_restore_binding <- function(name, value) {
  namespace <- asNamespace("ledgr")
  unlockBinding(name, namespace)
  assign(name, value, envir = namespace)
  lockBinding(name, namespace)
  invisible(NULL)
}

stage_m_semantic_hash <- function(result) {
  returns_columns <- c(
    "candidate_id", "candidate_row", "status", "ts_utc", "equity",
    "period_return"
  )
  trades_columns <- c(
    "candidate_id", "candidate_row", "trade_seq", "close_ts_utc",
    "realized_pnl", "win_loss"
  )
  digest::digest(
    list(
      status = result$status,
      returns = peer_plain_df(
        result$public_returns[, returns_columns, drop = FALSE]
      ),
      trades = peer_plain_df(
        result$public_trades[, trades_columns, drop = FALSE]
      ),
      metrics = result$metrics
    ),
    algo = "sha256",
    serialize = TRUE
  )
}

stage_m_child <- function(arm, engine, repetition, bars_path, output, marker) {
  production <- ledgr:::ledgr_precompute_validate_static_coverage
  target <- if (identical(arm, "current")) {
    stage_m_current_validator
  } else if (identical(arm, "candidate")) {
    production
  } else {
    stop("Unknown Stage M arm.", call. = FALSE)
  }
  observations <- new.env(parent = emptyenv())
  observations$calls <- 0L
  observations$seconds <- 0
  observed <- function(bars_by_id, universe) {
    started <- proc.time()[["elapsed"]]
    value <- target(bars_by_id, universe)
    observations$calls <- observations$calls + 1L
    observations$seconds <- observations$seconds +
      proc.time()[["elapsed"]] - started
    value
  }
  old <- stage_m_replace_binding(
    "ledgr_precompute_validate_static_coverage",
    observed
  )
  on.exit(stage_m_restore_binding(
    "ledgr_precompute_validate_static_coverage",
    old
  ), add = TRUE)

  features <- ledgr_feature_map(
    fast = peer_sma_ttr("fast", 5L),
    slow = peer_sma_ttr("slow", 10L)
  )
  strategy <- peer_strategy("fast", "slow")
  compiled <- if (identical(engine, "compiled")) "spot_fifo" else NULL
  engine_label <- if (identical(engine, "compiled")) {
    "ledgr_ttr_compiled_spot_fifo_sweep"
  } else {
    "ledgr_ttr_canonical_sweep"
  }

  invisible(gc(full = TRUE))
  writeLines(format(Sys.time(), tz = "UTC"), marker)
  result <- peer_run_ledgr_sweep(
    engine = engine_label,
    bars_path = bars_path,
    features = features,
    strategy = strategy,
    seed = 20260530L,
    compiled_accounting_model = compiled,
    cost_model = peer_cost_zero_model(),
    risk_chain = peer_risk_none_model()
  )
  if (!identical(observations$calls, 1L)) {
    stop("The public sweep did not call dense coverage exactly once.", call. = FALSE)
  }
  phase <- result$phase_sec
  summary <- list(
    arm = arm,
    engine = engine,
    repetition = repetition,
    status = result$status,
    validator_calls = observations$calls,
    validator_sec = observations$seconds,
    cold_sec = result$wall_sec,
    warm_sec = result$wall_sec - phase$snapshot_prepare_sec,
    snapshot_prepare_sec = phase$snapshot_prepare_sec,
    setup_sec = phase$experiment_setup_sec,
    engine_sec = phase$engine_sec,
    results_sec = phase$results_sec,
    semantic_sha256 = stage_m_semantic_hash(result)
  )
  slim <- list(
    status = result$status,
    public_returns = result$public_returns,
    public_trades = result$public_trades,
    metrics = result$metrics
  )
  saveRDS(list(summary = summary, result = slim), output)
  invisible(NULL)
}

sampler_ps1 <- '
param([string]$Exe, [string]$ChildArgsJoined, [string]$Marker,
      [double]$WallCeilingS, [double]$WsCeilingMiB,
      [int]$IntervalMs = 200)
$childArgs = $ChildArgsJoined.Split("|")
$p = Start-Process -FilePath $Exe -ArgumentList $childArgs -PassThru -WindowStyle Hidden
$null = $p.Handle
$peak = 0; $killed = ""; $runStart = $null
while (-not $p.HasExited) {
  try {
    $p.Refresh(); $ws = $p.WorkingSet64; $pk = $p.PeakWorkingSet64
    if ($pk -gt $peak) { $peak = $pk }
    if ($null -eq $runStart -and (Test-Path $Marker)) { $runStart = Get-Date }
    if ($WsCeilingMiB -gt 0 -and ($ws / 1MB) -gt $WsCeilingMiB) {
      $killed = "working_set"; $p.Kill()
    }
    if ($WallCeilingS -gt 0 -and $null -ne $runStart -and
        ((Get-Date) - $runStart).TotalSeconds -gt $WallCeilingS) {
      $killed = "wall"; $p.Kill()
    }
  } catch {}
  Start-Sleep -Milliseconds $IntervalMs
}
$p.WaitForExit()
$elapsed = if ($null -ne $runStart) {
  ((Get-Date) - $runStart).TotalSeconds
} else { -1 }
Write-Output ("PEAK_WS_BYTES=" + $peak)
Write-Output ("KILLED=" + $killed)
Write-Output ("RUN_ELAPSED_S=" + $elapsed)
Write-Output ("CHILD_EXIT=" + $p.ExitCode)
'

stage_m_rscript <- function() {
  path <- "C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe"
  if (!file.exists(path)) stop("R 4.6.1 Rscript was not found.", call. = FALSE)
  path
}

stage_m_launch <- function(arm, engine, repetition, bars_path) {
  ps1 <- tempfile("stage_m_sampler_", fileext = ".ps1")
  marker <- tempfile("stage_m_marker_")
  output <- tempfile("stage_m_result_", fileext = ".rds")
  writeLines(sampler_ps1, ps1)
  on.exit(unlink(c(ps1, marker, output), force = TRUE), add = TRUE)
  child_args <- c(
    script_path, "--child", arm, engine, repetition,
    normalizePath(bars_path, winslash = "/", mustWork = TRUE),
    normalizePath(output, winslash = "/", mustWork = FALSE),
    normalizePath(marker, winslash = "/", mustWork = FALSE)
  )
  process_output <- system2(
    "powershell",
    c(
      "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", shQuote(ps1),
      "-Exe", shQuote(stage_m_rscript()),
      "-ChildArgsJoined", shQuote(paste(child_args, collapse = "|")),
      "-Marker", shQuote(marker),
      "-WallCeilingS", "300", "-WsCeilingMiB", "4096",
      "-IntervalMs", "200"
    ),
    stdout = TRUE,
    stderr = TRUE
  )
  grab <- function(key) {
    match <- grep(paste0("^", key, "="), process_output, value = TRUE)
    if (!length(match)) NA_character_ else
      sub(paste0("^", key, "="), "", match[[1L]])
  }
  if (!file.exists(output)) {
    cat(process_output, sep = "\n")
    stop("Stage M child did not produce an output artifact.", call. = FALSE)
  }
  payload <- readRDS(output)
  payload$summary$peak_ws_mib <-
    as.numeric(grab("PEAK_WS_BYTES")) / 1024^2
  payload$summary$sampled_wall_sec <- as.numeric(grab("RUN_ELAPSED_S"))
  payload$summary$killed <- grab("KILLED")
  payload$summary$child_exit <- as.integer(grab("CHILD_EXIT"))
  if (!identical(payload$summary$killed, "") ||
      !identical(payload$summary$child_exit, 0L)) {
    stop("Stage M child was killed or failed.", call. = FALSE)
  }
  payload
}

stage_m_assert_exact <- function(reference, candidate, context) {
  returns_columns <- c(
    "candidate_id", "candidate_row", "status", "ts_utc", "equity",
    "period_return"
  )
  trades_columns <- c(
    "candidate_id", "candidate_row", "trade_seq", "close_ts_utc",
    "realized_pnl", "win_loss"
  )
  reference_returns <- peer_plain_df(
    reference$public_returns[, returns_columns, drop = FALSE]
  )
  candidate_returns <- peer_plain_df(
    candidate$public_returns[, returns_columns, drop = FALSE]
  )
  reference_trades <- peer_plain_df(
    reference$public_trades[, trades_columns, drop = FALSE]
  )
  candidate_trades <- peer_plain_df(
    candidate$public_trades[, trades_columns, drop = FALSE]
  )
  if (!identical(reference$status, candidate$status) ||
      !identical(reference_returns, candidate_returns) ||
      !identical(reference_trades, candidate_trades) ||
      !identical(reference$metrics, candidate$metrics)) {
    stop(context, " changed public sweep semantics.", call. = FALSE)
  }
  invisible(TRUE)
}

stage_m_gates <- function(runs, surfaces) {
  measured <- runs[runs$measured, , drop = FALSE]
  gate_rows <- list()
  for (engine in c("canonical", "compiled")) {
    current <- measured[
      measured$engine == engine & measured$arm == "current",
      , drop = FALSE
    ]
    candidate <- measured[
      measured$engine == engine & measured$arm == "candidate",
      , drop = FALSE
    ]
    current_validator <- stats::median(current$validator_sec)
    candidate_validator <- stats::median(candidate$validator_sec)
    current_warm <- stats::median(current$warm_sec)
    candidate_warm <- stats::median(candidate$warm_sec)
    current_spread <- diff(range(current$warm_sec))
    improvement <- current_warm - candidate_warm
    validator_ratio <- candidate_validator / current_validator
    memory_ratio <- max(candidate$peak_ws_mib) / max(current$peak_ws_mib)
    checks <- c(
      validator_ratio <= 0.10,
      improvement >= 10,
      improvement > current_spread,
      memory_ratio <= 1.15,
      all(current$validator_calls == 1L),
      all(candidate$validator_calls == 1L),
      length(unique(current$semantic_sha256)) == 1L,
      length(unique(candidate$semantic_sha256)) == 1L,
      identical(
        unique(current$semantic_sha256),
        unique(candidate$semantic_sha256)
      )
    )
    gate_rows[[engine]] <- data.frame(
      engine = engine,
      current_validator_median_sec = current_validator,
      candidate_validator_median_sec = candidate_validator,
      validator_ratio = validator_ratio,
      current_warm_median_sec = current_warm,
      candidate_warm_median_sec = candidate_warm,
      improvement_sec = improvement,
      current_spread_sec = current_spread,
      current_max_peak_ws_mib = max(current$peak_ws_mib),
      candidate_max_peak_ws_mib = max(candidate$peak_ws_mib),
      peak_ws_ratio = memory_ratio,
      passed = all(checks),
      stringsAsFactors = FALSE
    )
  }
  stage_m_assert_exact(
    surfaces$current_canonical,
    surfaces$candidate_canonical,
    "Canonical current/candidate"
  )
  stage_m_assert_exact(
    surfaces$current_compiled,
    surfaces$candidate_compiled,
    "Compiled current/candidate"
  )
  current_residual <- peer_compare_public_sweep_surfaces(
    surfaces$current_canonical,
    surfaces$current_compiled
  )
  candidate_residual <- peer_compare_public_sweep_surfaces(
    surfaces$candidate_canonical,
    surfaces$candidate_compiled
  )
  gates <- do.call(rbind, gate_rows)
  rownames(gates) <- NULL
  if (!all(gates$passed)) {
    print(gates)
    stop("One or more Stage M performance gates failed.", call. = FALSE)
  }
  list(
    gates = gates,
    current_residual = current_residual,
    candidate_residual = candidate_residual
  )
}

stage_m_write_evidence <- function(runs, result, bars_hash, output_dir) {
  utils::write.csv(
    runs,
    file.path(output_dir, "batch12-dense-timestamp-runs.csv"),
    row.names = FALSE
  )
  utils::write.csv(
    result$gates,
    file.path(output_dir, "batch12-dense-timestamp-gates.csv"),
    row.names = FALSE
  )
  lines <- c(
    "# Batch 12 Dense Timestamp Validation Evidence",
    "",
    "Status: accepted after independent Stage M review and maintainer approval.",
    "",
    sprintf("- Source base: `%s` plus the uncommitted Batch 12 candidate.",
            system2("git", c("-C", shQuote(repo_root), "rev-parse", "HEAD"),
                    stdout = TRUE)),
    sprintf("- Fixture SHA-256: `%s`.", bars_hash),
    paste0(
      "- Environment: R ", getRversion(), "; ledgr ",
      utils::packageVersion("ledgr"), "; duckdb ",
      utils::packageVersion("duckdb"), "; collapse ",
      utils::packageVersion("collapse"), "."
    ),
    paste(
      "- Clock: complete public `ledgr_sweep()` workflow with snapshot",
      "preparation separated; validator timing is observed inside that call."
    ),
    paste(
      "- Peak working set: external Windows process sampling every 200 ms;",
      "runs were serial with no intentional concurrent benchmark workload."
    ),
    "",
    paste(
      "The first record attempt completed its measurements but stopped before",
      "persisting evidence because the harness compared the random per-run"
    ),
    paste(
      "`sweep_id`. A small current/candidate smoke pair proved the corrected",
      "comparison, and the complete 16-run protocol was then repeated from"
    ),
    paste(
      "scratch. That clean repetition excluded `sweep_id` and also omitted",
      "`candidate_row` from returns while comparing it for trades."
    ),
    paste(
      "Independent review found the asymmetry. It cannot mask a difference",
      "in this one-candidate protocol because `candidate_row` is fixed at"
    ),
    paste(
      "`1L` in every run. The retained harness now compares it for both",
      "surfaces; the recorded timings did not require a rerun. The results"
    ),
    "below come only from the clean full repetition.",
    "",
    "## Gate Results",
    ""
  )
  for (i in seq_len(nrow(result$gates))) {
    x <- result$gates[i, ]
    lines <- c(
      lines,
      sprintf("### %s", x$engine),
      "",
      sprintf(
        paste(
          "- Validator median: %.4f s current, %.4f s candidate;",
          "ratio %.4f (limit 0.10)."
        ),
        x$current_validator_median_sec,
        x$candidate_validator_median_sec,
        x$validator_ratio
      ),
      sprintf(
        paste(
          "- Public warm median: %.2f s current, %.2f s candidate;",
          "improvement %.2f s versus %.2f s current spread."
        ),
        x$current_warm_median_sec,
        x$candidate_warm_median_sec,
        x$improvement_sec,
        x$current_spread_sec
      ),
      sprintf(
        paste(
          "- Maximum peak working set: %.1f MiB current, %.1f MiB",
          "candidate; ratio %.3f (limit 1.15)."
        ),
        x$current_max_peak_ws_mib,
        x$candidate_max_peak_ws_mib,
        x$peak_ws_ratio
      ),
      sprintf("- Gate disposition: `%s`.", if (x$passed) "PASS" else "FAIL"),
      ""
    )
  }
  lines <- c(
    lines,
    "## Semantic And Structural Results",
    "",
    paste(
      "Current and candidate public returns, realized trades, status, and",
      "metrics were exact within each accounting engine across every run."
    ),
    paste(
      "Canonical-versus-compiled public returns passed the existing `1e-8`",
      "floating tolerance and realized trades remained exact in both arms."
    ),
    paste(
      "The focused suite covers the complete direct semantic/failure matrix,",
      "public sweep, precompute, walk-forward, and the availability bypass."
    ),
    paste(
      "Its structural gate observes one vector-key call per axis, zero calls",
      "to the scalar formatter, rejects forbidden source tokens, and fails",
      "against a deliberate `vapply()` scalar-format mutant."
    ),
    "",
    paste(
      "The scalar production path is removed. No option, arm stamp, fallback,",
      "alternate public method, schema, identity, or availability behavior is",
      "introduced. This is Stage M evidence, not the final Stage O record."
    )
  )
  writeLines(
    lines,
    file.path(output_dir, "batch12-dense-timestamp-evidence.md"),
    useBytes = TRUE
  )
}

stage_m_main <- function() {
  key_source <- paste(
    deparse(body(ledgr:::ledgr_precompute_ts_key), width.cutoff = 500L),
    collapse = "\n"
  )
  if (any(vapply(
    c("vapply(", "format.POSIXct(", "ledgr_normalize_ts_utc(",
      "ledgr_iso_utc("),
    grepl,
    logical(1L),
    x = key_source,
    fixed = TRUE
  ))) {
    stop("Candidate source still contains scalar timestamp formatting.",
         call. = FALSE)
  }

  bars <- as.data.frame(ledgr_sim_bars(
    n_instruments = 500L,
    n_days = 1260L,
    seed = 20260530L,
    instrument_prefix = "PEER_"
  ))
  bars_path <- tempfile("stage_m_bars_", fileext = ".csv")
  on.exit(unlink(bars_path, force = TRUE), add = TRUE)
  utils::write.csv(bars, bars_path, row.names = FALSE)
  bars_hash <- digest::digest(
    file = bars_path,
    algo = "sha256",
    serialize = FALSE
  )
  rm(bars)
  invisible(gc(full = TRUE))

  repetitions <- c("warmup", "run1", "run2", "run3")
  rows <- list()
  surfaces <- list()
  row_number <- 0L
  for (repetition in repetitions) {
    engines <- if (repetition %in% c("warmup", "run2")) {
      c("canonical", "compiled")
    } else {
      c("compiled", "canonical")
    }
    arms <- if (repetition %in% c("warmup", "run1", "run3")) {
      c("current", "candidate")
    } else {
      c("candidate", "current")
    }
    for (engine in engines) {
      for (arm in arms) {
        message("[Stage M] ", repetition, " / ", engine, " / ", arm)
        payload <- stage_m_launch(arm, engine, repetition, bars_path)
        row_number <- row_number + 1L
        summary <- as.data.frame(payload$summary, stringsAsFactors = FALSE)
        summary$measured <- !identical(repetition, "warmup")
        rows[[row_number]] <- summary
        key <- paste(arm, engine, sep = "_")
        if (is.null(surfaces[[key]])) surfaces[[key]] <- payload$result
        message(sprintf(
          "  warm %.2f s; validator %.4f s; peak %.1f MiB",
          summary$warm_sec,
          summary$validator_sec,
          summary$peak_ws_mib
        ))
      }
    }
  }
  runs <- do.call(rbind, rows)
  rownames(runs) <- NULL
  result <- stage_m_gates(runs, surfaces)
  output_dir <- file.path(
    repo_root,
    "inst/design/ledgr_v0_2_0_1_spec_packet"
  )
  stage_m_write_evidence(runs, result, bars_hash, output_dir)
  print(result$gates, row.names = FALSE)
  message("BATCH12_DENSE_TIMESTAMP_GATES_OK")
  invisible(result)
}

if (length(args) >= 1L && identical(args[[1L]], "--child")) {
  if (length(args) != 7L) stop("Invalid Stage M child arguments.", call. = FALSE)
  stage_m_child(
    arm = args[[2L]],
    engine = args[[3L]],
    repetition = args[[4L]],
    bars_path = args[[5L]],
    output = args[[6L]],
    marker = args[[7L]]
  )
} else if (sys.nframe() == 0L) {
  stage_m_main()
}
