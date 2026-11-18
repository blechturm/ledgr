root <- 'C:/Users/maxth/ledgr-wt/ws41'
out <- 'C:/Users/maxth/ledgr-wt/ws41-scratch/rereview2_controls'
rscript <- 'C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe'
dir <- file.path(out,'runner_observer_probe')
dir.create(dir,showWarnings=FALSE)
sink(file.path(out,'runner_observer_probe.txt'),split=TRUE)
run <- function(script,args) {
  z <- suppressWarnings(system2(rscript,c(shQuote(script),args),stdout=TRUE,stderr=TRUE))
  status <- attr(z,'status')
  if (is.null(status)) status <- 0L
  cat('exit',status,'\n',paste(z,collapse='\n'),'\n')
  invisible(status)
}
lines <- readLines(file.path(root,'dev/feature_parity/runner.R'))
end <- grep('  # ---- the two TTR routes:',lines,fixed=TRUE)
tail <- grep('  obs <- do.call(rbind, rows)',lines,fixed=TRUE)
stopifnot(length(end)==1L,length(tail)==1L)
lines <- c(lines[seq_len(end-1L)],lines[seq.int(tail,length(lines))])
lines <- sub('  substrates <- fx_substrates()',
             '  substrates <- fx_substrates()["hostile_carry2"]',lines,fixed=TRUE)
lines <- sub('      for (set in names(sets)) {',
             '      for (set in c("close", "custom_volume_strict")) {',lines,fixed=TRUE)
lines <- sub('  for (rc in fx_read_entry_cases(sets)) {',
             '  for (rc in fx_read_entry_cases(sets)[1L]) {',lines,fixed=TRUE)
file.copy(file.path(root,'dev/feature_parity/corpus.R'),dir,overwrite=TRUE)
writeLines(lines,file.path(dir,'runner_baseline.R'))
# Deliberately lose the prep observer on two refusing cases. Both writes
# from this one observer disappear. Independent reached/check counters,
# namespace behavior, returned inputs, values, routes and refusals remain.
at <- which(lines=='    res <- orig(...)' & seq_along(lines) > grep('  wrap("ledgr_history_feature_inputs",',lines,fixed=TRUE))[[1L]]
faulty <- append(lines,
  '    if (isTRUE(rec$omit_prep_observation) && identical(phase(), "prep")) return(res)',after=at)
at <- grep('  observe <- function(family, case, expr) {',faulty,fixed=TRUE)
stopifnot(length(at)==1L)
faulty <- append(faulty,
  '    rec$omit_prep_observation <- grepl("custom_volume_strict$", case)',after=at+1L)
writeLines(faulty,file.path(dir,'runner_faulty.R'))
for (mode in c('baseline','faulty')) {
  for (arm in c('pin','candidate')) {
    lib <- if (arm=='pin') 'C:/Users/maxth/ledgr-wt/pin-lib-d5b3a151' else
      'C:/Users/maxth/ledgr-wt/ws41-scratch/libs/final-39ac4ba4'
    cat('\nRUN',mode,arm,'\n')
    stopifnot(run(file.path(dir,paste0('runner_',mode,'.R')),c(paste0('--arm=',arm),paste0('--lib=',lib),
      paste0('--out=',file.path(dir,paste(mode,arm,sep='_')))))==0L)
  }
}
read_obs <- function(mode,arm) read.csv(file.path(dir,paste(mode,arm,sep='_'),'observations.csv'),
  na.strings=character(),colClasses='character')
baseline <- read_obs('baseline','pin')
expected <- read.csv(file.path(root,'dev/feature_parity/corpus_expected.csv'),na.strings=character(),colClasses='character')
cases <- unique(paste(baseline$family,baseline$case,sep='|'))
expected <- expected[paste(expected$family,expected$case,sep='|') %in% cases,]
write.csv(expected,file.path(dir,'expected_subset.csv'),row.names=FALSE)
for (mode in c('baseline','faulty')) {
  cat('\nCHECK',mode,'\n')
  run(file.path(root,'dev/feature_parity/check.R'),c(paste0('--pin=',file.path(dir,paste0(mode,'_pin'))),
    paste0('--candidate=',file.path(dir,paste0(mode,'_candidate'))),paste0('--expected=',file.path(dir,'expected_subset.csv'))))
}
for (arm in c('pin','candidate')) {
  a <- read_obs('baseline',arm)
  b <- read_obs('faulty',arm)
  keep <- !a$component %in% c('treated_fields','handoffs')
  cat('\n',arm,'all non-observer components identical:',identical(a[keep,],b[keep,]),'\n')
  changed <- a$value!=b$value
  cat('Changed observer outputs:\n')
  print(b[changed,],row.names=FALSE)
}
sink()
