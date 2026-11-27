# R067 / R125 probe: the equity carrier built directly (the lean fold's
# return shape) is identical() to the pin's record + append + prefix for the
# blocks' fixture values.
pin <- "C:/Users/maxth/ledgr-wt/pin-src-7f65733f"
source("C:/Users/maxth/ledgr-wt/cut27-dev/dev/lean_core/load.R")
invisible(lean_core_load(pin, debug = TRUE))
L <- asNamespace("ledgr")
carrier <- function(ts, cash, value, realized, basis, n) {
  L$ledgr_carrier_new(list(ts = as.numeric(ts), cash = as.numeric(cash), positions_value = as.numeric(value),
    realized_pnl = as.numeric(realized), cost_basis = as.numeric(basis), n = n), "equity", NA_integer_)
}
# R067: 300 rows in a record of capacity 312, and the empty record.
n <- 300L
ts <- as.POSIXct("2020-01-01", tz = "UTC") + 86400 * (seq_len(n) - 1L)
cash <- 1000 + seq_len(n) / 7
value <- 50 + sqrt(seq_len(n))
realized <- seq_len(n) / 3
basis <- 40 + seq_len(n) / 11
record <- L$ledgr_fold_equity_record(n + 12L)
for (i in seq_len(n)) record <- L$ledgr_fold_equity_append(record, ts[[i]], cash[[i]], value[[i]], realized[[i]], basis[[i]])
r067 <- identical(L$ledgr_fold_equity_prefix(record), carrier(ts, cash, value, realized, basis, n))
r067_empty <- identical(L$ledgr_fold_equity_prefix(L$ledgr_fold_equity_record(4L)),
  L$ledgr_carrier_new(list(ts = numeric(), cash = numeric(), positions_value = numeric(),
    realized_pnl = numeric(), cost_basis = numeric(), n = 0L), "equity", NA_integer_))
# R125: the block's two rows, with its lot book and its one-row fill.
pulses <- as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:1
lot0 <- L$ledgr_lot_book_from_opening(instrument_ids = "AAA", positions = c(AAA = 2), cost_basis = c(AAA = 10))
eq <- L$ledgr_fold_equity_record(2L)
eq <- L$ledgr_fold_equity_append(eq, ts = pulses[[1L]], cash = 1000, positions_value = 20,
  realized_pnl = lot0$realized_pnl, cost_basis = lot0$total_cost_basis)
res <- L$ledgr_lot_fill(lot0, pos = 1L, side = -1L, qty = 3, price = 12, fee = 0.25)
cash_delta <- 3 * 12 - 0.25
eq <- L$ledgr_fold_equity_append(eq, ts = pulses[[2L]], cash = 1000 + cash_delta, positions_value = -12,
  realized_pnl = res$book$realized_pnl, cost_basis = res$book$total_cost_basis)
r125 <- identical(L$ledgr_fold_equity_prefix(eq), carrier(pulses, c(1000, 1000 + cash_delta), c(20, -12),
  c(as.numeric(lot0$realized_pnl), as.numeric(res$book$realized_pnl)),
  c(as.numeric(lot0$total_cost_basis), as.numeric(res$book$total_cost_basis)), 2L))
out <- data.frame(case = c("R067 300 rows", "R067 empty", "R125 two rows"), identical = c(r067, r067_empty, r125))
print(out)
utils::write.csv(out, "C:/Users/maxth/ledgr-wt/cut27-scratch/remap_B/probe_equity.csv", row.names = FALSE)
