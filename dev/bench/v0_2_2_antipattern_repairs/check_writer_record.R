args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1L) {
  stop("usage: check_writer_record.R <record.csv>", call. = FALSE)
}

record <- utils::read.csv(args[[1L]], stringsAsFactors = FALSE)
required <- c(
  "arm", "pair", "sample", "fills_per_pulse", "elapsed_sec",
  "event_rows", "fill_rows", "event_hash", "fill_hash"
)
stopifnot(identical(names(record), required))
stopifnot(identical(sort(unique(record$arm)), c("candidate", "pre_cut")))
stopifnot(identical(sort(unique(record$pair)), 1:3))
stopifnot(all(record$fills_per_pulse >= 2000L))
stopifnot(all(record$event_rows == record$fill_rows))

for (pair in sort(unique(record$pair))) {
  rows <- record[record$pair == pair, , drop = FALSE]
  stopifnot(length(unique(rows$event_hash)) == 1L)
  stopifnot(length(unique(rows$fill_hash)) == 1L)
}

medians <- stats::aggregate(
  elapsed_sec ~ arm + pair,
  data = record,
  FUN = stats::median
)
wide <- reshape(
  medians,
  idvar = "pair",
  timevar = "arm",
  direction = "wide"
)
wide$ratio <- wide$elapsed_sec.candidate / wide$elapsed_sec.pre_cut
stopifnot(all(is.finite(wide$ratio)))
cat(sprintf(
  "LEDGR_WS17_WRITER_OK paired_median_ratio=%.6f\n",
  stats::median(wide$ratio)
))

