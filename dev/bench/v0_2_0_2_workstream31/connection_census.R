# Workstream 31 connection census (LDG-2915).
#
# Usage, from any directory:
#
#   Rscript dev/bench/v0_2_0_2_workstream31/connection_census.R <tree> <arm> <out.csv>
#
# Loads the ledgr source tree <tree>, runs one small pipeline against one
# store, and appends one row per public call to <out.csv>, labelled <arm>.
# Every DuckDB connection ledgr makes goes through `DBI::dbConnect()`, which
# the harness wraps to record the connection and the file it opens. Per call it
# reports the connections opened, the distinct files they opened, the most
# opens of any one file, and how many connections opened so far in the
# pipeline, by this call or any earlier one, are still live when it returns.

args <- commandArgs(trailingOnly = TRUE)
tree <- args[[1L]]; arm <- args[[2L]]; out_path <- args[[3L]]
suppressMessages(pkgload::load_all(tree, quiet = TRUE, compile = FALSE))

log <- new.env()
log$cons <- list()
log$files <- character()
log$all <- list()
real_connect <- DBI::dbConnect
testthat::local_mocked_bindings(
  dbConnect = function(drv, ...) {
    con <- real_connect(drv, ...)
    dbdir <- list(...)$dbdir
    log$cons[[length(log$cons) + 1L]] <- con
    log$all[[length(log$all) + 1L]] <- con
    log$files <- c(log$files, if (is.null(dbdir)) ":memory:" else normalizePath(dbdir, mustWork = FALSE))
    con
  },
  .package = "DBI"
)

rows <- list()
census <- function(call, expr) {
  log$cons <- list()
  log$files <- character()
  force(expr)
  per_file <- table(log$files)
  rows[[length(rows) + 1L]] <<- data.frame(
    arm = arm,
    call = call,
    opens = length(log$cons),
    files = length(per_file),
    max_opens_per_file = if (length(per_file)) max(per_file) else 0L,
    live_after = sum(vapply(log$all, DBI::dbIsValid, logical(1)))
  )
  invisible(NULL)
}

bars <- data.frame(
  ts_utc = rep(as.POSIXct(paste(as.Date("2026-02-02") + 0:3, "16:00:00"), tz = "UTC"), each = 2L),
  instrument_id = rep(c("AAA", "BBB"), 4L),
  open = 10, high = 10, low = 10, close = 10, volume = 1000
)
db_path <- tempfile(fileext = ".duckdb")
strategy <- function(ctx, params) ctx$flat()
s <- new.env()

census("ledgr_snapshot_from_df", s$snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path, snapshot_id = "census"))
census("ledgr_snapshot_list", ledgr_snapshot_list(db_path))
census("ledgr_experiment", s$exp <- ledgr_experiment(
  s$snapshot, strategy, opening = ledgr_opening(cash = 1000), cost_model = ledgr_cost_zero()
))
census("ledgr_run", s$bt <- suppressWarnings(ledgr_run(s$exp, run_id = "census_1")))
census("ledgr_run (second)", s$bt2 <- suppressWarnings(ledgr_run(s$exp, run_id = "census_2")))
census("print", utils::capture.output(print(s$bt)))
census("summary", utils::capture.output(summary(s$bt)))
census("ledgr_results fills", ledgr_results(s$bt, "fills"))
census("ledgr_results equity", ledgr_results(s$bt, "equity"))
census("close", close(s$bt))
census("close (second)", close(s$bt2))
census("ledgr_run_list", ledgr_run_list(s$snapshot))
census("ledgr_run_info", ledgr_run_info(s$snapshot, "census_1"))
census("ledgr_run_open", s$reopened <- ledgr_run_open(s$snapshot, "census_1"))
census("close (reopened)", close(s$reopened))
census("ledgr_snapshot_info", ledgr_snapshot_info(s$snapshot))
census("ledgr_feature_contract_check", ledgr_feature_contract_check(s$snapshot, list(ledgr_ind_returns(1))))
s$grid <- ledgr_param_grid(a = list(), b = list())
census("ledgr_precompute_features", s$precomputed <- ledgr_precompute_features(s$exp, s$grid))
census("ledgr_sweep", suppressWarnings(ledgr_sweep(s$exp, s$grid)))
census("ledgr_sweep (precomputed)", suppressWarnings(ledgr_sweep(s$exp, s$grid, precomputed_features = s$precomputed)))
census("ledgr_backtest", s$bt3 <- suppressWarnings(ledgr_backtest(
  snapshot = s$snapshot, strategy = strategy, initial_cash = 1000, cost_model = ledgr_cost_zero()
)))
census("close (backtest)", close(s$bt3))
census("ledgr_db_init", DBI::dbDisconnect(ledgr_db_init(db_path), shutdown = TRUE))
census("ledgr_snapshot_close", ledgr_snapshot_close(s$snapshot))

# Walk-forward, promotion and the interactive contexts, on a second store of
# one instrument and twelve days; walk-forward commits one run per fold.
wf_path <- tempfile(fileext = ".duckdb")
wf_bars <- data.frame(
  ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:11,
  instrument_id = "AAA",
  open = 100 + 1:12, high = 101 + 1:12, low = 99 + 1:12, close = 100 + 1:12, volume = 1000
)
wf_strategy <- function(ctx, params) {
  targets <- ctx$flat()
  if (ctx$close("AAA") >= params$threshold) targets["AAA"] <- params$qty
  targets
}
s$wf_snapshot <- ledgr_snapshot_from_df(wf_bars, db_path = wf_path)
s$wf_exp <- ledgr_experiment(
  s$wf_snapshot, wf_strategy, opening = ledgr_opening(cash = 10000), cost_model = ledgr_cost_zero()
)
folds <- ledgr:::ledgr_fold_list(
  list(
    ledgr_fold("2020-01-01", "2020-01-04", "2020-01-05", "2020-01-07", fold_seq = 1L),
    ledgr_fold("2020-01-04", "2020-01-07", "2020-01-08", "2020-01-10", fold_seq = 2L)
  ),
  constructor = list(type_id = "explicit")
)
census("ledgr_walk_forward (two folds)", s$wf <- suppressWarnings(ledgr_walk_forward(
  s$wf_exp,
  grid = ledgr_param_grid(trade = list(qty = 1, threshold = 101)),
  folds = folds,
  selection_rule = ledgr_rule_argmax("sharpe_ratio"),
  seed = 101L
)))
census("close (two test runs)", invisible(lapply(s$wf$test_runs, close)))
census("ledgr_walk_forward_open", ledgr_walk_forward_open(s$wf_snapshot, s$wf$session_id))
census("ledgr_walk_forward_scores", ledgr_walk_forward_scores(s$wf_snapshot, s$wf$session_id))
census("ledgr_walk_forward_folds", ledgr_walk_forward_folds(s$wf_snapshot, s$wf$session_id))
census("ledgr_candidate (walk-forward)", s$candidate <- ledgr_candidate(s$wf, fold_seq = 1L))
census("ledgr_promote", s$promoted <- suppressWarnings(
  ledgr_promote(s$wf_exp, s$candidate, run_id = "census_promoted")
))
census("close (promoted)", close(s$promoted))
census("ledgr_pulse_snapshot", s$pulse <- ledgr_pulse_snapshot(s$wf_snapshot, "AAA", "2020-01-05T00:00:00Z"))
census("close (pulse)", close(s$pulse))
census("ledgr_indicator_dev", s$dev <- ledgr_indicator_dev(s$wf_snapshot, "AAA", "2020-01-06T00:00:00Z", lookback = 3))
census("indicator dev test_dates", s$dev$test_dates(
  function(window) mean(window$close),
  c("2020-01-05T00:00:00Z", "2020-01-06T00:00:00Z")
))
census("close (indicator dev)", close(s$dev))
census("ledgr_snapshot_close (second store)", ledgr_snapshot_close(s$wf_snapshot))

out <- do.call(rbind, rows)
utils::write.table(out, out_path, sep = ",", row.names = FALSE, col.names = !file.exists(out_path),
  append = file.exists(out_path))
print(out[, -1L], row.names = FALSE)
