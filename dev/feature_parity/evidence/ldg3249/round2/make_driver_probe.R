root <- 'C:/Users/maxth/ledgr-wt/ws41'
out <- 'C:/Users/maxth/ledgr-wt/ws41-scratch/rereview1_controls'
dir <- file.path(out, 'fault_driver_probe')
dir.create(dir, showWarnings = FALSE)
x <- readLines(file.path(root, 'dev/feature_parity/faults.R'))
start <- grep('  faults <- c(', x, fixed = TRUE)
end <- grep('wrong_route = "route", all_fields = "treated_fields")', x, fixed = TRUE)
stopifnot(length(start) == 1L, length(end) == 1L)
x <- c(x[seq_len(start - 1L)], '  faults <- c(all_fields = "treated_fields")', x[-seq_len(end)])
writeLines(x, file.path(dir, 'faults.R'))
file.copy(file.path(root, 'dev/feature_parity', c('check.R', 'corpus_expected.csv')), dir, overwrite = TRUE)
writeLines(c(
  "library(ledgr, lib.loc='C:/Users/maxth/ledgr-wt/ws41-scratch/libs/final-39ac4ba4')",
  "stopifnot(exists('ledgr_history_feature_fields', asNamespace('ledgr'), inherits=FALSE))",
  "cat('selector present: TRUE; deliberately failing this fault runner before observations\\n')",
  "stop('forced all_fields runner error unrelated to missing selector')"), file.path(dir, 'runner.R'))
cat('Created one-fault driver from committed faults.R. Only the faults list is reduced; failure branch, controls and final verdict code are unchanged.\n')
