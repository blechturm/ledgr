# Rscript dev/spikes/terminal-outcomes/probe.R IMPLEMENTATION_REPO OUTPUT_DIR
#
# Stage-1 probe for the terminal-outcome RFC: what does ledgr do today when a
# held instrument becomes untradable, and how do run, comparison, sweep and
# walk-forward surfaces treat the resulting run? Public API only, on sealed
# snapshots. Records observations; asserts nothing. Binds no design.
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) >= 2L)
repo <- normalizePath(args[[1L]], mustWork = TRUE)
out <- args[[2L]]
dir.create(out, recursive = TRUE, showWarnings = FALSE)
suppressMessages(pkgload::load_all(repo, quiet = TRUE, compile = FALSE))

rows <- list()
record <- function(case, observation, value) {
  text <- if (is.character(value) && length(value) == 1L) value else
    paste(utils::capture.output(dput(value)), collapse = " ")
  rows[[length(rows) + 1L]] <<- data.frame(case = case, observation = observation,
    value = gsub("\\s+", " ", text), stringsAsFactors = FALSE)
  invisible(NULL)
}
attempt <- function(case, observation, expr) {
  tryCatch(expr, error = function(e) {
    record(case, observation, paste0("<error ", class(e)[[1L]], "> ",
      conditionMessage(e)))
    NULL
  })
}

# Fixture: AAA rises 100 -> 130 over three sessions, then becomes untradable;
# BBB drifts 100 -> 109 over ten sessions and is never affected.
days <- 10L
dates <- as.Date("2020-01-01") + seq_len(days) - 1L
pulses <- as.POSIXct(paste(dates, "16:00:00"), tz = "UTC")
openings <- as.POSIXct(paste(dates, "09:30:00"), tz = "UTC")
aaa_close <- c(100, 115, 130, 131, 132, 133, 134, 135, 136, 137)
bbb_close <- 100 + 0:9
bar_rows <- function(id, close, keep) data.frame(ts_utc = pulses[keep],
  instrument_id = id, open = close[keep], high = close[keep], low = close[keep],
  close = close[keep], volume = 1000, stringsAsFactors = FALSE)
sessions <- ledgr_facts_sessions(data.frame(session_date = dates, status = "open",
  session_open = "09:30:00", session_close = "16:00:00",
  knowledge_time = as.POSIXct(dates, tz = "UTC") - 1), venue_id = "XNYS")
snapshot_for <- function(aaa_keep, extra = list(), price_basis = NULL) {
  bars <- rbind(bar_rows("AAA", aaa_close, aaa_keep),
    bar_rows("BBB", bbb_close, seq_len(days)))
  args <- list(bars, instruments_df = data.frame(instrument_id = c("AAA", "BBB")),
    facts = do.call(ledgr_facts, c(list(sessions), extra)))
  if (!is.null(price_basis)) args$price_basis <- price_basis
  do.call(ledgr_snapshot_from_df, args)
}
terminal <- function(event) ledgr_facts_lifetime(data.frame(instrument_id = "AAA",
  effective_from = pulses[[4L]], knowledge_time = pulses[[4L]] - 1,
  assertion = "known_inactive", terminal_event = event))
# A declared status family needs a row for every traded instrument: without
# the BBB row the first pulse fails with ledgr_restricted_target for BBB.
halt <- ledgr_facts_trading_status(data.frame(
  instrument_id = c("AAA", "AAA", "BBB"),
  effective_from = openings[c(1L, 4L, 1L)],
  effective_to = c(openings[[4L]], as.POSIXct(NA, tz = "UTC"),
    as.POSIXct(NA, tz = "UTC")),
  knowledge_time = openings[c(1L, 4L, 1L)] - 1,
  status = c("active", "halted", "active"),
  source = "exchange", precedence = 1L))
acquisition <- ledgr_facts_equity_corporate_actions(data.frame(
  fact_id = "acquisition-1", subtype = "cash_acquisition",
  parent_instrument_id = "AAA", entitlement_time = pulses[[4L]],
  effective_time = pulses[[4L]], knowledge_time = pulses[[3L]], complete = TRUE,
  provenance_tier = "snapshot_bound", gross_cash_validated = FALSE,
  recipient_identity_validated = FALSE, recipient_quantity_validated = FALSE,
  source = "terminal_outcome_probe", stringsAsFactors = FALSE))

# Buys 10 BBB, and 10 AAA when with_aaa = 1, on the first pulse; optionally
# targets AAA = 0 from exit_on; otherwise holds.
strategy <- function(ctx, params) {
  if (identical(ctx$ts_utc, "2020-01-01T16:00:00Z")) {
    return(c(AAA = 10 * params$with_aaa, BBB = 10))
  }
  if (!is.null(params$exit_on) && ctx$ts_utc >= params$exit_on) {
    targets <- ctx$hold()
    targets[["AAA"]] <- 0
    return(targets)
  }
  ctx$hold()
}
experiment <- function(snapshot, stale = 2L, policy = NULL) {
  args <- list(snapshot, strategy, opening = ledgr_opening(cash = 10000),
    valuation_policy = ledgr_valuation_stale(stale), cost_model = ledgr_cost_zero())
  if (!is.null(policy)) args$corporate_action_policy <- policy
  do.call(ledgr_experiment, args)
}
describe_run <- function(case, snapshot, bt) {
  info <- attempt(case, "run_info", ledgr_run_info(snapshot, bt$run_id))
  if (!is.null(info)) {
    for (field in intersect(c("status", "stop_reason", "achieved_end_utc",
        "complete_performance"), names(info))) record(case, field, info[[field]])
  }
  equity <- attempt(case, "equity", ledgr_results(bt, what = "equity"))
  if (!is.null(equity)) {
    record(case, "equity_rows", nrow(equity))
    record(case, "last_equity_ts", format(max(equity$ts_utc), tz = "UTC"))
  }
  fills <- attempt(case, "fills", ledgr_results(bt, what = "fills"))
  if (!is.null(fills)) record(case, "fills", nrow(fills))
  diagnostics <- attempt(case, "diagnostics", ledgr_results(bt, what = "diagnostics"))
  if (!is.null(diagnostics) && nrow(diagnostics) > 0L) {
    aaa <- diagnostics[diagnostics$instrument_id %in% "AAA" &
      diagnostics$outcome != "passed", , drop = FALSE]
    record(case, "aaa_non_passed_diagnostics", unique(paste(aaa$stage,
      aaa$outcome, aaa$reason_code, sep = ":")))
  }
  printed <- utils::capture.output(print(bt))
  record(case, "print_status_lines",
    paste(grep("INCOMPLETE|DONE|stop|prefix|terminal|exhaust", printed,
      value = TRUE, ignore.case = TRUE), collapse = " | "))
}
run_case <- function(case, snapshot, params, stale = 2L, policy = NULL) {
  bt <- attempt(case, "ledgr_run", ledgr_run(experiment(snapshot, stale, policy),
    params = params, run_id = case, seed = 1L))
  if (!is.null(bt)) describe_run(case, snapshot, bt)
  bt
}

# R1: held delisting with no settlement evidence.
s1 <- snapshot_for(1:3, list(terminal("delisted")))
run_case("R1_delisted_no_evidence", s1, list(with_aaa = 1))
# R2: held acquisition with an unvalidated cash-acquisition fact.
s2 <- snapshot_for(1:3, list(terminal("acquired"), acquisition), "split_adjusted")
r2 <- run_case("R2_acquired_research", s2, list(with_aaa = 1),
  policy = ledgr_corporate_actions_research())
if (!is.null(r2)) {
  summary <- attempt("R2_acquired_research", "ca_summary",
    ledgr_corporate_action_summary(r2))
  if (!is.null(summary)) for (field in intersect(c("modeled_terminal_proceeds",
      "positions_disposed", "realized_model_pnl"), names(summary)))
    record("R2_acquired_research", field, summary[[field]])
}
run_case("R2_acquired_strict", s2, list(with_aaa = 1),
  policy = ledgr_corporate_actions_strict())
# R3: known halt with no further AAA bars.
s3 <- snapshot_for(1:3, list(halt))
run_case("R3_halt_hold", s3, list(with_aaa = 1))
# R4: the strategy tries to exit AAA during the halt.
run_case("R4_halt_exit_attempt", s3,
  list(with_aaa = 1, exit_on = "2020-01-04T16:00:00Z"))
# R5: AAA bars simply end; no lifetime or status fact explains it.
s5 <- snapshot_for(1:3)
run_case("R5_unexplained_feed_end", s5, list(with_aaa = 1))
# C1: the unaffected comparison run on the R1 snapshot.
run_case("C1_without_aaa", s1, list(with_aaa = 0))

# S1: one sweep, one candidate holding AAA and one never holding it.
grid <- ledgr_param_grid(with_aaa = list(with_aaa = 1), without_aaa = list(with_aaa = 0))
sweep <- attempt("S1_sweep", "ledgr_sweep", ledgr_sweep(experiment(s1), grid,
  retain = ledgr_sweep_retention(returns = "completed"), seed = 1L))
if (!is.null(sweep)) {
  record("S1_sweep", "status", stats::setNames(sweep$status, sweep$candidate_label %||% NULL))
  for (metric in intersect(c("total_return", "sharpe_ratio", "final_equity"), names(sweep)))
    record("S1_sweep", metric, round(sweep[[metric]], 6))
  printed <- utils::capture.output(print(sweep))
  record("S1_sweep", "print", paste(printed, collapse = " | "))
  review <- attempt("S1_sweep", "review",
    utils::capture.output(ledgr_sweep_review(sweep, rank_by = "sharpe_ratio")))
  if (!is.null(review)) record("S1_sweep", "review", paste(review, collapse = " | "))
  filtered <- attempt("S1_sweep", "filter", ledgr_sweep_filter(sweep,
    ledgr_business_objective(ledgr_objective_min_trades(1L))))
  if (!is.null(filtered)) record("S1_sweep", "filter_print",
    paste(utils::capture.output(print(filtered)), collapse = " | "))
  trials <- attempt("S1_sweep", "effective_trials", ledgr_effective_trials(sweep))
  if (!is.null(trials)) record("S1_sweep", "effective_trials",
    paste(utils::capture.output(print(trials)), collapse = " | "))
}

# S2: run comparison on the R1 store (one incomplete run, one complete run).
compared <- attempt("S2_compare", "default", ledgr_run_compare(s1))
if (!is.null(compared)) record("S2_compare", "default_run_ids", compared$run_id)
attempt("S2_compare", "named_incomplete",
  ledgr_run_compare(s1, run_ids = c("R1_delisted_no_evidence", "C1_without_aaa")))

# W1: walk-forward whose training window contains the AAA delisting.
folds <- ledgr:::ledgr_fold_list(list(ledgr_fold("2020-01-01T16:00:00Z",
  "2020-01-06T16:00:00Z", "2020-01-07T16:00:00Z", "2020-01-10T16:00:00Z",
  fold_seq = 1L)), constructor = list(type_id = "explicit"))
wf <- attempt("W1_walk_forward", "ledgr_walk_forward", ledgr_walk_forward(
  experiment(s1), grid = grid, folds = folds,
  selection_rule = ledgr_rule_argmax("sharpe_ratio"), seed = 1L))
if (!is.null(wf)) {
  record("W1_walk_forward", "status", wf$status)
  train <- wf$scores[wf$scores$window == "train", , drop = FALSE]
  record("W1_walk_forward", "train_status", train$status)
  record("W1_walk_forward", "train_candidates", train$candidate_label %||% train$candidate_id)
  selected <- wf$folds$selected_candidate_key[[1L]]
  record("W1_walk_forward", "selected_label",
    unique(wf$scores$candidate_label[wf$scores$candidate_key == selected]))
  record("W1_walk_forward", "train_rows_per_candidate", table(train$candidate_label))
  record("W1_walk_forward", "degradation_warning_flags",
    as.character(wf$folds$warning_flags %||% NA_character_))
  test <- wf$scores[wf$scores$window == "test", , drop = FALSE]
  record("W1_walk_forward", "test_status", unique(test$status))
  record("W1_walk_forward", "print",
    paste(utils::capture.output(print(wf)), collapse = " | "))
}

observations <- do.call(rbind, rows)
utils::write.csv(observations, file.path(out, "observations.csv"), row.names = FALSE)
cat(sprintf("%d observations written to %s\n", nrow(observations), out))
