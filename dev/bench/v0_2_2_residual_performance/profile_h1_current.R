# Profile the current public H1 run without importing vendor rows into the
# package record. The private snapshot stays below SHARADAR_DATA_ROOT; only
# aggregate timings, counts and hashes are written to out_dir.
#
# Usage:
# Rscript profile_h1_current.R <ledgr_src> <snapshot> <snapshot_hash>
#   <private_work_dir> <out_dir> <profile|telemetry>

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 6L) {
  stop(
    paste(
      "Usage: profile_h1_current.R <ledgr_src> <snapshot> <snapshot_hash>",
      "<private_work_dir> <out_dir> <profile|telemetry>"
    ),
    call. = FALSE
  )
}

ledgr_src <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
snapshot_src <- normalizePath(args[[2L]], winslash = "/", mustWork = TRUE)
expected_hash <- args[[3L]]
work_dir <- normalizePath(args[[4L]], winslash = "/", mustWork = FALSE)
out_dir <- normalizePath(args[[5L]], winslash = "/", mustWork = FALSE)
mode <- match.arg(args[[6L]], c("profile", "telemetry"))
private_root <- normalizePath(
  Sys.getenv("SHARADAR_DATA_ROOT", unset = "."),
  winslash = "/",
  mustWork = TRUE
)
if (!file.exists(file.path(private_root, ".ledgr-sharadar-private-root")) ||
    !startsWith(tolower(work_dir), paste0(tolower(private_root), "/"))) {
  stop("private_work_dir must be below the sentinel-guarded private root.", call. = FALSE)
}
dir.create(work_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
suppressMessages(pkgload::load_all(ledgr_src, quiet = TRUE, compile = FALSE))
ns <- asNamespace("ledgr")
commit <- system2("git", c("-C", shQuote(ledgr_src), "rev-parse", "HEAD"), stdout = TRUE)

store <- file.path(work_dir, paste0("ws53-", mode, ".duckdb"))
if (file.exists(store)) unlink(store, force = TRUE)
if (!file.copy(snapshot_src, store, overwrite = FALSE)) {
  stop("Could not copy the private snapshot.", call. = FALSE)
}
on.exit(unlink(store, force = TRUE), add = TRUE)
snapshot <- ledgr::ledgr_snapshot_open(store, verify = TRUE)
on.exit(ledgr::ledgr_snapshot_close(snapshot), add = TRUE)
info <- ledgr::ledgr_snapshot_info(snapshot)
if (!identical(info$snapshot_hash[[1L]], expected_hash)) {
  stop("The private snapshot hash differs from the registered H1 input.", call. = FALSE)
}

strategy_record <- new.env(parent = emptyenv())
strategy_record$months <- character()
strategy_record$due <- logical()
strategy <- function(ctx, params) {
  month <- substr(ctx$ts_utc, 1L, 7L)
  due <- !identical(ctx$state_prev$month, month)
  strategy_record$months <- c(strategy_record$months, month)
  strategy_record$due <- c(strategy_record$due, due)
  if (!due) return(ctx$hold())
  target <- ctx |>
    ledgr::ledgr_signal_return(params$lookback) |>
    ledgr::ledgr_select_top_n(params$n, partial = "allow") |>
    ledgr::ledgr_weight_equal() |>
    ledgr::ledgr_target_rebalance(ctx, equity_fraction = 0.95)
  list(targets = target, state_update = list(month = month))
}
exp <- ledgr::ledgr_experiment(
  snapshot,
  strategy,
  features = list(ledgr::ledgr_ind_returns(252L)),
  universe = ledgr::ledgr_universe_members("sharadar_sp500"),
  valuation_policy = ledgr::ledgr_valuation_stale(5L),
  cost_model = ledgr::ledgr_cost_zero(),
  opening = ledgr::ledgr_opening(cash = 1e6)
)

restore_stride <- NULL
if (identical(mode, "telemetry")) {
  original_stride <- get("ledgr_run_prepare_telemetry_stride", envir = ns)
  unlockBinding("ledgr_run_prepare_telemetry_stride", ns)
  assign("ledgr_run_prepare_telemetry_stride", function(control) 1L, envir = ns)
  lockBinding("ledgr_run_prepare_telemetry_stride", ns)
  restore_stride <- function() {
    unlockBinding("ledgr_run_prepare_telemetry_stride", ns)
    assign("ledgr_run_prepare_telemetry_stride", original_stride, envir = ns)
    lockBinding("ledgr_run_prepare_telemetry_stride", ns)
  }
  on.exit(restore_stride(), add = TRUE)
}

profile_path <- file.path(work_dir, "ws53-profile.out")
if (identical(mode, "profile")) {
  utils::Rprof(profile_path, interval = 0.005, memory.profiling = TRUE)
  on.exit(utils::Rprof(NULL), add = TRUE)
}
started <- proc.time()[["elapsed"]]
bt <- ledgr::ledgr_run(
  exp,
  params = list(lookback = 252L, n = 20L),
  run_id = paste0("ws53-", mode),
  seed = 1L
)
elapsed <- proc.time()[["elapsed"]] - started
if (identical(mode, "profile")) utils::Rprof(NULL)

run_info <- ledgr::ledgr_run_info(snapshot, bt$run_id)
fills <- ledgr::ledgr_results(bt, "fills")
equity <- ledgr::ledgr_results(bt, "equity")
trades <- ledgr::ledgr_results(bt, "trades")
telemetry <- get("ledgr_get_run_telemetry", envir = ns)(bt$run_id)
hash_value <- function(x) digest::digest(x, algo = "sha256", serialize = TRUE)
stable_fills <- as.data.frame(fills[, setdiff(names(fills), c("run_id", "event_id"))])
stable_equity <- as.data.frame(equity[, setdiff(names(equity), "run_id")])
stable_trades <- as.data.frame(trades[, setdiff(names(trades), "run_id")])

run_row <- data.frame(
  mode = mode,
  ledgr_commit = commit,
  snapshot_hash = expected_hash,
  status = run_info$status[[1L]],
  pulses = run_info$pulse_count[[1L]],
  strategy_calls = length(strategy_record$due),
  decision_calls = sum(strategy_record$due),
  hold_calls = sum(!strategy_record$due),
  elapsed_s = elapsed,
  t_pre_s = telemetry$t_pre,
  t_loop_s = telemetry$t_loop,
  t_post_s = telemetry$t_post,
  fills = nrow(fills),
  trades = nrow(trades),
  final_equity = equity$equity[[nrow(equity)]],
  fills_hash = hash_value(stable_fills),
  equity_hash = hash_value(stable_equity),
  trades_hash = hash_value(stable_trades),
  stringsAsFactors = FALSE
)
utils::write.csv(run_row, file.path(out_dir, paste0(mode, "_run.csv")), row.names = FALSE)

if (identical(mode, "profile")) {
  prof <- summaryRprof(profile_path, memory = "both")
  self <- data.frame(function_name = rownames(prof$by.self), prof$by.self, row.names = NULL)
  total <- data.frame(function_name = rownames(prof$by.total), prof$by.total, row.names = NULL)
  utils::write.csv(self, file.path(out_dir, "profile_self.csv"), row.names = FALSE)
  utils::write.csv(total, file.path(out_dir, "profile_total.csv"), row.names = FALSE)
}

if (identical(mode, "telemetry")) {
  due <- strategy_record$due
  fields <- c(
    "t_pulse", "t_bars", "t_ctx", "t_fill", "t_state", "t_feats",
    "t_strat", "t_target", "t_event", "t_exec"
  )
  if (length(due) != length(telemetry$t_pulse)) {
    stop("Per-pulse telemetry and strategy calls do not align.", call. = FALSE)
  }
  rows <- lapply(fields, function(field) {
    values <- as.numeric(telemetry[[field]])
    data.frame(
      component = field,
      total_s = sum(values),
      decision_s = sum(values[due]),
      held_s = sum(values[!due]),
      wall_share = sum(values) / elapsed,
      held_wall_share = sum(values[!due]) / elapsed,
      stringsAsFactors = FALSE
    )
  })
  utils::write.csv(do.call(rbind, rows), file.path(out_dir, "telemetry_components.csv"), row.names = FALSE)
  candidate <- telemetry$t_ctx + telemetry$t_strat + telemetry$t_target
  utils::write.csv(
    data.frame(
      name = "held_ctx_strategy_target_lower_bound",
      seconds = sum(candidate[!due]),
      wall_share = sum(candidate[!due]) / elapsed,
      held_pulses = sum(!due),
      decision_pulses = sum(due),
      stringsAsFactors = FALSE
    ),
    file.path(out_dir, "scheduler_lower_bound.csv"),
    row.names = FALSE
  )
}

close(bt)
cat("WS53_PROFILE_OK ", mode, "\n", sep = "")
