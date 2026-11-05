args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 3L) {
  stop("Usage: measure_sequence.R <source-root> <build.csv> <output.csv>")
}
source_root <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
meta <- utils::read.csv(args[[2L]], stringsAsFactors = FALSE)
output <- args[[3L]]
.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
pkgload::load_all(source_root, quiet = TRUE)
snapshot <- ledgr_snapshot_open(meta$store[[1L]], meta$snapshot_id[[1L]])
on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
bt <- ledgr_run_open(snapshot, meta$run_id[[1L]])
on.exit(close(bt), add = TRUE)

validator_calls <- 0L
validator_elapsed <- 0
ns <- asNamespace("ledgr")
original <- get("ledgr_diagnostic_decision_order_bad", envir = ns, inherits = FALSE)
replacement <- function(...) {
  validator_calls <<- validator_calls + 1L
  started <- proc.time()[["elapsed"]]
  on.exit(
    validator_elapsed <<- validator_elapsed +
      (proc.time()[["elapsed"]] - started),
    add = TRUE
  )
  original(...)
}
utils::assignInNamespace(
  "ledgr_diagnostic_decision_order_bad",
  replacement,
  ns = "ledgr"
)
on.exit(
  utils::assignInNamespace(
    "ledgr_diagnostic_decision_order_bad",
    original,
    ns = "ledgr"
  ),
  add = TRUE
)

started <- proc.time()[["elapsed"]]
invisible(capture.output(print(bt)))
invisible(summary(bt))
invisible(ledgr_run_explain(
  bt,
  meta$instrument_id[[1L]],
  as.POSIXct(meta$ts_utc[[1L]], tz = "UTC")
))
invisible(ledgr_run_explain(bt, meta$instrument_id[[1L]]))
invisible(ledgr_compute_metrics(bt))
diagnostics <- ledgr_results(bt, "diagnostics")
elapsed <- proc.time()[["elapsed"]] - started
memory <- ps::ps_memory_info(ps::ps_handle())
source_commit_file <- file.path(source_root, "SOURCE_COMMIT")
source_commit_override <- Sys.getenv("LEDGR_SOURCE_COMMIT", unset = "")
source_commit <- if (nzchar(source_commit_override)) {
  source_commit_override
} else if (file.exists(source_commit_file)) {
  readLines(source_commit_file, n = 1L, warn = FALSE)
} else {
  system2(
    "git",
    c("-c", "safe.directory=*", "-C", shQuote(source_root),
      "rev-parse", "HEAD"),
    stdout = TRUE
  )[[1L]]
}
record <- data.frame(
  label = meta$label[[1L]],
  source_commit = source_commit,
  surface = "same_handle_sequence",
  elapsed_sec = elapsed,
  validator_calls = validator_calls,
  validator_elapsed_sec = validator_elapsed,
  result_bytes = as.numeric(object.size(diagnostics)),
  result_sha256 = digest::digest(
    diagnostics, algo = "sha256", serialize = TRUE
  ),
  peak_wset_mib = memory[["peak_wset"]] / 2^20,
  peak_private_mib = memory[["peak_pagefile"]] / 2^20,
  stringsAsFactors = FALSE
)
utils::write.csv(record, output, row.names = FALSE)
print(record)
