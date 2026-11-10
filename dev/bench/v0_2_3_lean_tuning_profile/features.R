# Feature-cost split before any feature design: the pin's feature series
# (ledgr_history_compute_feature_series, as a committed run calls it)
# against the bare per-instrument TTR calls a PMwR-style harness makes
# (apply(close, 2, TTR::SMA)) on the same close matrix, for SMA 5 and 10.
# Medians of `reps` timings after one warm call; both must give the same
# values where ledgr's series is calculated.
#
#   Rscript dev/bench/v0_2_3_lean_tuning_profile/features.R --lib=<pinned library>
#     --shapes=crossover_10x7200,crossover_500x1260,crossover_1166x252 --reps=5 --out=<csv>

arg <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), commandArgs(TRUE), value = TRUE)
  if (!length(hit)) { if (is.null(default)) stop("--", name, "= is required", call. = FALSE); return(default) }
  sub(paste0("^--", name, "="), "", hit[[1L]])
}
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
repo <- normalizePath(file.path(here, "..", "..", ".."), winslash = "/")
source(file.path(repo, "dev/lean_core/load.R"))
lean <- lean_core_load(arg("lib"))
ns <- asNamespace("ledgr")
source(file.path(repo, "dev/spikes/r_floor/fixture.R"))
shapes <- strsplit(arg("shapes", "crossover_10x7200,crossover_500x1260,crossover_1166x252"), ",")[[1L]]
reps <- as.integer(arg("reps", "5"))
work <- file.path(tempdir(), "feature_split")
dir.create(work, showWarnings = FALSE)
now <- function() proc.time()[["elapsed"]]
timed <- function(f) { f(); stats::median(vapply(seq_len(reps), function(r) { t0 <- now(); f(); now() - t0 }, 0)) }

rows <- list()
for (shape in shapes) {
  dims <- as.integer(strsplit(sub("^crossover_", "", shape), "x")[[1L]])
  db <- file.path(work, paste0(shape, ".duckdb"))
  if (file.exists(db)) unlink(db)
  ledgr::ledgr_snapshot_close(ledgr::ledgr_snapshot_from_df(r_floor_fixture(dims[[1L]], dims[[2L]])$bars,
    db_path = db, snapshot_id = "p", price_basis = "split_adjusted"))
  snapshot <- ledgr::ledgr_snapshot_open(db, "p", verify = TRUE)
  exp <- ledgr::ledgr_experiment(snapshot, function(ctx, params) ctx$hold(),
    features = ledgr::ledgr_feature_map(
      fast = ledgr::ledgr_ind_ttr("SMA", input = "close", id = "fast", n = 5L),
      slow = ledgr::ledgr_ind_ttr("SMA", input = "close", id = "slow", n = 10L)),
    opening = ledgr::ledgr_opening(cash = 1e7), cost_model = ledgr::ledgr_cost_zero())
  substrate <- ns$ledgr_history_substrate_for_experiment(exp)
  defs <- ns$ledgr_experiment_materialize_feature_result(exp, params = list(), feature_params = list())$features
  defs <- lapply(defs, function(d) if (inherits(d, "ledgr_indicator")) ns$ledgr_precompute_feature_def_from_indicator(d) else d)
  names(defs) <- vapply(defs, function(d) d$id, "")
  start <- ns$ledgr_history_calculation_start(substrate)
  ledgr_s <- timed(function() ns$ledgr_history_compute_feature_series(substrate, defs, calculation_start = start))
  close <- t(substrate$bars$close)            # sessions x instruments
  ttr_s <- timed(function() { apply(close, 2L, TTR::SMA, n = 5L); apply(close, 2L, TTR::SMA, n = 10L) })
  series <- ns$ledgr_history_compute_feature_series(substrate, defs, calculation_start = start)
  fast <- t(apply(close, 2L, TTR::SMA, n = 5L))
  same <- isTRUE(all(series[["fast"]] == fast | (is.na(series[["fast"]]) & is.na(fast)), na.rm = FALSE))
  ledgr::ledgr_snapshot_close(snapshot)
  rows[[shape]] <- data.frame(shape = shape, instruments = dims[[1L]], sessions = dims[[2L]],
    ledgr_s = round(ledgr_s, 3), ttr_only_s = round(ttr_s, 3), machinery_s = round(ledgr_s - ttr_s, 3),
    ledgr_us_per_instrument = round(1e6 * ledgr_s / dims[[1L]]), ttr_us_per_instrument = round(1e6 * ttr_s / dims[[1L]]),
    values_identical = same, stringsAsFactors = FALSE)
  print(rows[[shape]])
}
utils::write.csv(do.call(rbind, rows), arg("out"), row.names = FALSE)
