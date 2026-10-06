args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1L) stop("Usage: check_record.R <record_dir>")
record <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
measurements <- utils::read.csv(file.path(record, "measurements.csv"))
summary <- utils::read.csv(file.path(record, "summary.csv"))
parity <- utils::read.csv(file.path(record, "parity.csv"))
decision <- utils::read.csv(file.path(record, "decision.csv"))

stopifnot(
  nrow(measurements) %in% c(9L, 18L),
  all(table(measurements$attempt, measurements$arm) == 3L),
  all(parity$identical), isTRUE(decision$parity),
  isTRUE(decision$plane_gate), isTRUE(decision$loop_gate)
)
for (attempt in unique(measurements$attempt)) {
  rows <- measurements[measurements$attempt == attempt, , drop = FALSE]
  medians <- vapply(split(rows$elapsed_s, rows$arm), median, numeric(1))
  recorded <- summary[summary$attempt == attempt, , drop = FALSE]
  stopifnot(
    isTRUE(all.equal(
      recorded$plane_over_candidate_loop,
      medians[["candidate_plane"]] / medians[["candidate_bundle"]]
    )),
    isTRUE(all.equal(
      recorded$candidate_loop_over_pre_cut_loop,
      medians[["candidate_bundle"]] / medians[["pre_cut_bundle"]]
    ))
  )
}
if (any(summary$plane_over_candidate_loop > 0.90 |
        summary$candidate_loop_over_pre_cut_loop > 1.05)) {
  stopifnot(
    nrow(summary) == 2L,
    identical(summary$attempt, c("initial", "retry"))
  )
}
stopifnot(file.exists(file.path(record, "commands.txt")))
cat("LEDGR_WS16_RECORD_OK\n")
