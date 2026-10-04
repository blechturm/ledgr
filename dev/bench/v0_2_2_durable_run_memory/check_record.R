bench_lib <- Sys.getenv("LEDGR_BENCH_LIB", "")
if (nzchar(bench_lib)) .libPaths(c(bench_lib, .libPaths()))

args <- commandArgs(TRUE)
if (length(args) != 1L) stop("Usage: check_record.R <record_dir>")
record <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
suite <- jsonlite::read_json(file.path(record, "suite.json"),
                            simplifyVector = TRUE)
rows <- utils::read.csv(file.path(record, "measurements.csv"),
                        stringsAsFactors = FALSE)
stopifnot(suite$pairs >= 5L)
gate <- rows[!rows$marked, , drop = FALSE]
marked <- rows[rows$marked, , drop = FALSE]
stopifnot(nrow(gate) == 4L * suite$pairs, nrow(marked) == 4L)

read_case <- function(name) jsonlite::read_json(
  file.path(record, "raw", name), simplifyVector = FALSE
)
same_outputs <- function(a, b) identical(a$identities, b$identities) &&
  identical(a$status, b$status)
summary_rows <- list()
for (persistence in c("off", "on")) {
  part <- gate[gate$persistence == persistence, , drop = FALSE]
  accepted <- part[part$arm == "accepted", , drop = FALSE]
  candidate <- part[part$arm == "candidate", , drop = FALSE]
  accepted <- accepted[order(accepted$pair), , drop = FALSE]
  candidate <- candidate[order(candidate$pair), , drop = FALSE]
  stopifnot(identical(accepted$pair, candidate$pair))
  for (i in seq_len(nrow(accepted))) {
    stopifnot(same_outputs(read_case(accepted$output_file[[i]]),
                           read_case(candidate$output_file[[i]])))
  }
  peak_ratio <- median(candidate$peak_rss_bytes / accepted$peak_rss_bytes)
  elapsed_ratio <- median(candidate$elapsed_s / accepted$elapsed_s)
  summary_rows[[length(summary_rows) + 1L]] <- data.frame(
    persistence = persistence, pairs = nrow(accepted),
    peak_rss_ratio = peak_ratio, elapsed_ratio = elapsed_ratio,
    peak_gate = peak_ratio <= suite$peak_ratio_limit,
    elapsed_gate = elapsed_ratio <= suite$elapsed_ratio_limit
  )
}
summary <- do.call(rbind, summary_rows)
utils::write.csv(summary, file.path(record, "summary.csv"), row.names = FALSE)
if (!all(summary$peak_gate) || !all(summary$elapsed_gate)) {
  stop("A registered unmarked gate missed; apply the recorded retry rule")
}

dense <- utils::read.csv(file.path(record, "dense.csv"),
                         stringsAsFactors = FALSE)
stopifnot(nrow(dense) == 2L)
stopifnot(same_outputs(read_case(dense$output_file[[1L]]),
                       read_case(dense$output_file[[2L]])))

probe <- read_case(gate$output_file[[1L]])
mutant <- probe
mutant$identities$equity$hash <- paste0("mutant-", mutant$identities$equity$hash)
stopifnot(!same_outputs(probe, mutant))
cat("DURABLE_MEMORY_CHECKS_OK\n")
