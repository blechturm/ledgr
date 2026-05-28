# spike-feature-payload-dps.R
#
# High-dimensional feature-payload throughput spike for ledgr.
#
# PURPOSE
#   Measure ledgr's fold-core throughput (Pulses/sec and Data Points Per Second,
#   "DPS") under a wide feature payload, and quantify the resident-memory ceiling
#   of the current R-memory-backed runtime_projection. This is the empirical
#   baseline for the v0.1.8.6 DuckDB-backed feature-storage / out-of-core
#   projection decision (horizon: "feature payload scale and indicator-width
#   stress").
#
# WHAT THIS MEASURES (and what it does NOT)
#   * It exercises the REAL public path: features are declared indicators
#     computed via series_fn, materialized into the runtime_projection up front,
#     then read every pulse through the fast-context wide view. No external data
#     injection, no CSV in the hot loop, no causal-boundary violation.
#   * series_fn values are cheap deterministic functions of `close`. For a
#     THROUGHPUT benchmark the feature *values* are irrelevant; computing from
#     bars is contract-safe (series_fn is only guaranteed ts_utc + close),
#     causal (own-instrument bars only), and avoids holding a large external
#     array. It is NOT a measurement of external-data I/O cost (that is the
#     deferred v0.2.x PIT-regressor work).
#   * t_loop is ledgr's R fold-loop time. ledgr runs an interpreted R strategy
#     per pulse, so DPS will sit far below a compiled C#/Rust engine
#     (QuantConnect, Nautilus). The value here is the ledgr baseline and the
#     SCALING SHAPE, not parity with compiled engines.
#
# MEMORY CEILING (the critical takeaway)
#   The runtime_projection is strictly R-memory-backed today. Feature payload
#   memory scales linearly: n_inst * n_pulses * n_feat * 8 bytes. At
#   500 x 2520 x 50 that is ~504 MB for the feature matrices alone; with the
#   bars matrices and the transient per-instrument build form, peak R session
#   memory reaches ~1-1.5 GB BEFORE the loop runs. project_memory() below prints
#   the scaling table so you can see where larger universes / wider payloads
#   cross your machine's RAM ceiling. Run it before committing to a large grid.
#
# HOW TO RUN
#   Rscript dev/spikes/spike-feature-payload-dps.R
#   # or, interactively, after pkgload::load_all() / library(ledgr):
#   source("dev/spikes/spike-feature-payload-dps.R"); print(spike_main())
#
# NOTE: this reads one internal accessor, ledgr:::ledgr_get_run_telemetry(),
# to obtain the fold-loop time t_loop. That is intentional and isolated to the
# instrumentation; the benchmark itself uses only the public API.

suppressWarnings(suppressMessages({
  # Prefer SOURCE over any installed build. Benchmarking a dev branch against a
  # stale installed package silently measures the wrong code: an installed
  # v0.1.8.0 was once profiled instead of the v0.1.8.5 source, inflating results
  # ~4x and inventing a bottleneck the source had already fixed. When the ledgr
  # package source tree is present, always load_all the source.
  .desc_is_ledgr <- file.exists("DESCRIPTION") &&
    identical(unname(read.dcf("DESCRIPTION")[1, "Package"]), "ledgr")
  if (requireNamespace("pkgload", quietly = TRUE) && .desc_is_ledgr) {
    pkgload::load_all(".", quiet = TRUE)
  } else if (requireNamespace("ledgr", quietly = TRUE)) {
    library(ledgr)
  } else {
    stop("ledgr must be installed, or run from the package root so pkgload::load_all() can load source.")
  }
}))

# Announce the loaded build and HARD-FAIL on a stale install vs source mismatch,
# so the stale-build trap cannot recur silently.
local({
  loaded <- as.character(utils::packageVersion("ledgr"))
  src <- if (file.exists("DESCRIPTION")) unname(read.dcf("DESCRIPTION")[1, "Version"]) else NA_character_
  if (!is.na(src) && !identical(src, loaded)) {
    stop(sprintf(
      "Stale ledgr: loaded build is %s but source DESCRIPTION is %s. Benchmark source via pkgload::load_all('.').",
      loaded, src
    ))
  }
  message(sprintf("[spike] benchmarking ledgr %s", loaded))
})

# --- Config -----------------------------------------------------------------

DEFAULT_CONFIG <- list(
  n_inst   = 500L,
  n_days   = 2520L,   # ~10y EOD
  n_feat   = 50L,
  iters    = 3L,      # measured iterations (median of t_loop) to damp GC noise
  trade    = TRUE     # TRUE: full loop incl. fill resolution; FALSE: score-only
)

# --- Data: dense aligned OHLCV panel ----------------------------------------
# The run path requires a dense panel (every instrument a bar at every pulse);
# OHLC are kept equal so the example is about throughput, not price dynamics.

make_panel <- function(n_inst, n_days,
                       start = as.POSIXct("2014-01-01", tz = "UTC")) {
  ids <- sprintf("INST_%03d", seq_len(n_inst))
  ts  <- start + (seq_len(n_days) - 1L) * 86400
  px  <- 100 + (seq_len(n_inst * n_days) %% 37L)  # cheap deterministic walk
  data.frame(
    instrument_id = rep(ids, each = n_days),
    ts_utc        = rep(ts, times = n_inst),
    open = px, high = px, low = px, close = px, volume = 1,
    stringsAsFactors = FALSE
  )
}

# --- Features: n_feat cheap series_fn indicators -----------------------------
# Each series_fn returns a numeric vector aligned to its instrument's bars,
# computed from `close`. No external state; passes indicator purity/safety.

make_features <- function(n_feat) {
  lapply(seq_len(n_feat), function(i) {
    force(i)
    ledgr_indicator(
      id            = sprintf("fund_%02d", i),
      fn            = function(window) tail(window$close, 1),  # unused on series path
      requires_bars = 1L,
      series_fn     = function(bars, params) bars$close * (i * 1e-3) + i
    )
  })
}

# --- Strategy: read all features for all instruments per pulse ---------------
# FEATURE_COLS / TRADE are bound in the closure (resolved -> Tier 2, allowed).
# One bulk .rowSums per pulse over the prebuilt fast-context wide view; this
# replaces n_inst * n_feat scalar ctx$feature() dispatch calls.

make_strategy <- function(n_feat, trade = TRUE) {
  FEATURE_COLS <- sprintf("fund_%02d", seq_len(n_feat))
  TRADE <- isTRUE(trade)
  function(ctx, params) {
    fw    <- ctx$features_wide                          # 1 list index, no dispatch
    score <- .rowSums(as.matrix(fw[FEATURE_COLS]),      # 1 bulk reduction
                      m = nrow(fw), n = length(FEATURE_COLS))
    targets <- ctx$flat()                               # full dense universe
    if (TRADE) {
      # Light, stable target: long the single top-scoring name. This keeps the
      # loop FEATURE-READ dominated (the payload under test) instead of
      # fill-churn dominated. A `score > median(score)` rule would instead
      # emit ~n_inst/2 fills per pulse and turn this into a fill-path stress.
      targets[[fw$instrument_id[[which.max(score)]]]] <- params$qty
    }
    targets
  }
}

# --- Instrumentation: clean fold-loop time (t_loop) --------------------------
# Returns ledgr's pure fold-loop seconds (loop start -> loop end), excluding
# t_pre feature materialization, post-run reconstruction, and the R wrapper.

read_fold_telemetry <- function(run_id) {
  tel <- tryCatch(ledgr:::ledgr_get_run_telemetry(run_id), error = function(e) NULL)
  pick <- function(x) if (is.null(x) || !is.finite(x)) NA_real_ else as.numeric(x)
  list(
    t_pre  = if (is.null(tel)) NA_real_ else pick(tel$t_pre),
    t_loop = if (is.null(tel)) NA_real_ else pick(tel$t_loop)
  )
}

# --- Memory projection (matches the scaler widget) ---------------------------
# Linear feature-matrix term plus a rough whole-session multiplier. The
# empirical gc() peak from a real run calibrates the multiplier.

project_memory <- function(insts    = c(500, 1000, 2000),
                           feats    = c(50, 100, 200),
                           n_days   = 2520,
                           overhead = 2.5) {
  grid <- expand.grid(instruments = insts, features = feats)
  grid$feature_matrix_gb <- grid$instruments * n_days * grid$features * 8 / 1e9
  grid$est_peak_gb       <- round(grid$feature_matrix_gb * overhead, 2)
  grid$feature_matrix_gb <- round(grid$feature_matrix_gb, 2)
  grid[order(grid$instruments, grid$features), c(
    "instruments", "features", "feature_matrix_gb", "est_peak_gb"
  )]
}

# --- Benchmark harness -------------------------------------------------------

run_benchmark <- function(cfg = DEFAULT_CONFIG) {
  bars  <- make_panel(cfg$n_inst, cfg$n_days)
  feats <- make_features(cfg$n_feat)
  strat <- make_strategy(cfg$n_feat, trade = cfg$trade)

  tag <- sprintf("bench_%d_%d_%d", cfg$n_inst, cfg$n_days, cfg$n_feat)
  snap <- ledgr_snapshot_from_df(
    bars, snapshot_id = tag,
    db_path = file.path(tempdir(), paste0(tag, ".duckdb"))
  )
  exp <- ledgr_experiment(
    snapshot = snap, strategy = strat,
    features = feats, opening = ledgr_opening(cash = 1e7)
  )

  # Warm: first run pays t_pre (feature precompute + projection build) and the
  # per-pulse view construction. The feature cache then makes subsequent t_pre
  # cheap. We capture the warm run's t_pre/t_wall explicitly because the
  # precompute cost (suspected O(n_pulses^2)) lands there, once.
  gc(reset = TRUE, full = TRUE)
  warm_wall <- system.time(
    warm <- ledgr_run(exp, params = list(qty = 1), run_id = "bench_warm")
  )[["elapsed"]]
  close(warm)
  warm_tel <- read_fold_telemetry("bench_warm")
  peak <- gc(full = TRUE)                              # peak after materialization
  peak_mb <- sum(peak[, "max used"] * c(0.000056, 0.000008))  # Ncells, Vcells -> MB approx
  peak_mb_gc <- tryCatch(sum(peak[, 6L]), error = function(e) NA_real_)

  pre_s  <- numeric(cfg$iters)
  loop_s <- numeric(cfg$iters)
  wall_s <- numeric(cfg$iters)
  for (k in seq_len(cfg$iters)) {
    rid <- sprintf("bench_hot_%02d", k)
    wall_s[k] <- system.time(
      bt <- ledgr_run(exp, params = list(qty = 1), run_id = rid)
    )[["elapsed"]]
    tel <- read_fold_telemetry(rid)
    pre_s[k]  <- tel$t_pre
    loop_s[k] <- tel$t_loop
    close(bt)
  }
  info <- ledgr_run_info(snap, "bench_hot_01")
  ledgr_snapshot_close(snap)

  t_pre   <- stats::median(pre_s,  na.rm = TRUE)
  t_loop  <- stats::median(loop_s, na.rm = TRUE)
  t_wall  <- stats::median(wall_s, na.rm = TRUE)
  gap_s   <- t_wall - t_pre - t_loop                  # view build + post + wrapper
  n_pulse <- as.integer(info$pulse_count)
  dps_pts <- as.numeric(n_pulse) * cfg$n_inst * cfg$n_feat

  list(
    config             = cfg,
    pulses             = n_pulse,
    cache_hits         = as.integer(info$feature_cache_hits),
    cache_misses       = as.integer(info$feature_cache_misses),
    feature_matrix_mb  = round(cfg$n_inst * cfg$n_days * cfg$n_feat * 8 / 1e6, 1),
    peak_session_mb    = round(if (is.finite(peak_mb_gc)) peak_mb_gc else peak_mb, 1),
    warm_t_pre_sec     = round(warm_tel$t_pre, 4),
    warm_t_wall_sec    = round(warm_wall, 4),
    t_pre_sec          = round(t_pre, 4),
    t_loop_sec         = round(t_loop, 4),
    t_wall_sec         = round(t_wall, 4),
    gap_sec            = round(gap_s, 4),
    engine_elapsed_sec = round(as.numeric(info$elapsed_sec), 4),  # incl. t_pre
    pulses_per_sec     = round(n_pulse / t_loop, 1),
    data_points        = dps_pts,
    dps_loop           = round(dps_pts / t_loop),
    dps_wall           = round(dps_pts / t_wall)
  )
}

# --- Scale sweep: phase split vs pulse count (detects O(n^2) precompute) ------
# Holds instruments/features fixed and varies pulse count so the scaling
# exponent of each phase (precompute, view build, loop) is visible. The
# QC-normalized column divides DPS(wall) by n_feat to count security-bars,
# matching how engines like LEAN report data points.

scale_sweep <- function(n_inst = 200L, n_feat = 50L,
                        pulse_grid = c(126L, 252L, 504L), iters = 1L) {
  rows <- lapply(pulse_grid, function(np) {
    res <- run_benchmark(list(n_inst = n_inst, n_days = as.integer(np),
                              n_feat = n_feat, iters = iters, trade = TRUE))
    data.frame(
      pulses          = res$pulses,
      warm_t_pre      = res$warm_t_pre_sec,
      warm_t_wall     = res$warm_t_wall_sec,
      t_pre           = res$t_pre_sec,
      gap_viewbuild   = res$gap_sec,
      t_loop          = res$t_loop_sec,
      t_wall          = res$t_wall_sec,
      peak_mb         = res$peak_session_mb,
      dps_loop        = res$dps_loop,
      dps_wall        = res$dps_wall,
      dps_wall_perbar = round(res$dps_wall / n_feat)
    )
  })
  do.call(rbind, rows)
}

# --- Main -------------------------------------------------------------------

spike_main <- function(cfg = DEFAULT_CONFIG) {
  cat("== Memory projection (linear feature-matrix + ~2.5x session) ==\n")
  print(project_memory(n_days = cfg$n_days), row.names = FALSE)
  cat("\n== Running benchmark:",
      cfg$n_inst, "instruments x", cfg$n_days, "pulses x",
      cfg$n_feat, "features ==\n")
  res <- run_benchmark(cfg)
  cat(sprintf(
    paste0(
      "  pulses=%d  feature_matrix=%.0f MB  peak_session~%.0f MB\n",
      "  cache hits/misses=%d/%d\n",
      "  PHASE SPLIT (median measured iter):\n",
      "    t_pre=%.3fs  gap(view build+post)=%.3fs  t_loop=%.3fs  t_wall=%.3fs\n",
      "  WARM run: t_pre=%.3fs  t_wall=%.3fs\n",
      "  Pulses/sec=%.1f  data_points=%.0f\n",
      "  DPS(loop)=%.0f   DPS(wall)=%.0f   DPS(wall, per security-bar)=%.0f\n"
    ),
    res$pulses, res$feature_matrix_mb, res$peak_session_mb,
    res$cache_hits, res$cache_misses,
    res$t_pre_sec, res$gap_sec, res$t_loop_sec, res$t_wall_sec,
    res$warm_t_pre_sec, res$warm_t_wall_sec,
    res$pulses_per_sec, res$data_points,
    res$dps_loop, res$dps_wall, round(res$dps_wall / cfg$n_feat)
  ))
  invisible(res)
}

if (sys.nframe() == 0L) {
  print(spike_main())
}
