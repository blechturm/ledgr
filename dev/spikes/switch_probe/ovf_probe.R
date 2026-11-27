# Switch probe, extended by LDG-3276: the valuation-overflow refusals on the
# pin and on the lean core, asserted. Five declared-session cases (Cut 27
# decision 3): a 1e308 holding sold at 1.9, held at 1.9 and sold at 10; and
# two multi-fill pulses, an earlier fill's non-finite cash delta before a
# later fill's lot overflow, and the reverse (the inputs of the Cut 27 cut
# review's overflow_order_probe.R). For each case and debug setting, the
# lean core's escaping condition (complete class vector and message) through
# ledgr_run() and ledgr_sweep(stop_on_error = TRUE), and its failed
# candidate's class and message with stop_on_error = FALSE, must equal the
# pin's; each case must also refuse with its expected class.
#
#   Rscript ovf_probe.R --lean=<dir holding load.R> --lib=<pin library> --out=<txt>
local({
  arg <- function(n) sub(paste0("^--", n, "="), "", grep(paste0("^--", n, "="), commandArgs(TRUE), value = TRUE)[[1L]])
  assign("lean_dir", normalizePath(arg("lean"), winslash = "/", mustWork = TRUE), globalenv())
  assign("lib", normalizePath(arg("lib"), winslash = "/", mustWork = TRUE), globalenv())
  assign("out", arg("out"), globalenv())
})
source(file.path(lean_dir, "load.R"))
lean <- lean_core_load(lib)
library(ledgr)
probe <- function(prices, targets, opening_qty) {
  pulses <- as.POSIXct("2024-01-01 16:00:00", tz = "UTC") + 86400 * 0:3
  ids <- names(prices)
  bars <- do.call(rbind, lapply(ids, function(id) data.frame(ts_utc = pulses, instrument_id = id,
    open = prices[[id]], high = prices[[id]], low = prices[[id]], close = prices[[id]], volume = 1000)))
  sessions <- ledgr_facts_sessions(data.frame(session_date = as.Date(pulses), status = "open",
    session_open = "09:30:00", session_close = "16:00:00", knowledge_time = pulses - 86400), venue_id = "XNYS")
  snap <- ledgr_snapshot_from_df(bars, instruments_df = data.frame(instrument_id = ids),
    facts = ledgr_facts(sessions), price_basis = "split_adjusted", db_path = tempfile(fileext = ".duckdb"))
  on.exit(ledgr_snapshot_close(snap))
  strategy <- function(ctx, params) {
    t <- ctx$hold()
    if (identical(substr(ctx$ts_utc, 1L, 10L), "2024-01-01")) t[names(params$t)] <- unlist(params$t)
    t
  }
  exp <- ledgr_experiment(snap, strategy, cost_model = ledgr_cost_zero(),
    opening = ledgr_opening(cash = 1000, positions = opening_qty, cost_basis = stats::setNames(rep(1, length(ids)), ids)))
  cond <- function(e) paste(paste(class(e), collapse = "/"), "|", conditionMessage(e))
  grid <- ledgr_grid_named(c = list(strategy = list(t = targets)))
  run <- tryCatch({ close(suppressWarnings(ledgr_run(exp, params = list(t = targets), run_id = "ovf", seed = 1L))); "none" },
                  error = cond)
  escape <- tryCatch({ suppressWarnings(ledgr_sweep(exp, grid, seed = 1L, stop_on_error = TRUE)); "none" }, error = cond)
  row <- suppressWarnings(ledgr_sweep(exp, grid, seed = 1L, stop_on_error = FALSE))
  c(run = run, sweep_escape = escape, sweep_row = paste(row$error_class[[1L]], "|", row$error_msg[[1L]]))
}
cases <- list(
  sell_at_1.9 = list(c(S = 1.9), list(S = 0), c(S = 1e308), "ledgr_invalid_accounting_event"),
  hold_at_1.9 = list(c(S = 1.9), list(), c(S = 1e308), "ledgr_config_non_finite"),
  sell_at_10 = list(c(S = 10), list(S = 0), c(S = 1e308), "ledgr_invalid_lot_fill"),
  early_delta_late_lot = list(c(A = 1.9, B = 1e308), list(A = 0, B = 0), c(A = 1e308, B = 2), "ledgr_invalid_accounting_event"),
  early_lot_late_delta = list(c(A = 1e308, B = 1.9), list(A = 0, B = 0), c(A = 2, B = 1e308), "ledgr_invalid_lot_fill"))
lines <- character()
say <- function(...) { s <- sprintf(...); lines <<- c(lines, s); cat(s, "\n") }
fail <- 0L
for (nm in names(cases)) {
  a <- cases[[nm]]
  pin <- probe(a[[1L]], a[[2L]], a[[3L]])
  say("== %s (expected %s)", nm, a[[4L]])
  for (f in names(pin)) say("  pin  %-13s %s", f, pin[[f]])
  if (!all(startsWith(pin, a[[4L]]))) { fail <- fail + 1L; say("  FAIL: the pin does not refuse with %s", a[[4L]]) }
  for (debug in c(FALSE, TRUE)) {
    lean$.lean_debug <- debug
    restore <- lean$lean_loop_install(hooks = FALSE)
    ln <- tryCatch(probe(a[[1L]], a[[2L]], a[[3L]]), finally = restore())
    same <- identical(unname(ln), unname(pin))
    if (!same) {
      fail <- fail + 1L
      for (f in names(ln)) say("  lean %-13s %s", f, ln[[f]])
    }
    say("  lean debug %s: %s", debug, if (same) "identical to the pin" else "DIFFERS")
  }
}
say("%s: %d failure(s)", if (fail) "OVERFLOW PROBE FAIL" else "OVERFLOW PROBE PASS", fail)
writeLines(lines, out)
quit(status = if (fail) 1L else 0L)
