args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 3L) {
  stop("usage: Rscript probe.R <package-root> <label> <out.csv>")
}
root <- normalizePath(args[[1L]], winslash = "/")
label <- args[[2L]]
out <- args[[3L]]
.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
pkgload::load_all(root, quiet = TRUE)

ids <- sprintf("I%04d", seq_len(600L))
axis <- ledgr_utc("2020-01-01") + 86400 * 0:4
instrument_pos <- rep(seq_len(600L), each = 5L)
session_pos <- rep(seq_len(5L), times = 600L)
close <- 100 + instrument_pos / 10 + session_pos
bars <- data.frame(
  instrument_id = ids[instrument_pos],
  ts_utc = axis[session_pos],
  open = close - 0.25,
  high = close + 0.5,
  low = close - 0.5,
  close = close,
  volume = 100000 + instrument_pos,
  stringsAsFactors = FALSE
)
snapshot <- ledgr_snapshot_from_df(
  bars,
  db_path = tempfile(fileext = ".duckdb"),
  snapshot_id = "pulse_inspection_materialization"
)
on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
features <- ledgr_feature_map(
  ret_1 = ledgr_ind_returns(1L),
  sma_2 = ledgr_ind_sma(2L),
  sma_3 = ledgr_ind_sma(3L)
)
pulse <- ledgr_pulse_snapshot(
  snapshot,
  universe = ids,
  ts_utc = max(axis),
  features = features,
  cash = 1e6
)
on.exit(close(pulse), add = TRUE)

allocated <- function(fun, reps = 10L) {
  fun()
  path <- tempfile(fileext = ".mem")
  Rprofmem(path)
  for (i in seq_len(reps)) fun()
  Rprofmem(NULL)
  lines <- readLines(path, warn = FALSE)
  unlink(path)
  sizes <- suppressWarnings(as.numeric(sub(" .*", "", lines)))
  sum(sizes, na.rm = TRUE) / reps
}

long <- ledgr_pulse_features(pulse)
wide <- ledgr_pulse_wide(pulse)
result <- data.frame(
  label = label,
  helper = c("long", "wide"),
  bytes_per_call = c(
    allocated(function() ledgr_pulse_features(pulse)),
    allocated(function() ledgr_pulse_wide(pulse))
  ),
  rows = c(nrow(long), nrow(wide)),
  columns = c(ncol(long), ncol(wide)),
  numeric_sum = c(
    sum(long$feature_value, na.rm = TRUE),
    sum(vapply(wide[-1L], function(x) {
      if (is.numeric(x)) sum(x, na.rm = TRUE) else 0
    }, numeric(1)))
  ),
  stringsAsFactors = FALSE
)
utils::write.csv(result, out, row.names = FALSE)
print(result)
