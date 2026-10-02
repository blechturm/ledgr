# Availability-aware sweep, sweep save/open and walk-forward costs.
# Rscript lw_sweepwf.R <repo> <snapshot_db> <out_json>
args <- commandArgs(TRUE)
repo <- args[[1]]; db <- args[[2]]; out_json <- args[[3]]
suppressMessages(pkgload::load_all(repo, quiet = TRUE, compile = FALSE))

momentum <- function(ctx, params) {
  month <- format(ledgr_utc(ctx$ts_utc), "%Y-%m", tz = "UTC")
  if (identical(ctx$state_prev$month, month)) return(ctx$hold())
  if (sum(is.finite(ctx$vec$feature("return_252"))) < 20L) {
    return(list(targets = ctx$hold(), state_update = list(month = month)))
  }
  targets <- ctx |>
    ledgr_signal_return(lookback = 252) |>
    ledgr_select_top_n(params$n, partial = "allow") |>
    ledgr_weight_equal() |>
    ledgr_target_rebalance(ctx, equity_fraction = params$frac)
  list(targets = targets, state_update = list(month = month))
}

snapshot <- ledgr_snapshot_open(db)
exp <- ledgr_experiment(
  snapshot, momentum,
  features = list(ledgr_ind_returns(63), ledgr_ind_returns(126), ledgr_ind_returns(252)),
  universe = ledgr_universe_members("synthetic_members"),
  valuation_policy = ledgr_valuation_stale(max_sessions = 2L),
  cost_model = ledgr_cost_zero(),
  opening = ledgr_opening(cash = 1e6)
)
grid <- ledgr_strategy_grid(n = c(5, 10), frac = c(0.5, 0.95))
clock <- function(expr) { t0 <- proc.time()[["elapsed"]]; v <- force(expr); list(value = v, s = proc.time()[["elapsed"]] - t0) }
gc(full = TRUE)

s1 <- clock(ledgr_sweep(exp, grid)); cat('SWEEP1', s1$s, '
')
s2 <- clock(ledgr_sweep(exp, grid)); cat('SWEEP2', s2$s, '
')
sv <- clock(ledgr_sweep_save(s1$value, snapshot, sweep_id = "lw_sweep"))
op <- clock(ledgr_sweep_open(snapshot, "lw_sweep")); cat('SAVE', sv$s, 'OPEN', op$s, '
')

folds <- ledgr_folds_rolling(start = "1999-01-04", end = "2000-12-29",
                             train_window = "6 months", test_window = "3 months", step = "6 months")
n_folds <- tryCatch(length(folds$folds %||% folds), error = function(e) NA)
wf <- clock(tryCatch(ledgr_walk_forward(exp, grid = grid, folds = folds,
                                        selection_rule = ledgr_rule_argmax("sharpe_ratio"), seed = 1L),
                     error = function(e) e))
out <- list(
  sweep_cold_s = s1$s, sweep_second_call_s = s2$s, candidates = nrow(s1$value),
  sweep_status = paste(unique(s1$value$status), collapse = ","),
  save_s = sv$s, open_s = op$s,
  folds = n_folds, walk_forward_s = wf$s,
  walk_forward_status = if (inherits(wf$value, "error")) paste("ERROR:", conditionMessage(wf$value)) else "returned")
ledgr_snapshot_close(snapshot)
jsonlite::write_json(out, out_json, auto_unbox = TRUE, pretty = TRUE)
print(unlist(out))
