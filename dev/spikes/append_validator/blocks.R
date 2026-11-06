# Real fill publication blocks: synthetic fills through the pinned payload
# builder (R/backtest-runner.R:92), so every block is what P4 publishes.

av_fill <- function(n, seed = 1L) {
  set.seed(seed)
  side <- ifelse(stats::runif(n) < 0.5, -1L, 1L)
  qty <- round(stats::runif(n, 1, 500))
  price <- round(stats::runif(n, 5, 400), 4)
  fee <- round(stats::runif(n, 0, 2), 2)
  d <- ledgr_fill_publication_deltas(side, qty, price, fee)
  exec_ts <- rep(as.numeric(as.POSIXct("2020-01-02 16:00:00", tz = "UTC")), n)
  list(side = side, qty = qty, price = price, fee = fee,
       cash_delta = d$cash_delta, position_delta = d$position_delta, exec_ts = exec_ts)
}

av_block <- function(n, event_seq = 2L, run_id = "av-run") {
  fill <- av_fill(n)
  ledgr_fill_event_payload(run_id, fill, seq_len(n), sprintf("P%04d", seq_len(n)), event_seq)
}
