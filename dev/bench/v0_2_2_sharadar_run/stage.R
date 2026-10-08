# LDG-2976 stage worker: one stage of the 1998-2026 Sharadar run per process.
#
#   Rscript stage.R <stage> <ledgr_repo> <adapter_repo> <work_dir> <out_dir>
#
# Stages: build, census, momentum, equal_weight, sweep, walk_forward.
# Reads the private lake read-only and writes only aggregate outputs to
# <out_dir> (no instrument IDs, no vendor rows). The snapshot itself lives in
# <work_dir>, which must be under the private data root.
args <- commandArgs(trailingOnly = TRUE)
stage <- args[[1L]]
ledgr_repo <- normalizePath(args[[2L]], winslash = "/")
adapter_repo <- normalizePath(args[[3L]], winslash = "/")
work_dir <- args[[4L]]
out_dir <- args[[5L]]
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths(), "E:/ledgr-data/r-lib/ledgr-0.2.1.0"))
suppressMessages(pkgload::load_all(ledgr_repo, quiet = TRUE, compile = FALSE))
suppressMessages(pkgload::load_all(file.path(adapter_repo, "packages", "ledgr.sharadar"), quiet = TRUE))
root <- Sys.getenv("SHARADAR_DATA_ROOT", "E:/ledgr-data/sharadar")
Sys.setenv(SHARADAR_DATA_ROOT = root)
from <- as.Date("1998-01-02")
to <- as.Date("2026-09-04")
snapshot_path <- file.path(work_dir, "sp500-1998-2026.duckdb")
started <- Sys.time()

out <- list(stage = stage)
put <- function(...) { x <- list(...); out[names(x)] <<- x }
condition_row <- function(e) list(class = paste(class(e), collapse = "|"), message = gsub("\\s+", " ", conditionMessage(e)))
attempt <- function(label, expr) {
  t0 <- Sys.time()
  value <- tryCatch(expr, error = function(e) e, interrupt = function(e) e)
  rec <- list(elapsed_s = round(as.numeric(difftime(Sys.time(), t0, units = "secs")), 2))
  if (inherits(value, "condition")) rec$condition <- condition_row(value) else rec$condition <- NULL
  out$attempts[[label]] <<- rec
  if (inherits(value, "condition")) NULL else value
}

lake_connect <- function() sharadar_connect_lake(file.path(root, "lake", "ledgr-research.duckdb"),
                                                  read_only = TRUE, require_sentinel = TRUE)
build_id_of <- function(lake) {
  DBI::dbGetQuery(lake, paste(
    "SELECT f.canonical_build_id FROM audit.full_history_runs f",
    "JOIN audit.data_mvp_closeouts c USING (full_history_run_id)",
    "WHERE f.reproducibility_status = 'matched'"))$canonical_build_id
}
universe_of <- function(snapshot) {
  con <- ledgr:::get_connection(snapshot)
  DBI::dbGetQuery(con, "SELECT DISTINCT universe_id FROM snapshot_membership_sets")$universe_id[[1L]]
}

if (identical(stage, "build")) {
  dir.create(work_dir, recursive = TRUE, showWarnings = FALSE)
  unlink(c(snapshot_path, paste0(snapshot_path, ".wal")))
  lake <- lake_connect()
  build_id <- build_id_of(lake)
  put(canonical_build_id = build_id, from = format(from), to = format(to),
      adapter_policy = sharadar_ledgr_adapter_policy_version())
  snapshot <- attempt("build_snapshot", sharadar_ledgr_snapshot(lake, build_id, from, to, snapshot_path))
  if (!is.null(snapshot)) {
    info <- ledgr_snapshot_info(snapshot)
    put(snapshot_id = snapshot$snapshot_id, snapshot_hash = info$snapshot_hash,
        snapshot_status = info$status)
    ledgr_snapshot_close(snapshot)
    reopened <- attempt("reopen_verify", ledgr_snapshot_open(snapshot_path, verify = TRUE))
    if (!is.null(reopened)) ledgr_snapshot_close(reopened)
  }
  # Bars the adapter left out because nobody traded (aggregate).
  # Bars of the snapshot's instruments the v003 adapter left out because
  # nobody traded (aggregate count only).
  if (file.exists(snapshot_path)) {
    snap_con <- DBI::dbConnect(duckdb::duckdb(), snapshot_path, read_only = TRUE)
    ids <- DBI::dbGetQuery(snap_con, "SELECT DISTINCT instrument_id FROM snapshot_instruments")
    DBI::dbDisconnect(snap_con, shutdown = TRUE)
    duckdb::duckdb_register(lake, "ldg2976_axis", ids)
    dropped <- DBI::dbGetQuery(lake, paste(
      "SELECT COUNT(*) AS untraded_bars, COUNT(DISTINCT b.instrument_id) AS instruments",
      "FROM core.daily_bars b JOIN ldg2976_axis a ON a.instrument_id = b.instrument_id",
      "WHERE b.canonical_build_id = ? AND b.trade_date BETWEEN ? AND ?",
      "AND b.adjustment_policy = 'split_adjusted' AND b.quality_status = 'accepted'",
      "AND b.volume = 0"), params = list(build_id, from, to))
    duckdb::duckdb_unregister(lake, "ldg2976_axis")
    put(untraded_bars_dropped = dropped$untraded_bars, untraded_bar_instruments = dropped$instruments)
  }
  DBI::dbDisconnect(lake, shutdown = TRUE)
}

if (identical(stage, "census")) {
  snapshot <- ledgr_snapshot_open(snapshot_path)
  con <- ledgr:::get_connection(snapshot)
  q <- function(sql) DBI::dbGetQuery(con, sql)
  put(bars = q("SELECT COUNT(*) n FROM snapshot_bars")$n,
      instruments_with_bars = q("SELECT COUNT(DISTINCT instrument_id) n FROM snapshot_bars")$n,
      open_sessions = q("SELECT COUNT(*) n FROM snapshot_sessions WHERE status = 'open'")$n,
      membership_rows = q("SELECT COUNT(*) n FROM snapshot_membership")$n,
      membership_sets = q("SELECT COUNT(*) n FROM snapshot_membership_sets")$n,
      lifetime_rows = q("SELECT COUNT(*) n FROM snapshot_lifetime")$n,
      trading_status_facts = q("SELECT COUNT(*) n FROM snapshot_trading_status")$n,
      superseding_status_facts = q("SELECT COUNT(*) n FROM snapshot_trading_status WHERE supersedes_fact_id IS NOT NULL")$n)
  terminal <- q("SELECT COALESCE(terminal_event, '(none)') AS terminal_event, COUNT(*) AS n
                 FROM snapshot_lifetime WHERE assertion = 'known_inactive' GROUP BY 1 ORDER BY 2 DESC")
  utils::write.csv(terminal, file.path(out_dir, "terminal_labels.csv"), row.names = FALSE)
  # Runs of consecutive open sessions without a bar, between each instrument's
  # first and last bar (interior gaps), after untraded bars were dropped.
  gaps <- q("
    WITH s AS (SELECT session_date, ROW_NUMBER() OVER (ORDER BY session_date) AS idx
               FROM snapshot_sessions WHERE status = 'open'),
    b AS (SELECT DISTINCT instrument_id, CAST(ts_utc AS DATE) AS d FROM snapshot_bars),
    bi AS (SELECT b.instrument_id, s.idx FROM b JOIN s ON s.session_date = b.d),
    g AS (SELECT instrument_id, idx, LEAD(idx) OVER (PARTITION BY instrument_id ORDER BY idx) AS next_idx FROM bi)
    SELECT CASE WHEN next_idx - idx - 1 = 1 THEN '1'
                WHEN next_idx - idx - 1 = 2 THEN '2'
                WHEN next_idx - idx - 1 BETWEEN 3 AND 5 THEN '3-5'
                WHEN next_idx - idx - 1 BETWEEN 6 AND 10 THEN '6-10'
                WHEN next_idx - idx - 1 BETWEEN 11 AND 20 THEN '11-20'
                ELSE '>20' END AS gap_sessions,
           COUNT(*) AS runs, COUNT(DISTINCT instrument_id) AS instruments, SUM(next_idx - idx - 1) AS missing_sessions
    FROM g WHERE next_idx - idx - 1 > 0 GROUP BY 1 ORDER BY MIN(next_idx - idx - 1)")
  utils::write.csv(gaps, file.path(out_dir, "gap_lengths.csv"), row.names = FALSE)
  ledgr_snapshot_close(snapshot)
}

run_stage <- function(label, strategy, features, params_list, mode) {
  snapshot <- ledgr_snapshot_open(snapshot_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  universe <- universe_of(snapshot)
  exp <- ledgr_experiment(snapshot, strategy, features = features,
                          universe = ledgr_universe_members(universe),
                          valuation_policy = ledgr_valuation_stale(5),
                          cost_model = ledgr_cost_zero(),
                          opening = ledgr_opening(cash = 1e6))
  if (identical(mode, "run")) {
    bt <- attempt(label, ledgr_run(exp, params = params_list, run_id = paste0("ldg2976-", label)))
    if (!is.null(bt)) {
      info <- ledgr_run_info(snapshot, bt$run_id)
      diag <- ledgr_results(bt, "diagnostics")
      put(status = info$status, stop_reason = info$stop_reason %||% NA_character_,
          fills = nrow(ledgr_results(bt, "fills")), equity_rows = nrow(ledgr_results(bt, "equity")),
          final_equity = round(utils::tail(ledgr_results(bt, "equity")$equity, 1L), 2),
          sizing_unavailable_rows = sum(diag$reason_code == "sizing_unavailable"),
          diagnostic_reasons = as.list(table(diag$reason_code)))
      close(bt)
    }
  } else if (identical(mode, "sweep")) {
    grid <- do.call(ledgr_strategy_grid, params_list)
    sw <- attempt(label, ledgr_sweep(exp, grid, workers = 1L, seed = 1L))
    if (!is.null(sw)) put(candidates = nrow(sw), candidate_status = as.list(table(sw$status)))
  } else {
    grid <- do.call(ledgr_strategy_grid, params_list)
    # Fold boundaries are UTC midnight but the snapshot starts at the first
    # close (21:00 UTC): before LDG-2991 the first date was refused (stop S1),
    # so the LDG-2976 record starts on 1998-01-05.
    wf_start <- if (identical(label, "walk_forward_first_date")) "1998-01-02" else "1998-01-05"
    folds <- ledgr_folds_rolling(wf_start, "2026-09-04", train_window = "2 years",
                                 test_window = "1 year", step = "1 year")
    wf <- attempt(label, ledgr_walk_forward(exp, grid, folds, ledgr_rule_argmax("sharpe_ratio"), seed = 1L))
    if (!is.null(wf)) {
      put(session_status = wf$status, folds = nrow(wf$folds),
          fold_status = as.list(table(wf$folds$status)),
          selection_source = as.list(table(wf$folds$selection_source, useNA = "ifany")))
    }
  }
}

momentum <- function(ctx, params) {
  month <- substr(ctx$ts_utc, 1L, 7L)
  if (identical(ctx$state_prev$month, month)) return(ctx$hold())
  target <- ctx |> ledgr_signal_return(params$lookback) |>
    ledgr_select_top_n(params$n, partial = "allow") |> ledgr_weight_equal() |>
    ledgr_target_rebalance(ctx, equity_fraction = 0.95)
  list(targets = target, state_update = list(month = month))
}
equal_weight <- function(ctx, params) {
  month <- substr(ctx$ts_utc, 1L, 7L)
  if (identical(ctx$state_prev$month, month)) return(ctx$hold())
  target <- ctx |> ledgr_selection() |> ledgr_weight_equal() |>
    ledgr_target_rebalance(ctx, equity_fraction = 0.95)
  list(targets = target, state_update = list(month = month))
}

if (identical(stage, "momentum")) {
  run_stage("momentum", momentum, list(ledgr_ind_returns(252L)), list(lookback = 252L, n = 20L), "run")
}
if (identical(stage, "equal_weight")) {
  run_stage("equal_weight", equal_weight, list(), list(), "run")
}
if (identical(stage, "sweep")) {
  run_stage("sweep", momentum, list(ledgr_ind_returns(252L)), list(lookback = 252L, n = c(10L, 20L, 40L)), "sweep")
}
if (stage %in% c("walk_forward", "walk_forward_first_date")) {
  run_stage(stage, momentum, list(ledgr_ind_returns(63L)), list(lookback = 63L, n = c(10L, 20L, 40L)), "wf")
}

# Phase shares of one canonical-R run, from the fold's own sampled telemetry
# (every 100th pulse by default; the samples live only in this R session).
profile_stage <- function(label, strategy, features, params) {
  snapshot <- ledgr_snapshot_open(snapshot_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  exp <- ledgr_experiment(snapshot, strategy, features = features,
                          universe = ledgr_universe_members(universe_of(snapshot)),
                          valuation_policy = ledgr_valuation_stale(5),
                          cost_model = ledgr_cost_zero(),
                          opening = ledgr_opening(cash = 1e6))
  run_id <- paste0("ldg2976-profile-", label, "-", format(Sys.time(), "%H%M%S"))
  bt <- attempt(label, ledgr_run(exp, params = params, run_id = run_id))
  if (is.null(bt)) return(invisible(NULL))
  tel <- ledgr:::ledgr_get_run_telemetry(run_id)
  phases <- c("t_bars", "t_feats", "t_ctx", "t_strat", "t_target", "t_fill", "t_event", "t_state", "t_pulse")
  sums <- vapply(phases, function(p) sum(as.numeric(tel[[p]]), na.rm = TRUE), numeric(1))
  rows <- data.frame(stage = label, phase = phases, sampled_s = round(sums, 4),
                     share_of_pulse = round(sums / sums[["t_pulse"]], 4), stringsAsFactors = FALSE)
  utils::write.csv(rows, file.path(out_dir, paste0("profile_", label, ".csv")), row.names = FALSE)
  put(telemetry_stride = tel$telemetry_stride, telemetry_samples = tel$telemetry_samples,
      t_pre = tel$t_pre, t_loop = tel$t_loop, t_post = tel$t_post,
      fills = nrow(ledgr_results(bt, "fills")))
  close(bt)
}
if (identical(stage, "profile_momentum")) {
  profile_stage("momentum", momentum, list(ledgr_ind_returns(252L)), list(lookback = 252L, n = 20L))
}
if (identical(stage, "profile_equal_weight")) {
  profile_stage("equal_weight", equal_weight, list(), list())
}

put(elapsed_s = round(as.numeric(difftime(Sys.time(), started, units = "secs")), 1),
    ledgr_commit = system2("git", c("-C", shQuote(ledgr_repo), "rev-parse", "HEAD"), stdout = TRUE),
    adapter_commit = system2("git", c("-C", shQuote(adapter_repo), "rev-parse", "HEAD"), stdout = TRUE))
jsonlite::write_json(out, file.path(out_dir, paste0(stage, ".json")), auto_unbox = TRUE, pretty = TRUE, null = "null")
cat("STAGE_DONE", stage, "\n")
