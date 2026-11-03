args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1L) stop("usage: Rscript gut.R <record.csv>")
here <- dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]))
source(file.path(here, "lib.R"))
record <- utils::read.csv(args[[1L]], stringsAsFactors = FALSE)
base <- record$bytes_per_call[record$label == "base" & record$helper == "wide"]
record$bytes_per_call[record$label == "candidate" & record$helper == "wide"] <- base * 2
problems <- cut10_allocation_problems(record)
if (!identical(problems, "wide allocation did not improve")) {
  stop("gutted wide-allocation record was not detected")
}
cat("PULSE_INSPECTION_ALLOCATION_GUT_OK\n")
