# Protocol ws2-timing-1 (LDG-3156): workloads for the v0.2.3 cut 4 RNG gate.
# measure.R sources this file after loading the arm's ledgr, so it uses only
# ledgr's public API, identically in both arms. protocol.md explains it.
#
# Every cell is one workload, one public path and one seed state, passed as
# args path=run|sweep and seed_state=seeded|unseeded. The fixture builders
# below are the WS1 and A0 timing fixtures (dense_scale_50x1260 from
# dev/bench/v0_2_3_ws1_timing/matrix.R, timing_scale from
# dev/bench/v0_2_3_output_freeze/timing.R, retention from that directory's
# lib.R), copied here so the protocol's four files are its whole input.

# Deterministic sin-wave prices: n instruments x days sessions, no RNG.
ws2_bars <- function(n, days, start, prefix) {
  ids <- sprintf(prefix, seq_len(n))
  ts <- as.POSIXct(start, tz = "UTC") + 86400 * (seq_len(days) - 1L)
  do.call(rbind, lapply(seq_along(ids), function(j) {
    close <- 100 * exp(cumsum(0.01 * sin(seq_len(days) * (0.05 + j / 97) + j)))
    data.frame(instrument_id = ids[[j]], ts_utc = ts, open = close * 0.999, high = close * 1.01,
      low = close * 0.99, close = close, volume = 1e5, stringsAsFactors = FALSE)
  }))
}

# 50 x 1260, SMA(20), vectorised strategy, two candidates (qty 10, 20).
ws2_fx_dense_scale <- function(db_path) {
  snapshot <- ledgr_snapshot_from_df(ws2_bars(50L, 1260L, "2015-01-01", "I%03d"), db_path = db_path,
    snapshot_id = "ws1_dense_scale_50x1260")
  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    sma <- ctx$vec$feature("sma_20")
    up <- !is.na(sma) & ctx$vec$close > sma
    targets[ctx$universe[up]] <- params$qty
    targets
  }
  exp <- ledgr_experiment(snapshot, strategy, features = list(ledgr_ind_sma(20)),
    opening = ledgr_opening(cash = 1e7), cost_model = ledgr_cost_spread_bps(5))
  grid <- ledgr_grid_named(q10 = list(strategy = list(qty = 10)), q20 = list(strategy = list(qty = 20)))
  list(snapshot = snapshot, exp = exp, grid = grid, seed = 7L)
}

# 20 x 252, SMA(20), per-instrument scalar strategy, two candidates (qty 10, 20).
ws2_fx_timing_scale <- function(db_path) {
  snapshot <- ledgr_snapshot_from_df(ws2_bars(20L, 252L, "2019-01-01", "I%02d"), db_path = db_path,
    snapshot_id = "a0_timing_scale")
  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    for (id in ctx$universe) {
      sma <- ctx$feature(id, "sma_20")
      if (!is.na(sma) && ctx$close(id) > sma) targets[[id]] <- params$qty
    }
    targets
  }
  exp <- ledgr_experiment(snapshot, strategy, features = list(ledgr_ind_sma(20)),
    opening = ledgr_opening(cash = 1e6), cost_model = ledgr_cost_spread_bps(5))
  grid <- ledgr_grid_named(q10 = list(strategy = list(qty = 10)), q20 = list(strategy = list(qty = 20)))
  list(snapshot = snapshot, exp = exp, grid = grid, seed = 7L)
}

# 50 x 1260, the contract's stochastic recipe: a seed-required guard, then
# withr::with_seed(ctx$pulse_seed, sample.int(...)) on every pulse. When the
# book holds anything the target is flat; otherwise it buys exactly k drawn
# instruments. Every instrument has a bar every session, so the trade count
# is the same whichever instruments the pulse seed draws, under any pulse
# rule; the draws change only which instruments trade.
ws2_fx_stochastic <- function(db_path) {
  snapshot <- ledgr_snapshot_from_df(ws2_bars(50L, 1260L, "2015-01-01", "I%03d"), db_path = db_path,
    snapshot_id = "ws2_stochastic_50x1260")
  strategy <- function(ctx, params) {
    if (is.null(ctx$pulse_seed)) stop("this strategy needs `seed =`", call. = FALSE)
    pick <- withr::with_seed(ctx$pulse_seed, sample.int(length(ctx$universe), params$k))
    targets <- ctx$flat()
    if (any(ctx$hold() != 0)) return(targets)
    targets[ctx$universe[pick]] <- params$qty
    targets
  }
  exp <- ledgr_experiment(snapshot, strategy, opening = ledgr_opening(cash = 1e7),
    cost_model = ledgr_cost_spread_bps(5))
  grid <- ledgr_grid_named(k5 = list(strategy = list(k = 5L, qty = 10)), k10 = list(strategy = list(k = 10L, qty = 10)))
  list(snapshot = snapshot, exp = exp, grid = grid, seed = 11L)
}

# One measurement. Untimed preparation, identical in both arms and both
# paths, in the cell's seed state: a fresh snapshot, one sweep (which also
# supplies each candidate's params and, when seeded, its execution seed),
# one committed run per candidate, gc(). Then the timed path, `reps` times
# in one timed section (short cells repeat so the section lasts about 3 s or
# more). Clock endpoints, as.numeric(Sys.time()): immediately before the
# first ledgr_run() or ledgr_sweep() call of the first rep, immediately
# after the last close() or ledgr_sweep() return of the last rep. Retained
# surfaces: each run persisted in the snapshot's store under its own run_id
# per rep (no reader called); each in-memory sweep with completed returns
# and closed trades (not saved). Work: each candidate's status and trade
# count, which every rep must repeat exactly; anything but two DONE
# candidates with trades fails here.
ws2_measure <- function(fixture, args, work_dir) {
  reps <- suppressWarnings(as.integer(args$reps))
  if (!args$path %in% c("run", "sweep") || !args$seed_state %in% c("seeded", "unseeded") || !isTRUE(reps >= 1L)) {
    stop("bad cell args")
  }
  # The harness gives every slot a fresh, empty work directory, so a fixed
  # store name is unique to this slot.
  fx <- fixture(file.path(work_dir, "ws2.duckdb"))
  on.exit(ledgr_snapshot_close(fx$snapshot), add = TRUE)
  seeded <- identical(args$seed_state, "seeded")
  retain <- ledgr_sweep_retention(returns = "completed", trades = "closed")
  options(ledgr.interrupt = FALSE)
  sweep_path <- function() ledgr_sweep(fx$exp, fx$grid, seed = if (seeded) fx$seed else NULL, retain = retain)
  sw <- suppressWarnings(sweep_path())
  run_path <- function(tag) {
    for (i in seq_len(nrow(sw))) {
      close(suppressWarnings(ledgr_run(fx$exp, params = sw$params[[i]], feature_params = sw$feature_params[[i]],
        run_id = paste("ws2", tag, sw$candidate_id[[i]], sep = "-"),
        seed = if (seeded) sw$execution_seed[[i]] else NULL)))
    }
  }
  run_path("warm")
  invisible(gc())

  # Each rep's work as "status;status|trades;trades".
  work <- character(reps)
  if (identical(args$path, "run")) {
    t0 <- as.numeric(Sys.time())
    for (r in seq_len(reps)) run_path(paste0("timed", r))
    t1 <- as.numeric(Sys.time())
    runs <- as.data.frame(ledgr_run_list(fx$snapshot))
    for (r in seq_len(reps)) {
      hit <- match(paste("ws2", paste0("timed", r), sw$candidate_id, sep = "-"), runs$run_id)
      work[r] <- paste(paste(runs$status[hit], collapse = ";"), paste(runs$n_trades[hit], collapse = ";"), sep = "|")
    }
  } else {
    timed <- vector("list", reps)
    t0 <- as.numeric(Sys.time())
    for (r in seq_len(reps)) timed[[r]] <- suppressWarnings(sweep_path())
    t1 <- as.numeric(Sys.time())
    for (r in seq_len(reps)) {
      work[r] <- paste(paste(timed[[r]]$status, collapse = ";"), paste(timed[[r]]$n_trades, collapse = ";"), sep = "|")
    }
  }
  if (length(unique(work)) != 1L || !grepl("^DONE;DONE\\|[1-9][0-9]*;[1-9][0-9]*$", work[[1L]])) {
    stop(sprintf("expected every rep to give two DONE candidates with the same trades, got %s", paste(work, collapse = " / ")))
  }
  list(seconds = stats::setNames(t1 - t0, args$path), work = sprintf("%s x%d", work[[1L]], reps))
}

dense_scale_50x1260 <- function(args, work_dir) ws2_measure(ws2_fx_dense_scale, args, work_dir)
timing_scale <- function(args, work_dir) ws2_measure(ws2_fx_timing_scale, args, work_dir)
stochastic_50x1260 <- function(args, work_dir) {
  if (!identical(args$seed_state, "seeded")) stop("the stochastic workload is seeded only")
  ws2_measure(ws2_fx_stochastic, args, work_dir)
}
