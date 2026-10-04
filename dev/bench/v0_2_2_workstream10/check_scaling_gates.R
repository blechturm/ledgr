args <- commandArgs(trailingOnly = TRUE)
evidence <- if (length(args) >= 1L) {
  args[[1L]]
} else {
  file.path("dev", "bench", "v0_2_2_workstream10", "evidence")
}

read_record <- function(name) {
  utils::read.csv(file.path(evidence, name), stringsAsFactors = FALSE)
}
timings <- read_record("timings.csv")
ratios <- read_record("pair_ratios.csv")
calibration <- read_record("calibration.csv")
summary <- read_record("summary.csv")
identities <- read_record("identities.csv")
elements <- read_record("element_counts.csv")
mutations <- read_record("mutations.csv")
environment <- read_record("environment.csv")

stopifnot(
  identical(nrow(ratios[ratios$boundary == "in_memory_assertion", ]), 3L),
  identical(nrow(ratios[ratios$boundary == "public_facts_resolve", ]), 3L),
  identical(nrow(ratios[ratios$boundary == "low_repetition_assertion", ]), 5L),
  all(ratios$exact),
  all(timings$exact),
  all(identities$exact),
  all(elements$exact),
  all(elements$formatted_elements <= elements$distinct_nonmissing),
  all(mutations$detected),
  all(summary$passed),
  tail(calibration$current_seconds, 1L) >= 1,
  tail(calibration$candidate_seconds, 1L) >= 1,
  environment$large_fact_rows[[1L]] == 300000L,
  environment$large_bar_rows[[1L]] == 500L,
  environment$low_total_rows[[1L]] ==
    3L * environment$low_rows_per_family[[1L]]
)
message("WORKSTREAM10_SCALING_GATE_RECORD_OK")
