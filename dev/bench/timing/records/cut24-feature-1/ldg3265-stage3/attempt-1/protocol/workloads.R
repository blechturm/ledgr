# Cut 24 (decision 3): the feature path, base against candidate, each arm its
# own installed package, no overlay. Three workloads, all timing complete
# preparations back to back after one untimed warm-up and a full gc():
#
#   cut24_feature    Cut 22's feature cells (cut22-feature-1, same fixture,
#                    definitions and clock): run = engine version +
#                    ledgr_history_compute_feature_series() + projection;
#                    sweep = ledgr_history_precompute_payload() + projection
#                    with the engine version.
#   cut24_certify    the certification clock: ledgr_feature_certify() over
#                    the run (TTR SMA 5, 10) or sweep (TTR SMA 3, 5, 8, 12,
#                    20, 40) definition set; no substrate.
#   cut24_admission  the four admission workloads of decision 3, on the run
#                    or sweep preparation sequence:
#                    custom  custom-only on the 500 x 1,260 Cut 22 fixture: a
#                            close-returning series_fn with its matching fn,
#                            requires_bars 1, required_fields close;
#                    zero    certified (Cut 22's SMA sets) on 500 x 1,260 with
#                            declared sessions and price_carry 2, one middle
#                            session's bar removed from every instrument (the
#                            session stays expected);
#                    low     as zero, but the first five instruments keep
#                            that bar (5 of 500 complete);
#                    pit     the simulated PIT panel of
#                            dev/spikes/feature_stage23_probe/gate_count.R
#                            (200 instruments, 2019-01-01..2020-12-31, seed
#                            20261118, price_carry 2, output_carry 2) with
#                            Cut 22's SMA sets.
#
# Every workload takes debug=0|1 (decision 6) and sets the arm's internal
# debug flag explicitly through its local setter; an arm without the flag
# (the cut base) runs only debug=0. Production timings use debug=0.
# The work string is the workload, its arguments, reps, the definition count,
# debug and a digest of the logical result (the projection with the declared
# engine marker removed, or the certification outcomes).

cut24_sha <- function(x) substr(digest::digest(serialize(x, NULL, version = 2L), algo = "sha256", serialize = FALSE), 1L, 16L)

cut24_debug <- function(ns, args, frame) {
  value <- identical(args$debug, "1")
  if (!args$debug %in% c("0", "1")) stop("cut24-feature-1: debug must be 0 or 1")
  if (exists("local_ledgr_debug", envir = ns, inherits = FALSE)) {
    ns$local_ledgr_debug(value, frame = frame)
  } else if (value) {
    stop("cut24-feature-1: this arm has no debug flag; only debug=0 is valid")
  }
  if (value) "1" else "0"
}

cut24_bars <- function(n_inst, n_axis) {
  bars <- ledgr::ledgr_sim_bars(n_inst, n_axis, seed = 20260530L, start = "2020-01-01", instrument_prefix = "P")
  bars$ts_utc <- bars$ts_utc + 21 * 3600
  for (name in c("open", "high", "low", "close", "volume")) bars[[name]] <- round(bars[[name]], 8L)
  bars[order(bars$instrument_id, bars$ts_utc, method = "radix"), ]
}

cut24_sma_defs <- function(ns, path) {
  widths <- if (identical(path, "run")) c(5, 10) else c(3, 5, 8, 12, 20, 40)
  lapply(widths, function(n) ns$ledgr_precompute_feature_def_from_indicator(
    ledgr::ledgr_ind_ttr("SMA", input = "close", id = paste0("sma_", n), n = as.integer(n))))
}

cut24_custom_defs <- function(ns) {
  ind <- ledgr::ledgr_indicator(
    id = "custom_close",
    fn = function(window) as.numeric(window$close[[nrow(window)]]),
    series_fn = function(bars, params) as.numeric(bars$close),
    requires_bars = 1L, required_fields = "close")
  list(ns$ledgr_precompute_feature_def_from_indicator(ind))
}

# The bar-native Cut 22 fixture (sealed snapshot, experiment, substrate).
cut24_bar_native <- function(shape, work_dir, ns) {
  dims <- as.integer(strsplit(shape, "x", fixed = TRUE)[[1L]])
  store <- file.path(work_dir, "store.duckdb")
  ledgr::ledgr_snapshot_close(ledgr::ledgr_snapshot_from_df(cut24_bars(dims[[1L]], dims[[2L]]), db_path = store,
    snapshot_id = "cut24", price_basis = "split_adjusted"))
  snapshot <- ledgr::ledgr_snapshot_open(store, "cut24", verify = TRUE)
  exp <- ledgr::ledgr_experiment(snapshot, function(ctx, params) ctx$hold(),
    features = list(ledgr::ledgr_ind_sma(3)), opening = ledgr::ledgr_opening(cash = 1e7),
    cost_model = ledgr::ledgr_cost_zero())
  list(snapshot = snapshot, substrate = ns$ledgr_history_substrate_for_experiment(exp))
}

# Declared sessions on the dense 500 x 1,260 bars with one middle session's
# bar removed from every instrument but the first `keep` (decision 3 b, c).
cut24_gap_substrate <- function(ns, keep) {
  bars <- cut24_bars(500L, 1260L)
  axis <- sort(unique(bars$ts_utc))
  ids <- sort(unique(bars$instrument_id))
  gap <- axis[[630L]]
  bars <- bars[!(bars$ts_utc == gap & !(bars$instrument_id %in% ids[seq_len(keep)])), , drop = FALSE]
  sessions <- data.frame(venue_id = "V", session_date = as.Date(axis), status = "open",
                         session_open = axis - 6 * 3600, session_close = axis,
                         knowledge_time = axis - 6 * 3600, stringsAsFactors = FALSE)
  data <- list(families = data.frame(family = "sessions", stringsAsFactors = FALSE), lifetime = NULL,
               sessions = sessions)
  config <- list(universe = list(instrument_ids = ids),
                 availability = list(universe_rule = NULL, valuation_policy = unclass(ledgr::ledgr_valuation_stale())),
                 history_policy = ledgr::ledgr_history_policy(price_carry = 2L))
  ns$ledgr_history_substrate(bars = bars[c("instrument_id", "ts_utc", "open", "high", "low", "close", "volume")],
    instrument_ids = ids, axis = axis, availability_data = data, availability_config = config,
    snapshot_hash = paste0("cut24-gap-keep", keep))
}

# The simulated PIT panel exactly as feature_stage23_probe/gate_count.R.
cut24_pit <- function(work_dir, ns) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
  pit <- ledgr::ledgr_sim_pit_inputs(sprintf("S%03d", seq_len(200L)), "2019-01-01", "2020-12-31", seed = 20261118L)
  facts <- ledgr::ledgr_facts(
    ledgr::ledgr_facts_sessions(pit$sessions, venue_id = pit$recipe$venue_id %||% "DEMO_VENUE", knowledge = "evidenced"),
    ledgr::ledgr_facts_membership_snapshots(pit$membership, universe_id = pit$recipe$universe_id %||% "DEMO_UNIVERSE",
                                            complete = TRUE, knowledge = "evidenced"),
    ledgr::ledgr_facts_trading_status(pit$trading_status, knowledge = "evidenced"),
    ledgr::ledgr_facts_lifetime(pit$lifetime, knowledge = "evidenced"))
  snapshot <- ledgr::ledgr_snapshot_from_df(pit$bars, pit$instruments, db_path = file.path(work_dir, "pit.duckdb"),
                                            facts = facts, price_basis = "split_adjusted")
  exp <- ledgr::ledgr_experiment(snapshot, function(ctx, params) ctx$hold(),
    universe = ledgr::ledgr_universe_members(pit$recipe$universe_id %||% "DEMO_UNIVERSE"),
    features = list(ledgr::ledgr_ind_sma(3)), valuation_policy = ledgr::ledgr_valuation_stale(3),
    cost_model = ledgr::ledgr_cost_zero(), opening = ledgr::ledgr_opening(cash = 1e6),
    history_policy = ledgr::ledgr_history_policy(price_carry = 2L, output_carry = 2L))
  list(snapshot = snapshot, substrate = ns$ledgr_history_substrate_for_experiment(exp))
}

# One preparation on the run or sweep sequence, as the package performs it.
cut24_prepare <- function(ns, path, sub, defs) {
  start <- ns$ledgr_history_calculation_start(sub)
  end <- sub$axis[[length(sub$axis)]]
  if (identical(path, "run")) {
    named <- stats::setNames(defs, vapply(defs, function(d) d$id, ""))
    function() {
      version <- ns$ledgr_feature_engine_version()
      m <- ns$ledgr_history_compute_feature_series(substrate = sub, definitions = named,
        calculation_start = start, calculation_end = end)
      ns$ledgr_projection_from_feature_matrix(feature_matrix = m, universe = sub$instrument_ids,
        pulses_posix = sub$axis, feature_engine_version = version, alias_index = NULL)
    }
  } else if (identical(path, "sweep")) {
    named <- stats::setNames(defs, vapply(defs, ns$ledgr_feature_def_fingerprint, ""))
    function() {
      payload <- ns$ledgr_history_precompute_payload(named, sub, calculation_start = start, calculation_end = end)
      ns$ledgr_projection_from_payload(payload = payload, universe = sub$instrument_ids,
        pulses_posix = sub$axis, feature_engine_version = ns$ledgr_feature_engine_version(), alias_index = NULL)
    }
  } else {
    stop("cut24-feature-1: unknown path ", path)
  }
}

cut24_time <- function(prepare, reps) {
  result <- prepare()                       # warm-up, outside the clock
  invisible(gc(FALSE))
  t0 <- as.numeric(Sys.time())
  for (i in seq_len(reps)) prepare()
  list(seconds = as.numeric(Sys.time()) - t0, result = result)
}

cut24_logical <- function(projection) {
  logical <- unclass(projection)
  logical$feature_engine_version <- NULL
  cut24_sha(logical)
}

cut24_feature <- function(args, work_dir) {
  ns <- asNamespace("ledgr")
  debug <- cut24_debug(ns, args, environment())
  fx <- cut24_bar_native(args$shape, work_dir, ns)
  on.exit(ledgr::ledgr_snapshot_close(fx$snapshot), add = TRUE)
  defs <- cut24_sma_defs(ns, args$path)
  t <- cut24_time(cut24_prepare(ns, args$path, fx$substrate, defs), as.integer(args$reps))
  list(seconds = c(feature = t$seconds),
       work = paste("feature", args$shape, args$path, args$reps, length(defs), debug, cut24_logical(t$result), sep = "|"))
}

cut24_certify <- function(args, work_dir) {
  ns <- asNamespace("ledgr")
  debug <- cut24_debug(ns, args, environment())
  defs <- cut24_sma_defs(ns, args$path)
  certify <- function() lapply(defs, ns$ledgr_feature_certify)
  t <- cut24_time(certify, as.integer(args$reps))
  outcome <- lapply(t$result, function(cert) list(cert$certification, cert$kind, cert$def$fingerprint,
                                                  cert$declarations))
  list(seconds = c(certify = t$seconds),
       work = paste("certify", args$path, args$reps, length(defs), debug, cut24_sha(outcome), sep = "|"))
}

cut24_admission <- function(args, work_dir) {
  ns <- asNamespace("ledgr")
  debug <- cut24_debug(ns, args, environment())
  fx <- switch(args$case,
    custom = cut24_bar_native("500x1260", work_dir, ns),
    zero = list(snapshot = NULL, substrate = cut24_gap_substrate(ns, keep = 0L)),
    low = list(snapshot = NULL, substrate = cut24_gap_substrate(ns, keep = 5L)),
    pit = cut24_pit(work_dir, ns),
    stop("cut24-feature-1: unknown admission case ", args$case))
  if (!is.null(fx$snapshot)) on.exit(ledgr::ledgr_snapshot_close(fx$snapshot), add = TRUE)
  defs <- if (identical(args$case, "custom")) cut24_custom_defs(ns) else cut24_sma_defs(ns, args$path)
  t <- cut24_time(cut24_prepare(ns, args$path, fx$substrate, defs), as.integer(args$reps))
  list(seconds = c(feature = t$seconds),
       work = paste("admission", args$case, args$path, args$reps, length(defs), debug, cut24_logical(t$result), sep = "|"))
}
