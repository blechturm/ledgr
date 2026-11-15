# Slice-3 probe: reason codes in the pin's dumped run diagnostics, per workload.
d <- commandArgs(TRUE)[[1L]]
for (f in list.files(d, pattern = "\\.rds$", full.names = TRUE)) {
  t <- readRDS(f)
  diag <- t$run$run_diagnostics
  comp <- t$run$run_completion
  rc <- if (is.null(diag)) character() else as.character(diag$reason_code)
  codes <- sort(table(unlist(strsplit(rc[!is.na(rc) & nzchar(rc)], "|", fixed = TRUE))), decreasing = TRUE)
  st <- if (is.null(comp)) "-" else paste(comp$status, comp$stop_reason)
  cat(sprintf("%-22s %s | %s\n", sub("\\.rds$", "", basename(f)), st, paste(names(codes), codes, sep = "=", collapse = " ")))
}
