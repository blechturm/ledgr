# One current-tree H1 sweep arm for the WS53 process-tree sampler.
# Private snapshot rows stay below SHARADAR_DATA_ROOT.

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 7L) {
  stop(
    paste(
      "Usage: worker_scaling_h1.R <ledgr_src> <snapshot> <snapshot_hash>",
      "<private_work_dir> <out_dir> <tag> <workers>"
    ),
    call. = FALSE
  )
}
ledgr_src <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
snapshot_src <- normalizePath(args[[2L]], winslash = "/", mustWork = TRUE)
expected_hash <- args[[3L]]
work_dir <- normalizePath(args[[4L]], winslash = "/", mustWork = FALSE)
out_dir <- normalizePath(args[[5L]], winslash = "/", mustWork = FALSE)
tag <- args[[6L]]
workers <- as.integer(args[[7L]])
if (is.na(workers) || !workers %in% c(2L, 4L, 8L)) {
  stop("workers must be 2, 4 or 8 for this record.", call. = FALSE)
}
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
commit <- system2("git", c("-C", shQuote(ledgr_src), "rev-parse", "HEAD"), stdout = TRUE)

store <- file.path(work_dir, paste0(tag, ".duckdb"))
if (file.exists(store)) unlink(store, force = TRUE)
if (!file.copy(snapshot_src, store, overwrite = FALSE)) stop("Snapshot copy failed.", call. = FALSE)
on.exit(unlink(store, force = TRUE), add = TRUE)
snapshot <- ledgr::ledgr_snapshot_open(store, verify = TRUE)
on.exit(ledgr::ledgr_snapshot_close(snapshot), add = TRUE)
info <- ledgr::ledgr_snapshot_info(snapshot)
if (!identical(info$snapshot_hash[[1L]], expected_hash)) stop("Snapshot hash changed.", call. = FALSE)

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
exp <- ledgr::ledgr_experiment(
  snapshot,
  strategy,
  features = list(ledgr::ledgr_ind_returns(252L)),
  universe = ledgr::ledgr_universe_members("sharadar_sp500"),
  valuation_policy = ledgr::ledgr_valuation_stale(5L),
  cost_model = ledgr::ledgr_cost_zero(),
  opening = ledgr::ledgr_opening(cash = 1e6)
)
grid <- ledgr::ledgr_strategy_grid(lookback = 252L, n = c(20L, 40L))
started <- proc.time()[["elapsed"]]
sweep <- ledgr::ledgr_sweep(exp, grid, workers = workers, seed = 1L)
elapsed <- proc.time()[["elapsed"]] - started
payload_census <- attr(sweep, "staged_payload_census")
utils::write.csv(
  payload_census,
  file.path(out_dir, paste0(tag, "_payload_census.csv")),
  row.names = FALSE
)
utils::write.csv(
  data.frame(
    tag = tag,
    workers = workers,
    ledgr_commit = commit,
    snapshot_hash = expected_hash,
    elapsed_s = elapsed,
    staged_invariant_bytes = attr(sweep, "staged_invariant_bytes"),
    candidates = nrow(sweep),
    done = sum(sweep$status == "DONE"),
    final_equity = paste(sprintf("%.6f", sweep$final_equity), collapse = ";"),
    execution_seed = paste(sweep$execution_seed, collapse = ";"),
    stringsAsFactors = FALSE
  ),
  file.path(out_dir, paste0(tag, "_result.csv")),
  row.names = FALSE
)
cat("WS53_WORKER_ARM_OK ", tag, "\n", sep = "")
