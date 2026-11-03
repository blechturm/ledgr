# Compare a candidate successor record with the immutable 0d6c0b11 record.
# Only the accepted INCOMPLETE annualized-return correction may differ.
# Usage: Rscript compare.R --base=<dir> --candidate=<dir>

args <- commandArgs(trailingOnly = TRUE)
arg <- function(name) {
  hit <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (!length(hit)) stop(sprintf("missing --%s", name), call. = FALSE)
  sub(paste0("^--", name, "="), "", hit[[1L]])
}
base <- normalizePath(arg("base"), winslash = "/")
candidate <- normalizePath(arg("candidate"), winslash = "/")
read_manifest <- function(path) {
  utils::read.csv(file.path(path, "manifest.csv"), colClasses = "character")
}
verify_manifest <- function(path, manifest) {
  actual <- list.files(path, recursive = TRUE, all.files = FALSE, no.. = TRUE)
  actual <- gsub("\\\\", "/", actual)
  actual <- sort(setdiff(actual, "manifest.csv"), method = "radix")
  expected <- sort(gsub("\\\\", "/", manifest$file), method = "radix")
  if (!identical(actual, expected)) {
    stop(sprintf("successor A0 manifest file set is stale: %s", path), call. = FALSE)
  }
  located <- file.path(path, manifest$file)
  bytes <- vapply(located, function(file) sprintf("%d", as.integer(file.size(file))), character(1))
  hashes <- vapply(located, digest::digest, character(1), algo = "sha256", file = TRUE)
  if (!identical(unname(bytes), manifest$bytes) ||
      !identical(unname(hashes), manifest$sha256)) {
    stop(sprintf("successor A0 manifest hashes are stale: %s", path), call. = FALSE)
  }
  invisible(TRUE)
}
base_manifest <- read_manifest(base)
candidate_manifest <- read_manifest(candidate)
verify_manifest(base, base_manifest)
verify_manifest(candidate, candidate_manifest)
if (!identical(base_manifest$file, candidate_manifest$file)) {
  stop("successor A0 file sets differ", call. = FALSE)
}
allowed <- c(
  "avail_incomplete/sweep_w1/sweep.csv",
  "avail_incomplete/sweep_w2/sweep.csv"
)
changed <- base_manifest$file[base_manifest$sha256 != candidate_manifest$sha256]
if (!identical(sort(changed, method = "radix"), sort(allowed, method = "radix"))) {
  stop(sprintf("unexpected changed successor A0 files: %s", paste(changed, collapse = ", ")), call. = FALSE)
}
for (file in allowed) {
  before <- utils::read.csv(
    file.path(base, file), colClasses = "character", na.strings = "NA",
    check.names = FALSE
  )
  after <- utils::read.csv(
    file.path(candidate, file), colClasses = "character", na.strings = "NA",
    check.names = FALSE
  )
  annualized <- "annualized_return:numeric"
  other <- names(before) != annualized
  if (!identical(names(before), names(after)) ||
      !annualized %in% names(before) || nrow(before) != 2L ||
      !identical(before[other], after[other])) {
    stop(sprintf("%s differs outside the accepted field", file), call. = FALSE)
  }
  if (!identical(before[[annualized]], c("0", "0")) ||
      !identical(after[[annualized]], c(NA_character_, NA_character_))) {
    stop(sprintf("%s does not contain the accepted values", file), call. = FALSE)
  }
}
cat("successor A0 compare: PASS (281 files; four accepted annualized_return cells)\n")
