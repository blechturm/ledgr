# Current FIFO kernel cost at the pin, on the registered fill-heavy workload
# (500 x 1,260 SMA 5/10, about 54 fills per pulse).
#
#   Rscript fifo_cost.R --lib=<installed pinned build> --out=<dir> [--passes=7]
#
# One untouched run and fills read give the end-to-end clocks. A second run
# captures every ledgr_lot_apply(book, input) call with its caller; the
# original kernel is then restored and each captured call is replayed in
# timed passes, split into input validation (ledgr_lot_input, as the
# operation wrappers call it) and the kernel (ledgr_lot_apply, which includes
# the applied-row validation). Per-call cost is the median pass time divided
# by the calls in the group. Run on a quiet host (High performance plan,
# P-core affinity).

local({
  here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]])))
  source(file.path(here, "common.R"))
  source(file.path(here, "workloads.R"))
})
commit <- ws16_load_installed(ws16_need("lib"))
out <- ws16_out(ws16_need("out"))
passes <- as.integer(ws16_arg("passes", "7"))
ns <- asNamespace("ledgr")
lot_input <- get("ledgr_lot_input", envir = ns)
op_fill <- get(".ledgr_lot_fill", envir = ns)
op_opening <- get(".ledgr_lot_opening", envir = ns)

work <- file.path(tempdir(), "ws16_fifo_cost")
dir.create(work, showWarnings = FALSE)
snap <- ledgr_snapshot_from_df(ws16_fill_heavy_bars(), db_path = file.path(work, "fill.duckdb"),
                               snapshot_id = "ws16_fill_cost", price_basis = "split_adjusted")
exp <- ws16_fill_heavy_experiment(snap)

clock <- function(run_id) {
  t0 <- proc.time()[["elapsed"]]
  bt <- suppressWarnings(ledgr_run(exp, run_id = run_id, seed = 20260530L))
  t1 <- proc.time()[["elapsed"]]
  fills <- ledgr_results(bt, "fills")
  t2 <- proc.time()[["elapsed"]]
  eq <- ledgr_results(bt, "equity")
  close(bt)
  data.frame(run_s = t1 - t0, fills_read_s = t2 - t1, n_fills = nrow(fills),
             final_equity = sprintf("%.6f", eq$equity[nrow(eq)]))
}
clocks <- clock("ws16-cost-1")

captured <- list()
orig <- ws16_wrap("ledgr_lot_apply", function(orig) {
  force(orig)
  function(book, input) {
    caller <- ws16_caller(c("ledgr_lot_apply", "ledgr_lot_fill", "ledgr_lot_opening",
                            "ledgr_lot_disposition", "ledgr_lot_apply_blocks"))
    captured[[length(captured) + 1L]] <<- list(book = book, input = input, caller = caller)
    orig(book, input)
  }
})
invisible(clock("ws16-cost-capture"))
ns_unlock <- function() {
  unlockBinding("ledgr_lot_apply", ns)
  assign("ledgr_lot_apply", orig, envir = ns)
  lockBinding("ledgr_lot_apply", ns)
}
ns_unlock()
ledgr_snapshot_close(snap)

caller <- vapply(captured, `[[`, character(1), "caller")
rows <- vapply(captured, function(x) length(x$input$pos), integer(1))
bucket <- ifelse(rows >= 50L, "50+", ifelse(rows >= 10L, "10-49", ifelse(rows >= 2L, "2-9", "1")))
group <- paste(caller, bucket, sep = "\t")

# The elapsed clock ticks in about 10-16 ms here, so each pass repeats the
# group's calls until it lasts at least half a second.
time_pass <- function(calls, fn, reps = 1L) {
  t0 <- proc.time()[["elapsed"]]
  for (r in seq_len(reps)) for (x in calls) fn(x)
  proc.time()[["elapsed"]] - t0
}
reps_for <- function(calls, fn) {
  reps <- 1L
  while (time_pass(calls, fn, reps) < 0.5) reps <- reps * 2L
  reps
}
validate <- function(x) {
  i <- x$input
  lot_input(i$operation[[1L]], i$pos, i$side, i$qty, i$price, i$fee, i$position_before, i$realized_model_pnl)
}
kernel <- function(x) orig(x$book, x$input)

res <- list()
for (g in unique(group)) {
  calls <- captured[group == g]
  for (part in c("input_validation", "kernel")) {
    fn <- if (part == "kernel") kernel else validate
    reps <- reps_for(calls, fn)
    t <- vapply(seq_len(passes), function(p) time_pass(calls, fn, reps), numeric(1)) / reps
    parts <- strsplit(g, "\t", fixed = TRUE)[[1L]]
    res[[length(res) + 1L]] <- data.frame(
      caller = parts[[1L]], block_rows = parts[[2L]], part = part, calls = length(calls),
      rows = sum(rows[group == g]), reps = reps, median_pass_s = stats::median(t),
      us_per_call = 1e6 * stats::median(t) / length(calls),
      us_per_row = 1e6 * stats::median(t) / sum(rows[group == g])
    )
  }
}
res <- do.call(rbind, res)
res <- res[order(res$caller, res$block_rows, res$part), ]
plan <- system2("powercfg", "/getactivescheme", stdout = TRUE)
clocks$commit <- commit
clocks$power_plan <- if (any(grepl("High performance", plan))) "High performance" else "other"
clocks$captured_calls <- length(captured)
ws16_write(clocks, file.path(out, "fifo_cost_clocks.csv"))
ws16_write(res, file.path(out, "fifo_cost_calls.csv"))
print(clocks)
print(res, row.names = FALSE)
