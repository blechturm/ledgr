# F6 probe: inside real runs, how are the rebuilt old lists certified,
# and does the reviewer's fixture data refuse end to end?
tree <- commandArgs(TRUE)[1]; if (is.na(tree)) tree <- "."
pkgload::load_all(tree, quiet = TRUE)
ns <- asNamespace("ledgr")
box <- new.env(parent = emptyenv())
box$cert <- character()
o_cert <- ns$ledgr_feature_certify
unlockBinding("ledgr_feature_certify", ns)
assign("ledgr_feature_certify", function(def) {
  out <- o_cert(def)
  box$cert <- c(box$cert, paste0(def$id, "=", out$certification))
  out
}, ns)
o_cfg <- ns$ledgr_feature_defs_from_config
unlockBinding("ledgr_feature_defs_from_config", ns)
assign("ledgr_feature_defs_from_config", function(cfg) {
  box$cfg <- cfg
  o_cfg(cfg)
}, ns)

# The reviewer's fixture bars (dev/feature_parity/corpus.R fx_empty), instrument F only.
axis <- as.POSIXct("2020-01-01 21:00:00", tz = "UTC") + 0:11 * 86400
k <- seq_along(axis)
bars <- data.frame(instrument_id = "F", ts_utc = axis, open = 50 + k, high = 51 + k + k %% 3,
  low = 49 + k, close = 50.5 + k + sin(k), volume = 500 + k, stringsAsFactors = FALSE)
snap <- ledgr_snapshot_from_df(bars, db_path = tempfile(fileext = ".duckdb"))

run_one <- function(label, features) {
  box$cert <- character()
  exp <- ledgr_experiment(snap, function(ctx, params) ctx$hold(), features = features,
    opening = ledgr_opening(cash = 1e5), cost_model = ledgr_cost_zero())
  r <- tryCatch({ close(ledgr_run(exp, run_id = paste0("f6p5_", label))); "success" },
    error = function(e) paste(class(e)[1], "-", substr(conditionMessage(e), 1, 160)))
  cat(sprintf("%-10s run: %s\n           certified as: %s\n", label, r, paste(unique(box$cert), collapse = ", ")))
}
run_one("sma_3", list(ledgr_ind_sma(3L)))
run_one("sma_5", list(ledgr_ind_sma(5L)))
run_one("return_1", list(ledgr_ind_returns(1L)))

# The same stored config, rebuilt with and without its stored fingerprint.
exp <- ledgr_experiment(snap, function(ctx, params) ctx$hold(), features = list(ledgr_ind_sma(3L)),
  opening = ledgr_opening(cash = 1e5), cost_model = ledgr_cost_zero())
invisible(tryCatch(close(ledgr_run(exp, run_id = "f6p5_cfg")), error = function(e) NULL))
cfg <- box$cfg
d_with <- o_cfg(cfg)[[1]]
cfg$features$defs[[1]]$fingerprint <- NULL
d_without <- o_cfg(cfg)[[1]]
cat("stored def fields:", paste(names(box$cfg$features$defs[[1]]), collapse = ","), "\n")
cat("with stored fingerprint -> certification:", o_cert(d_with)$certification, "\n")
cat("without stored fingerprint -> certification:", o_cert(d_without)$certification, "\n")
# Each rebuilt definition through preparation on the reviewer's substrate.
source(file.path(tree, "dev/feature_parity/corpus.R"))
sub <- fx_empty(ledgr_history_policy())
prep <- function(def) tryCatch({ ns$ledgr_history_compute_feature_series(sub, list(def)); "success" },
  error = function(e) class(e)[1])
cat("preparation, with stored fingerprint:", prep(d_with), "| without:", prep(d_without), "\n")
cat("done\n")
