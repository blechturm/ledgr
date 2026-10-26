# Run one arm of the registered H1 scheduler comparison. Private snapshot rows
# never leave the copied store; this runner writes only hashes, counts, dates
# and clocks.
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 8L) {
  stop(paste(
    "Usage: run_arm.R <ledgr_src> <snapshot> <snapshot_hash>",
    "<private_work_dir> <out_dir> <pair> <order> <manual|scheduled>"
  ), call. = FALSE)
}

ledgr_src <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
snapshot_src <- normalizePath(args[[2L]], winslash = "/", mustWork = TRUE)
expected_hash <- args[[3L]]
work_dir <- normalizePath(args[[4L]], winslash = "/", mustWork = FALSE)
out_dir <- normalizePath(args[[5L]], winslash = "/", mustWork = FALSE)
pair <- as.integer(args[[6L]])
order_in_pair <- as.integer(args[[7L]])
arm <- match.arg(args[[8L]], c("manual", "scheduled"))
if (is.na(pair) || pair < 1L || is.na(order_in_pair) || !order_in_pair %in% 1:2) {
  stop("pair and order must identify a positive pair and arm 1 or 2.", call. = FALSE)
}

private_root <- normalizePath(Sys.getenv("SHARADAR_DATA_ROOT", unset = "."), winslash = "/", mustWork = TRUE)
if (!file.exists(file.path(private_root, ".ledgr-sharadar-private-root")) ||
    !startsWith(tolower(work_dir), paste0(tolower(private_root), "/"))) {
  stop("private_work_dir must be below the sentinel-guarded private root.", call. = FALSE)
}
dir.create(work_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

suppressMessages(pkgload::load_all(ledgr_src, quiet = TRUE, compile = FALSE))
product_commit <- system2("git", c("-C", shQuote(ledgr_src), "rev-parse", "HEAD"), stdout = TRUE)
affinity <- system2(
  "powershell",
  c("-NoProfile", "-Command", shQuote(sprintf(
    "$p = Get-Process -Id %d; $p.ProcessorAffinity = 0xFFFF; [string]$p.ProcessorAffinity",
    Sys.getpid()
  ), type = "cmd")),
  stdout = TRUE,
  stderr = TRUE
)
power <- system2("powercfg", "/getactivescheme", stdout = TRUE, stderr = TRUE)

tag <- sprintf("pair%d_%d_%s", pair, order_in_pair, arm)
store <- file.path(work_dir, paste0(tag, ".duckdb"))
if (file.exists(store)) unlink(store, force = TRUE)
if (!file.copy(snapshot_src, store, overwrite = FALSE)) stop("Could not copy the private snapshot.", call. = FALSE)
if (!identical(Sys.getenv("LEDGR_KEEP_PRIVATE_STORE"), "true")) {
  on.exit(unlink(store, force = TRUE), add = TRUE)
}
snapshot <- ledgr::ledgr_snapshot_open(store, verify = TRUE)
on.exit(ledgr::ledgr_snapshot_close(snapshot), add = TRUE)
info <- ledgr::ledgr_snapshot_info(snapshot)
if (!identical(info$snapshot_hash[[1L]], expected_hash)) {
  stop("The private snapshot hash differs from the registered H1 input.", call. = FALSE)
}

strategy <- function(ctx, params) {
  month <- substr(ctx$ts_utc, 1L, 7L)
  due <- !identical(ctx$state_prev$month, month)
  if (!due) return(ctx$hold())
  target <- ctx |>
    ledgr::ledgr_signal_return(params$lookback) |>
    ledgr::ledgr_select_top_n(params$n, partial = "allow") |>
    ledgr::ledgr_weight_equal() |>
    ledgr::ledgr_target_rebalance(ctx, equity_fraction = 0.95)
  list(targets = target, state_update = list(month = month))
}
run_strategy <- if (identical(arm, "scheduled")) {
  ledgr::ledgr_strategy_schedule(strategy, ledgr::ledgr_schedule_month_start())
} else {
  strategy
}
exp <- ledgr::ledgr_experiment(
  snapshot,
  run_strategy,
  features = list(ledgr::ledgr_ind_returns(252L)),
  universe = ledgr::ledgr_universe_members("sharadar_sp500"),
  valuation_policy = ledgr::ledgr_valuation_stale(5L),
  cost_model = ledgr::ledgr_cost_zero(),
  opening = ledgr::ledgr_opening(cash = 1e6, date = as.Date("1998-02-02"))
)

started <- proc.time()[["elapsed"]]
bt <- ledgr::ledgr_run(exp, params = list(lookback = 252L, n = 20L), run_id = tag, seed = 1L)
elapsed <- proc.time()[["elapsed"]] - started
run_info <- ledgr::ledgr_run_info(snapshot, tag)
fills <- ledgr::ledgr_results(bt, "fills")
ledger <- ledgr::ledgr_results(bt, "ledger")
equity <- ledgr::ledgr_results(bt, "equity")
diagnostics <- ledgr::ledgr_results(bt, "diagnostics")
close(bt)

con <- ledgr::ledgr_db_init(store)
on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
reconstructed <- ledgr::ledgr_state_reconstruct(tag, con)
states <- DBI::dbGetQuery(
  con,
  "SELECT ts_utc, state_json FROM strategy_state WHERE run_id = ? ORDER BY ts_utc",
  params = list(tag)
)
DBI::dbDisconnect(con, shutdown = TRUE)

stable_hash <- function(x, drop = character()) {
  x <- as.data.frame(x[, setdiff(names(x), drop), drop = FALSE])
  rownames(x) <- NULL
  digest::digest(x, algo = "sha256", serialize = TRUE)
}
state_month <- sub(
  '.*"month":"([^"]+)".*',
  "\\1",
  states$state_json
)
if (any(!grepl("^[0-9]{4}-[0-9]{2}$", state_month))) {
  stop("Persisted strategy state does not carry the expected month cursor.", call. = FALSE)
}
state_changed <- c(TRUE, state_month[-1L] != state_month[-length(state_month)])
due_tokens <- as.character(states$ts_utc[state_changed])
if (any(!grepl("^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}Z$", due_tokens))) {
  stop("Persisted strategy-state timestamps are not canonical UTC strings.", call. = FALSE)
}
due_ts <- as.POSIXct(
  due_tokens,
  tz = "UTC",
  format = "%Y-%m-%dT%H:%M:%SZ"
)
due_dates <- format(due_ts, "%Y-%m-%d", tz = "UTC")
utils::write.csv(
  data.frame(pair = pair, arm = arm, due_date = due_dates),
  file.path(out_dir, paste0(tag, "_due_dates.csv")),
  row.names = FALSE
)

diagnostic_ts <- format(as.POSIXct(diagnostics$ts_utc, tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
due_diagnostics <- diagnostics[diagnostic_ts %in% due_tokens, , drop = FALSE]
off_diagnostics <- diagnostics[!diagnostic_ts %in% due_tokens, , drop = FALSE]
diag_columns <- setdiff(names(due_diagnostics), c("run_id", "diagnostic_seq"))
retained_off_diagnostics <- off_diagnostics[
  !off_diagnostics$stage %in% c("decision", "risk"),
  diag_columns,
  drop = FALSE
]
off_counts <- stats::aggregate(
  rep.int(1L, nrow(off_diagnostics)),
  by = off_diagnostics[c("stage", "outcome", "reason_code")],
  FUN = sum
)
names(off_counts)[[4L]] <- "n"
off_counts <- off_counts[order(
  off_counts$stage,
  off_counts$outcome,
  off_counts$reason_code
), , drop = FALSE]
utils::write.csv(
  cbind(
    data.frame(
      pair = rep.int(pair, nrow(off_counts)),
      arm = rep.int(arm, nrow(off_counts)),
      stringsAsFactors = FALSE
    ),
    off_counts
  ),
  file.path(out_dir, paste0(tag, "_off_diagnostic_counts.csv")),
  row.names = FALSE
)

row <- data.frame(
  pair = pair,
  order_in_pair = order_in_pair,
  arm = arm,
  elapsed_s = elapsed,
  product_commit = product_commit,
  snapshot_hash = expected_hash,
  snapshot_id = info$snapshot_id[[1L]],
  strategy_source_hash = run_info$strategy_source_hash[[1L]],
  schedule_hash = if ("schedule_hash" %in% names(run_info)) run_info$schedule_hash[[1L]] else NA_character_,
  status = run_info$status[[1L]],
  pulse_count = run_info$pulse_count[[1L]],
  decision_pulse_count = run_info$decision_pulse_count[[1L]],
  scheduled_skip_count = run_info$scheduled_skip_count[[1L]],
  due_count = length(due_dates),
  fills_hash = stable_hash(fills, c("run_id", "event_id")),
  ledger_hash = stable_hash(ledger, c("run_id", "event_id")),
  equity_hash = stable_hash(equity, "run_id"),
  positions_hash = digest::digest(reconstructed$positions, algo = "sha256", serialize = TRUE),
  lots_hash = digest::digest(reconstructed$lots, algo = "sha256", serialize = TRUE),
  state_hash = stable_hash(states),
  due_diagnostics_hash = stable_hash(due_diagnostics[, diag_columns, drop = FALSE]),
  due_diagnostic_rows = nrow(due_diagnostics),
  retained_off_diagnostics_hash = stable_hash(retained_off_diagnostics),
  retained_off_diagnostic_rows = nrow(retained_off_diagnostics),
  off_diagnostic_rows = nrow(off_diagnostics),
  off_scheduled_skip_rows = sum(off_diagnostics$reason_code == "scheduled_skip"),
  final_equity = tail(equity$equity, 1L),
  affinity = paste(affinity, collapse = " "),
  power_plan = if (any(grepl("High performance", power, fixed = TRUE))) "High performance" else "other",
  stringsAsFactors = FALSE
)
utils::write.csv(row, file.path(out_dir, paste0(tag, "_summary.csv")), row.names = FALSE)
cat("LEDGR_SCHEDULER_ARM_OK ", tag, "\n", sep = "")
