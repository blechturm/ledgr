args <- commandArgs(TRUE)
if (length(args) != 1L) stop("Usage: summarize_record.R <record_dir>")
record <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
measurements <- utils::read.csv(
  file.path(record, "measurements.csv"), stringsAsFactors = FALSE
)
processes <- utils::read.csv(
  file.path(record, "processes.csv"), stringsAsFactors = FALSE
)

initial <- measurements[measurements$attempt == "initial", , drop = FALSE]
summary <- do.call(rbind, lapply(unique(initial$shape_id), function(shape) {
  part <- initial[initial$shape_id == shape, , drop = FALSE]
  accepted <- part[part$arm == "accepted", , drop = FALSE]
  candidate <- part[part$arm == "candidate", , drop = FALSE]
  accepted <- accepted[order(accepted$pair), , drop = FALSE]
  candidate <- candidate[order(candidate$pair), , drop = FALSE]
  data.frame(
    shape_id = shape,
    pairs = nrow(accepted),
    accepted_cold_median_s = median(accepted$cold_s),
    candidate_cold_median_s = median(candidate$cold_s),
    cold_pair_ratio_median = median(candidate$cold_s / accepted$cold_s),
    accepted_warm_median_s = median(accepted$warm_s),
    candidate_warm_median_s = median(candidate$warm_s),
    warm_pair_ratio_median = median(candidate$warm_s / accepted$warm_s),
    retry = shape %in% measurements$shape_id[
      measurements$attempt == "retry"
    ],
    stringsAsFactors = FALSE
  )
}))
summary$peak_rss_bytes <- vapply(summary$shape_id, function(shape) {
  max(processes$peak_rss_bytes[processes$shape_id == shape])
}, numeric(1L))
utils::write.csv(summary, file.path(record, "summary.csv"), row.names = FALSE)

# Process logs are evidence text, but toolchains may append terminal spaces to
# diagnostic lines. Preserve every line while making the checked-in record
# pass the repository whitespace contract.
logs <- list.files(file.path(record, "raw"), pattern = "[.](stdout|stderr)$",
                   full.names = TRUE)
for (log in logs) {
  lines <- readLines(log, warn = FALSE)
  writeLines(sub("[ \t]+$", "", lines), log, useBytes = TRUE)
}

normalized_hash <- function(path) {
  bytes <- readBin(path, "raw", n = file.info(path)$size)
  text <- rawToChar(bytes)
  text <- gsub("\r\n", "\n", text, fixed = TRUE)
  digest::digest(charToRaw(text), algo = "sha256", serialize = FALSE)
}
files <- list.files(record, recursive = TRUE, full.names = TRUE)
files <- files[!dir.exists(files)]
files <- files[basename(files) != "record_hashes.csv"]
relative <- substring(normalizePath(files, winslash = "/"),
                      nchar(record) + 2L)
hashes <- data.frame(
  path = relative,
  sha256_lf = vapply(files, normalized_hash, character(1L)),
  stringsAsFactors = FALSE
)
hashes <- hashes[order(hashes$path), , drop = FALSE]
utils::write.csv(hashes, file.path(record, "record_hashes.csv"),
                 row.names = FALSE)
cat("LWREG_SUMMARY_OK", nrow(summary), nrow(hashes), "\n")
