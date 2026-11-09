# Inspect the executed scratch stores after the SQL probe omitted holds.
source("C:/Users/maxth/ledgr-wt/diag-records-t2-out/probe/common.R")
metrics <- read.csv(file.path(out,"sql_metrics.csv"))
rows <- lapply(seq_len(nrow(metrics)),function(i) {
  m<-metrics[i,]
  con<-DBI::dbConnect(duckdb::duckdb(),file.path(work,paste0(m$workload,".duckdb")),read_only=TRUE)
  e<-DBI::dbGetQuery(con,"SELECT count(*) AS n FROM run_diagnostics WHERE run_id='t2' AND stage='decision'")$n
  summary<-DBI::dbGetQuery(con,"SELECT decisions FROM run_diagnostic_summary WHERE run_id='t2'")$decisions
  DBI::dbDisconnect(con,shutdown=TRUE)
  data.frame(workload=m$workload,summary_decisions=summary,explicit_decisions=e,
    certified_holds=m$holds,clean_fill_decisions=m$fills,seed_d4=e+m$holds,complete=e+m$holds+m$fills)
})
csv(do.call(rbind,rows),"reductions")
