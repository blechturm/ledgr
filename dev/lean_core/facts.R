# Slice 4 (interface Section 19.13): stateless helpers for the lean loop's
# corporate actions, its context axis and its dispositions, terminal stops
# and position history. The loop keeps one slice-4 environment,
# `facts_state` (as slice 3 keeps `marks_state`), so the envelope frame
# grows by one binding.
#
# The package's corporate-action plan (R/corporate-action-settlement.R) is
# called, not copied. It posts its event rows through an output handler;
# the lean loop hands it a capture instead (no store write in the loop).
# The capture is the in-memory acceptance boundary: each append is checked
# by the package's accounting append validator against the boundary the
# package's handler would hold (its last accepted event_seq and timestamp,
# advanced by accepted fills too) before the plan installs its settlement
# state, so a refused append raises the package's condition in P1. Accepted
# blocks are kept in a list grown by doubling and published after the loop
# in event_seq order with the fills (lean_facts_emit_ca), and read by the
# committed-prefix reader as soon as they are accepted.

# `handler` is the fold's own output handler after init_buffers(), before any
# harness wrapper, and `max_events` the room the loop passed to it. The
# capture's append boundary and the retaining handler's room come from facts
# the loop owns and the handler's public surface, never from a method's
# closure: a handler with events() retains; its entry events are the rows it
# holds at init, its room their count plus max_events as the fold's capacity
# hook gives it (as the package's output handler counts it), its boundary its
# last entry event. With no entry event the boundary is the event before
# execution$event_seq_start, as the package's run seeds it; its seeded
# timestamp is the run's start,
# which no pulse precedes, so no captured row can fall before it and that
# bound is left open.
#
# On a marked run `facts_state` also holds each pulse's context:
# its run positions in one typed vector `cx`, grown by doubling, with an
# offset (row 1) and a length (row 2) per pulse in the integer matrix `cxi`
# (NULL on other runs, whose context is the run axis), and `axis`, the axis
# the strategy state is aligned to (the run axis after the envelope's first
# alignment). On every run `mv` records the P1 position changes
# (lean_facts_moved), and the constants the dispositions need.
lean_facts_run_state <- function(execution, handler, ids, marked, max_events, cap = 4L) {
  facts_state <- new.env(parent = emptyenv())
  facts_state$plan <- execution$corporate_action_plan
  facts_state$policy <- execution$corporate_action_policy   # the terminal policy
  facts_state$provider <- execution$availability_provider
  # A run that can capture: a plan, or declared lifetime facts (terminal
  # dispositions post with no plan). Its fills keep the capture's append
  # boundary and its retaining handler's population.
  facts_state$captures <- !is.null(facts_state$plan) || "lifetime" %in% facts_state$provider$identity()$declared_families
  facts_state$run_id <- execution$run_id
  facts_state$pulses <- execution$pulses_posix
  facts_state$ids <- facts_state$axis <- ids
  facts_state$ok <- lean_targets_axis_ok(ids)   # the target check's universe predicate on that axis (checks.R)
  facts_state$mv <- list(pulse = integer(cap), pos = integer(cap), net = numeric(cap))   # P1 position changes
  facts_state$nmv <- 0L
  if (marked) {
    facts_state$cx <- integer(4L * max(1L, length(ids)))
    facts_state$ncx <- 0L
    facts_state$cxi <- matrix(0L, 2L, length(execution$pulses_posix))
  }
  facts_state$retains <- is.function(handler$events)
  facts_state$pre <- ev <- if (facts_state$retains) handler$events()
  facts_state$entry <- NROW(ev)
  facts_state$hmax <- facts_state$entry + as.integer(lean_hooks$capacity(max_events))
  seq0 <- as.integer(execution$event_seq_start) - 1L
  facts_state$bseq <- if (facts_state$entry > 0L) as.integer(ev$event_seq[[facts_state$entry]]) else if (isTRUE(seq0 > 0L)) seq0
  facts_state$bts <- if (facts_state$entry > 0L) ev$ts_utc[[facts_state$entry]]
  facts_state$nfc <- 0L        # fills the handler holds (committed in P5)
  facts_state$cap <- cap
  facts_state$blocks <- vector("list", cap)
  facts_state$nb <- 0L
  facts_state$nrows <- 0L
  facts_state$calls <- 0L      # debug witness: post calls and the returned state this pulse
  facts_state$posted <- NULL
  facts_state$capture <- list(append_event_rows = function(rows) lean_facts_accept(facts_state, rows))
  facts_state
}

# The capture's append: validate, advance the boundary, keep the block. The
# block list is detached while written, so the write does not copy it
# (optimization coding style, shape 7; as marks.R's row buffer).
lean_facts_accept <- function(facts_state, rows) {
  if (is.null(rows) || nrow(rows) == 0L) return(invisible(TRUE))
  p <- ledgr_validate_accounting_append(rows, prior_event_seq = facts_state$bseq, prior_ts_utc = facts_state$bts)
  facts_state$bseq <- utils::tail(p$event_seq, 1L)
  facts_state$bts <- utils::tail(p$ts_utc, 1L)
  lean_facts_capacity(facts_state, facts_state$nfc, nrow(rows))   # then the buffer's room, as the package's append
  blocks <- facts_state$blocks
  facts_state$blocks <- NULL
  if (facts_state$nb == facts_state$cap) {
    facts_state$cap <- 2L * facts_state$cap
    length(blocks) <- facts_state$cap
  }
  facts_state$nb <- facts_state$nb + 1L
  blocks[[facts_state$nb]] <- rows
  facts_state$blocks <- blocks
  facts_state$nrows <- facts_state$nrows + nrow(rows)
  invisible(TRUE)
}

# A retaining handler's room: its entry events, the accepted
# corporate-action rows, `incoming` rows and `fills` held fills against its
# maximum, refused by the package's owner with its condition
# (ledgr_event_buffer_next_capacity()). A draining handler appends
# corporate-action rows to the store, outside its count, so its fills keep
# the loop's own check.
# Returns `fills`.
lean_facts_capacity <- function(facts_state, fills, incoming = 0L) {
  if (facts_state$retains && facts_state$nrows + incoming > 0L) {
    ledgr_event_buffer_next_capacity(0L, facts_state$entry + facts_state$nrows + incoming + fills, facts_state$hmax)
  }
  fills
}

# Accepted fills advance the boundary as the package's staged fill block
# does.
lean_facts_fills_accepted <- function(facts_state, last_seq, last_ts) {
  facts_state$bseq <- as.integer(last_seq)
  facts_state$bts <- .POSIXct(last_ts, tz = "UTC")
}

# P1's corporate-action step: the plan's clocks and cash posting into the
# capture, at the pulse's current closes. The caller
# installs the returned state and checks the quantity effects.
lean_facts_post <- function(facts_state, i, run_id, event_seq, cash, pos, book, ids, close) {
  facts_state$plan$check_clocks(i)
  posted <- facts_state$plan$post(index = i, run_id = run_id, event_seq = event_seq, output_handler = facts_state$capture,
    state_value = list(cash = cash, positions = stats::setNames(pos, ids), lot_state = book),
    marks = stats::setNames(as.numeric(close), ids))
  if (.lean_debug) {
    facts_state$calls <- facts_state$calls + 1L
    facts_state$posted <- posted$state
  }
  posted
}

# Debug only: on every P1 of a run with a plan,
# exactly one post call this pulse and its returned state installed before
# valuation. The witness is reset here and set only by the call itself, so
# an omitted call or an omitted installation fails this check.
lean_facts_debug_settled <- function(facts_state, i, cash, pos, book) {
  fail <- function(what) rlang::abort(sprintf("Lean corporate-action settlement %s at pulse %d.", what, i),
                                      class = "ledgr_internal_error")
  calls <- facts_state$calls
  posted <- facts_state$posted
  facts_state$calls <- 0L
  facts_state$posted <- NULL
  if (calls != 1L) fail(sprintf("ran %d post calls, not one", calls))
  if (!identical(cash, posted$cash) || !identical(pos, unname(as.numeric(posted$positions))) ||
      !identical(book, posted$lot_state)) fail("was not installed")
  invisible(TRUE)
}

# --- the context axis -----------------------------------------------------------

# Records pulse i's context (its run positions in context order) in the typed
# columns: written by index, the vector doubled when full and detached while
# written (shape 7), so the write does not copy it.
lean_facts_context <- function(facts_state, i, cp) {
  m <- length(cp)
  cx <- facts_state$cx
  facts_state$cx <- NULL
  while (facts_state$ncx + m > length(cx)) length(cx) <- 2L * length(cx)
  cx[facts_state$ncx + seq_len(m)] <- cp
  facts_state$cx <- cx
  ci <- facts_state$cxi
  facts_state$cxi <- NULL
  ci[, i] <- c(facts_state$ncx, m)
  facts_state$cxi <- ci
  facts_state$ncx <- facts_state$ncx + m
}

# Run positions of context ordinals `k` on pulses `p` (vectorised): the
# ordinal itself on a run whose context is the run axis.
lean_facts_rpos <- function(facts_state, k, p) if (is.null(facts_state$cxi)) k else facts_state$cx[facts_state$cxi[1L, p] + k]

# --- the position history ------------------------------------------------------

# Records the run positions a P1 settlement changed, with their exact
# installed book nets and pulse (the stage is P1: fills are in the fill
# records), typed, written by index, doubled when full and detached while
# written.
lean_facts_moved <- function(facts_state, i, before, after) {
  k <- which(before != after)
  if (length(k) == 0L) return(invisible(NULL))
  mv <- facts_state$mv
  facts_state$mv <- NULL
  while (facts_state$nmv + length(k) > length(mv$pulse)) mv <- lapply(mv, function(v) { length(v) <- 2L * length(v); v })
  r <- facts_state$nmv + seq_along(k)
  mv$pulse[r] <- i
  mv$pos[r] <- k
  mv$net[r] <- after[k]
  facts_state$mv <- mv
  facts_state$nmv <- facts_state$nmv + length(k)
}

# The position changes of pulses a..b in time order: P1 changes of pulse p
# at slot 2 (p - a) + 2, before p's fills at 2 (p - a) + 3 (slot 1 is the
# carry entering a); record order within a slot. `fl` holds the typed fill
# records, `fr` their rows in a..b.
lean_facts_moves <- function(facts_state, fl, fr, a, b) {
  p <- facts_state$mv$pulse[seq_len(facts_state$nmv)]   # pulse-ordered: the rows of a..b by two binary searches
  lo <- findInterval(a - 1L, p)
  t <- lo + seq_len(findInterval(b, p) - lo)
  slot <- c(2L * (facts_state$mv$pulse[t] - a) + 2L, 2L * (fl$pulse[fr] - a) + 3L)
  o <- order(slot, method = "radix")
  list(k = c(facts_state$mv$pos[t], fl$pos[fr])[o], slot = slot[o], v = c(facts_state$mv$net[t], fl$net_after[fr])[o])
}

# Positions of run positions `rk` entering the decisions of pulses `hp` (a <=
# hp <= b), for the holds of one expansion range (moved from loop.R): the
# book net after the latest change `ev` (lean_facts_moves) on rk at a P1 of
# a pulse up to hp or a fill of an earlier pulse, else its position entering
# a (`carry`); never a sum of deltas.
lean_facts_positions_at <- function(ev, rk, hp, a, b, carry) {
  out <- carry[rk]
  if (length(ev$k) == 0L || length(rk) == 0L) return(out)
  n <- length(carry)
  stride <- 2L * (b - a) + 3L
  key <- (ev$k - 1L) * stride + ev$slot
  val <- numeric(n * stride)
  has <- logical(n * stride)
  val[key] <- ev$v
  has[key] <- TRUE
  idx <- seq_len(n * stride)
  last <- cummax(ifelse(has, idx, (idx - 1L) %/% stride * stride))
  src <- last[(rk - 1L) * stride + 2L * (hp - a) + 2L]
  found <- src %% stride != 0L
  out[found] <- val[src[found]]
  out
}

# The strategy state aligned to a changed context, from the axis it is on; the target check's axis predicate follows the context.
lean_facts_align <- function(facts_state, values, declaration, cids, defaults) {
  out <- ledgr_strategy_state_align(values, declaration, facts_state$axis, cids, default_scalars = defaults)
  facts_state$axis <- cids
  facts_state$ok <- lean_targets_axis_ok(cids)
  out
}

# P1 after the corporate-action posting: the dispositions, then the one P1
# stop path for a corporate-action refusal (`refused`), a blocked
# disposition or the valuation horizon, with the package's rows, reason and
# affected exposure (lean_marks_valuation_stop).
# `state` is the fold's cash, positions, book and event_seq, and
# `settle(value, next_seq)` installs a settlement and returns the new state.
# Returns the pulse's marks `m` (re-read after a disposition) and the stop or
# NULL. In the package's order: the plan's scheduled dispositions,
# with the view re-read after any; then the held lifetime-inactive
# instruments resolved by ledgr_terminal_resolve(), all stopped when any is
# blocked (no partial disposition), else posted by ledgr_disposition_post()
# with their valuation/disposed rows and the view re-read. Each posting
# goes through the capture and is installed before the next view, checked
# in debug.
lean_facts_dispose <- function(marks_state, facts_state, m, i, refused, state, settle) {
  ts <- facts_state$pulses[[i]]
  stop <- function(ids, reason, reasons) {
    list(m = m, stop = lean_marks_valuation_stop(m, ts, ids, reason, rep_len(reasons, length(ids))))
  }
  if (!is.null(refused)) return(stop(refused$ids, refused$reason_code, refused$reasons))
  reread <- function() lean_marks_pulse(facts_state$provider, marks_state$state, i, ts, state$positions, facts_state$ids)
  plan <- facts_state$plan
  if (!is.null(plan) && isTRUE(plan$has_disposition())) {
    d <- plan$post_disposition(index = i, run_id = facts_state$run_id, event_seq = state$seq, output_handler = facts_state$capture,
      state_value = ledgr_carrier_settlement_state(state, facts_state$ids), valuation = m$valuation)
    if (.lean_debug) lean_facts_debug_posted(facts_state, d$state)
    state <- settle(d$state, d$next_event_seq)
    if (.lean_debug) lean_facts_debug_settled(facts_state, i, state$cash, state$positions, state$lot_state)
    if (!is.null(d$stopped)) return(stop(d$stopped$ids, d$stopped$reason_code, d$stopped$reasons))
    if (d$dispositions > 0L) m <- reread()
  }
  held <- m$cids[m$columns$held]
  inactive <- held[as.character(m$view$lifetime[held]) %in% "known_inactive"]
  if (length(inactive) > 0L) {
    labels <- as.character(m$view$terminal_event[inactive])
    r <- ledgr_terminal_resolve(facts_state$policy, inactive, labels, m$valuation)
    r$outcome[!nzchar(labels)] <- "unlabeled"
    blocked <- r$outcome != "dispose"
    if (any(blocked)) {
      # The package's terminal stop.
      reasons <- ifelse(r$outcome == "unlabeled", "terminal_settlement_unsupported|terminal_label_missing",
        ifelse(r$outcome == "refuse", ifelse(r$basis == "frozen_fallback",
          "terminal_settlement_unsupported|frozen_terminal_refuse", "terminal_settlement_unsupported"),
          paste("terminal_mark_unavailable", r$choice, sep = "|")))
      return(stop(inactive[blocked], if (any(r$outcome %in% c("unlabeled", "refuse"))) "terminal_settlement_unsupported" else
        "terminal_mark_unavailable", reasons[blocked]))
    }
    mm <- ledgr_terminal_mark_meta(r, m$valuation, ts)
    p <- ledgr_disposition_post(ids = inactive, price = r$price, source = rep("lifetime_terminal_disposition", length(inactive)),
      source_fact_id = as.character(m$view$lifetime_fact_id[inactive]), terminal_event = labels,
      matched_label = r$matched_label, disposition_policy_id = r$policy_id, disposition_choice = r$choice,
      disposition_basis = r$basis, mark_source = mm$source, mark_source_ts_utc = mm$source_ts, mark_age = mm$age,
      haircut_fraction = ifelse(r$choice == "haircut", r$haircut, NA_real_), ts = ts, run_id = facts_state$run_id,
      event_seq = state$seq, output_handler = facts_state$capture, state_value = ledgr_carrier_settlement_state(state, facts_state$ids),
      instrument_ids = facts_state$ids, exposure_mark = r$reference)
    if (.lean_debug) lean_facts_debug_posted(facts_state, p$state)
    state <- settle(p$state, p$next_event_seq)
    if (.lean_debug) lean_facts_debug_settled(facts_state, i, state$cash, state$positions, state$lot_state)
    lean_marks_add_rows(marks_state, i, 1L, lean_marks_group(inactive, "valuation", "disposed", "terminal_disposition",
      reasons = paste("terminal_disposition", r$choice, r$basis, sep = "|"), quantity = abs(p$before), price = r$price,
      mark_source = mm$source, mark_age = mm$age, event_seq = p$event_seq, position_before = p$before, position_after = 0))
    m <- reread()
  }
  list(m = m, stop = lean_marks_valuation_stop(m, ts))
}

# Debug only: the witness of one disposition posting and its returned state,
# checked after installation by lean_facts_debug_settled().
lean_facts_debug_posted <- function(facts_state, value) {
  facts_state$calls <- facts_state$calls + 1L
  facts_state$posted <- value
}

# The accepted rows as one frame, in event_seq order (blocks are accepted in
# increasing event_seq), or NULL.
lean_facts_rows <- function(facts_state) {
  if (facts_state$nb == 0L) return(NULL)
  out <- do.call(rbind, facts_state$blocks[seq_len(facts_state$nb)])
  rownames(out) <- NULL
  out
}

# Fill rows `fr` (ascending) of the typed fill records `fl` to handler `h` in
# event_seq order: each run of contiguous fill numbers in appends of at most
# `bound` rows, preceded by the accepted corporate-action rows `ca` numbered
# below it, from row `cur`. Returns the next corporate-action
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
