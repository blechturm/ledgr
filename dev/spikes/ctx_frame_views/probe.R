# Probe: how much memory do the fold's precomputed per-pulse frame views hold,
# and can on-demand builders over the prepared primitives reproduce them exactly?
#
# Rscript dev/spikes/ctx_frame_views/probe.R <ledgr_repo> <out_dir> [sessions]
args <- commandArgs(TRUE)
repo <- normalizePath(args[[1L]], winslash = "/")
out_dir <- args[[2L]]
sessions <- if (length(args) >= 3L) as.integer(args[[3L]]) else 757L
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
suppressMessages(pkgload::load_all(repo, quiet = TRUE, compile = FALSE))
source(file.path(repo, "dev/bench/v0_2_2_long_window_regression/helpers.R"))
ns <- asNamespace("ledgr")

mb_used <- function() sum(gc(full = TRUE)[, 2L])
measure <- function(expr) {
  before <- mb_used(); value <- force(expr); after <- mb_used()
  list(value = value, mib = after - before)
}

# --- on-demand builders over the prepared primitives (the spike's one seam) --
bars_at <- function(bars_mat, ids, pulses_posix, i) {
  ns$ledgr_fast_data_frame(list(
    instrument_id = ids,
    ts_utc = as.POSIXct(rep(pulses_posix[[i]], length(ids)), tz = "UTC"),
    open = bars_mat$open[, i], high = bars_mat$high[, i], low = bars_mat$low[, i],
    close = bars_mat$close[, i], volume = bars_mat$volume[, i],
    gap_type = bars_mat$gap_type[, i], is_synthetic = bars_mat$is_synthetic[, i]
  ), length(ids))
}
wide_at <- function(projection, feature_ids, i) {
  ids <- names(projection$instrument_index)
  ns$ledgr_fast_data_frame(ns$ledgr_projection_features_wide_columns(
    projection, i, feature_ids, ids, unname(projection$feature_values[feature_ids])
  ), length(ids))
}

capture <- new.env()
trace("ledgr_execute_fold", where = ns, print = FALSE,
      tracer = quote(assign("execution", execution, envir = capture)))

probe_run <- function(label, exp) {
  gc(reset = TRUE, full = TRUE)
  bt <- ledgr_run(exp, run_id = paste0("probe_", label))
  peak_r_mib <- sum(gc(full = TRUE)[, 6L])
  status <- ledgr_run_info(exp$snapshot, bt$run_id)$status
  close(bt)
  spec <- capture$execution
  ids <- spec$instrument_ids; P <- length(spec$pulses_posix)
  def_ids <- vapply(spec$feature_defs, function(d) d$id, character(1))
  bars_views <- measure(ns$ledgr_bars_pulse_views(spec$bars_mat, ids, spec$pulses_posix))
  feat_views <- measure(ns$ledgr_projection_pulse_views(spec$runtime_projection, feature_ids = def_ids))
  bars_ok <- all(vapply(seq_len(P), function(i) {
    identical(bars_at(spec$bars_mat, ids, spec$pulses_posix, i), bars_views$value[[i]])
  }, logical(1)))
  wide_ok <- all(vapply(seq_len(P), function(i) {
    identical(wide_at(spec$runtime_projection, def_ids, i), feat_views$value$features_wide[[i]])
  }, logical(1)))
  table_shared <- length(unique(lapply(feat_views$value$feature_table, nrow))) == 1L &&
    nrow(feat_views$value$feature_table[[1L]]) == 0L
  i <- P %/% 2L
  t_lookup <- summary(microbenchmark::microbenchmark(bars_views$value[[i]], times = 500L, unit = "us"))$median
  t_bars <- summary(microbenchmark::microbenchmark(bars_at(spec$bars_mat, ids, spec$pulses_posix, i), times = 500L, unit = "us"))$median
  t_wide <- summary(microbenchmark::microbenchmark(wide_at(spec$runtime_projection, def_ids, i), times = 500L, unit = "us"))$median
  data.frame(
    label = label, status = status, instruments = length(ids), pulses = P,
    features = length(def_ids), peak_r_heap_mib = round(peak_r_mib, 1),
    bars_views_mib = round(bars_views$mib, 1),
    feature_views_mib = round(feat_views$mib, 1),
    bars_mat_mib = round(as.numeric(object.size(spec$bars_mat)) / 2^20, 1),
    projection_mib = round(as.numeric(object.size(spec$runtime_projection)) / 2^20, 1),
    views_share_of_r_peak = round((bars_views$mib + feat_views$mib) / peak_r_mib, 3),
    feature_table_is_empty_schema = table_shared,
    on_demand_bars_identical_all_pulses = bars_ok,
    on_demand_wide_identical_all_pulses = wide_ok,
    lookup_us = round(t_lookup, 2), on_demand_bars_us = round(t_bars, 2),
    on_demand_wide_us = round(t_wide, 2),
    on_demand_ms_per_run = round((t_bars + t_wide) * P / 1000, 1),
    stringsAsFactors = FALSE
  )
}

# Availability: the WS11 orientation shape (600 instruments, 500 members, monthly
# top-10 momentum on three returns features, read through ctx$vec).
row <- data.frame(shape_id = "probe_avail", profile = "orientation", mode = "run",
  sessions = sessions, instruments = 600L, members = 500L, sets = 12L, churn = 0.02,
  terminals = 0L, terminal_ownership = "none", gap_pattern = "none", stale_budget = 2L,
  features = "returns_63+returns_126+returns_252", strategy = "momentum",
  expected_status = "DONE", stringsAsFactors = FALSE)
lwreg_build_fixture(row, file.path(out_dir, "avail"))
snap <- ledgr_snapshot_open(file.path(out_dir, "avail", "snapshot.duckdb"))
ledgr_feature_cache_clear()
avail <- probe_run("availability", lwreg_experiment(snap, row))

# Dense: the same bars without facts; the strategy reads ctx$features_wide on
# every pulse, the worst case for removing the prepared wide views.
con <- DBI::dbConnect(duckdb::duckdb(), file.path(out_dir, "avail", "snapshot.duckdb"), read_only = TRUE)
bars <- DBI::dbGetQuery(con, "SELECT ts_utc, instrument_id, open, high, low, close, volume FROM snapshot_bars ORDER BY instrument_id, ts_utc")
DBI::dbDisconnect(con, shutdown = TRUE)
ledgr_snapshot_close(snap)
dense_snap <- ledgr_snapshot_from_df(bars, db_path = file.path(out_dir, "dense.duckdb"), snapshot_id = "probe_dense")
wide_reader <- function(ctx, params) {
  wide <- ctx$features_wide
  targets <- ctx$flat()
  score <- wide$return_252
  if (sum(is.finite(score)) >= 20L && identical(format(ledgr_utc(ctx$ts_utc), "%d", tz = "UTC") <= "07", TRUE)) {
    top <- wide$instrument_id[order(-score, na.last = NA)[1:10]]
    targets[top] <- floor(0.09 * ctx$equity / ctx$vec$close[match(top, ctx$vec$id)])
    return(targets)
  }
  ctx$hold()
}
dense_exp <- ledgr_experiment(dense_snap, wide_reader,
  features = list(ledgr_ind_returns(63), ledgr_ind_returns(126), ledgr_ind_returns(252)),
  cost_model = ledgr_cost_zero(), opening = ledgr_opening(cash = 1e6), persist_features = FALSE)
ledgr_feature_cache_clear()
dense <- probe_run("dense_wide_reader", dense_exp)
ledgr_snapshot_close(dense_snap)

out <- rbind(avail, dense)
utils::write.csv(out, file.path(out_dir, "probe.csv"), row.names = FALSE)
print(t(out))
