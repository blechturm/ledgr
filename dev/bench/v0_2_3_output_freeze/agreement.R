# Today's agreement between the persistent handler (ledgr_run) and the memory
# handler (ledgr_sweep) on shared workloads, computed from the canonical
# tables of one a0_run_all() pass. Descriptive: a FALSE row names a known
# difference, it does not fail check.R. Internal memory-handler buffers are
# compared only while today's factory exists.

a0_cmp <- function(left, right, drop = character()) {
  left <- left[, setdiff(names(left), drop), drop = FALSE]
  right <- right[, setdiff(names(right), drop), drop = FALSE]
  if (!identical(names(left), names(right))) {
    return(sprintf("columns differ: [%s] vs [%s]", paste(names(left), collapse = ","), paste(names(right), collapse = ",")))
  }
  if (nrow(left) != nrow(right)) return(sprintf("rows differ: %d vs %d", nrow(left), nrow(right)))
  for (i in seq_len(nrow(left))) {
    bad <- names(left)[unlist(left[i, ]) != unlist(right[i, ])]
    if (length(bad)) {
      l <- left[i, bad[[1L]]]; r <- right[i, bad[[1L]]]
      n <- min(nchar(l), nchar(r))
      at <- which(substring(l, 1:n, 1:n) != substring(r, 1:n, 1:n))
      start <- max(1L, (if (length(at)) at[[1L]] else n) - 20L)
      return(sprintf("row %d: %s (...%s vs ...%s)", i, paste(bad, collapse = "|"),
        substr(l, start, start + 70L), substr(r, start, start + 70L)))
    }
  }
  ""
}

a0_rows <- function(df, col, value) {
  out <- df[df[[col]] == value, , drop = FALSE]
  rownames(out) <- NULL
  out
}

a0_agreement <- function(results) {
  rows <- list()
  add <- function(workload, comparison, candidate, detail) {
    rows[[length(rows) + 1L]] <<- data.frame(workload = workload, comparison = comparison,
      candidate = candidate, agrees = if (identical(detail, "")) "TRUE" else "FALSE",
      detail = detail, stringsAsFactors = FALSE)
  }
  metric_cols <- c("total_return", "annualized_return", "volatility", "sharpe_ratio", "max_drawdown",
    "n_trades", "win_rate", "avg_trade", "time_in_market")
  for (w in names(results$tables)) {
    t <- results$tables[[w]]
    sw <- t$sweep_w1
    if (!is.null(t$run)) {
      run <- t$run
      for (cid in sw$sweep$candidate_id) {
        rid <- a0_run_id(w, cid)
        srow <- a0_rows(sw$sweep, "candidate_id", cid)
        runs <- a0_rows(run$runs, "run_id", rid)
        eq <- a0_rows(run$equity_curve, "run_id", rid)
        add(w, "status: sweep row vs runs.status", cid,
          if (identical(srow$status, runs$status)) "" else sprintf("%s vs %s", srow$status, runs$status))
        last <- if (nrow(eq)) eq$equity[[nrow(eq)]] else "NA"
        add(w, "final_equity: sweep row vs last equity_curve row", cid,
          if (identical(srow$final_equity, last)) "" else sprintf("%s vs %s", srow$final_equity, last))
        m <- a0_rows(run$metrics, "run_id", rid)
        mv <- stats::setNames(sub("^=", "", m$value), m$metric)
        bad <- metric_cols[srow[metric_cols] != mv[metric_cols]]
        add(w, "metrics: sweep row vs ledgr_compute_metrics()", cid,
          if (length(bad)) paste(sprintf("%s %s vs %s", bad, srow[bad], mv[bad]), collapse = "; ") else "")
        ret <- a0_rows(sw$sweep_returns, "candidate_id", cid)[, c("ts_utc", "equity")]
        add(w, "equity path: ledgr_sweep_returns vs equity_curve", cid, a0_cmp(ret, eq[, c("ts_utc", "equity")]))
        st <- a0_rows(sw$sweep_trades, "candidate_id", cid)
        rt <- a0_rows(run$trades, "run_id", rid)
        common <- intersect(names(st), names(rt))
        add(w, sprintf("closed trades: ledgr_sweep_trades vs ledgr_results(trades) [%s]", paste(setdiff(common, "run_id"), collapse = ",")),
          cid, a0_cmp(st[, common, drop = FALSE], rt[, common, drop = FALSE], drop = "run_id"))
        comp <- a0_rows(run$run_completion, "run_id", rid)
        reason <- if (nrow(comp)) comp$stop_reason[[1L]] else "NA"
        add(w, "stop_reason: sweep row vs run_completion", cid,
          if (identical(srow$stop_reason, reason)) "" else sprintf("%s vs %s", srow$stop_reason, reason))
        codes <- function(x) sort(as.character(unlist(regmatches(x, gregexpr("LEDGR_[A-Z_]+", x)))))
        sweep_warn <- codes(srow$warnings)
        run_warn <- codes(a0_rows(run$run_warnings, "run_id", rid)$message)
        add(w, "warning codes: sweep row vs ledgr_run() warnings", cid,
          if (identical(sweep_warn, run_warn)) "" else
            sprintf("[%s] vs [%s]", paste(sweep_warn, collapse = ","), paste(run_warn, collapse = ",")))
      }
    }
    for (p in intersect(c("sweep_w2", "sweep_compiled"), names(t))) {
      for (tab in names(sw)) add(w, sprintf("%s vs sweep_w1: %s", p, tab), "", a0_cmp(t[[p]][[tab]], sw[[tab]]))
    }
    if (!is.null(t$run_resumed)) {
      straight <- a0_run_id(w, sw$sweep$candidate_id[[1L]])
      for (tab in c("ledger_events", "equity_curve", "run_diagnostics", "run_completion", "strategy_state", "fills")) {
        add(w, sprintf("resumed vs straight run: %s", tab), "",
          a0_cmp(t$run_resumed[[tab]], a0_rows(t$run[[tab]], "run_id", straight), drop = c("run_id", "event_id")))
      }
    }
    if (!is.null(t$run_db_live)) {
      for (cid in sw$sweep$candidate_id) {
        live <- a0_run_id(w, cid, "db_live")
        for (tab in c("ledger_events", "equity_curve", "fills", "trades", "metrics")) {
          add(w, sprintf("db_live (ledgr_backtest) vs audit_log (ledgr_run): %s", tab), cid,
            a0_cmp(a0_rows(t$run_db_live[[tab]], "run_id", live), a0_rows(t$run[[tab]], "run_id", a0_run_id(w, cid)),
              drop = c("run_id", "event_id")))
        }
      }
    }
    internal <- results$internal[[w]]
    if (is.null(internal)) {
      add(w, "memory handler internals", "", "skipped: ledgr_memory_output_handler absent on this tree")
    } else if (!is.null(t$run)) {
      # Sweep candidates run under run_id = candidate label.
      for (cid in intersect(sw$sweep$candidate_id, names(internal))) {
        rid <- a0_run_id(w, cid)
        h <- internal[[cid]]
        ev <- a0_canon(h$events, "memory_events", "event_seq")
        add(w, "internal: memory events() vs persisted ledger_events", cid,
          a0_cmp(ev, a0_rows(t$run$ledger_events, "run_id", rid), drop = c("run_id", "event_id")))
        diag <- a0_rows(t$run$run_diagnostics, "run_id", rid)
        kept <- if (is.null(h$diagnostics)) diag[0, ] else a0_canon(h$diagnostics, "memory_diagnostics", "diagnostic_seq")
        same_seq <- diag[diag$diagnostic_seq %in% kept$diagnostic_seq, , drop = FALSE]
        rownames(same_seq) <- NULL
        detail <- a0_cmp(kept[, names(diag), drop = FALSE], same_seq, drop = "run_id")
        add(w, sprintf("internal: memory kept diagnostics (%d of %d rows) vs run_diagnostics rows with the same diagnostic_seq",
          nrow(kept), nrow(diag)), cid, detail)
      }
    }
  }
  do.call(rbind, rows)
}
