# Slice 3 (Cut 19, Section 19.11): marks on a run whose prepared planes hold
# a missing bar or a non-finite close. Pure helpers, no loop state: the loop
# (loop.R) keeps the valuation state, the frozen set and the records. The
# mark rule itself is the pin's (ledgr_availability_valuation_state(), the
# provider's decision view, ledgr_availability_restrict_frozen() and
# ledgr_carrier_provider_view()); nothing here copies it.

# TRUE when any prepared bar is unobserved or any prepared close is not
# finite. Such a run takes its marks from the pin's valuation state; a run
# with complete planes keeps the constant fixed-basket packet, whose marks
# are the current closes.
lean_marks_needed <- function(bars) !all(bars$observed) || !all(is.finite(bars$close))

# The pin's valuation state for the run, built once in E as the pin builds it
# (R/fold-engine.R:1732-1740): the full prepared bars and session axis and
# the history reader's pulse columns (cut review R2).
lean_marks_state <- function(bars, ids, substrate, provider, history_reader) {
  ledgr_availability_valuation_state(bars, ids, substrate$axis, as.integer(provider$valuation_policy$max_sessions),
    ledgr_availability_exhausted_choice(provider$valuation_policy), pulse_columns = history_reader$pulse_columns)
}

# One pulse's marks: the provider's decision view on the run's positions,
# the valuation state advanced to the pulse with the held set, the frozen
# restriction and the carrier's provider view (the pin's P1 order,
# R/fold-engine.R:315-336). Returns the view columns, the valuation, the
# named full positions and the P2 input. A context axis other than the run
# axis cannot occur on a fixed basket (R/availability-provider-prepared.R:472);
# it is a coverage condition, so the attempt reruns on the pin.
lean_marks_pulse <- function(provider, vs, i, ts_posix, pos, ids) {
  full <- stats::setNames(pos, ids)
  view <- provider$decision_view(ts_posix, full)
  axis <- as.character(view$axis)
  valuation <- vs$advance(i, axis, held = as.logical(view$held[axis]))
  view <- ledgr_availability_restrict_frozen(view, valuation)
  columns <- ledgr_carrier_provider_view(view, valuation)
  if (!identical(columns$context_pos, seq_along(ids))) lean_abort_attempt("a context axis other than the run axis")
  list(columns = columns, valuation = valuation, full = full, p2 = ledgr_carrier_p2_input(columns, ids))
}

# A group of diagnostic rows (one per entry of `ids`), with the pin's segment
# default: `reasons` is the reason code unless given (R/fold-carrier.R:823).
lean_marks_group <- function(ids, stage, outcome, reason_code, ..., reasons = reason_code) {
  c(list(instrument_id = ids, stage = stage, outcome = outcome, reason_code = reason_code, reasons = reasons), list(...))
}

# The valuation-horizon stop (R/fold-engine.R:338-361, :512-521): the held
# instruments without a usable mark, their rows and the affected exposure
# the completion row records. NULL when every holding is priced.
lean_marks_valuation_stop <- function(m, ts_posix) {
  ids <- names(m$full)[m$columns$held & !m$columns$priced]
  if (length(ids) == 0L) return(NULL)
  v <- m$valuation
  affected <- ledgr_availability_affected_exposure(ids, m$full, v)
  q <- unname(m$full[ids])
  list(affected = c(affected, list(ts_utc = ts_posix, specified = TRUE)),
       rows = lean_marks_group(ids, "valuation", "stopped", "valuation_horizon_exhausted", quantity = q,
         price = unname(v$reference[ids]), mark_source = unname(v$source[ids]), mark_age = unname(v$age[ids]),
         position_before = q, position_after = q,
         detail_json = vapply(seq_along(ids), function(k) ledgr_availability_detail_json(affected$details[[k]]), "")))
}

# The frozen set's transitions at this pulse (R/fold-engine.R:522-545):
# newly frozen holdings in context order, then holdings that left the frozen
# set in the previous set's order. Returns the new set and the row groups.
lean_marks_frozen <- function(m, before) {
  ids <- names(m$full)
  now <- ids[m$columns$held & m$columns$frozen]
  entered <- setdiff(now, before)
  exited <- setdiff(before, now)
  v <- m$valuation
  groups <- list()
  if (length(entered) > 0L) {
    q <- unname(m$full[entered])
    groups[[1L]] <- lean_marks_group(entered, "valuation", "frozen", "valuation_frozen", quantity = q,
      price = unname(v$mark[entered]), mark_source = unname(v$source[entered]), mark_age = unname(v$age[entered]),
      position_before = q, position_after = q)
  }
  if (length(exited) > 0L) {
    q <- unname(m$full[exited])
    src <- as.character(v$source[exited])
    src[is.na(src)] <- ""
    groups[[length(groups) + 1L]] <- lean_marks_group(exited, "valuation", "exited", "valuation_freeze_exited",
      quantity = q, price = as.numeric(v$mark[exited]), mark_source = src, mark_age = as.integer(v$age[exited]),
      position_before = q, position_after = q)
  }
  list(set = now, groups = groups)
}

# The decision rows' per-cell fields on a marked pulse (the pin's
# append_decision_trace, R/fold-engine.R:927-966): the mark, its source and
# age, and the reason: a restriction's reasons, or sizing_unavailable for an
# instrument a sizing helper skipped.
lean_marks_decision_fields <- function(m, ids, skipped_ids) {
  rs <- m$p2$restriction
  reason <- ifelse(nzchar(rs$reason), rs$reason, "decision_recorded")
  reasons <- ifelse(nzchar(rs$reasons), rs$reasons, reason)
  skipped <- ids %in% skipped_ids
  if (any(skipped)) {
    reason[skipped] <- "sizing_unavailable"
    reasons[skipped] <- ifelse(nzchar(rs$reasons[skipped]), paste(rs$reasons[skipped], "sizing_unavailable", sep = "|"),
                               "sizing_unavailable")
  }
  list(mark = m$columns$mark, source = m$p2$mark_source, age = m$columns$mark_age, reason = reason, reasons = reasons)
}

# A scheduled-skip pulse's rows (R/fold-engine.R:1968-1977, :664-687): the
# skip row, then evidence for each holding marked from a stale or frozen
# close (none on a run with complete planes).
lean_marks_skip_rows <- function(m, ids, pos) {
  groups <- list(lean_marks_group("", "decision", "skipped", "scheduled_skip", detail_json = "{}"))
  if (is.null(m)) return(groups)
  src <- m$p2$mark_source
  ev <- which(pos != 0 & src %in% c("stale_close", "frozen_close"))
  if (length(ev) > 0L) {
    groups[[2L]] <- lean_marks_group(ids[ev], "valuation", "marked", "", reasons = "", quantity = pos[ev],
      price = m$columns$mark[ev], mark_source = src[ev], mark_age = m$columns$mark_age[ev], position_before = pos[ev],
      position_after = pos[ev])
  }
  groups
}

# LR-23 on marks: a decision cell is clean only on a current-close mark of
# age 0 with the plain decision reason and no risk row (the pin's
# ledgr_diagnostic_clean_hold() and _fill()). With no marks (`d` NULL) the
# cell's close is the current close.
lean_marks_clean <- function(d, close, ids, risk_ids) {
  if (is.null(d)) return(is.finite(close))
  x <- d$source == "current_close" & !is.na(d$age) & d$age == 0L & is.finite(d$mark) &
    d$reason == "decision_recorded" & d$reasons == "decision_recorded" & !(ids %in% risk_ids)
  x[is.na(x)] <- FALSE
  x
}

# The decision fields of a cell on complete planes, apart from its mark.
lean_marks_current <- list(source = "current_close", age = 0L, reason = "decision_recorded", reasons = "decision_recorded")

# The slice-3 rows of pulses 1..np by part: 1 opens the pulse, 2 follows the
# decision cells, 3 closes it.
lean_marks_part_counts <- function(pulse, part, np) {
  list(open = tabulate(pulse[part == 1L], np), risk = tabulate(pulse[part == 2L], np),
       stop = tabulate(pulse[part == 3L], np))
}

# Logical sequence numbers of slice-3 rows: rows of one (pulse, part) are
# contiguous and in order, each part starting at its pulse offset.
lean_marks_part_seq <- function(pulse, part, lay) {
  key <- pulse * 4L + part
  start <- ifelse(part == 1L, lay$base[pulse], ifelse(part == 2L, lay$risk0[pulse], lay$stop0[pulse]))
  start + seq_along(pulse) - match(key, key) + 1L
}

# The risk-mark gate (R/fold-engine.R:973-1013): a new or larger long
# position on an instrument whose mark is not permissible stops the run.
# NULL when no target does so.
lean_marks_risk_stop <- function(m, ids, sq, pos, ts_posix) {
  st <- which(sq > pos & sq > 0 & !m$columns$permissible)
  if (length(st) == 0L) return(NULL)
  affected <- ledgr_availability_affected_exposure(ids[st], m$full, ledgr_carrier_p2_valuation(m$columns, ids))
  list(affected = c(affected, list(ts_utc = ts_posix, specified = TRUE)),
       rows = lean_marks_group(ids[st], "risk", "stopped", "risk_mark_unavailable", target = sq[st], quantity = pos[st],
         mark_source = m$p2$mark_source[st], mark_age = m$columns$mark_age[st], target_before_risk = sq[st],
         position_before = pos[st], position_after = pos[st],
         detail_json = canonical_json(list(risk_step = "availability_risk_mark_gate"))))
}

# Stale-mark risk rows after the risk plan (R/fold-engine.R:1026-1056): each
# holding or target at a permissible mark older than the pulse, reduced or
# passed through. NULL when there is none.
lean_marks_stale_rows <- function(m, ids, sq, tq, pos) {
  age <- m$columns$mark_age
  st <- which(m$columns$permissible & !is.na(age) & age > 0L & (pos != 0 | tq != 0))
  if (length(st) == 0L) return(NULL)
  reduced <- ledgr_fold_target_changed(tq[st], sq[st])
  lean_marks_group(ids[st], "risk", ifelse(reduced, "reduced", "passed"),
    ifelse(reduced, "stale_mark_reduction", "stale_mark_pass_through"), target = tq[st], quantity = pos[st],
    price = m$columns$mark[st], mark_source = m$p2$mark_source[st], mark_age = age[st], target_before_risk = sq[st],
    target_after_risk = tq[st], position_before = pos[st], position_after = pos[st])
}
