# Slice 4 (Cut 21; interface Section 19.13): stateless helpers for the
# lean loop's corporate actions. The loop keeps one slice-4 environment, s4
# (as slice 3 keeps s3), so the envelope frame grows by one binding.
#
# The package's corporate-action plan (R/corporate-action-settlement.R) is
# called, not copied (decision 3). It posts its event rows through an output
# handler; the lean loop hands it a capture instead (decision 4: no store
# write in the loop). The capture is the in-memory acceptance boundary
# (decision 4(a), cut review R3): each append is checked by the package's
# accounting append validator against the boundary the pin's handler would
# hold (its last accepted event_seq and timestamp, advanced by accepted
# fills too) before the plan installs its settlement state, so a refused
# append raises the pin's condition in P1. Accepted blocks are kept in a
# list grown by doubling and published after the loop in event_seq order
# with the fills (lean_facts_emit_ca), and read by the committed-prefix
# reader as soon as they are accepted (decision 4(b)).

# `handler` is the fold's own output handler, before any harness wrapper: the
# capture starts from its append boundary (opening rows, a sweep's retained
# rows), read from the handler's state (R/output-handler.R:466-477).
lean_facts_run_state <- function(plan, handler, cap = 4L) {
  s4 <- new.env(parent = emptyenv())
  s4$plan <- plan
  st <- get0("state", envir = environment(handler$init_buffers), inherits = FALSE)
  s4$bseq <- if (is.environment(st)) st$last_event_seq
  s4$bts <- if (is.environment(st)) st$last_event_ts_utc
  s4$cap <- cap
  s4$blocks <- vector("list", cap)
  s4$nb <- 0L
  s4$nrows <- 0L
  s4$calls <- 0L      # debug witness: post calls and the returned state this pulse
  s4$posted <- NULL
  s4$capture <- list(append_event_rows = function(rows) lean_facts_accept(s4, rows))
  s4
}

# The capture's append: validate, advance the boundary, keep the block.
lean_facts_accept <- function(s4, rows) {
  if (is.null(rows) || nrow(rows) == 0L) return(invisible(TRUE))
  p <- ledgr_validate_accounting_append(rows, prior_event_seq = s4$bseq, prior_ts_utc = s4$bts)
  s4$bseq <- utils::tail(p$event_seq, 1L)
  s4$bts <- utils::tail(p$ts_utc, 1L)
  if (s4$nb == s4$cap) {
    s4$cap <- 2L * s4$cap
    length(s4$blocks) <- s4$cap
  }
  s4$nb <- s4$nb + 1L
  s4$blocks[[s4$nb]] <- rows
  s4$nrows <- s4$nrows + nrow(rows)
  invisible(TRUE)
}

# Accepted fills advance the boundary as the pin's staged fill block does
# (R/output-handler.R:559-563).
lean_facts_fills_accepted <- function(s4, last_seq, last_ts) {
  s4$bseq <- as.integer(last_seq)
  s4$bts <- .POSIXct(last_ts, tz = "UTC")
}

# P1's corporate-action step (R/fold-engine.R:363-382): the plan's clocks and
# cash posting into the capture, at the pulse's current closes. The caller
# installs the returned state and checks the quantity effects.
lean_facts_post <- function(s4, i, run_id, event_seq, cash, pos, book, ids, close) {
  s4$plan$check_clocks(i)
  posted <- s4$plan$post(index = i, run_id = run_id, event_seq = event_seq, output_handler = s4$capture,
    state_value = list(cash = cash, positions = stats::setNames(pos, ids), lot_state = book),
    marks = stats::setNames(as.numeric(close), ids))
  if (.lean_debug) {
    s4$calls <- s4$calls + 1L
    s4$posted <- posted$state
  }
  posted
}

# Debug only (decision 9, cut review R6): on every P1 of a run with a plan,
# exactly one post call this pulse and its returned state installed before
# valuation. The witness is reset here and set only by the call itself, so
# an omitted call or an omitted installation fails this check.
lean_facts_debug_settled <- function(s4, i, cash, pos, book) {
  fail <- function(what) rlang::abort(sprintf("Lean corporate-action settlement %s at pulse %d.", what, i),
                                      class = "ledgr_internal_error")
  calls <- s4$calls
  posted <- s4$posted
  s4$calls <- 0L
  s4$posted <- NULL
  if (calls != 1L) fail(sprintf("ran %d post calls, not one", calls))
  if (!identical(cash, posted$cash) || !identical(pos, unname(as.numeric(posted$positions))) ||
      !identical(book, posted$lot_state)) fail("was not installed")
  invisible(TRUE)
}

# The accepted rows as one frame, in event_seq order (blocks are accepted in
# increasing event_seq), or NULL.
lean_facts_rows <- function(s4) {
  if (s4$nb == 0L) return(NULL)
  out <- do.call(rbind, s4$blocks[seq_len(s4$nb)])
  rownames(out) <- NULL
  out
}

# Writes accepted rows `cur`.. numbered below `below` to `h`, in appends of at
# most `bound` rows; returns the next row to write.
lean_facts_emit_ca <- function(h, ca, cur, below, bound, tick) {
  if (is.null(ca)) return(cur)
  last <- findInterval(below - 1, ca$event_seq)
  while (cur <= last) {
    e <- min(last, cur + bound - 1L)
    tick()
    h$append_event_rows(ca[cur:e, , drop = FALSE])
    cur <- e + 1L
  }
  cur
}
