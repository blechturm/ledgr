# Golden-table check for the installed package (LDG-3161; ws2_rng_design.md
# Section 2.5). Executes the installed production ledgr_pulse_seeds against
# the fixed golden fixture and prints the platform identity and every integer.
#
# Usage: Rscript golden_platform.R <fixture.csv> [<library>]
args <- commandArgs(trailingOnly = TRUE)
if (length(args) >= 2L) .libPaths(c(args[[2L]], .libPaths()))
golden <- utils::read.csv(args[[1L]], colClasses = c("numeric", "numeric", "integer"))
suppressPackageStartupMessages(library(ledgr))
ns <- asNamespace("ledgr")
got <- integer(nrow(golden))
for (s in unique(golden$execution_seed)) {
  rows <- which(golden$execution_seed == s)
  got[rows] <- ns$ledgr_pulse_seeds(as.integer(s), golden$pulse_idx[rows])
}
cat("R:", R.version.string, "| platform:", R.version$platform, "| os:",
  paste(Sys.info()[c("sysname", "release", "machine")], collapse = " "), "\n")
cat("ledgr:", as.character(packageVersion("ledgr")), "from", find.package("ledgr"),
  "| rule constant:", ns$ledgr_pulse_seed_rule_version, "| duckdb:", as.character(packageVersion("duckdb")), "\n")
cat("execution_seed,pulse_idx,pulse_seed\n")
cat(sprintf("%.0f,%.0f,%d\n", golden$execution_seed, golden$pulse_idx, got), sep = "")
mismatches <- sum(got != golden$pulse_seed)
cat("MATCH", identical(got, golden$pulse_seed), "rows", nrow(golden), "mismatches", mismatches, "\n")
quit(status = if (mismatches == 0L && nrow(golden) == 63L) 0L else 1L)
