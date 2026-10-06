args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 4L) {
  stop("usage: writer_arm.R <root> <arm> <pair> <output.csv>", call. = FALSE)
}

root <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
arm <- args[[2L]]
pair <- as.integer(args[[3L]])
output <- args[[4L]]

.libPaths(c("C:/tmp/ledgr-duckdb-156-lib", .libPaths()))
pkgload::load_all(root, quiet = TRUE)

n_fills <- 5000L
n_samples <- 3L
handler <- ledgr:::ledgr_memory_output_handler("writer-record")
handler$init_buffers(n_fills * n_samples)
fill <- structure(
  list(
    instrument_id = "AAA",
    side = "BUY",
    qty = 1,
    fill_price = 100,
    fee = 0,
    ts_exec_utc = as.POSIXct("2020-01-02", tz = "UTC")
  ),
  class = "ledgr_fill_intent"
)
lot_res <- list(close_qty = 0, open_qty = 1, realized_close = 0)
lot_state <- list(realized_pnl = 0, total_cost_basis = 100)

elapsed <- numeric(n_samples)
event_seq <- 1L
for (sample in seq_len(n_samples)) {
  started <- proc.time()[["elapsed"]]
  for (i in seq_len(n_fills)) {
    write_res <- handler$write_fill_events(fill, event_seq)
    handler$record_accounting_fact(write_res, lot_res, lot_state)
    event_seq <- event_seq + 1L
  }
  handler$flush_pulse_events()
  elapsed[[sample]] <- proc.time()[["elapsed"]] - started
}

events <- handler$typed_events()
state <- get("state", envir = environment(handler$inline_summary))
fills <- ledgr:::ledgr_fill_row_buffer_tibble(state$inline_fills)
result <- data.frame(
  arm = arm,
  pair = pair,
  sample = seq_len(n_samples),
  fills_per_pulse = n_fills,
  elapsed_sec = elapsed,
  event_rows = nrow(events),
  fill_rows = nrow(fills),
  event_hash = digest::digest(events, algo = "sha256"),
  fill_hash = digest::digest(fills, algo = "sha256"),
  stringsAsFactors = FALSE
)
utils::write.csv(result, output, row.names = FALSE, na = "")
