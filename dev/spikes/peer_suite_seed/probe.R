# Small prerequisite: can the old peer verdict stand in for a deletion oracle?
root <- "C:/Users/maxth/Documents/GitHub/ledgr"
suppressMessages(pkgload::load_all(root, quiet = TRUE))
source(file.path(root, "dev/bench/peer_benchmark/peer_benchmark.R"))
base <- file.path(root, "dev/spikes/peer_suite_seed")
args <- commandArgs(trailingOnly = TRUE)
gut <- "--gut" %in% args; args <- setdiff(args, "--gut")
out <- if (length(args)) args[1] else file.path(base, "evidence")
dir.create(out, recursive = TRUE, showWarnings = FALSE)
bars <- ledgr_sim_bars(n_instruments = 2L, n_days = 120L, seed = 20260530L,
  start = "2020-01-01", instrument_prefix = "P")
snapshot <- ledgr_snapshot_from_df(bars, snapshot_id = "peer_suite_seed",
  price_basis = "split_adjusted")
features <- peer_public_ttr_features(5, 10)
strategy <- peer_strategy("fast", "slow")
exp <- ledgr_experiment(snapshot, strategy = strategy, features = features,
  opening = ledgr_opening(cash = 1e7), cost_model = ledgr_cost_zero(), risk_chain = ledgr_risk_none())
quiet <- function(expr) withCallingHandlers(expr, warning = function(w) {
  if (inherits(w, "LEDGR_LAST_BAR_NO_FILL") || grepl("LEDGR_LAST_BAR_NO_FILL", conditionMessage(w)))
    invokeRestart("muffleWarning")
})
bt <- quiet(ledgr_run(exp, run_id = "peer_seed_probe", seed = 20260530L))
equity <- as.data.frame(ledgr_results(bt, "equity"))
fills <- as.data.frame(ledgr_results(bt, "fills"))
diagnostics <- as.data.frame(ledgr_results(bt, "diagnostics"))
stopifnot(nrow(fills) > 0L)
reference <- list(status = "DONE", engine = "ledgr", fills = fills,
  equity = peer_canonical_equity("ledgr", equity),
  trades = peer_trade_summary_from_fills("ledgr", fills),
  metrics = peer_metric_oracles(equity$equity))
candidate <- reference
candidate$fills$qty[1] <- candidate$fills$qty[1] + 1
classified <- peer_parity(reference, candidate)
exact <- function(a, b) if (gut) TRUE else identical(a, b)
observed <- data.frame(
  observation = c("fill_count", "peer_equity_attribution_after_fill_mutation",
    "native_fills_equal_after_mutation", "native_equity_equal_after_fill_mutation",
    "unchanged_native_fills_equal"),
  value = c(nrow(fills), classified$attribution, exact(reference$fills, candidate$fills),
    identical(reference$equity, candidate$equity), exact(reference$fills, reference$fills)))
write.csv(fills, file.path(out, "native_fills.csv"), row.names = FALSE)
write.csv(equity, file.path(out, "native_equity.csv"), row.names = FALSE)
write.csv(diagnostics, file.path(out, "native_diagnostics.csv"), row.names = FALSE)
write.csv(observed, file.path(out, "observations.csv"), row.names = FALSE)
writeLines(c(paste("source:", system2("C:/Program Files/Git/cmd/git.exe", c("-C", root, "rev-parse", "HEAD"), stdout = TRUE)),
  paste("snapshot_hash:", ledgr_snapshot_info(snapshot)$snapshot_hash),
  paste("config_hash:", ledgr:::config_hash(bt$config)), capture.output(sessionInfo())), file.path(out, "environment.txt"))
close(bt); ledgr_snapshot_close(snapshot)
