# Candidates 2 and 3, time: the compute step (ledgr_history_compute_feature_series,
# the only step the patches touch) on the wide crossover shapes, for the run's
# SMA 5/10 and the sweep's SMA 3/5/8/12/20/40. Arms alternate within each
# repetition in a rotating order; the medians are reported. The values of
# every arm are checked identical to the pin's before timing.
#
#   Rscript probe_time.R --lib=<pinned library> --shapes=crossover_500x1260,crossover_1166x252 --reps=7 --out=<csv>

arg <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), commandArgs(TRUE), value = TRUE)
  if (!length(hit)) return(default)
  sub(paste0("^--", name, "="), "", hit[[1L]])
}
.libPaths(c(arg("lib"), .libPaths()))
library(ledgr)
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
repo <- normalizePath(file.path(here, "..", "..", ".."), winslash = "/")
source(file.path(here, "patches.R"))
source(file.path(repo, "dev/spikes/r_floor/fixture.R"))
shapes <- strsplit(arg("shapes", "crossover_500x1260,crossover_1166x252"), ",")[[1L]]
reps <- as.integer(arg("reps", "7"))
arms <- c("pin", "c2", "c3", "c23")
work <- file.path(tempdir(), "feature_stage1_time")
dir.create(work, showWarnings = FALSE)

sma <- function(n) ledgr::ledgr_ind_ttr("SMA", input = "close", id = paste0("sma_", n), n = as.integer(n))
rows <- list()
for (shape in shapes) {
  dims <- as.integer(strsplit(sub("^crossover_", "", shape), "x")[[1L]])
  db <- file.path(work, paste0(shape, ".duckdb"))
  if (file.exists(db)) unlink(db)
  ledgr::ledgr_snapshot_close(ledgr::ledgr_snapshot_from_df(r_floor_fixture(dims[[1L]], dims[[2L]])$bars,
    db_path = db, snapshot_id = "p", price_basis = "split_adjusted"))
  snapshot <- ledgr::ledgr_snapshot_open(db, "p", verify = TRUE)
  exp <- ledgr::ledgr_experiment(snapshot, function(ctx, params) ctx$hold(),
    features = do.call(ledgr::ledgr_feature_map, stats::setNames(lapply(c(5, 10), sma), c("sma_5", "sma_10"))),
    opening = ledgr::ledgr_opening(cash = 1e7), cost_model = ledgr::ledgr_cost_zero())
  substrate <- ns$ledgr_history_substrate_for_experiment(exp)
  start <- ns$ledgr_history_calculation_start(substrate)
  defsets <- list(run = c(5, 10), sweep = c(3, 5, 8, 12, 20, 40))
  for (path in names(defsets)) {
    defs <- lapply(defsets[[path]], function(n) ns$ledgr_precompute_feature_def_from_indicator(sma(n)))
    names(defs) <- vapply(defs, function(d) d$id, "")
    f <- function() ns$ledgr_history_compute_feature_series(substrate, defs, calculation_start = start)
    ref <- NULL
    for (arm in arms) {
      use_arm(arm)
      v <- f()
      if (is.null(ref)) ref <- v else stopifnot(identical(v, ref))
    }
    times <- matrix(NA_real_, reps, length(arms), dimnames = list(NULL, arms))
    for (r in seq_len(reps)) {
      order <- arms[(seq_along(arms) + r - 2L) %% length(arms) + 1L]
      for (arm in order) {
        use_arm(arm)
        invisible(gc(FALSE))
        t0 <- proc.time()[["elapsed"]]
        f()
        times[r, arm] <- proc.time()[["elapsed"]] - t0
      }
    }
    use_arm("pin")
    med <- apply(times, 2L, stats::median)
    rows[[paste(shape, path)]] <- data.frame(shape = shape, path = path, arm = arms,
      median_s = round(med, 3), min_s = round(apply(times, 2L, min), 3), max_s = round(apply(times, 2L, max), 3),
      saved_s = round(med[["pin"]] - med, 3), saved_pct = round(100 * (1 - med / med[["pin"]]), 1),
      reps = reps, stringsAsFactors = FALSE)
    cat(shape, path, paste(sprintf("%s=%.3f", arms, med), collapse = " "), "\n")
  }
  ledgr::ledgr_snapshot_close(snapshot)
}
out <- do.call(rbind, rows)
rownames(out) <- NULL
utils::write.csv(out, arg("out"), row.names = FALSE)
