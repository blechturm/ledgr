args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 4L) stop("Usage: measure_surface.R <source-root> <build.csv> <surface> <output.csv>")
source_root <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
meta <- utils::read.csv(args[[2L]], stringsAsFactors = FALSE)
surface <- args[[3L]]; output <- args[[4L]]
.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
pkgload::load_all(source_root, quiet = TRUE)
snapshot <- ledgr_snapshot_open(meta$store[[1L]], meta$snapshot_id[[1L]])
on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
bt <- ledgr_run_open(snapshot, meta$run_id[[1L]])
on.exit(close(bt), add = TRUE)

validator_calls <- 0L; validator_elapsed <- 0
ns <- asNamespace("ledgr")
if (exists("ledgr_diagnostic_decision_order_bad", envir = ns, inherits = FALSE)) {
  original <- get("ledgr_diagnostic_decision_order_bad", envir = ns, inherits = FALSE)
  replacement <- function(...) {
    validator_calls <<- validator_calls + 1L
    started <- proc.time()[["elapsed"]]
    on.exit(validator_elapsed <<- validator_elapsed + (proc.time()[["elapsed"]] - started), add = TRUE)
    original(...)
  }
  utils::assignInNamespace("ledgr_diagnostic_decision_order_bad", replacement, ns = "ledgr")
  on.exit(utils::assignInNamespace("ledgr_diagnostic_decision_order_bad", original, ns = "ledgr"), add = TRUE)
}

started <- proc.time()[["elapsed"]]
value <- switch(
  surface,
  print = capture.output(print(bt)),
  summary = summary(bt),
  point_explain = ledgr_run_explain(
    bt,
    meta$instrument_id[[1L]],
    as.POSIXct(
      meta$ts_utc[[1L]],
      format = "%Y-%m-%dT%H:%M:%OSZ",
      tz = "UTC"
    )
  ),
  history_explain = ledgr_run_explain(bt, meta$instrument_id[[1L]]),
  diagnostics = ledgr_results(bt, "diagnostics"),
  metrics = ledgr_compute_metrics(bt),
  stop("Unknown surface: ", surface)
)
elapsed <- proc.time()[["elapsed"]] - started
memory <- ps::ps_memory_info(ps::ps_handle())
digest_value <- value
if (is.data.frame(digest_value) && "run_id" %in% names(digest_value)) {
  digest_value$run_id <- "<run>"
}
record <- data.frame(
  label = meta$label[[1L]], source_commit = meta$source_commit[[1L]], surface = surface,
  elapsed_sec = elapsed, validator_calls = validator_calls, validator_elapsed_sec = validator_elapsed,
  result_bytes = as.numeric(object.size(value)),
  result_sha256 = digest::digest(
    digest_value, algo = "sha256", serialize = TRUE
  ),
  peak_wset_mib = memory[["peak_wset"]] / 2^20,
  peak_private_mib = memory[["peak_pagefile"]] / 2^20, stringsAsFactors = FALSE
)
utils::write.csv(record, output, row.names = FALSE); print(record)
