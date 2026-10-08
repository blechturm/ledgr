# Cut 10 real-data continuity runner (LDG-2972).
#
# Usage, from any directory:
#   Rscript dev/bench/v0_2_2_real_data_continuity/run_record.R <repo> <out_dir> [--allow-dirty]
#
# Records public-path observations for three vendor-neutral fixtures derived
# from the ledgr-research EXP-0003 reproducer: an unpriced member under the
# canonical rebalance pipeline (LFB-017), a walk-forward fold without a
# selectable candidate (LFB-023) and a run that exits early (LFB-018), plus
# the invariance arms. check_record.R states the expectations. Every arm
# records `error` instead of stopping, so a pre-cut tree produces a record too.

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2L) {
  stop("usage: run_record.R <repo> <out_dir> [--allow-dirty]", call. = FALSE)
}
repo <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
out_dir <- args[[2L]]
allow_dirty <- "--allow-dirty" %in% args

git <- function(...) {
  out <- suppressWarnings(system2("git", c("-C", shQuote(repo), ...), stdout = TRUE, stderr = TRUE))
  paste(out, collapse = "\n")
}
tracked_status <- git("status", "--porcelain", "--untracked-files=no")
if (nzchar(tracked_status) && !allow_dirty) {
  stop("Refusing to record from a dirty tracked tree:\n", tracked_status, call. = FALSE)
}

suppressMessages(pkgload::load_all(repo, quiet = TRUE))
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

rows <- list()
record <- function(arm, observable, value) {
  value <- if (length(value) == 0L) "" else paste(as.character(value), collapse = ",")
  rows[[length(rows) + 1L]] <<- data.frame(arm = arm, observable = observable, value = value,
                                           stringsAsFactors = FALSE)
}
attempt <- function(arm, expr) {
  out <- tryCatch(expr, error = function(e) e, interrupt = function(e) e)
  if (inherits(out, "condition")) {
    record(arm, "condition_class", paste(class(out), collapse = "|"))
    record(arm, "condition_message", gsub("\\s+", " ", conditionMessage(out)))
    return(NULL)
  }
  record(arm, "condition_class", "")
  out
}
utc <- function(x) as.POSIXct(paste(x, "21:00:00"), tz = "UTC")
iso <- function(x) format(as.POSIXct(x, tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")

# Five weekday sessions, 2020-01-06 to 2020-01-10, and a two-member universe.
# Open equals close on every bar, so fills happen at the decision close.
availability_snapshot <- function(bars, days, instruments) {
  membership <- data.frame(effective_from = utc(days[[1]] - 1), knowledge_time = utc(days[[1]] - 1), source = "d")
  membership$members <- I(list(instruments))
  facts <- ledgr_facts(
    ledgr_facts_sessions(
      data.frame(session_date = days, status = "open", session_open = "14:30:00", session_close = "21:00:00"),
      venue_id = "V", timezone = "UTC", knowledge = "assume_effective"),
    ledgr_facts_membership_snapshots(membership, universe_id = "u", complete = TRUE, knowledge = "assume_effective")
  )
  ledgr_snapshot_from_df(bars, data.frame(instrument_id = instruments),
                         db_path = tempfile(fileext = ".duckdb"), facts = facts)
}
bar_rows <- function(id, days, close) {
  data.frame(instrument_id = id, ts_utc = utc(days), open = close, high = close, low = close,
             close = close, volume = 100)
}
gap_days <- as.Date(c("2020-01-06", "2020-01-07", "2020-01-08", "2020-01-09", "2020-01-10"))
record_run <- function(arm, bt, snapshot) {
  info <- ledgr_run_info(snapshot, bt$run_id)
  record(arm, "status", info$status)
  equity <- ledgr_results(bt, "equity")
  record(arm, "equity", format(round(equity$equity, 6), nsmall = 0, trim = TRUE))
  fills <- ledgr_results(bt, "fills")
  record(arm, "fills", sprintf("%s:%s:%s:%s", substr(iso(fills$ts_utc), 1, 10), fills$instrument_id,
                               fills$side, format(fills$qty, trim = TRUE)))
  diag <- ledgr_results(bt, "diagnostics")
  decision <- diag[diag$stage == "decision", , drop = FALSE]
  record(arm, "decision_rows", sprintf("%s:%s:%s:%s", substr(iso(decision$ts_utc), 1, 10), decision$instrument_id,
                                       decision$reason_code, format(decision$target, trim = TRUE)))
}

# ---- LFB-017: unpriced members under the canonical rebalance pipeline -------
# BBB has no bar on day 1 (unheld skip) and on day 4 (held skip).
bars17 <- rbind(bar_rows("AAA", gap_days, 10), bar_rows("BBB", gap_days[-c(1, 4)], 20))
s17 <- availability_snapshot(bars17, gap_days, c("AAA", "BBB"))
exp17 <- function(strategy) {
  ledgr_experiment(s17, strategy, universe = ledgr_universe_members("u"),
                   valuation_policy = ledgr_valuation_stale(2), cost_model = ledgr_cost_zero(),
                   opening = ledgr_opening(cash = 1000))
}
equal_weight <- function(ctx, params) {
  ctx |> ledgr_selection() |> ledgr_weight_equal() |> ledgr_target_rebalance(ctx, equity_fraction = 0.9)
}
bt <- attempt("lfb017_default", ledgr_run(exp17(equal_weight), run_id = "lfb017-default"))
if (!is.null(bt)) record_run("lfb017_default", bt, s17)
# The same pipeline, but the strategy flattens the ledgr_target to a plain
# vector the two ways common strategy code does.
equal_weight_c <- function(ctx, params) {
  c(ctx |> ledgr_selection() |> ledgr_weight_equal() |> ledgr_target_rebalance(ctx, equity_fraction = 0.9))
}
equal_weight_sub <- function(ctx, params) {
  target <- ctx |> ledgr_selection() |> ledgr_weight_equal() |> ledgr_target_rebalance(ctx, equity_fraction = 0.9)
  target[ctx$universe]
}
bt <- attempt("lfb017_concat", ledgr_run(exp17(equal_weight_c), run_id = "lfb017-concat"))
if (!is.null(bt)) record_run("lfb017_concat", bt, s17)
bt <- attempt("lfb017_subset", ledgr_run(exp17(equal_weight_sub), run_id = "lfb017-subset"))
if (!is.null(bt)) record_run("lfb017_subset", bt, s17)
# Cap: buy 10 AAA and 45 BBB on day 2; on day 4 (BBB unpriced, held 45 at
# mark 20 = 900) ask for 0.5/0.5 at full equity. Uncapped, AAA would be 50.
cap_weights <- function(ctx, params) {
  day <- substr(ctx$ts_utc, 1, 10)
  w <- if (day %in% c("2020-01-07", "2020-01-08")) c(AAA = 0.1, BBB = 0.9) else c(AAA = 0.5, BBB = 0.5)
  if (identical(day, "2020-01-06")) return(ctx$flat())
  close <- stats::setNames(as.numeric(ctx$vec$close), ctx$universe)
  priced <- names(w)[is.finite(close[names(w)]) & close[names(w)] > 0]
  if (identical(day, "2020-01-09")) priced <- names(w)
  ledgr_weights(w[priced], universe = ctx$universe) |> ledgr_target_rebalance(ctx, equity_fraction = 1)
}
bt <- attempt("lfb017_cap", ledgr_run(exp17(cap_weights), run_id = "lfb017-cap"))
if (!is.null(bt)) record_run("lfb017_cap", bt, s17)
# Invariance: the close-filter pipeline and a gap-free run.
equal_weight_where <- function(ctx, params) {
  ctx |> ledgr_selection(where = is.finite(ctx$vec$close) & ctx$vec$close > 0) |>
    ledgr_weight_equal() |> ledgr_target_rebalance(ctx, equity_fraction = 0.9)
}
bt <- attempt("inv_where", ledgr_run(exp17(equal_weight_where), run_id = "inv-where"))
if (!is.null(bt)) record_run("inv_where", bt, s17)
ledgr_snapshot_close(s17)

bars_full <- rbind(bar_rows("AAA", gap_days, 10), bar_rows("BBB", gap_days, 20))
s_full <- availability_snapshot(bars_full, gap_days, c("AAA", "BBB"))
bt <- attempt("inv_nogap", ledgr_run(
  ledgr_experiment(s_full, equal_weight, universe = ledgr_universe_members("u"),
                   valuation_policy = ledgr_valuation_stale(2), cost_model = ledgr_cost_zero(),
                   opening = ledgr_opening(cash = 1000)),
  run_id = "inv-nogap"))
if (!is.null(bt)) record_run("inv_nogap", bt, s_full)
ledgr_snapshot_close(s_full)

# Dense warn-and-zero and raw numeric targets stay as they are.
dense_bars <- data.frame(instrument_id = rep(c("AAA", "BBB"), each = 3),
                         ts_utc = rep(as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:2, 2),
                         open = c(10, 10, 10, 20, NA, 20), high = c(10, 10, 10, 20, NA, 20),
                         low = c(10, 10, 10, 20, NA, 20), close = c(10, 10, 10, 20, NA, 20), volume = 100)
dense_bars <- dense_bars[!is.na(dense_bars$close), , drop = FALSE]
dense_ctx <- list(universe = c("AAA", "BBB"), equity = 1000, vec = list(close = c(AAA = 10, BBB = NA)))
dense_warning <- NULL
dense_target <- withCallingHandlers(
  ledgr_target_rebalance(ledgr_weights(c(AAA = 0.5, BBB = 0.5), universe = c("AAA", "BBB")), dense_ctx),
  ledgr_invalid_target_price = function(w) { dense_warning <<- class(w)[[1L]]; invokeRestart("muffleWarning") }
)
record("inv_dense", "target", paste(names(dense_target), unclass(dense_target), sep = "=", collapse = ","))
record("inv_dense", "warning", dense_warning %||% "")

# ---- LFB-023: a fold without a selectable candidate --------------------------
all_days <- seq(as.Date("2020-01-01"), as.Date("2020-12-31"), by = "day")
weekday <- as.integer(format(all_days, "%u")) <= 5L
wf_days <- all_days[weekday]
set.seed(1)
wf_close <- function(n) round(10 * exp(cumsum(rnorm(n, 0, 0.01))), 4)
wf_bars <- rbind(bar_rows("AAA", wf_days, wf_close(length(wf_days))),
                 bar_rows("BBB", wf_days, wf_close(length(wf_days))))
wf_membership <- data.frame(effective_from = utc(wf_days[[1]]), knowledge_time = utc(wf_days[[1]]), source = "d")
wf_membership$members <- I(list(c("AAA", "BBB")))
wf_facts <- ledgr_facts(
  ledgr_facts_sessions(
    data.frame(session_date = all_days, status = ifelse(weekday, "open", "closed"),
               session_open = ifelse(weekday, "14:30:00", NA), session_close = ifelse(weekday, "21:00:00", NA)),
    venue_id = "V", timezone = "UTC", knowledge = "assume_effective"),
  ledgr_facts_membership_snapshots(wf_membership, universe_id = "u", complete = TRUE, knowledge = "assume_effective")
)
s23 <- ledgr_snapshot_from_df(wf_bars, data.frame(instrument_id = c("AAA", "BBB")),
                              db_path = tempfile(fileext = ".duckdb"), facts = wf_facts)
wf_exp <- function(strategy) {
  ledgr_experiment(s23, strategy, universe = ledgr_universe_members("u"),
                   valuation_policy = ledgr_valuation_stale(2), cost_model = ledgr_cost_zero(),
                   opening = ledgr_opening(cash = 1000))
}
# Candidates trade until the end of May, then hold cash: training windows that
# lie entirely after May have constant equity and no finite Sharpe ratio.
trade_until_may <- function(ctx, params) {
  if (substr(ctx$ts_utc, 1, 10) > "2020-05-31") return(ctx$flat())
  ctx |> ledgr_selection() |> ledgr_weight_equal() |> ledgr_target_rebalance(ctx, equity_fraction = params$f)
}
all_cash <- function(ctx, params) ctx$flat()
trade_always <- function(ctx, params) {
  ctx |> ledgr_selection() |> ledgr_weight_equal() |> ledgr_target_rebalance(ctx, equity_fraction = params$f)
}
wf_grid <- ledgr_strategy_grid(f = c(0.5, 0.9))
wf_folds <- ledgr_folds_rolling("2020-01-02", "2020-12-31", train_window = "2 months",
                                test_window = "1 month", step = "1 month")
record_session <- function(arm, wf) {
  record(arm, "session_status", wf$status %||% "")
  folds <- ledgr_walk_forward_folds(s23, wf$session_id)
  source <- if ("selection_source" %in% names(folds)) folds$selection_source else rep("<absent>", nrow(folds))
  record(arm, "folds", sprintf("%d:%s:%s:%s:%s", folds$fold_seq, substr(iso(folds$train_start_utc), 1, 10),
                               folds$status, ifelse(is.na(source), "NULL", source),
                               ifelse(is.na(folds$test_run_id), "no_test", "test")))
  record(arm, "session_id", wf$session_id)
  invisible(folds)
}
run_wf <- function(arm, strategy, ...) {
  wf <- attempt(arm, ledgr_walk_forward(wf_exp(strategy), wf_grid, wf_folds,
                                        ledgr_rule_argmax("sharpe_ratio"), seed = 1L, ...))
  if (!is.null(wf)) record_session(arm, wf)
  wf
}
wf_prev <- run_wf("lfb023_later_empty", trade_until_may)
wf_none <- run_wf("lfb023_never", all_cash)
known_sessions <- c(wf_prev$session_id, wf_none$session_id)
wf_fail <- run_wf("lfb023_fail", all_cash, no_selection = "fail")
# The refusal propagates, so read the persisted fold rows of the new session.
stored <- DBI::dbGetQuery(ledgr:::get_connection(s23), "SELECT * FROM walk_forward_folds ORDER BY session_id, fold_seq")
stored <- stored[!stored$session_id %in% known_sessions, , drop = FALSE]
record("lfb023_fail", "stored_folds", sprintf("%d:%s:%s", stored$fold_seq, stored$status,
       if ("selection_source" %in% names(stored)) ifelse(is.na(stored$selection_source), "NULL", stored$selection_source)
       else "<absent>"))
wf_all <- run_wf("inv_wf_all_select", trade_always)
wf_all_fail <- run_wf("lfb023_all_select_fail", trade_always, no_selection = "fail")
if (!is.null(wf_all) && !is.null(wf_all_fail)) {
  record("lfb023_all_select_fail", "same_test_equity_as_previous",
         identical(lapply(wf_all$test_runs %||% list(), function(r) ledgr_results(r, "equity")$equity),
                   lapply(wf_all_fail$test_runs %||% list(), function(r) ledgr_results(r, "equity")$equity)))
}
if (!is.null(wf_prev)) {
  folds <- ledgr_walk_forward_folds(s23, wf_prev$session_id)
  prev_seq <- folds$fold_seq[!is.na(folds$selection_source %||% NA) & folds$selection_source %in% "previous"]
  if (length(prev_seq)) {
    cand <- attempt("lfb023_candidate_previous", ledgr_candidate(wf_prev, prev_seq[[1]]))
    if (!is.null(cand)) record("lfb023_candidate_previous", "provenance_source",
                               cand$provenance$walk_forward$selection_source %||% "")
  }
}
if (!is.null(wf_none)) {
  attempt("lfb023_candidate_none", ledgr_candidate(wf_none, 1L))
  record("lfb023_never", "print", paste(utils::capture.output(print(wf_none)), collapse = " | "))
}
ledgr_snapshot_close(s23)

# ---- LFB-018: runs that exit early ------------------------------------------
# Moving prices, so equity comparisons between arms have power.
bars18 <- rbind(bar_rows("AAA", gap_days, c(10, 11, 12, 13, 14)), bar_rows("BBB", gap_days, c(20, 22, 21, 23, 24)))
s18 <- availability_snapshot(bars18, gap_days, c("AAA", "BBB"))
slow_feature <- ledgr_indicator(id = "slow_close", requires_bars = 1L, gap_contract = "strict_window",
                                fn = function(window) { Sys.sleep(0.4); window$close[[nrow(window)]] })
# One definition, so a rerun resumes the same row; the option picks the exit.
interrupt_feature <- ledgr_indicator(id = "interrupt_close", requires_bars = 1L, gap_contract = "strict_window",
                                     fn = function(window) {
                                       if (identical(getOption("ledgr.oracle.exit"), "error")) stop("second attempt failed")
                                       rlang::interrupt()
                                     })
exp18 <- function(features, strategy = function(ctx, params) ctx$hold(), snapshot = s18, availability = TRUE) {
  if (availability) {
    ledgr_experiment(snapshot, strategy, features = features, universe = ledgr_universe_members("u"),
                     valuation_policy = ledgr_valuation_stale(2), cost_model = ledgr_cost_zero(),
                     opening = ledgr_opening(cash = 1000))
  } else {
    ledgr_experiment(snapshot, strategy, features = features, opening = ledgr_opening(cash = 1000),
                     cost_model = ledgr_cost_zero())
  }
}
record_status <- function(arm, run_id, snapshot = s18) {
  st <- tryCatch(DBI::dbGetQuery(ledgr:::get_connection(snapshot),
                                 "SELECT status, error_msg FROM runs WHERE run_id = ?", params = list(run_id)),
                 error = function(e) data.frame(status = "<unreadable>", error_msg = conditionMessage(e)))
  record(arm, "status", st$status)
  record(arm, "error_msg_nonempty", !is.na(st$error_msg) & nzchar(st$error_msg))
  record(arm, "error_msg", st$error_msg)
}
attempt("lfb018_timelimit", {
  setTimeLimit(elapsed = 1, transient = TRUE)
  on.exit(setTimeLimit(elapsed = Inf), add = TRUE)
  ledgr_run(exp18(list(slow_feature)), run_id = "lfb018-timelimit")
})
setTimeLimit(elapsed = Inf)
record_status("lfb018_timelimit", "lfb018-timelimit")
attempt("lfb018_interrupt", ledgr_run(exp18(list(interrupt_feature)), run_id = "lfb018-interrupt"))
record_status("lfb018_interrupt", "lfb018-interrupt")
# The FAILED row resumes and exits differently; its message must be the new one.
old <- options(ledgr.oracle.exit = "error")
attempt("lfb018_resumed", ledgr_run(exp18(list(interrupt_feature)), run_id = "lfb018-interrupt"))
options(old)
record_status("lfb018_resumed", "lfb018-interrupt")

# An interrupt inside the pulse loop, dense and availability-aware: the row is
# FAILED, the caller sees the interrupt, and rerunning resumes to the
# uninterrupted result.
rebalance_mid <- function(ctx, params) {
  if (identical(getOption("ledgr.oracle.midloop"), substr(ctx$ts_utc, 1, 10))) rlang::interrupt()
  ctx |> ledgr_selection() |> ledgr_weight_equal() |> ledgr_target_rebalance(ctx, equity_fraction = 0.9)
}
s18_dense <- ledgr_snapshot_from_df(bars18, db_path = tempfile(fileext = ".duckdb"))
for (mode in c("dense", "availability")) {
  snap <- if (identical(mode, "dense")) s18_dense else s18
  make <- function() exp18(list(), rebalance_mid, snapshot = snap, availability = identical(mode, "availability"))
  arm <- paste0("lfb018_midloop_", mode)
  ref <- attempt(paste0(arm, "_reference"), ledgr_run(make(), run_id = paste0("midloop-ref-", mode)))
  if (!is.null(ref)) record_run(paste0(arm, "_reference"), ref, snap)
  old <- options(ledgr.oracle.midloop = "2020-01-08")
  attempt(arm, ledgr_run(make(), run_id = paste0("midloop-", mode)))
  options(old)
  record_status(arm, paste0("midloop-", mode), snap)
  resumed <- attempt(paste0(arm, "_resume"), ledgr_run(make(), run_id = paste0("midloop-", mode)))
  if (!is.null(resumed)) record_run(paste0(arm, "_resume"), resumed, snap)
}
ledgr_snapshot_close(s18_dense)

# Invariance: the soft stop keeps RUNNING, and resume reaches the
# uninterrupted result.
buy_once <- function(ctx, params) {
  ctx |> ledgr_selection() |> ledgr_weight_equal() |> ledgr_target_rebalance(ctx, equity_fraction = 0.9)
}
bt <- attempt("inv_uninterrupted", ledgr_run(exp18(list(), buy_once), run_id = "inv-uninterrupted"))
if (!is.null(bt)) record_run("inv_uninterrupted", bt, s18)
old <- options(ledgr.interrupt = TRUE)
bt <- attempt("inv_soft_stop", ledgr_run(exp18(list(), buy_once), run_id = "inv-soft-stop"))
options(old)
record_status("inv_soft_stop", "inv-soft-stop")
bt <- attempt("inv_soft_stop_resume", ledgr_run(exp18(list(), buy_once), run_id = "inv-soft-stop"))
if (!is.null(bt)) record_run("inv_soft_stop_resume", bt, s18)
ledgr_snapshot_close(s18)

# ==== Cut 11 groups (LDG-2977) ================================================
eq_text <- function(eq, cols = c("cash", "positions_value", "equity", "realized_pnl", "unrealized_pnl")) {
  apply(vapply(cols, function(c) format(as.numeric(eq[[c]]), digits = 15, trim = TRUE), character(nrow(eq))),
        1L, paste, collapse = "/")
}

# ---- LFB-019: reconstruction of gap-bearing availability runs ----------------
# Gap: BBB has no bar on day 1 (unheld skip) and day 4 (held skip, stale mark).
# Freeze: BBB's last bar is day 2; with stale(1) its holding is frozen at 22
# from day 4.
bars19g <- rbind(bar_rows("AAA", gap_days, 10), bar_rows("BBB", gap_days[-c(1, 4)], c(20, 21, 23)))
bars19f <- rbind(bar_rows("AAA", gap_days, c(10, 11, 12, 13, 14)), bar_rows("BBB", gap_days[1:2], c(20, 22)))
for (case in list(list(arm = "lfb019_gap", bars = bars19g, stale = 2L),
                  list(arm = "lfb019_freeze", bars = bars19f, stale = 1L))) {
  s19 <- availability_snapshot(case$bars, gap_days, c("AAA", "BBB"))
  bt <- attempt(paste0(case$arm, "_run"), ledgr_run(
    ledgr_experiment(s19, equal_weight, universe = ledgr_universe_members("u"),
                     valuation_policy = ledgr_valuation_stale(case$stale), cost_model = ledgr_cost_zero(),
                     opening = ledgr_opening(cash = 1000)),
    run_id = case$arm))
  if (!is.null(bt)) {
    con19 <- ledgr:::get_connection(s19)
    stored <- DBI::dbGetQuery(con19, "SELECT * FROM equity_curve WHERE run_id = ? ORDER BY ts_utc", params = list(bt$run_id))
    record(case$arm, "status", ledgr_run_info(s19, bt$run_id)$status)
    record(case$arm, "stored_equity", eq_text(stored))
    decision <- ledgr_results(bt, "diagnostics")
    record(case$arm, "skips", sum(decision$reason_code == "sizing_unavailable"))
    record(case$arm, "frozen", sum(decision$reason_code == "valuation_frozen"))
    rebuilt <- attempt(case$arm, ledgr_state_reconstruct(bt$run_id, con19))
    if (!is.null(rebuilt)) {
      record(case$arm, "rebuilt_equity", eq_text(rebuilt$equity_curve))
      record(case$arm, "rebuilt_positions", paste(rebuilt$positions$instrument_id, rebuilt$positions$qty, sep = ":"))
    }
    close(bt)
  }
  ledgr_snapshot_close(s19)
}

# Shared 2020 weekday walk-forward fixture: AAA, BBB and, optionally, CCC.
wf_snapshot <- function(ids, lifetime = NULL) {
  set.seed(2)
  bars <- do.call(rbind, lapply(ids, function(id) bar_rows(id, wf_days, wf_close(length(wf_days)))))
  if (!is.null(lifetime)) bars <- bars[!(bars$instrument_id == lifetime$id & bars$ts_utc >= utc(lifetime$day)), , drop = FALSE]
  m <- data.frame(effective_from = utc(wf_days[[1]]), knowledge_time = utc(wf_days[[1]]), source = "d")
  m$members <- I(list(ids))
  families <- list(
    ledgr_facts_sessions(
      data.frame(session_date = all_days, status = ifelse(weekday, "open", "closed"),
                 session_open = ifelse(weekday, "14:30:00", NA), session_close = ifelse(weekday, "21:00:00", NA)),
      venue_id = "V", timezone = "UTC", knowledge = "assume_effective"),
    ledgr_facts_membership_snapshots(m, universe_id = "u", complete = TRUE, knowledge = "assume_effective"))
  if (!is.null(lifetime)) {
    families <- c(families, list(ledgr_facts_lifetime(data.frame(
      instrument_id = lifetime$id, effective_from = utc(lifetime$day), knowledge_time = utc(lifetime$day) - 1,
      assertion = "known_inactive", terminal_event = "bankruptcy", stringsAsFactors = FALSE))))
  }
  ledgr_snapshot_from_df(bars, data.frame(instrument_id = ids), db_path = tempfile(fileext = ".duckdb"),
                         facts = do.call(ledgr_facts, families))
}
wf_exp_on <- function(snapshot, strategy) {
  ledgr_experiment(snapshot, strategy, universe = ledgr_universe_members("u"),
                   valuation_policy = ledgr_valuation_stale(2), cost_model = ledgr_cost_zero(),
                   opening = ledgr_opening(cash = 1000))
}
store_counts <- function(snapshot) {
  con <- ledgr:::get_connection(snapshot)
  n <- function(table) tryCatch(DBI::dbGetQuery(con, paste("SELECT COUNT(*) n FROM", table))$n, error = function(e) 0)
  sprintf("sessions=%d,runs=%d", n("walk_forward_sessions"), n("runs"))
}

# ---- Gapped carry (LDG-2979) ---------------------------------------------------
# Step 2 months, test 1 month: test windows March, May, July, ... leave April,
# June, ... unobserved. CCC delists on 2020-04-15, inside the first gap.
s_gap <- wf_snapshot(c("AAA", "BBB", "CCC"), lifetime = list(id = "CCC", day = as.Date("2020-04-15")))
gap_folds <- ledgr_folds_rolling("2020-01-02", "2020-12-31", train_window = "2 months",
                                 test_window = "1 month", step = "2 months")
before <- store_counts(s_gap)
wf <- attempt("wfgap_carry", ledgr_walk_forward(wf_exp_on(s_gap, trade_always), wf_grid, gap_folds,
                                                ledgr_rule_argmax("sharpe_ratio"), seed = 1L))
record("wfgap_carry", "store_before", before)
record("wfgap_carry", "store_after", store_counts(s_gap))
if (!is.null(wf)) {
  folds <- ledgr_walk_forward_folds(s_gap, wf$session_id)
  record("wfgap_carry", "session_status", wf$status)
  test_status <- vapply(folds$test_run_id[!is.na(folds$test_run_id)],
                        function(id) ledgr_run_info(s_gap, id)$status, character(1))
  record("wfgap_carry", "test_status", test_status)
}
wf <- attempt("inv_wfgap_flat", suppressWarnings(ledgr_walk_forward(
  wf_exp_on(s_gap, trade_always), wf_grid, gap_folds, ledgr_rule_argmax("sharpe_ratio"), seed = 1L,
  opening_state_policy = "flat_test_state")))
if (!is.null(wf)) record("inv_wfgap_flat", "session_status", wf$status)
ledgr_snapshot_close(s_gap)

# ---- Walk-forward resume (LDG-2980) ------------------------------------------
# The strategy interrupts on 2020-05-12, inside fold 3's test window (May),
# when the option is set. A reference session runs uninterrupted on its own
# copy of the same data.
interrupt_may <- function(ctx, params) {
  if (identical(getOption("ledgr.oracle.wf_interrupt"), substr(ctx$ts_utc, 1, 10))) rlang::interrupt()
  ctx |> ledgr_selection() |> ledgr_weight_equal() |> ledgr_target_rebalance(ctx, equity_fraction = params$f)
}
session_digest <- function(snapshot, wf) {
  folds <- ledgr_walk_forward_folds(snapshot, wf$session_id)
  equity <- vapply(folds$test_run_id, function(id) {
    if (is.na(id)) return("none")
    run <- ledgr_run_open(snapshot, id)
    on.exit(close(run), add = TRUE)
    paste(format(ledgr_results(run, "equity")$equity, digits = 15), collapse = "/")
  }, character(1))
  sprintf("%d:%s:%s:%s:%s", folds$fold_seq, folds$status, folds$selection_source,
          substr(folds$selected_candidate_key, 1, 12), equity)
}
telemetry_stamp <- function(snapshot, ids) {
  con <- ledgr:::get_connection(snapshot)
  if (!"run_telemetry" %in% DBI::dbListTables(con)) return("no_telemetry_table")
  rows <- DBI::dbGetQuery(con, "SELECT run_id, updated_at_utc FROM run_telemetry ORDER BY run_id")
  rows <- rows[rows$run_id %in% ids, , drop = FALSE]
  paste(rows$run_id, format(rows$updated_at_utc, "%Y-%m-%dT%H:%M:%OS6"), sep = "@")
}
s_ref <- wf_snapshot(c("AAA", "BBB"))
ref <- attempt("wfresume_reference", ledgr_walk_forward(wf_exp_on(s_ref, interrupt_may), wf_grid, wf_folds,
                                                         ledgr_rule_argmax("sharpe_ratio"), seed = 1L))
if (!is.null(ref)) {
  record("wfresume_reference", "session_status", ref$status)
  record("wfresume_reference", "digest", session_digest(s_ref, ref))
  # Rerunning a finished session opens its DONE test runs without executing them.
  test_ids <- ledgr_walk_forward_folds(s_ref, ref$session_id)$test_run_id
  stamp <- telemetry_stamp(s_ref, test_ids)
  again <- attempt("inv_wfresume_reopen", ledgr_walk_forward(wf_exp_on(s_ref, interrupt_may), wf_grid, wf_folds,
                                                              ledgr_rule_argmax("sharpe_ratio"), seed = 1L))
  record("inv_wfresume_reopen", "stamp_before", stamp)
  record("inv_wfresume_reopen", "stamp_after", telemetry_stamp(s_ref, test_ids))
  if (!is.null(again)) record("inv_wfresume_reopen", "digest_matches", identical(session_digest(s_ref, again), session_digest(s_ref, ref)))
}
ledgr_snapshot_close(s_ref)
s_int <- wf_snapshot(c("AAA", "BBB"))
old <- options(ledgr.oracle.wf_interrupt = "2020-05-12")
attempt("wfresume_interrupted", ledgr_walk_forward(wf_exp_on(s_int, interrupt_may), wf_grid, wf_folds,
                                                    ledgr_rule_argmax("sharpe_ratio"), seed = 1L))
options(old)
stored <- DBI::dbGetQuery(ledgr:::get_connection(s_int), "SELECT meta_json FROM walk_forward_sessions")
record("wfresume_interrupted", "stored_session_status",
       vapply(stored$meta_json, function(j) as.character(jsonlite::fromJSON(j)$status %||% ""), character(1)))
resumed <- attempt("wfresume_rerun", ledgr_walk_forward(wf_exp_on(s_int, interrupt_may), wf_grid, wf_folds,
                                                         ledgr_rule_argmax("sharpe_ratio"), seed = 1L))
if (!is.null(resumed)) {
  record("wfresume_rerun", "session_status", resumed$status)
  record("wfresume_rerun", "digest", session_digest(s_int, resumed))
}
ledgr_snapshot_close(s_int)

# ---- Fold boundaries on the sealed first and last dates (LDG-2991) ------------
# The 2020 weekday fixture starts on Wednesday 2020-01-01; its bars are stamped
# 21:00 UTC, fold boundaries at midnight UTC.
s_b <- wf_snapshot(c("AAA", "BBB"))
bounds <- function(start, end) ledgr_folds_rolling(start, end, train_window = "2 months",
                                                   test_window = "1 month", step = "1 month")
for (case in list(list(arm = "bounds_first_date", start = "2020-01-01", end = "2020-12-31"),
                  list(arm = "bounds_before_first", start = "2019-12-02", end = "2020-12-31"),
                  list(arm = "bounds_after_last", start = "2020-01-02", end = "2021-01-04"),
                  list(arm = "inv_bounds_inside", start = "2020-01-02", end = "2020-12-31"))) {
  folds <- bounds(case$start, case$end)
  record(case$arm, "fold_list_hash", attr(folds, "fold_list_hash"))
  wf <- attempt(case$arm, ledgr_walk_forward(wf_exp_on(s_b, trade_always), wf_grid, folds,
                                             ledgr_rule_argmax("sharpe_ratio"), seed = 1L))
  if (!is.null(wf)) {
    record(case$arm, "session_status", wf$status)
    record(case$arm, "digest", session_digest(s_b, wf))
  }
}
ledgr_snapshot_close(s_b)

record("meta", "commit", git("rev-parse", "HEAD"))
record("meta", "tracked_clean", !nzchar(tracked_status))
record("meta", "R", R.version.string)
record("meta", "command", paste("Rscript dev/bench/v0_2_2_real_data_continuity/run_record.R", paste(args, collapse = " ")))
out <- do.call(rbind, rows)
utils::write.csv(out, file.path(out_dir, "record.csv"), row.names = FALSE)
cat(sprintf("wrote %d observations to %s\n", nrow(out), file.path(out_dir, "record.csv")))
