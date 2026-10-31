# Base-versus-candidate public outcomes of the WS13 close review's F1
# (valuation) and F2 (compiled overflow) cases. Usage:
# Rscript public.R base|candidate <out-dir>
args <- commandArgs(TRUE)
root <- 'C:/Users/maxth/ledgr-wt/ws4a-impl'
if (args[1L] == 'base') {
  library(ledgr, lib.loc = 'E:/ledgr-data/r-lib/ledgr-v0.2.3-base-953338df')
} else {
  pkgload::load_all(root, quiet = TRUE)
}
out <- file.path(args[2L], paste0('public-', args[1L], '.txt'))
log <- file(out, 'wt')
sink(log, split = TRUE)
outcome <- function(expr) tryCatch({ force(expr); 'OK' },
  error = function(e) paste(class(e)[1L], conditionMessage(e), sep = ' | '))
public <- function(label, avail, prices, opening, targets, compiled = FALSE) {
  pulses <- as.POSIXct('2024-01-01 16:00:00', tz = 'UTC') + 86400 * 0:3
  bars <- do.call(rbind, lapply(names(prices), function(id) data.frame(ts_utc = pulses, instrument_id = id,
    open = prices[[id]], high = prices[[id]], low = prices[[id]], close = prices[[id]], volume = 1000,
    stringsAsFactors = FALSE)))
  db <- tempfile(fileext = '.duckdb')
  snap <- if (avail) {
    sessions <- ledgr_facts_sessions(data.frame(session_date = as.Date(pulses), status = 'open',
      session_open = '09:30:00', session_close = '16:00:00', knowledge_time = pulses - 86400), venue_id = 'XNYS')
    ledgr_snapshot_from_df(bars, instruments_df = data.frame(instrument_id = names(prices)),
      facts = ledgr_facts(sessions), price_basis = 'split_adjusted', db_path = db)
  } else ledgr_snapshot_from_df(bars, db_path = db)
  on.exit(ledgr_snapshot_close(snap))
  exp <- ledgr_experiment(snap, function(ctx, params) {
    t <- ctx$hold()
    if (identical(substr(ctx$ts_utc, 1L, 10L), '2024-01-01')) t[names(params$t)] <- unlist(params$t)
    t
  }, cost_model = ledgr_cost_zero(), opening = opening)
  cat(label, '\n')
  if (!compiled) {
    cat('  run:  ', suppressWarnings(outcome(close(ledgr_run(exp, params = list(t = targets), run_id = 'pub', seed = 1L)))), '\n')
  }
  s <- suppressWarnings(ledgr_sweep(exp, ledgr_grid_named(c = list(strategy = list(t = targets))), seed = 1L,
    compiled_accounting_model = if (compiled) 'spot_fifo' else NULL))
  cat('  sweep:', s$status[1L], s$error_class[1L], s$error_msg[1L], 'final_equity=', s$final_equity[1L], '\n')
}
long <- function(id, q, basis) ledgr_opening(cash = 1000, positions = stats::setNames(q, id), cost_basis = stats::setNames(basis, id))
cat('MODE', args[1L], '\n')
public('A10 availability, long 1e308 basis 1 at 10, target 0 (review F1)', TRUE, list(S = 10), long('S', 1e308, 1), list(S = 0))
public('A19 availability, long 1e308 basis 1 at 1.9, target 0', TRUE, list(S = 1.9), long('S', 1e308, 1), list(S = 0))
public('H10 availability, long 1e308 basis 1 at 10, hold', TRUE, list(S = 10), long('S', 1e308, 1), list())
public('H19 availability, long 1e308 basis 1 at 1.9, hold', TRUE, list(S = 1.9), long('S', 1e308, 1), list())
public('C dense, long 1e308 basis 1 at 1.9, hold (item c)', FALSE, list(S = 1.9), long('S', 1e308, 1), list())
public('B1 compiled, buy 1e308 at 10', FALSE, list(S = 10), ledgr_opening(cash = 1000), list(S = 1e308), TRUE)
public('B2 compiled, sell long 1e308 basis -1 at 1.5', FALSE, list(S = 1.5), long('S', 1e308, -1), list(S = 0), TRUE)
public('B3 compiled ordinary, buy 5 at 10', FALSE, list(S = 10), ledgr_opening(cash = 1000), list(S = 5), TRUE)
sink(); close(log)
