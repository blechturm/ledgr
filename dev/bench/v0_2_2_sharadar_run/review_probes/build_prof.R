.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
suppressMessages(pkgload::load_all("C:/Users/maxth/Documents/GitHub/ledgr", quiet = TRUE, compile = FALSE))
args <- commandArgs(TRUE)
n_inst <- as.integer(args[[1]]); n_days <- as.integer(args[[2]]); n_mem <- as.integer(args[[3]])
path <- args[[4]]
set.seed(1)
dates <- seq(as.Date("2000-01-03"), by = "day", length.out = round(n_days * 7 / 5) + 10)
dates <- dates[!format(dates, "%u") %in% c("6", "7")][seq_len(n_days)]
pulses <- as.POSIXct(paste(dates, "21:00:00"), tz = "UTC")
ids <- sprintf("I%04d", seq_len(n_inst))
n <- length(pulses)
t0 <- Sys.time()
ret <- matrix(rnorm(n_inst * n, 0.0003, 0.02), n_inst, n)
px <- 50 * exp(t(apply(ret, 1, cumsum)))
bars <- data.frame(instrument_id = rep(ids, each = n), ts_utc = rep(pulses, times = n_inst),
  open = as.vector(t(px)), high = as.vector(t(px)) * 1.01, low = as.vector(t(px)) * 0.99,
  close = as.vector(t(px)), volume = 1000, stringsAsFactors = FALSE)
all_d <- seq(min(dates), max(dates), by = "day"); op <- all_d %in% dates
sessions <- ledgr_facts_sessions(data.frame(session_date = all_d, status = ifelse(op, "open", "closed"),
  session_open = ifelse(op, "14:30:00", NA), session_close = ifelse(op, "21:00:00", NA),
  knowledge_time = as.POSIXct(all_d, tz = "UTC") - 1, stringsAsFactors = FALSE), venue_id = "XNYS")
month_starts <- which(!duplicated(format(dates, "%Y-%m")))
mi <- data.frame(effective_from = pulses[month_starts], knowledge_time = pulses[month_starts] - 3600,
  source = "probe", stringsAsFactors = FALSE)
mi$members <- I(lapply(seq_along(month_starts), function(k) {
  off <- (k - 1L) * max(1L, (n_inst - n_mem) %/% length(month_starts))
  ids[((off + seq_len(n_mem) - 1L) %% n_inst) + 1L]
}))
membership <- ledgr_facts_membership_snapshots(mi, universe_id = "U", complete = TRUE)
Rprof("prof_build.out", interval = 0.02); snap <- ledgr_snapshot_from_df(bars, facts = ledgr_facts(sessions, membership), db_path = path); Rprof(NULL)
cat("build", format(difftime(Sys.time(), t0, units = "secs")), "\n")
ledgr_snapshot_close(snap)
