# Reference check for LDG-2650 PBO/CSCV spike.
#
# This script is not package runtime code. It verifies the current CRAN `pbo`
# package API/output against a fixed T x N returns panel and an independent
# manual CSCV calculation for the same small fixture.

if (!requireNamespace("pbo", quietly = TRUE)) {
  stop("The `pbo` package is required for this spike reference check.", call. = FALSE)
}

reference_panel <- data.frame(
  c1 = c(0.02, 0.01, -0.01, 0.00, 0.03, 0.01, -0.02, 0.00, 0.01, 0.02, -0.01, 0.00),
  c2 = c(0.00, 0.01, 0.02, 0.01, -0.01, 0.00, 0.03, 0.02, -0.02, -0.01, 0.00, 0.01),
  c3 = c(-0.01, 0.00, 0.01, 0.02, 0.00, -0.01, 0.01, 0.03, 0.02, 0.00, -0.02, -0.01),
  c4 = c(0.01, -0.02, 0.00, 0.01, 0.02, 0.03, 0.00, -0.01, 0.00, 0.01, 0.02, 0.03),
  check.names = FALSE
)

metric_col_mean <- function(x) {
  colMeans(as.data.frame(x), na.rm = FALSE)
}

manual_cscv <- function(m, s, f) {
  t <- nrow(m)
  if (t %% s != 0L) {
    stop("`s` must evenly divide the number of rows.", call. = FALSE)
  }
  combos <- utils::combn(s, s / 2)
  subset_n <- t / s
  out <- vector("list", ncol(combos))

  for (case_idx in seq_len(ncol(combos))) {
    is_subset <- combos[, case_idx]
    is_indices <- unlist(lapply(is_subset, function(i) {
      start <- subset_n * i - subset_n + 1L
      end <- start + subset_n - 1L
      start:end
    }), use.names = FALSE)
    os_indices <- setdiff(seq_len(t), is_indices)
    r <- f(m[is_indices, , drop = FALSE])
    r_bar <- f(m[os_indices, , drop = FALSE])
    n_star <- which.max(r)
    n_max_oos <- which.max(r_bar)
    os_rank <- rank(r_bar)[[n_star]]
    omega_bar <- os_rank / length(r_bar)
    lambda <- log(omega_bar / (1 - omega_bar))
    out[[case_idx]] <- data.frame(
      n_star = as.integer(n_star),
      n_max_oos = as.integer(n_max_oos),
      os_rank = as.numeric(os_rank),
      omega_bar = as.numeric(omega_bar),
      lambda = as.numeric(lambda),
      Rn = as.numeric(r[[n_star]]),
      Rbn = as.numeric(r_bar[[n_star]])
    )
  }

  do.call(rbind, out)
}

extract_pbo_result <- function(x) {
  data.frame(
    n_star = vapply(seq_len(nrow(x$results)), function(i) as.integer(x$results[[i, "n*"]]), integer(1)),
    n_max_oos = vapply(seq_len(nrow(x$results)), function(i) as.integer(x$results[[i, "n_max_oos"]]), integer(1)),
    os_rank = vapply(seq_len(nrow(x$results)), function(i) as.numeric(x$results[[i, "os_rank"]]), numeric(1)),
    omega_bar = vapply(seq_len(nrow(x$results)), function(i) as.numeric(x$results[[i, "omega_bar"]]), numeric(1)),
    lambda = vapply(seq_len(nrow(x$results)), function(i) as.numeric(x$results[[i, "lambda"]]), numeric(1)),
    Rn = as.numeric(x$rn_pairs$Rn),
    Rbn = as.numeric(x$rn_pairs$Rbn)
  )
}

expected <- manual_cscv(reference_panel, s = 4L, f = metric_col_mean)
pbo_1 <- pbo::pbo(reference_panel, s = 4L, f = metric_col_mean, threshold = 0, allow_parallel = FALSE)
pbo_2 <- pbo::pbo(reference_panel, s = 4L, f = metric_col_mean, threshold = 0, allow_parallel = FALSE)
actual <- extract_pbo_result(pbo_1)

stopifnot(identical(pbo_1, pbo_2))
stopifnot(isTRUE(all.equal(actual, expected, tolerance = 1e-12, check.attributes = FALSE)))
stopifnot(isTRUE(all.equal(pbo_1$phi, 2 / 3, tolerance = 1e-12)))
stopifnot(isTRUE(all.equal(pbo_1$below_threshold, 0.333, tolerance = 1e-12)))
stopifnot(identical(names(pbo_1), c(
  "results", "combos", "lambda", "phi", "rn_pairs", "func", "slope",
  "intercept", "ar2", "threshold", "below_threshold", "test_config", "inf_sub"
)))

cat("pbo reference check passed\n")
cat("version:", as.character(utils::packageVersion("pbo")), "\n")
cat("phi:", pbo_1$phi, "\n")
cat("below_threshold:", pbo_1$below_threshold, "\n")
