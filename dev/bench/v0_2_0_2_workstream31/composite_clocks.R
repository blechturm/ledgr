# Workstream 31 composite-call clocks (LDG-2915, close-review round).
#
# Usage, from any directory:
#
#   Rscript dev/bench/v0_2_0_2_workstream31/composite_clocks.R <tree> <arm> <out.csv>
#
# Loads the ledgr source tree <tree> and appends one row per measurement to
# <out.csv>, labelled <arm>. Run the arms in alternating order, one process
# each. Warm clock: each measured call runs once untimed first.
#
# Measurements, on the walk-forward store of connection_census.R (one
# instrument, twelve days): `ledgr_walk_forward()` over two folds, the
# walk-forward inspection read `ledgr_walk_forward_open()`, `ledgr_candidate()`
# on the result, `ledgr_promote()` of that candidate followed by `close()`, and
# one `test_dates()` call on an indicator dev object; the median of 10 calls
# each. Bytes are `Rprofmem()` vector allocations of one further call. The
# indicator dev object gets its own store and is measured last: the earlier
# code kept its connection open, and an open connection to the same file makes
# every later open of that file cheaper.

args <- commandArgs(trailingOnly = TRUE)
tree <- args[[1L]]; arm <- args[[2L]]; out_path <- args[[3L]]
suppressMessages(pkgload::load_all(tree, quiet = TRUE, compile = FALSE))

allocated_bytes <- function(f) {
  path <- tempfile()
  Rprofmem(path, threshold = 0)
  f()
  Rprofmem(NULL)
  lines <- readLines(path, warn = FALSE)
  sum(as.numeric(sub(" :.*$", "", lines[grepl("^[0-9]+ :", lines)])))
}

bars <- data.frame(
  ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:11,
  instrument_id = "AAA",
  open = 100 + 1:12, high = 101 + 1:12, low = 99 + 1:12, close = 100 + 1:12, volume = 1000
)
strategy <- function(ctx, params) {
  targets <- ctx$flat()
  if (ctx$close("AAA") >= params$threshold) targets["AAA"] <- params$qty
  targets
}
snapshot <- ledgr_snapshot_from_df(bars, db_path = tempfile(fileext = ".duckdb"))
exp <- ledgr_experiment(snapshot, strategy, opening = ledgr_opening(cash = 10000), cost_model = ledgr_cost_zero())
ledgr_snapshot_close(snapshot)
folds <- ledgr:::ledgr_fold_list(
  list(
    ledgr_fold("2020-01-01", "2020-01-04", "2020-01-05", "2020-01-07", fold_seq = 1L),
    ledgr_fold("2020-01-04", "2020-01-07", "2020-01-08", "2020-01-10", fold_seq = 2L)
  ),
  constructor = list(type_id = "explicit")
)
grid <- ledgr_param_grid(trade = list(qty = 1, threshold = 101))
wf <- NULL
promoted_id <- 0L
dev <- NULL

calls <- list(
  walk_forward = function() {
    wf <<- suppressWarnings(ledgr_walk_forward(
      exp, grid = grid, folds = folds, selection_rule = ledgr_rule_argmax("sharpe_ratio"), seed = 101L
    ))
    invisible(lapply(wf$test_runs, close))
  },
  walk_forward_open = function() ledgr_walk_forward_open(snapshot, wf$session_id),
  candidate = function() ledgr_candidate(wf, fold_seq = 1L),
  promote = function() {
    promoted_id <<- promoted_id + 1L
    candidate <- ledgr_candidate(wf, fold_seq = 1L)
    close(suppressWarnings(ledgr_promote(exp, candidate, run_id = sprintf("promoted_%03d", promoted_id))))
  },
  indicator_test_dates = function() {
    dev$test_dates(function(window) mean(window$close), c("2020-01-05T00:00:00Z", "2020-01-06T00:00:00Z"))
  }
)
timed <- function(f, n = 10L) {
  ledgr_snapshot_close(snapshot)
  f()
  stats::median(vapply(seq_len(n), function(i) {
    ledgr_snapshot_close(snapshot)
    start <- proc.time()[["elapsed"]]
    f()
    proc.time()[["elapsed"]] - start
  }, numeric(1)))
}

dev_snapshot <- ledgr_snapshot_from_df(bars, db_path = tempfile(fileext = ".duckdb"))
rows <- lapply(names(calls), function(name) {
  if (identical(name, "indicator_test_dates")) {
    dev <<- ledgr_indicator_dev(dev_snapshot, "AAA", "2020-01-06T00:00:00Z", lookback = 3)
  }
  f <- calls[[name]]
  data.frame(arm = arm, measure = name, seconds = timed(f), bytes = allocated_bytes(f))
})
close(dev)
ledgr_snapshot_close(dev_snapshot)
ledgr_snapshot_close(snapshot)
out <- do.call(rbind, rows)
utils::write.table(out, out_path, sep = ",", row.names = FALSE, col.names = !file.exists(out_path),
  append = file.exists(out_path))
cat("recorded", nrow(out), "measurements for", arm, "\n")
