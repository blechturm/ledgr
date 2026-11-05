# LDG-3209 milestone: quiet 10 x 7,200 durable run (hold-only, no fills).
# Usage: Rscript quiet_probe.R <lib> <label> <out_dir>
# Three timed runs, one Rprof run (10 ms); per-function self/total sample
# counts; stored rows per table and store bytes; read costs on the last run.
args <- commandArgs(trailingOnly = TRUE)
lib <- args[[1]]; label <- args[[2]]; out <- args[[3]]
dir.create(out, recursive = TRUE, showWarnings = FALSE)
suppressPackageStartupMessages(library(ledgr, lib.loc = lib))
bars <- ledgr_sim_bars(10L, 7200L, seed = 20261105L)
db <- file.path(out, "quiet.duckdb")
snap <- ledgr_snapshot_from_df(bars, db_path = db, snapshot_id = "quiet", price_basis = "split_adjusted")
hold_only <- function(ctx, params) ctx$hold()
exp <- ledgr_experiment(snap, hold_only, opening = ledgr_opening(cash = 1e6),
  cost_model = ledgr_cost_zero(), risk_chain = ledgr_risk_none())
one <- function(i, profile = FALSE) {
  invisible(gc())
  if (profile) Rprof(file.path(out, "rprof.out"), interval = 0.01)
  t0 <- proc.time()[["elapsed"]]
  bt <- suppressWarnings(ledgr_run(exp, run_id = sprintf("quiet_%d", i), seed = 1L))
  t1 <- proc.time()[["elapsed"]]
  if (profile) Rprof(NULL)
  eq <- ledgr_results(bt, "equity")
  close(bt)
  data.frame(label = label, rep = i, profiled = profile, run = t1 - t0, pulses = nrow(eq),
    final_equity = sprintf("%.6f", eq$equity[nrow(eq)]))
}
rows <- rbind(one(1), one(2), one(3), one(4, profile = TRUE))
write.csv(rows, file.path(out, "timings.csv"), row.names = FALSE)

p <- summaryRprof(file.path(out, "rprof.out"))
interval <- 0.01
self <- data.frame(label = label, fn = rownames(p$by.self), self_samples = round(p$by.self$self.time / interval),
  total_samples = round(p$by.total[rownames(p$by.self), "total.time"] / interval))
total <- data.frame(label = label, fn = rownames(p$by.total), total_samples = round(p$by.total$total.time / interval))
write.csv(self, file.path(out, "prof_self.csv"), row.names = FALSE)
write.csv(total, file.path(out, "prof_total.csv"), row.names = FALSE)

bt <- ledgr_run_open(snap, "quiet_3")
tm <- function(f) system.time(f())[["elapsed"]]
d <- NULL
reads <- c(
  diagnostics_full = tm(function() d <<- ledgr_results(bt, "diagnostics")),
  explain_history = tm(function() ledgr_run_explain(bt, unique(bars$instrument_id)[[1L]])),
  result_print = tm(function() utils::capture.output(print(bt))),
  summary_print = tm(function() utils::capture.output(summary(bt))),
  metrics = tm(function() ledgr_compute_metrics(bt)))
close(bt)
ledgr_snapshot_close(snap)
con <- DBI::dbConnect(duckdb::duckdb(), dbdir = db, read_only = TRUE)
tabs <- DBI::dbGetQuery(con, "SELECT table_name FROM duckdb_tables() ORDER BY table_name")$table_name
counts <- vapply(tabs, function(t) as.numeric(DBI::dbGetQuery(con, sprintf('SELECT COUNT(*) AS n FROM "%s"', t))$n), 0)
DBI::dbDisconnect(con, shutdown = TRUE)
write.csv(data.frame(label = label, table = tabs, rows = counts), file.path(out, "stored_rows.csv"), row.names = FALSE)
write.csv(data.frame(label = label, measure = c(names(reads), "logical_diagnostic_rows", "store_bytes"),
  value = c(reads, nrow(d), file.size(db))), file.path(out, "reads.csv"), row.names = FALSE)
cat("QUIET_PROBE_DONE", label, sprintf("median run %.2f s", median(rows$run[!rows$profiled])), "\n")
