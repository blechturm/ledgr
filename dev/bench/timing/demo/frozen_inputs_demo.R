# Shared timing harness (LDG-3155, review round 1 F3): frozen inputs.
#
# Starts a real smoke-1 window (A/A at HEAD, --host-policy=record; not timing
# evidence) and, while it runs:
#   1. after slot 4, edits the live harness and protocol: measure.R gains a
#      stop() and workloads.R redefines small_dense to report work "EDITED".
#      Had any later slot executed the live files, it would fail or report
#      that work; the frozen copies keep every later slot unchanged.
#   2. after slot 18, appends a comment to the attempt's frozen workloads.R.
#      Behaviour is unchanged, but the final integrity check must find the
#      departure from the commit and mark the attempt invalid.
# The live files are restored with git checkout whatever happens. Writes
# demo/frozen_inputs_demo_results.csv; exits 1 unless both hold.
#
# Launch like the runner, from one PowerShell call that pins affinity first:
#   [System.Diagnostics.Process]::GetCurrentProcess().ProcessorAffinity = [IntPtr]0xFFFF; `
#   & "C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe" dev/bench/timing/demo/frozen_inputs_demo.R

here <- normalizePath(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]])),
  winslash = "/")
harness <- dirname(here)
repo <- normalizePath(file.path(harness, "..", "..", ".."), winslash = "/")
source(file.path(harness, "protocol.R"))
label_dir <- file.path(harness, "records", "smoke-1", "frozen-inputs-demo")
if (dir.exists(label_dir)) stop("frozen_inputs_demo.R: ", label_dir, " exists; records are never overwritten")
live_measure <- file.path(harness, "measure.R")
live_workloads <- file.path(harness, "protocols", "smoke-1", "workloads.R")
restore <- function() system2("git", c("-C", shQuote(repo), "checkout", "--", "dev/bench/timing/measure.R",
  "dev/bench/timing/protocols/smoke-1/workloads.R"))

head <-system2("git", c("-C", shQuote(repo), "rev-parse", "HEAD"), stdout = TRUE)
log <- file.path(tempdir(), "runner.log")
system2(file.path(R.home("bin"), "Rscript"), c(shQuote(file.path(harness, "runner.R")),
  shQuote(paste0("--protocol=", file.path(harness, "protocols", "smoke-1"))), paste0("--base=", head),
  paste0("--candidate=", head), "--label=frozen-inputs-demo", "--host-policy=record"),
  stdout = log, stderr = log, wait = FALSE)

attempt <- file.path(label_dir, "attempt-1")
rows_done <- function() {
  path <- file.path(attempt, "raw.csv")
  if (file.exists(path)) nrow(timing_read_csv(path)) else 0L
}
status <- function() {
  path <- file.path(attempt, "session.csv")
  if (file.exists(path)) timing_read_kv(path)$status else "starting"
}
wait_for <- function(done, limit = 1800) {
  t0 <- Sys.time()
  while (!done()) {
    if (as.numeric(Sys.time() - t0, units = "secs") > limit) stop("frozen_inputs_demo.R: timed out; see ", log)
    Sys.sleep(1)
  }
}

tryCatch({
  wait_for(function() rows_done() >= 4L)
  cat("\nstop(\"live measure.R was executed\")\n", file = live_measure, append = TRUE)
  cat("\nsmall_dense <- function(args, work_dir) list(seconds = c(cold = 1, warm = 1), work = \"EDITED\")\n",
    file = live_workloads, append = TRUE)
  edited_after <- rows_done()
  message("live files edited after ", edited_after, " slots")

  wait_for(function() rows_done() >= 18L)
  cat("# edited during the window\n", file = file.path(attempt, "protocol", "workloads.R"), append = TRUE)
  frozen_after <- rows_done()
  message("frozen workloads.R edited after ", frozen_after, " slots")

  wait_for(function() !status() %in% c("starting", "running"))
}, finally = restore())
raw <- timing_read_csv(file.path(attempt, "raw.csv"))
session <- timing_read_kv(file.path(attempt, "session.csv"))
later <- raw[as.integer(raw$seq) > edited_after & !is.na(raw$seq), , drop = FALSE]
results <- data.frame(
  check = c("slots after the live edit", "of which ok with work 1240;1240", "slots after the frozen-copy edit",
    "final status", "inputs_end"),
  value = c(nrow(later), sum(later$outcome == "ok" & later$work == "1240;1240"),
    sum(as.integer(raw$seq) > frozen_after, na.rm = TRUE), session$status, session$inputs_end),
  stringsAsFactors = FALSE)
utils::write.csv(results, file.path(here, "frozen_inputs_demo_results.csv"), row.names = FALSE, fileEncoding = "UTF-8")
print(results, row.names = FALSE, right = FALSE)
held <- nrow(later) > 0L && all(later$outcome == "ok" & later$work == "1240;1240") &&
  identical(session$status, "invalid") && grepl("workloads.R", session$inputs_end)
quit(save = "no", status = if (held) 0L else 1L)
