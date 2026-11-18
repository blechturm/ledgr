# The close review round 1 (F5) noise diagnostic, from the reviewer's noise_probe.R with
# the record paths pointed at this worktree: the median-ratio statistic under all 256
# within-pair arm-label exchanges of the A/A observations on unit 4's target cells.
root <- 'C:/Users/maxth/ledgr-wt/ws41/dev/bench/timing/records/cut22-feature-1'
sink('C:/Users/maxth/ledgr-wt/ws41/dev/feature_parity/evidence/ldg3250/unit4_noise/noise_probe.txt',split=TRUE)
aa <- read.csv(file.path(root,'aa-cut-base/attempt-1/raw.csv'))
unit <- read.csv(file.path(root,'unit4-admission/attempt-1/raw.csv'))
for (cell in c('sweep_500x1260','sweep_1166x252')) {
  x <- subset(aa,cell==cell) # subsetting below uses explicit column selection
  x <- aa[aa$cell==cell,]
  a <- x[x$arm=='base',]; b <- x[x$arm=='candidate',]
  b <- b[match(a$pair,b$pair),]
  swapped <- sapply(0:255,function(mask) {
    hit <- as.logical(intToBits(mask)[1:8])
    median(ifelse(hit,a$seconds,b$seconds))/median(ifelse(hit,b$seconds,a$seconds))
  })
  u <- unit[unit$cell==cell,]
  observed <- median(u$seconds[u$arm=='candidate'])/median(u$seconds[u$arm=='base'])
  cat(cell,'unit ratio',observed,'\n')
  cat('A/A ratios from all 256 within-pair label swaps, quantiles:'); print(quantile(swapped,c(.025,.05,.5,.95,.975)))
  cat('fraction of A/A labelings at least this fast:',mean(swapped<=observed),'\n')
  print(data.frame(pair=a$pair,base=a$seconds,candidate=b$seconds,ratio=b$seconds/a$seconds))
}
sink()
