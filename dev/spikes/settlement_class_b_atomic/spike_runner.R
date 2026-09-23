#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
repo_root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
gut_mode <- "--gut-parent-consumption" %in% args
git_config <- tempfile("ledgr-class-b-gitconfig-")
writeLines(c("[safe]", paste0("\tdirectory = ", repo_root)), git_config)
Sys.setenv(GIT_CONFIG_GLOBAL = git_config)
on.exit(unlink(git_config, force = TRUE), add = TRUE)

copy_tracked_package <- function(source, destination) {
  tracked <- system2("git", c("-C", shQuote(source), "ls-files"),
                     stdout = TRUE, stderr = TRUE)
  if (!is.null(attr(tracked, "status")) && attr(tracked, "status") != 0L) {
    stop(paste(tracked, collapse = "\n"), call. = FALSE)
  }
  for (relative in tracked[nzchar(tracked)]) {
    from <- file.path(source, relative)
    to <- file.path(destination, relative)
    dir.create(dirname(to), recursive = TRUE, showWarnings = FALSE)
    if (!file.copy(from, to, overwrite = TRUE, copy.mode = TRUE)) {
      stop("Could not copy tracked file: ", relative, call. = FALSE)
    }
  }
}

prototype_lines <- c(
  "ledgr_spike_group_recipients <- function(value) {",
  "  if (is.data.frame(value)) return(value)",
  "  if (!is.list(value) || !length(value)) return(data.frame())",
  "  rows <- lapply(value, function(x) data.frame(",
  "    instrument_id=as.character(x$instrument_id),",
  "    ratio=as.numeric(x$ratio),",
  "    basis_fraction=as.numeric(x$basis_fraction),",
  "    stringsAsFactors=FALSE))",
  "  do.call(rbind, rows)",
  "}",
  "",
  "ledgr_spike_validate_settlement_group <- function(group, state) {",
  "  if (!is.list(group)) rlang::abort('Settlement group must be a list.',",
  "    class=c('ledgr_invalid_settlement_group','ledgr_invalid_state'))",
  "  parent <- as.character(group$parent_instrument_id)",
  "  recipients <- ledgr_spike_group_recipients(group$recipients)",
  "  parent_fraction <- as.numeric(group$parent_basis_fraction)",
  "  source_identity <- as.character(group$source_identity)",
  "  valid_head <- length(parent)==1L && !is.na(parent) && nzchar(parent) &&",
  "    nrow(recipients)>0L && length(parent_fraction)==1L &&",
  "    is.finite(parent_fraction) && parent_fraction>=0 && parent_fraction<=1 &&",
  "    length(source_identity)==1L && !is.na(source_identity) && nzchar(source_identity)",
  "  if (!valid_head || !all(c('instrument_id','ratio','basis_fraction') %in% names(recipients)))",
  "    rlang::abort('Settlement group header is malformed.',",
  "      class=c('ledgr_invalid_settlement_group','ledgr_invalid_state'))",
  "  recipients$instrument_id <- as.character(recipients$instrument_id)",
  "  recipients$ratio <- as.numeric(recipients$ratio)",
  "  recipients$basis_fraction <- as.numeric(recipients$basis_fraction)",
  "  bad <- anyNA(recipients) || any(!nzchar(recipients$instrument_id)) ||",
  "    anyDuplicated(recipients$instrument_id) || parent %in% recipients$instrument_id ||",
  "    any(!is.finite(recipients$ratio) | recipients$ratio<=0) ||",
  "    any(!is.finite(recipients$basis_fraction) | recipients$basis_fraction<0) ||",
  "    abs(parent_fraction + sum(recipients$basis_fraction) - 1) > 1e-12",
  "  if (bad) rlang::abort('Settlement legs or basis allocation are malformed.',",
  "    class=c('ledgr_invalid_settlement_group','ledgr_invalid_state'))",
  "  parent_idx <- unname(state$instrument_index[parent])",
  "  if (length(parent_idx)!=1L || is.na(parent_idx))",
  "    rlang::abort('Settlement parent is absent.',",
  "      class=c('ledgr_invalid_settlement_group','ledgr_invalid_state'))",
  "  parent_values <- ledgr_lot_values(state,parent)",
  "  parent_qty <- as.numeric(state$net_by_inst[[parent_idx]])",
  "  parent_basis <- as.numeric(state$cost_basis_by_inst[[parent_idx]])",
  "  if (parent_qty<=0 || !length(parent_values$qty) || any(parent_values$qty<=0) ||",
  "      !isTRUE(all.equal(sum(parent_values$qty),parent_qty)))",
  "    rlang::abort('Settlement requires supported positive parent lots.',",
  "      class=c('ledgr_invalid_settlement_group','ledgr_invalid_state'))",
  "  for (id in recipients$instrument_id) {",
  "    values <- ledgr_lot_values(state,id)",
  "    if (length(values$qty) && any(values$qty<0))",
  "      rlang::abort('Settlement cannot cross a short recipient lot.',",
  "        class=c('ledgr_invalid_settlement_group','ledgr_invalid_state'))",
  "  }",
  "  list(parent=parent,parent_idx=parent_idx,recipients=recipients,",
  "    parent_fraction=parent_fraction,parent_values=parent_values,",
  "    parent_qty=parent_qty,parent_basis=parent_basis,source_identity=source_identity)",
  "}",
  "",
  "ledgr_spike_apply_settlement_group <- function(state, group) {",
  "  spec <- ledgr_spike_validate_settlement_group(group,state)",
  "  before_basis <- as.numeric(state$total_cost_basis)",
  "  out <- state",
  "  if (!isTRUE(getOption('ledgr.spike_gut_parent_consumption',FALSE))) {",
  "    if (spec$parent_fraction==0) {",
  "      out$lot_qty[[spec$parent_idx]][] <- NA_real_",
  "      out$lot_price[[spec$parent_idx]][] <- NA_real_",
  "      out$lot_head[[spec$parent_idx]] <- 1L",
  "      out$lot_tail[[spec$parent_idx]] <- 0L",
  "      out$net_by_inst[[spec$parent_idx]] <- 0",
  "      out$cost_basis_by_inst[[spec$parent_idx]] <- 0",
  "    } else {",
  "      live <- seq.int(out$lot_head[[spec$parent_idx]],out$lot_tail[[spec$parent_idx]])",
  "      out$lot_price[[spec$parent_idx]][live] <-",
  "        out$lot_price[[spec$parent_idx]][live] * spec$parent_fraction",
  "      out$cost_basis_by_inst[[spec$parent_idx]] <- spec$parent_basis*spec$parent_fraction",
  "    }",
  "  }",
  "  for (leg_i in seq_len(nrow(spec$recipients))) {",
  "    id <- spec$recipients$instrument_id[[leg_i]]",
  "    ratio <- spec$recipients$ratio[[leg_i]]",
  "    fraction <- spec$recipients$basis_fraction[[leg_i]]",
  "    ensured <- ledgr_lot_ensure_instrument(out,id)",
  "    out <- ensured$state; idx <- ensured$index",
  "    for (lot_i in seq_along(spec$parent_values$qty)) {",
  "      appended <- ledgr_lot_append_vectors(out$lot_qty[[idx]],out$lot_price[[idx]],",
  "        out$lot_head[[idx]],out$lot_tail[[idx]],",
  "        spec$parent_values$qty[[lot_i]]*ratio,",
  "        spec$parent_values$price[[lot_i]]*fraction/ratio)",
  "      out$lot_qty[[idx]] <- appended$qty; out$lot_price[[idx]] <- appended$price",
  "      out$lot_head[[idx]] <- appended$head; out$lot_tail[[idx]] <- appended$tail",
  "    }",
  "    out$net_by_inst[[idx]] <- out$net_by_inst[[idx]] + spec$parent_qty*ratio",
  "    out$cost_basis_by_inst[[idx]] <- out$cost_basis_by_inst[[idx]] +",
  "      spec$parent_basis*fraction",
  "  }",
  "  out$total_cost_basis <- sum(out$cost_basis_by_inst)",
  "  tol <- ledgr_lot_dust_tolerance(before_basis,out$total_cost_basis)",
  "  if (abs(out$total_cost_basis-before_basis)>tol)",
  "    rlang::abort('Settlement did not preserve total model basis.',",
  "      class=c('ledgr_settlement_basis_invariant','ledgr_invalid_state'))",
  "  out",
  "}",
  "",
  "ledgr_spike_settlement_event_row <- function(run_id,ts,event_seq,group) {",
  "  serialized <- group",
  "  serialized$recipients <- lapply(seq_len(nrow(group$recipients)),function(i)",
  "    as.list(group$recipients[i,,drop=FALSE]))",
  "  meta <- list(source='proto:equity_settlement',cash_delta=0,position_delta=0,",
  "    settlement=serialized,source_identity=group$source_identity)",
  "  data.frame(event_id=paste0('proto:settlement:',group$source_identity,':',event_seq),",
  "    run_id=run_id,ts_utc=as.POSIXct(ts,tz='UTC'),event_type='CASHFLOW',",
  "    instrument_id=group$parent_instrument_id,side=NA_character_,qty=NA_real_,",
  "    price=NA_real_,fee=0,meta_json=canonical_json(meta),event_seq=as.integer(event_seq),",
  "    stringsAsFactors=FALSE)",
  "}",
  "",
  ".ledgr_spike_original_prepare <- ledgr_prepare_accounting_events",
  "ledgr_prepare_accounting_events <- function(columns,instrument_ids=character()) {",
  "  out <- .ledgr_spike_original_prepare(columns,instrument_ids)",
  "  special <- vapply(out$meta,function(x) is.list(x) &&",
  "    identical(x$source,'proto:equity_settlement'),logical(1))",
  "  if (any(special)) {",
  "    for (i in which(special)) {",
  "      if (is.null(out$meta[[i]]$settlement))",
  "        rlang::abort('Settlement metadata is missing.',",
  "          class=c('ledgr_invalid_settlement_group','ledgr_invalid_state'))",
  "      out$operation[[i]] <- 4L",
  "    }",
  "  }",
  "  out",
  "}",
  "",
  "ledgr_replay_accounting_events <- function(prepared,initial_cash=0,",
  "    initial_positions=NULL,lot_state=NULL) {",
  "  if (!inherits(prepared,'ledgr_prepared_accounting_events'))",
  "    rlang::abort('`prepared` must be prepared accounting events.',class='ledgr_invalid_args')",
  "  ids <- prepared$instrument_ids",
  "  if (is.null(lot_state)) lot_state <- ledgr_lot_state(ids)",
  "  positions <- stats::setNames(rep(0,length(ids)),ids)",
  "  if (!is.null(initial_positions) && length(initial_positions)) {",
  "    matched <- intersect(names(initial_positions),ids)",
  "    positions[matched] <- as.numeric(initial_positions[matched])",
  "  }",
  "  cash <- as.numeric(initial_cash); n <- length(prepared$event_seq)",
  "  cash_after <- position_after <- event_realized <- event_cost_basis <- numeric(n)",
  "  close_qty <- open_qty <- realized_close <- realized_delta <- numeric(n)",
  "  position_matrix <- matrix(0,nrow=length(ids),ncol=n,dimnames=list(ids,NULL))",
  "  for (i in seq_len(n)) {",
  "    cash <- cash + prepared$cash_delta[[i]]",
  "    idx <- prepared$instrument_index[[i]]",
  "    if (prepared$operation[[i]]==4L) {",
  "      lot_state <- ledgr_spike_apply_settlement_group(",
  "        lot_state,prepared$meta[[i]]$settlement)",
  "      positions <- lot_state$net_by_inst[ids]",
  "      position_after[[i]] <- positions[[idx]]",
  "    } else {",
  "      if (!is.na(idx)) { positions[[idx]] <- positions[[idx]]+prepared$position_delta[[i]]",
  "        position_after[[i]] <- positions[[idx]] } else position_after[[i]] <- NA_real_",
  "      result <- ledgr_lot_apply_event(lot_state,event_type=prepared$event_type[[i]],",
  "        instrument_id=prepared$instrument_id[[i]],side=prepared$side[[i]],",
  "        qty=prepared$qty[[i]],price=prepared$price[[i]],fee=prepared$fee[[i]],",
  "        meta=prepared$meta[[i]])",
  "      lot_state <- result$state",
  "      if (prepared$operation[[i]]==1L) { close_qty[[i]]<-result$close_qty",
  "        open_qty[[i]]<-result$open_qty; realized_close[[i]]<-result$realized_close",
  "        realized_delta[[i]]<-result$realized_delta }",
  "    }",
  "    if (n) position_matrix[,i] <- positions",
  "    cash_after[[i]] <- cash; event_realized[[i]] <- lot_state$realized_pnl",
  "    event_cost_basis[[i]] <- lot_state$total_cost_basis",
  "  }",
  "  list(prepared=prepared,lot_state=lot_state,cash=cash,positions=positions,",
  "    cash_after=cash_after,position_after=position_after,event_realized=event_realized,",
  "    event_cost_basis=event_cost_basis,close_qty=close_qty,open_qty=open_qty,",
  "    realized_close=realized_close,realized_delta=realized_delta,",
  "    event_seq=prepared$event_seq,positions_after_matrix=position_matrix)",
  "}",
  "",
  "ledgr_accounting_positions_at_pulses <- function(replay,pulses_posix,instrument_ids) {",
  "  requested <- match(instrument_ids,replay$prepared$instrument_ids)",
  "  out <- matrix(0,nrow=length(instrument_ids),ncol=length(pulses_posix),",
  "    dimnames=list(instrument_ids,NULL))",
  "  at <- findInterval(as.numeric(as.POSIXct(pulses_posix,tz='UTC')),",
  "    as.numeric(replay$prepared$ts_utc))",
  "  present <- at>0L",
  "  if (any(present)) out[,present] <- replay$positions_after_matrix[requested,at[present],drop=FALSE]",
  "  out",
  "}"
)

install_prototype <- function(package_root) {
  writeLines(prototype_lines,file.path(package_root,"R","zz-settlement-spike.R"),
             sep="\r\n",useBytes=TRUE)
}

install_fold_seam <- function(package_root) {
  path <- file.path(package_root,"R","fold-engine.R")
  lines <- readLines(path,warn=FALSE)
  accounting <- which(lines == '      current_fold_stage <<- "accounting"')
  marker <- which(lines == '      if (availability_active) {')
  marker <- marker[marker > accounting[[1L]]][[1L]]
  seam <- c(
    "      spike_injector <- getOption('ledgr.spike_settlement_injector',NULL)",
    "      if (is.function(spike_injector)) {",
    "        group <- spike_injector(i,ts,run_id,event_seq,state)",
    "        if (!is.null(group)) {",
    "          if (use_compiled_spot_fifo) rlang::abort(",
    "            'Compiled accounting does not support settlement groups.',",
    "            class=c('ledgr_unsupported_compiled_accounting_event','ledgr_invalid_state'))",
    "          next_lots <- ledgr_spike_apply_settlement_group(state$lot_state,group)",
    "          row <- ledgr_spike_settlement_event_row(run_id,ts,event_seq,group)",
    "          output_handler$append_event_rows(row)",
    "          state$lot_state <- next_lots",
    "          state$positions <- unname(next_lots$net_by_inst[instrument_ids])",
    "          state <<- state",
    "          event_seq <- event_seq + 1L",
    "        }",
    "      }"
  )
  lines <- append(lines,seam,after=marker-1L)
  writeLines(lines,path,sep="\r\n",useBytes=TRUE)
}

make_group <- function(kind,malformed=FALSE) {
  if (kind=="stock") { recipients<-data.frame(instrument_id="CHILD",ratio=.5,
      basis_fraction=1); parent_fraction<-0
  } else if (kind=="spin") { recipients<-data.frame(instrument_id="CHILD",ratio=.5,
      basis_fraction=.2); parent_fraction<-.8
  } else if (kind=="multi") { recipients<-data.frame(
      instrument_id=c("CHILD","CHILD2"),ratio=c(.5,.25),
      basis_fraction=c(.75,.25)); parent_fraction<-0
  } else stop("unknown group kind",call.=FALSE)
  if (malformed) recipients$basis_fraction[[1L]]<-1.1
  list(source_identity=paste0("source-",kind),parent_instrument_id="PARENT",
       parent_basis_fraction=parent_fraction,recipients=recipients)
}

make_execution <- function(run_id,state,compiled=NULL) {
  pulses<-as.POSIXct(c("2024-01-02 21:00:00","2024-01-03 21:00:00",
    "2024-01-04 21:00:00"),tz="UTC")
  iso<-vapply(pulses,ledgr_normalize_ts_utc,character(1)); ids<-c("PARENT","CHILD","CHILD2")
  close<-matrix(c(10,11,12,20,21,22,30,31,32),nrow=3,byrow=TRUE,
    dimnames=list(ids,iso))
  bars_mat<-list(open=close,high=close,low=close,close=close,
    volume=matrix(1000,3,3,dimnames=dimnames(close)),gap_type=matrix("",3,3,
    dimnames=dimnames(close)),is_synthetic=matrix(FALSE,3,3,dimnames=dimnames(close)))
  bars_by_id<-stats::setNames(lapply(ids,function(id) data.frame(instrument_id=id,
    ts_utc=pulses,open=close[id,],high=close[id,],low=close[id,],close=close[id,],
    volume=1000,gap_type="",is_synthetic=FALSE,stringsAsFactors=FALSE)),ids)
  strategy<-function(ctx,params) ctx$hold()
  resolver<-ledgr_cost_resolver_from_model(ledgr_cost_chain(
    ledgr_cost_spread_bps(0),ledgr_cost_fixed_fee(0)))
  ledgr_execution_spec(run_id=run_id,instrument_ids=ids,strategy_fn=strategy,
    strategy_params=list(),strategy_call_signature=ledgr_strategy_signature(strategy),
    strategy_is_functional=TRUE,pulses_posix=pulses,pulses_iso=iso,start_idx=1L,
    max_pulses=Inf,checkpoint_every=0L,telemetry_stride=0L,state=state,state_prev=NULL,
    bars_by_id=bars_by_id,bars_mat=bars_mat,static_bars_views=NULL,
    static_feature_views=NULL,feature_defs=list(),runtime_projection=
      ledgr_projection_from_feature_matrix(list(),ids,pulses),active_alias_map=NULL,
    risk_plan=NULL,cost_resolver=resolver,event_seq_start=1L,
    telemetry=ledgr_sweep_telemetry_env(),seed=1L,event_mode="buffered",
    use_fast_context=TRUE,compiled_accounting_model=compiled)
}

initial_state <- function(child=0,child_short=FALSE,multiple_parent=FALSE) {
  ids<-c("PARENT","CHILD","CHILD2"); lots<-ledgr_lot_state(ids)
  if(multiple_parent) { lots<-ledgr_lot_apply_opening(lots,"PARENT",2,8)
    lots<-ledgr_lot_apply_opening(lots,"PARENT",3,12)
  } else lots<-ledgr_lot_apply_opening(lots,"PARENT",5,10)
  if(child!=0) lots<-ledgr_lot_apply_opening(lots,"CHILD",child,20)
  if(child_short) lots<-ledgr_lot_apply_opening(lots,"CHILD",-1,20)
  list(cash=1000,positions=unname(lots$net_by_inst[ids]),lot_state=lots)
}

injector_for <- function(group) { force(group)
  function(i,ts,run_id,event_seq,state) if(i==2L) group else NULL }

summarize_case <- function(case_id,events,replay,error=NULL,reopened=FALSE) {
  ids<-c("PARENT","CHILD","CHILD2")
  settlement<-if(nrow(events)) vapply(replay$prepared$meta,function(x)
    is.list(x)&&identical(x$source,"proto:equity_settlement"),logical(1)) else logical()
  lots<-replay$lot_state
  data.frame(case_id=case_id,status=if(is.null(error)) "DONE" else "ERROR",
    error_class=if(is.null(error)) "" else class(error)[[1L]],event_count=nrow(events),
    settlement_count=sum(settlement),parent_position=unname(replay$positions[["PARENT"]]),
    child_position=unname(replay$positions[["CHILD"]]),
    child2_position=unname(replay$positions[["CHILD2"]]),
    parent_lot_count=ledgr_lot_count(lots,"PARENT"),
    child_lot_count=ledgr_lot_count(lots,"CHILD"),
    child2_lot_count=ledgr_lot_count(lots,"CHILD2"),
    parent_basis=unname(lots$cost_basis_by_inst[["PARENT"]]),
    child_basis=unname(lots$cost_basis_by_inst[["CHILD"]]),
    child2_basis=unname(lots$cost_basis_by_inst[["CHILD2"]]),
    total_basis=as.numeric(lots$total_cost_basis),realized=as.numeric(lots$realized_pnl),
    position_lot_agree=isTRUE(all.equal(as.numeric(replay$positions[ids]),
      as.numeric(lots$net_by_inst[ids]))),reopened=isTRUE(reopened),
    evidence_source="fold_and_replay",literal_excluded=FALSE,stringsAsFactors=FALSE)
}

run_direct <- function(case_id,group,state,compiled=NULL) {
  handler<-ledgr_memory_output_handler(paste0("proto-",case_id))
  old<-getOption("ledgr.spike_settlement_injector")
  on.exit(options(ledgr.spike_settlement_injector=old),add=TRUE)
  options(ledgr.spike_settlement_injector=injector_for(group))
  error<-NULL
  tryCatch(ledgr_execute_fold(make_execution(paste0("proto-",case_id),state,compiled),handler),
    error=function(e) error<<-e)
  events<-handler$typed_events()
  prepared<-ledgr_prepare_accounting_events(events,c("PARENT","CHILD","CHILD2"))
  replay<-ledgr_replay_accounting_events(prepared,initial_cash=state$cash,
    initial_positions=stats::setNames(state$positions,c("PARENT","CHILD","CHILD2")),
    lot_state=state$lot_state)
  summarize_case(case_id,events,replay,error)
}

run_resume <- function(scratch_root) {
  prior<-options(ledgr.interrupt=FALSE,ledgr.spike_interrupt_done=FALSE,
    ledgr.spike_settlement_injector=injector_for(make_group("stock")))
  on.exit(options(prior),add=TRUE)
  pulses<-as.POSIXct("2024-01-02 21:00:00",tz="UTC")+86400*0:2
  bars<-expand.grid(instrument_id=c("PARENT","CHILD","CHILD2"),ts_utc=pulses,
    KEEP.OUT.ATTRS=FALSE,stringsAsFactors=FALSE)
  bars<-bars[order(bars$instrument_id,bars$ts_utc),,drop=FALSE]
  bars$open<-ifelse(bars$instrument_id=="PARENT",10,
    ifelse(bars$instrument_id=="CHILD",20,30))
  bars$high<-bars$open; bars$low<-bars$open; bars$close<-bars$open; bars$volume<-1000
  db_path<-file.path(scratch_root,"resume.duckdb")
  snapshot<-ledgr_snapshot_from_df(bars,db_path=db_path)
  on.exit(ledgr_snapshot_close(snapshot),add=TRUE)
  strategy<-function(ctx,params) { if(!isTRUE(getOption("ledgr.spike_interrupt_done",FALSE))) {
      options(ledgr.interrupt=TRUE,ledgr.spike_interrupt_done=TRUE) }; ctx$hold() }
  experiment<-ledgr_experiment(snapshot,strategy,cost_model=ledgr_cost_zero(),
    opening=ledgr_opening(cash=1000,positions=c(PARENT=5),cost_basis=c(PARENT=10)))
  first<-ledgr_run(experiment,run_id="proto-resume"); close(first)
  options(ledgr.interrupt=FALSE)
  resumed<-ledgr_run(experiment,run_id="proto-resume"); close(resumed)
  reopened<-ledgr_run_open(snapshot,"proto-resume"); on.exit(close(reopened),add=TRUE)
  store<-ledgr_run_store_open(db_path); on.exit(ledgr_run_store_close(store),add=TRUE)
  events<-DBI::dbGetQuery(store$con,paste("SELECT event_id,run_id,ts_utc,event_type,",
    "instrument_id,side,qty,price,fee,meta_json,event_seq FROM ledger_events",
    "WHERE run_id=? ORDER BY event_seq"),params=list("proto-resume"))
  prepared<-ledgr_prepare_accounting_events(events,c("PARENT","CHILD","CHILD2"))
  replay<-ledgr_replay_accounting_events(prepared,initial_cash=1000)
  summarize_case("case_7_resume",events,replay,reopened=TRUE)
}

scratch<-tempfile("ledgr-class-b-fork-"); dir.create(scratch,recursive=TRUE)
on.exit(unlink(scratch,recursive=TRUE,force=TRUE),add=TRUE)
copy_tracked_package(repo_root,scratch); install_prototype(scratch); install_fold_seam(scratch)
pkgload::load_all(scratch,quiet=TRUE,export_all=TRUE)
options(ledgr.spike_gut_parent_consumption=gut_mode)

if(gut_mode) cases<-list(run_direct("case_1_stock",make_group("stock"),initial_state())) else
  cases<-list(run_direct("case_1_stock",make_group("stock"),initial_state()),
    run_direct("case_2_spinoff",make_group("spin"),initial_state()),
    run_direct("case_3_multi",make_group("multi"),initial_state()),
    run_direct("case_4_existing_recipient",make_group("stock"),initial_state(child=1)),
    run_direct("case_5_malformed",make_group("stock",TRUE),initial_state()),
    run_direct("case_6_short_recipient",make_group("stock"),initial_state(child_short=TRUE)),
    run_resume(scratch),
    run_direct("case_8_compiled_refusal",make_group("stock"),initial_state(),"spot_fifo"),
    run_direct("case_9_multiple_parent_lots",make_group("stock"),
      initial_state(multiple_parent=TRUE)))
evidence<-do.call(rbind,cases); row.names(evidence)<-NULL
at<-match("--output-dir",args)
output_dir<-if(!is.na(at)&&at<length(args)) args[[at+1L]] else
  file.path(repo_root,"dev","spikes","settlement_class_b_atomic","evidence")
dir.create(output_dir,recursive=TRUE,showWarnings=FALSE)
utils::write.csv(evidence,file.path(output_dir,"cases.csv"),row.names=FALSE,na="")
print(evidence); cat("CLASS_B_ATOMIC_SPIKE_COMPLETE\n")
