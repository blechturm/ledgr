# Long-window scaling reproducer: measured ledgr_run() calls in a fresh process.
# Rscript lw_run.R <repo> <snapshot_db> <strategy: momentum|flat> <marker> <out_json> [prof_file] [n_runs]
# n_runs > 1 repeats the same experiment on the same store with new run_ids, so
# run 1 computes and persists features and later runs can reuse them.
# Each run is split into phases by timestamps taken inside the strategy:
#   setup    = ledgr_run() entry to the first strategy call
#   loop     = first to last strategy call
#   finalize = last strategy call to ledgr_run() return
args <- commandArgs(TRUE)
repo <- args[[1]]; db <- args[[2]]; strategy_name <- args[[3]]
marker <- args[[4]]; out_json <- args[[5]]
prof <- if (length(args) >= 6 && nzchar(args[[6]]) && args[[6]] != "none") args[[6]] else NULL
n_runs <- if (length(args) >= 7) as.integer(args[[7]]) else 1L
suppressMessages(pkgload::load_all(repo, quiet = TRUE, compile = FALSE))

.lw <- new.env()
momentum <- function(ctx, params) {
  now <- proc.time()[["elapsed"]]
  if (is.null(.lw$first)) .lw$first <- now
  .lw$last <- now
  .lw$calls <- .lw$calls + 1L
  month <- format(ledgr_utc(ctx$ts_utc), "%Y-%m", tz = "UTC")
  if (identical(ctx$state_prev$month, month)) return(ctx$hold())
  if (sum(is.finite(ctx$vec$feature("return_252"))) < 20L) {
    return(list(targets = ctx$hold(), state_update = list(month = month)))
  }
  .lw$decisions <- .lw$decisions + 1L
  targets <- ctx |>
    ledgr_signal_return(lookback = 252) |>
    ledgr_select_top_n(10, partial = "allow") |>
    ledgr_weight_equal() |>
    ledgr_target_rebalance(ctx, equity_fraction = 0.95)
  list(targets = targets, state_update = list(month = month))
}
flat <- function(ctx, params) {
  now <- proc.time()[["elapsed"]]
  if (is.null(.lw$first)) .lw$first <- now
  .lw$last <- now
  .lw$calls <- .lw$calls + 1L
  ctx$flat()
}
strategy <- switch(strategy_name, momentum = momentum, flat = flat)

snapshot <- ledgr_snapshot_open(db)
exp <- ledgr_experiment(
  snapshot, strategy,
  features = if (identical(Sys.getenv("LW_NOFEAT"), "1")) list() else list(ledgr_ind_returns(63), ledgr_ind_returns(126), ledgr_ind_returns(252)),
  universe = ledgr_universe_members("synthetic_members"),
  valuation_policy = ledgr_valuation_stale(max_sessions = 2L),
  cost_model = ledgr_cost_zero(),
  opening = ledgr_opening(cash = 1e6),
  persist_features = !identical(Sys.getenv("LW_PERSIST", "TRUE"), "FALSE")
)
gc(full = TRUE)
writeLines("start", marker)
runs <- list()
for (k in seq_len(n_runs)) {
  .lw$first <- NULL; .lw$last <- NULL; .lw$calls <- 0L; .lw$decisions <- 0L
  if (!is.null(prof) && k == 1L) Rprof(prof, interval = 0.05)
  t0 <- proc.time()
  res <- tryCatch(ledgr_run(exp, run_id = sprintf("lw%d", k)), error = function(e) e)
  el <- proc.time() - t0
  if (!is.null(prof) && k == 1L) Rprof(NULL)
  start <- t0[["elapsed"]]; end <- start + el[["elapsed"]]
  runs[[k]] <- list(
    run_id = sprintf("lw%d", k), elapsed_s = el[["elapsed"]], cpu_s = el[["user.self"]] + el[["sys.self"]],
    setup_s = if (is.null(.lw$first)) NA else .lw$first - start,
    loop_s = if (is.null(.lw$first)) NA else .lw$last - .lw$first,
    finalize_s = if (is.null(.lw$last)) NA else end - .lw$last,
    calls = .lw$calls, decisions = .lw$decisions,
    r_status = if (inherits(res, "error")) paste("ERROR:", conditionMessage(res)) else "returned")
  cat(sprintf("RUN %d: %.1f s (setup %.1f, loop %.1f, finalize %.1f), %d calls\n", k,
              runs[[k]]$elapsed_s, runs[[k]]$setup_s, runs[[k]]$loop_s, runs[[k]]$finalize_s, runs[[k]]$calls))
}
ledgr_snapshot_close(snapshot)
con <- DBI::dbConnect(duckdb::duckdb(), db, read_only = TRUE)
count <- function(tbl, id) tryCatch(DBI::dbGetQuery(con, sprintf("SELECT count(*) AS n FROM %s WHERE run_id = '%s'", tbl, id))$n, error = function(e) NA)
tables <- c("ledger_events", "equity_curve", "run_diagnostics", "strategy_state", "features")
for (k in seq_along(runs)) {
  runs[[k]]$rows <- setNames(lapply(tables, count, id = runs[[k]]$run_id), tables)
  runs[[k]]$run_status <- tryCatch(DBI::dbGetQuery(con, sprintf("SELECT status FROM runs WHERE run_id = '%s'", runs[[k]]$run_id))$status, error = function(e) NA)
}
feature_total <- tryCatch(DBI::dbGetQuery(con, "SELECT count(*) AS n FROM features")$n, error = function(e) NA)
DBI::dbDisconnect(con, shutdown = TRUE)
out <- list(strategy = strategy_name, runs = runs, feature_rows_total = feature_total)
jsonlite::write_json(out, out_json, auto_unbox = TRUE, pretty = TRUE)
cat("RUN_OK\n")
