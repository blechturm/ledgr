# Feature-keeping pre-charter probe (spike_protocol.md Section 1).
# Binds nothing and changes no package code.

args <- commandArgs(trailingOnly = TRUE)
repo <- if (length(args) >= 1L) normalizePath(args[[1L]], winslash = "/", mustWork = TRUE) else normalizePath(".", winslash = "/", mustWork = TRUE)
out_dir <- if (length(args) >= 2L) args[[2L]] else file.path(tempdir(), "ledgr-feature-keeping-probe")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
pkgload::load_all(repo, quiet = TRUE)

db_path <- file.path(out_dir, "probe.duckdb")
unlink(c(db_path, paste0(db_path, ".wal")))
bars <- as.data.frame(ledgr_sim_bars(
  n_instruments = 3L,
  n_days = 40L,
  seed = 20261014L,
  instrument_prefix = "FK_"
))
ids <- sort(unique(as.character(bars$instrument_id)))
snap <- ledgr_snapshot_from_df(
  bars,
  instruments_df = data.frame(instrument_id = ids),
  db_path = db_path,
  snapshot_id = "feature_keeping_probe"
)
on.exit(ledgr_snapshot_close(snap), add = TRUE)

captured <- new.env(parent = emptyenv())
captured$value <- 1
indicator <- ledgr_indicator(
  id = "capture_probe",
  fn = function(window, params = list()) captured$value,
  series_fn = function(bars, params = list()) rep(captured$value, nrow(bars)),
  requires_bars = 1L
)
strategy <- function(ctx, params) {
  signal <- ctx$vec$feature("capture_probe")
  targets <- ctx$flat()
  targets[is.finite(signal) & signal > 1.5] <- 1
  targets
}

run_once <- function(run_id) {
  bt <- ledgr_backtest(
    snapshot = snap,
    strategy = strategy,
    universe = ids,
    start = min(as.Date(bars$ts_utc)),
    end = max(as.Date(bars$ts_utc)),
    initial_cash = 100000,
    run_id = run_id,
    features = list(indicator),
    persist_features = TRUE,
    db_path = db_path,
    cost_model = ledgr_cost_zero()
  )
  on.exit(close(bt), add = TRUE)
  info <- ledgr_run_info(snap, bt$run_id)
  fills <- ledgr_results(bt, "fills")
  data.frame(
    run_id = run_id,
    capture_value = captured$value,
    fills = nrow(fills),
    cache_hits = as.integer(info$feature_cache_hits[[1L]]),
    cache_misses = as.integer(info$feature_cache_misses[[1L]]),
    stringsAsFactors = FALSE
  )
}

ledgr_feature_cache_clear()
first <- run_once("feature-keeping-probe-1")
captured$value <- 2
warm <- run_once("feature-keeping-probe-2")
ledgr_feature_cache_clear()
fresh <- run_once("feature-keeping-probe-3")

feature_read <- tryCatch(
  {
    bt <- ledgr_run_open(snap, "feature-keeping-probe-3")
    on.exit(close(bt), add = TRUE)
    ledgr_results(bt, "features")
    "accepted"
  },
  error = function(e) paste(class(e)[[1L]], conditionMessage(e), sep = ": ")
)

utils::write.csv(rbind(first, warm, fresh), file.path(out_dir, "runs.csv"), row.names = FALSE, na = "")
writeLines(feature_read, file.path(out_dir, "feature_reader.txt"), useBytes = TRUE)
cat(normalizePath(out_dir, winslash = "/", mustWork = TRUE), "\n")
