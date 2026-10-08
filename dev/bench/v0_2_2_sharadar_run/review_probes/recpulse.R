.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
suppressMessages(pkgload::load_all("C:/Users/maxth/Documents/GitHub/ledgr", quiet = TRUE, compile = FALSE))
ns <- 7213
d <- as.POSIXct("1998-01-02", tz = "UTC") + 86400 * (0:(ns - 1))
sessions <- data.frame(status = "open", session_open = d + 14.5 * 3600, session_close = d + 21 * 3600)
for (n in c(10000L, 20000L, 40000L)) {
  k <- sample.int(ns - 1L, n, TRUE) + 1L
  fills <- data.frame(event_seq = seq_len(n), ts_utc = sessions$session_open[k], instrument_id = "A")
  diag <- data.frame(event_seq = seq_len(n), instrument_id = "A", stage = "execution", outcome = "filled",
                     decision_ts_utc = sessions$session_close[k - 1L], execution_ts_utc = sessions$session_open[k])
  t0 <- Sys.time()
  r <- ledgr_fill_recording_pulses_from_evidence(fills, diag, sessions, list(execution_timing_convention = "availability_open_v2", execution_timing_version = 2L))
  cat(n, format(difftime(Sys.time(), t0, units = "secs")), sum(!is.na(r)), "\n")
}
