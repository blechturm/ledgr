# Slice-3 probe, step 1: which slice-3 branches does the pin take on small
# missing-bar scenarios over a declared session calendar? Pin library only;
# prints the run status and the reason codes in its diagnostics.
lib <- "C:/Users/maxth/AppData/Local/Temp/claude/a337d437c6e22de3/78383ced-ac83-4579-b480-65f39660106d/scratchpad/ws16/lib-d5b3a151"
library(ledgr, lib.loc = lib)
out <- "C:/Users/maxth/ledgr-wt/slice3-probe-out"
n_days <- 20L
dates <- as.Date("2020-01-01") + seq_len(n_days) - 1L
at <- function(k) as.POSIXct(paste(dates[k], "16:00:00"), tz = "UTC")
day <- function(k) format(dates[[k]], "%Y-%m-%d")
closes_for <- function(drop = list()) {
  x <- list(A = 30 * (1 + 0.02 * sin(1:n_days)), B = 45 * (1 + 0.02 * sin(2:(n_days + 1))),
            C = 12 * (1 + 0.02 * sin(3:(n_days + 2))))
  for (id in names(drop)) x[[id]][drop[[id]]] <- NA
  x
}
snapshot_for <- function(name, closes) {
  sessions <- ledgr_facts_sessions(data.frame(session_date = dates, status = "open", session_open = "09:30:00",
    session_close = "16:00:00", knowledge_time = as.POSIXct(dates, tz = "UTC") - 1, stringsAsFactors = FALSE),
    venue_id = "XNYS")
  bars <- do.call(rbind, lapply(names(closes), function(id) {
    k <- which(!is.na(closes[[id]]))
    data.frame(ts_utc = at(k), instrument_id = id, open = closes[[id]][k], high = closes[[id]][k] + 1,
               low = closes[[id]][k] - 1, close = closes[[id]][k], volume = 1000, stringsAsFactors = FALSE)
  }))
  db <- file.path(out, paste0(name, ".duckdb"))
  if (file.exists(db)) unlink(db)
  ledgr_snapshot_from_df(bars, instruments_df = data.frame(instrument_id = names(closes)),
                         facts = ledgr_facts(sessions), price_basis = "split_adjusted", db_path = db, snapshot_id = name)
}
plan_strategy <- function(plan) {
  force(plan)
  function(ctx, params) {
    targets <- ctx$hold()
    want <- plan[[substr(ctx$ts_utc, 1L, 10L)]]
    if (!is.null(want)) targets[names(want)] <- want
    targets
  }
}
run_case <- function(name, drop, plan, valuation = NULL, risk = ledgr_risk_none(), strategy = NULL) {
  snap <- snapshot_for(name, closes_for(drop))
  on.exit(ledgr_snapshot_close(snap))
  if (is.null(strategy)) strategy <- plan_strategy(plan)
  r <- tryCatch({
    exp <- ledgr_experiment(snap, strategy, opening = ledgr_opening(cash = 1e4), cost_model = ledgr_cost_zero(),
                            risk_chain = risk, valuation_policy = valuation)
    ledgr_run(exp, run_id = name)
  }, error = function(e) e)
  if (inherits(r, "error")) {
    cat(sprintf("%-18s ERROR %s | %s\n", name, class(r)[[1L]], substr(conditionMessage(r), 1, 120)))
    return(invisible())
  }
  d <- tryCatch(as.data.frame(ledgr_results(r, what = "diagnostics")), error = function(e) NULL)
  rc <- if (is.null(d) || !"reason_code" %in% names(d)) character() else as.character(d$reason_code)
  codes <- sort(table(unlist(strsplit(rc[!is.na(rc) & nzchar(rc)], "|", fixed = TRUE))), decreasing = TRUE)
  st <- tryCatch(as.character(ledgr_run_info(r)$status), error = function(e) "?")
  cat(sprintf("%-18s status %s | %s\n", name, st, paste(names(codes), codes, sep = "=", collapse = " ")))
  close(r)
}
stale <- function(n, ex) ledgr_valuation_stale(max_sessions = n, exhausted = ex)
run_case("gap_default", list(B = 8L), stats::setNames(list(c(A = 10, B = 10)), day(2)))
run_case("gap_stale_ok", list(B = 8L), stats::setNames(list(c(A = 10, B = 10)), day(2)), stale(3, "freeze"))
run_case("stop_freeze", list(B = 12:20), stats::setNames(list(c(A = 10, B = 10)), day(2)), stale(2, "freeze"))
run_case("stop_refuse", list(B = 12:20), stats::setNames(list(c(A = 10, B = 10)), day(2)), stale(2, "refuse"))
run_case("buy_on_stale", list(B = 7:8), stats::setNames(list(c(A = 10), c(B = 10)), c(day(2), day(8))), stale(3, "freeze"))
run_case("reduce_on_stale", list(B = 7:8), stats::setNames(list(c(A = 10, B = 20), c(B = 5)), c(day(2), day(8))),
         stale(3, "freeze"), risk = ledgr_risk_max_weight(0.9))
run_case("exec_bar_missing", list(C = 6L), stats::setNames(list(c(C = 10)), day(5)), stale(3, "freeze"))
run_case("sizing_unpriced", list(C = 5L), NULL, stale(3, "freeze"),
         strategy = function(ctx, params) ledgr_target_rebalance(ctx, c(A = 0.3, B = 0.3, C = 0.3)))
