# Re-review 1, G2 negative control, from the reviewer's capture_controls.R:
# the one-fault driver built by make_driver_probe.R (the committed faults.R
# with its fault list reduced to all_fields, and a runner that loads the
# library, asserts the selector and then errors before any observation).
# On the final library (selector present) the driver must fail; on the pin
# (no selector) all_fields is not run and the driver passes.
out <- 'C:/Users/maxth/ledgr-wt/ws41-scratch/rereview1_controls'
rscript <- 'C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe'
pin <- 'C:/Users/maxth/ledgr-wt/ws41-scratch/oracle/v5/pin'
run <- function(lib, label) {
  txt <- suppressWarnings(system2(rscript, c(shQuote(file.path(out, 'fault_driver_probe/faults.R')),
    paste0('--lib=', lib), paste0('--pin=', pin),
    paste0('--scratch=', file.path(out, 'fault_driver_probe', paste0('scratch_', label))),
    paste0('--evidence=', file.path(out, 'fault_driver_probe', paste0('evidence_', label)))), stdout = TRUE, stderr = TRUE))
  status <- attr(txt, 'status')
  if (is.null(status)) status <- 0L
  txt <- grep('^During startup|^[0-9]: Setting LC_', txt, value = TRUE, invert = TRUE)
  writeLines(c(paste('library:', lib), paste('exit:', status), txt), file.path(out, paste0('fault_driver_', label, '.txt')))
  cat(label, 'exit', status, '\n')
}
run('C:/Users/maxth/ledgr-wt/ws41-scratch/libs/final-39ac4ba4', 'selector_present')
run('C:/Users/maxth/ledgr-wt/pin-lib-d5b3a151', 'selector_absent')
