# Rerun the public probes, diff correctness columns and guard source scope.
# H1 is deliberately not repeated: h1.R records the one registered scale run.
root <- "C:/Users/maxth/ledgr-wt/diag-records-t2-out/probe"
repo <- "C:/Users/maxth/ledgr-wt/diag-records-t2"
scope <- c("R","src","tests","NAMESPACE","DESCRIPTION","man","inst/design")
files <- unlist(lapply(file.path(repo,scope),function(p) {
  if(dir.exists(p))list.files(p,recursive=TRUE,full.names=TRUE,all.files=TRUE)else p
}))
files <- files[!dir.exists(files)]
before <- tools::md5sum(files)
scratch <- file.path(root,"check-rerun")
dir.create(scratch,showWarnings=FALSE)
Sys.setenv(LEDGR_DIAG_T2_OUT=scratch)
for(s in c("run.R","reductions.R","edges.R")) {
  status <- system2("C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe",shQuote(file.path(root,s)))
  stopifnot(identical(status,0L))
}
columns <- list(sql_metrics=c("workload","logical","holds","fills","explicit","exact_full","exact_point","gut"),
  sql_differences=NULL,fractional_sequential=NULL,edge_counts=NULL,edge_segments=NULL,edge_tuples=NULL,recon_economics=NULL,
  comparison=NULL,reductions=NULL,numbering=NULL,edge_risk_stop=NULL,edge_sizing=NULL,edge_risk=NULL,edge_tiny=NULL,edge_p3=NULL)
records <- lapply(names(columns),function(n) {
  read <- function(dir) {
    x<-read.csv(file.path(dir,paste0(n,".csv")),colClasses="character",check.names=FALSE)
    if(!is.null(columns[[n]]))x<-x[columns[[n]]]
    x
  }
  data.frame(record=n,identical=identical(read(root),read(scratch)))
})
records <- do.call(rbind,records)
write.csv(records,file.path(root,"check.csv"),row.names=FALSE)
stopifnot(all(records$identical),identical(before,tools::md5sum(files)))
cat("CHECK PASS; public correctness records identical; source scope unchanged\n")
