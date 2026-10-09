# Aggregate view of a record (Cut 11 LDG-2982).
#
#   Rscript summarize_record.R <record_dir> <out_csv>
#
# Writes one row per family: name, data rows and the sha256 of the family
# file, plus the phase clocks. A Sharadar record keeps its families in the
# private store; only this summary leaves it. check_record.R compares the full
# records there; equal hashes here mean equal families.

args <- commandArgs(trailingOnly = TRUE)
record <- args[[1L]]
fam <- list.files(file.path(record, "families"), pattern = "\\.csv$", full.names = TRUE)
rows <- vapply(fam, function(f) length(readLines(f, warn = FALSE)) - 1L, integer(1))
out <- data.frame(
  family = sub("\\.csv$", "", basename(fam)),
  rows = unname(rows),
  sha256 = vapply(fam, function(f) digest::digest(file = f, algo = "sha256"), character(1), USE.NAMES = FALSE),
  stringsAsFactors = FALSE
)
utils::write.csv(out, args[[2L]], row.names = FALSE)
phases <- file.path(record, "phases.csv")
if (file.exists(phases)) {
  ph <- utils::read.csv(phases)
  ph$elapsed_s <- round(ph$end - ph$start, 3)
  utils::write.csv(ph[, c("phase", "elapsed_s")], sub("\\.csv$", "_phases.csv", args[[2L]]), row.names = FALSE)
}
cat("SUMMARY_OK", nrow(out), "families\n")
