# Probe: why does a one-candidate sweep cost more than one run on the
# 1998-2026 Sharadar snapshot? Profiles both with Rprof and writes the
# top functions by total time. Aggregates only.
#
#   Rscript probe_sweep_cost.R <ledgr_repo> <work_dir> <out_dir>
args <- commandArgs(trailingOnly = TRUE)
ledgr_repo <- normalizePath(args[[1L]], winslash = "/")
work_dir <- args[[2L]]
out_dir <- args[[3L]]
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
suppressMessages(pkgload::load_all(ledgr_repo, quiet = TRUE, compile = FALSE))
snapshot <- ledgr_snapshot_open(file.path(work_dir, "sp500-1998-2026.duckdb"))
universe <- DBI::dbGetQuery(ledgr:::get_connection(snapshot),
                            "SELECT DISTINCT universe_id FROM snapshot_membership_sets")$universe_id[[1L]]
momentum <- function(ctx, params) {
  month <- substr(ctx$ts_utc, 1L, 7L)
  if (identical(ctx$state_prev$month, month)) return(ctx$hold())
  target <- ctx |> ledgr_signal_return(params$lookback) |>
    ledgr_select_top_n(params$n, partial = "allow") |> ledgr_weight_equal() |>
    ledgr_target_rebalance(ctx, equity_fraction = 0.95)
  list(targets = target, state_update = list(month = month))
}
exp <- ledgr_experiment(snapshot, momentum, features = list(ledgr_ind_returns(252L)),
                        universe = ledgr_universe_members(universe),
                        valuation_policy = ledgr_valuation_stale(5),
                        cost_model = ledgr_cost_zero(), opening = ledgr_opening(cash = 1e6))
profile <- function(label, expr) {
  prof <- file.path(work_dir, paste0("probe_", label, ".Rprof"))
  t0 <- Sys.time()
  Rprof(prof, interval = 0.05)
  value <- force(expr)
  Rprof(NULL)
  elapsed <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  top <- summaryRprof(prof)$by.total
  top <- utils::head(data.frame(fn = rownames(top), total_s = top$total.time,
                                total_pct = top$total.pct, self_s = top$self.time), 40L)
  utils::write.csv(top, file.path(out_dir, paste0("probe_", label, "_top.csv")), row.names = FALSE)
  cat(sprintf("%-6s %.1f s\n", label, elapsed))
  list(value = value, elapsed = elapsed)
}
run <- profile("run", ledgr_run(exp, params = list(lookback = 252L, n = 20L),
                                run_id = paste0("probe-run-", format(Sys.time(), "%H%M%S"))))
sweep <- profile("sweep", ledgr_sweep(exp, ledgr_strategy_grid(lookback = 252L, n = 20L)))
utils::write.csv(data.frame(path = c("run", "sweep"), elapsed_s = round(c(run$elapsed, sweep$elapsed), 1),
                            final_equity = c(utils::tail(ledgr_results(run$value, "equity")$equity, 1L),
                                             sweep$value$final_equity[[1L]])),
                 file.path(out_dir, "probe_elapsed.csv"), row.names = FALSE)
ledgr_snapshot_close(snapshot)
