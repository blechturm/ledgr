lw_work <- Sys.getenv("LW_WORK", "C:/tmp/ledgr-lw-work")
# Split the cost of one strict feature window into its steps, and compare the
# strict path with a vectorised candidate on the same aligned bars.
# Rscript lw_strict_breakdown.R <repo> <n_pulses> <reps>
args <- commandArgs(TRUE)
repo <- args[[1]]; n <- as.integer(args[[2]]); reps <- as.integer(args[[3]])
suppressMessages(pkgload::load_all(repo, quiet = TRUE, compile = FALSE))
ns <- asNamespace("ledgr")
set.seed(1)
ts <- as.POSIXct("2000-01-03 21:00:00", tz = "UTC") + 86400 * seq_len(n)
close <- 100 * exp(cumsum(rnorm(n, 0, 0.02)))
# The availability-aligned frame the runner builds per instrument (9 columns).
b <- data.frame(instrument_id = "I0001", ts_utc = ts, open = close, high = close * 1.005,
                low = close * 0.995, close = close, volume = 1e5,
                gap_type = "", is_synthetic = FALSE, stringsAsFactors = FALSE)
# Parity cases: a mid-history entrant (leading missing sessions before the
# first bar), isolated gaps inside windows, and warmup positions.
entry <- n %/% 5L
gap <- c(seq_len(entry), sample(seq.int(entry + 1L, n), max(1L, n %/% 200L)))
b[gap, c("open", "high", "low", "close", "volume")] <- NA
b$gap_type[gap] <- "MISSING_EXPECTED_SESSION"

defs <- lapply(list(ledgr_ind_returns(63), ledgr_ind_returns(126), ledgr_ind_returns(252)),
               function(ind) ns$ledgr_precompute_feature_def_from_indicator(ind))
time_it <- function(expr_fun) { t0 <- proc.time()[["elapsed"]]; for (r in seq_len(reps)) v <- expr_fun(); (proc.time()[["elapsed"]] - t0) / reps }

rows <- list()
for (def in defs) {
  width <- as.integer(def$stable_after)
  windows <- n - width + 1L
  strict_s <- time_it(function() ns$ledgr_compute_feature_series_strict(b, def))
  strict <- ns$ledgr_compute_feature_series_strict(b, def)
  # Step costs, each repeated over every window position.
  idx <- seq.int(width, n)
  value_columns <- c("open", "high", "low", "close")
  t_slice <- time_it(function() for (i in idx) w <- b[seq.int(i - width + 1L, i), , drop = FALSE])
  w <- b[seq.int(n - width + 1L, n), , drop = FALSE]
  one <- function(f) { t0 <- proc.time()[["elapsed"]]; for (i in idx) f(); proc.time()[["elapsed"]] - t0 }
  t_check <- one(function() all(vapply(w[value_columns], function(x) { v <- suppressWarnings(as.numeric(x)); !anyNA(v) && all(is.finite(v)) }, logical(1))))
  t_fn <- one(function() ns$ledgr_normalize_feature_scalar_output(ns$ledgr_call_feature_fn(def$fn, w, def$params %||% list()), def$id))
  t_series <- one(function() ns$ledgr_normalize_feature_scalar_output(utils::tail(ns$ledgr_call_feature_series_fn(def$series_fn, w, def$params %||% list()), 1L), def$id))
  s1 <- 0.1; s2 <- 0.1
  t_alleq <- one(function() isTRUE(all.equal(s1, s2, tolerance = sqrt(.Machine$double.eps))))
  # Vectorised candidate: one series_fn over the full history, masked where the
  # trailing window contains an incomplete row.
  vec <- function() {
    full <- ns$ledgr_call_feature_series_fn(def$series_fn, b, def$params %||% list())
    bad <- !stats::complete.cases(b[value_columns]) | !is.finite(rowSums(as.matrix(b[value_columns])))
    cnt <- cumsum(bad); prev <- c(rep(0L, width), cnt)[seq_len(n)]
    out <- as.numeric(full); ok <- seq_len(n) >= width & (cnt - prev) == 0L
    out[!ok] <- NA_real_
    out
  }
  vec_s <- time_it(vec)
  v <- vec()
  rows[[def$id]] <- data.frame(
    feature = def$id, n = n, width = width, windows = windows,
    strict_s = strict_s, us_per_window = 1e6 * strict_s / windows,
    slice_us = 1e6 * t_slice / windows, check_us = 1e6 * t_check / windows,
    fn_us = 1e6 * t_fn / windows, series_us = 1e6 * t_series / windows, all_equal_us = 1e6 * t_alleq / windows,
    vectorised_s = vec_s, speedup = strict_s / vec_s,
    identical = identical(strict, v), max_abs_diff = max(abs(strict - v), na.rm = TRUE),
    na_mask_identical = identical(is.na(strict), is.na(v)))
}
out <- do.call(rbind, rows)
print(format(out, digits = 4), row.names = FALSE)
write.csv(out, paste0(lw_work, sprintf("/strict_breakdown_%d.csv", n)), row.names = FALSE)
