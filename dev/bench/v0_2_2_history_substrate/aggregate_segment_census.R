args <- commandArgs(trailingOnly = TRUE)
root <- if (length(args) > 0L) args[[1L]] else "."
root <- normalizePath(root, winslash = "/", mustWork = TRUE)

input_path <- file.path(
  root,
  "dev", "bench", "v0_2_2_sharadar_run", "evidence", "ws39_schema120",
  "build_summary.csv"
)
input <- utils::read.csv(input_path, stringsAsFactors = FALSE)
value <- stats::setNames(input$value, input$key)
required <- c(
  "bars", "instruments", "open_sessions", "membership_rows",
  "membership_sets", "lifetime_rows", "fact_families"
)
if (!all(required %in% names(value))) {
  stop("The WS39 aggregate record is incomplete.", call. = FALSE)
}
number <- function(name) as.numeric(value[[name]])

n_instruments <- number("instruments")
n_sets <- number("membership_sets")
n_membership <- number("membership_rows")
membership_fact_total <- n_instruments * n_sets + n_membership
membership_segment_bound <- n_instruments * (n_sets + 1)

out <- data.frame(
  family = c(
    "membership", "trading_status", "lifetime", "lifetime_terminal"
  ),
  instrument_count = n_instruments,
  source_fact_rows = c(
    n_membership, 0, number("lifetime_rows"), NA_real_
  ),
  prepared_fact_count = c(membership_fact_total, 0, NA_real_, NA_real_),
  segment_count = c(
    membership_segment_bound, n_instruments, NA_real_, NA_real_
  ),
  aggregate_ratio = c(
    membership_segment_bound / membership_fact_total,
    1,
    NA_real_,
    NA_real_
  ),
  maximum_ratio_bound = c(
    (n_sets + 1) / n_sets, 1, NA_real_, NA_real_
  ),
  default_guard = c(
    "passes_by_bound", "passes_exactly", "needs_full_census",
    "needs_full_census"
  ),
  stringsAsFactors = FALSE
)

output_path <- file.path(
  root,
  "dev", "bench", "v0_2_2_history_substrate", "evidence",
  "ws41_aggregate_segment_census", "aggregate_census.csv"
)
utils::write.csv(out, output_path, row.names = FALSE, na = "")
cat(sprintf(
  "LEDGR_WS41_AGGREGATE_CENSUS_OK membership_ratio_bound=%.9f\n",
  out$maximum_ratio_bound[[1L]]
))
