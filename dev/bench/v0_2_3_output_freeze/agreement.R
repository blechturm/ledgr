# Today's agreement between the persistent handler (ledgr_run) and the memory
# handler (ledgr_sweep) on shared workloads, computed from the canonical
# tables of one a0_run_all() pass. Descriptive: a FALSE row names a known
# difference; it does not fail check.R (the byte comparison does).

a0_show <- function(x) if (is.na(x)) "<NA>" else x

a0_cmp <- function(left, right, drop = character()) {
  left <- left[, setdiff(names(left), drop), drop = FALSE]
  right <- right[, setdiff(names(right), drop), drop = FALSE]
  if (!identical(names(left), names(right))) {
    return(sprintf("columns differ: [%s] vs [%s]", paste(names(left), collapse = ","), paste(names(right), collapse = ",")))
  }
  if (nrow(left) != nrow(right)) return(sprintf("rows differ: %d vs %d", nrow(left), nrow(right)))
  for (i in seq_len(nrow(left))) {
    bad <- names(left)[!mapply(identical, unlist(left[i, ]), unlist(right[i, ]))]
    if (length(bad)) {
      l <- a0_show(left[i, bad[[1L]]]); r <- a0_show(right[i, bad[[1L]]])
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
  out <- df[!is.na(df[[col]]) & df[[col]] == value, , drop = FALSE]
  rownames(out) <- NULL
  out
}

a0_same <- function(a, b) if (identical(a, b)) "" else sprintf("%s vs %s", a0_show(a), a0_show(b))

a0_agreement <- function(results) {
  rows <- list()
  add <- function(workload, comparison, candidate, detail) {
    rows[[length(rows) + 1L]] <<- data.frame(workload = workload, comparison = comparison,
      candidate = candidate, agrees = if (identical(detail, "")) "TRUE" else "FALSE",
      detail = detail, stringsAsFactors = FALSE)
  }
  metric_cols <- c("total_return", "annualized_return", "volatility", "sharpe_ratio", "max_drawdown",
    "n_trades", "win_rate", "avg_trade", "time_in_market")
  codes <- function(x) sort(as.character(unlist(regmatches(x, gregexpr("LEDGR_[A-Z_]+", x)))))
  for (w in names(results$tables)) {
    t <- results$tables[[w]]
    sw <- t$sweep_w1
    run <- t$run
    if (!is.null(run)) {
      for (cid in sw$sweep$candidate_id) {
        rid <- a0_run_id(w, cid)
        srow <- a0_rows(sw$sweep, "candidate_id", cid)
        eq <- a0_rows(run$equity_curve, "run_id", rid)
        conds <- a0_rows(run$run_conditions, "run_id", rid)
        add(w, "status: sweep row vs runs.status", cid, a0_same(srow$status, a0_rows(run$runs, "run_id", rid)$status))
        add(w, "final_equity: sweep row vs last equity_curve row", cid,
          a0_same(srow$final_equity, if (nrow(eq)) eq$equity[[nrow(eq)]] else NA_character_))
        if (identical(srow$status, "FAILED")) {
          err <- conds$class[conds$kind == "error"]
          add(w, "failure class: sweep error_class vs ledgr_run() condition class", cid,
            a0_same(srow$error_class, if (length(err)) strsplit(err[[1L]], "/", fixed = TRUE)[[1L]][[1L]] else NA_character_))
          add(w, "failure message: sweep error_msg vs runs.error_msg", cid,
            a0_same(srow$error_msg, a0_rows(run$runs, "run_id", rid)$error_msg))
          next
        }
        m <- a0_rows(run$metrics, "run_id", rid)
        mv <- stats::setNames(m$value, m$metric)
        bad <- metric_cols[!mapply(identical, unlist(srow[metric_cols]), unname(mv[metric_cols]))]
        add(w, "metrics: sweep row vs ledgr_compute_metrics()", cid,
          paste(sprintf("%s %s vs %s", bad, vapply(unlist(srow[bad]), a0_show, ""), vapply(unname(mv[bad]), a0_show, "")), collapse = "; "))
        ret <- a0_rows(sw$sweep_returns, "candidate_id", cid)[, c("ts_utc", "equity")]
        add(w, "equity path: ledgr_sweep_returns vs equity_curve", cid, a0_cmp(ret, eq[, c("ts_utc", "equity")]))
        st <- a0_rows(sw$sweep_trades, "candidate_id", cid)
        rt <- a0_rows(run$trades, "run_id", rid)
        common <- setdiff(intersect(names(st), names(rt)), "run_id")
        add(w, sprintf("closed trades: ledgr_sweep_trades vs ledgr_results(trades) [%s]", paste(common, collapse = ",")),
          cid, a0_cmp(st[, common, drop = FALSE], rt[, common, drop = FALSE]))
        comp <- a0_rows(run$run_completion, "run_id", rid)
        add(w, "stop_reason: sweep row vs run_completion", cid,
          a0_same(srow$stop_reason, if (nrow(comp)) comp$stop_reason[[1L]] else NA_character_))
        sweep_warn <- codes(srow$warnings)
        run_warn <- codes(conds$message[conds$kind == "warning"])
        add(w, "warning codes: sweep row vs ledgr_run() warnings", cid,
          if (identical(sweep_warn, run_warn)) "" else
            sprintf("[%s] vs [%s]", paste(sweep_warn, collapse = ","), paste(run_warn, collapse = ",")))
        # The memory sink's own buffers against the persisted tables.
        ev <- a0_rows(sw$memory_events, "run_id", cid)
        led <- a0_rows(run$ledger_events, "run_id", rid)
        add(w, "memory sink events vs persisted ledger_events", cid,
          a0_cmp(ev[, names(led), drop = FALSE], led, drop = c("run_id", "event_id")))
        kept <- a0_rows(sw$memory_diagnostics, "run_id", cid)
        diag <- a0_rows(run$run_diagnostics, "run_id", rid)
        same_seq <- a0_rows(diag[diag$diagnostic_seq %in% kept$diagnostic_seq, , drop = FALSE], "run_id", rid)
        add(w, sprintf("memory sink kept diagnostics (%d of %d rows) vs run_diagnostics with the same diagnostic_seq",
          nrow(kept), nrow(diag)), cid,
          if (nrow(kept)) a0_cmp(kept[, names(diag), drop = FALSE], same_seq, drop = "run_id") else "")
        mc <- a0_rows(sw$memory_completion, "run_id", cid)
        if (nrow(mc) || nrow(comp)) {
          add(w, "memory sink completion vs run_completion", cid,
            if (nrow(mc)) a0_cmp(mc[, names(comp), drop = FALSE], comp, drop = "run_id") else "rows differ: 0 vs 1")
        }
        me <- a0_rows(sw$memory_equity, "run_id", cid)
        add(w, "memory sink equity facts vs equity_curve", cid, a0_cmp(me[, names(eq), drop = FALSE], eq, drop = "run_id"))
      }
    }
    for (p in intersect(c("sweep_w2", "sweep_compiled"), names(t))) {
      for (tab in intersect(names(t[[p]]), names(sw))) add(w, sprintf("%s vs sweep_w1: %s", p, tab), "", a0_cmp(t[[p]][[tab]], sw[[tab]]))
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
  }
  do.call(rbind, rows)
}
