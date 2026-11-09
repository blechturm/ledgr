source("C:/Users/maxth/ledgr-wt/diag-records-t2-out/probe/common.R")
state <- new.env()
state$label <- ""
state$segments <- list()
state$sql <- list()
state$tuples <- list()
state$boundaries <- list()
for(name in c("ledgr_diagnostic_decode","ledgr_diagnostic_next_seq","ledgr_run_restart_nonterminal",
              "ledgr_run_completion_info_many","ledgr_run_completion_validate_finalized")) {
  local({nm<-name
    wrap(nm,function(orig) function(...) {
      state$boundaries[[length(state$boundaries)+1L]] <- data.frame(path=state$label,boundary=nm)
      orig(...)
    })
  })
}
wrap("ledgr_fold_diagnostic_segment",function(orig) function(segment,ts) {
  s <- orig(segment,ts)
  if (identical(s$stage,"decision")) {
    state$segments[[length(state$segments)+1L]] <- data.frame(path=state$label,
      seq=seq_len(s$n),id=rep_len(s$instrument_id,s$n),
      reason=rep_len(s$reason_code,s$n),after_risk=rep_len(s$target_after_risk,s$n))
  }
  s
})
wrap("ledgr_fold_reconciliation_check",function(orig) function(...) {
  values <- list(...)
  state$tuples[[length(state$tuples)+1L]] <- cbind(path=state$label,
    as.data.frame(lapply(values,function(x)sprintf("%.17g",x))))
  orig(...)
})
.t2_query <- function(statement) {
  if (is.character(statement) && grepl("run_diagnostic",statement,fixed=TRUE)) {
    state$sql[[length(state$sql)+1L]] <- data.frame(path=state$label,
      caller=ws16_caller(character()),sql=statement)
  }
}
trace("dbGetQuery",where=asNamespace("DBI"),tracer=quote(.t2_query(statement)),print=FALSE)

db <- dr_fresh("edges")
dates <- as.Date("2020-01-01")+0:3
bars <- data.frame(instrument_id="CLOCK",ts_utc=as.POSIXct(paste(dates,"16:00:00"),tz="UTC"),
  open=100,high=101,low=99,close=100,volume=1000)
snapshot <- ledgr::ledgr_snapshot_from_df(bars,instruments_df=data.frame(instrument_id=c("AAA","CLOCK")),
  db_path=db,snapshot_id="edges",facts=ledgr::ledgr_facts(a0_sessions(dates)),price_basis="split_adjusted")
strategy <- function(ctx,params) {
  if (identical(params$mode,"sizing")) return(list(targets=ledgr::ledgr_target_rebalance(ctx,
    weights=c(AAA=1),index_leavers="keep",capital_base="remaining_equity")))
  t <- ctx$hold()
  if (identical(params$mode,"risk_stop")) t[["AAA"]] <- 1
  if (identical(params$mode,"risk")) t[["CLOCK"]] <- -1
  if (identical(params$mode,"tiny")) t[["CLOCK"]] <- 1e-10
  t
}
exp <- ledgr::ledgr_experiment(snapshot,strategy,opening=ledgr::ledgr_opening(cash=1000),
  valuation_policy=ledgr::ledgr_valuation_stale(1L),cost_model=ledgr::ledgr_cost_zero(),
  risk_chain=ledgr::ledgr_risk_chain(ledgr::ledgr_risk_long_only()))
rows <- list()
for(mode in c("risk_stop","sizing","risk","tiny")) {
  state$label <- mode
  bt <- suppressWarnings(ledgr::ledgr_run(exp,params=list(mode=mode),run_id=mode,seed=1L))
  d <- as.data.frame(tibble::as_tibble(ledgr::ledgr_results(bt,"diagnostics")))
  csv(d,paste0("edge_",mode))
  info <- ledgr::ledgr_run_info(snapshot,mode)
  rows[[length(rows)+1L]] <- data.frame(path=mode,n=nrow(d),decision=sum(d$stage=="decision"),
    stopped=sum(d$outcome=="stopped"),sizing_unavailable=sum(d$reason_code=="sizing_unavailable"))
  close(bt)
}
# Gut an internal plan's expected cash to execute P3's contracted stop.
state$label <- "p3_stop_gut"
old <- wrap("ledgr_fold_build_availability_pulse_plan",function(orig) function(...) {
  b<-orig(...); b$expected_final_cash<-b$expected_final_cash+1; b
})
bt <- suppressWarnings(ledgr::ledgr_run(exp,params=list(mode="hold"),run_id="p3",seed=1L))
csv(as.data.frame(tibble::as_tibble(ledgr::ledgr_results(bt,"diagnostics"))),"edge_p3")
close(bt)
restore("ledgr_fold_build_availability_pulse_plan",old)

# Same economic outputs, different intended gross exposure: cash/events cannot
# identify this tuple. Long-only maps two distinct negative requests to zero.
exp2 <- ledgr::ledgr_experiment(snapshot,function(ctx,params){t<-ctx$hold();t[["CLOCK"]]<-params$qty;t},
  opening=ledgr::ledgr_opening(cash=1000),valuation_policy=ledgr::ledgr_valuation_stale(1L),
  cost_model=ledgr::ledgr_cost_zero(),risk_chain=ledgr::ledgr_risk_chain(ledgr::ledgr_risk_long_only()))
econ <- list()
for(qty in c(-1,-2)) {
  state$label <- paste0("recon",qty)
  bt <- ledgr::ledgr_run(exp2,params=list(qty=qty),run_id=state$label,seed=1L)
  econ[[length(econ)+1L]] <- lapply(c("ledger","equity"),function(what){
    x<-tibble::as_tibble(ledgr::ledgr_results(bt,what)); x$run_id<-NULL; x
  })
  close(bt)
}
csv(data.frame(ledger_equal=identical(econ[[1]][[1]],econ[[2]][[1]]),
  equity_equal=identical(econ[[1]][[2]],econ[[2]][[2]])),"recon_economics")
state$label <- "promotion"
sw <- ledgr::ledgr_sweep(exp2,ledgr::ledgr_grid_named(only=list(strategy=list(qty=-1))),seed=1L)
candidate <- ledgr::ledgr_candidate(sw)
bt <- ledgr::ledgr_promote(exp2,candidate,run_id="promoted")
close(bt)
state$label <- "comparison"
comparison <- ledgr::ledgr_run_compare(snapshot,run_ids=c("promoted","recon-1","recon-2"))
csv(data.frame(rows=nrow(comparison)),"comparison")
# Publication recovery on disposable output, with valid committed completion.
con <- DBI::dbConnect(duckdb::duckdb(),db)
state$label <- "batched_completion"
ns$ledgr_run_completion_info_many(con,c("risk_stop","promoted"))
state$label <- "numbering"
next_seq <- ns$ledgr_diagnostic_next_seq(con,"risk_stop")
csv(data.frame(next_seq=next_seq),"numbering")
DBI::dbExecute(con,"UPDATE runs SET status='RUNNING' WHERE run_id='risk_stop'")
DBI::dbDisconnect(con,shutdown=TRUE)
state$label <- "recovery"
bt <- ledgr::ledgr_run(exp,params=list(mode="risk_stop"),run_id="risk_stop",seed=1L)
close(bt)
con <- DBI::dbConnect(duckdb::duckdb(),db)
DBI::dbExecute(con,"UPDATE runs SET status='FAILED' WHERE run_id='tiny'")
DBI::dbExecute(con,"DELETE FROM run_completion WHERE run_id='tiny'")
DBI::dbDisconnect(con,shutdown=TRUE)
state$label <- "restart"
bt <- ledgr::ledgr_run(exp,params=list(mode="tiny"),run_id="tiny",seed=1L)
close(bt)
ledgr::ledgr_snapshot_close(snapshot)
untrace("dbGetQuery",where=asNamespace("DBI"))
csv(do.call(rbind,rows),"edge_counts")
csv(do.call(rbind,state$segments),"edge_segments")
csv(do.call(rbind,state$tuples),"edge_tuples")
csv(unique(do.call(rbind,state$sql)),"consumer_queries")
csv(do.call(rbind,state$boundaries),"consumer_boundaries")
cat("Edge and consumer probes complete\n")
