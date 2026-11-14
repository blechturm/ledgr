# Cut 17 (WS35 final check): compares the two arms of adversarial_probe.R
# (contents, attributes and their order, numeric bits, Encoding() marks,
# conditions without trace, signals, notes). Exits 1 on any mismatch inside the
# contract. A universe marked "bytes" is outside it (maintainer decision
# 2026-11-14: ledgr builds the universe from DuckDB, never "bytes"); those
# cases are counted and listed, not failed.
#   Rscript dev/bench/v0_2_3_helper/adversarial_compare.R --out=<dir>
args <- commandArgs(TRUE)
out <- sub("^--out=", "", grep("^--out=", args, value = TRUE)[[1L]])
p <- readRDS(file.path(out, "probe_pin.rds"))
c <- readRDS(file.path(out, "probe_candidate.rds"))
stopifnot(identical(names(p$results), names(c$results)))
# Compare contents and encoding marks, not ALTREP serialization representation.
eq <- function(a, b) {
  if (!identical(typeof(a), typeof(b)) || length(a) != length(b)) return(FALSE)
  aa <- attributes(a)
  ba <- attributes(b)
  if (!identical(names(aa), names(ba))) return(FALSE)
  if (length(aa) && !all(vapply(seq_along(aa), function(i) eq(aa[[i]], ba[[i]]), TRUE))) return(FALSE)
  if (is.language(a)) return(identical(a, b))
  attributes(a) <- NULL
  attributes(b) <- NULL
  if (is.list(a)) return(all(vapply(seq_along(a), function(i) eq(a[[i]], b[[i]]), TRUE)))
  if (is.character(a)) return(identical(a, b) && identical(Encoding(a), Encoding(b)))
  if (is.double(a)) return(identical(writeBin(a, raw()), writeBin(b, raw())))
  identical(a, b)
}
bad <- names(p$results)[!vapply(names(p$results), function(n) eq(p$results[[n]], c$results[[n]]), TRUE)]
outside <- grepl("^encoding/[0-9]+/[^/]+/bytes/", names(p$results))
bad_outside <- intersect(bad, names(p$results)[outside])
bad <- setdiff(bad, bad_outside)
cat("probe cases:", length(p$results), "in contract:", sum(!outside), "mismatches:", length(bad), "\n")
cat("byte-marked universe (outside the contract):", sum(outside), "cases,", length(bad_outside), "differ\n")
nonencoding <- names(p$results)[!startsWith(names(p$results), "encoding/")]
cat("non-encoding cases:", length(nonencoding), "equal:", sum(!nonencoding %in% bad), "\n")
cat("preserved amount class:", class(c$results[["40/ids/plain/list/amount"]]$value), "\n")
summary <- data.frame(case = names(p$results), contract = !outside, equal = !names(p$results) %in% c(bad, bad_outside),
  pin = vapply(p$results, function(r) if (is.null(r$error)) "value" else r$error$message, ""),
  candidate = vapply(c$results, function(r) if (is.null(r$error)) "value" else r$error$message, ""))
write.csv(summary, file.path(out, "probe_comparison.csv"), row.names = FALSE)
if (length(bad)) { print(summary[!summary$equal & summary$contract, ], row.names = FALSE); quit(status = 1L) }
