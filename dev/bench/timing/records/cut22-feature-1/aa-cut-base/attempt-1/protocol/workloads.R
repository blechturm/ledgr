# Cut 22 (decision 3a): the feature path, base against candidate, each arm
# its own installed package, no overlay. The fixture is built inside the slot
# from ledgr_sim_bars() (the r_floor shape, dev/spikes/r_floor/fixture.R) and
# sealed in the slot's work directory, outside the clock.
#
#   feature  wall time (Sys.time) of `reps` back-to-back feature preparations
#            after one untimed warm-up and a full gc(); each preparation is
#            the package's own call sequence, the engine version included:
#     run    ledgr_feature_engine_version(),
#            ledgr_history_compute_feature_series() on the experiment's
#            definitions named by ID, ledgr_projection_from_feature_matrix()
#            (R/backtest-runner.R, ledgr_run_fold_impl);
#     sweep  ledgr_history_precompute_payload() on the unique definitions
#            named by fingerprint, ledgr_projection_from_payload() with
#            ledgr_feature_engine_version() (R/sweep.R, implicit sweep).
#            Run: TTR SMA 5 and 10 (the published crossover). Sweep: TTR SMA
#            3, 5, 8, 12, 20 and 40 (the sweep map's union).
# The work string is the shape, path, reps and a digest of the logical result:
# the projection's matrices, indexed planes, instrument and pulse indexes and
# formatted axis, with the declared engine marker removed (decision 3a); the
# payload's physical shape is not part of it.

cut22_sha <- function(x) substr(digest::digest(serialize(x, NULL, version = 2L), algo = "sha256", serialize = FALSE), 1L, 16L)

cut22_fixture <- function(shape, work_dir, widths) {
  dims <- as.integer(strsplit(shape, "x", fixed = TRUE)[[1L]])
  bars <- ledgr::ledgr_sim_bars(dims[[1L]], dims[[2L]], seed = 20260530L, start = "2020-01-01",
                                instrument_prefix = "P")
  bars$ts_utc <- bars$ts_utc + 21 * 3600
  for (name in c("open", "high", "low", "close", "volume")) bars[[name]] <- round(bars[[name]], 8L)
  bars <- bars[order(bars$instrument_id, bars$ts_utc, method = "radix"), ]
  store <- file.path(work_dir, "store.duckdb")
  ledgr::ledgr_snapshot_close(ledgr::ledgr_snapshot_from_df(bars, db_path = store, snapshot_id = "cut22",
                                                            price_basis = "split_adjusted"))
  snapshot <- ledgr::ledgr_snapshot_open(store, "cut22", verify = TRUE)
  sma <- function(n) ledgr::ledgr_ind_ttr("SMA", input = "close", id = paste0("sma_", n), n = as.integer(n))
  exp <- ledgr::ledgr_experiment(snapshot, function(ctx, params) ctx$hold(),
    features = do.call(ledgr::ledgr_feature_map, stats::setNames(lapply(widths, sma), paste0("sma_", widths))),
    opening = ledgr::ledgr_opening(cash = 1e7), cost_model = ledgr::ledgr_cost_zero())
  ns <- asNamespace("ledgr")
  substrate <- ns$ledgr_history_substrate_for_experiment(exp)
  defs <- ns$ledgr_precompute_feature_defs_from_indicators(
    ns$ledgr_experiment_materialize_feature_result(exp, params = list(), feature_params = list())$features)
  list(snapshot = snapshot, substrate = substrate, defs = defs, ns = ns,
       start = ns$ledgr_history_calculation_start(substrate), end = substrate$axis[[length(substrate$axis)]])
}

cut22_feature <- function(args, work_dir) {
  path <- args$path
  reps <- as.integer(args$reps)
  widths <- if (identical(path, "run")) c(5, 10) else c(3, 5, 8, 12, 20, 40)
  fx <- cut22_fixture(args$shape, work_dir, widths)
  on.exit(ledgr::ledgr_snapshot_close(fx$snapshot), add = TRUE)
  ns <- fx$ns
  sub <- fx$substrate
  prepare <- if (identical(path, "run")) {
    defs <- stats::setNames(fx$defs, vapply(fx$defs, function(d) d$id, ""))
    function() {
      version <- ns$ledgr_feature_engine_version()
      m <- ns$ledgr_history_compute_feature_series(substrate = sub, definitions = defs,
        calculation_start = fx$start, calculation_end = fx$end)
      ns$ledgr_projection_from_feature_matrix(feature_matrix = m, universe = sub$instrument_ids,
        pulses_posix = sub$axis, feature_engine_version = version, alias_index = NULL)
    }
  } else if (identical(path, "sweep")) {
    defs <- stats::setNames(fx$defs, vapply(fx$defs, ns$ledgr_feature_def_fingerprint, ""))
    function() {
      payload <- ns$ledgr_history_precompute_payload(defs, sub, calculation_start = fx$start,
                                                     calculation_end = fx$end)
      ns$ledgr_projection_from_payload(payload = payload, universe = sub$instrument_ids,
        pulses_posix = sub$axis, feature_engine_version = ns$ledgr_feature_engine_version(), alias_index = NULL)
    }
  } else {
    stop("cut22-feature-1: unknown path ", path)
  }
  projection <- prepare()                   # warm-up, outside the clock
  invisible(gc(FALSE))
  t0 <- as.numeric(Sys.time())
  for (i in seq_len(reps)) prepare()
  feature_s <- as.numeric(Sys.time()) - t0
  logical <- unclass(projection)
  logical$feature_engine_version <- NULL
  list(seconds = c(feature = feature_s),
       work = paste(args$shape, path, reps, length(fx$defs), cut22_sha(logical), sep = "|"))
}
