root <- 'C:/Users/maxth/ledgr-wt/ws41'
out <- 'C:/Users/maxth/ledgr-wt/ws41-scratch/rereview1_controls'
rscript <- 'C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe'
sink(file.path(out, 'controls.txt'), split = TRUE)
run <- function(script, args) {
  z <- suppressWarnings(system2(rscript, c(shQuote(script), args), stdout = TRUE, stderr = TRUE))
  status <- attr(z, 'status')
  if (is.null(status)) status <- 0L
  cat('exit', status, '\n', paste(z, collapse = '\n'), '\n')
  invisible(status)
}
census <- read.csv(file.path(root, 'dev/feature_parity/census.csv'))
variants <- list(
  missing_row = census[census$helper != 'ledgr_history_lifetime_segments', ],
  false_engine = transform(census, binding = ifelse(helper == 'ledgr_history_substrate_terminal_at', 'engine version', binding)),
  false_exclusion = transform(census, binding = ifelse(helper == 'ledgr_function_fingerprint', 'excluded: claimed infrastructure', binding)),
  claimed_identity = transform(census, binding = ifelse(helper == 'ledgr_function_fingerprint', 'identity: engine version machinery', binding)))
for (nm in names(variants)) {
  file <- file.path(out, paste0('census_', nm, '.csv'))
  write.csv(variants[[nm]], file, row.names = FALSE)
  cat('\nCENSUS', nm, '\n')
  run(file.path(root, 'dev/feature_parity/census.R'), c(
    '--lib=C:/Users/maxth/ledgr-wt/ws41-scratch/libs/final-39ac4ba4',
    paste0('--out=', file.path(out, paste0('census_', nm))), paste0('--census=', file)))
}
base <- 'C:/Users/maxth/ledgr-wt/ws41-scratch/oracle/v5/final'
pin <- 'C:/Users/maxth/ledgr-wt/ws41-scratch/oracle/v5/pin'
obs <- read.csv(file.path(base, 'observations.csv'), na.strings = character(), colClasses = 'character')
variants <- list(
  empty_treated = transform(obs, value = ifelse(component == 'treated_fields', '', value)),
  prep_only = transform(obs, value = ifelse(component == 'treated_fields', gsub('(^|;)causality:[^;]*;?', '\\1', value), value)),
  missing_parameterized = obs[!grepl('parameterized_|param:', obs$case), ],
  missing_treated_component = obs[!(obs$component == 'treated_fields' & obs$case == 'empty|data_start|close'), ])
for (nm in names(variants)) {
  dir <- file.path(out, nm)
  dir.create(dir, showWarnings = FALSE)
  write.csv(variants[[nm]], file.path(dir, 'observations.csv'), row.names = FALSE)
  file.copy(file.path(base, 'provenance.csv'), dir, overwrite = TRUE)
  cat('\nORACLE', nm, '\n')
  run(file.path(root, 'dev/feature_parity/check.R'), c(paste0('--pin=', pin), paste0('--candidate=', dir)))
}
sink()
