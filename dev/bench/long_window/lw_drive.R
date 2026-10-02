lw_work <- Sys.getenv("LW_WORK", "C:/tmp/ledgr-lw-work")
# Long-window scaling reproducer: build (cached) and run one configuration under
# an external working-set sampler, appending one row to results.csv.
# Rscript lw_drive.R <repo> <label> sessions instruments members sets churn terminals \
#   <strategy> <wall_ceiling_s> [profile:0|1]
args <- commandArgs(TRUE)
repo <- normalizePath(args[[1]], winslash = "/")
label <- args[[2]]
cfg <- as.list(args[3:8]); names(cfg) <- c("sessions", "instruments", "members", "sets", "churn", "terminals")
strategy <- args[[9]]; wall <- as.numeric(args[[10]])
profile <- length(args) >= 11 && identical(args[[11]], "1")
n_runs <- if (length(args) >= 12) as.integer(args[[12]]) else 1L
work <- lw_work
script_dir <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1]]), winslash = "/"))
rscript <- file.path(R.home("bin"), "Rscript.exe")
snap_dir <- file.path(work, "snapshots", paste(unlist(cfg), collapse = "_"))
build_json <- file.path(snap_dir, "build.json")
if (!file.exists(build_json)) {
  cat("building", snap_dir, "\n")
  out <- system2(rscript, c(file.path(script_dir, "lw_build.R"), repo, snap_dir, unlist(cfg)), stdout = TRUE, stderr = TRUE)
  if (!file.exists(build_json)) { cat(tail(out, 20), sep = "\n"); stop("build failed") }
}
build <- jsonlite::read_json(build_json)

# Fresh copy of the sealed snapshot so every run starts from the same store.
run_db <- file.path(work, "runs", paste0(label, ".duckdb"))
dir.create(dirname(run_db), showWarnings = FALSE)
unlink(c(run_db, paste0(run_db, ".wal")))
file.copy(file.path(snap_dir, "snapshot.duckdb"), run_db)

sampler <- '
param([string]$Exe, [string]$ChildArgsJoined, [string]$Marker,
      [double]$WallCeilingS, [double]$WsCeilingMiB, [int]$IntervalMs = 200)
$childArgs = $ChildArgsJoined.Split("|")
$p = Start-Process -FilePath $Exe -ArgumentList $childArgs -PassThru -WindowStyle Hidden
if ($null -eq $p) { Write-Output "KILLED=start_failed"; exit 1 }
$null = $p.Handle
$peak = 0; $killed = ""; $runStart = $null; $wsAtStart = 0
while (-not $p.HasExited) {
  try {
    $p.Refresh(); $ws = $p.WorkingSet64; $pk = $p.PeakWorkingSet64
    if ($pk -gt $peak) { $peak = $pk }
    if ($null -eq $runStart -and (Test-Path $Marker)) { $runStart = Get-Date; $wsAtStart = $ws }
    if ($WsCeilingMiB -gt 0 -and ($ws / 1MB) -gt $WsCeilingMiB) { $killed = "working_set"; $p.Kill() }
    if ($WallCeilingS -gt 0 -and $null -ne $runStart -and
        ((Get-Date) - $runStart).TotalSeconds -gt $WallCeilingS) { $killed = "wall"; $p.Kill() }
  } catch {}
  Start-Sleep -Milliseconds $IntervalMs
}
$p.WaitForExit()
$elapsed = if ($null -ne $runStart) { ((Get-Date) - $runStart).TotalSeconds } else { -1 }
Write-Output ("PEAK_WS_BYTES=" + $peak)
Write-Output ("WS_AT_START_BYTES=" + $wsAtStart)
Write-Output ("KILLED=" + $killed)
Write-Output ("RUN_ELAPSED_S=" + $elapsed)
Write-Output ("CHILD_EXIT=" + $p.ExitCode)
'
ps1 <- tempfile("lw_sampler_", fileext = ".ps1"); writeLines(sampler, ps1)
marker <- tempfile("lw_marker_"); out_json <- file.path(work, "runs", paste0(label, ".json"))
prof_file <- if (profile) file.path(work, "profiles", paste0(label, ".Rprof")) else ""
if (profile) dir.create(dirname(prof_file), showWarnings = FALSE)
unlink(out_json)
child <- paste(c(file.path(script_dir, "lw_run.R"), repo, run_db, strategy, marker, out_json, if (nzchar(prof_file)) prof_file else "none", n_runs), collapse = "|")
dq <- function(x) shQuote(x, type = "cmd")
o <- system2("powershell", c("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", dq(ps1),
  "-Exe", dq(rscript), "-ChildArgsJoined", dq(child), "-Marker", dq(marker),
  "-WallCeilingS", format(wall), "-WsCeilingMiB", "12000", "-IntervalMs", "200"), stdout = TRUE, stderr = TRUE)
grab <- function(key) { v <- grep(paste0("^", key, "="), o, value = TRUE); if (!length(v)) NA_character_ else sub(paste0("^", key, "="), "", v[[1]]) }
run <- if (file.exists(out_json)) jsonlite::read_json(out_json) else list(runs = list(list()))
rows <- lapply(seq_along(run$runs), function(k) {
  r <- run$runs[[k]]
  data.frame(
    label = label, repo = basename(repo), strategy = strategy, run = k,
    sessions = build$sessions, instruments = build$instruments, members = build$members,
    sets = build$sets, churn = build$churn, terminals = build$terminals,
    bar_rows = build$bar_rows, membership_rows = build$membership_rows, seal_s = round(build$seal_s, 1),
    killed = grab("KILLED"), process_wall_s = round(as.numeric(grab("RUN_ELAPSED_S")), 1),
    elapsed_s = round(r$elapsed_s %||% NA, 1), cpu_s = round(r$cpu_s %||% NA, 1),
    setup_s = round(r$setup_s %||% NA, 1), loop_s = round(r$loop_s %||% NA, 1),
    finalize_s = round(r$finalize_s %||% NA, 1),
    loop_ms_per_pulse = round(1000 * (r$loop_s %||% NA) / build$sessions, 2),
    calls = r$calls %||% NA, decisions = r$decisions %||% NA,
    peak_ws_mib = round(as.numeric(grab("PEAK_WS_BYTES")) / 1024^2),
    ws_at_start_mib = round(as.numeric(grab("WS_AT_START_BYTES")) / 1024^2),
    run_status = r$run_status %||% NA, r_status = r$r_status %||% NA,
    ledger_events = r$rows$ledger_events %||% NA, equity_rows = r$rows$equity_curve %||% NA,
    diagnostics = r$rows$run_diagnostics %||% NA, state_rows = r$rows$strategy_state %||% NA,
    feature_rows_run = r$rows$features %||% NA, feature_rows_total = run$feature_rows_total %||% NA,
    when = format(Sys.time(), "%Y-%m-%d %H:%M:%S"), stringsAsFactors = FALSE)
})
row <- do.call(rbind, rows)
res_csv <- file.path(work, "results.csv")
write.table(row, res_csv, sep = ",", row.names = FALSE, col.names = !file.exists(res_csv), append = file.exists(res_csv))
print(t(row))
unlink(c(ps1, marker, run_db, paste0(run_db, ".wal")))
