args <- commandArgs(trailingOnly = TRUE)
arg_value <- function(flag) {
  i <- match(flag, args)
  if (is.na(i) || i == length(args)) stop("Missing ", flag)
  args[[i + 1L]]
}
repo <- normalizePath(arg_value("--repo"), winslash = "/")
out <- arg_value("--out")
arm <- arg_value("--arm")
dir.create(out, recursive = TRUE, showWarnings = FALSE)
suppressMessages(pkgload::load_all(repo, quiet = TRUE, compile = FALSE))

set.seed(2L)
values <- 100 * exp(cumsum(stats::rnorm(3000L, 0, 0.02)))
bars <- data.frame(
  ts_utc = as.POSIXct("2000-01-01", tz = "UTC") + 86400 * 0:2999,
  instrument_id = "AAA",
  open = values,
  high = values * 1.005,
  low = values * 0.995,
  close = values,
  volume = 1e5,
  stringsAsFactors = FALSE
)
bars[c(1:400, 1200:1210), c("open", "high", "low", "close")] <- NA

rows <- lapply(c("sma", "returns"), function(feature) {
  indicator <- if (identical(feature, "sma")) {
    ledgr_ind_sma(20L)
  } else {
    ledgr_ind_returns(20L)
  }
  definition <- ledgr:::ledgr_precompute_feature_def_from_indicator(indicator)
  times <- numeric(3L)
  value <- NULL
  for (rep in seq_len(3L)) {
    started <- proc.time()[["elapsed"]]
    for (iteration in seq_len(10L)) {
      value <- ledgr:::ledgr_compute_feature_series_strict(bars, definition)
    }
    times[[rep]] <- (proc.time()[["elapsed"]] - started) / 10
  }
  saveRDS(value, file.path(out, paste0(feature, "-", arm, ".rds")), version = 3L)
  data.frame(
    feature = feature,
    arm = arm,
    median_s = stats::median(times)
  )
})
utils::write.csv(
  do.call(rbind, rows),
  file.path(out, paste0("micro-", arm, ".csv")),
  row.names = FALSE
)
