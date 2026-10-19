# Frozen reference: the membership and trading-status segment compilers of
# BASE b9d098c8 (R/history-substrate.R, and the header applier from
# R/availability-provider-prepared.R), copied verbatim with package
# internals qualified and the eight functions renamed history_reference_*.
# Cut 16 decision (22) removed them from the package: membership and status
# segments are counted, not stored. LTB-0291 and LTB-0335 compare the
# package's segment counts and segment-guard refusals with these compilers.
history_reference_segments_build <- function(axis,
                                         instrument_ids,
                                         epochs,
                                         epoch_start,
                                         initial,
                                         resolve,
                                         fact_count,
                                         family,
                                         segment_limit = NULL,
                                         observation_breaks = seq_along(axis)) {
  n_inst <- length(instrument_ids)
  n_axis <- length(axis)
  dictionaries <- list(
    state = ledgr:::ledgr_history_segment_dictionary(),
    winner = ledgr:::ledgr_history_segment_dictionary(),
    reason = ledgr:::ledgr_history_segment_dictionary()
  )
  initial_state <- dictionaries$state$encode(rep(initial$state, n_inst))
  initial_winner <- dictionaries$winner$encode(rep(initial$winner, n_inst))
  initial_reason <- dictionaries$reason$encode(rep(initial$reason, n_inst))
  observation_breaks <- sort(unique(as.integer(observation_breaks)))
  observation_breaks <- observation_breaks[
    !is.na(observation_breaks) & observation_breaks >= 1L &
      observation_breaks <= n_axis
  ]
  if (n_axis > 0L && !1L %in% observation_breaks) {
    observation_breaks <- c(1L, observation_breaks)
  }
  observation_to <- c(observation_breaks[-1L], n_axis + 1L)
  n_breaks <- length(observation_breaks)
  current_state <- matrix(initial_state, nrow = n_inst, ncol = n_breaks)
  current_winner <- matrix(initial_winner, nrow = n_inst, ncol = n_breaks)
  current_reason <- matrix(initial_reason, nrow = n_inst, ncol = n_breaks)
  chunks <- vector("list", length(epochs) + 1L)
  if (n_axis > 0L) {
    chunks[[1L]] <- list(
      instrument = as.integer(seq_len(n_inst)),
      observation_from = rep(1L, n_inst),
      observation_to = rep(as.integer(n_axis + 1L), n_inst),
      knowledge_from = rep(-Inf, n_inst),
      state = initial_state,
      winner = initial_winner,
      reason = initial_reason
    )
  }
  for (epoch_idx in seq_along(epochs)) {
    start <- as.integer(epoch_start[[epoch_idx]])
    start_pos <- match(TRUE, observation_breaks >= start, nomatch = n_breaks + 1L)
    if (is.na(start) || start > n_axis || start_pos > n_breaks) next
    width <- n_breaks - start_pos + 1L
    cell_inst <- vector("list", width)
    cell_obs <- vector("list", width)
    cell_obs_to <- vector("list", width)
    cell_state <- vector("list", width)
    cell_winner <- vector("list", width)
    cell_reason <- vector("list", width)
    for (offset in seq_len(width)) {
      break_pos <- start_pos + offset - 1L
      pulse_idx <- observation_breaks[[break_pos]]
      answer <- resolve(axis[[pulse_idx]], epochs[[epoch_idx]])
      state <- dictionaries$state$encode(answer$state)
      winner <- dictionaries$winner$encode(answer$winner)
      reason <- dictionaries$reason$encode(answer$reason)
      changed <- state != current_state[, break_pos] |
        winner != current_winner[, break_pos] |
        reason != current_reason[, break_pos]
      if (any(changed)) {
        ids <- which(changed)
        cell_inst[[offset]] <- ids
        cell_obs[[offset]] <- rep.int(pulse_idx, length(ids))
        cell_obs_to[[offset]] <- rep.int(observation_to[[break_pos]], length(ids))
        cell_state[[offset]] <- state[ids]
        cell_winner[[offset]] <- winner[ids]
        cell_reason[[offset]] <- reason[ids]
        current_state[ids, break_pos] <- state[ids]
        current_winner[ids, break_pos] <- winner[ids]
        current_reason[ids, break_pos] <- reason[ids]
      }
    }
    chunks[[epoch_idx + 1L]] <- ledgr:::ledgr_history_segment_epoch_cells(
      inst = unlist(cell_inst, use.names = FALSE),
      obs = unlist(cell_obs, use.names = FALSE),
      obs_to = unlist(cell_obs_to, use.names = FALSE),
      knowledge = epochs[[epoch_idx]],
      state = unlist(cell_state, use.names = FALSE),
      winner = unlist(cell_winner, use.names = FALSE),
      reason = unlist(cell_reason, use.names = FALSE)
    )
  }
  out <- ledgr:::ledgr_history_segment_bind(chunks, dictionaries, n_inst)
  out$family <- family
  out$fact_count <- as.integer(fact_count)
  out$segment_count <- as.integer(out$count)
  out$segment_ratio <- out$segment_count / pmax(out$fact_count, 1L)
  limit <- if (is.null(segment_limit)) pmax(4L * out$fact_count, 16L) else rep(as.integer(segment_limit), n_inst)
  exceeded <- which(out$segment_count > limit)
  if (length(exceeded) > 0L) {
    i <- exceeded[[1L]]
    rlang::abort(
      sprintf(
        "History segment limit exceeded for instrument `%s`, family `%s`: %d segments for %d facts (ratio %.3f; limit %d).",
        instrument_ids[[i]], family, out$segment_count[[i]], out$fact_count[[i]],
        out$segment_ratio[[i]], limit[[i]]
      ),
      class = c("ledgr_history_segment_limit_exceeded", "ledgr_invalid_config"),
      instrument_id = instrument_ids[[i]],
      family = family,
      fact_count = out$fact_count[[i]],
      segment_count = out$segment_count[[i]],
      segment_ratio = out$segment_ratio[[i]],
      segment_limit = limit[[i]]
    )
  }
  out$limit <- as.integer(limit)
  out
}
history_reference_membership_diagonal_segments <- function(data,
                                                        universe_id,
                                                        instrument_ids,
                                                        axis,
                                                        headers,
                                                        interval,
                                                        fact_count,
                                                        segment_limit) {
  breaks <- ledgr:::ledgr_history_observation_breaks(
    axis,
    headers$effective_from,
    interval$effective_from,
    interval$effective_to
  )
  ends <- c(breaks[-1L], length(axis) + 1L)
  members_at <- ledgr:::ledgr_availability_prepared_membership(
    data, universe_id, instrument_ids
  )
  resolve <- attr(members_at, "resolve", exact = TRUE)
  dictionaries <- list(
    state = ledgr:::ledgr_history_segment_dictionary(),
    winner = ledgr:::ledgr_history_segment_dictionary(),
    reason = ledgr:::ledgr_history_segment_dictionary()
  )
  initial_state <- dictionaries$state$encode(rep("unknown", length(instrument_ids)))
  initial_winner <- dictionaries$winner$encode(rep("", length(instrument_ids)))
  initial_reason <- dictionaries$reason$encode(
    rep("unknown_no_usable_evidence", length(instrument_ids))
  )
  initial <- list(
    instrument = as.integer(seq_along(instrument_ids)),
    observation_from = rep(1L, length(instrument_ids)),
    observation_to = rep(as.integer(length(axis) + 1L), length(instrument_ids)),
    knowledge_from = rep(-Inf, length(instrument_ids)),
    state = initial_state,
    winner = initial_winner,
    reason = initial_reason
  )
  cells <- lapply(seq_along(breaks), function(j) {
    answer <- resolve(as.numeric(axis[[breaks[[j]]]]))
    state <- history_reference_membership_state(
      ifelse(answer$known, answer$member, NA),
      answer$reason
    )
    reason <- answer$reason
    reason[!answer$known] <- "unknown_no_usable_evidence"
    keep <- is.finite(answer$knowledge) |
      state != "unknown" | answer$winner != "" |
      reason != "unknown_no_usable_evidence"
    if (!any(keep)) return(NULL)
    list(
      instrument = as.integer(which(keep)),
      observation_from = rep.int(breaks[[j]], sum(keep)),
      observation_to = rep.int(ends[[j]], sum(keep)),
      knowledge_from = as.numeric(answer$knowledge[keep]),
      state = dictionaries$state$encode(state[keep]),
      winner = dictionaries$winner$encode(answer$winner[keep]),
      reason = dictionaries$reason$encode(reason[keep])
    )
  })
  out <- ledgr:::ledgr_history_segment_bind(c(list(initial), cells), dictionaries, length(instrument_ids))
  out$family <- "membership"
  out$fact_count <- as.integer(fact_count)
  out$segment_count <- as.integer(out$count)
  out$segment_ratio <- out$segment_count / pmax(out$fact_count, 1L)
  limit <- if (is.null(segment_limit)) {
    pmax(4L * out$fact_count, 16L)
  } else {
    rep(as.integer(segment_limit), length(instrument_ids))
  }
  exceeded <- which(out$segment_count > limit)
  if (length(exceeded) > 0L) {
    i <- exceeded[[1L]]
    rlang::abort(
      sprintf(
        "History segment limit exceeded for instrument `%s`, family `membership`: %d segments for %d facts (ratio %.3f; limit %d).",
        instrument_ids[[i]], out$segment_count[[i]], out$fact_count[[i]],
        out$segment_ratio[[i]], limit[[i]]
      ),
      class = c("ledgr_history_segment_limit_exceeded", "ledgr_invalid_config"),
      instrument_id = instrument_ids[[i]],
      family = "membership",
      fact_count = out$fact_count[[i]],
      segment_count = out$segment_count[[i]],
      segment_ratio = out$segment_ratio[[i]],
      segment_limit = limit[[i]]
    )
  }
  out$limit <- as.integer(limit)
  out
}
history_reference_membership_complete_segments <- function(
    data,
    universe_id,
    instrument_ids,
    axis,
    headers,
    fact_count,
    segment_limit) {
  headers <- headers[order(
    headers$effective_from,
    headers$knowledge_time,
    headers$set_id,
    method = "radix"
  ), , drop = FALSE]
  set_index <- ledgr:::ledgr_membership_index_set_rows(
    data$membership,
    universe_id,
    headers$set_id
  )
  dictionaries <- list(
    state = ledgr:::ledgr_history_segment_dictionary(),
    winner = ledgr:::ledgr_history_segment_dictionary(),
    reason = ledgr:::ledgr_history_segment_dictionary()
  )
  n_inst <- length(instrument_ids)
  initial <- list(
    instrument = as.integer(seq_len(n_inst)),
    observation_from = rep(1L, n_inst),
    observation_to = rep(as.integer(length(axis) + 1L), n_inst),
    knowledge_from = rep(-Inf, n_inst),
    state = dictionaries$state$encode(rep("unknown", n_inst)),
    winner = dictionaries$winner$encode(rep("", n_inst)),
    reason = dictionaries$reason$encode(rep("unknown_no_usable_evidence", n_inst))
  )
  effective <- as.numeric(as.POSIXct(headers$effective_from, tz = "UTC"))
  observation_breaks <- sort(unique(c(
    1L,
    ledgr:::ledgr_history_axis_lower_bound(axis, headers$effective_from)
  )))
  observation_breaks <- observation_breaks[
    observation_breaks <= length(axis)
  ]
  observation_to <- c(observation_breaks[-1L], length(axis) + 1L)
  knowledge <- as.numeric(as.POSIXct(headers$knowledge_time, tz = "UTC"))
  header_rank <- seq_len(nrow(headers))
  header_from <- ledgr:::ledgr_history_axis_lower_bound(axis, headers$effective_from)
  header_break <- match(header_from, observation_breaks)
  epochs <- sort(unique(knowledge[is.finite(knowledge)]))
  selected <- integer(length(observation_breaks))
  chunks <- vector("list", length(epochs))
  for (epoch_idx in seq_along(epochs)) {
    epoch <- epochs[[epoch_idx]]
    before <- selected
    arriving <- which(knowledge == epoch)
    for (h in arriving) {
      from <- header_break[[h]]
      if (is.na(from) || from < 1L || from > length(selected)) next
      cells <- seq.int(from, length(selected))
      replace <- header_rank[[h]] > selected[cells]
      selected[cells[replace]] <- h
    }
    changed <- which(selected != before & selected > 0L)
    if (length(changed) == 0L) next
    run_start <- c(
      TRUE,
      diff(changed) != 1L | selected[changed[-1L]] != selected[changed[-length(changed)]]
    )
    run <- cumsum(run_start)
    first <- changed[!duplicated(run)]
    last <- changed[!duplicated(run, fromLast = TRUE)]
    parts <- vector("list", length(first))
    for (part_idx in seq_along(first)) {
      h <- selected[[first[[part_idx]]]]
      applied <- history_reference_apply_prepared_header(
        known = logical(n_inst),
        state = logical(n_inst),
        reason = rep("", n_inst),
        winner = rep("", n_inst),
        selected_knowledge = rep(-Inf, n_inst),
        header = h,
        headers = headers,
        header_complete = rep(TRUE, nrow(headers)),
        header_knowledge = knowledge,
        set_index = set_index,
        key = instrument_ids
      )
      parts[[part_idx]] <- list(
        instrument = as.integer(seq_len(n_inst)),
        observation_from = rep.int(
          observation_breaks[[first[[part_idx]]]], n_inst
        ),
        observation_to = rep.int(
          observation_to[[last[[part_idx]]]], n_inst
        ),
        knowledge_from = rep(epoch, n_inst),
        state = dictionaries$state$encode(ifelse(
          applied$state, "active", "inactive"
        )),
        winner = dictionaries$winner$encode(applied$winner),
        reason = dictionaries$reason$encode(applied$reason)
      )
    }
    chunks[[epoch_idx]] <- list(
      instrument = unlist(lapply(parts, `[[`, "instrument"), use.names = FALSE),
      observation_from = unlist(lapply(parts, `[[`, "observation_from"), use.names = FALSE),
      observation_to = unlist(lapply(parts, `[[`, "observation_to"), use.names = FALSE),
      knowledge_from = unlist(lapply(parts, `[[`, "knowledge_from"), use.names = FALSE),
      state = unlist(lapply(parts, `[[`, "state"), use.names = FALSE),
      winner = unlist(lapply(parts, `[[`, "winner"), use.names = FALSE),
      reason = unlist(lapply(parts, `[[`, "reason"), use.names = FALSE)
    )
  }
  out <- ledgr:::ledgr_history_segment_bind(
    c(list(initial), chunks),
    dictionaries,
    n_inst
  )
  out$family <- "membership"
  out$fact_count <- as.integer(fact_count)
  out$segment_count <- as.integer(out$count)
  out$segment_ratio <- out$segment_count / pmax(out$fact_count, 1L)
  limit <- if (is.null(segment_limit)) {
    pmax(4L * out$fact_count, 16L)
  } else {
    rep(as.integer(segment_limit), n_inst)
  }
  exceeded <- which(out$segment_count > limit)
  if (length(exceeded) > 0L) {
    i <- exceeded[[1L]]
    rlang::abort(
      sprintf(
        "History segment limit exceeded for instrument `%s`, family `membership`: %d segments for %d facts (ratio %.3f; limit %d).",
        instrument_ids[[i]], out$segment_count[[i]], out$fact_count[[i]],
        out$segment_ratio[[i]], limit[[i]]
      ),
      class = c("ledgr_history_segment_limit_exceeded", "ledgr_invalid_config"),
      instrument_id = instrument_ids[[i]],
      family = "membership",
      fact_count = out$fact_count[[i]],
      segment_count = out$segment_count[[i]],
      segment_ratio = out$segment_ratio[[i]],
      segment_limit = limit[[i]]
    )
  }
  out$limit <- as.integer(limit)
  out
}
history_reference_membership_segments <- function(data,
                                              universe_id,
                                              instrument_ids,
                                              axis,
                                              segment_limit) {
  headers <- data$membership_sets
  headers <- headers[as.character(headers$universe_id) == universe_id, , drop = FALSE]
  rows <- data$membership
  rows <- rows[as.character(rows$universe_id) == universe_id, , drop = FALSE]
  interval <- rows[is.na(rows$set_id), , drop = FALSE]
  epoch_values <- c(
    as.numeric(as.POSIXct(headers$knowledge_time, tz = "UTC")),
    as.numeric(as.POSIXct(interval$knowledge_time, tz = "UTC"))
  )
  epochs <- sort(unique(epoch_values[is.finite(epoch_values)]))
  epoch_start <- vapply(epochs, function(epoch) {
    effective <- c(
      headers$effective_from[as.numeric(as.POSIXct(headers$knowledge_time, tz = "UTC")) == epoch],
      interval$effective_from[as.numeric(as.POSIXct(interval$knowledge_time, tz = "UTC")) == epoch]
    )
    ledgr:::ledgr_history_epoch_start(axis, effective)
  }, integer(1))
  resolver <- function(observation, knowledge) {
    answer <- ledgr:::ledgr_membership_resolve_prepared(
      data,
      universe_id,
      observation,
      instruments = instrument_ids,
      knowledge_cutoff = as.POSIXct(knowledge, origin = "1970-01-01", tz = "UTC")
    )$rows
    state <- history_reference_membership_state(answer$member, answer$reason)
    list(
      state = state,
      winner = as.character(answer$evidence_ids),
      reason = as.character(answer$reason)
    )
  }
  set_rows <- rows[!is.na(rows$set_id), , drop = FALSE]
  fact_count <- rep.int(as.integer(nrow(headers)), length(instrument_ids)) +
    tabulate(
      match(as.character(interval$instrument_id), instrument_ids),
      nbins = length(instrument_ids)
    ) +
    tabulate(
      match(as.character(set_rows$instrument_id), instrument_ids),
      nbins = length(instrument_ids)
    )
  if (nrow(interval) == 0L && nrow(headers) > 0L &&
      all(!is.na(headers$complete) & headers$complete)) {
    return(history_reference_membership_complete_segments(
      data,
      universe_id,
      instrument_ids,
      axis,
      headers,
      fact_count,
      segment_limit
    ))
  }
  if (nrow(headers) == 0L && nrow(interval) > 0L) {
    # Without set headers an instrument's membership depends only on its own
    # interval rows, so compile each instrument over its own epochs and breaks
    # with the canonical resolver applied to that instrument's rows.
    interval_data <- list(membership_sets = headers)
    return(ledgr:::ledgr_history_fact_segments_by_instrument(
      rows = interval,
      instrument_ids = instrument_ids,
      axis = axis,
      initial = list(
        state = "unknown", winner = "", reason = "unknown_no_usable_evidence"
      ),
      family = "membership",
      segment_limit = segment_limit,
      resolve_one = function(indices, observation, cutoff) {
        interval_data$membership <- interval[indices, , drop = FALSE]
        answer <- ledgr:::ledgr_membership_resolve_prepared(
          interval_data,
          universe_id,
          observation,
          instruments = as.character(interval$instrument_id[[indices[[1L]]]]),
          knowledge_cutoff = as.POSIXct(cutoff, origin = "1970-01-01", tz = "UTC")
        )$rows
        list(
          state = history_reference_membership_state(answer$member, answer$reason),
          winner = as.character(answer$evidence_ids),
          reason = as.character(answer$reason)
        )
      }
    ))
  }
  if (history_reference_membership_is_diagonal(headers, interval)) {
    return(history_reference_membership_diagonal_segments(
      data,
      universe_id,
      instrument_ids,
      axis,
      headers,
      interval,
      fact_count,
      segment_limit
    ))
  }
  observation_breaks <- ledgr:::ledgr_history_observation_breaks(
    axis,
    headers$effective_from,
    interval$effective_from,
    interval$effective_to
  )
  history_reference_segments_build(
    axis, instrument_ids, epochs, epoch_start,
    initial = list(state = "unknown", winner = "", reason = "unknown_no_usable_evidence"),
    resolve = resolver,
    fact_count = fact_count,
    family = "membership",
    segment_limit = segment_limit,
    observation_breaks = observation_breaks
  )
}
history_reference_status_segments <- function(data,
                                          instrument_ids,
                                          axis,
                                          declared,
                                          segment_limit) {
  rows <- data$status
  if (!is.data.frame(rows)) rows <- data.frame()
  sparse <- ledgr:::ledgr_history_sparse_fact_segments(
    rows = rows,
    instrument_ids = instrument_ids,
    axis = axis,
    state = as.character(rows$status),
    initial = list(
      state = if (isTRUE(declared)) "unknown" else "active",
      winner = "",
      reason = if (isTRUE(declared)) {
        "status_unknown"
      } else {
        "status_undeclared_active"
      }
    ),
    reason = "status_asserted",
    family = "trading_status",
    segment_limit = segment_limit
  )
  if (!is.null(sparse)) return(sparse)
  knowledge <- if (nrow(rows) > 0L) as.numeric(as.POSIXct(rows$knowledge_time, tz = "UTC")) else numeric()
  status <- as.character(rows$status)
  precedence <- as.integer(rows$precedence)
  fact_id <- as.character(rows$fact_id)
  lineage <- if (nrow(rows) > 0L) ledgr:::ledgr_status_lineage(rows) else list()
  effective <- if (nrow(rows) > 0L) as.numeric(as.POSIXct(rows$effective_from, tz = "UTC")) else numeric()
  end <- if (nrow(rows) > 0L) as.numeric(as.POSIXct(rows$effective_to, tz = "UTC")) else numeric()
  end[is.na(end)] <- Inf
  initial <- list(
    state = if (isTRUE(declared)) "unknown" else "active",
    winner = "",
    reason = if (isTRUE(declared)) "status_unknown" else "status_undeclared_active"
  )
  resolve_one <- function(indices, observation, cutoff) {
    s <- as.numeric(observation)
    applicable <- indices[
      knowledge[indices] <= cutoff & effective[indices] <= s & s < end[indices]
    ]
    if (length(applicable) == 0L) return(initial)
    ledgr:::ledgr_history_status_resolve_applicable(
      applicable, status, precedence, fact_id, lineage
    )
  }
  ledgr:::ledgr_history_fact_segments_by_instrument(
    rows = rows,
    instrument_ids = instrument_ids,
    axis = axis,
    initial = initial,
    family = "trading_status",
    segment_limit = segment_limit,
    resolve_one = resolve_one
  )
}

history_reference_apply_prepared_header <- function(known,
                                                    state,
                                                    reason,
                                                    winner,
                                                    selected_knowledge,
                                                    header,
                                                    headers,
                                                    header_complete,
                                                    header_knowledge,
                                                    set_index,
                                                    key) {
  header_ref <- paste0("set:", headers$set_id[[header]])
  if (isTRUE(header_complete[[header]])) {
    known[] <- TRUE
    state[] <- FALSE
    reason[] <- "omitted_from_complete_set"
    winner[] <- header_ref
    selected_knowledge[] <- header_knowledge[[header]]
  }
  selected_rows <- set_index$by_header[[header]]
  if (length(selected_rows) > 0L) {
    selected_rows <- selected_rows[
      !duplicated(set_index$rows$instrument_id[selected_rows])
    ]
    selected <- match(
      as.character(set_index$rows$instrument_id[selected_rows]),
      key
    )
    keep <- !is.na(selected)
    selected <- selected[keep]
    selected_rows <- selected_rows[keep]
    known[selected] <- TRUE
    state[selected] <- TRUE
    reason[selected] <- "member_asserted"
    winner[selected] <- paste0(
      header_ref,
      "|fact:",
      as.character(set_index$rows$fact_id[selected_rows])
    )
    selected_knowledge[selected] <- header_knowledge[[header]]
  }
  list(
    known = known,
    state = state,
    reason = reason,
    winner = winner,
    knowledge = selected_knowledge
  )
}

history_reference_membership_is_diagonal <- function(headers, interval) {
  same_clock <- function(effective, knowledge) {
    if (length(effective) == 0L) return(TRUE)
    identical(
      as.numeric(as.POSIXct(effective, tz = "UTC")),
      as.numeric(as.POSIXct(knowledge, tz = "UTC"))
    )
  }
  same_clock(headers$effective_from, headers$knowledge_time) &&
    same_clock(interval$effective_from, interval$knowledge_time)
}

history_reference_membership_state <- function(member, reason) {
  member <- as.logical(member)
  reason <- as.character(reason)
  ifelse(
    !is.na(member),
    ifelse(member, "active", "inactive"),
    ifelse(grepl("conflict", reason, fixed = TRUE), "conflicting", "unknown")
  )
}
