# Gut corruptions for gut.R. Each edits raw product output the way a regressed
# handler would have produced it, before the harness canonicalizes anything:
# `store(con)` edits the run store after every path ran, `sweep(sw)` the sweep
# result, `memory(run_id, handler)` the memory sink's buffers, and `patch`
# swaps namespace bindings while `patch_paths` run. `expect` is the record
# table check.R must name.

a0_next_ulp <- function(x) x + 2^(floor(log2(abs(x))) - 52)

# The memory sink's state lives in the handler factory's frame.
a0_sink_state <- function(handler) get("state", envir = environment(handler$events))

a0_guts <- list(
  fill_qty = list(workload = "dense_cost", expect = "ledger_events",
    what = "one FILL quantity in ledger_events increased by 1 share (partial candidate, first fill)",
    store = function(con) {
      DBI::dbExecute(con, paste(
        "UPDATE ledger_events SET qty = qty + 1 WHERE run_id = ? AND event_seq =",
        "(SELECT MIN(event_seq) FROM ledger_events WHERE run_id = ? AND event_type = 'FILL')"
      ), params = list("a0-dense_cost-partial", "a0-dense_cost-partial"))
    }),
  equity_ulp = list(workload = "dense_risk_features", expect = "equity_curve",
    what = "one equity_curve equity value moved by one unit in the last place",
    store = function(con) {
      rid <- "a0-dense_risk_features-tight"
      row <- DBI::dbGetQuery(con, "SELECT ts_utc, equity FROM equity_curve WHERE run_id = ? ORDER BY ts_utc LIMIT 1 OFFSET 4",
        params = list(rid))
      DBI::dbExecute(con, "UPDATE equity_curve SET equity = ? WHERE run_id = ? AND ts_utc = ?",
        params = list(a0_next_ulp(row$equity[[1L]]), rid, row$ts_utc[[1L]]))
    }),
  drop_diagnostic = list(workload = "avail_terminal_resume", expect = "run_diagnostics",
    what = "one run_diagnostics row deleted",
    store = function(con) {
      rid <- "a0-avail_terminal_resume-straight"
      DBI::dbExecute(con, paste(
        "DELETE FROM run_diagnostics WHERE run_id = ? AND diagnostic_seq =",
        "(SELECT MIN(diagnostic_seq) + 5 FROM run_diagnostics WHERE run_id = ?)"
      ), params = list(rid, rid))
    }),
  swap_events = list(workload = "dense_dividend_state", expect = "ledger_events",
    what = "two adjacent ledger events (dividend CASHFLOW, FILL) written in swapped order",
    store = function(con) {
      rid <- "a0-dense_dividend_state-add"
      rows <- DBI::dbGetQuery(con, "SELECT * FROM ledger_events WHERE run_id = ? AND event_seq IN (2, 3) ORDER BY event_seq",
        params = list(rid))
      rows$event_seq <- rev(rows$event_seq)
      DBI::dbExecute(con, "DELETE FROM ledger_events WHERE run_id = ? AND event_seq IN (2, 3)", params = list(rid))
      DBI::dbAppendTable(con, "ledger_events", rows)
    }),
  null_to_text = list(workload = "avail_terminal_resume", expect = "runs",
    what = "runs.error_msg changed from SQL NULL to the literal text 'NA'",
    store = function(con) {
      DBI::dbExecute(con, "UPDATE runs SET error_msg = 'NA' WHERE run_id = ?",
        params = list("a0-avail_terminal_resume-straight"))
    }),
  sweep_return_ulp = list(workload = "dense_cost", expect = "sweep_returns",
    what = "memory path: one retained sweep equity value moved by one unit in the last place",
    sweep = function(sw) {
      returns <- attr(sw, "sweep_returns")
      i <- which(returns$candidate_id == "partial")[[3L]]
      returns$equity[[i]] <- a0_next_ulp(returns$equity[[i]])
      attr(sw, "sweep_returns") <- returns
      sw
    }),
  struct_alias = list(workload = "dense_cost", expect = "sweep_attrs",
    what = "sweep attribute execution_assumptions$opening replaced by sibling fields named opening/<field>",
    sweep = function(sw) {
      ea <- attr(sw, "execution_assumptions")
      opening <- unclass(ea$opening)
      ea$opening <- NULL
      for (n in names(opening)) ea[[paste0("opening/", n)]] <- opening[[n]]
      attr(sw, "execution_assumptions") <- ea
      sw
    }),
  interrupted_telemetry = list(workload = "avail_terminal_resume", expect = "run_telemetry",
    what = "soft-stopped run: the handler persists pulse_count = -999 before the resume overwrites it",
    patch_paths = "run_interrupted",
    patch = list(ledgr_persistent_output_handler = function(original) function(...) {
      handler <- original(...)
      write <- handler$write_telemetry
      handler$write_telemetry <- function(status, strict = TRUE, telemetry = NULL, processed = NA_integer_) {
        write(status, strict = strict, telemetry = telemetry, processed = -999L)
      }
      handler
    })),
  memory_event = list(workload = "dense_cost", expect = "memory_events",
    what = "memory sink: one buffered event's event_id altered (invisible to the summary projections)",
    memory = function(run_id, handler) {
      if (!identical(run_id, "partial")) return(invisible())
      cols <- a0_sink_state(handler)$event_cols
      cols$event_id[[2L]] <- "a0-corrupted-event"
    }),
  memory_diagnostic = list(workload = "avail_terminal_resume", expect = "memory_diagnostics",
    what = "memory sink: the first retained diagnostic's detail_json replaced",
    memory = function(run_id, handler) {
      state <- a0_sink_state(handler)
      if (state$diagnostic_part_n == 0L) return(invisible())
      part <- state$diagnostic_parts[[1L]]
      part$detail_json[[1L]] <- "{\"corrupted\":true}"
      state$diagnostic_parts[[1L]] <- part
    }),
  memory_observer_missing = list(workload = "dense_cost", expect = "<error>",
    error_pattern = "no memory-sink observation point",
    what = "WS1 shape: the memory handler factory is absent and no observation point replaces it",
    memory_factory = "ledgr_memory_output_handler_removed"),
  wf_warning = list(workload = "walk_forward", expect = "run_conditions",
    what = "walk-forward: the persistent handler raises one extra warning per telemetry write",
    patch_paths = "walk_forward",
    patch = list(ledgr_persistent_output_handler = function(original) function(...) {
      handler <- original(...)
      write <- handler$write_telemetry
      handler$write_telemetry <- function(...) {
        warning("a0 gut: injected handler warning", call. = FALSE)
        write(...)
      }
      handler
    })),
  fail_error_msg = list(workload = "failures", expect = "runs",
    what = "failed run: runs.error_msg text altered",
    store = function(con) {
      DBI::dbExecute(con, "UPDATE runs SET error_msg = error_msg || ' (altered)' WHERE run_id = ?",
        params = list("a0-failures-bad"))
    }),
  fail_exception_diagnostic = list(workload = "failures", expect = "run_diagnostics",
    what = "failed run: the exception diagnostic written after rollback is lost",
    store = function(con) {
      DBI::dbExecute(con, "DELETE FROM run_diagnostics WHERE run_id = ? AND outcome = 'error'",
        params = list("a0-failures-bad"))
    }),
  fail_rollback = list(workload = "failures", expect = "ledger_events",
    what = "failed run: a fill from the rolled-back pulses survives in ledger_events",
    store = function(con) {
      row <- DBI::dbGetQuery(con, "SELECT * FROM ledger_events WHERE run_id = ? AND event_type = 'FILL' LIMIT 1",
        params = list("a0-failures-ok"))
      row$run_id <- "a0-failures-bad"
      row$event_id <- "a0-failures-bad_00000001"
      DBI::dbAppendTable(con, "ledger_events", row)
    }),
  fail_sweep_error = list(workload = "failures", expect = "sweep",
    what = "FAILED sweep candidate: error_msg altered",
    sweep = function(sw) {
      i <- which(sw$status == "FAILED")[[1L]]
      sw$error_msg[[i]] <- paste(sw$error_msg[[i]], "(altered)")
      sw
    }),
  abort_status = list(workload = "failures", expect = "runs",
    what = "abort_run refusal: run status left RUNNING instead of FAILED",
    store = function(con) {
      DBI::dbExecute(con, "UPDATE runs SET status = 'RUNNING' WHERE run_id = ?", params = list("a0-failures-abort"))
    })
)
