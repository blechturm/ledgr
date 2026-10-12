args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1L) {
  stop("Usage: Rscript check_record.R <evidence-dir>", call. = FALSE)
}

record_dir <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
read_record <- function(name) {
  path <- file.path(record_dir, name)
  if (!file.exists(path)) stop("Missing record: ", path, call. = FALSE)
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}

cases <- read_record("production_cases.csv")
seals <- read_record("production_seals.csv")
cost <- read_record("cost.csv")
encoder <- read_record("encoder.csv")
memory <- read_record("memory.csv")

expected_cases <- c(
  dense_baseline = "35d334c6526fc7b619a84084865a31d09f9ba5bd092a68bce8fed0b9f3c511db",
  fixed_block_boundary = "65daa3f64cb3c7c266048647736176a5e2e2a0a27df4560c9283860579152ef5",
  unicode_mixed_case = "2b21728cf9bd8f77aea3cec9e3f2f2faaf5a8f4c9224223d6c407cfb300d3583",
  dst_same_instant = "57e5d461f4e54d80fced636020010bf68a3e8c9972eb25f258c78b6a8db6e79b",
  numeric_edges = "7a7bd5b5bccbc6e601150cb83622a7a6a5e666426a5db7b0679df72909c74f49",
  all_fact_families = "6df946b7736a40d73e299509f559b5b35cd25e616e77d43cefc24293889d42c0",
  covered_value_mutation = "35d334c6526fc7b619a84084865a31d09f9ba5bd092a68bce8fed0b9f3c511db"
)
actual_cases <- stats::setNames(cases$root, cases$case)
if (!identical(unname(actual_cases[names(expected_cases)]), unname(expected_cases))) {
  stop("Production roots do not match the accepted rule-3 corpus.", call. = FALSE)
}
equal_rows <- cases$relation == "equal"
different_rows <- cases$relation == "different"
if (any(cases$root[equal_rows] != cases$comparison_root[equal_rows]) ||
    any(cases$root[different_rows] == cases$comparison_root[different_rows])) {
  stop("At least one rule-3 relation failed.", call. = FALSE)
}
if (!all(seals$identical)) {
  stop("A schema-valid production seal moved a rule-3 root.", call. = FALSE)
}

median_by_rows <- function(x, column) {
  aggregate(x[[column]], list(rows = x$rows), stats::median)
}
cost_medians <- median_by_rows(cost, "microseconds_per_bar")
if (any(cost_medians$x > 1.5)) {
  stop("Complete verification exceeded 1.5 microseconds per bar.", call. = FALSE)
}
cost_summary <- aggregate(elapsed_seconds ~ rows, cost, stats::median)
cost_fit <- stats::lm(log(elapsed_seconds) ~ log(rows), data = cost_summary)
cost_exponent <- unname(stats::coef(cost_fit)[[2L]])
if (!is.finite(cost_exponent) || cost_exponent > 1.10) {
  stop("Complete verification growth exponent exceeded 1.10.", call. = FALSE)
}

for (n in unique(cost$rows)) {
  roots <- unique(cost$root[cost$rows == n])
  if (length(roots) != 1L) stop("Cost repetitions moved a root.", call. = FALSE)
}
if (any(!is.finite(encoder$microseconds_per_bar)) ||
    any(encoder$microseconds_per_bar <= 0)) {
  stop("Encoder record is incomplete.", call. = FALSE)
}
if (!all(c("bars", "facts") %in% memory$kind) ||
    any(!is.finite(memory$peak_rss_bytes)) ||
    any(memory$peak_rss_bytes <= 0)) {
  stop("Memory disclosure is incomplete.", call. = FALSE)
}

cat(sprintf(
  paste0(
    "LEDGR_RULE3_RECORD_OK cases=%d seals=%d max_us_per_bar=%.3f ",
    "growth_exponent=%.3f\n"
  ),
  nrow(cases), nrow(seals), max(cost_medians$x), cost_exponent
))
