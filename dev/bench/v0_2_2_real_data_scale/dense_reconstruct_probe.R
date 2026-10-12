# Dense reconstruction identity probe (Cut 12 LDG-3006).
#
#   Rscript dense_reconstruct_probe.R <repo>
#
# The fixture lane reaches ledgr_state_reconstruct() only on availability
# runs, so the dense close map needs its own witness. This probe seals a dense
# snapshot (30 instruments, 400 sessions), commits a run that trades every
# session, reconstructs it and prints a SHA-256 digest of the reconstructed
# equity curve, positions and cash. Two trees with the same digest rebuild
# byte-identical state. Synthetic data only.
args <- commandArgs(trailingOnly = TRUE)
suppressMessages(pkgload::load_all(args[[1L]], quiet = TRUE, compile = FALSE))
set.seed(1L)
ids <- sprintf("I%02d", 1:30)
days <- as.POSIXct("2020-01-02 21:00:00", tz = "UTC") + 86400 * 0:399
close <- 50 * exp(apply(matrix(stats::rnorm(400 * 30, 0, 0.01), 400), 2, cumsum))
bars <- data.frame(instrument_id = rep(ids, each = 400), ts_utc = rep(days, 30), open = as.vector(close),
                   high = as.vector(close) * 1.01, low = as.vector(close) * 0.99, close = as.vector(close), volume = 1000)
db <- tempfile(fileext = ".duckdb")
snapshot <- ledgr_snapshot_from_df(bars, db_path = db)
strategy <- function(ctx, params) {
  target <- ctx$flat()
  day <- as.integer(as.numeric(as.POSIXct(ctx$ts_utc, tz = "UTC")) %/% 86400)
  target[ctx$universe[(seq_along(ctx$universe) + day) %% 3L == 0L]] <- 10
  target
}
exp <- ledgr_experiment(snapshot, strategy, cost_model = ledgr_cost_zero(), opening = ledgr_opening(cash = 1e5))
close(ledgr_run(exp, run_id = "dense_reconstruct"))
ledgr_snapshot_close(snapshot)
con <- DBI::dbConnect(duckdb::duckdb(), db)
state <- ledgr_state_reconstruct("dense_reconstruct", con)
DBI::dbDisconnect(con, shutdown = TRUE)
payload <- list(equity = state$equity_curve, positions = state$positions, cash = state$cash)
cat(sprintf("RESULT rows=%d digest=%s\n", nrow(state$equity_curve), digest::digest(payload, algo = "sha256")))
