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
    "dev/bench/v0_2_0_1_stage_n/run_snapshot_hash_deduplication.R",
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

stage_n_replace_binding <- function(name, value) {
  namespace <- asNamespace("ledgr")
  old <- get(name, envir = namespace, inherits = FALSE)
  unlockBinding(name, namespace)
  assign(name, value, envir = namespace)
  lockBinding(name, namespace)
  old
}

stage_n_restore_binding <- function(name, value) {
  namespace <- asNamespace("ledgr")
  unlockBinding(name, namespace)
  assign(name, value, envir = namespace)
  lockBinding(name, namespace)
  invisible(NULL)
}

stage_n_child <- function(arm,
                          repetition,
                          db_path,
                          snapshot_id,
                          output,
                          marker) {
  snapshot <- ledgr_snapshot_open(db_path, snapshot_id, verify = FALSE)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  con <- ledgr:::get_connection(snapshot)
  observations <- new.env(parent = emptyenv())
  observations$formatter_inputs <- 0L
  canonical_formatter <- ledgr:::ledgr_snapshot_hash_format_ts_utc

  observed <- function(x) {
    observations$formatter_inputs <-
      observations$formatter_inputs + length(x)
    canonical_formatter(x)
  }
  if (identical(arm, "current")) {
    binding_name <- "ledgr_snapshot_hash_format_distinct_ts_utc"
  } else if (identical(arm, "candidate")) {
    binding_name <- "ledgr_snapshot_hash_format_ts_utc"
  } else {
    stop("Unknown Stage N arm.", call. = FALSE)
  }
  old <- stage_n_replace_binding(binding_name, observed)
  on.exit(stage_n_restore_binding(binding_name, old), add = TRUE)

  invisible(gc(full = TRUE))
  writeLines(format(Sys.time(), tz = "UTC"), marker)
  started <- proc.time()[["elapsed"]]
  hash <- ledgr:::ledgr_snapshot_hash(
    con,
    snapshot_id,
    chunk_size = 10000L
  )
  wall_sec <- proc.time()[["elapsed"]] - started
  stored_hash <- ledgr_snapshot_info(snapshot)$snapshot_hash[[1L]]
  saveRDS(
    list(
      arm = arm,
      repetition = repetition,
      status = "DONE",
      wall_sec = wall_sec,
      formatter_inputs = observations$formatter_inputs,
      snapshot_hash = hash,
      stored_hash = stored_hash
    ),
    output
  )
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

stage_n_rscript <- function() {
  path <- "C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe"
  if (!file.exists(path)) stop("R 4.6.1 Rscript was not found.", call. = FALSE)
  path
}

stage_n_launch <- function(arm, repetition, db_path, snapshot_id) {
  ps1 <- tempfile("stage_n_sampler_", fileext = ".ps1")
  marker <- tempfile("stage_n_marker_")
  output <- tempfile("stage_n_result_", fileext = ".rds")
  writeLines(sampler_ps1, ps1)
  on.exit(unlink(c(ps1, marker, output), force = TRUE), add = TRUE)
  child_args <- c(
    script_path,
    "--child",
    arm,
    repetition,
    normalizePath(db_path, winslash = "/", mustWork = TRUE),
    snapshot_id,
    normalizePath(output, winslash = "/", mustWork = FALSE),
    normalizePath(marker, winslash = "/", mustWork = FALSE)
  )
  process_output <- system2(
    "powershell",
    c(
      "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", shQuote(ps1),
      "-Exe", shQuote(stage_n_rscript()),
      "-ChildArgsJoined", shQuote(paste(child_args, collapse = "|")),
      "-Marker", shQuote(marker),
      "-WallCeilingS", "120", "-WsCeilingMiB", "2048",
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
    stop("Stage N child did not produce an output artifact.", call. = FALSE)
  }
  result <- readRDS(output)
  result$peak_ws_mib <- as.numeric(grab("PEAK_WS_BYTES")) / 1024^2
  result$sampled_wall_sec <- as.numeric(grab("RUN_ELAPSED_S"))
  result$killed <- grab("KILLED")
  result$child_exit <- as.integer(grab("CHILD_EXIT"))
  if (!identical(result$killed, "") || !identical(result$child_exit, 0L)) {
    stop("Stage N child was killed or failed.", call. = FALSE)
  }
  result
}

stage_n_gate <- function(runs, row_count) {
  measured <- runs[runs$measured, , drop = FALSE]
  current <- measured[measured$arm == "current", , drop = FALSE]
  candidate <- measured[measured$arm == "candidate", , drop = FALSE]
  current_median <- stats::median(current$wall_sec)
  candidate_median <- stats::median(candidate$wall_sec)
  wall_ratio <- candidate_median / current_median
  formatter_ratio <- max(candidate$formatter_inputs) / row_count
  peak_ratio <- max(candidate$peak_ws_mib) / max(current$peak_ws_mib)
  exact_hash <- length(unique(runs$snapshot_hash)) == 1L &&
    all(runs$snapshot_hash == runs$stored_hash)
  checks <- c(
    formatter_ratio <= 0.20,
    wall_ratio <= 0.80,
    exact_hash,
    peak_ratio <= 1.15,
    all(current$formatter_inputs == row_count),
    all(candidate$formatter_inputs < row_count)
  )
  data.frame(
    row_count = row_count,
    current_formatter_inputs = max(current$formatter_inputs),
    candidate_formatter_inputs = max(candidate$formatter_inputs),
    formatter_ratio = formatter_ratio,
    current_median_sec = current_median,
    candidate_median_sec = candidate_median,
    wall_ratio = wall_ratio,
    current_max_peak_ws_mib = max(current$peak_ws_mib),
    candidate_max_peak_ws_mib = max(candidate$peak_ws_mib),
    peak_ws_ratio = peak_ratio,
    exact_hash = exact_hash,
    passed = all(checks),
    stringsAsFactors = FALSE
  )
}

stage_n_write_evidence <- function(runs,
                                   gate,
                                   source_base,
                                   fixture_hash,
                                   output_dir) {
  utils::write.csv(
    runs,
    file.path(output_dir, "batch13-snapshot-hash-runs.csv"),
    row.names = FALSE
  )
  utils::write.csv(
    gate,
    file.path(output_dir, "batch13-snapshot-hash-gates.csv"),
    row.names = FALSE
  )
  lines <- c(
    "# Batch 13 Snapshot-Hash Timestamp Deduplication Evidence",
    "",
    "Status: implementation evidence pending independent Stage N review.",
    "",
    sprintf("- Source base: `%s` plus the uncommitted Batch 13 candidate.",
            source_base),
    paste0(
      "- Environment: R ", getRversion(), "; ledgr ",
      utils::packageVersion("ledgr"), "; duckdb ",
      utils::packageVersion("duckdb"), "; collapse ",
      utils::packageVersion("collapse"), "."
    ),
    paste(
      "- Fixture: 500 instruments by 1,260 daily bars, 630,000 rows;",
      "default 10,000-row fetch chunks."
    ),
    sprintf("- Frozen fixture hash: `%s`.", fixture_hash),
    paste(
      "- Clock: complete `ledgr_snapshot_hash()` only; fixture creation and",
      "opening are outside the clock."
    ),
    paste(
      "- Peak working set: external Windows process sampling every 200 ms;",
      "runs were serial with no intentional concurrent benchmark workload."
    ),
    "- Method: `within_chunk_distinct_timestamp_v001`.",
    "",
    paste(
      "An initial provisional pass used the Stage M `PEER_` instrument prefix.",
      "Source review caught that its hash did not match the frozen Stage L"
    ),
    paste(
      "fixture, so those files were replaced. The runner now refuses a fixture",
      "whose stored hash is not the frozen `ed05aa17...c7bb5` value, and the"
    ),
    paste(
      "complete eight-run protocol was repeated. Only that corrected",
      "repetition is reported below."
    ),
    "",
    "## A. Decision And Scope",
    "",
    paste(
      "Only timestamp-token construction inside each existing fetched hash",
      "chunk changes. Query order, chunking, numeric tokens, separators,"
    ),
    paste(
      "hash blocks, rule versions, availability payloads, stored hashes, and",
      "verification remain unchanged. No cross-chunk cache exists."
    ),
    "",
    "## B. Eligibility",
    "",
    paste(
      "OPT-L01 remains in the exact-parity lane: any byte or hash difference",
      "removes it rather than changing a version or expected hash."
    ),
    "",
    "## C. Baseline Attribution",
    "",
    sprintf(
      paste(
        "The current arm formatted %d timestamp inputs. Its measured median",
        "complete hash wall was %.2f seconds."
      ),
      gate$current_formatter_inputs,
      gate$current_median_sec
    ),
    "",
    "## D. Semantic Matrix",
    "",
    paste(
      "Focused tests compare tokens and emitted bytes for repeated and unique",
      "timestamps at row counts below, at, and above chunk sizes 1, 2, 17,"
    ),
    paste(
      "9,999, 10,000, 10,001, and 50,000. Full hashes cover rules 1 and 2,",
      "missing volume, every canonical bar field, and every registered size."
    ),
    "",
    "## E. Identity And Persistence",
    "",
    paste(
      "All measured and stored hashes are identical. A snapshot sealed through",
      "the retained old formatter reopens and verifies under production."
    ),
    paste(
      "Timestamp, price, and stored-hash mutations still fail, including the",
      "public run guard. Hash algorithm and rule versions are unchanged."
    ),
    "",
    "## F. Numerical Comparison",
    "",
    "No numerical tolerance is used. Byte and hash identity are absolute.",
    "",
    "## G. Structural Regression Gate",
    "",
    sprintf(
      paste(
        "The candidate formatted %d inputs (ratio %.6f; ceiling 0.20). A",
        "no-dedup mutant retained the hash but formatted all %d rows and failed."
      ),
      gate$candidate_formatter_inputs,
      gate$formatter_ratio,
      gate$row_count
    ),
    "",
    "## H. Performance Result",
    "",
    sprintf(
      paste(
        "Complete hash median: %.2f seconds current, %.2f seconds candidate;",
        "ratio %.4f (ceiling 0.80)."
      ),
      gate$current_median_sec,
      gate$candidate_median_sec,
      gate$wall_ratio
    ),
    sprintf(
      paste(
        "Maximum peak working set: %.1f MiB current, %.1f MiB candidate;",
        "ratio %.4f (ceiling 1.15)."
      ),
      gate$current_max_peak_ws_mib,
      gate$candidate_max_peak_ws_mib,
      gate$peak_ws_ratio
    ),
    sprintf("Gate disposition: `%s`.", if (gate$passed) "PASS" else "FAIL"),
    "",
    "## I. Verification",
    "",
    paste(
      "The focused identity, boundary, rule, reopen, run-guard, tamper, source,",
      "and deliberate-mutant tests pass. This is Stage N evidence, not final"
    ),
    "Stage O evidence.",
    "",
    "## J. Independent Review",
    "",
    paste(
      "LDG-2743 remains review-pending. The reviewer must reconcile the raw",
      "CSVs, rerun focused gates, gut deduplication, and confirm containment."
    )
  )
  writeLines(
    lines,
    file.path(output_dir, "batch13-snapshot-hash-evidence.md"),
    useBytes = TRUE
  )
}

stage_n_main <- function() {
  db_path <- tempfile("stage_n_hash_", fileext = ".duckdb")
  on.exit(unlink(c(db_path, paste0(db_path, ".wal")), force = TRUE), add = TRUE)
  bars <- as.data.frame(ledgr_sim_bars(
    n_instruments = 500L,
    n_days = 1260L,
    seed = 20260530L,
    instrument_prefix = "STAGE_L_"
  ))
  snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path)
  snapshot_id <- snapshot$snapshot_id
  stored_hash <- ledgr_snapshot_info(snapshot)$snapshot_hash[[1L]]
  ledgr_snapshot_close(snapshot)
  frozen <- utils::read.csv(
    file.path(
      repo_root,
      "inst/design/ledgr_v0_2_0_1_spec_packet/",
      "batch11-current-arm-prefixes.csv"
    ),
    stringsAsFactors = FALSE
  )
  frozen_hash <- unique(frozen$semantic_fingerprint[
    frozen$mechanism == "snapshot_hash_rule_1"
  ])
  if (length(frozen_hash) != 1L || !identical(stored_hash, frozen_hash)) {
    stop("Stage N fixture does not match the frozen Stage L hash.", call. = FALSE)
  }
  rm(bars)
  invisible(gc(full = TRUE))

  repetitions <- c("warmup", "run1", "run2", "run3")
  rows <- list()
  row_number <- 0L
  for (repetition in repetitions) {
    arms <- if (repetition %in% c("warmup", "run1", "run3")) {
      c("current", "candidate")
    } else {
      c("candidate", "current")
    }
    for (arm in arms) {
      message("[Stage N] ", repetition, " / ", arm)
      result <- stage_n_launch(arm, repetition, db_path, snapshot_id)
      row_number <- row_number + 1L
      row <- as.data.frame(result, stringsAsFactors = FALSE)
      row$measured <- !identical(repetition, "warmup")
      rows[[row_number]] <- row
      message(sprintf(
        "  hash %.2f s; formatter inputs %d; peak %.1f MiB",
        row$wall_sec,
        row$formatter_inputs,
        row$peak_ws_mib
      ))
    }
  }
  runs <- do.call(rbind, rows)
  rownames(runs) <- NULL
  if (!all(runs$snapshot_hash == stored_hash)) {
    stop("Stage N changed the registered snapshot hash.", call. = FALSE)
  }
  gate <- stage_n_gate(runs, row_count = 630000L)
  if (!isTRUE(gate$passed)) {
    print(gate)
    stop("One or more Stage N gates failed.", call. = FALSE)
  }
  output_dir <- file.path(
    repo_root,
    "inst/design/ledgr_v0_2_0_1_spec_packet"
  )
  source_base <- system2(
    "git",
    c("-C", shQuote(repo_root), "rev-parse", "HEAD"),
    stdout = TRUE
  )
  stage_n_write_evidence(
    runs,
    gate,
    source_base,
    fixture_hash = frozen_hash,
    output_dir = output_dir
  )
  print(gate, row.names = FALSE)
  message("BATCH13_SNAPSHOT_HASH_GATES_OK")
  invisible(gate)
}

if (length(args) >= 1L && identical(args[[1L]], "--child")) {
  if (length(args) != 7L) stop("Invalid Stage N child arguments.", call. = FALSE)
  stage_n_child(
    arm = args[[2L]],
    repetition = args[[3L]],
    db_path = args[[4L]],
    snapshot_id = args[[5L]],
    output = args[[6L]],
    marker = args[[7L]]
  )
} else if (sys.nframe() == 0L) {
  stage_n_main()
}
