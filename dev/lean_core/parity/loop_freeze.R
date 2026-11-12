# LDG-3220 freeze (Cut 14, R1-R2): the execution paths and the variant
# manifest of the slice-1 lean loop at 4a3e08b8, taken from that commit's
# evidence CSVs before the restructure. loop_parity.R --freeze checks every
# later run against loop_freeze.csv; loop_variants.R runs loop_variants.csv.
#
#   Rscript dev/lean_core/parity/loop_freeze.R
#
# loop_freeze.csv: one row per workload, mode (gate, batch1, inert) and
# debug setting: lean folds, refusals and backstop marks of the lean arm.
# loop_variants.csv: one row per variant, workload, debug setting and batch
# bound, with the signal the variant expects.

here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
ev <- file.path(here, "evidence")
paths <- function(file, mode) {
  x <- utils::read.csv(file.path(ev, file), stringsAsFactors = FALSE, na.strings = character(),
                       colClasses = c(refused = "character", backstop = "character"))
  # the merged evidence CSVs carry an empty record as NA
  for (col in c("refused", "backstop")) x[[col]][is.na(x[[col]]) | x[[col]] == "NA"] <- ""
  x <- unique(x[, c("workload", "debug", "lean_folds", "refused", "backstop")])
  if (anyDuplicated(x[, c("workload", "debug")])) stop(file, ": a workload has more than one execution path")
  cbind(mode = mode, x)
}
freeze <- rbind(paths("loop_gate_debug0.csv", "gate"), paths("loop_gate_debug1.csv", "gate"),
                paths("loop_batch1.csv", "batch1"), paths("loop_inert.csv", "inert"))
freeze <- freeze[order(freeze$mode, freeze$workload, freeze$debug), ]
utils::write.csv(freeze, file.path(here, "loop_freeze.csv"), row.names = FALSE)

variants <- do.call(rbind, lapply(c("loop_mutations.csv", "loop_mutations_debug1.csv"), function(f) {
  x <- utils::read.csv(file.path(ev, f), stringsAsFactors = FALSE, na.strings = character())
  unique(x[, c("mutation", "workload", "debug", "batch_rows", "expect", "verdict")])
}))
if (!all(variants$verdict == "CAUGHT")) stop("the 4a3e08b8 manifest holds a variant that was not caught")
variants$verdict <- NULL
variants <- variants[order(variants$mutation, variants$debug, variants$workload), ]
utils::write.csv(variants, file.path(here, "loop_variants.csv"), row.names = FALSE)
cat(sprintf("freeze: %d rows (%s); variants: %d rows, %d variants\n", nrow(freeze),
            paste(names(table(freeze$mode)), table(freeze$mode), collapse = ", "), nrow(variants),
            length(unique(variants$mutation))))
