# Slice 3 (Section 19.11): marks on a run whose prepared planes hold a
# missing bar or a non-finite close, schedules and the slice-3 records.
# The loop (loop.R) holds the slice-3 run state as one environment,
# `marks_state` (lean_marks_run_state); the other helpers are pure. The mark
# rule itself is the package's (ledgr_availability_valuation_state(), the
# provider's decision view, ledgr_availability_restrict_frozen() and
# ledgr_carrier_provider_view()); nothing here copies it.

# The slice-3 run state. One environment, so slice 3 adds one binding to the
# loop's frame: R searches that frame's bindings one by one for every name a
# pulse stage looks up, and twelve more cost about 12 us per pulse
# (measured). Fields: the package's valuation state on a marked run (NULL
# otherwise), the schedule's decision flags (NULL: every pulse is decided),
# the frozen set, the stop's affected exposure, and the slice-3 rows, typed
# and preallocated: valuation, risk and stop rows, pulse-ordered and within
# a pulse in logical order (part 1 opens the pulse: valuation, scheduled-skip
# and evidence rows; part 2 follows the decision cells: stale-mark risk rows;
# part 3 closes it: stop rows).
lean_marks_run_state <- function(bars, ids, substrate, provider, history_reader, due, frozen = character(),
                                 marked = FALSE) {
  marks_state <- new.env(parent = emptyenv())
  # A carried opening's frozen holdings start the frozen set, as the
  # package's fold state does, so freeze entry is not recorded twice; such a
  # run takes the marked path, since only the valuation state can exit or
  # keep a frozen holding. So does a run with a corporate-action plan: its
  # refusal stops at the valuation; and one that declares a fact family
  # other than sessions: its decision axis is the provider's per-pulse
  # context.
  marks_state$state <- if (lean_marks_needed(bars) || length(frozen) > 0L || marked) {
    lean_marks_state(bars, ids, substrate, provider, history_reader)
  }
  marks_state$due <- due
  marks_state$frozen <- frozen
  marks_state$affected <- list(value = NA_real_, details = list(), ts_utc = as.POSIXct(NA, tz = "UTC"), specified = FALSE)
  marks_state$xcap <- cap <- 64L
  marks_state$xr <- list(pulse = integer(cap), part = integer(cap), instrument_id = character(cap), stage = character(cap),
    outcome = character(cap), reason_code = character(cap), reasons = character(cap), target = numeric(cap),
    quantity = numeric(cap), price = numeric(cap), mark_source = character(cap), mark_age = integer(cap),
    target_before_risk = numeric(cap), target_after_risk = numeric(cap), position_before = numeric(cap),
    position_after = numeric(cap), detail_json = character(cap), event_seq = rep(NA_integer_, cap))
  marks_state$nx <- 0L
  marks_state
}

# Appends a group of rows of one part, written by index, the buffer doubled
# when full; a field the group does not carry takes the package's diagnostic
# default. The buffer is detached while written, so its columns change in
# place.
lean_marks_add_rows <- function(marks_state, i, part, g) {
  m <- length(g$instrument_id)
  rows <- marks_state$nx + seq_len(m)
  xr <- marks_state$xr
  marks_state$xr <- NULL
  if (marks_state$nx + m > marks_state$xcap) {
    while (marks_state$nx + m > marks_state$xcap) marks_state$xcap <- marks_state$xcap * 2L
    xr <- lapply(xr, function(v) { length(v) <- marks_state$xcap; v })
  }
  xr$pulse[rows] <- i
  xr$part[rows] <- part
  for (f in names(xr)[-(1:2)]) xr[[f]][rows] <- rep_len(g[[f]] %||% .ledgr_diagnostic_defaults[[f]], m)
  marks_state$xr <- xr
  marks_state$nx <- marks_state$nx + m
}

# A slice-3 stop: its rows close the pulse, and the completion row records
# its affected exposure.
lean_marks_stop <- function(marks_state, i, s) {
  lean_marks_add_rows(marks_state, i, 3L, s$rows)
  marks_state$affected <- s$affected
}

# TRUE when any prepared bar is unobserved or any prepared close is not
# finite. Such a run takes its marks from the package's valuation state; a run
# with complete planes keeps the constant fixed-basket packet, whose marks
# are the current closes.
lean_marks_needed <- function(bars) !all(bars$observed) || !all(is.finite(bars$close))

# The package's valuation state for the run, built once in E as the package
# builds it: the full prepared bars and session axis and the history
# reader's pulse columns.
lean_marks_state <- function(bars, ids, substrate, provider, history_reader) {
  ledgr_availability_valuation_state(bars, ids, substrate$axis, as.integer(provider$valuation_policy$max_sessions),
    ledgr_availability_exhausted_choice(provider$valuation_policy), pulse_columns = history_reader$pulse_columns)
}

# One pulse's marks: the provider's decision view on the run's positions,
# the valuation state advanced to the pulse with the held set, the frozen
# restriction and the carrier's provider view (the package's P1 order).
# Returns the view columns, the valuation, the named full positions, the
# restricted view (lifetime and terminal facts), the context ids `cids` (the
# decision axis: members, then held nonmembers, as the prepared provider
# orders them; no run-axis refusal) and the P2 input on that axis.
lean_marks_pulse <- function(provider, vs, i, ts_posix, pos, ids) {
  full <- stats::setNames(pos, ids)
  view <- provider$decision_view(ts_posix, full)
  axis <- as.character(view$axis)
  valuation <- vs$advance(i, axis, held = as.logical(view$held[axis]))
  view <- ledgr_availability_restrict_frozen(view, valuation)
  columns <- ledgr_carrier_provider_view(view, valuation)
  list(columns = columns, valuation = valuation, full = full, view = view, cids = axis,
       p2 = ledgr_carrier_p2_input(columns, axis))
}

# A group of diagnostic rows (one per entry of `ids`), with the package's
# segment default: `reasons` is the reason code unless given.
lean_marks_group <- function(ids, stage, outcome, reason_code, ..., reasons = reason_code) {
  c(list(instrument_id = ids, stage = stage, outcome = outcome, reason_code = reason_code, reasons = reasons), list(...))
}

# A P1 stop (the package's stop_valuation): by default the valuation-horizon
# stop, the held instruments without a usable mark, NULL when every holding
# is priced; or a given stop, such as a corporate-action refusal. Its rows,
# reason and the affected exposure the completion row records.
lean_marks_valuation_stop <- function(m, ts_posix, ids = m$cids[m$columns$held & !m$columns$priced],
                                      reason_code = "valuation_horizon_exhausted", reasons = reason_code) {
  if (length(ids) == 0L) return(NULL)
  v <- m$valuation
  affected <- ledgr_availability_affected_exposure(ids, m$full, v)
  q <- unname(m$full[ids])
  list(reason = reason_code, affected = c(affected, list(ts_utc = ts_posix, specified = TRUE)),
       rows = lean_marks_group(ids, "valuation", "stopped", reason_code, reasons = reasons, quantity = q,
         price = unname(v$reference[ids]), mark_source = unname(v$source[ids]), mark_age = unname(v$age[ids]),
         position_before = q, position_after = q,
         detail_json = vapply(seq_along(ids), function(k) ledgr_availability_detail_json(affected$details[[k]]), "")))
}

# The frozen set's transitions at this pulse: newly frozen holdings in
# context order, then holdings that left the frozen set in the previous
# set's order. Returns the new set and the row groups.
lean_marks_frozen <- function(m, before) {
  ids <- m$cids
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

# The decision rows' per-cell fields on a marked pulse (the package's
# append_decision_trace): the mark, its source and age, and the reason: a
# restriction's reasons, or sizing_unavailable for an instrument a sizing
# helper skipped.
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

# A scheduled-skip pulse's rows: the skip row, then evidence for each
# holding marked from a stale or frozen close (none on a run with complete
# planes).
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
# age 0 with the plain decision reason and no risk row (the package's
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

# The slice-3 rows of pulses 1..np by part (1 opens the pulse, 2 follows the
# decision cells, 3 closes it), and the pulses without decision cells: a
# scheduled skip and a P1 stop (any reason: the valuation horizon, a
# corporate-action refusal), each recognised by its row.
lean_marks_part_counts <- function(marks_state, np) {
  k <- seq_len(marks_state$nx)
  pulse <- marks_state$xr$pulse[k]
  part <- marks_state$xr$part[k]
  none <- marks_state$xr$reason_code[k] == "scheduled_skip" | (marks_state$xr$stage[k] == "valuation" & marks_state$xr$outcome[k] == "stopped")
  list(open = tabulate(pulse[part == 1L], np), risk = tabulate(pulse[part == 2L], np),
       stop = tabulate(pulse[part == 3L], np), no_decision = tabulate(pulse[none], np) > 0L)
}

# Logical sequence numbers of slice-3 rows: rows of one (pulse, part) are
# contiguous and in order, each part starting at its pulse offset.
lean_marks_part_seq <- function(pulse, part, lay) {
  key <- pulse * 4L + part
  start <- ifelse(part == 1L, lay$base[pulse], ifelse(part == 2L, lay$risk0[pulse], lay$stop0[pulse]))
  start + seq_along(pulse) - match(key, key) + 1L
}

# The risk-mark gate: a new or larger long position on an instrument whose
# mark is not permissible stops the run. NULL when no target does so.
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

# Stale-mark risk rows after the risk plan: each holding or target at a
# permissible mark older than the pulse, reduced or passed through. NULL when there is none.
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
