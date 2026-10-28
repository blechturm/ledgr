# WS1 timing protocol (LDG-3127): one measurement in one fresh R process.
# Called by runner.R only. Loads the arm's installed ledgr from --lib, builds
# the workload's snapshot in a fresh DuckDB file, runs the declared untimed
# warmup, then times exactly one execution of the requested path and writes
# one CSV row. Errors are recorded in the row, never retried.
#
# Usage: Rscript --no-init-file measure.R --root=<protocol tree> --lib=<arm library>
#   --arm=base|candidate --pair=<k> --seq=<n> --workload=<id> --path=run|sweep
#   --work=<dir> --out=<row csv>

args <- commandArgs(trailingOnly = TRUE)
arg <- function(name) {
  hit <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (length(hit) != 1L) stop(sprintf("measure.R: --%s is required once", name), call. = FALSE)
  sub(paste0("^--", name, "="), "", hit)
}

# The record is one environment so that an error keeps every field already set.
rec <- new.env(parent = emptyenv())
rec$seq <- as.integer(arg("seq")); rec$pair <- as.integer(arg("pair")); rec$arm <- arg("arm")
rec$workload <- arg("workload"); rec$path <- arg("path")
rec$seconds <- NA_real_; rec$outcome <- "error"; rec$error <- NA_character_
rec$candidates <- NA_integer_; rec$statuses <- NA_character_; rec$n_trades <- NA_real_
rec$pid <- Sys.getpid(); rec$affinity <- NA_real_; rec$power_plan_guid <- NA_character_
rec$ledgr_path <- NA_character_; rec$ledgr_version <- NA_character_
rec$started_utc <- format(Sys.time(), "%Y-%m-%dT%H:%M:%OS3Z", tz = "UTC")
fields <- c("seq", "pair", "arm", "workload", "path", "seconds", "outcome", "error", "candidates",
  "statuses", "n_trades", "pid", "affinity", "power_plan_guid", "ledgr_path", "ledgr_version", "started_utc")

host_probe <- function() {
  plan <- tryCatch(suppressWarnings(system2("powercfg", "/getactivescheme", stdout = TRUE, stderr = TRUE)),
    error = function(e) "")
  guid <- regmatches(plan, regexpr("[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}", plan))
  aff <- tryCatch(suppressWarnings(system2("powershell", c("-NoProfile", "-Command",
    shQuote(sprintf("(Get-Process -Id %d).ProcessorAffinity.ToInt64()", Sys.getpid()), type = "cmd")),
    stdout = TRUE, stderr = TRUE)), error = function(e) NA_character_)
  aff <- suppressWarnings(as.numeric(trimws(aff[nzchar(trimws(aff))])[1L]))
  list(guid = if (length(guid)) guid[[1L]] else NA_character_, affinity = aff)
}

# Wall clock with sub-millisecond resolution. proc.time()[["elapsed"]] ticks in
# 10 ms steps on Windows, which is 5% of the smallest cells.
ws1_clock <- function() as.numeric(Sys.time())

measure <- function(rec) {
  root <- arg("root"); lib <- arg("lib"); work <- arg("work")
  if (!rec$path %in% c("run", "sweep")) stop("unknown path ", rec$path, call. = FALSE)
  host <- host_probe()
  rec$power_plan_guid <- host$guid
  rec$affinity <- host$affinity

  suppressPackageStartupMessages(library(ledgr, lib.loc = lib))
  rec$ledgr_path <- normalizePath(find.package("ledgr"), winslash = "/")
  rec$ledgr_version <- as.character(utils::packageVersion("ledgr", lib.loc = lib))
  if (!startsWith(tolower(rec$ledgr_path), tolower(normalizePath(lib, winslash = "/")))) {
    stop("ledgr was not loaded from the arm library", call. = FALSE)
  }

  sys.source(file.path(root, "dev", "bench", "v0_2_3_ws1_timing", "matrix.R"), envir = globalenv())
  spec <- ws1_timing_fixture(root, rec$workload, envir = globalenv())

  # Untimed preparation, identical in both arms and both paths: a fresh
  # snapshot, one sweep (which also yields each candidate's params and
  # execution seed), and one committed run per candidate.
  db_path <- file.path(work, sprintf("m%04d.duckdb", rec$seq))
  if (file.exists(db_path)) unlink(db_path)
  fx <- spec$fixture(db_path)
  on.exit(ledgr_snapshot_close(fx$snapshot), add = TRUE)
  options(ledgr.interrupt = FALSE)
  sweep_path <- function() ledgr_sweep(fx$exp, fx$grid, seed = fx$seed, retain = spec$retain())
  sw <- suppressWarnings(sweep_path())
  run_path <- function(tag) {
    for (i in seq_len(nrow(sw))) {
      bt <- suppressWarnings(ledgr_run(fx$exp, params = sw$params[[i]], feature_params = sw$feature_params[[i]],
        run_id = paste("ws1", tag, sw$candidate_id[[i]], sep = "-"), seed = sw$execution_seed[[i]]))
      close(bt)
    }
  }
  run_path("warm")
  invisible(gc())

  # Timed section. Clock endpoints: ws1_clock() immediately before the first
  # ledgr_run() or the ledgr_sweep() call, immediately after the last close()
  # or the ledgr_sweep() return.
  if (identical(rec$path, "run")) {
    t0 <- ws1_clock()
    run_path("timed")
    t1 <- ws1_clock()
    runs <- as.data.frame(ledgr_run_list(fx$snapshot))
    hit <- match(paste("ws1", "timed", sw$candidate_id, sep = "-"), runs$run_id)
    statuses <- as.character(runs$status[hit])
    trades <- sum(as.numeric(runs$n_trades[hit]))
  } else {
    t0 <- ws1_clock()
    timed <- suppressWarnings(sweep_path())
    t1 <- ws1_clock()
    statuses <- as.character(timed$status)
    trades <- sum(as.numeric(timed$n_trades))
  }
  rec$seconds <- t1 - t0
  rec$candidates <- length(statuses)
  rec$statuses <- paste(statuses, collapse = ";")
  rec$n_trades <- trades
  rec$outcome <- "ok"
  invisible(NULL)
}

tryCatch(measure(rec), error = function(e) {
  rec$outcome <- "error"
  rec$error <- gsub("[\r\n]+", " ", conditionMessage(e))
})

row <- as.data.frame(mget(fields, envir = rec), stringsAsFactors = FALSE)
for (f in c("seconds", "n_trades", "affinity")) row[[f]] <- sprintf("%.17g", row[[f]])
utils::write.csv(row, arg("out"), row.names = FALSE, na = "NA", fileEncoding = "UTF-8")
