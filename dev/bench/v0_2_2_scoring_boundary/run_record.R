# Cut 9 scoring-boundary runner (LDG-2968).
#
# Usage, from any directory:
#   Rscript dev/bench/v0_2_2_scoring_boundary/run_record.R <repo> <out_dir> [--allow-dirty]
#
# Records public-path observations for the ten-bar SMA(3) fixture with an
# opening and scoring start on day 6. The internal window helpers isolate the
# defect; they are labelled `internal` and carry no product claim. Strategy
# state is decoded read-only from the persisted store because ledgr exports no
# strategy-state result kind.

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

day <- function(d) as.POSIXct(paste(as.Date("2020-01-01") + d - 1L, "00:00:00"), tz = "UTC")
iso <- function(x) format(as.POSIXct(x, tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
bars <- data.frame(
  instrument_id = "AAA",
  ts_utc = day(1:10),
  open = as.numeric(1:10),
  high = 1:10 + 0.5,
  low = 1:10 - 0.5,
  close = as.numeric(1:10),
  volume = 1000
)
snapshot <- ledgr_snapshot_from_df(bars, db_path = tempfile(fileext = ".duckdb"))
on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
con <- ledgr:::get_connection(snapshot)

strategy <- function(ctx, params) {
  value <- ctx$feature("AAA", "sma_3")
  seen <- c(ctx$state_prev$seen, if (is.na(value)) "NA" else format(value))
  target <- ctx$flat()
  if (!is.na(value)) target[["AAA"]] <- 1
  list(targets = target, state_update = list(seen = seen))
}
features <- list(ledgr_ind_sma(3L))
exp_dated <- ledgr_experiment(
  snapshot, strategy, features = features,
  opening = ledgr_opening(cash = 1000, date = iso(day(6))),
  cost_model = ledgr_cost_zero()
)
exp_plain <- ledgr_experiment(
  snapshot, strategy, features = features,
  opening = ledgr_opening(cash = 1000),
  cost_model = ledgr_cost_zero()
)
grid <- ledgr_param_grid(only = list())
retain <- ledgr_sweep_retention(returns = "completed")

rows <- list()
record <- function(arm, observable, value, boundary = "public") {
  value <- if (length(value) == 0L) "" else paste(as.character(value), collapse = ",")
  rows[[length(rows) + 1L]] <<- data.frame(
    arm = arm, observable = observable, value = value, boundary = boundary,
    stringsAsFactors = FALSE
  )
}
ts_text <- function(x) if (length(x) == 0L) character() else iso(x)

record_durable <- function(arm, bt, boundary = "public") {
  equity <- ledgr_results(bt, "equity")
  fills <- ledgr_results(bt, "fills")
  ledger <- ledgr_results(bt, "ledger")
  state <- DBI::dbGetQuery(
    con,
    "SELECT ts_utc, state_json FROM strategy_state WHERE run_id = ? ORDER BY ts_utc",
    params = list(bt$run_id)
  )
  seen <- if (nrow(state) > 0L) {
    ledgr:::ledgr_json_read_nested(state$state_json[[nrow(state)]])$seen
  } else {
    character()
  }
  record(arm, "equity_first_ts", ts_text(min(equity$ts_utc)), boundary)
  record(arm, "equity_last_ts", ts_text(max(equity$ts_utc)), boundary)
  record(arm, "equity_n", nrow(equity), boundary)
  record(arm, "final_equity", format(equity$equity[[nrow(equity)]], digits = 15), boundary)
  record(arm, "fill_ts", ts_text(fills$ts_utc), boundary)
  record(arm, "fill_n", nrow(fills), boundary)
  record(arm, "ledger_first_ts", ts_text(if (nrow(ledger)) min(ledger$ts_utc) else NULL), boundary)
  record(arm, "ledger_n", nrow(ledger), boundary)
  record(arm, "state_first_ts", ts_text(if (nrow(state)) min(state$ts_utc) else NULL), boundary)
  record(arm, "state_n", nrow(state), boundary)
  record(arm, "sma_seen", seen, boundary)
}

record_sweep <- function(arm, sweep, boundary = "public") {
  returns <- ledgr_sweep_returns(sweep)
  scoring <- attr(sweep, "scoring_range")
  record(arm, "scoring_start", ts_text(scoring$start), boundary)
  record(arm, "scoring_end", ts_text(scoring$end), boundary)
  record(arm, "final_equity", format(sweep$final_equity[[1L]], digits = 15), boundary)
  record(arm, "time_in_market", format(sweep$time_in_market[[1L]], digits = 15), boundary)
  record(arm, "total_return", format(sweep$total_return[[1L]], digits = 15), boundary)
  record(arm, "returns_first_ts", ts_text(min(returns$ts_utc)), boundary)
  record(arm, "returns_last_ts", ts_text(max(returns$ts_utc)), boundary)
  record(arm, "returns_n", nrow(returns), boundary)
}

run <- ledgr_run(exp_dated, run_id = "boundary-run")
record_durable("run", run)
close(run)

backtest <- ledgr_backtest(
  snapshot = snapshot, strategy = strategy, universe = "AAA",
  start = iso(day(6)), initial_cash = 1000, features = features,
  cost_model = ledgr_cost_zero(), run_id = "boundary-backtest"
)
record_durable("backtest", backtest)
close(backtest)

sweep <- ledgr_sweep(exp_dated, grid, retain = retain, workers = 1L, seed = 1L)
record_sweep("sweep", sweep)

promoted <- ledgr_promote(exp_dated, ledgr_candidate(sweep, 1L), run_id = "boundary-promote")
record_durable("promote", promoted)
close(promoted)

window <- ledgr:::ledgr_experiment_window(exp_plain, iso(day(6)), iso(day(10)))
run_window <- ledgr:::ledgr_run_window(exp_plain, window = window, run_id = "boundary-run-window")
record_durable("run_window", run_window, boundary = "internal")
close(run_window)

sweep_window <- ledgr:::ledgr_sweep_window(
  exp_plain, grid, window = window, retain = retain, workers = 1L, seed = 1L
)
record_sweep("sweep_window", sweep_window, boundary = "internal")

folds <- ledgr:::ledgr_fold_list(
  list(ledgr_fold(iso(day(6)), iso(day(8)), iso(day(9)), iso(day(10)), fold_seq = 1L)),
  constructor = list(type_id = "explicit")
)
walk_forward <- suppressWarnings(ledgr_walk_forward(
  exp_plain, grid, folds,
  selection_rule = ledgr_rule_argmax("sharpe_ratio"), seed = 1L
))
fold <- as.data.frame(walk_forward$folds)
scores <- as.data.frame(walk_forward$scores)
score <- function(window_name, metric) {
  hit <- scores$window == window_name & scores$metric_name == metric
  format(scores$metric_value[hit][[1L]], digits = 15)
}
record("walk_forward", "hydration_start", ts_text(fold$hydration_start_utc[[1L]]))
record("walk_forward", "train_scoring_start", ts_text(fold$train_scoring_start_utc[[1L]]))
record("walk_forward", "test_scoring_start", ts_text(fold$test_scoring_start_utc[[1L]]))
record("walk_forward", "train_final_equity", score("train", "final_equity"))
record("walk_forward", "train_time_in_market", score("train", "time_in_market"))
record("walk_forward", "train_total_return", score("train", "total_return"))
record("walk_forward", "test_final_equity", score("test", "final_equity"))
record_durable("walk_forward_test", walk_forward$test_runs[[1L]])
invisible(lapply(walk_forward$test_runs, close))

refusal <- tryCatch(
  {
    ledgr:::ledgr_experiment_window(
      exp_plain, iso(day(6)), iso(day(10)),
      execution_start_utc = iso(day(7))
    )
    list(class = "accepted", message = "")
  },
  error = function(e) list(class = class(e)[[1L]], message = conditionMessage(e))
)
record("execution_start", "outcome", refusal$class, "internal")
record("execution_start", "message", refusal$message, "internal")

observations <- do.call(rbind, rows)
utils::write.csv(observations, file.path(out_dir, "observations.csv"), row.names = FALSE)
environment <- data.frame(
  key = c("commit", "tracked_tree_clean", "r_version", "ledgr_version", "duckdb_version", "command"),
  value = c(
    git("rev-parse", "HEAD"),
    if (nzchar(tracked_status)) "FALSE" else "TRUE",
    paste(R.version$major, R.version$minor, sep = "."),
    as.character(utils::packageVersion("ledgr", lib.loc = NULL)),
    as.character(utils::packageVersion("duckdb")),
    paste("Rscript dev/bench/v0_2_2_scoring_boundary/run_record.R", "<repo>", "<out_dir>")
  ),
  stringsAsFactors = FALSE
)
utils::write.csv(environment, file.path(out_dir, "environment.csv"), row.names = FALSE)
cat("LEDGR_SCORING_BOUNDARY_RECORDED", nrow(observations), "observations\n")
