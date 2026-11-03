cut10_bars <- function(n_instrument, n_session) {
  ids <- sprintf("I%04d", seq_len(n_instrument))
  axis <- as.POSIXct("2020-01-01", tz = "UTC") +
    86400 * (seq_len(n_session) - 1L)
  instrument_pos <- rep(seq_len(n_instrument), each = n_session)
  session_pos <- rep(seq_len(n_session), times = n_instrument)
  close <- 100 + instrument_pos / 10 + session_pos
  data.frame(
    instrument_id = ids[instrument_pos],
    ts_utc = axis[session_pos],
    open = close - 0.25,
    high = close + 0.5,
    low = close - 0.5,
    close = close,
    volume = 100000 + instrument_pos,
    stringsAsFactors = FALSE
  )
}

cut10_work <- function(value, kind) {
  if (identical(kind, "long")) {
    return(sprintf(
      "%dx%d|%.17g|%s|%s",
      nrow(value), ncol(value), sum(value$feature_value, na.rm = TRUE),
      value$instrument_id[[1L]], value$feature_id[[nrow(value)]]
    ))
  }
  numeric_value <- vapply(
    value[-1L],
    function(column) if (is.numeric(column)) sum(column, na.rm = TRUE) else 0,
    numeric(1)
  )
  sprintf(
    "%dx%d|%.17g|%s|%s",
    nrow(value), ncol(value), sum(numeric_value), names(value)[[4L]],
    names(value)[[ncol(value)]]
  )
}

pulse_inspection <- function(args, work_dir) {
  kind <- args$kind
  reps <- suppressWarnings(as.integer(args$reps))
  if (!kind %in% c("long", "wide") || !isTRUE(reps >= 1L)) {
    stop("bad pulse-inspection arguments")
  }
  bars <- cut10_bars(600L, 5L)
  snapshot <- ledgr_snapshot_from_df(
    bars,
    db_path = file.path(work_dir, "cut10.duckdb"),
    snapshot_id = "cut10_pulse_inspection"
  )
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  features <- ledgr_feature_map(
    ret_1 = ledgr_ind_returns(1L),
    sma_2 = ledgr_ind_sma(2L),
    sma_3 = ledgr_ind_sma(3L)
  )
  pulse <- ledgr_pulse_snapshot(
    snapshot,
    universe = sprintf("I%04d", seq_len(600L)),
    ts_utc = max(bars$ts_utc),
    features = features,
    cash = 1e6
  )
  on.exit(close(pulse), add = TRUE)
  inspect <- if (identical(kind, "long")) ledgr_pulse_features else ledgr_pulse_wide
  expected <- cut10_work(inspect(pulse), kind)
  invisible(gc())
  last <- NULL
  t0 <- as.numeric(Sys.time())
  for (i in seq_len(reps)) last <- inspect(pulse)
  t1 <- as.numeric(Sys.time())
  observed <- cut10_work(last, kind)
  if (!identical(observed, expected)) {
    stop("inspection output changed during the timing window")
  }
  list(
    seconds = stats::setNames(t1 - t0, "inspect"),
    work = paste(kind, expected, paste0("x", reps), sep = "|")
  )
}
