source("C:/Users/maxth/ledgr-wt/diag-records-t2-out/probe/common.R")
state <- jsonlite::read_json("E:/ledgr-data/sharadar/experiments/WS25-private-gate/rebuild-cad309f4/build-state.json",simplifyVector=TRUE)
# Vendor rows stay outside the response directory. Only aggregates are emitted.
db <- file.path(tempdir(),"diagnostic-t2-h1.duckdb")
stopifnot(file.copy(state$snapshot_path,db))
snapshot <- ledgr::ledgr_snapshot_open(db,state$snapshot_id,verify=TRUE)
stopifnot(identical(ledgr::ledgr_snapshot_info(snapshot)$snapshot_hash[[1L]],state$snapshot_hash))
exp <- ledgr::ledgr_experiment(snapshot,ws16_momentum_strategy,
  features=list(ledgr::ledgr_ind_returns(252L)),schedule=ledgr::ledgr_schedule_month_start(),
  universe=ledgr::ledgr_universe_members(state$universe_id),valuation_policy=ledgr::ledgr_valuation_stale(5L),
  cost_model=ledgr::ledgr_cost_zero(),opening=ledgr::ledgr_opening(cash=1e6))
t0 <- clock()
error <- ""
bt <- tryCatch(ledgr::ledgr_run(exp,params=list(lookback=252L,n=20L),run_id="t2-h1",seed=1L),
  error=function(e){error<<-paste(class(e)[[1L]],conditionMessage(e));NULL})
run_s <- clock()-t0
if(!is.null(bt))close(bt)
ledgr::ledgr_snapshot_close(snapshot)
con <- DBI::dbConnect(duckdb::duckdb(),db,read_only=TRUE)
q <- function(sql) DBI::dbGetQuery(con,sql)
E <- q("SELECT * FROM run_diagnostics WHERE run_id='t2-h1'")
Fi <- q("SELECT * FROM run_diagnostic_implicit WHERE run_id='t2-h1' AND execution_seq IS NOT NULL")
counts <- q("SELECT count(*) AS n, count(DISTINCT ts_utc) AS pulses FROM run_diagnostic_implicit WHERE run_id='t2-h1' AND execution_seq IS NULL")
ledger <- q("SELECT * FROM ledger_events WHERE run_id='t2-h1'")
equity <- q("SELECT * FROM equity_curve WHERE run_id='t2-h1'")
csv(data.frame(snapshot_hash=state$snapshot_hash,run_s=run_s,error=error,
  status=q("SELECT status FROM runs WHERE run_id='t2-h1'")$status,
  explicit_rows=nrow(E),fill_rows=nrow(Fi),hold_rows=counts$n,hold_pulses=counts$pulses,
  explicit_mib=as.numeric(object.size(E))/2^20,fill_mib=as.numeric(object.size(Fi))/2^20,
  ledger_mib=as.numeric(object.size(ledger))/2^20,equity_mib=as.numeric(object.size(equity))/2^20),"h1")
csv(q("SELECT stage,outcome,count(*) AS n FROM run_diagnostics WHERE run_id='t2-h1' GROUP BY 1,2 ORDER BY 1,2"),"h1_kinds")
DBI::dbDisconnect(con,shutdown=TRUE)
cat("H1 aggregate record written\n")
