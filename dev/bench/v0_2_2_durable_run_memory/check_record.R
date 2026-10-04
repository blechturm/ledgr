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
gate <- rows[rows$mode == "gate", , drop = FALSE]
marked <- rows[rows$mode == "phase", , drop = FALSE]
stopifnot(nrow(gate) == 4L * suite$pairs, nrow(marked) == 4L)

read_case <- function(name) jsonlite::read_json(
  file.path(record, "raw", name), simplifyVector = FALSE
)
same_outputs <- function(a, b) identical(a$identities, b$identities) &&
  identical(a$status, b$status)
phase_peak <- function(row) {
  value <- read_case(row$output_file[[1L]])
  marker <- if (is.null(suite$feature_phase_end_marker)) {
    "start_setup"
  } else {
    suite$feature_phase_end_marker
  }
  markers <- vapply(value$phases, `[[`, character(1L), "marker")
  peaks <- vapply(
    value$phases,
    function(x) as.numeric(x$peak_since_last_mib),
    numeric(1L)
  )
  hit <- which(markers == marker)
  stopifnot(length(hit) == 1L)
  peaks[[hit]]
}
summary_rows <- list()
calibration <- identical(suite$accepted_commit, suite$candidate_commit)
gate_profile <- if (is.null(suite$gate_profile)) "memory" else {
  suite$gate_profile
}
for (persistence in c("off", "on")) {
  part <- gate[gate$persistence == persistence, , drop = FALSE]
  accepted <- part[part$arm == "accepted", , drop = FALSE]
  candidate <- part[part$arm == "candidate", , drop = FALSE]
  accepted <- accepted[order(accepted$pair), , drop = FALSE]
  candidate <- candidate[order(candidate$pair), , drop = FALSE]
  stopifnot(identical(accepted$pair, candidate$pair))
  peak_ratio <- median(candidate$peak_rss_bytes / accepted$peak_rss_bytes)
  elapsed_ratio <- median(candidate$elapsed_s / accepted$elapsed_s)
  accepted_marked <- marked[
    marked$arm == "accepted" & marked$persistence == persistence,
    , drop = FALSE
  ]
  candidate_marked <- marked[
    marked$arm == "candidate" & marked$persistence == persistence,
    , drop = FALSE
  ]
  stopifnot(nrow(accepted_marked) == 1L, nrow(candidate_marked) == 1L)
  feature_phase_ratio <- phase_peak(candidate_marked) /
    phase_peak(accepted_marked)
  gated_peak_ratio <- if (identical(gate_profile, "dispatch")) {
    feature_phase_ratio
  } else {
    peak_ratio
  }
  summary_rows[[length(summary_rows) + 1L]] <- data.frame(
    persistence = persistence, pairs = nrow(accepted),
    peak_rss_ratio = peak_ratio, elapsed_ratio = elapsed_ratio,
    feature_phase_peak_ratio = feature_phase_ratio,
    peak_gate = if (calibration) {
      gated_peak_ratio >= 0.95 && gated_peak_ratio <= 1.05
    } else {
      gated_peak_ratio <= suite$peak_ratio_limit
    },
    elapsed_gate = if (calibration) {
      elapsed_ratio >= 0.95 && elapsed_ratio <= 1.05
    } else {
      elapsed_ratio <= suite$elapsed_ratio_limit
    }
  )
}
summary <- do.call(rbind, summary_rows)
utils::write.csv(summary, file.path(record, "summary.csv"), row.names = FALSE)
if (!all(summary$peak_gate) || !all(summary$elapsed_gate)) {
  stop(if (calibration) {
    "The same-commit calibration fell outside its 0.95 to 1.05 band"
  } else {
    "A registered unmarked gate missed; apply the recorded retry rule"
  })
}

oracles <- utils::read.csv(file.path(record, "oracles.csv"),
                           stringsAsFactors = FALSE)
for (persistence in c("off", "on")) {
  part <- oracles[oracles$persistence == persistence, , drop = FALSE]
  stopifnot(nrow(part) == 2L)
  stopifnot(same_outputs(read_case(part$output_file[part$arm == "accepted"]),
                         read_case(part$output_file[part$arm == "candidate"])))
}
dense <- utils::read.csv(file.path(record, "dense.csv"),
                         stringsAsFactors = FALSE)
stopifnot(nrow(dense) == 2L)
stopifnot(same_outputs(read_case(dense$output_file[[1L]]),
                       read_case(dense$output_file[[2L]])))

probe <- read_case(oracles$output_file[[1L]])
mutant <- probe
mutant$identities$equity$hash <- paste0("mutant-", mutant$identities$equity$hash)
stopifnot(!same_outputs(probe, mutant))
cat("DURABLE_MEMORY_CHECKS_OK\n")
