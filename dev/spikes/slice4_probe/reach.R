# What each slice-4 workload reaches on the pin: event types, diagnostic
# stage/outcome/reason codes, run status.
d <- commandArgs(TRUE)[[1]]   # the loop_parity.R --dump directory
for (f in list.files(d, full.names = TRUE)) {
  x <- readRDS(f)$run
  cat("==", sub(".rds", "", basename(f)), "| tables:", paste(names(x), collapse = " "), "\n")
  ev <- x$ledger_events
  if (is.data.frame(ev) && nrow(ev)) print(table(ev$event_type))
  dg <- x$run_diagnostics
  if (is.data.frame(dg) && nrow(dg)) {
    k <- paste(dg$stage, dg$outcome, dg$reason_code, sep = "/")
    k <- k[!k %in% c("decision/recorded/strategy_target")]
    if (length(k)) print(sort(table(k), decreasing = TRUE))
  }
  r <- x$runs
  if (is.data.frame(r)) cat("status:", r$status, if ("error_msg" %in% names(r)) r$error_msg, "\n")
  cc <- x$run_completion
  if (is.data.frame(cc) && nrow(cc)) cat("completion:", cc$intended_terminal_status, cc$stop_reason, "\n")
}
