# Fixed cost per run: where a small ledgr run spends its time, against the
# floor doing the same run (prepare, loop, one batched write).
# Usage: Rscript dev/spikes/r_floor/fixed_cost.R <ledgr lib> <out dir> [runs]
args <- commandArgs(TRUE)
suppressPackageStartupMessages(library(ledgr, lib.loc = args[[1]]))
out <- args[[2]]
n_runs <- if (length(args) >= 3) as.integer(args[[3]]) else 20L
dir.create(out, recursive = TRUE, showWarnings = FALSE)
here <- file.path("dev", "spikes", "r_floor")
for (f in c("fixture.R", "floor.R", "layers.R")) source(file.path(here, f))

fx <- r_floor_fixture(12L, 90L)
snap <- ledgr_snapshot_from_df(fx$bars, db_path = tempfile(fileext = ".duckdb"),
  snapshot_id = "fixed_cost", price_basis = "split_adjusted")
strategy <- r_floor_transition
environment(strategy) <- asNamespace("ledgr")
exp <- ledgr_experiment(snap, strategy,
  features = ledgr_feature_map(
    fast = ledgr_ind_ttr("SMA", input = "close", id = "fast", n = 5L),
    slow = ledgr_ind_ttr("SMA", input = "close", id = "slow", n = 10L)),
  opening = ledgr_opening(cash = 1e7), cost_model = ledgr_cost_zero(),
  risk_chain = ledgr_risk_none(), asset_state = list(above = FALSE, usable = FALSE))
one <- function(i) {
  bt <- suppressWarnings(ledgr_run(exp, run_id = sprintf("fixed_%03d", i), seed = 20260530L))
  invisible(as.data.frame(ledgr_results(bt, "fills")))
  invisible(as.data.frame(ledgr_results(bt, "equity")))
  close(bt)
}
one(0L)  # warm-up
prof <- file.path(out, "fixed_cost_rprof.out")
Rprof(prof, interval = 0.005)
t_ledgr <- system.time(for (i in seq_len(n_runs)) one(i))[["elapsed"]] / n_runs
Rprof(NULL)

# Attribute each sample to the outermost ledgr function below ledgr_run_impl
# (or to the result reads), so the buckets add up to the run.
stacks <- lapply(strsplit(readLines(prof)[-1], " "), function(s) gsub('"', "", s))
bucket <- vapply(stacks, function(s) {
  if (any(s == "ledgr_results")) return("results reads (fills, equity)")
  if (any(s == "ledgr_fold_envelope")) return("fold loop (all pulses)")
  r <- rev(s); k <- match("ledgr_run_impl", r)
  if (is.na(k)) return(if (any(grepl("^close|ledgr_run_close", s))) "close" else "other")
  inner <- r[(k + 1L):length(r)]
  inner <- inner[grepl("^ledgr_", inner)]
  if (length(inner) > 2L) inner[[3L]] else if (length(inner)) inner[[length(inner)]] else "ledgr_run_impl"
}, "")
tab <- sort(table(bucket), decreasing = TRUE)
ledgr_rows <- data.frame(bucket = names(tab), share = as.numeric(tab) / length(stacks))
ledgr_rows$ms_per_run <- ledgr_rows$share * t_ledgr * 1000

floor_one <- function() {
  p <- r_floor_prepare_rich(fx, r_floor_prepare(fx))
  sk <- r_floor_fold_layers(p, r_floor_transition,
    list(validate = TRUE, ctx = "rich", avail = TRUE, trace = "diff"))
  db <- tempfile(fileext = ".duckdb"); on.exit(unlink(c(db, paste0(db, ".wal"))))
  r_floor_write(db, sk)
}
floor_one()
t_floor <- system.time(for (i in seq_len(n_runs)) floor_one())[["elapsed"]] / n_runs

utils::write.csv(ledgr_rows, file.path(out, "fixed_cost_buckets.csv"), row.names = FALSE)
utils::write.csv(data.frame(shape = "12x90", runs = n_runs, ledgr_ms_per_run = t_ledgr * 1000,
  floor_ms_per_run = t_floor * 1000), file.path(out, "fixed_cost.csv"), row.names = FALSE)
cat(sprintf("ledgr %.1f ms per run, floor %.1f ms per run\n", t_ledgr * 1000, t_floor * 1000))
print(utils::head(ledgr_rows, 20), row.names = FALSE)
