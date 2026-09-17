# Production availability closeout for ledgr v0.2.0.1.
#
# Run from the repository root:
#   Rscript dev/bench/availability_closeout/availability_closeout.R all
#
# The parent process creates one immutable local record under
# dev/bench/results/. A child process builds and seals the registered fixture;
# four more children run the production fold (one warm-up and three measured
# runs), and a fifth profiles lane attribution. No retired arm is restored.

args <- commandArgs(trailingOnly = TRUE)
script_path <- local({
  f <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  if (!length(f)) stop("Run with Rscript.", call. = FALSE)
  normalizePath(sub("^--file=", "", f[[1L]]), winslash = "/")
})
script_dir <- dirname(script_path)
repo_root <- normalizePath(file.path(script_dir, "..", "..", ".."), winslash = "/")
profile_home <- Sys.getenv("USERPROFILE")
if (nzchar(profile_home)) Sys.setenv(HOME = profile_home)
`%||%` <- function(a, b) if (is.null(a) || !length(a)) b else a
arg_value <- function(flag, default = NULL) {
  i <- match(flag, args)
  if (is.na(i) || i == length(args)) default else args[[i + 1L]]
}

WARM_WALL_STOP_S <- 300
WARM_WS_STOP_MIB <- 2048
COLD_WALL_STOP_S <- 1800
COLD_WS_STOP_MIB <- 4096
WARM_WALL_GATE_S <- 60
WARM_WS_GATE_MIB <- 1024
REGISTERED <- list(
  n_instruments = 563L,
  n_members = 505L,
  n_sessions = 757L,
  n_lists = 60L,
  bars = 426191L,
  membership_rows = 30300L,
  diagnostic_rows = 383042L,
  decision_rows = 382285L
)

rscript_path <- function() {
  candidates <- file.path(R.home("bin"), c("Rscript.exe", "x64/Rscript.exe", "Rscript"))
  candidates[file.exists(candidates)][[1L]]
}

load_package <- function() {
  options(keep.source = TRUE, keep.source.pkgs = TRUE, warn = 1)
  pkgload::load_all(repo_root, quiet = TRUE, export_all = TRUE)
}

registered_fixture <- function() {
  source_path <- file.path(
    repo_root, "dev", "spikes", "availability-hot-path-representation",
    "spike_runner.R"
  )
  env <- new.env(parent = globalenv())
  for (expr in parse(source_path)) {
    if (is.call(expr) && identical(expr[[1L]], as.name("<-")) &&
        is.name(expr[[2L]]) &&
        as.character(expr[[2L]]) %in% c("FIXTURES", "spike_fixture")) {
      eval(expr, env)
    }
  }
  env$spike_fixture(env$FIXTURES$envelope757)
}

flat_strategy <- function(ctx, params) ctx$flat()

production_experiment <- function(snapshot) {
  ledgr::ledgr_experiment(
    snapshot,
    flat_strategy,
    universe = ledgr::ledgr_universe_members("synthetic_members"),
    valuation_policy = ledgr::ledgr_valuation_stale(max_sessions = 2L),
    cost_model = ledgr::ledgr_cost_zero(),
    opening = ledgr::ledgr_opening(cash = 1e6)
  )
}

environment_row <- function() {
  info <- Sys.info()
  data.frame(
    source_commit = system2("git", c("-C", shQuote(repo_root), "rev-parse", "HEAD"), stdout = TRUE),
    r = R.version.string,
    platform = R.version$platform,
    os = paste(info[["sysname"]], info[["release"]], info[["version"]]),
    machine = info[["machine"]],
    logical_cores = parallel::detectCores(logical = TRUE),
    duckdb = as.character(utils::packageVersion("duckdb")),
    testthat = as.character(utils::packageVersion("testthat")),
    collapse = as.character(utils::packageVersion("collapse")),
    primary_library = normalizePath(.libPaths()[[1L]], winslash = "/"),
    stringsAsFactors = FALSE
  )
}

phase_functions <- c(
  "ledgr_availability_validate_inputs",
  "ledgr_snapshot_create",
  "ledgr_create_schema",
  "ledgr_snapshot_write_availability",
  "ledgr_snapshot_write_fact_family",
  "ledgr_snapshot_seal",
  "ledgr_snapshot_validate_for_seal",
  "ledgr_snapshot_validate_availability_for_seal",
  "ledgr_snapshot_metadata_for_seal",
  "ledgr_snapshot_hash",
  "ledgr_checkpoint_duckdb"
)

install_phase_timers <- function() {
  times <- new.env(parent = emptyenv())
  assign("batch8_phase_times", times, envir = globalenv())
  for (fn in phase_functions) {
    suppressMessages(trace(
      fn,
      where = asNamespace("ledgr"),
      print = FALSE,
      tracer = quote(.batch8_phase_t0 <- proc.time()[["elapsed"]]),
      exit = bquote(assign(
        .(fn),
        c(
          get0(.(fn), envir = batch8_phase_times, inherits = FALSE, ifnotfound = numeric()),
          proc.time()[["elapsed"]] - .batch8_phase_t0
        ),
        envir = batch8_phase_times
      ))
    ))
  }
  times
}

remove_phase_timers <- function() {
  for (fn in phase_functions) {
    suppressMessages(untrace(fn, where = asNamespace("ledgr")))
  }
}

child_seal <- function(template_path, marker, output_path) {
  load_package()
  times <- install_phase_timers()
  on.exit(remove_phase_timers(), add = TRUE)
  invisible(gc(full = TRUE))
  writeLines(format(Sys.time(), tz = "UTC"), marker)
  total_start <- proc.time()[["elapsed"]]
  fixture_start <- proc.time()[["elapsed"]]
  fixture <- registered_fixture()
  fixture_seconds <- proc.time()[["elapsed"]] - fixture_start
  seal_start <- proc.time()[["elapsed"]]
  snapshot <- ledgr::ledgr_snapshot_from_df(
    fixture$bars,
    instruments_df = fixture$instruments,
    db_path = template_path,
    snapshot_id = "batch8",
    facts = fixture$facts
  )
  seal_seconds <- proc.time()[["elapsed"]] - seal_start
  snapshot_hash <- ledgr::ledgr_snapshot_info(snapshot)$snapshot_hash[[1L]]
  ledgr::ledgr_snapshot_close(snapshot)
  total_seconds <- proc.time()[["elapsed"]] - total_start
  phase_rows <- do.call(rbind, lapply(phase_functions, function(fn) {
    values <- get0(fn, envir = times, inherits = FALSE, ifnotfound = numeric())
    data.frame(phase = fn, calls = length(values), inclusive_seconds = sum(values))
  }))
  result <- list(
    fixture_seconds = fixture_seconds,
    seal_seconds = seal_seconds,
    cold_end_to_end_seconds = total_seconds,
    snapshot_hash = snapshot_hash,
    bars = nrow(fixture$bars),
    instruments = nrow(fixture$instruments),
    sessions = length(fixture$session_dates),
    phase_times = phase_rows,
    pairwise_reference_exported = any(vapply(
      c(
        "availability_reference_validate_membership_conflicts",
        "availability_reference_validate_lifetime_conflicts",
        "availability_reference_validate_status_conflicts"
      ),
      exists,
      logical(1),
      envir = asNamespace("ledgr"),
      inherits = FALSE
    ))
  )
  jsonlite::write_json(result, output_path, auto_unbox = TRUE, digits = NA)
}

lane_names <- c(
  "provider_build", "provider_membership", "provider_status_lifetime",
  "provider_other", "valuation", "diag_construct", "diag_append_retain",
  "final_bind", "duckdb_diag_append", "residual_fold", "outside_loop"
)

classify_sample <- function(functions) {
  has <- function(x) any(x %in% functions)
  if (has(c(
    "ledgr_availability_provider_build",
    "ledgr_availability_provider_build_prepared",
    "ledgr_availability_prepared_membership",
    "ledgr_availability_prepared_segments"
  ))) return("provider_build")
  if (!has("run_transaction")) return("outside_loop")
  if (has(c("prepared_members_at", "members_at"))) return("provider_membership")
  if (has(c("prepared_facts", "prepared_seek", "prepared_read", "facts", "seek", "read"))) {
    return("provider_status_lifetime")
  }
  if (has("ledgr_availability_valuation_marks")) return("valuation")
  if (has(c("write_run_diagnostics", "write_run_evidence"))) return("duckdb_diag_append")
  if (has(c(
    "ledgr_availability_diagnostic_block", "ledgr_availability_diagnostic_row",
    "add_segment", "append_decision_trace"
  ))) return("diag_construct")
  if (has(c("append_block", "flush_pulse_block", "put"))) return("diag_append_retain")
  if (has(c("rbind", "rbind.data.frame", "drain", "build")) && !has("flush_pending")) {
    return("final_bind")
  }
  if (has(c("decision_view", "execution_view"))) return("provider_other")
  "residual_fold"
}

parse_profile <- function(path) {
  lines <- readLines(path, warn = FALSE)
  interval_us <- as.numeric(sub(".*sample.interval=", "", lines[[1L]]))
  samples <- lines[startsWith(lines, ":")]
  prefix_re <- "^:[0-9]+:[0-9]+:[0-9]+:[0-9]+:"
  tokens <- strsplit(trimws(sub(prefix_re, "", samples)), " +")
  functions <- lapply(tokens, function(x) {
    sub("^.*[$:]", "", gsub('"', "", x[startsWith(x, '"')], fixed = TRUE))
  })
  lanes <- vapply(functions, classify_sample, character(1))
  in_loop <- sum(!lanes %in% c("outside_loop", "provider_build"))
  do.call(rbind, lapply(lane_names, function(lane) {
    n <- sum(lanes == lane)
    data.frame(
      lane = lane,
      samples = n,
      seconds = n * interval_us / 1e6,
      share_in_loop = if (lane %in% c("outside_loop", "provider_build") || !in_loop) 0 else n / in_loop,
      stringsAsFactors = FALSE
    )
  }))
}

child_warm <- function(template_path, run_db, run_id, marker, output_path, profile_path = NULL) {
  load_package()
  if (!file.copy(template_path, run_db, overwrite = FALSE)) {
    stop("Could not copy the registered sealed snapshot.", call. = FALSE)
  }
  on.exit(unlink(c(run_db, paste0(run_db, ".wal")), force = TRUE), add = TRUE)
  snapshot <- ledgr::ledgr_snapshot_open(run_db, "batch8", verify = TRUE)
  on.exit(ledgr::ledgr_snapshot_close(snapshot), add = TRUE)
  experiment <- production_experiment(snapshot)
  counters <- new.env(parent = emptyenv())
  counters$provider_build <- 0L
  counters$diagnostic_block <- 0L
  assign("batch8_counters", counters, envir = globalenv())
  suppressMessages(trace(
    "ledgr_availability_provider_build",
    where = asNamespace("ledgr"),
    print = FALSE,
    tracer = quote(batch8_counters$provider_build <- batch8_counters$provider_build + 1L)
  ))
  suppressMessages(trace(
    "ledgr_availability_diagnostic_block",
    where = asNamespace("ledgr"),
    print = FALSE,
    tracer = quote(batch8_counters$diagnostic_block <- batch8_counters$diagnostic_block + 1L)
  ))
  on.exit(suppressMessages(untrace("ledgr_availability_provider_build", where = asNamespace("ledgr"))), add = TRUE)
  on.exit(suppressMessages(untrace("ledgr_availability_diagnostic_block", where = asNamespace("ledgr"))), add = TRUE)
  invisible(gc(full = TRUE))
  if (!is.null(profile_path)) {
    Rprof(profile_path, interval = 0.02, memory.profiling = TRUE, line.profiling = TRUE, gc.profiling = TRUE)
    on.exit(Rprof(NULL), add = TRUE)
  }
  writeLines(format(Sys.time(), tz = "UTC"), marker)
  started <- proc.time()[["elapsed"]]
  bt <- ledgr::ledgr_run(experiment, run_id = run_id)
  wall <- proc.time()[["elapsed"]] - started
  if (!is.null(profile_path)) Rprof(NULL)
  info <- ledgr::ledgr_run_info(snapshot, run_id)
  telemetry <- ledgr:::ledgr_get_run_telemetry(run_id)
  diagnostics <- as.data.frame(ledgr::ledgr_results(bt, "diagnostics"))
  close(bt)
  result <- list(
    run_id = run_id,
    wall_seconds = wall,
    t_loop_seconds = as.numeric(telemetry$t_loop %||% NA_real_),
    status = as.character(info$status),
    diagnostic_rows = nrow(diagnostics),
    decision_rows = sum(diagnostics$stage == "decision"),
    pulses_with_diagnostics = length(unique(diagnostics$ts_utc)),
    provider_build_calls = counters$provider_build,
    diagnostic_block_calls = counters$diagnostic_block,
    lanes = if (is.null(profile_path)) NULL else parse_profile(profile_path)
  )
  jsonlite::write_json(result, output_path, auto_unbox = TRUE, digits = NA)
}

sampler_ps1 <- '
param([string]$Exe, [string]$ChildArgsJoined, [string]$Marker,
      [double]$WallCeilingS, [double]$WsCeilingMiB, [int]$IntervalMs = 200)
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
$elapsed = if ($null -ne $runStart) { ((Get-Date) - $runStart).TotalSeconds } else { -1 }
Write-Output ("PEAK_WS_BYTES=" + $peak)
Write-Output ("KILLED=" + $killed)
Write-Output ("RUN_ELAPSED_S=" + $elapsed)
Write-Output ("CHILD_EXIT=" + $p.ExitCode)
'

launch_child <- function(child_args, wall_ceiling, ws_ceiling, marker) {
  ps1 <- tempfile("batch8_sampler_", fileext = ".ps1")
  writeLines(sampler_ps1, ps1)
  on.exit(unlink(c(ps1, marker), force = TRUE), add = TRUE)
  output <- system2(
    "powershell",
    c(
      "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", shQuote(ps1),
      "-Exe", shQuote(rscript_path()),
      "-ChildArgsJoined", shQuote(paste(c(script_path, child_args), collapse = "|")),
      "-Marker", shQuote(marker),
      "-WallCeilingS", format(wall_ceiling),
      "-WsCeilingMiB", format(ws_ceiling),
      "-IntervalMs", "200"
    ),
    stdout = TRUE,
    stderr = TRUE
  )
  grab <- function(key) {
    value <- grep(paste0("^", key, "="), output, value = TRUE)
    if (!length(value)) NA_character_ else sub(paste0("^", key, "="), "", value[[1L]])
  }
  list(
    output = output,
    killed = grab("KILLED"),
    exit = as.integer(grab("CHILD_EXIT")),
    run_elapsed_seconds = as.numeric(grab("RUN_ELAPSED_S")),
    peak_ws_mib = as.numeric(grab("PEAK_WS_BYTES")) / 1024^2
  )
}

run_json_child <- function(child_args, wall_ceiling, ws_ceiling, marker) {
  result_path <- tempfile("batch8_child_", fileext = ".json")
  on.exit(unlink(result_path, force = TRUE), add = TRUE)
  sampled <- launch_child(
    c(child_args, result_path),
    wall_ceiling = wall_ceiling,
    ws_ceiling = ws_ceiling,
    marker = marker
  )
  result <- if (file.exists(result_path)) {
    jsonlite::read_json(result_path, simplifyVector = TRUE)
  } else {
    NULL
  }
  if (is.null(result)) {
    cat(sampled$output, sep = "\n")
    stop(
      sprintf("Batch 8 child failed (exit %s, killed '%s').", sampled$exit, sampled$killed),
      call. = FALSE
    )
  }
  c(sampled, list(result = result))
}

write_summary <- function(out_dir, cold, warm, lanes) {
  measured <- warm[warm$measured, , drop = FALSE]
  leading <- lanes$lane[which.max(lanes$share_in_loop)]
  lines <- c(
    "# v0.2.0.1 Availability Closeout Record",
    "",
    sprintf("- Source commit: `%s`.", environment_row()$source_commit),
    sprintf("- Cold end to end: %.2f seconds; peak working set %.1f MiB.", cold$cold_end_to_end_seconds, cold$peak_ws_mib),
    sprintf("- Warm walls: %s seconds.", paste(sprintf("%.2f", measured$wall_seconds), collapse = " / ")),
    sprintf("- Warm median: %.2f seconds; spread: %.2f seconds.", stats::median(measured$wall_seconds), diff(range(measured$wall_seconds))),
    sprintf("- Warm measured peaks: %s MiB.", paste(sprintf("%.1f", measured$peak_ws_mib), collapse = " / ")),
    sprintf("- Largest profiled in-loop lane: `%s` (%.1f%%).", leading, 100 * max(lanes$share_in_loop)),
    "- Clock boundary: cold includes deterministic fixture preparation through sealing; warm surrounds ledgr_run() over a reused sealed snapshot.",
    "- This is an internal closeout record, not a public peer ranking."
  )
  writeLines(lines, file.path(out_dir, "summary.md"))
}

run_parent <- function(out_dir) {
  tracked <- system2(
    "git",
    c("-C", shQuote(repo_root), "status", "--porcelain", "--untracked-files=no"),
    stdout = TRUE
  )
  if (length(tracked)) stop("Tracked worktree changes must be committed before recording.", call. = FALSE)
  if (dir.exists(out_dir) && length(list.files(out_dir, all.files = TRUE, no.. = TRUE))) {
    stop("Refusing to overwrite an existing closeout record.", call. = FALSE)
  }
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  env <- environment_row()
  utils::write.csv(env, file.path(out_dir, "environment.csv"), row.names = FALSE)
  fixture <- data.frame(
    instruments = REGISTERED$n_instruments,
    members = REGISTERED$n_members,
    sessions = REGISTERED$n_sessions,
    membership_lists = REGISTERED$n_lists,
    bars = REGISTERED$bars,
    membership_rows = REGISTERED$membership_rows,
    formula = "spike_fixture(FIXTURES$envelope757); flat targets; zero fills",
    stringsAsFactors = FALSE
  )
  utils::write.csv(fixture, file.path(out_dir, "fixture.csv"), row.names = FALSE)

  template <- file.path(out_dir, "availability_template.duckdb")
  cold_marker <- tempfile("batch8_cold_marker_")
  cat("Batch 8 cold seal ...\n")
  cold_run <- run_json_child(
    c("--child-seal", template, cold_marker),
    COLD_WALL_STOP_S,
    COLD_WS_STOP_MIB,
    cold_marker
  )
  cold <- as.data.frame(cold_run$result[c(
    "fixture_seconds", "seal_seconds", "cold_end_to_end_seconds", "snapshot_hash",
    "bars", "instruments", "sessions", "pairwise_reference_exported"
  )])
  cold$peak_ws_mib <- cold_run$peak_ws_mib
  cold$killed <- cold_run$killed
  utils::write.csv(cold, file.path(out_dir, "cold_seal.csv"), row.names = FALSE)
  utils::write.csv(
    as.data.frame(cold_run$result$phase_times),
    file.path(out_dir, "cold_phases.csv"),
    row.names = FALSE
  )
  cat(sprintf("  %.2f s end to end; %.1f MiB peak\n", cold$cold_end_to_end_seconds, cold$peak_ws_mib))

  repetitions <- c("warmup", "run1", "run2", "run3", "profiled")
  warm_rows <- list()
  lanes <- NULL
  for (repetition in repetitions) {
    marker <- tempfile("batch8_warm_marker_")
    run_db <- tempfile("batch8_warm_", fileext = ".duckdb")
    profile <- if (identical(repetition, "profiled")) tempfile("batch8_warm_", fileext = ".prof") else NULL
    child_args <- c(
      "--child-warm", template, run_db,
      paste0("batch8-", repetition), marker,
      if (!is.null(profile)) profile
    )
    cat(sprintf("Batch 8 warm %s ...\n", repetition))
    run <- run_json_child(child_args, WARM_WALL_STOP_S, WARM_WS_STOP_MIB, marker)
    result <- run$result
    warm_rows[[repetition]] <- data.frame(
      repetition = repetition,
      measured = repetition %in% c("run1", "run2", "run3"),
      profiled = identical(repetition, "profiled"),
      wall_seconds = result$wall_seconds,
      t_loop_seconds = result$t_loop_seconds,
      peak_ws_mib = run$peak_ws_mib,
      status = result$status,
      diagnostic_rows = result$diagnostic_rows,
      decision_rows = result$decision_rows,
      pulses_with_diagnostics = result$pulses_with_diagnostics,
      provider_build_calls = result$provider_build_calls,
      diagnostic_block_calls = result$diagnostic_block_calls,
      killed = run$killed,
      stringsAsFactors = FALSE
    )
    if (!is.null(result$lanes)) lanes <- as.data.frame(result$lanes)
    unlink(profile, force = TRUE)
    cat(sprintf("  %.2f s; %.1f MiB peak; %s\n", result$wall_seconds, run$peak_ws_mib, result$status))
  }
  warm <- do.call(rbind, warm_rows)
  rownames(warm) <- NULL
  utils::write.csv(warm, file.path(out_dir, "warm_runs.csv"), row.names = FALSE)
  utils::write.csv(lanes, file.path(out_dir, "warm_lanes.csv"), row.names = FALSE)

  measured <- warm[warm$measured, , drop = FALSE]
  checks <- c(
    cold$bars == REGISTERED$bars,
    cold$instruments == REGISTERED$n_instruments,
    cold$sessions == REGISTERED$n_sessions,
    !isTRUE(cold$pairwise_reference_exported),
    all(warm$status == "DONE"),
    all(warm$diagnostic_rows == REGISTERED$diagnostic_rows),
    all(warm$decision_rows == REGISTERED$decision_rows),
    all(warm$pulses_with_diagnostics == REGISTERED$n_sessions),
    all(warm$provider_build_calls == 1L),
    all(warm$diagnostic_block_calls == REGISTERED$n_sessions),
    stats::median(measured$wall_seconds) <= WARM_WALL_GATE_S,
    all(measured$peak_ws_mib <= WARM_WS_GATE_MIB),
    !any(nzchar(warm$killed)),
    !nzchar(cold$killed)
  )
  if (!all(checks)) stop("One or more registered availability closeout checks failed.", call. = FALSE)
  write_summary(out_dir, cold, warm, lanes)
  cat(sprintf("AVAILABILITY_RECORD_PREFIX=%s\n", normalizePath(out_dir, winslash = "/")))
  cat(sprintf(
    "WARM_MEDIAN_SECONDS=%.2f WARM_SPREAD_SECONDS=%.2f WARM_MAX_PEAK_MIB=%.1f\n",
    stats::median(measured$wall_seconds), diff(range(measured$wall_seconds)), max(measured$peak_ws_mib)
  ))
}

if (length(args) && identical(args[[1L]], "--child-seal")) {
  child_seal(args[[2L]], args[[3L]], args[[4L]])
} else if (length(args) && identical(args[[1L]], "--child-warm")) {
  profile <- if (length(args) >= 7L) args[[6L]] else NULL
  output <- args[[length(args)]]
  child_warm(args[[2L]], args[[3L]], args[[4L]], args[[5L]], output, profile)
} else {
  mode <- if (length(args)) args[[1L]] else "all"
  if (!identical(mode, "all")) stop("Only parent mode `all` is supported.", call. = FALSE)
  head <- system2("git", c("-C", shQuote(repo_root), "rev-parse", "--short=7", "HEAD"), stdout = TRUE)
  default_out <- file.path(repo_root, "dev", "bench", "results", paste0("v0_2_0_1_batch8_availability_", head))
  out_dir <- normalizePath(arg_value("--out-dir", default_out), winslash = "/", mustWork = FALSE)
  run_parent(out_dir)
}
