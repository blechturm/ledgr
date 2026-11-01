# F1 differential: base 953338df library versus candidate worktree.
# Usage: Rscript probe_f1.R base|candidate
mode <- commandArgs(TRUE)[[1L]]
if (mode == "base") {
  library(ledgr, lib.loc = "E:/ledgr-data/r-lib/ledgr-v0.2.3-base-953338df")
} else {
  suppressMessages(pkgload::load_all("C:/Users/maxth/ledgr-wt/ws4a-impl", quiet = TRUE))
}
ns <- asNamespace("ledgr")
show <- function(label, expr) {
  w <- 0L
  out <- withCallingHandlers(tryCatch(expr, error = identity), warning = function(x) {
    w <<- w + 1L
    invokeRestart("muffleWarning")
  })
  txt <- if (inherits(out, "error")) {
    sprintf("ERROR %s | %s", paste(setdiff(class(out), c("rlang_error", "error", "condition")), collapse = "/"),
      conditionMessage(out))
  } else out
  cat(sprintf("%-28s warnings=%d %s\n", label, w, txt))
}
t0 <- as.POSIXct("2024-01-02 16:00:00", tz = "UTC")
t1 <- as.POSIXct("2024-01-03 14:30:00", tz = "UTC")
resolver <- function(fixed = 0) ns$ledgr_cost_resolver_from_model(ledgr_cost_chain(ledgr_cost_fixed_fee(fixed)))
overflow <- function() ns$ledgr_cost_resolver_from_model(ledgr_cost_chain(ledgr_cost_fixed_fee(1e308), ledgr_cost_notional_bps_fee(1e308)))

# Dense planner: two rows A, B; `open` the next opens; `sub` a sub-second next pulse.
dense <- function(position, target, open = c(10, 10), has_next = TRUE, sub = FALSE, cost = resolver()) {
  ids <- c("A", "B")
  next_ts <- t1 + if (sub) 0.25 else 0
  m <- function(v) matrix(c(10, 10, v), 2L, 2L, dimnames = list(ids, NULL))
  bars <- list(open = m(open), high = m(open), low = m(open), close = m(open), volume = m(c(1, 1)))
  if (mode == "base") {
    pulses <- if (has_next) c(t0, next_ts) else t0
    p <- ns$ledgr_fold_build_pulse_plan(stats::setNames(target, ids), ids, 1:2, position, target - position, 1:2, 1L,
      pulses, bars, cost, "2024-01-02T16:00:00Z")
    paste("fills", paste(vapply(p$fills, function(e) paste0(e$instrument_id, ":fee=", e$fill$fee), ""), collapse = ","))
  } else {
    p <- ns$ledgr_fold_build_pulse_plan(1:2, target, position, 1:2, 1L, has_next, as.numeric(next_ts),
      ns$ledgr_plan_epoch_valid(as.numeric(next_ts)), bars, cost, 2L)
    paste("fills", paste(paste0(ids[p$fill$pos], ":fee=", p$fill$fee), collapse = ","))
  }
}
# Availability planner: two rows A, B; next opens `open`; `sub` a sub-second opportunity.
avail <- function(position, target, open = c(10, 10), sub = FALSE, cost = resolver(), cash = 1000) {
  ids <- c("A", "B")
  exec <- t1 + if (sub) 0.25 else 0
  if (mode == "base") {
    provider <- list(execution_view = function(cutoff, x) list(member = stats::setNames(rep(TRUE, length(x)), x),
      restricted = stats::setNames(rep(FALSE, length(x)), x), reasons = stats::setNames(rep("", length(x)), x)))
    p <- ns$ledgr_fold_build_availability_pulse_plan(stats::setNames(target, ids), ids, 1:2, position, target - position,
      1:2, 1L, exec, NULL, cost, "x", provider, stats::setNames(c(TRUE, TRUE), ids), cash,
      next_bars = list(open = open, high = open, low = open, close = open, volume = c(1, 1)))
    paste("fills", paste(vapply(p$fills, `[[`, "", "instrument_id"), collapse = ","),
      "| rejected", paste(vapply(p$rejected, function(e) paste0(e$instrument_id, ":", e$reasons), ""), collapse = ","))
  } else {
    p <- ns$ledgr_fold_build_availability_pulse_plan(1:2, target, position, 1:2, c(TRUE, TRUE),
      list(exec_ts = as.numeric(exec), has_next = TRUE, open = open),
      list(member = c(TRUE, TRUE), restricted = c(FALSE, FALSE), reason_offset = c(0L, 0L), reason_count = c(0L, 0L),
        reason_code = integer()), ns$ledgr_plan_epoch_valid(as.numeric(exec)), cost, cash, ids)
    txt <- ns$ledgr_carrier_segment_text(p$rejection$reason_offset, p$rejection$reason_count, p$rejection$reason_code,
      ns$.ledgr_plan_reason_levels)$reasons
    paste("fills", paste(ids[p$fill$pos], collapse = ","), "| rejected", paste(paste0(ids[p$rejection$pos], ":", txt), collapse = ","))
  }
}
big <- 1e308
cat("== planners\n")
show("dense delta1 open2", dense(c(-big, 0), c(big, 1), open = c(10, NA)))
show("dense open1 delta2", dense(c(0, -big), c(1, big), open = c(NA, 10)))
show("dense ok1 delta2 sub", dense(c(0, -big), c(1, big), sub = TRUE))
show("dense delta1 sub", dense(c(-big, 0), c(big, 1), sub = TRUE))
show("dense open1 sub", dense(c(0, 0), c(1, 1), open = c(NA, 10), sub = TRUE))
show("dense final ok1 delta2", dense(c(0, -big), c(1, big), has_next = FALSE))
show("dense final delta1", dense(c(-big, 0), c(big, 1), has_next = FALSE))
show("dense fee overflow", dense(c(0, 0), c(2, 1), cost = overflow()))
show("avail short1 delta2", avail(c(0, -big), c(-1, big)))
show("avail delta1 short2", avail(c(-big, 0), c(big, -1)))
show("avail nobar-delta1 short2", avail(c(-big, 0), c(big, -1), open = c(NA, 10)))
show("avail nobar1 delta2 sub", avail(c(0, -big), c(1, big), open = c(NA, 10), sub = TRUE))
show("avail ok1 sub", avail(c(0, 0), c(1, 1), sub = TRUE))
show("avail nobar both sub", avail(c(0, 0), c(1, 1), open = c(NA, NA), sub = TRUE))
show("avail short1 sub", avail(c(0, 0), c(-1, 1), sub = TRUE))
show("avail fee overflow", avail(c(0, 0), c(2, 1), cost = overflow()))
show("avail fee overflow sell", avail(c(5, 0), c(0, 1), cost = overflow()))

cat("== public\n")
pulses <- as.POSIXct("2024-01-01 16:00:00", tz = "UTC") + 86400 * 0:3
bars <- do.call(rbind, lapply(c("AAA", "BBB"), function(id) data.frame(ts_utc = pulses, instrument_id = id,
  open = 10, high = 11, low = 9, close = 10.5, volume = 1000, stringsAsFactors = FALSE)))
sessions <- ledgr_facts_sessions(data.frame(session_date = as.Date(pulses), status = "open", session_open = "09:30:00",
  session_close = "16:00:00", knowledge_time = pulses - 86400, stringsAsFactors = FALSE), venue_id = "XNYS")
snaps <- list(
  dense = ledgr_snapshot_from_df(bars, db_path = tempfile(fileext = ".duckdb")),
  avail = ledgr_snapshot_from_df(bars, instruments_df = data.frame(instrument_id = c("AAA", "BBB")),
    facts = ledgr_facts(sessions), price_basis = "split_adjusted", db_path = tempfile(fileext = ".duckdb"))
)
public <- function(kind, strategy, cost, opening = ledgr_opening(cash = 1000), rid) {
  exp <- ledgr_experiment(snaps[[kind]], strategy, cost_model = cost, opening = opening)
  out <- tryCatch({
    bt <- ledgr_run(exp, run_id = rid, seed = 1L)
    on.exit(close(bt))
    d <- tryCatch(as.data.frame(ledgr_results(bt, "diagnostics")), error = function(e) NULL)
    paste("DONE; fills", nrow(ledgr_results(bt, "fills")),
      if (!is.null(d) && nrow(d)) paste("| no_fill:", paste(d$reasons[d$outcome == "no_fill"], collapse = ",")) else "")
  }, error = identity)
  if (inherits(out, "error")) {
    con <- DBI::dbConnect(duckdb::duckdb(), snaps[[kind]]$db_path, read_only = TRUE)
    on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
    stage <- tryCatch(DBI::dbGetQuery(con, "SELECT stage, reason_code FROM run_diagnostics WHERE run_id = ? AND outcome = 'error'",
      params = list(rid)), error = function(e) data.frame())
    stop(structure(class = class(out), list(message = paste0(conditionMessage(out),
      if (nrow(stage)) paste0(" [stage ", stage$stage[[1L]], "]") else ""), call = NULL)))
  }
  out
}
buy2 <- function(ctx, params) { t <- ctx$hold(); if (substr(ctx$ts_utc, 1, 10) == "2024-01-01") t[["AAA"]] <- 2; t }
cost_over <- ledgr_cost_chain(ledgr_cost_fixed_fee(1e308), ledgr_cost_notional_bps_fee(1e308))
for (k in c("dense", "avail")) show(paste("public fee overflow", k), public(k, buy2, cost_over, rid = paste0("ovf-", k)))
flip <- function(ctx, params) { t <- ctx$hold(); if (substr(ctx$ts_utc, 1, 10) == "2024-01-01") t[["AAA"]] <- params$to; t }
show("public delta overflow dense", public("dense", function(ctx, params) { t <- ctx$hold()
  if (substr(ctx$ts_utc, 1, 10) == "2024-01-01") t[["AAA"]] <- -1e308; t },
  ledgr_cost_zero(), ledgr_opening(cash = 1000, positions = c(AAA = 1e308), cost_basis = c(AAA = 1)), rid = "dov-dense"))
show("public delta overflow avail", public("avail", function(ctx, params) { t <- ctx$hold()
  if (substr(ctx$ts_utc, 1, 10) == "2024-01-01") t[["AAA"]] <- 1e308; t },
  ledgr_cost_zero(), ledgr_opening(cash = 1000, positions = c(AAA = -1e308), cost_basis = c(AAA = 1)), rid = "dov-avail"))
for (s in snaps) ledgr_snapshot_close(s)
