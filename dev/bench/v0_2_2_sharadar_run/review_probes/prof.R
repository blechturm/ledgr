.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
suppressMessages(pkgload::load_all("C:/Users/maxth/Documents/GitHub/ledgr", quiet = TRUE, compile = FALSE))
args <- commandArgs(TRUE)
path <- args[[1]]; which <- args[[2]]; strat <- if (length(args) > 2) args[[3]] else "momentum"
snapshot <- ledgr_snapshot_open(path)
momentum <- function(ctx, params) {
  month <- substr(ctx$ts_utc, 1L, 7L)
  if (identical(ctx$state_prev$month, month)) return(ctx$hold())
  target <- ctx |> ledgr_signal_return(params$lookback) |>
    ledgr_select_top_n(params$n, partial = "allow") |> ledgr_weight_equal() |>
    ledgr_target_rebalance(ctx, equity_fraction = 0.95)
  list(targets = target, state_update = list(month = month))
}
equal_weight <- function(ctx, params) {
  month <- substr(ctx$ts_utc, 1L, 7L)
  if (identical(ctx$state_prev$month, month)) return(ctx$hold())
  target <- ctx |> ledgr_selection() |> ledgr_weight_equal() |>
    ledgr_target_rebalance(ctx, equity_fraction = 0.95)
  list(targets = target, state_update = list(month = month))
}
fn <- if (strat == "momentum") momentum else equal_weight
feats <- if (strat == "momentum") list(ledgr_ind_returns(60L)) else list()
params <- if (strat == "momentum") list(lookback = 60L, n = 20L) else list()
exp <- ledgr_experiment(snapshot, fn, features = feats, universe = ledgr_universe_members("U"),
  valuation_policy = ledgr_valuation_stale(5), cost_model = ledgr_cost_zero(), opening = ledgr_opening(cash = 1e6))
prof <- paste0("prof_", which, "_", strat, ".out")
t0 <- Sys.time()
Rprof(prof, interval = 0.02, memory.profiling = FALSE)
val <- if (which == "run") ledgr_run(exp, params = params, run_id = paste0("p", format(Sys.time(), "%H%M%OS3"))) else
  if (which == "sweep") ledgr_sweep(exp, do.call(ledgr_strategy_grid, params)) else NULL
Rprof(NULL)
cat(which, strat, "elapsed", format(difftime(Sys.time(), t0, units = "secs")), "\n")
s <- summaryRprof(prof)
options(width=200); print(head(s$by.total, 160))
cat("---- self\n")
print(head(s$by.self, 30))
if (which == "run") {
  tel <- ledgr:::ledgr_get_run_telemetry(val$run_id)
  cat("t_pre", tel$t_pre, "t_loop", tel$t_loop, "t_post", tel$t_post, "\n")
  t1 <- Sys.time(); d <- ledgr_results(val, "diagnostics"); cat("diag rows", nrow(d), format(difftime(Sys.time(), t1, units="secs")), "\n")
  t1 <- Sys.time(); e <- ledgr_results(val, "equity"); cat("equity read", format(difftime(Sys.time(), t1, units="secs")), "\n")
  t1 <- Sys.time(); f <- ledgr_results(val, "fills"); cat("fills", nrow(f), format(difftime(Sys.time(), t1, units="secs")), "\n")
  t1 <- Sys.time(); tr <- ledgr_results(val, "trades"); cat("trades read", format(difftime(Sys.time(), t1, units="secs")), "\n")
  t1 <- Sys.time(); print(val); cat("print", format(difftime(Sys.time(), t1, units="secs")), "\n")
}
