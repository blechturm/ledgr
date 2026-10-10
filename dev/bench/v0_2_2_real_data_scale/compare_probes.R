# Before/after verdicts for the growth-shape probes (Cut 11 Workstream 22).
#
#   Rscript compare_probes.R <pre_cut_probes.csv> <final_probes.csv> <out_csv>
#
# Declared thresholds: a timing shape is removed when its final growth
# exponent is at most 1.10 where the pre-cut one exceeded 1.10 (F1, F2, F4;
# F5 from ms per pulse at the smallest and largest axis); a counting shape is
# removed when the final count no longer grows with its collection (F6, F7).
# F9 and F10 were linear before (the cut review classed F9 as overstated);
# their verdict is the time ratio at the largest size. F8 records no per-fill
# growth either way. F11, F12 and F13 closed as measured and rejected and must
# show the shape unchanged. The pre-cut file is the reintroduced-shape case:
# every removed shape fails its threshold there.

args <- commandArgs(trailingOnly = TRUE)
pre <- utils::read.csv(args[[1L]], stringsAsFactors = FALSE)
fin <- utils::read.csv(args[[2L]], stringsAsFactors = FALSE)
val <- function(d, f, metric, size = NULL) {
  r <- d[d$finding == f & d$metric == metric, , drop = FALSE]
  if (!is.null(size)) r <- r[r$size == size, , drop = FALSE]
  as.numeric(r$value)
}
exponent_of <- function(d, f) val(d, f, "growth_exponent")
ms_exp <- function(d) { v <- val(d, "F5", "ms_per_pulse"); log(v[[length(v)]] / v[[1L]]) / log(4) }
rows <- list()
add <- function(finding, measure, before, after, removed, note) {
  rows[[length(rows) + 1L]] <<- data.frame(finding = finding, measure = measure, pre_cut = signif(before, 4),
                                           final = signif(after, 4), verdict = note, ok = removed)
}
for (f in c("F1", "F2", "F4")) {
  b <- exponent_of(pre, f); a <- exponent_of(fin, f)
  add(f, "growth exponent", b, a, b > 1.10 && a <= 1.10, if (b > 1.10 && a <= 1.10) "shape removed" else "NOT removed")
}
b <- ms_exp(pre); a <- ms_exp(fin)
add("F5", "growth exponent (ms per pulse, axis 250 to 1000)", b, a, b > 1.10 && a <= 1.10,
    if (b > 1.10 && a <= 1.10) "shape removed" else "NOT removed")
for (f in c("F6", "F7")) {
  metric <- if (f == "F6") "feature_appends_per_run" else "diagnostic_appends_per_run"
  b <- val(pre, f, metric); a <- val(fin, f, metric)
  grows_b <- b[[length(b)]] > b[[1L]]; grows_a <- a[[length(a)]] > a[[1L]]
  add(f, paste(metric, "(small, large)"), b[[length(b)]], a[[length(a)]], grows_b && !grows_a || a[[length(a)]] < b[[length(b)]],
      if (!grows_a) "count no longer grows" else if (a[[length(a)]] < b[[length(b)]]) "count reduced" else "NOT reduced")
}
for (f in c("F9", "F10")) {
  metric <- if (f == "F9") "token_seconds" else "build_seconds"
  b <- val(pre, f, metric); a <- val(fin, f, metric)
  add(f, paste(metric, "at the largest size"), b[[length(b)]], a[[length(a)]], a[[length(a)]] < b[[length(b)]],
      sprintf("time ratio %.2f", a[[length(a)]] / b[[length(b)]]))
}
b <- exponent_of(pre, "F8"); a <- exponent_of(fin, "F8")
add("F8", "seconds per fill growth exponent", b, a, a <= 1.10, "no per-fill growth")
for (spec in list(c("F11", "provider_builds"), c("F12", "canonical_json_calls_per_pulse"), c("F13", "context_vec_builds_per_pulse"))) {
  b <- val(pre, spec[[1L]], spec[[2L]]); a <- val(fin, spec[[1L]], spec[[2L]])
  add(spec[[1L]], spec[[2L]], b[[length(b)]], a[[length(a)]], isTRUE(all.equal(a, b, tolerance = 0.05)),
      "rejected: shape unchanged as recorded")
}
out <- do.call(rbind, rows)
utils::write.csv(out, args[[3L]], row.names = FALSE)
print(out, row.names = FALSE)
if (!all(out$ok)) cat("SOME VERDICTS FAILED\n") else cat("PROBE_VERDICTS_OK\n")
