# Synthetic micro-benchmark: build one pulse's wide, long and bars frames from
# prepared matrix columns (base data.frame(), collapse::qDF(), bare constructor)
# against a prebuilt-list lookup. 600 instruments, 1,514 pulses, 3 features.
# Rscript dev/spikes/ctx_frame_views/frame_builder_bench.R

library(microbenchmark)
library(collapse)
set.seed(1)
n <- 600L; P <- 1514L; fids <- c("sma_5", "return_5", "return_20")
ids <- sprintf("I%03d", seq_len(n))
pulses <- as.POSIXct("2000-01-03 21:00:00", tz = "UTC") + 86400 * seq_len(P)
feat <- setNames(lapply(fids, function(f) matrix(rnorm(n * P), n, P)), fids)
bm <- list(open = matrix(runif(n * P), n, P), high = matrix(runif(n * P), n, P),
           low = matrix(runif(n * P), n, P), close = matrix(runif(n * P), n, P),
           volume = matrix(runif(n * P), n, P))
i <- 700L

# --- builders from primitives (one pulse) ---------------------------------
wide_base <- function(i) data.frame(instrument_id = ids, ts_utc = rep(pulses[i], n),
  sma_5 = feat$sma_5[, i], return_5 = feat$return_5[, i], return_20 = feat$return_20[, i],
  stringsAsFactors = FALSE)
wide_collapse <- function(i) qDF(c(list(instrument_id = ids, ts_utc = rep(pulses[i], n)),
  lapply(feat, function(m) m[, i])))
wide_raw <- function(i) {
  x <- c(list(instrument_id = ids, ts_utc = rep(pulses[i], n)), lapply(feat, function(m) m[, i]))
  attr(x, "row.names") <- c(NA_integer_, -n); class(x) <- "data.frame"; x
}
long_raw <- function(i) {
  x <- list(ts_utc = rep(pulses[i], n * 3L), instrument_id = rep(ids, each = 3L),
            feature_name = rep(fids, n),
            feature_value = as.vector(rbind(feat[[1]][, i], feat[[2]][, i], feat[[3]][, i])))
  attr(x, "row.names") <- c(NA_integer_, -n * 3L); class(x) <- "data.frame"; x
}
bars_raw <- function(i) {
  x <- c(list(instrument_id = ids, ts_utc = rep(pulses[i], n)), lapply(bm, function(m) m[, i]))
  attr(x, "row.names") <- c(NA_integer_, -n); class(x) <- "data.frame"; x
}
vec_read <- function(i) feat$sma_5[, i]

# --- prepared lookup (what the fold does today) ---------------------------
prepared <- lapply(1:P, wide_raw)
lookup <- function(i) prepared[[i]]

stopifnot(identical(wide_base(i), wide_raw(i)), isTRUE(all.equal(qDF(wide_raw(i)), wide_collapse(i))))
r <- microbenchmark(
  prepared_lookup = lookup(i),
  vec_one_feature = vec_read(i),
  wide_base_data.frame = wide_base(i),
  wide_collapse_qDF = wide_collapse(i),
  wide_raw_constructor = wide_raw(i),
  long_raw_constructor = long_raw(i),
  bars_raw_constructor = bars_raw(i),
  times = 2000L, unit = "us")
s <- summary(r)[, c("expr", "median")]
s$per_run_1514_pulses_ms <- round(s$median * P / 1000, 1)
s$median <- round(s$median, 2)
names(s)[2] <- "median_us_per_pulse"
print(s, row.names = FALSE)
cat(sprintf("\nall three frames on demand, every pulse: %.0f ms per 1,514-pulse run\n",
            (s$median_us_per_pulse[s$expr == "wide_raw_constructor"] +
             s$median_us_per_pulse[s$expr == "long_raw_constructor"] +
             s$median_us_per_pulse[s$expr == "bars_raw_constructor"]) * P / 1000))
cat("prepared frames held for the whole run (object.size, MiB):",
    round(as.numeric(object.size(prepared)) / 2^20, 1), "(wide only)\n")
