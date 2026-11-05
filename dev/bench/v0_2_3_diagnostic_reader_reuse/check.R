args <- commandArgs(trailingOnly = TRUE)
record_dir <- if (length(args) > 0L) args[[1L]] else file.path("dev", "bench", "v0_2_3_diagnostic_reader_reuse", "records", "pre_correction")
build <- utils::read.csv(file.path(record_dir, "build-summary.csv"), stringsAsFactors = FALSE)
readers <- utils::read.csv(file.path(record_dir, "reader-summary.csv"), stringsAsFactors = FALSE)
stopifnot(nrow(build) == 2L, all(build$decision_shape_rows >= 3600000),
          identical(sort(unique(readers$label)), c("base", "candidate")), nrow(readers) == 12L,
          all(table(readers$label) == 6L), all(is.finite(readers$elapsed_sec)),
          all(is.finite(readers$peak_wset_mib)), all(is.finite(readers$peak_private_mib)))
cat("DIAGNOSTIC_READER_REUSE_RECORD_OK\n")
