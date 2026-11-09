source("C:/Users/maxth/ledgr-wt/diag-records-t2-out/probe/common.R")
source(file.path(probe_root, "sql.R"))
csv(data.frame(pin=pin, R=R.version.string, duckdb=as.character(packageVersion("duckdb"))), "environment")
state <- new.env()
state$recon <- list()
state$label <- ""
wrap("ledgr_fold_reconciliation_check", function(orig) function(...) {
  values <- list(...)
  state$recon[[length(state$recon)+1L]] <- cbind(workload=state$label, as.data.frame(values))
  orig(...)
})
state$segments <- list()
wrap("ledgr_fold_diagnostic_segment", function(orig) function(segment, ts) {
  if (identical(segment$stage,"decision") && identical(segment$outcome,"recorded")) {
    state$segments[[length(state$segments)+1L]] <- data.frame(workload=state$label,
      n=segment$n, has_after_risk=!is.null(segment$target_after_risk) && all(!is.na(segment$target_after_risk)))
  }
  orig(segment,ts)
})
state$appends <- list()
state$pulse <- 0L
wrap("ledgr_fold_stage_commit", function(orig) function(...) {
  state$pulse <- state$pulse+1L
  orig(...)
})
wrap("ledgr_store_append", function(orig) function(con,name,value) {
  state$appends[[length(state$appends)+1L]] <- data.frame(workload=state$label,table=name,n=NROW(value),pulse=state$pulse)
  orig(con,name,value)
})

fractional <- function() {
  db <- dr_fresh("fractional")
  bars <- data.frame(instrument_id="AAA",ts_utc=as.POSIXct("2020-01-01",tz="UTC")+86400*(0:47),
    open=13.37,high=14,low=13,close=13.37,volume=1000)
  snapshot <- ledgr::ledgr_snapshot_from_df(bars,db_path=db,snapshot_id="frac")
  strategy <- function(ctx,params) {
    i <- as.integer(as.Date(substr(ctx$ts_utc,1L,10L))-as.Date("2020-01-01"))+1L
    target <- ctx$hold()
    if (i%%3L==1L) target[["AAA"]] <- c(0.1,0.3,0.4,0.2,0.7,0.6,0.9,0.5,0.11,0.31,0.41,0.21,0.71,0.61,0.91,0.51)[(i+2L)%/%3L]
    target
  }
  exp <- ledgr::ledgr_experiment(snapshot,strategy,opening=ledgr::ledgr_opening(cash=1000),cost_model=ledgr::ledgr_cost_zero())
  list(db=db,snapshot=snapshot,exp=exp,params=list(),seed=1L)
}
builders <- list(crossover_500x1260=dr_crossover(500L,1260L),momentum_500x1260=dr_momentum(500L,1260L),
  dense_risk_features=dr_workloads$dense_risk_features,fractional=fractional)
metrics <- list()
diffs <- list()
for (id in names(builders)) {
  state$label <- id
  state$pulse <- 0L
  w <- builders[[id]]()
  t0 <- clock()
  bt <- suppressWarnings(ledgr::ledgr_run(w$exp,params=w$params,run_id="t2",seed=w$seed))
  run_s <- clock()-t0
  t0 <- clock()
  truth <- as.data.frame(tibble::as_tibble(ledgr::ledgr_results(bt,"diagnostics")))
  public_full_s <- clock()-t0
  candidate <- which(truth$stage=="decision" & truth$instrument_id!="" &
    truth$reason_code=="decision_recorded" & truth$target==truth$quantity & truth$mark_source=="current_close")
  explain_cell <- truth[tail(candidate,1L),,drop=FALSE]
  t0 <- clock()
  explanation <- ledgr::ledgr_run_explain(bt,explain_cell$instrument_id,explain_cell$ts_utc)
  public_explain_s <- clock()-t0
  # One point explanation at the last clean hold.
  close(bt)
  ledgr::ledgr_snapshot_close(w$snapshot)
  con <- DBI::dbConnect(duckdb::duckdb(),w$db)
  q <- function(sql) DBI::dbGetQuery(con,sql)
  imp <- q("SELECT * FROM run_diagnostic_implicit WHERE run_id='t2'")
  explicit <- q("SELECT * FROM run_diagnostics WHERE run_id='t2'")
  holds <- imp[is.na(imp$execution_seq),,drop=FALSE]
  fills <- imp[!is.na(imp$execution_seq),,drop=FALSE]
  if(id=="fractional") {
    ev <- q("SELECT ts_utc,position_delta FROM ledger_events WHERE run_id='t2' ORDER BY ts_utc,event_seq")
    cumulative <- Reduce(`+`,ev$position_delta,accumulate=TRUE)
    at <- findInterval(as.numeric(holds$ts_utc),as.numeric(ev$ts_utc))
    pos <- ifelse(at==0,0,cumulative[pmax(1L,at)])
    csv(data.frame(seq=holds$decision_seq,truth=sprintf("%.17g",holds$target),
      sequential=sprintf("%.17g",pos),exact=holds$target==pos),"fractional_sequential")
  }
  retained_mb <- as.numeric(object.size(explicit)+object.size(fills))/2^20
  cfg <- ns$ledgr_json_read_config(q("SELECT config_json FROM runs WHERE run_id='t2'")$config_json)
  axis <- data.frame(instrument_id=as.character(cfg$universe$instrument_ids),k=seq_along(cfg$universe$instrument_ids))
  DBI::dbWriteTable(con,"t2_axis",axis,temporary=TRUE)
  DBI::dbExecute(con,"CREATE TEMP TABLE t2_counts AS SELECT ts_utc,count(*)::INTEGER AS n FROM run_diagnostic_implicit WHERE run_id='t2' AND execution_seq IS NULL GROUP BY ts_utc")
  base_sql <- ns$ledgr_diagnostic_logical_sql()
  # Baseline SQL boundary on unchanged store; public boundary is reported separately.
  times <- numeric(3L)
  for (j in 1:3) {t0<-clock(); baseline<-q(paste(base_sql,"ORDER BY diagnostic_seq"));times[j]<-clock()-t0}
  point <- holds[nrow(holds),,drop=FALSE]
  pred <- paste0(" WHERE instrument_id='",point$instrument_id,"' AND ((stage='decision' AND ts_utc=TIMESTAMP '",
    format(point$ts_utc,"%Y-%m-%d %H:%M:%S",tz="UTC"),"') OR (stage='execution' AND decision_ts_utc=TIMESTAMP '",
    format(point$ts_utc,"%Y-%m-%d %H:%M:%S",tz="UTC"),"'))")
  ptimes <- numeric(3L)
  for (j in 1:3) {t0<-clock(); base_point<-q(paste0("SELECT * FROM (",base_sql,") v",pred," ORDER BY diagnostic_seq"));ptimes[j]<-clock()-t0}
  DBI::dbExecute(con,"DELETE FROM run_diagnostic_implicit WHERE run_id='t2' AND execution_seq IS NULL")
  certify(con)
  full_sql <- paste0(base_sql," UNION ALL SELECT * FROM (",hold_sql(),") ORDER BY diagnostic_seq")
  full_times <- numeric(3L)
  for (j in 1:3) {t0<-clock(); rebuilt<-q(full_sql);full_times[j]<-clock()-t0}
  rebuilt$reasons[rebuilt$stage=="sizing" & !is.na(rebuilt$reasons) & !nzchar(rebuilt$reasons)] <- NA_character_
  equal <- identical(truth,rebuilt)
  if(!equal) cat(paste(all.equal(truth,rebuilt),collapse="\n"),"\n")
  if (!equal) {
    bad_cols <- names(truth)[!vapply(names(truth),function(nm) identical(truth[[nm]],rebuilt[[nm]]),logical(1))]
    for (nm in bad_cols) {
      hits <- which((is.na(truth[[nm]]) != is.na(rebuilt[[nm]])) |
        (!is.na(truth[[nm]]) & !is.na(rebuilt[[nm]]) & truth[[nm]] != rebuilt[[nm]]))
      if(length(hits)) diffs[[length(diffs)+1L]] <- data.frame(workload=id,column=nm,seq=truth$diagnostic_seq[hits],
        original=a0_fmt_atomic(truth[[nm]][hits]),rebuilt=a0_fmt_atomic(rebuilt[[nm]][hits]))
    }
  }
  point_sql <- paste0("SELECT * FROM (",base_sql," UNION ALL SELECT * FROM (",
    hold_sql(point$instrument_id,point$ts_utc),")) v",pred," ORDER BY diagnostic_seq")
  point_times <- numeric(3L)
  for (j in 1:3) {t0<-clock(); rebuilt_point<-q(point_sql);point_times[j]<-clock()-t0}
  t0<-clock(); certify(con); certified_s<-clock()-t0
  DBI::dbExecute(con,"UPDATE t2_counts SET n=n-1 WHERE ts_utc=(SELECT min(ts_utc) FROM t2_counts)")
  gut <- tryCatch({certify(con);"missed"},error=function(e) class(e)[[1L]])
  metrics[[length(metrics)+1L]] <- data.frame(workload=id,logical=nrow(truth),holds=nrow(holds),fills=nrow(fills),
    explicit=nrow(explicit),retained_mb=retained_mb,run_s=run_s,public_full_s=public_full_s,public_explain_s=public_explain_s,
    base_sql_s=median(times),rebuilt_sql_s=median(full_times),base_point_s=median(ptimes),rebuilt_point_s=median(point_times),
    certify_s=certified_s,exact_full=equal,exact_point=identical(base_point,rebuilt_point),gut=gut)
  DBI::dbDisconnect(con,shutdown=TRUE)
  cat(id, "full exact",equal,"retained MiB",retained_mb,"\n")
  csv(do.call(rbind,metrics),"sql_metrics")
}
csv(if(length(diffs))do.call(rbind,diffs)else data.frame(),"sql_differences")
csv(do.call(rbind,state$recon),"reconciliation_values")
csv(do.call(rbind,state$segments),"decision_segments")
csv(do.call(rbind,state$appends),"appends")
