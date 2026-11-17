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

# `handler` is the fold's own output handler after init_buffers(), before any
# harness wrapper: the capture starts from its append boundary (opening rows,
# a sweep's retained rows), read from the handler's state
# (R/output-handler.R:466-477), and, for a retaining handler, from its event
# count and maximum (:488-492; close review round 1, F1).
#
# On a marked run (LDG-3246, decision 7) s4 also holds each pulse's context:
# its run positions in one typed vector `cx`, grown by doubling, with an
# offset (row 1) and a length (row 2) per pulse in the integer matrix `cxi`
# (NULL on other runs, whose context is the run axis), and `axis`, the axis
# the strategy state is aligned to (the run axis after the envelope's first
# alignment).
lean_facts_run_state <- function(execution, handler, ids, marked, cap = 4L) {
  s4 <- new.env(parent = emptyenv())
  s4$plan <- execution$corporate_action_plan
  s4$policy <- execution$corporate_action_policy   # the terminal policy (R/fold-engine.R:1837)
  s4$provider <- execution$availability_provider
  s4$run_id <- execution$run_id
  s4$pulses <- execution$pulses_posix
  s4$ids <- s4$axis <- ids
  if (marked) {
    s4$cx <- integer(4L * max(1L, length(ids)))
    s4$ncx <- 0L
    s4$cxi <- matrix(0L, 2L, length(execution$pulses_posix))
  }
  st <- get0("state", envir = environment(handler$init_buffers), inherits = FALSE)
  s4$bseq <- if (is.environment(st)) st$last_event_seq
  s4$bts <- if (is.environment(st)) st$last_event_ts_utc
  s4$retains <- is.function(handler$events) && is.environment(st)
  s4$entry <- if (s4$retains) st$event_count else 0L
  s4$hmax <- if (s4$retains) st$event_max_capacity
  s4$nfc <- 0L        # fills the handler holds (committed in P5)
  s4$cap <- cap
  s4$blocks <- vector("list", cap)
  s4$nb <- 0L
  s4$nrows <- 0L
  s4$calls <- 0L      # debug witness: post calls and the returned state this pulse
  s4$posted <- NULL
  s4$capture <- list(append_event_rows = function(rows) lean_facts_accept(s4, rows))
  s4
}

# The capture's append: validate, advance the boundary, keep the block. The
# block list is detached while written, so the write does not copy it
# (optimization coding style, shape 7; as marks.R's row buffer).
lean_facts_accept <- function(s4, rows) {
  if (is.null(rows) || nrow(rows) == 0L) return(invisible(TRUE))
  p <- ledgr_validate_accounting_append(rows, prior_event_seq = s4$bseq, prior_ts_utc = s4$bts)
  s4$bseq <- utils::tail(p$event_seq, 1L)
  s4$bts <- utils::tail(p$ts_utc, 1L)
  lean_facts_capacity(s4, s4$nfc, nrow(rows))   # then the buffer's room, as the pin's append (:699-705)
  blocks <- s4$blocks
  s4$blocks <- NULL
  if (s4$nb == s4$cap) {
    s4$cap <- 2L * s4$cap
    length(blocks) <- s4$cap
  }
  s4$nb <- s4$nb + 1L
  blocks[[s4$nb]] <- rows
  s4$blocks <- blocks
  s4$nrows <- s4$nrows + nrow(rows)
  invisible(TRUE)
}

# A retaining handler's room (close review round 1, F1): its entry events,
# the accepted corporate-action rows, `incoming` rows and `fills` held fills
# against its maximum, refused by the package's owner with its condition
# (ledgr_event_buffer_next_capacity(), R/fold-event-buffer.R:15). A
# draining handler appends corporate-action rows to the store, outside its
# count (R/output-handler.R:666-669), so its fills keep the loop's own check.
# Returns `fills`.
lean_facts_capacity <- function(s4, fills, incoming = 0L) {
  if (s4$retains && s4$nrows + incoming > 0L) {
    ledgr_event_buffer_next_capacity(0L, s4$entry + s4$nrows + incoming + fills, s4$hmax)
  }
  fills
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

# --- the context axis (LDG-3246, decision 7) ------------------------------------

# Records pulse i's context (its run positions in context order) in the typed
# columns: written by index, the vector doubled when full and detached while
# written (shape 7), so the write does not copy it.
lean_facts_context <- function(s4, i, cp) {
  m <- length(cp)
  cx <- s4$cx
  s4$cx <- NULL
  while (s4$ncx + m > length(cx)) length(cx) <- 2L * length(cx)
  cx[s4$ncx + seq_len(m)] <- cp
  s4$cx <- cx
  ci <- s4$cxi
  s4$cxi <- NULL
  ci[, i] <- c(s4$ncx, m)
  s4$cxi <- ci
  s4$ncx <- s4$ncx + m
}

# Run positions of context ordinals `k` on pulses `p` (vectorised): the
# ordinal itself on a run whose context is the run axis.
lean_facts_rpos <- function(s4, k, p) if (is.null(s4$cxi)) k else s4$cx[s4$cxi[1L, p] + k]

# Positions of run positions `rk` entering the decisions of pulses `hp` (a <=
# hp <= b), for the holds of one expansion range (moved from loop.R, now
# keyed by run position): the book net after the instrument's latest fill on
# an earlier pulse of a..b (the fill's recorded net after; `fl` the typed
# fill records, `fr` the rows of a..b), else its position entering a
# (`carry`); never a sum of deltas.
lean_facts_positions_at <- function(fl, fr, rk, hp, a, b, carry) {
  out <- carry[rk]
  if (length(fr) == 0L || length(rk) == 0L) return(out)
  n <- length(carry)
  stride <- b - a + 2L
  # P[pulse - a + 2, k] = position after the fill on `pulse`
  key_fill <- (fl$pos[fr] - 1L) * stride + fl$pulse[fr] - a + 2L
  val <- numeric(n * stride)
  has <- logical(n * stride)
  val[key_fill] <- fl$net_after[fr]
  has[key_fill] <- TRUE
  idx <- seq_len(n * stride)
  last <- cummax(ifelse(has, idx, (idx - 1L) %/% stride * stride))
  src <- last[(rk - 1L) * stride + hp - a + 1L]
  found <- src %% stride != 0L
  out[found] <- val[src[found]]
  out
}

# The strategy state aligned to a changed context (R/fold-engine.R:546-556),
# from the axis it is on.
lean_facts_align <- function(s4, values, declaration, cids, defaults) {
  out <- ledgr_strategy_state_align(values, declaration, s4$axis, cids, default_scalars = defaults)
  s4$axis <- cids
  out
}

# P1 after the corporate-action posting (R/fold-engine.R:383-521): the
# dispositions, then the one P1 stop path (decision 6) for a corporate-action
# refusal (`refused`), a blocked disposition or the valuation horizon, with
# the pin's rows, reason and affected exposure (lean_marks_valuation_stop).
# `state` is the fold's cash, positions, book and event_seq, and
# `settle(value, next_seq)` installs a settlement and returns the new state.
# Returns the pulse's marks `m` (re-read after a disposition) and the stop or
# NULL. Terminal and scheduled dispositions are LDG-3247's: until then a
# held lifetime-inactive instrument aborts the attempt, which reruns on the
# pin.
lean_facts_dispose <- function(s3, s4, m, i, refused, state, settle) {
  ts <- s4$pulses[[i]]
  if (is.null(refused)) {
    held <- m$cids[m$columns$held]
    if (any(m$view$lifetime[held] %in% "known_inactive")) lean_abort_attempt("terminal dispositions")
  }
  list(m = m, stop = if (is.null(refused)) lean_marks_valuation_stop(m, ts) else
    lean_marks_valuation_stop(m, ts, refused$ids, refused$reason_code, rep_len(refused$reasons, length(refused$ids))))
}

# The accepted rows as one frame, in event_seq order (blocks are accepted in
# increasing event_seq), or NULL.
lean_facts_rows <- function(s4) {
  if (s4$nb == 0L) return(NULL)
  out <- do.call(rbind, s4$blocks[seq_len(s4$nb)])
  rownames(out) <- NULL
  out
}

# Fill rows `fr` (ascending) of the typed fill records `fl` to handler `h` in
# event_seq order: each run of contiguous fill numbers in appends of at most
# `bound` rows, preceded by the accepted corporate-action rows `ca` numbered
# below it, from row `cur` (decision 4). Returns the next corporate-action
# row. Loops over runs and batches, not over events.
lean_facts_emit <- function(h, fl, ids, fr, ca, cur, bound, tick) {
  if (length(fr) == 0L) return(cur)
  ev <- fl$evseq[fr]
  for (r in split(seq_along(fr), cumsum(c(TRUE, diff(ev) != 1L)))) {
    cur <- lean_facts_emit_ca(h, ca, cur, ev[[r[[1L]]]], bound, tick)
    for (s in seq.int(1L, length(r), by = bound)) {
      tick()
      rows <- fr[r[seq.int(s, min(length(r), s + bound - 1L))]]
      block <- h$write_fill_events(fill = fl, i = rows, instrument_id = ids[fl$pos[rows]],
        event_seq = fl$evseq[[rows[[1L]]]], use_transaction = FALSE)
      if (is.function(h$record_accounting_fact)) {
        h$record_accounting_fact(block = block, applied = list(close_qty = fl$close_qty[rows],
          open_qty = fl$open_qty[rows], realized_close = fl$realized_close[rows]))
      }
      h$flush_pulse_events()
      if (h$pending_event_count() > 0L) h$flush_pending()
    }
  }
  cur
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
