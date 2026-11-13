# Decision 5's displaced-regression check (Cut 15): from the recorded paired
# comparisons (evidence/cut15/cmp_*_raw.csv), the time outside the pulse loop
# per round, candidate minus base, for the envelope outside the loop
# (envelope - pulses) and the whole run outside the loop (whole - pulses).
# No new timing. Reports the median paired change, the rounds where the
# candidate was slower, and the base median for scale.
#
#   Rscript dev/lean_core/parity/outside_loop.R --out=<csv>

here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
out <- sub("^--out=", "", grep("^--out=", commandArgs(TRUE), value = TRUE)[[1L]])
rows <- list()
for (t in c("3222", "3223", "3224", "ws32")) {
  raw <- utils::read.csv(file.path(here, "evidence", "cut15", paste0("cmp_", t, "_raw.csv")), stringsAsFactors = FALSE)
  for (s in unique(raw$shape)) {
    b <- raw[raw$shape == s & raw$arm == "base", ]
    c <- raw[raw$shape == s & raw$arm == "candidate", ]
    b <- b[order(b$round), ]
    c <- c[order(c$round), ]
    stopifnot(identical(b$round, c$round))
    for (clock in c("envelope", "whole")) {
      d <- (c[[paste0(clock, "_s")]] - c$pulses_s) - (b[[paste0(clock, "_s")]] - b$pulses_s)
      rows[[length(rows) + 1L]] <- data.frame(comparison = t, shape = s, outside_of = clock, rounds = length(d),
        base_median_s = round(stats::median(b[[paste0(clock, "_s")]] - b$pulses_s), 3),
        median_change_s = round(stats::median(d), 3), rounds_slower = sum(d > 0),
        min_change_s = round(min(d), 3), max_change_s = round(max(d), 3))
    }
  }
}
res <- do.call(rbind, rows)
utils::write.csv(res, out, row.names = FALSE)
print(res, row.names = FALSE)
