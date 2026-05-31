# Sweep amortization measurement (ledgr side first): does ledgr_sweep amortize
# the feature precompute across candidates, and how much does it win?
#
# The bet: ledgr_sweep computes the feature union ONCE and reuses it across N
# candidates, while peers (quantstrat apply.paramset, backtrader optstrategy)
# re-pay per candidate. BUT ledgr re-runs the per-candidate FOLD each time, and
# the fold is ledgr's slow part. So amortization wins in proportion to the
# feature-precompute fraction -- big on feature-heavy workloads, small on cheap
# SMA. This measures ledgr_sweep wall vs N for both, and decomposes:
#   wall(N) ~= intercept (amortized one-time precompute+bars+scaffold) + slope*N
#             (per-candidate fold, NOT amortized).
# A large intercept + small slope = strong amortization (feature-heavy); a small
# intercept = little to amortize (cheap SMA).
#
# Timing boundary: ledgr_sweep() execution only (snapshot/experiment build
# excluded, like peer_three_way.R). Peers added in a follow-up once the ledgr
# curve is established. Relates to: architecture_synthesis.md L7.
#
# Usage: Rscript dev/bench/peer_sweep_three_way.R --width 30 --days 504

suppressWarnings(suppressMessages({
  if (file.exists("DESCRIPTION") && identical(unname(read.dcf("DESCRIPTION")[1L, "Package"]), "ledgr")) {
    pkgload::load_all(".", quiet = TRUE)
  } else library(ledgr)
}))
if (!requireNamespace("TTR", quietly = TRUE)) {
  stop("This harness uses TTR::SMA (optimized C SMA), matching bench_make_sma_features. Install TTR.")
}

# TTR-backed SMA indicator (matches run_benchmarks.R bench_make_sma_features), so
# the precompute cost is realistic -- the built-in ledgr_ind_sma rolling mean
# would inflate the amortizable precompute and rig the sweep in ledgr's favor.
sma_ttr <- function(w) {
  w <- as.integer(w); force(w)
  ledgr_indicator(
    id = sprintf("sma_ttr_%d", w),
    fn = function(window) {
      x <- as.numeric(window$close)
      if (length(x) < w) return(NA_real_)
      as.numeric(TTR::SMA(x, n = w))[[length(x)]]
    },
    requires_bars = w,
    series_fn = function(bars, params) as.numeric(TTR::SMA(as.numeric(bars$close), n = w))
  )
}

a <- commandArgs(trailingOnly = TRUE)
gi <- function(k, d) { i <- which(a == k); if (length(i)) as.integer(a[[i + 1L]]) else d }
WIDTH <- gi("--width", 30L); DAYS <- gi("--days", 504L); SEED <- gi("--seed", 20260529L)
N_HEAVY <- gi("--heavy-feat", 40L)
NS <- c(1L, 5L, 25L, 50L)
OUT <- "dev/bench/results"; dir.create(OUT, recursive = TRUE, showWarnings = FALSE)

bars <- as.data.frame(ledgr_sim_bars(n_instruments = WIDTH, n_days = DAYS, seed = SEED))

sma_features <- ledgr_feature_map(fast = sma_ttr(20L), slow = sma_ttr(50L))
# distinct windows excluding 20/50 (feature id = sma_ttr_<n>, must be unique)
heavy_w <- setdiff(3:(N_HEAVY + 8L), c(20L, 50L))[seq_len(N_HEAVY - 2L)]
extra <- stats::setNames(lapply(heavy_w, sma_ttr), sprintf("x_%03d", heavy_w))
heavy_features <- do.call(ledgr_feature_map, c(list(fast = sma_ttr(20L), slow = sma_ttr(50L)), extra))

# strategy-param sweep: vary qty 1..N, features fixed -> union computed once
sweep_wall <- function(features, n) {
  db <- tempfile(fileext = ".duckdb"); on.exit(unlink(db), add = TRUE)
  snap <- ledgr_snapshot_from_df(bars, db_path = db); on.exit(ledgr_snapshot_close(snap), add = TRUE)
  exp <- ledgr_experiment(snapshot = snap, strategy = ledgr_demo_sma_crossover_strategy(),
                          features = features, opening = ledgr_opening(cash = 1e7), persist_features = FALSE)
  cand <- stats::setNames(lapply(seq_len(n), function(i) list(qty = i, threshold = 0)), sprintf("c%03d", seq_len(n)))
  grid <- do.call(ledgr_param_grid, cand)
  suppressWarnings(system.time(ledgr_sweep(exp, grid, seed = SEED))[["elapsed"]])
}

cat(sprintf("ledgr_sweep amortization: %d inst x %d days, strategy-param sweep (vary qty)\n", WIDTH, DAYS))
cat(sprintf("sma = 2 features; heavy = %d features (strategy reads 2, rest are precompute load)\n\n", N_HEAVY))

rows <- list()
for (wl in c("sma", "heavy")) {
  features <- if (wl == "sma") sma_features else heavy_features
  invisible(sweep_wall(features, 1L))  # warmup
  walls <- vapply(NS, function(n) sweep_wall(features, n), numeric(1))
  fit <- stats::lm(walls ~ NS)
  intercept <- unname(coef(fit)[1L]); slope <- unname(coef(fit)[2L])
  cat(sprintf("[%s]\n", wl))
  for (j in seq_along(NS)) cat(sprintf("  N=%-3d  wall %.2fs  (%.3fs/candidate)\n", NS[j], walls[j], walls[j] / NS[j]))
  cat(sprintf("  fit: amortized one-time intercept %.2fs  +  per-candidate slope %.3fs/cand\n", intercept, slope))
  cat(sprintf("  => N=50 actual %.2fs vs naive (50 x single-equiv = 50*(int+slope)) %.2fs  -> %.1fx amortization\n\n",
              walls[length(NS)], 50 * (intercept + slope), (50 * (intercept + slope)) / walls[length(NS)]))
  for (j in seq_along(NS)) rows[[length(rows) + 1L]] <- data.frame(workload = wl, n_candidates = NS[j], sweep_wall_s = walls[j],
                                                                  per_candidate_s = walls[j] / NS[j], intercept_s = intercept, slope_s = slope)
}
utils::write.csv(do.call(rbind, rows), file.path(OUT, "peer_sweep_three_way_ledgr.csv"), row.names = FALSE)
cat("WROTE", file.path(OUT, "peer_sweep_three_way_ledgr.csv"), "\n")
