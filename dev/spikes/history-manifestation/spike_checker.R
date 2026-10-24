# Checker for the bounded history-manifestation spike.

args <- commandArgs(trailingOnly = TRUE)
recorded_dir <- if (length(args)) args[[1L]] else file.path(
  "dev", "spikes", "history-manifestation", "evidence"
)
check_only <- length(args) >= 2L && identical(args[[2L]], "--check-only")

read_record <- function(dir) {
  files <- c(
    "measurements.csv", "components.csv", "parity.csv", "source_scale.csv",
    "environment.csv"
  )
  paths <- file.path(dir, files)
  if (any(!file.exists(paths))) stop("Spike evidence is incomplete.")
  stats::setNames(lapply(paths, utils::read.csv, stringsAsFactors = FALSE), files)
}

validate <- function(record) {
  measurements <- record[["measurements.csv"]]
  parity <- record[["parity.csv"]]
  source_scale <- record[["source_scale.csv"]]
  expected_cases <- c("j50_l252", "j500_l252", "j1166_l252", "j500_full")
  stopifnot(
    identical(unique(measurements$case), expected_cases),
    identical(unique(measurements$path), c("current", "matrix", "frame")),
    nrow(measurements) == 12L,
    all(parity$matrix_current_identical),
    all(parity$frame_matrix_identical),
    all(parity$dimensions_identical),
    all(parity$names_identical),
    all(parity$selected_ids_identical),
    all(measurements$digest_calls[measurements$path %in% c("matrix", "frame")] == 0L)
  )

  ordinary <- measurements[measurements$case == "j500_l252", ]
  matrix_us <- ordinary$median_us[ordinary$path == "matrix"]
  frame_us <- ordinary$median_us[ordinary$path == "frame"]
  current_us <- ordinary$median_us[ordinary$path == "current"]
  stopifnot(
    matrix_us <= 500,
    frame_us <= 500,
    frame_us / matrix_us <= 1.5,
    current_us / max(matrix_us, frame_us) >= 10
  )

  for (path in c("matrix", "frame")) {
    rows <- measurements[measurements$path == path, ]
    exponent <- unname(stats::coef(stats::lm(
      log(median_us) ~ log(returned_cells), data = rows
    ))[[2L]])
    if (!is.finite(exponent) || exponent < 0.65 || exponent > 1.30) {
      stop(sprintf("%s growth exponent %.3f is outside the linear band.", path, exponent))
    }
    payload <- 8 * rows$returned_cells
    if (any(rows$allocated_bytes / payload > 3.5)) {
      stop(sprintf("%s allocation exceeds 3.5 payload copies.", path))
    }
  }
  stopifnot(
    abs(source_scale$full_median_us[[1L]] -
        source_scale$short_median_us[[1L]]) <= 100,
    source_scale$full_median_us[[1L]] <= 250,
    source_scale$short_median_us[[1L]] <= 250
  )
  invisible(TRUE)
}

recorded <- read_record(recorded_dir)
validate(recorded)
if (check_only) {
  cat("HISTORY_MANIFESTATION_CHECK_OK mode=check-only\n")
  quit(save = "no", status = 0L)
}

scope_files <- c(
  list.files("R", recursive = TRUE, full.names = TRUE),
  list.files("src", recursive = TRUE, full.names = TRUE),
  list.files("tests", recursive = TRUE, full.names = TRUE),
  list.files("man", recursive = TRUE, full.names = TRUE),
  list.files("inst/design", recursive = TRUE, full.names = TRUE),
  c("NAMESPACE", "DESCRIPTION")
)
scope_files <- scope_files[file.exists(scope_files)]
before <- tools::md5sum(scope_files)

scratch <- tempfile("history-manifestation-check-")
dir.create(scratch)
on.exit(unlink(scratch, recursive = TRUE, force = TRUE), add = TRUE)
rscript <- file.path(R.home("bin"), "Rscript.exe")
old_commit <- Sys.getenv("LEDGR_PRODUCT_COMMIT", unset = NA_character_)
Sys.setenv(
  LEDGR_PRODUCT_COMMIT = recorded[["environment.csv"]]$product_commit[[1L]]
)
on.exit({
  if (is.na(old_commit)) Sys.unsetenv("LEDGR_PRODUCT_COMMIT") else
    Sys.setenv(LEDGR_PRODUCT_COMMIT = old_commit)
}, add = TRUE)
run <- processx::run(
  rscript,
  c("dev/spikes/history-manifestation/spike_runner.R", scratch),
  timeout = 120000,
  error_on_status = FALSE,
  echo = FALSE
)
if (!identical(run$status, 0L)) {
  stop(paste(
    "Spike rerun failed:",
    run$stderr,
    run$stdout
  ))
}
after <- tools::md5sum(scope_files)
if (!identical(before, after)) stop("Spike changed product-scope files.")

rerun <- read_record(scratch)
validate(rerun)
deterministic <- c(
  "case", "path", "rows", "columns", "returned_cells", "digest_calls",
  "patch_cells"
)
stopifnot(
  identical(recorded[["measurements.csv"]][deterministic],
            rerun[["measurements.csv"]][deterministic]),
  identical(recorded[["parity.csv"]], rerun[["parity.csv"]]),
  identical(recorded[["environment.csv"]][c(
    "product_commit", "r_version", "platform", "collapse_version",
    "microbenchmark_version", "gut_hash", "snapshot_sessions",
    "snapshot_instruments", "power_plan", "process_affinity"
  )], rerun[["environment.csv"]][c(
    "product_commit", "r_version", "platform", "collapse_version",
    "microbenchmark_version", "gut_hash", "snapshot_sessions",
    "snapshot_instruments", "power_plan", "process_affinity"
  )])
)
cat("HISTORY_MANIFESTATION_CHECK_OK mode=rerun\n")
