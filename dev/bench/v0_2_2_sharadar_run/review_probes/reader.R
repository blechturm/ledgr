.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
suppressMessages(pkgload::load_all("C:/Users/maxth/Documents/GitHub/ledgr", quiet = TRUE, compile = FALSE))
snapshot <- ledgr_snapshot_open("probe_1000x1500.duckdb")
runs <- ledgr_run_list(snapshot)
print(as.data.frame(runs)[, 1:3])
rid <- runs$run_id[[as.integer(commandArgs(TRUE)[[1]])]]
bt <- ledgr_run_open(snapshot, rid)
Rprof("prof_reader.out", interval = 0.02)
t0 <- Sys.time(); f <- ledgr_results(bt, "fills"); cat("fills", nrow(f), format(difftime(Sys.time(), t0, units = "secs")), "\n")
Rprof(NULL)
s <- summaryRprof("prof_reader.out"); options(width = 200); print(head(s$by.total, 40))
if (isTRUE(as.logical(commandArgs(TRUE)[2]))) { t0 <- Sys.time(); a <- ledgr_results(bt, "availability"); cat("availability", nrow(a), format(difftime(Sys.time(), t0, units = "secs")), "
") }
t0 <- Sys.time(); sm <- summary(bt); cat("summary", format(difftime(Sys.time(), t0, units = "secs")), "\n")
t0 <- Sys.time(); m <- ledgr_compute_metrics(bt); cat("metrics", format(difftime(Sys.time(), t0, units = "secs")), "\n")
t0 <- Sys.time(); v <- ledgr_valuation_summary(bt); cat("valuation_summary", format(difftime(Sys.time(), t0, units = "secs")), "\n")
