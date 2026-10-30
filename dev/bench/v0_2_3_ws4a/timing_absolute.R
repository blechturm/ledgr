# WS4a absolute timing checker (LDG-3163; v0.2.3 cut 5 decision (4)).
#
# Protocol ws4a-timing-1's cell `avail_wide_marginal` reports, per process,
# the availability wide sweep's marginal seconds per executed fill (its own
# clock; see that protocol's workloads.R). This script runs the unchanged
# shared checker, dev/bench/timing/check.R's timing_check(), on one record
# and reads that cell's per-cell result. It never subtracts medians of
# separate cells and never re-reads raw rows. It passes only when:
#   - the shared checker found no validity failure (any failure other than
#     a ratio above its bound invalidates the record, and so this verdict);
#   - the cell has a valid candidate row in every pair, so no zero,
#     negative or nonfinite measurement was dropped from its median;
#   - the candidate median is finite, positive and at most 40e-6 seconds.
# Ratio cells stay the shared checker's verdict; this one fails separately.
#
# Usage, from the package root:
#   Rscript dev/bench/v0_2_3_ws4a/timing_absolute.R --protocol=<folder> --record=<attempt dir> [--aa]
#   Rscript dev/bench/v0_2_3_ws4a/timing_absolute.R --self-test
# Exit status 0 means PASS (or every self-test case behaved as expected).

ws4a_absolute_cell <- "avail_wide_marginal"
ws4a_absolute_limit <- 40e-6

# `res` is timing_check()'s result, list(ok, failures, cells); `pairs` is
# the protocol's pair count. Returns the cell row and the reasons it fails.
ws4a_absolute_verdict <- function(res, pairs, cell = ws4a_absolute_cell, limit = ws4a_absolute_limit) {
  row <- if (is.null(res$cells)) data.frame() else res$cells[res$cells$cell %in% cell, , drop = FALSE]
  if (nrow(row) != 1L) return(list(row = row, reasons = sprintf("the shared checker reported no result for cell %s", cell)))
  invalid <- unique(res$failures$reason[res$failures$reason != "ratio above bound"])
  m <- row$median_candidate
  reasons <- c(
    if (length(invalid)) sprintf("record invalid under the shared checker (%s)", paste(invalid, collapse = ", ")),
    if (!isTRUE(row$n_candidate == pairs)) sprintf("%s valid candidate rows, the protocol states %d pairs", row$n_candidate, pairs),
    if (!is.finite(m)) sprintf("candidate median %s is not finite", format(m)) else
      if (m <= 0) sprintf("candidate median %s is not positive", format(m)) else
      if (m > limit) sprintf("candidate median %.3f us per fill > %.3f us", 1e6 * m, 1e6 * limit))
  list(row = row, reasons = reasons)
}

ws4a_absolute_report <- function(v) {
  if (nrow(v$row) == 1L) {
    cat(sprintf("%s: candidate median %.6g s/fill (%.3f us), base median %.6g s/fill, %s candidate / %s base rows\n",
      v$row$cell, v$row$median_candidate, 1e6 * v$row$median_candidate, v$row$median_base, v$row$n_candidate, v$row$n_base))
  }
  if (!length(v$reasons)) {
    cat(sprintf("ABSOLUTE PASS (candidate median <= %.0f us per fill)\n", 1e6 * ws4a_absolute_limit))
    return(0L)
  }
  cat("ABSOLUTE FAIL:", paste(v$reasons, collapse = "; "), "\n")
  1L
}

# Self-test: per-cell results in the shape timing_check() returns them. A
# zero, negative or nonfinite row is what the shared checker records as an
# "invalid seconds" failure and leaves out of its median; the direct cases
# put such a value in the median itself, so the guard holds even if the
# shared checker's exclusion changed.
ws4a_absolute_self_test <- function() {
  pairs <- 8L
  result <- function(candidate, base = 240e-6, n_candidate = pairs, failures = character()) {
    list(failures = data.frame(reason = failures, detail = rep("self-test", length(failures))),
      cells = data.frame(cell = ws4a_absolute_cell, clock = "marginal", bound = 1, n_candidate = n_candidate,
        n_base = pairs, median_candidate = candidate, median_base = base, ratio = candidate / base))
  }
  cases <- list(
    list("45 us candidate against a 240 us paired base", result(45e-6), FALSE),
    list("30 us candidate against a 240 us paired base", result(30e-6), TRUE),
    list("40 us candidate (the bound itself)", result(40e-6), TRUE),
    list("zero rows dropped by the shared checker", result(30e-6, n_candidate = 7L, failures = "invalid seconds"), FALSE),
    list("every row zero (no median)", result(NA_real_, n_candidate = 0L, failures = "invalid seconds"), FALSE),
    list("zero median", result(0), FALSE),
    list("negative median", result(-30e-6), FALSE),
    list("NaN median", result(NaN), FALSE),
    list("Inf median", result(Inf), FALSE),
    list("NA median", result(NA_real_), FALSE),
    list("valid 30 us in an invalid record", result(30e-6, failures = "process identity"), FALSE),
    list("30 us with another cell above its ratio bound", result(30e-6, failures = "ratio above bound"), TRUE))
  ok <- TRUE
  for (case in cases) {
    v <- ws4a_absolute_verdict(case[[2]], pairs)
    accepted <- !length(v$reasons)
    ok <- ok && identical(accepted, case[[3]])
    cat(sprintf("%-4s %-50s %-6s %s\n", if (identical(accepted, case[[3]])) "ok" else "BAD", case[[1]],
      if (accepted) "ACCEPT" else "REJECT", paste(v$reasons, collapse = "; ")))
  }
  cat(if (ok) "\nSELF-TEST PASS\n" else "\nSELF-TEST FAIL\n")
  if (ok) 0L else 1L
}

if (sys.nframe() == 0L) {
  here <- normalizePath(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]])),
    winslash = "/")
  harness <- file.path(here, "..", "timing")
  for (f in c("host.R", "protocol.R", "check.R")) source(file.path(harness, f))
  opt <- timing_args()
  if (isTRUE(opt("self-test"))) quit(save = "no", status = ws4a_absolute_self_test())
  if (!is.character(opt("protocol")) || !is.character(opt("record"))) {
    stop("usage: timing_absolute.R --protocol=<folder> --record=<attempt dir> [--aa] | --self-test", call. = FALSE)
  }
  res <- timing_check(opt("protocol"), opt("record"), aa = isTRUE(opt("aa")),
    repo = normalizePath(file.path(here, "..", "..", ".."), winslash = "/"))
  for (i in seq_len(nrow(res$failures))) cat(sprintf("shared checker: %s: %s\n", res$failures$reason[[i]], res$failures$detail[[i]]))
  quit(save = "no", status = ws4a_absolute_report(ws4a_absolute_verdict(res, timing_read_protocol(opt("protocol"))$pairs)))
}
