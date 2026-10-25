args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 3L) {
  stop("usage: run_correction_clock.R <package-root> <arm> <output.csv>")
}

package_root <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
arm <- args[[2L]]
output <- args[[3L]]

.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
pkgload::load_all(package_root, quiet = TRUE)

n <- 40000L
events <- data.frame(
  event_id = paste0("clock_", seq_len(n)),
  run_id = "ws59-correction-clock",
  ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + seq_len(n),
  event_type = "FILL",
  instrument_id = "AAA",
  side = rep(c("BUY", "SELL"), n / 2L),
  qty = 0.1,
  price = 100,
  fee = 0,
  meta_json = "{}",
  event_seq = seq_len(n),
  stringsAsFactors = FALSE
)
prepared <- ledgr:::ledgr_prepare_accounting_events(events, "AAA")
invisible(ledgr:::ledgr_replay_accounting_events(prepared))

elapsed <- numeric(3L)
for (i in seq_along(elapsed)) {
  gc()
  elapsed[[i]] <- unname(system.time(
    replay <- ledgr:::ledgr_replay_accounting_events(prepared)
  )[["elapsed"]])
  stopifnot(
    identical(unname(replay$positions[["AAA"]]), 0),
    identical(ledgr:::ledgr_lot_count(replay$lot_state, "AAA"), 0L)
  )
}

record <- data.frame(
  arm = arm,
  repetition = seq_along(elapsed),
  events = n,
  elapsed_seconds = elapsed,
  stringsAsFactors = FALSE
)
dir.create(dirname(output), recursive = TRUE, showWarnings = FALSE)
utils::write.csv(record, output, row.names = FALSE)
cat(sprintf(
  "WS59_CORRECTION_CLOCK arm=%s median=%.6f seconds events=%d\n",
  arm,
  stats::median(elapsed),
  n
))
