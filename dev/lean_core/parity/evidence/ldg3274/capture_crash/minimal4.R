# Scratch crash probe (not committed): load_all() a ledgr source tree (no
# recompile when its DLL is current) and raise the native type-check refusal
# of ledgr_cpp_spot_fifo_batch() three times.
#   Rterm -f minimal4.R --args <source dir>
src <- commandArgs(TRUE)[[1L]]
.libPaths(unique(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths())))
dll <- file.path(src, "src", "ledgr.dll")
cat("dll before", format(file.mtime(dll)), "\n")
suppressMessages(pkgload::load_all(src, quiet = TRUE, export_all = TRUE))
cat("dll after ", format(file.mtime(dll)), "\n")
call_batch <- function(cash = 1000, event_seq_start = 1L) {
  ledgr:::ledgr_cpp_spot_fifo_batch("compiled-scalar-check", 1L, "AAA", "BUY", 1, 100, 0,
    as.numeric(as.POSIXct("2020-01-02", tz = "UTC")), event_seq_start, 0, 0, cash,
    integer(), numeric(), numeric(), 0, 0, 0, 0)
}
for (i in 1:3) {
  cat("native refusal", i, "... "); flush(stdout())
  cat(tryCatch({ call_batch(cash = 1000L); "no error" }, error = conditionMessage), "\n"); flush(stdout())
}
cat("SURVIVED\n")
