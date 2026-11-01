ledgr_position_fact_state <- function(n, entry_bar = NULL, exit_bar = NULL) {
  n <- as.integer(n)
  entry <- if (is.null(entry_bar)) rep(NA_integer_, n) else as.integer(entry_bar)
  exit <- if (is.null(exit_bar)) rep(NA_integer_, n) else as.integer(exit_bar)
  if (length(entry) != n || length(exit) != n) {
    rlang::abort("Position-fact anchors must align with the run axis.", class = "ledgr_internal_error")
  }
  list(entry_bar = entry, exit_bar = exit)
}

ledgr_position_fact_axis_map <- function(bar_axis, transition_time = NULL,
                                         transition_index = NULL) {
  epoch <- as.numeric(as.POSIXct(bar_axis, tz = "UTC"))
  if (anyNA(epoch) || anyDuplicated(epoch)) {
    rlang::abort(
      "Position-fact bar axis must contain unique non-missing timestamps.",
      class = c("ledgr_position_fact_off_axis", "ledgr_invalid_fold_execution")
    )
  }
  out <- stats::setNames(as.integer(seq_along(epoch)), format(epoch, scientific = FALSE, trim = TRUE))
  if (length(transition_time) == 0L) return(out)
  transition_epoch <- as.numeric(as.POSIXct(transition_time, tz = "UTC"))
  transition_index <- as.integer(transition_index)
  if (length(transition_epoch) != length(transition_index) ||
      anyNA(transition_epoch) || anyNA(transition_index) ||
      any(transition_index < 1L | transition_index > length(epoch))) {
    rlang::abort(
      "Prepared position-transition labels must map to the run bar axis.",
      class = c("ledgr_position_fact_off_axis", "ledgr_invalid_fold_execution")
    )
  }
  keys <- format(transition_epoch, scientific = FALSE, trim = TRUE)
  first <- match(keys, keys)
  duplicate_conflict <- transition_index != transition_index[first]
  if (any(duplicate_conflict)) {
    rlang::abort(
      "Prepared position-transition labels must map uniquely to the run bar axis.",
      class = c("ledgr_position_fact_off_axis", "ledgr_invalid_fold_execution")
    )
  }
  keep <- !duplicated(keys)
  keys <- keys[keep]
  transition_index <- transition_index[keep]
  prior <- unname(out[keys])
  conflict <- !is.na(prior) & prior != transition_index
  if (any(conflict)) {
    rlang::abort(
      "Prepared position-transition labels must map uniquely to the run bar axis.",
      class = c("ledgr_position_fact_off_axis", "ledgr_invalid_fold_execution")
    )
  }
  c(out, stats::setNames(transition_index[is.na(prior)], keys[is.na(prior)]))
}

ledgr_position_fact_replay_axis_map <- function(prepared, bar_axis) {
  fill <- prepared$operation == .ledgr_lot_fill
  if (!any(fill)) return(ledgr_position_fact_axis_map(bar_axis))
  bars <- as.numeric(as.POSIXct(bar_axis, tz = "UTC"))
  if (length(bars) == 0L) {
    rlang::abort(
      "Replay position transitions require a non-empty run bar axis.",
      class = c("ledgr_position_fact_off_axis", "ledgr_invalid_fold_execution")
    )
  }
  times <- as.numeric(as.POSIXct(prepared$ts_utc[fill], tz = "UTC"))
  index <- match(times, bars)
  missing <- is.na(index)
  index[missing] <- findInterval(times[missing], bars) + 1L
  valid <- times >= bars[[1L]] & index >= 1L & index <= length(bars) &
    times <= bars[pmin(index, length(bars))]
  previous <- index > 1L
  valid[previous] <- valid[previous] & times[previous] > bars[index[previous] - 1L]
  if (any(!valid)) {
    rlang::abort(
      "A replayed fill timestamp cannot be placed on the prepared run bar axis.",
      class = c("ledgr_position_fact_off_axis", "ledgr_invalid_fold_execution")
    )
  }
  ledgr_position_fact_axis_map(bar_axis, prepared$ts_utc[fill], index)
}

ledgr_position_fact_fill_axis <- function(bar_axis, pulses_posix,
                                          execution_opportunities_posix) {
  bars <- as.numeric(as.POSIXct(bar_axis, tz = "UTC"))
  pulses <- as.numeric(as.POSIXct(pulses_posix, tz = "UTC"))
  opportunities <- as.numeric(as.POSIXct(execution_opportunities_posix, tz = "UTC"))
  n <- length(opportunities)
  if (n == 0L) return(list(bar = integer(), opportunity = numeric()))
  if (length(pulses) < n || anyNA(bars) || anyNA(pulses[seq_len(n)]) ||
      anyNA(opportunities)) {
    rlang::abort(
      "Prepared fill opportunities must align with the run pulse axis.",
      class = c("ledgr_position_fact_off_axis", "ledgr_invalid_fold_execution")
    )
  }
  pulse_bar <- match(pulses[seq_len(n)], bars)
  fill_bar <- as.integer(pulse_bar) + 1L
  if (anyNA(pulse_bar) || any(fill_bar > length(bars))) {
    rlang::abort(
      "Prepared fill opportunities must map to a following run bar.",
      class = c("ledgr_position_fact_off_axis", "ledgr_invalid_fold_execution")
    )
  }
  list(bar = fill_bar, opportunity = opportunities)
}

ledgr_position_fact_fill_bar <- function(prepared, pulse_idx, fill_time) {
  pulse_idx <- as.integer(pulse_idx)
  time <- as.numeric(as.POSIXct(fill_time, origin = "1970-01-01", tz = "UTC"))
  valid_pulse <- length(pulse_idx) == 1L && !is.na(pulse_idx) &&
    pulse_idx >= 1L && pulse_idx <= length(prepared$bar)
  valid_time <- length(time) > 0L && !anyNA(time) && all(is.finite(time))
  if (!valid_pulse || !valid_time ||
      any(time != prepared$opportunity[[pulse_idx]])) {
    rlang::abort(
      sprintf(
        "Fill timestamps must equal the opportunity prepared for their pulse (pulse=%s, got=%s, expected=%s).",
        paste(pulse_idx, collapse = ","), paste(time, collapse = ","),
        if (valid_pulse) prepared$opportunity[[pulse_idx]] else "<none>"
      ),
      class = c("ledgr_position_fact_off_axis", "ledgr_invalid_fold_execution")
    )
  }
  prepared$bar[[pulse_idx]]
}

ledgr_position_fact_bar_index <- function(time, bar_axis = NULL, axis_map = NULL) {
  if (is.null(axis_map)) axis_map <- ledgr_position_fact_axis_map(bar_axis)
  epoch <- as.numeric(as.POSIXct(time, tz = "UTC"))
  key <- format(epoch, scientific = FALSE, trim = TRUE)
  exact <- unname(as.integer(axis_map[key]))
  if (anyNA(epoch) || anyNA(exact)) {
    rlang::abort(
      "A position transition timestamp is not on the prepared run bar axis.",
      class = c("ledgr_position_fact_off_axis", "ledgr_invalid_fold_execution")
    )
  }
  exact
}

# Classify canonical accounting transitions from the replay's own sequential
# book values.  The helper consumes replay output; it is not a second replay
# engine and it never scans fills separately from non-fill accounting events.
ledgr_position_facts_from_replay <- function(replay, bar_axis, initial_state = NULL,
                                             axis_map = NULL) {
  prepared <- replay$prepared
  n_inst <- length(prepared$instrument_ids)
  state <- initial_state %||% ledgr_position_fact_state(n_inst)
  if (!is.list(state) ||
      !identical(names(state), c("entry_bar", "exit_bar")) ||
      length(state$entry_bar) != n_inst || length(state$exit_bar) != n_inst) {
    rlang::abort("Initial position facts must align with the replay axis.", class = "ledgr_internal_error")
  }
  state <- list(entry_bar = as.integer(state$entry_bar), exit_bar = as.integer(state$exit_bar))
  n <- length(prepared$event_seq)
  if (n == 0L) return(state)

  pos <- prepared$instrument_index
  after <- replay$position_after
  valid <- !is.na(pos) & is.finite(after)
  before <- rep(NA_real_, n)
  before[valid] <- after[valid] - prepared$position_delta[valid]
  flat_before <- valid & abs(before) <= 1e-12
  flat_after <- valid & abs(after) <= 1e-12
  # Opening-position rows describe the initial book and are not transitions.
  # A carried window therefore keeps its seeded anchors, while an ordinary
  # supplied opening remains unknown when no seed was supplied.
  transition <- prepared$operation != .ledgr_lot_opening
  opened <- transition & flat_before & !flat_after
  closed <- transition & !flat_before & flat_after
  fill <- prepared$operation == .ledgr_lot_fill
  if (is.null(axis_map)) {
    axis_map <- ledgr_position_fact_replay_axis_map(prepared, bar_axis)
  }
  bar <- rep(NA_integer_, n)
  action <- opened | closed
  if (any(action)) {
    bar[action] <- ledgr_position_fact_bar_index(
      prepared$ts_utc[action], axis_map = axis_map
    )
  }

  entry_action <- which(action)
  if (length(entry_action) > 0L) {
    last <- entry_action[!duplicated(pos[entry_action], fromLast = TRUE)]
    set <- fill[last] & opened[last]
    state$entry_bar[pos[last[set]]] <- bar[last[set]]
  }
  exit_action <- which(fill & closed)
  if (length(exit_action) > 0L) {
    last <- exit_action[!duplicated(pos[exit_action], fromLast = TRUE)]
    state$exit_bar[pos[last]] <- bar[last]
  }
  state
}

ledgr_position_facts_apply <- function(state, pos, before, after, bar, fill) {
  pos <- as.integer(pos)
  before <- as.numeric(before)
  after <- as.numeric(after)
  bar <- rep_len(as.integer(bar), length(pos))
  fill <- rep_len(as.logical(fill), length(pos))
  opened <- abs(before) <= 1e-12 & abs(after) > 1e-12
  closed <- abs(before) > 1e-12 & abs(after) <= 1e-12
  action <- opened | closed
  if (any(action)) {
    state$entry_bar[pos[action]] <- NA_integer_
    set <- action & fill & opened
    state$entry_bar[pos[set]] <- bar[set]
  }
  set_exit <- fill & closed
  if (any(set_exit)) state$exit_bar[pos[set_exit]] <- bar[set_exit]
  state
}

ledgr_position_fact_source <- function(state, book, position, current_bar, bar_axis,
                                       context_pos = seq_along(position),
                                       unknown_basis = rep(FALSE, length(position))) {
  list(
    entry_bar = state$entry_bar,
    exit_bar = state$exit_bar,
    cost_basis = book$cost_basis_by_inst,
    position = position,
    current_bar = as.integer(current_bar),
    bar_axis = bar_axis,
    context_pos = as.integer(context_pos),
    unknown_basis = rep_len(as.logical(unknown_basis), length(position))
  )
}

ledgr_position_fact_field <- function(source, name) {
  pos <- source$context_pos
  position <- source$position[pos]
  held <- abs(position) > 1e-12
  entry_bar <- source$entry_bar[pos]
  exit_bar <- source$exit_bar[pos]
  known_entry <- held & !is.na(entry_bar)
  known_exit <- !is.na(exit_bar)

  if (identical(name, "entry_price")) {
    out <- rep(NA_real_, length(pos))
    known_basis <- held & !source$unknown_basis[pos]
    out[known_basis] <- source$cost_basis[pos[known_basis]] / abs(position[known_basis])
    return(out)
  }
  if (identical(name, "entry_at")) {
    out <- as.POSIXct(rep(NA_real_, length(pos)), origin = "1970-01-01", tz = "UTC")
    out[known_entry] <- source$bar_axis[entry_bar[known_entry]]
    return(out)
  }
  if (identical(name, "exit_at")) {
    out <- as.POSIXct(rep(NA_real_, length(pos)), origin = "1970-01-01", tz = "UTC")
    out[known_exit] <- source$bar_axis[exit_bar[known_exit]]
    return(out)
  }
  if (identical(name, "bars_since_entry")) {
    out <- rep(NA_real_, length(pos))
    out[known_entry] <- as.numeric(source$current_bar - entry_bar[known_entry])
    return(out)
  }
  if (identical(name, "bars_since_exit")) {
    out <- rep(Inf, length(pos))
    out[known_exit] <- as.numeric(source$current_bar - exit_bar[known_exit])
    return(out)
  }
  rlang::abort("Unknown position-fact field.", class = "ledgr_internal_error")
}

ledgr_position_facts_from_carried <- function(carried, instrument_ids, bar_axis) {
  state <- ledgr_position_fact_state(length(instrument_ids))
  facts <- carried$position_facts
  if (is.null(facts) || length(facts$instrument_id) == 0L) return(state)
  pos <- match(facts$instrument_id, instrument_ids, nomatch = 0L)
  keep <- pos > 0L
  entry <- nzchar(facts$entry_at) & keep
  exit <- nzchar(facts$exit_at) & keep
  state$entry_bar[pos[entry]] <- ledgr_position_fact_bar_index(facts$entry_at[entry], bar_axis)
  state$exit_bar[pos[exit]] <- ledgr_position_fact_bar_index(facts$exit_at[exit], bar_axis)
  state
}

ledgr_position_facts_carried <- function(state, instrument_ids, bar_axis) {
  entry <- rep("", length(instrument_ids))
  exit <- rep("", length(instrument_ids))
  known <- !is.na(state$entry_bar)
  if (any(known)) {
    entry[known] <- format(
      as.POSIXct(bar_axis[state$entry_bar[known]], tz = "UTC"),
      "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"
    )
  }
  known_exit <- !is.na(state$exit_bar)
  if (any(known_exit)) {
    exit[known_exit] <- format(
      as.POSIXct(bar_axis[state$exit_bar[known_exit]], tz = "UTC"),
      "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"
    )
  }
  keep <- nzchar(entry) | nzchar(exit)
  if (!any(keep)) return(NULL)
  list(instrument_id = instrument_ids[keep], entry_at = entry[keep], exit_at = exit[keep])
}
