args <- commandArgs(trailingOnly = TRUE)
record_dir <- if (length(args)) args[[1L]] else file.path(
  "dev", "bench", "v0_2_2_history_manifestation", "evidence", "run"
)
read_record <- function(name) {
  utils::read.csv(file.path(record_dir, name), stringsAsFactors = FALSE)
}
measurements <- read_record("measurements.csv")
slopes <- read_record("slopes.csv")
parity <- read_record("parity.csv")
source_scale <- read_record("source_scale.csv")
environment <- read_record("environment.csv")

focal <- measurements[
  measurements$axis == "instrument" & measurements$size == 500L,
]
focal <- stats::aggregate(
  cbind(median_us, payload_copies) ~ path,
  data = focal,
  FUN = stats::median
)
stopifnot(
  nrow(focal) == 2L,
  all(focal$median_us <= 750),
  all(focal$payload_copies <= 2.5),
  environment$digest_calls[[1L]] == 0L,
  nrow(slopes) == 4L,
  all(slopes$exponent >= 0.65 & slopes$exponent <= 1.30),
  all(source_scale$absolute_delta_us <= 100),
  all(unlist(parity, use.names = FALSE))
)
cat("LEDGR_HISTORY_MANIFESTATION_OK\n")
