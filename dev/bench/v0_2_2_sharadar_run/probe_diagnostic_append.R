# Probe: cost of the sweep memory handler's diagnostic append
# (R/sweep.R handler$write_run_diagnostics) as the accumulated table grows.
# Calls the real handler with real 4096-row diagnostic chunks.
#
#   Rscript probe_diagnostic_append.R <ledgr_repo> <out_dir> <total_rows>
args <- commandArgs(trailingOnly = TRUE)
ledgr_repo <- normalizePath(args[[1L]], winslash = "/")
out_dir <- args[[2L]]
total_rows <- as.integer(args[[3L]])
.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
suppressMessages(pkgload::load_all(ledgr_repo, quiet = TRUE, compile = FALSE))
chunk_rows <- 4096L
cols <- ledgr:::ledgr_availability_diagnostic_columns(chunk_rows)
cols$run_id[] <- "probe"
cols$instrument_id[] <- sprintf("sharadar:permaticker:%06d", seq_len(chunk_rows))
cols$stage[] <- "decision"; cols$outcome[] <- "recorded"; cols$reason_code[] <- "decision_recorded"
cols$reasons[] <- "decision_recorded"
cols$ts_utc <- .POSIXct(rep(0, chunk_rows), tz = "UTC")
chunk <- as.data.frame(cols, stringsAsFactors = FALSE)
handler <- ledgr:::ledgr_memory_output_handler("probe")
n_chunks <- ceiling(total_rows / chunk_rows)
marks <- unique(round(seq(1, n_chunks, length.out = 12L)))
rows <- list()
t_all <- Sys.time()
for (k in seq_len(n_chunks)) {
  t0 <- Sys.time()
  handler$write_run_diagnostics(chunk)
  if (k %in% marks) {
    rows[[length(rows) + 1L]] <- data.frame(
      chunk = k, accumulated_rows = k * chunk_rows,
      append_ms = round(1000 * as.numeric(difftime(Sys.time(), t0, units = "secs")), 1),
      cumulative_s = round(as.numeric(difftime(Sys.time(), t_all, units = "secs")), 1))
    print(rows[[length(rows)]])
  }
}
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
utils::write.csv(do.call(rbind, rows), file.path(out_dir, "probe_diagnostic_append.csv"), row.names = FALSE)
