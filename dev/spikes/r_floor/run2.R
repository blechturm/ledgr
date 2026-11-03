# Stage 2 runner: price each guarantee added back to the floor.
# Usage: Rscript dev/spikes/r_floor/run2.R <ledgr lib> <out dir> [shapes]
args <- commandArgs(TRUE)
suppressPackageStartupMessages(library(ledgr, lib.loc = args[[1]]))
out <- args[[2]]
shapes <- strsplit(if (length(args) >= 3) args[[3]] else "10x7200,500x1260", ",")[[1]]
dir.create(out, recursive = TRUE, showWarnings = FALSE)
here <- file.path("dev", "spikes", "r_floor")
for (f in c("fixture.R", "floor.R", "layers.R")) source(file.path(here, f))

configs <- list(
  base       = list(validate = FALSE, ctx = "lean", avail = FALSE, trace = "none"),
  validate   = list(validate = TRUE,  ctx = "lean", avail = FALSE, trace = "none"),
  rich_ctx   = list(validate = TRUE,  ctx = "rich", avail = FALSE, trace = "none"),
  avail      = list(validate = TRUE,  ctx = "rich", avail = TRUE,  trace = "none"),
  trace_full = list(validate = TRUE,  ctx = "rich", avail = TRUE,  trace = "full"),
  trace_diff = list(validate = TRUE,  ctx = "rich", avail = TRUE,  trace = "diff")
)
key <- function(f) {
  f <- f[order(as.numeric(f$ts_utc), f$instrument_id, method = "radix"), ]
  data.frame(instrument_id = f$instrument_id, ts = as.numeric(f$ts_utc), side = f$side,
             qty = as.numeric(f$qty), price = as.numeric(f$price))
}
med <- function(fn, reps) stats::median(vapply(seq_len(reps), function(i) system.time(fn())[["elapsed"]], 1))
first_diff <- function(a, b) {
  bad <- names(a)[!vapply(names(a), function(c) identical(a[[c]], b[[c]]), TRUE)]
  if (!length(bad)) return("")
  if (nrow(a) != nrow(b)) return(sprintf("rows %d vs %d", nrow(a), nrow(b)))
  c1 <- bad[[1]]; i <- which(!(a[[c1]] == b[[c1]]) | xor(is.na(a[[c1]]), is.na(b[[c1]])))[1]
  sprintf("%s (first at row %s)", paste(bad, collapse = "+"), i)
}

par_rows <- list(); time_rows <- list()
for (shape in shapes) {
  dims <- as.integer(strsplit(shape, "x")[[1]])
  fx <- r_floor_fixture(dims[[1]], dims[[2]])
  bt <- r_floor_ledgr_run(fx, paste0("layers_", shape),
                          db_path = tempfile(paste0("r_floor2_", shape, "_"), fileext = ".duckdb"))
  fills <- as.data.frame(ledgr_results(bt, "fills"))
  equity <- as.data.frame(ledgr_results(bt, "equity"))
  ledgr_trace <- r_floor_ledgr_trace_frame(ledgr_results(bt, "diagnostics"))
  close(bt)
  p <- r_floor_prepare_rich(fx, r_floor_prepare(fx))
  reps <- if (dims[[1]] * dims[[2]] > 1e5) 3L else 5L
  for (name in names(configs)) {
    fold <- function() r_floor_fold_layers(p, r_floor_transition, configs[[name]])
    sk <- fold()
    trace_check <- ""
    if (identical(configs[[name]]$trace, "full")) {
      fr <- r_floor_trace_frame(p, sk$trace)
      trace_check <- if (identical(fr, ledgr_trace)) "identical" else first_diff(fr, ledgr_trace)
    }
    rebuild_s <- NA_real_
    if (identical(configs[[name]]$trace, "diff")) {
      rb <- function() r_floor_trace_frame(p, r_floor_rebuild_trace(p, sk$fills, sk$residual))
      fr <- rb()
      trace_check <- if (identical(fr, ledgr_trace)) "identical" else first_diff(fr, ledgr_trace)
      rebuild_s <- med(rb, reps)
    }
    write_s <- med(function() {
      db <- tempfile(fileext = ".duckdb")
      on.exit(unlink(c(db, paste0(db, ".wal"))))
      r_floor_write(db, sk, if (identical(configs[[name]]$trace, "full")) r_floor_trace_frame(p, sk$trace))
    }, reps)
    par_rows[[length(par_rows) + 1L]] <- data.frame(shape = shape, layer = name,
      fills_identical = identical(key(sk$fills), key(fills)),
      equity_identical = identical(sk$equity$equity, equity$equity),
      cash_identical = identical(sk$equity$cash, equity$cash),
      trace = trace_check, unmet_requests = sk$unmet, trace_rows = nrow(ledgr_trace))
    loop <- med(fold, reps)
    time_rows[[length(time_rows) + 1L]] <- data.frame(shape = shape, layer = name,
      loop_s = loop, us_per_pulse = loop / dims[[2]] * 1e6,
      rebuild_trace_s = rebuild_s, durable_write_s = write_s)
  }
}
par_out <- do.call(rbind, par_rows); time_out <- do.call(rbind, time_rows)
utils::write.csv(par_out, file.path(out, "parity_layers.csv"), row.names = FALSE)
utils::write.csv(time_out, file.path(out, "timings_layers.csv"), row.names = FALSE)
print(par_out, row.names = FALSE); print(time_out, row.names = FALSE)
