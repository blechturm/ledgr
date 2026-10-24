# Prerequisite probe for the history-manifestation spike.
#
# Reuse the registered public-API WS55 record for the current reader, then
# measure only final matrix/frame manifestation from an already prepared
# instrument-by-session numeric plane. This changes no product code.

.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))

root <- normalizePath(".", winslash = "/", mustWork = TRUE)
record_path <- file.path(
  root, "dev", "bench", "v0_2_2_history_api_cleanup", "evidence",
  "history_matrix.csv"
)
record <- utils::read.csv(record_path, stringsAsFactors = FALSE)
stopifnot(all(c("direct", "adapter") %in% record$arm))

n_inst <- 500L
n_time <- 252L
ids <- sprintf("I%03d", seq_len(n_inst))
axis <- as.POSIXct("2020-01-01", tz = "UTC") + seq_len(n_time) * 86400
plane <- matrix(
  seq_len(n_inst * n_time) / 100,
  nrow = n_inst,
  ncol = n_time
)
time_names <- format(axis, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")

matrix_manifest <- function() {
  out <- t(plane)
  dim(out) <- c(n_time, n_inst)
  dimnames(out) <- list(time_names, ids)
  structure(out, class = c("ledgr_history_matrix_probe", "matrix", "array"))
}

frame_manifest <- function() {
  value <- t(plane)
  dim(value) <- c(n_time, n_inst)
  columns <- collapse::mctl(value)
  names(columns) <- ids
  structure(
    c(list(ts_utc = axis), columns),
    names = c("ts_utc", ids),
    row.names = .set_row_names(n_time),
    class = c("ledgr_history_probe", "data.frame")
  )
}

clock <- function(expr, times = 500L) {
  timing <- microbenchmark::microbenchmark(expr(), times = times, unit = "us")
  c(
    median_us = stats::median(timing$time) / 1000,
    p95_us = unname(stats::quantile(timing$time, 0.95)) / 1000
  )
}

matrix_clock <- clock(matrix_manifest)
frame_clock <- clock(frame_manifest)
matrix_value <- matrix_manifest()
frame_value <- frame_manifest()
stopifnot(
  identical(as.double(matrix_value), as.double(as.matrix(frame_value[ids]))),
  identical(dim(matrix_value), c(n_time, n_inst))
)

out <- data.frame(
  measure = c("registered_current_direct", "prepared_matrix", "prepared_frame"),
  rows = n_time,
  columns = n_inst,
  median_us = c(
    stats::median(record$elapsed_seconds_per_read[record$arm == "direct"]) * 1e6,
    matrix_clock[["median_us"]],
    frame_clock[["median_us"]]
  ),
  p95_us = c(NA_real_, matrix_clock[["p95_us"]], frame_clock[["p95_us"]]),
  retained_bytes = c(
    stats::median(record$retained_bytes[record$arm == "direct"]),
    as.numeric(object.size(matrix_value)),
    as.numeric(object.size(frame_value))
  ),
  stringsAsFactors = FALSE
)

print(out, row.names = FALSE)
