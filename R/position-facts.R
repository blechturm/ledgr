ledgr_position_fact_state <- function(n, entry_bar = NULL, exit_bar = NULL) {
  n <- as.integer(n)
  entry <- if (is.null(entry_bar)) rep(NA_integer_, n) else as.integer(entry_bar)
  exit <- if (is.null(exit_bar)) rep(NA_integer_, n) else as.integer(exit_bar)
  if (length(entry) != n || length(exit) != n) {
    rlang::abort("Position-fact anchors must align with the run axis.", class = "ledgr_internal_error")
  }
  list(entry_bar = entry, exit_bar = exit)
}

ledgr_position_fact_bar_index <- function(time, bar_axis) {
  epoch <- as.numeric(as.POSIXct(time, tz = "UTC"))
  bars <- as.numeric(as.POSIXct(bar_axis, tz = "UTC"))
  exact <- match(epoch, bars)
  missing <- is.na(exact)
  if (any(missing)) exact[missing] <- findInterval(epoch[missing], bars) + 1L
  exact[exact < 1L | exact > length(bars)] <- NA_integer_
  as.integer(exact)
}

# Classify canonical accounting transitions from the replay's own sequential
# book values.  The helper consumes replay output; it is not a second replay
# engine and it never scans fills separately from non-fill accounting events.
ledgr_position_facts_from_replay <- function(replay, bar_axis) {
  prepared <- replay$prepared
  n_inst <- length(prepared$instrument_ids)
  state <- ledgr_position_fact_state(n_inst)
  n <- length(prepared$event_seq)
  if (n == 0L) return(state)

  pos <- prepared$instrument_index
  after <- replay$position_after
  valid <- !is.na(pos) & is.finite(after)
  before <- rep(NA_real_, n)
  before[valid] <- after[valid] - prepared$position_delta[valid]
  flat_before <- valid & abs(before) <= 1e-12
  flat_after <- valid & abs(after) <= 1e-12
  opened <- flat_before & !flat_after
  closed <- !flat_before & flat_after
  fill <- prepared$operation == .ledgr_lot_fill
  bar <- ledgr_position_fact_bar_index(prepared$ts_utc, bar_axis)

  entry_action <- which(opened | closed)
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

ledgr_position_facts_view <- function(state, book, position, current_bar, bar_axis) {
  n <- length(position)
  entry_price <- rep(NA_real_, n)
  held <- abs(position) > 1e-12
  entry_price[held] <- as.numeric(book$cost_basis_by_inst[held]) / abs(as.numeric(position[held]))
  entry_at <- as.POSIXct(rep(NA_real_, n), origin = "1970-01-01", tz = "UTC")
  known_entry <- held & !is.na(state$entry_bar)
  entry_at[known_entry] <- as.POSIXct(bar_axis[state$entry_bar[known_entry]], tz = "UTC")
  exit_at <- as.POSIXct(rep(NA_real_, n), origin = "1970-01-01", tz = "UTC")
  known_exit <- !is.na(state$exit_bar)
  exit_at[known_exit] <- as.POSIXct(bar_axis[state$exit_bar[known_exit]], tz = "UTC")
  bars_since_entry <- rep(NA_real_, n)
  bars_since_entry[known_entry] <- as.numeric(current_bar - state$entry_bar[known_entry])
  bars_since_exit <- rep(Inf, n)
  bars_since_exit[known_exit] <- as.numeric(current_bar - state$exit_bar[known_exit])
  list(
    entry_price = entry_price,
    entry_at = entry_at,
    exit_at = exit_at,
    bars_since_entry = bars_since_entry,
    bars_since_exit = bars_since_exit
  )
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
