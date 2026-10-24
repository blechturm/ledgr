# Execute one registered H1 run or two-candidate sweep for the WS53 sampler.

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 10L) {
  stop(
    paste(
      "Usage: attribution_h1.R <ledgr_src> <library_dir> <load_mode>",
      "<snapshot> <snapshot_hash> <private_work_dir> <out_dir>",
      "<tag> <workers> <product_commit>"
    ),
    call. = FALSE
  )
}

ledgr_src <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
library_dir <- normalizePath(args[[2L]], winslash = "/", mustWork = TRUE)
load_mode <- match.arg(args[[3L]], c("load_all", "library"))
snapshot_src <- normalizePath(args[[4L]], winslash = "/", mustWork = TRUE)
expected_hash <- args[[5L]]
work_dir <- normalizePath(args[[6L]], winslash = "/", mustWork = FALSE)
out_dir <- normalizePath(args[[7L]], winslash = "/", mustWork = FALSE)
tag <- args[[8L]]
workers <- as.integer(args[[9L]])
product_commit <- args[[10L]]
if (!workers %in% c(1L, 2L)) stop("workers must be 1 or 2.", call. = FALSE)

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

markers <- data.frame(label = character(), epoch = numeric())
mark <- function(label) {
  markers <<- rbind(markers, data.frame(label = label, epoch = as.numeric(Sys.time())))
}
mark("process_start")
.libPaths(c(library_dir, "C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
if (identical(load_mode, "load_all")) {
  suppressMessages(pkgload::load_all(ledgr_src, quiet = TRUE, compile = FALSE))
} else {
  suppressPackageStartupMessages(library(ledgr))
}
mark("loaded")

acquisition_commit <- system2(
  "git", c("-C", shQuote(ledgr_src), "rev-parse", "HEAD"), stdout = TRUE
)[[1L]]
store <- file.path(work_dir, paste0(tag, ".duckdb"))
if (file.exists(store)) unlink(store, force = TRUE)
if (!file.copy(snapshot_src, store, overwrite = FALSE)) {
  stop("Snapshot copy failed.", call. = FALSE)
}
on.exit(unlink(store, force = TRUE), add = TRUE)
mark("copied")
snapshot <- ledgr::ledgr_snapshot_open(store, verify = TRUE)
on.exit(ledgr::ledgr_snapshot_close(snapshot), add = TRUE)
info <- ledgr::ledgr_snapshot_info(snapshot)
if (!identical(info$snapshot_hash[[1L]], expected_hash)) {
  stop("Snapshot hash changed.", call. = FALSE)
}
mark("opened")

strategy <- function(ctx, params) {
  month <- substr(ctx$ts_utc, 1L, 7L)
  if (identical(ctx$state_prev$month, month)) return(ctx$hold())
  target <- ctx |>
    ledgr::ledgr_signal_return(params$lookback) |>
    ledgr::ledgr_select_top_n(params$n, partial = "allow") |>
    ledgr::ledgr_weight_equal() |>
    ledgr::ledgr_target_rebalance(ctx, equity_fraction = 0.95)
  list(targets = target, state_update = list(month = month))
}
experiment <- ledgr::ledgr_experiment(
  snapshot,
  strategy,
  features = list(ledgr::ledgr_ind_returns(252L)),
  universe = ledgr::ledgr_universe_members("sharadar_sp500"),
  valuation_policy = ledgr::ledgr_valuation_stale(5L),
  cost_model = ledgr::ledgr_cost_zero(),
  opening = ledgr::ledgr_opening(cash = 1e6)
)
hash_value <- function(x) digest::digest(x, algo = "sha256", serialize = TRUE)

if (workers == 1L) {
  mark("run_start")
  backtest <- ledgr::ledgr_run(
    experiment,
    params = list(lookback = 252L, n = 20L),
    run_id = tag,
    seed = 1L
  )
  mark("run_end")
  run_info <- ledgr::ledgr_run_info(snapshot, backtest$run_id)
  fills <- ledgr::ledgr_results(backtest, "fills")
  equity <- ledgr::ledgr_results(backtest, "equity")
  trades <- ledgr::ledgr_results(backtest, "trades")
  stable_fills <- as.data.frame(fills[, setdiff(names(fills), c("run_id", "event_id"))])
  stable_equity <- as.data.frame(equity[, setdiff(names(equity), "run_id")])
  stable_trades <- as.data.frame(trades[, setdiff(names(trades), "run_id")])
  result <- c(
    status = run_info$status[[1L]],
    pulses = as.character(run_info$pulse_count[[1L]]),
    fills = as.character(nrow(fills)),
    trades = as.character(nrow(trades)),
    final_equity = sprintf("%.6f", equity$equity[[nrow(equity)]]),
    fills_hash = hash_value(stable_fills),
    equity_hash = hash_value(stable_equity),
    trades_hash = hash_value(stable_trades)
  )
  close(backtest)
} else {
  grid <- ledgr::ledgr_strategy_grid(lookback = 252L, n = c(20L, 40L))
  mark("sweep_start")
  sweep <- ledgr::ledgr_sweep(experiment, grid, workers = workers, seed = 1L)
  mark("sweep_end")
  result <- c(
    candidate_status = paste(sweep$status, collapse = ";"),
    candidate_count = as.character(nrow(sweep)),
    candidates_done = as.character(sum(sweep$status == "DONE")),
    final_equity = paste(sprintf("%.6f", sweep$final_equity), collapse = ";"),
    execution_seed = paste(sweep$execution_seed, collapse = ";")
  )
}
mark("reads_end")
result <- c(
  product_commit = product_commit,
  acquisition_commit = acquisition_commit,
  mode = load_mode,
  workers = as.character(workers),
  snapshot_hash = expected_hash,
  result
)
utils::write.csv(
  data.frame(key = names(result), value = unname(result)),
  file.path(out_dir, paste0(tag, "__attrib.csv")),
  row.names = FALSE
)
mark("worker_end")
utils::write.csv(markers, file.path(out_dir, paste0(tag, "__markers.csv")), row.names = FALSE)
cat("WS53_ATTRIBUTION_ARM_OK ", tag, "\n", sep = "")
