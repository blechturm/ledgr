# Verify WHY the ledgr_sweep amortization curve was flat (peer_sweep_three_way.R):
# is there genuinely no amortization, or did the harness miss the documented
# precompute-sharing path? Compare, on the feature-heavy workload at N=10:
#   (1) ledgr_sweep                          -- internal union precompute
#   (2) ledgr_sweep(precomputed_features=..) -- explicit ledgr_precompute_features()
#   (3) N x ledgr_run                        -- true naive (no sharing at all)
# If (1) ~= (2) ~= (3): no amortization exists (thesis negative).
# If (2) << (3): explicit precompute amortizes (harness missed it).
# Also reports a 2-feature reference so we can see the per-candidate width scaling.
#
# Usage: Rscript dev/bench/peer_sweep_verify.R

suppressWarnings(suppressMessages({
  if (file.exists("DESCRIPTION") && identical(unname(read.dcf("DESCRIPTION")[1L, "Package"]), "ledgr")) {
    pkgload::load_all(".", quiet = TRUE)
  } else library(ledgr)
}))
if (!requireNamespace("TTR", quietly = TRUE)) stop("needs TTR")

WIDTH <- 30L; DAYS <- 504L; SEED <- 20260529L; N <- 10L; N_HEAVY <- 40L
bars <- as.data.frame(ledgr_sim_bars(n_instruments = WIDTH, n_days = DAYS, seed = SEED))

sma_ttr <- function(w) { w <- as.integer(w); force(w)
  ledgr_indicator(id = sprintf("sma_ttr_%d", w),
    fn = function(window) { x <- as.numeric(window$close); if (length(x) < w) return(NA_real_); as.numeric(TTR::SMA(x, n = w))[[length(x)]] },
    requires_bars = w, series_fn = function(bars, params) as.numeric(TTR::SMA(as.numeric(bars$close), n = w))) }
heavy_w <- setdiff(3:(N_HEAVY + 8L), c(20L, 50L))[seq_len(N_HEAVY - 2L)]
heavy_features <- do.call(ledgr_feature_map, c(list(fast = sma_ttr(20L), slow = sma_ttr(50L)),
                                               stats::setNames(lapply(heavy_w, sma_ttr), sprintf("x_%03d", heavy_w))))

mk_exp <- function() {
  db <- tempfile(fileext = ".duckdb")
  snap <- ledgr_snapshot_from_df(bars, db_path = db)
  exp <- ledgr_experiment(snapshot = snap, strategy = ledgr_demo_sma_crossover_strategy(),
                          features = heavy_features, opening = ledgr_opening(cash = 1e7), persist_features = FALSE)
  list(exp = exp, snap = snap, db = db)
}
close_exp <- function(h) { try(ledgr_snapshot_close(h$snap), silent = TRUE); unlink(h$db) }
grid_N <- function(n) do.call(ledgr_param_grid, stats::setNames(lapply(seq_len(n), function(i) list(qty = i, threshold = 0)), sprintf("c%03d", seq_len(n))))

cat(sprintf("heavy (%d features), N=%d, %d inst x %d days\n\n", N_HEAVY, N, WIDTH, DAYS))

# (1) internal union precompute
h <- mk_exp(); g <- grid_N(N)
t1 <- suppressWarnings(system.time(ledgr_sweep(h$exp, g, seed = SEED))[["elapsed"]]); close_exp(h)

# (2) explicit precomputed_features
h <- mk_exp(); g <- grid_N(N)
t_pre <- system.time(pf <- ledgr_precompute_features(h$exp, g))[["elapsed"]]
t2 <- suppressWarnings(system.time(ledgr_sweep(h$exp, g, precomputed_features = pf, seed = SEED))[["elapsed"]]); close_exp(h)

# (3) true naive: N separate ledgr_run
h <- mk_exp()
t3 <- system.time(for (i in seq_len(N)) {
  bt <- ledgr_run(h$exp, params = list(qty = i, threshold = 0), run_id = sprintf("naive_%02d_%s", i, paste(sample(c(0:9,letters),5,TRUE),collapse="")), seed = SEED)
  try(close(bt), silent = TRUE)
})[["elapsed"]]; close_exp(h)

cat(sprintf("(1) ledgr_sweep internal           : %.2fs  (%.3fs/cand)\n", t1, t1/N))
cat(sprintf("(2) ledgr_sweep + precomputed      : %.2fs  (%.3fs/cand)  [precompute step %.2fs]\n", t2, t2/N, t_pre))
cat(sprintf("(3) N x ledgr_run (true naive)     : %.2fs  (%.3fs/cand)\n", t3, t3/N))
cat(sprintf("\namortization (3)/(1) = %.2fx ; (3)/(2incl-pre) = %.2fx\n", t3/t1, t3/(t2 + t_pre)))
cat(sprintf("if all ~equal: no amortization. if (2) << (3): explicit precompute is the path.\n"))
