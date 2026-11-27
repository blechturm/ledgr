# The overflow refusals at P4 (Cut 27 decision 3, LDG-3276). On declared
# sessions, an opening of 1e308 shares (cost basis 1) and a strategy that
# sets its day-1 targets once:
# - ovf_sell_1.9: sold at 1.9, the proceeds are infinite while the lot
#   accounting is finite: the fill-delta refusal (ledgr_invalid_accounting_event);
# - ovf_hold_1.9: held, the valuation is infinite: refused later
#   (ledgr_config_non_finite), a control the P4 check must not pre-empt;
# - ovf_sell_10: sold at 10, the realized P&L overflows: the lot refusal
#   (ledgr_invalid_lot_fill) comes first, a control against checking the
#   batch too early;
# - ovf_delta_then_lot: in one pulse an earlier fill's infinite cash delta
#   (A at 1.9) and a later fill's lot overflow (B at 1e308): the earlier
#   row's delta refusal wins;
# - ovf_lot_then_delta: the reverse order (A at 1e308, B at 1.9): the
#   earlier row's lot refusal wins.
# Each workload keeps the run's tables and its escaping condition (the
# complete class vector), the failed sweep candidate's row
# (stop_on_error = FALSE) and the sweep's escaping condition
# (stop_on_error = TRUE).
ovf_snapshot <- function(name, prices) build(name, function(db) {
  pulses <- as.POSIXct("2024-01-01 16:00:00", tz = "UTC") + 86400 * 0:3
  ids <- names(prices)
  bars <- do.call(rbind, lapply(ids, function(id) data.frame(ts_utc = pulses, instrument_id = id,
    open = prices[[id]], high = prices[[id]], low = prices[[id]], close = prices[[id]], volume = 1000,
    stringsAsFactors = FALSE)))
  sessions <- ledgr::ledgr_facts_sessions(data.frame(session_date = as.Date(pulses), status = "open",
    session_open = "09:30:00", session_close = "16:00:00", knowledge_time = pulses - 86400,
    stringsAsFactors = FALSE), venue_id = "XNYS")
  ledgr::ledgr_snapshot_from_df(bars, instruments_df = data.frame(instrument_id = ids), facts = ledgr::ledgr_facts(sessions),
    price_basis = "split_adjusted", db_path = db, snapshot_id = name)
})
ovf_strategy <- function() {
  f <- function(ctx, params) {
    t <- ctx$hold()
    if (identical(substr(ctx$ts_utc, 1L, 10L), "2024-01-01")) t[names(params$t)] <- unlist(params$t)
    t
  }
  environment(f) <- ns
  f
}
ovf_condition <- function(e) data.frame(class = paste(class(e), collapse = "/"), message = conditionMessage(e),
                                        stringsAsFactors = FALSE)
ovf_workload <- function(name, prices, targets, opening) function() {
  db <- ovf_snapshot(name, prices)
  ids <- names(prices)
  exp <- function(snapshot) ledgr::ledgr_experiment(snapshot, ovf_strategy(), cost_model = ledgr::ledgr_cost_zero(),
    opening = ledgr::ledgr_opening(cash = 1000, positions = opening, cost_basis = stats::setNames(rep(1, length(ids)), ids)))
  run <- collect(db, name, paste0("ovf-", name), exp, params = list(t = targets), seed = 1L)
  snapshot <- ledgr::ledgr_snapshot_open(db, name, verify = TRUE)
  on.exit(ledgr::ledgr_snapshot_close(snapshot))
  grid <- ledgr::ledgr_grid_named(c = list(strategy = list(t = targets)))
  row <- a0_sweep_tables(suppressWarnings(ledgr::ledgr_sweep(exp(snapshot), grid, seed = 1L, stop_on_error = FALSE,
                                                             retain = a0_retain())))
  escape <- tryCatch({
    suppressWarnings(ledgr::ledgr_sweep(exp(snapshot), grid, seed = 1L, stop_on_error = TRUE, retain = a0_retain()))
    data.frame(class = "none", message = "", stringsAsFactors = FALSE)
  }, error = ovf_condition)
  c(run, list(sweep = row, sweep_escape = list(condition = escape)))
}
loop_overflow <- list(
  ovf_sell_1.9 = ovf_workload("ovf_sell_1.9", c(S = 1.9), list(S = 0), c(S = 1e308)),
  ovf_hold_1.9 = ovf_workload("ovf_hold_1.9", c(S = 1.9), list(), c(S = 1e308)),
  ovf_sell_10 = ovf_workload("ovf_sell_10", c(S = 10), list(S = 0), c(S = 1e308)),
  ovf_delta_then_lot = ovf_workload("ovf_delta_then_lot", c(A = 1.9, B = 1e308), list(A = 0, B = 0), c(A = 1e308, B = 2)),
  ovf_lot_then_delta = ovf_workload("ovf_lot_then_delta", c(A = 1e308, B = 1.9), list(A = 0, B = 0), c(A = 2, B = 1e308))
)

# The route each workload is named for, on the pin's own tables: the run's
# escaping condition, the failed candidate and the stopping sweep all carry
# the expected class; a P4 refusal is recorded by the run's exception
# diagnostic at stage "accounting" on the fill pulse.
ovf_refused <- function(class, stage = "accounting") function(t) {
  rc <- t$run$run_conditions
  err <- rc[rc$kind == "error", , drop = FALSE]
  ok <- NROW(err) == 1L && startsWith(err$class, class) &&
    identical(as.character(t$sweep$sweep$status), "FAILED") &&
    identical(as.character(t$sweep$sweep$error_class), class) &&
    startsWith(t$sweep_escape$condition$class, class)
  if (!ok || is.null(stage)) return(ok)
  d <- t$run$run_diagnostics
  e <- d[as.character(d$outcome) == "error", , drop = FALSE]
  NROW(e) == 1L && identical(as.character(e$stage), stage) &&
    identical(as.character(e$ts_utc), "2024-01-01T16:00:00Z") &&
    grepl(class, as.character(e$detail_json), fixed = TRUE)
}
loop_reach <- c(loop_reach, list(
  ovf_sell_1.9 = ovf_refused("ledgr_invalid_accounting_event"),
  ovf_hold_1.9 = ovf_refused("ledgr_config_non_finite", stage = NULL),
  ovf_sell_10 = ovf_refused("ledgr_invalid_lot_fill"),
  ovf_delta_then_lot = ovf_refused("ledgr_invalid_accounting_event"),
  ovf_lot_then_delta = ovf_refused("ledgr_invalid_lot_fill")
))
