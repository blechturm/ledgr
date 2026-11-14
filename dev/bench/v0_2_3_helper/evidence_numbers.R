# Cut 17 (close-review correction, finding 6): every number quoted in
# LDG-3232's and LDG-3233's evidence, computed from the committed CSVs, so
# the ticket text can be checked against this output.
#
#   Rscript dev/bench/v0_2_3_helper/evidence_numbers.R

here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
repo <- normalizePath(file.path(here, "..", "..", ".."), winslash = "/")
res <- file.path(here, "results")
rd <- function(...) utils::read.csv(file.path(...), stringsAsFactors = FALSE)
cell <- function(v, n) paste0(substr(v, 1, 3), "_", n)
cols <- c("reb_10", "reb_500", "reb_1166", "adj_10", "adj_500", "adj_1166")

t <- rd(res, "measure_base", "timings.csv")
cat("measure_base timings (us per call, first use / cached):\n")
for (i in seq_len(nrow(t))) cat(sprintf("  %-9s %4d  %.0f / %.0f  (resolution share %.1e)\n", t$verb[i], t$instruments[i],
                                         t$first_use_us[i], t$cached_us[i], t$resolution_share[i]))
cat(sprintf("  first-use views %d-%d, cached calls %d-%d\n", min(t$first_use_calls), max(t$first_use_calls), min(t$cached_calls), max(t$cached_calls)))

s <- rd(res, "measure_base", "sites_timing.csv")
s$cell <- cell(s$verb, s$instruments)
cat("\nsites: executed share of the call (percent), whole-call sites marked *; S15_16 is inside S17 and not summed:\n")
whole <- c("S12a", "S12b", "S13", "S14", "S15_16", "S17")
parts <- unique(s$part)
for (p in parts) {
  v <- vapply(cols, function(cc) { x <- s[s$part == p & s$cell == cc, ]; if (!nrow(x)) "-" else if (!x$executed) "(not run)"
                                   else sprintf("%.1f", 100 * x$share_of_call) }, "")
  cat(sprintf("  %-7s%s %s\n", p, if (p %in% whole) "*" else " ", paste(v, collapse = " / ")))
}
tot <- vapply(cols, function(cc) 100 * sum(s$share_of_call[s$cell == cc & s$executed & s$part != "S15_16"]), 0)
cat("  executed total:", paste(sprintf("%.1f", tot), collapse = " / "), "\n")
sitesum <- function(prefix) vapply(cols, function(cc) {
  x <- s[s$cell == cc & s$executed & startsWith(s$part, prefix), ]; if (!nrow(x)) NA_real_ else 100 * sum(x$share_of_call) }, 0)
cat("  S01 (a+b):", paste(sprintf("%.1f", sitesum("S01")), collapse = " / "), "\n")
calls <- unique(s[, c("cell", "call_us")]); cat("  call us:", paste(sprintf("%s %.0f", calls$cell, calls$call_us), collapse = ", "), "\n")

f <- rd(res, "fmatch_compare.csv")
cat("\nfmatch / match ratio:", paste(sprintf("%d %s %.2f", f$instruments, f$shape, f$ratio), collapse = "; "), "\n")

ck <- function(label) {
  x <- utils::read.csv(file.path(repo, "dev/bench/timing/records/cut17-helper-1", label, "attempt-1", "raw.csv"),
                       stringsAsFactors = FALSE)
  x <- x[x$outcome == "ok", ]
  r <- vapply(unique(x$cell), function(cc) {
    stats::median(x$seconds[x$cell == cc & x$arm == "candidate"]) / stats::median(x$seconds[x$cell == cc & x$arm == "base"]) }, 0)
  rng <- range(x$seconds[x$arm == "candidate" & x$cell != "run_slice2_10x7200"])
  rb <- range(x$seconds[x$arm == "base" & x$cell != "run_slice2_10x7200"])
  cat(sprintf("%s: %s; helper batches candidate %.2f-%.2f s, base %.2f-%.2f s\n", label,
              paste(sprintf("%s %.3f", names(r), r), collapse = ", "), rng[1], rng[2], rb[1], rb[2]))
}
cat("\n")
for (l in c("ldg3232-base-base", "ldg3232-base-base-2", "ldg3233-match-vs-gated", "ldg3233-close", "ldg3233-close-2", "ldg3233-close-3", "ldg3233-close-4", "ldg3233-close-5", "ldg3233-close-6")) ck(l)

for (d in c("lean_helper", "lean_helper_r1", "lean_helper_r2", "lean_helper_r3", "lean_helper_final")) {
  x <- rd(res, d, "lean_helper_summary.csv")
  cat(sprintf("\n%s: fold %.0f -> %.0f us/pulse (saving %.1f%%), run saving %.1f%%", d, x$fold_us_per_pulse_base,
              x$fold_us_per_pulse_cand, 100 * x$fold_saving_median, 100 * x$run_saving_median))
}
cat("\n")
for (od in c("oracle_ldg3233_r1", "oracle_ldg3233_r2", "oracle_ldg3233_r3", "oracle_ldg3233_final")) {
  o <- rd(res, od, "oracle_check.csv"); cat(sprintf("\n%s: %d checks, %d as required", od, nrow(o), sum(o$ok)))
}
ins <- rd(res, "lean_helper", "insitu.csv")
ins_m <- aggregate(cbind(helper_us_per_call, read_us_per_call) ~ arm, ins, mean)
cat(sprintf("\ninsitu (lean slice2; base = pin, candidate = a564a226; mean of 3 runs): %s\n",
            paste(sprintf("%s helper %.0f us per call, column reads %.0f us", ins_m$arm, ins_m$helper_us_per_call,
                          ins_m$read_us_per_call), collapse = "; ")))
m <- utils::read.csv(file.path(here, "manifest.csv"), colClasses = "character")
cat(sprintf("manifest: %d cases (%d value, %d error), %d sites\n", nrow(m), sum(m$expect == "value"), sum(m$expect != "value"),
            nrow(rd(here, "sites.csv"))))
oc <- rd(res, "oracle_ldg3233_final_old_candidate.csv")
cat(sprintf("old candidate 5eb67e6d against the final manifest: %d differences, cases %s\n", nrow(oc), paste(unique(oc$case), collapse = ", ")))
a <- rd(res, "adversarial_final", "probe_comparison.csv")
cat(sprintf("adversarial: %d cases, %d in contract with %d mismatches; %d byte-marked-universe cases outside, %d differ\n",
            nrow(a), sum(a$contract), sum(a$contract & !a$equal), sum(!a$contract), sum(!a$contract & !a$equal)))
