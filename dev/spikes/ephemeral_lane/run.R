# Spike ephemeral_lane, runner (CHARTER.md): the lean loop durable
# (ledgr_run()) against ephemeral (one-candidate, one-worker ledgr_sweep()),
# alternating fresh processes, phase clocks reconciled to the whole call.
#
#   Rscript dev/spikes/ephemeral_lane/run.R --lib=<pin library> --out=<dir>
#     [--rounds=7] [--shapes=10x7200,slice2_10x7200]
# One arm (internal): --mode=arm --lane=durable|ephemeral --shape=<id> --row=<csv>
#
# Phases per run, seconds: call (the ledgr_run() or ledgr_sweep() call);
# fold (inside ledgr_fold_envelope); writes (inside the output handler's
# write and flush methods the loop calls, timed in the fold wrapper);
# fold_rest = fold - writes (the loop, expansion and transaction overhead);
# outside = call - fold (preparation, finalisation, result assembly). The
# sweep's own t_engine is recorded beside. Economic parity: the nine metrics
# both lanes produce must be identical, and the final equities equal.

args <- commandArgs(trailingOnly = TRUE)
opt <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (length(hit)) sub(paste0("^--", name, "="), "", hit[[1L]]) else default
}
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
repo <- normalizePath(file.path(here, "..", "..", ".."), winslash = "/")
lib <- normalizePath(opt("lib"), winslash = "/", mustWork = TRUE)
metric_names <- c("total_return", "annualized_return", "volatility", "sharpe_ratio", "max_drawdown", "n_trades",
                  "win_rate", "avg_trade", "time_in_market")
write_methods <- c("write_fill_events", "record_accounting_fact", "flush_pulse_events", "flush_pending", "append_event_rows",
                   "write_run_diagnostics", "write_run_diagnostic_implicit", "write_diagnostic_coverage",
                   "write_diagnostic_summary", "write_run_evidence", "write_telemetry", "store_session_telemetry")

if (identical(opt("mode"), "arm")) {
  source(file.path(repo, "dev/spikes/lean_fifo_cpp/lean_env.R"))
  env <- spike_lean_env(lib, repo)
  ns <- env$ns
  shape <- opt("shape"); lane <- opt("lane")
  # Gut (check.R only): the crossover strategy reads its slow average as fast
  # and its fast as slow, so the run's metrics must differ from the record.
  if (identical(opt("gut"), "1")) {
    b <- paste(deparse(body(env$defs$r_floor_transition)), collapse = "\n")
    b <- sub("fast <- ctx$fast\n    slow <- ctx$slow", "fast <- ctx$slow\n    slow <- ctx$fast", b, fixed = TRUE)
    if (!grepl("fast <- ctx$slow", b, fixed = TRUE)) stop("gut target not found")
    body(env$defs$r_floor_transition) <- parse(text = b)[[1L]]
  }
  desc <- env$defs$bench_descriptor(shape)
  store <- tempfile(fileext = ".duckdb")
  ledgr::ledgr_snapshot_close(ledgr::ledgr_snapshot_from_df(desc$bars(), db_path = store, snapshot_id = "eph",
                                                            price_basis = "split_adjusted"))
  snapshot <- ledgr::ledgr_snapshot_open(store, "eph", verify = TRUE)
  exp <- desc$experiment(snapshot)
  restore <- env$lean$lean_loop_install()
  now <- function() as.numeric(Sys.time())
  clk <- new.env(); clk$fold <- 0; clk$writes <- 0; clk$write_calls <- 0L
  inner <- get("ledgr_fold_envelope", envir = ns)
  timed <- function(f) { force(f); function(...) { t0 <- now(); on.exit({ clk$writes <- clk$writes + (now() - t0)
    clk$write_calls <- clk$write_calls + 1L }); f(...) } }
  unlockBinding("ledgr_fold_envelope", ns)
  assign("ledgr_fold_envelope", function(execution, output_handler) {
    for (m in intersect(write_methods, names(output_handler))) {
      if (is.function(output_handler[[m]])) output_handler[[m]] <- timed(output_handler[[m]])
    }
    t0 <- now(); on.exit(clk$fold <- clk$fold + (now() - t0)); inner(execution, output_handler)
  }, envir = ns)
  lockBinding("ledgr_fold_envelope", ns)
  folds0 <- env$lean$lean_entry$lean_folds %||% 0L
  invisible(gc(FALSE))
  t0 <- now()
  if (lane == "durable") {
    bt <- suppressWarnings(ledgr::ledgr_run(exp, run_id = "eph", seed = 20260530L))
    call_s <- now() - t0
    m <- ledgr::ledgr_compute_metrics(bt)
    eq <- ledgr::ledgr_results(bt, "equity")
    final_equity <- eq$equity[nrow(eq)]
    close(bt)
    t_engine <- NA_real_
  } else {
    sw <- suppressWarnings(ledgr::ledgr_sweep(exp, ledgr::ledgr_grid_named(a = list(strategy = list())), seed = 20260530L))
    call_s <- now() - t0
    s <- as.data.frame(sw)
    m <- as.list(s[1L, metric_names])
    final_equity <- s$final_equity[[1L]]
    t_engine <- s$t_engine[[1L]]
  }
  if (env$lean$lean_entry$lean_folds - folds0 != 1L) stop("the lean loop did not run once")
  restore(); ledgr::ledgr_snapshot_close(snapshot)
  row <- data.frame(shape = shape, lane = lane, call_s = call_s, fold_s = clk$fold, writes_s = clk$writes,
                    write_calls = clk$write_calls, t_engine = t_engine, final_equity = sprintf("%.17g", final_equity),
                    metrics = paste(vapply(metric_names, function(k) sprintf("%.17g", as.numeric(m[[k]])), ""), collapse = "|"))
  utils::write.csv(row, opt("row"), row.names = FALSE)
  quit(status = 0L)
}

out <- opt("out"); dir.create(out, recursive = TRUE, showWarnings = FALSE)
rounds <- as.integer(opt("rounds", "7"))
shapes <- strsplit(opt("shapes", "10x7200,slice2_10x7200"), ",")[[1L]]
rscript <- file.path(R.home("bin"), "Rscript.exe")
rows <- list()
for (s in shapes) for (k in seq_len(rounds)) {
  for (lane in if (k %% 2L) c("durable", "ephemeral") else c("ephemeral", "durable")) {
    row <- tempfile(fileext = ".csv")
    st <- system2(rscript, c(file.path(here, "run.R"), paste0("--lib=", lib), "--mode=arm", paste0("--lane=", lane),
                             paste0("--shape=", s), paste0("--row=", row)), stdout = FALSE, stderr = FALSE)
    if (st != 0L) stop("lane ", lane, " on ", s, " round ", k, " failed")
    x <- utils::read.csv(row, stringsAsFactors = FALSE, colClasses = c(final_equity = "character", metrics = "character"))
    x$round <- k
    rows[[length(rows) + 1L]] <- x
    cat(sprintf("%-15s round %d %-9s call %.2f s fold %.2f s writes %.2f s\n", s, k, lane, x$call_s, x$fold_s, x$writes_s))
  }
}
raw <- do.call(rbind, rows)
utils::write.csv(raw, file.path(out, "lanes_raw.csv"), row.names = FALSE)
pulses <- c("10x7200" = 7200, "slice2_10x7200" = 7200)
summ <- do.call(rbind, lapply(split(raw, list(raw$shape, raw$lane), drop = TRUE), function(x) {
  med <- function(v) stats::median(v)
  p <- pulses[[x$shape[[1L]]]]
  data.frame(shape = x$shape[[1L]], lane = x$lane[[1L]], rounds = nrow(x),
    call_us = 1e6 * med(x$call_s) / p, fold_us = 1e6 * med(x$fold_s) / p, writes_us = 1e6 * med(x$writes_s) / p,
    fold_rest_us = 1e6 * med(x$fold_s - x$writes_s) / p, outside_us = 1e6 * med(x$call_s - x$fold_s) / p,
    t_engine_us = 1e6 * med(x$t_engine) / p, write_calls = med(x$write_calls))
}))
parity <- do.call(rbind, lapply(split(raw, raw$shape), function(x) data.frame(shape = x$shape[[1L]],
  metrics_identical = length(unique(x$metrics)) == 1L, final_equity_identical = length(unique(x$final_equity)) == 1L)))
utils::write.csv(summ, file.path(out, "lanes_summary.csv"), row.names = FALSE)
utils::write.csv(parity, file.path(out, "lanes_parity.csv"), row.names = FALSE)
writeLines(c(paste("power plan:", paste(system2("powercfg", "/getactivescheme", stdout = TRUE), collapse = " ")),
             paste("library:", lib), paste("head:", system2("git", c("-C", repo, "rev-parse", "HEAD"), stdout = TRUE))),
           file.path(out, "lanes_host.txt"))
print(summ, row.names = FALSE, digits = 3); print(parity, row.names = FALSE)
quit(status = if (all(parity$metrics_identical & parity$final_equity_identical)) 0L else 1L)
