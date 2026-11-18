root <- 'C:/Users/maxth/ledgr-wt/ws41'
out <- 'C:/Users/maxth/ledgr-wt/ws41-scratch/rereview2_controls'
oracle <- c(pin = 'C:/Users/maxth/ledgr-wt/ws41-scratch/oracle/v6/pin', candidate = 'C:/Users/maxth/ledgr-wt/ws41-scratch/oracle/v6/final')
rscript <- 'C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe'
sink(file.path(out, 'common_observer_probe.txt'), split=TRUE)
read_obs <- function(dir) read.csv(file.path(dir,'observations.csv'), na.strings=character(), colClasses='character')
run <- function(label,pin,candidate) {
  z <- suppressWarnings(system2(rscript,c(shQuote(file.path(root,'dev/feature_parity/check.R')),
      paste0('--pin=',pin),paste0('--candidate=',candidate)),stdout=TRUE,stderr=TRUE))
  status <- attr(z,'status')
  if (is.null(status)) status <- 0L
  cat('\n',label,'exit',status,'\n',paste(z,collapse='\n'),'\n')
}
dirs <- list()
for (arm in c('pin','candidate')) {
  base <- oracle[[arm]]
  x <- read_obs(base)
  ck <- paste(x$family,x$case,sep='|')
  refused <- unique(ck[x$component=='refusal' & x$value!='none'])
  target <- ck %in% refused
  prep <- target & x$component=='treated_fields'
  handoffs <- target & x$component=='handoffs'
  cat(arm,'refusing cases:',length(refused),'prep traces removed:',sum(prep & grepl('prep:',x$value,fixed=TRUE)),'\n')
  before <- x[x$case=='hostile_carry2|data_start|custom_volume_strict' & x$component %in% c('treated_fields','handoffs'),]
  x$value[prep] <- gsub('^;|;$','',gsub('(^|;)prep:[^;]*','',x$value[prep]))
  # These are exactly the two outputs of the treated-fields observer at
  # runner.R:150-152. Leave all independently recorded reach counters intact.
  x$value[handoffs] <- sub('prep_seen=[0-9]+','prep_seen=0',x$value[handoffs])
  after <- x[x$case=='hostile_carry2|data_start|custom_volume_strict' & x$component %in% c('treated_fields','handoffs'),]
  cat('before:\n'); print(before,row.names=FALSE)
  cat('after:\n'); print(after,row.names=FALSE)
  dir <- file.path(out,paste0('refusal_observer_missing_',arm))
  dir.create(dir,showWarnings=FALSE)
  write.csv(x,file.path(dir,'observations.csv'),row.names=FALSE)
  file.copy(file.path(base,'provenance.csv'),dir,overwrite=TRUE)
  dirs[[arm]] <- dir
}
run('candidate-only observer loss',oracle[['pin']],dirs$candidate)
run('shared observer loss on refusing cases',dirs$pin,dirs$candidate)
sink()
