# Switch probe: the valuation-overflow case the suite probe found
# (test-ws4a-carrier.R, "[WS4a valuation overflow]"): a 1e308 holding sold
# at 1.9, on declared sessions. Pin and lean conditions for run and sweep.
#   Rscript ovf_probe.R --tree=<release tree with LEDGR_SOURCE_COMMIT>
tree <- normalizePath(sub("^--tree=", "", grep("^--tree=", commandArgs(TRUE), value = TRUE)[[1L]]), winslash = "/")
source(file.path(tree, "dev", "lean_core", "load.R"))
lean <- lean_core_load(tree)
library(ledgr)
ovf <- function(price, targets) {
  pulses <- as.POSIXct("2024-01-01 16:00:00", tz = "UTC") + 86400 * 0:3
  bars <- data.frame(ts_utc = pulses, instrument_id = "S", open = price, high = price, low = price,
    close = price, volume = 1000, stringsAsFactors = FALSE)
  sessions <- ledgr_facts_sessions(data.frame(session_date = as.Date(pulses), status = "open",
    session_open = "09:30:00", session_close = "16:00:00", knowledge_time = pulses - 86400,
    stringsAsFactors = FALSE), venue_id = "XNYS")
  snap <- ledgr_snapshot_from_df(bars, instruments_df = data.frame(instrument_id = "S"),
    facts = ledgr_facts(sessions), price_basis = "split_adjusted", db_path = tempfile(fileext = ".duckdb"))
  on.exit(ledgr_snapshot_close(snap))
  strategy <- function(ctx, params) {
    t <- ctx$hold()
    if (identical(substr(ctx$ts_utc, 1L, 10L), "2024-01-01")) t[names(params$t)] <- unlist(params$t)
    t
  }
  exp <- ledgr_experiment(snap, strategy, cost_model = ledgr_cost_zero(),
    opening = ledgr_opening(cash = 1000, positions = c(S = 1e308), cost_basis = c(S = 1)))
  cond <- function(e) paste(class(e)[[1L]], "|", conditionMessage(e))
  run <- tryCatch({ close(suppressWarnings(ledgr_run(exp, params = list(t = targets), run_id = "ovf", seed = 1L))); "none" },
                  error = cond)
  s <- suppressWarnings(ledgr_sweep(exp, ledgr_grid_named(c = list(strategy = list(t = targets))), seed = 1L))
  list(run = run, sweep = paste(s$error_class[[1L]], "|", s$error_msg[[1L]]))
}
cases <- list(sell_at_1.9 = list(1.9, list(S = 0)), hold_at_1.9 = list(1.9, list()), sell_at_10 = list(10, list(S = 0)))
for (nm in names(cases)) {
  a <- cases[[nm]]
  pin <- ovf(a[[1L]], a[[2L]])
  restore <- lean$lean_loop_install(hooks = FALSE)
  ln <- tryCatch(ovf(a[[1L]], a[[2L]]), finally = restore())
  cat("==", nm, "\n  pin  run:  ", pin$run, "\n  lean run:  ", ln$run,
      "\n  pin  sweep:", pin$sweep, "\n  lean sweep:", ln$sweep, "\n")
}
