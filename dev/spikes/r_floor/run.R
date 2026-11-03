# Runner: ledgr oracle against the R-floor fold, per shape, writing evidence.
# Usage: Rscript dev/spikes/r_floor/run.R <ledgr lib> <out dir> [shapes] [gut]
#   shapes: comma list like 3x40,10x7200,500x1260 (default 10x7200,500x1260)
#   gut:    "same_bar_fill" breaks the inline fold on purpose
args <- commandArgs(TRUE)
suppressPackageStartupMessages(library(ledgr, lib.loc = args[[1]]))
out <- args[[2]]
shapes <- strsplit(if (length(args) >= 3) args[[3]] else "10x7200,500x1260", ",")[[1]]
gut <- if (length(args) >= 4) args[[4]] else ""
dir.create(out, recursive = TRUE, showWarnings = FALSE)
here <- file.path("dev", "spikes", "r_floor")
source(file.path(here, "fixture.R"))
source(file.path(here, "floor.R"))

key <- function(f) {
  f <- f[order(as.numeric(f$ts_utc), f$instrument_id, method = "radix"), ]
  data.frame(instrument_id = f$instrument_id, ts = as.numeric(f$ts_utc),
             side = f$side, qty = as.numeric(f$qty), price = as.numeric(f$price))
}
parity <- function(sk, fills, equity) {
  a <- key(sk$fills); b <- key(fills)
  d <- abs(sk$equity$equity - equity$equity)
  data.frame(n_fills_floor = nrow(a), n_fills_ledgr = nrow(b),
             fills_identical = identical(a, b),
             equity_identical = identical(sk$equity$equity, equity$equity),
             cash_identical = identical(sk$equity$cash, equity$cash),
             max_abs_equity_diff = max(d), final_equity = sprintf("%.6f", equity$equity[nrow(equity)]))
}
median_time <- function(fn, reps) {
  t <- vapply(seq_len(reps), function(i) system.time(fn())[["elapsed"]], numeric(1))
  stats::median(t)
}

par_rows <- list(); time_rows <- list()
for (shape in shapes) {
  dims <- as.integer(strsplit(shape, "x")[[1]])
  fx <- r_floor_fixture(dims[[1]], dims[[2]])
  db_path <- tempfile(paste0("r_floor_", shape, "_"), fileext = ".duckdb")
  t0 <- proc.time()[["elapsed"]]
  bt <- r_floor_ledgr_run(fx, paste0("floor_", shape), db_path = db_path)
  t1 <- proc.time()[["elapsed"]]
  fills <- as.data.frame(ledgr_results(bt, "fills"))
  equity <- as.data.frame(ledgr_results(bt, "equity"))
  t2 <- proc.time()[["elapsed"]]
  close(bt)

  t_prep <- system.time(p <- r_floor_prepare(fx))[["elapsed"]]
  strategy <- r_floor_transition
  folds <- list(
    inline = function() r_floor_fold_inline(p, gut = gut),
    strategy = function() r_floor_fold_strategy(p, strategy)
  )
  reps <- if (dims[[2]] * dims[[1]] > 1e5) 3L else 5L
  for (v in names(folds)) {
    sk <- folds[[v]]()
    par_rows[[length(par_rows) + 1L]] <- cbind(data.frame(shape = shape, variant = v), parity(sk, fills, equity))
    loop <- median_time(folds[[v]], reps)
    time_rows[[length(time_rows) + 1L]] <- data.frame(shape = shape, variant = v,
      prepare_s = t_prep, loop_s = loop, us_per_pulse = loop / dims[[2]] * 1e6,
      ledgr_run_s = t1 - t0, ledgr_reads_s = t2 - t1,
      ledgr_us_per_pulse = (t1 - t0) / dims[[2]] * 1e6)
  }
}
par_out <- do.call(rbind, par_rows); time_out <- do.call(rbind, time_rows)
utils::write.csv(par_out, file.path(out, "parity.csv"), row.names = FALSE)
utils::write.csv(time_out, file.path(out, "timings.csv"), row.names = FALSE)
print(par_out, row.names = FALSE); print(time_out, row.names = FALSE)
