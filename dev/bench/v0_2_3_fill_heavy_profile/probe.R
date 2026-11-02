# Profile one ledgr build on the published 500x1260 SMA5/10 transition workload.
# Usage: Rscript probe.R <lib> <label> <variant old|new> <fixture.rds> <out_dir>
args <- commandArgs(trailingOnly = TRUE)
lib <- args[[1]]; label <- args[[2]]; variant <- args[[3]]
fixture <- args[[4]]; out <- args[[5]]
dir.create(out, recursive = TRUE, showWarnings = FALSE)
suppressPackageStartupMessages(library(ledgr, lib.loc = lib))
cat("ledgr from", find.package("ledgr"), "\n")

bars <- readRDS(fixture)
snap <- ledgr_snapshot_from_df(bars, db_path = file.path(out, "snap.duckdb"),
  snapshot_id = paste0("prof_", label), price_basis = "split_adjusted")

old_transition <- function(ctx, params) {
  fast <- ctx$vec$feature("fast")
  slow <- ctx$vec$feature("slow")
  ids <- ctx$universe
  usable <- is.finite(fast) & is.finite(slow)
  above <- usable & fast > slow
  prior_above <- prior_usable <- stats::setNames(rep(FALSE, length(ids)), ids)
  old_above <- unlist(ctx$state_prev$above)
  old_usable <- unlist(ctx$state_prev$usable)
  prior_above[names(old_above)] <- old_above
  prior_usable[names(old_usable)] <- old_usable
  targets <- ctx$hold()
  enter <- prior_usable & usable & above & !prior_above
  exit <- prior_usable & usable & !above & prior_above
  targets[enter] <- 1
  targets[exit] <- 0
  list(targets = targets, state_update = list(
    above = as.list(stats::setNames(above, ids)),
    usable = as.list(stats::setNames(usable, ids))
  ))
}
new_transition <- function(ctx, params) {
  fast <- ctx$fast
  slow <- ctx$slow
  usable <- is.finite(fast) & is.finite(slow)
  above <- usable & fast > slow
  targets <- ctx$hold()
  enter <- ctx$state$usable & usable & above & !ctx$state$above
  exit <- ctx$state$usable & usable & !above & ctx$state$above
  targets[enter] <- 1
  targets[exit] <- 0
  ledgr_strategy_result(targets, above = above, usable = usable)
}

features <- ledgr_feature_map(
  fast = ledgr_ind_ttr("SMA", input = "close", id = "fast", n = 5L),
  slow = ledgr_ind_ttr("SMA", input = "close", id = "slow", n = 10L))
t_exp <- system.time({
  exp <- if (variant == "old") {
    ledgr_experiment(snap, old_transition, features = features,
      opening = ledgr_opening(cash = 1e7), cost_model = ledgr_cost_zero(),
      risk_chain = ledgr_risk_none())
  } else {
    ledgr_experiment(snap, new_transition, features = features,
      opening = ledgr_opening(cash = 1e7), cost_model = ledgr_cost_zero(),
      risk_chain = ledgr_risk_none(), asset_state = list(above = FALSE, usable = FALSE))
  }
})[["elapsed"]]

one <- function(i, profile = FALSE) {
  if (profile) Rprof(file.path(out, "rprof.out"), interval = 0.01)
  t0 <- proc.time()[["elapsed"]]
  bt <- suppressWarnings(ledgr_run(exp, run_id = sprintf("prof_%s_%d", label, i), seed = 20260530L))
  t1 <- proc.time()[["elapsed"]]
  fills <- as.data.frame(ledgr_results(bt, "fills"))
  t2 <- proc.time()[["elapsed"]]
  equity <- as.data.frame(ledgr_results(bt, "equity"))
  t3 <- proc.time()[["elapsed"]]
  if (profile) Rprof(NULL)
  close(bt)
  data.frame(label = label, rep = i, profiled = profile, run = t1 - t0,
    fills_read = t2 - t1, equity_read = t3 - t2, total = t3 - t0,
    n_fills = nrow(fills), n_equity = nrow(equity),
    final_equity = sprintf("%.6f", equity$equity[nrow(equity)]))
}
rows <- rbind(one(1), one(2), one(3), one(4, profile = TRUE))
rows$experiment <- t_exp
print(rows)
write.csv(rows, file.path(out, "timings.csv"), row.names = FALSE)
