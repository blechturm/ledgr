# A nonterminal invocation is a fresh attempt. Identity and snapshot trust are
# checked by the caller before this boundary; any terminal completion evidence
# is validated there as well. Only derived attempt output is replaced. The run
# registration, provenance, tags and promotion context remain the identity of
# the same run.
ledgr_run_restart_nonterminal <- function(con,
                                          run_id,
                                          is_restart,
                                          start_ts_utc,
                                          opening_positions,
                                          opening_cost_basis,
                                          opening_lots = NULL) {
  restart <- function() {
    if (isTRUE(is_restart)) {
      for (table in c(
        "run_completion",
        "run_telemetry",
        "run_diagnostics",
        "equity_curve",
        "ledger_events"
      )) {
        DBI::dbExecute(
          con,
          paste("DELETE FROM", table, "WHERE run_id = ?"),
          params = list(run_id)
        )
      }
    }
    next_event_seq <- 1L
    if (length(opening_positions) > 0L) {
      next_event_seq <- ledgr_write_opening_position_events(
        con = con,
        run_id = run_id,
        ts_utc = start_ts_utc,
        positions = opening_positions,
        cost_basis = opening_cost_basis,
        event_seq_start = next_event_seq,
        lots = opening_lots
      )
    }
    as.integer(next_event_seq)
  }
  # Replacement and opening publication are one boundary. A condition in
  # either half leaves the previous attempt untouched; the run exit guard
  # records the failed invocation without producing mixed attempt output.
  next_event_seq <- if (isTRUE(is_restart)) {
    DBI::dbWithTransaction(con, restart())
  } else {
    restart()
  }
  list(start_idx = 1L, next_event_seq = next_event_seq)
}
