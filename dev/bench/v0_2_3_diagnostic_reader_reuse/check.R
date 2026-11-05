args <- commandArgs(trailingOnly = TRUE)
record_dir <- if (length(args) > 0L) args[[1L]] else file.path("dev", "bench", "v0_2_3_diagnostic_reader_reuse", "records", "pre_correction")
review_correction <- file.exists(
  file.path(record_dir, "availability-build-summary.csv")
)
if (review_correction) {
  build <- utils::read.csv(
    file.path(record_dir, "availability-build-summary.csv"),
    stringsAsFactors = FALSE
  )
  readers <- utils::read.csv(
    file.path(record_dir, "availability-reader-summary.csv"),
    stringsAsFactors = FALSE
  )
  sequence <- utils::read.csv(
    file.path(record_dir, "availability-sequence-summary.csv"),
    stringsAsFactors = FALSE
  )
  stopifnot(
    nrow(build) == 2L,
    identical(as.character(build$source_commit), c("93e4b347", "f4ead35d")),
    all(build$decision_shape_rows == 3600000),
    all(build$membership_sets == 600L),
    length(unique(build$fixture_sha256)) == 1L,
    nrow(readers) == 2L,
    identical(readers$result_sha256[[1L]], readers$result_sha256[[2L]]),
    identical(readers$result_bytes[[1L]], readers$result_bytes[[2L]]),
    nrow(sequence) == 2L,
    identical(as.integer(sequence$validator_calls), c(17L, 1L)),
    identical(sequence$result_sha256[[1L]], sequence$result_sha256[[2L]]),
    file.exists(file.path(record_dir, "base-availability-plan.txt")),
    file.exists(file.path(record_dir, "candidate-availability-plan.txt"))
  )
  cat("DIAGNOSTIC_READER_REUSE_RECORD_OK\n")
  quit(save = "no", status = 0L)
}
build <- utils::read.csv(file.path(record_dir, "build-summary.csv"), stringsAsFactors = FALSE)
readers <- utils::read.csv(file.path(record_dir, "reader-summary.csv"), stringsAsFactors = FALSE)
post <- file.exists(file.path(record_dir, "same-handle-sequence.csv"))
if (!post) {
  stopifnot(
    nrow(build) == 2L,
    all(build$decision_shape_rows >= 3600000),
    identical(sort(unique(readers$label)), c("base", "candidate")),
    nrow(readers) == 12L,
    all(table(readers$label) == 6L)
  )
} else {
  sequence <- utils::read.csv(
    file.path(record_dir, "same-handle-sequence.csv"),
    stringsAsFactors = FALSE
  )
  availability <- utils::read.csv(
    file.path(record_dir, "availability-plan.csv"),
    stringsAsFactors = FALSE
  )
  stopifnot(
    nrow(build) == 1L,
    build$decision_shape_rows[[1L]] >= 3600000,
    nrow(readers) == 6L,
    readers$validator_calls[readers$surface %in% c(
      "summary", "point_explain", "history_explain"
    )] == 1L,
    nrow(sequence) == 1L,
    sequence$validator_calls[[1L]] == 1L,
    identical(as.character(availability$source_commit), c("93e4b347", "d24b081e")),
    length(unique(availability$result_bytes)) == 1L,
    availability$validator_elapsed_sec[[2L]] <
      availability$validator_elapsed_sec[[1L]],
    availability$peak_wset_mib[[2L]] < availability$peak_wset_mib[[1L]]
  )
}
stopifnot(
  all(is.finite(readers$elapsed_sec)),
  all(is.finite(readers$peak_wset_mib)),
  all(is.finite(readers$peak_private_mib))
)
cat("DIAGNOSTIC_READER_REUSE_RECORD_OK\n")
