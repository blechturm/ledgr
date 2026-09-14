# Manual numerical cross-check for ledgr's native Deflated Sharpe Ratio.
#
# quantstrat is not available from CRAN, so this reference procedure is kept
# outside the automated package suite. Install quantstrat into the active R
# library before running this script from the package root.

if (!requireNamespace("quantstrat", quietly = TRUE)) {
  stop("Install quantstrat in the active R library before running this check.")
}
if (!requireNamespace("pkgload", quietly = TRUE)) {
  stop("Install pkgload in the active R library before running this check.")
}

pkgload::load_all(".", quiet = TRUE)

a <- c(
  -0.020, -0.010, 0.000, 0.010, 0.020, 0.030,
  0.010, -0.020, 0.000, 0.020, 0.015, -0.005
)
b <- a + rep(c(0.001, -0.001), 6L)
c <- c(
  0.030, -0.020, 0.025, -0.015, 0.020, -0.010,
  0.015, -0.005, 0.010, 0.000, 0.005, -0.005
)
d <- c + rep(c(-0.001, 0.001), 6L)

panel <- ledgr_return_panel(cbind(a = a, b = b, c = c, d = d))
row_a <- tibble::as_tibble(ledgr_dsr(panel, effective_trials = 2L))
row_a <- row_a[row_a$candidate_id == "a", , drop = FALSE]

reference <- getFromNamespace(".deflatedSharpe", "quantstrat")(
  sharpe = row_a$observed_sharpe[[1L]],
  nTrials = row_a$effective_trials[[1L]],
  varTrials = row_a$variance_sharpe[[1L]],
  skew = row_a$skewness[[1L]],
  kurt = row_a$kurtosis[[1L]],
  numPeriods = row_a$observations[[1L]],
  periodsInYear = 1
)

stopifnot(
  isTRUE(all.equal(row_a$p_value[[1L]], reference$p.value, tolerance = 1e-12)),
  isTRUE(all.equal(
    row_a$deflated_sharpe[[1L]],
    reference$deflated.Sharpe,
    tolerance = 1e-12
  ))
)

cat("quantstrat DSR cross-check passed at tolerance 1e-12.\n")
