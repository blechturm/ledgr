# A0 baseline timing (descriptive, not a gate). For each workload: wall time
# of the committed-run path (ledgr_run over every candidate) and the sweep
# path (ledgr_sweep, one worker, same grid), three alternating repetitions,
# medians and the run/sweep ratio (inventory H6). The snapshot is built once
# per workload and reused (warm clock); one untimed sweep and run warm up
# first. Writes timing.csv and timing_host.txt next to this script.
#
# Usage: Rscript timing.R [--reps=3] [--pkg=<root>]

local({
  file_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  here <- if (length(file_arg)) dirname(sub("^--file=", "", file_arg[[1L]])) else getwd()
  source(file.path(here, "lib.R"))
})
pkg <- a0_load()
here <- a0_script_dir()
reps <- as.integer(a0_arg("reps", "3"))
work_dir <- file.path(tempdir(), "a0_timing_work")
dir.create(work_dir, recursive = TRUE, showWarnings = FALSE)

# Timing-only scale workload: the record fixtures have 3 to 10 bars, so their
# times are per-call overhead. This one has 20 instruments x 252 sessions
# (deterministic prices, no RNG), an SMA(20) feature and a cost model.
a0_fx_timing_scale <- function(db_path) {
  days <- 252L
  ids <- sprintf("I%02d", 1:20)
  ts <- as.POSIXct("2019-01-01", tz = "UTC") + 86400 * (seq_len(days) - 1L)
  bars <- do.call(rbind, lapply(seq_along(ids), function(j) {
    close <- 100 * exp(cumsum(0.01 * sin(seq_len(days) * (0.05 + j / 97) + j)))
    data.frame(instrument_id = ids[[j]], ts_utc = ts, open = close * 0.999, high = close * 1.01,
      low = close * 0.99, close = close, volume = 1e5, stringsAsFactors = FALSE)
  }))
  snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path, snapshot_id = "a0_timing_scale")
  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    for (id in ctx$universe) {
      sma <- ctx$feature(id, "sma_20")
      if (!is.na(sma) && ctx$close(id) > sma) targets[[id]] <- params$qty
    }
    targets
  }
  exp <- ledgr_experiment(snapshot, strategy, features = list(ledgr_ind_sma(20)),
    opening = ledgr_opening(cash = 1e6), cost_model = ledgr_cost_spread_bps(5))
  grid <- ledgr_grid_named(q10 = list(strategy = list(qty = 10)), q20 = list(strategy = list(qty = 20)))
  list(snapshot = snapshot, exp = exp, grid = grid, seed = 7L)
}

# The failures workload ends runs by design and is not timed.
timed <- Filter(function(w) !isFALSE(w$timing), a0_workloads)
fixtures <- c(lapply(timed, `[[`, "fixture"), list(timing_scale = a0_fx_timing_scale))

elapsed <- function(expr) {
  start <- proc.time()[["elapsed"]]
  force(expr)
  proc.time()[["elapsed"]] - start
}

time_workload <- function(id, fixture) {
  db_path <- file.path(work_dir, paste0(id, ".duckdb"))
  if (file.exists(db_path)) unlink(db_path)
  fx <- fixture(db_path)
  on.exit(ledgr_snapshot_close(fx$snapshot), add = TRUE)
  options(ledgr.interrupt = FALSE)
  sweep_path <- function() ledgr_sweep(fx$exp, fx$grid, seed = fx$seed, retain = a0_retain())
  sw <- suppressWarnings(sweep_path())
  run_path <- function(tag) {
    for (i in seq_len(nrow(sw))) {
      bt <- suppressWarnings(ledgr_run(fx$exp, params = sw$params[[i]], feature_params = sw$feature_params[[i]],
        run_id = paste("t", id, sw$candidate_id[[i]], tag, sep = "-"), seed = sw$execution_seed[[i]]))
      close(bt)
    }
  }
  run_path("warm")
  run <- numeric(reps); sweep <- numeric(reps)
  for (r in seq_len(reps)) {
    # Alternate which path goes first so drift does not favour one path.
    if (r %% 2L == 1L) {
      run[[r]] <- elapsed(run_path(r))
      sweep[[r]] <- elapsed(suppressWarnings(sweep_path()))
    } else {
      sweep[[r]] <- elapsed(suppressWarnings(sweep_path()))
      run[[r]] <- elapsed(run_path(r))
    }
  }
  data.frame(workload = id, candidates = nrow(sw),
    run_reps = paste(sprintf("%.2f", run), collapse = ";"),
    sweep_reps = paste(sprintf("%.2f", sweep), collapse = ";"),
    run_median_sec = sprintf("%.2f", stats::median(run)),
    sweep_median_sec = sprintf("%.2f", stats::median(sweep)),
    run_over_sweep = sprintf("%.2f", stats::median(run) / stats::median(sweep)),
    stringsAsFactors = FALSE)
}

host_cmd <- function(cmd, args) {
  out <- tryCatch(suppressWarnings(system2(cmd, args, stdout = TRUE, stderr = TRUE)), error = function(e) conditionMessage(e))
  trimws(out[nzchar(trimws(out))])
}
ps <- function(script) host_cmd("powershell", c("-NoProfile", "-Command", shQuote(script, type = "cmd")))
host_before <- c(
  sprintf("date: %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
  sprintf("R: %s", R.version.string),
  sprintf("ledgr: %s (pkgload from %s, HEAD %s)", as.character(utils::packageVersion("ledgr")), pkg,
    paste(host_cmd("git", c("-C", pkg, "rev-parse", "--short", "HEAD")), collapse = "")),
  sprintf("duckdb: %s; collapse: %s; mirai: %s", utils::packageVersion("duckdb"), utils::packageVersion("collapse"),
    tryCatch(as.character(utils::packageVersion("mirai")), error = function(e) "absent")),
  sprintf("logical cores: %d", parallel::detectCores()),
  paste("cpu:", ps("(Get-CimInstance Win32_Processor).Name")),
  paste("power plan:", host_cmd("powercfg", "/getactivescheme")),
  "top processes by CPU seconds before timing:",
  paste("  ", ps("Get-Process | Sort-Object CPU -Descending | Select-Object -First 8 Name,CPU,@{n='WS_MB';e={[int]($_.WS/1MB)}} | Format-Table -HideTableHeaders | Out-String -Width 120")),
  paste("cpu load % (1 s sample):", ps("[int](Get-CimInstance Win32_Processor | Measure-Object LoadPercentage -Average).Average"))
)
cat(host_before, sep = "\n")

rows <- lapply(names(fixtures), function(id) {
  cat("timing", id, "\n")
  time_workload(id, fixtures[[id]])
})
timing <- do.call(rbind, rows)
print(timing, row.names = FALSE)
a0_write_table(timing, file.path(here, "timing.csv"))
host_after <- paste("cpu load % after timing (1 s sample):",
  ps("[int](Get-CimInstance Win32_Processor | Measure-Object LoadPercentage -Average).Average"))
writeLines(c(host_before, host_after), file.path(here, "timing_host.txt"), useBytes = TRUE)
