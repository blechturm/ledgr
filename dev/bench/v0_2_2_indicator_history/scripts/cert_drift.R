root <- commandArgs(TRUE)[[1]]; out <- commandArgs(TRUE)[[2]]
suppressMessages(pkgload::load_all(root, quiet = TRUE))
src <- readLines(file.path(root, "tests/testthat/test-indicator-history.R"))
end <- grep("^# ledgr-test-profile: review", src)[1] - 1L
eval(parse(text = src[seq_len(end)]))
catalogue <- ledgr:::ledgr_indicator_history_catalogue()
fixtures <- list(smooth = indicator_history_bars(80L), hostile = indicator_history_bars(80L, hostile = TRUE))
scaled <- function(a, b) abs(a - b) / pmax(1, abs(b))
rows <- list()
for (i in seq_len(nrow(catalogue))) {
  row <- catalogue[i, , drop = FALSE]
  ind <- indicator_history_catalogue_indicator(row)
  w <- ind$requires_bars
  for (fx in names(fixtures)) {
    bars <- fixtures[[fx]]
    full <- ledgr:::ledgr_compute_feature_series(bars, ind)
    ks <- seq.int(ind$stable_after, nrow(bars))
    d <- vapply(ks, function(k) {
      v <- ledgr:::ledgr_compute_feature_series(bars[seq.int(k - w + 1L, k), , drop = FALSE], ind)[[w]]
      scaled(v, full[[k]])
    }, numeric(1))
    rows[[length(rows) + 1L]] <- data.frame(
      source = row$source, family = row$family, output = row$output, variant = row$variant,
      history_class = row$history_class, input_carry = row$input_carry, width = w,
      fixture = fx, max_scaled_window_delta = max(d, na.rm = TRUE),
      ttr_version = as.character(utils::packageVersion("TTR")), stringsAsFactors = FALSE)
  }
}
res <- do.call(rbind, rows)
utils::write.csv(res, out, row.names = FALSE)
b <- res[res$history_class == "bounded", ]
h <- res[res$history_class == "history_dependent", ]
cat("bounded max", max(b$max_scaled_window_delta), "history min", min(aggregate(max_scaled_window_delta ~ family + output + variant, h, max)$max_scaled_window_delta), "\n")
print(b[order(-b$max_scaled_window_delta), ][1:5, c("family", "output", "variant", "fixture", "max_scaled_window_delta")])
