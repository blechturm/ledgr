# Probe: does per-pulse block writing of fill events reproduce ledgr's event
# stream on the smallest real run and sweep? Usage, from the repository root:
#   Rscript dev/spikes/fill-event-block-write/probe.R
suppressMessages(pkgload::load_all(".", quiet = TRUE, compile = FALSE))
ns <- asNamespace("ledgr")
source("dev/spikes/fill-event-block-write/seam.R")
block <- bw_block_functions(ns)

bars <- as.data.frame(ledgr_sim_bars(n_instruments = 6L, n_days = 60L, seed = 11L))
pristine <- tempfile(fileext = ".duckdb")
snap <- ledgr_snapshot_from_df(bars, db_path = pristine, snapshot_id = "probe")
ledgr_snapshot_close(snap)

sma_exp <- function(snapshot) ledgr_experiment(snapshot, ledgr_demo_sma_crossover_strategy(),
  features = ledgr_feature_map(fast = ledgr_ind_sma(ledgr_param("fast_n")), slow = ledgr_ind_sma(ledgr_param("slow_n"))),
  opening = ledgr_opening(cash = 1e5), cost_model = ledgr_cost_zero())

run_arm <- function(functions) {
  path <- tempfile(fileext = ".duckdb"); file.copy(pristine, path)
  snapshot <- ledgr_snapshot_open(path, "probe")
  run <- bw_with(ns, functions, ledgr_run(sma_exp(snapshot), params = list(qty = 1, threshold = 0),
    feature_params = list(fast_n = 3L, slow_n = 7L), run_id = "probe-run", seed = 1L))
  fills <- ledgr_results(run, what = "fills"); equity <- ledgr_results(run, what = "equity")
  close(run); ledgr_snapshot_close(snapshot)
  con <- DBI::dbConnect(duckdb::duckdb(), path, read_only = TRUE)
  events <- DBI::dbGetQuery(con, "SELECT * FROM ledger_events WHERE run_id = 'probe-run' ORDER BY event_seq")
  DBI::dbDisconnect(con, shutdown = TRUE)
  list(events = events, fills = fills, equity = equity)
}
sweep_arm <- function(functions) {
  snapshot <- ledgr_snapshot_open(pristine, "probe")
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  grid <- ledgr_grid_cross(features = ledgr_feature_grid(fast_n = 3L, slow_n = 7L),
    strategy = ledgr_strategy_grid(qty = 1, threshold = c(0, 0.01)))
  s <- bw_with(ns, functions, suppressWarnings(ledgr_sweep(sma_exp(snapshot), grid, seed = 1L,
    retain = ledgr_sweep_retention(returns = "completed", trades = "closed"))))
  s[!grepl("^t_", names(s))]
}

rb <- run_arm(NULL); rk <- run_arm(block)
cat("run: ledger events", nrow(rb$events), "base vs", nrow(rk$events), "block; identical:", identical(rb$events, rk$events), "\n")
cat("run: fills identical:", identical(rb$fills, rk$fills), " equity identical:", identical(rb$equity, rk$equity), "\n")
sb <- sweep_arm(NULL); sk <- sweep_arm(block)
cat("sweep: columns", paste(names(sb), collapse = ","), "\n")
cat("sweep: identical:", identical(sb, sk), " n_trades:", paste(sb$n_trades, collapse = "/"), "\n")
if (!identical(sb, sk)) print(names(sb)[!mapply(identical, sb, sk)])
gut <- bw_block_functions(ns, "misorder")
rg <- run_arm(gut); sg <- sweep_arm(gut)
cat("gut misorder: run events identical:", identical(rb$events, rg$events), " sweep identical:", identical(sb, sg), "\n")
