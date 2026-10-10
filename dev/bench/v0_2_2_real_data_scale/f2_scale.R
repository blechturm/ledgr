# F2 resolver per-fill cost from 10,000 to 640,000 fills on the final tree (a
# two-point exponent at small sizes is dominated by cache effects).
#   Rscript f2_scale.R
.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
suppressMessages(pkgload::load_all("C:/tmp/ws22-b", quiet = TRUE, compile = FALSE))
ns <- asNamespace("ledgr")
nses <- 5000L
d <- as.POSIXct("2000-01-03", tz = "UTC") + 86400 * (0:(nses - 1L))
sessions <- data.frame(status = "open", session_open = d + 14.5 * 3600, session_close = d + 21 * 3600)
spc <- function(fn) { reps <- 0L; t0 <- Sys.time(); repeat { fn(); reps <- reps + 1L; tt <- as.numeric(difftime(Sys.time(), t0, units = "secs")); if (tt >= 1) break }; tt / reps }
sizes <- c(10000L, 40000L, 160000L, 640000L)
t <- vapply(sizes, function(n) { set.seed(n); k <- sample.int(nses - 1L, n, TRUE) + 1L
  fills <- data.frame(event_seq = seq_len(n), ts_utc = sessions$session_open[k], instrument_id = "A")
  diag <- data.frame(event_seq = seq_len(n), instrument_id = "A", stage = "execution", outcome = "filled",
                     decision_ts_utc = sessions$session_close[k - 1L], execution_ts_utc = sessions$session_open[k])
  spc(function() ns$ledgr_fill_recording_pulses_from_evidence(fills, diag, sessions,
      list(execution_timing_convention = "availability_open_v2", execution_timing_version = 2L))) }, numeric(1))
out <- data.frame(fills = sizes, seconds = signif(t, 4), us_per_fill = signif(1e6 * t / sizes, 4)); out$slope_10k_640k <- signif(stats::coef(stats::lm(log(t) ~ log(sizes)))[[2L]], 3); utils::write.csv(out, "C:/Users/maxth/Documents/GitHub/ledgr/dev/bench/v0_2_2_real_data_scale/evidence/probes_final/f2_scale.csv", row.names = FALSE); print(out)
print(log(t[-1] / t[-4]) / log(4))
