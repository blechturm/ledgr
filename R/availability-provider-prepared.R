# Prepared availability provider promoted from the reviewed provider spike.
# It is the production default while the temporary two-arm seam remains for
# the Batch 4 parity gate.
#
# Canonical sparse facts remain the durable input. The build step compiles them
# once, before the fold, into instrument-indexed primitive vectors plus monotone
# change cursors:
#   - membership: headers in the resolver's processing order with eligibility
#     times, per-header member index sets, and interval assertions as flat
#     start/end/member vectors; the eligible-header cursor only advances;
#   - trading status, lifetime, and terminal event: per-instrument piecewise
#     constant segments (flat boundary and code vectors in CSR layout) whose
#     values were resolved with the production rules at compile time; one
#     cursor per instrument advances vectorised, and a cutoff below the previous
#     one re-seeks every cursor, so answers never depend on query order.
# No fact data frame is filtered, sorted, split, or subset per instrument and
# pulse; the returned views keep the current list shape, names, types, and
# order. Everything outside the closures (facts tables, history, identity,
# sessions, valuation policy, provider version) is unchanged.

ledgr_availability_prepared_seconds <- function(x) as.numeric(as.POSIXct(x, tz = "UTC"))

ledgr_membership_apply_prepared_header <- function(known,
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

ledgr_availability_prepared_membership_plan <- function(data, universe_id, key) {
  headers <- data$membership_sets
  headers <- headers[as.character(headers$universe_id) == universe_id, , drop = FALSE]
  rows <- data$membership
  rows <- rows[as.character(rows$universe_id) == universe_id, , drop = FALSE]
  headers <- headers[order(headers$effective_from, headers$knowledge_time, headers$set_id), , drop = FALSE]
  n_headers <- nrow(headers)
  h_effective <- ledgr_availability_prepared_seconds(headers$effective_from)
  h_knowledge <- ledgr_availability_prepared_seconds(headers$knowledge_time)
  h_from <- pmax(h_effective, h_knowledge)
  h_from[is.na(h_from)] <- Inf
  h_complete <- !is.na(headers$complete) & as.logical(headers$complete)
  set_index <- ledgr_membership_index_set_rows(
    rows,
    universe_id,
    headers$set_id
  )
  elig_order <- order(h_from)
  elig_times <- h_from[elig_order]

  interval <- rows[is.na(rows$set_id), , drop = FALSE]
  interval <- interval[order(interval$effective_from, interval$knowledge_time, interval$fact_id), , drop = FALSE]
  iv_effective <- ledgr_availability_prepared_seconds(interval$effective_from)
  iv_knowledge <- ledgr_availability_prepared_seconds(interval$knowledge_time)
  iv_start <- pmax(iv_effective, iv_knowledge)
  iv_start[is.na(iv_start)] <- Inf
  iv_end <- ledgr_availability_prepared_seconds(interval$effective_to)
  iv_end[is.na(iv_end)] <- Inf
  iv_member <- !is.na(interval$member) & as.logical(interval$member)
  iv_idx <- match(as.character(interval$instrument_id), key)
  n_interval <- nrow(interval)

  list(
    key = key,
    headers = headers,
    header_from = h_from,
    header_complete = h_complete,
    header_knowledge = h_knowledge,
    set_index = set_index,
    eligibility_order = elig_order,
    eligibility_times = elig_times,
    interval = interval,
    interval_start = iv_start,
    interval_end = iv_end,
    interval_knowledge = iv_knowledge,
    interval_member = iv_member,
    interval_index = iv_idx,
    n_headers = n_headers,
    n_interval = n_interval
  )
}

ledgr_availability_prepared_membership_from_plan <- function(plan) {
  key <- plan$key
  headers <- plan$headers
  h_complete <- plan$header_complete
  h_knowledge <- plan$header_knowledge
  set_index <- plan$set_index
  elig_order <- plan$eligibility_order
  elig_times <- plan$eligibility_times
  interval <- plan$interval
  iv_start <- plan$interval_start
  iv_end <- plan$interval_end
  iv_knowledge <- plan$interval_knowledge
  iv_member <- plan$interval_member
  iv_idx <- plan$interval_index
  n_headers <- plan$n_headers
  n_interval <- plan$n_interval

  n_key <- length(key)
  eligible_count <- 0L
  eligible_cached <- -1L
  last_cutoff <- NA_real_
  base_known <- logical(n_key)
  base_state <- logical(n_key)
  base_reason <- rep("", n_key)
  base_winner <- rep("", n_key)
  base_knowledge <- rep(-Inf, n_key)

  prepared_resolve_at <- function(cutoff) {
    if (is.na(last_cutoff) || cutoff < last_cutoff) {
      eligible_count <<- findInterval(cutoff, elig_times)
    } else {
      while (eligible_count < n_headers && elig_times[[eligible_count + 1L]] <= cutoff) {
        eligible_count <<- eligible_count + 1L
      }
    }
    last_cutoff <<- cutoff
    if (eligible_count != eligible_cached) {
      eligible <- logical(n_headers)
      eligible[elig_order[seq_len(eligible_count)]] <- TRUE
      known <- logical(n_key)
      state <- logical(n_key)
      reason <- rep("", n_key)
      winner <- rep("", n_key)
      selected_knowledge <- rep(-Inf, n_key)
      complete_idx <- which(eligible & h_complete)
      replay_start <- if (length(complete_idx) > 0L) {
        max(complete_idx)
      } else {
        0L
      }
      replay_headers <- which(eligible & seq_len(n_headers) >= replay_start)
      for (h in replay_headers) {
        applied <- ledgr_membership_apply_prepared_header(
          known,
          state,
          reason,
          winner,
          selected_knowledge,
          h,
          headers,
          h_complete,
          h_knowledge,
          set_index,
          key
        )
        known <- applied$known
        state <- applied$state
        reason <- applied$reason
        winner <- applied$winner
        selected_knowledge <- applied$knowledge
      }
      base_known <<- known
      base_state <<- state
      base_reason <<- reason
      base_winner <<- winner
      base_knowledge <<- selected_knowledge
      eligible_cached <<- eligible_count
    }
    known <- base_known
    state <- base_state
    reason <- base_reason
    winner <- base_winner
    selected_knowledge <- base_knowledge
    if (n_interval > 0L) {
      applicable <- which(iv_start <= cutoff & cutoff < iv_end)
      if (length(applicable) > 0L) {
        keep <- !duplicated(iv_idx[applicable], fromLast = TRUE)
        applicable <- applicable[keep]
        selected <- iv_idx[applicable]
        valid <- !is.na(selected)
        applicable <- applicable[valid]
        selected <- selected[valid]
        known[selected] <- TRUE
        state[selected] <- iv_member[applicable]
        reason[selected] <- ifelse(
          iv_member[applicable], "member_asserted", "nonmember_asserted"
        )
        winner[selected] <- paste0(
          "fact:", as.character(interval$fact_id[applicable])
        )
        selected_knowledge[selected] <- iv_knowledge[applicable]
      }
    }
    list(
      known = known,
      member = state,
      reason = reason,
      winner = winner,
      knowledge = selected_knowledge
    )
  }
  prepared_members_at <- function(cutoff) {
    resolved <- prepared_resolve_at(cutoff)
    key[resolved$known & resolved$member]
  }
  attr(prepared_members_at, "resolve") <- prepared_resolve_at
  prepared_members_at
}

ledgr_availability_prepared_membership <- function(data, universe_id, key) {
  ledgr_availability_prepared_membership_from_plan(
    ledgr_availability_prepared_membership_plan(data, universe_id, key)
  )
}

# Piecewise-constant segments per instrument for one fact family. `resolve`
# receives the row indices applicable at a segment start and returns the code
# vector (one code per output plane) that the production rule assigns there.
ledgr_availability_prepared_segments <- function(rows, key, n_planes, default_codes, resolve) {
  n_key <- length(key)
  inst <- match(as.character(rows$instrument_id), key)
  effective_start <- ledgr_availability_prepared_seconds(rows$effective_from)
  knowledge_start <- ledgr_availability_prepared_seconds(rows$knowledge_time)
  effective_start[is.na(effective_start)] <- Inf
  knowledge_start[is.na(knowledge_start)] <- Inf
  end <- ledgr_availability_prepared_seconds(rows$effective_to)
  end[is.na(end)] <- Inf
  by_inst <- split(seq_len(nrow(rows)), factor(inst, levels = seq_len(n_key)))
  bound <- vector("list", n_key)
  codes <- vector("list", n_key)
  for (i in seq_len(n_key)) {
    r <- by_inst[[i]]
    b <- sort(unique(c(effective_start[r], knowledge_start[r], end[r])))
    b <- b[is.finite(b)]
    seg_codes <- matrix(default_codes, nrow = n_planes, ncol = length(b) + 1L)
    for (j in seq_along(b)) {
      t <- b[[j]]
      applicable <- r[
        effective_start[r] <= t & knowledge_start[r] <= t & t < end[r]
      ]
      if (length(applicable) > 0L) seg_codes[, j + 1L] <- resolve(applicable)
    }
    bound[[i]] <- c(-Inf, b)
    codes[[i]] <- seg_codes
  }
  cnt <- lengths(bound)
  off <- cumsum(c(1L, cnt[-n_key]))
  list(
    off = as.integer(off), cnt = as.integer(cnt), bound = unlist(bound, use.names = FALSE),
    codes = do.call(cbind, codes), n_key = n_key,
    effective_start = effective_start,
    knowledge_start = knowledge_start
  )
}

# A cursor over one segment table: vectorised advance for non-decreasing
# cutoffs, vectorised re-seek otherwise.
ledgr_availability_prepared_cursor <- function(segments) {
  off <- segments$off
  cnt <- segments$cnt
  bound <- segments$bound
  codes <- segments$codes
  limit <- off + cnt
  cur <- off
  last_cutoff <- NA_real_
  prepared_seek <- function(cutoff) {
    if (is.na(last_cutoff) || cutoff < last_cutoff) {
      le <- bound <= cutoff
      cs <- c(0L, cumsum(le))
      cur <<- off + (cs[limit] - cs[off]) - 1L
    } else if (cutoff > last_cutoff) {
      repeat {
        nxt <- cur + 1L
        can <- nxt < limit
        adv <- can
        adv[can] <- bound[nxt[can]] <= cutoff
        if (!any(adv)) break
        cur[adv] <<- nxt[adv]
      }
    }
    last_cutoff <<- cutoff
    invisible(NULL)
  }
  prepared_read <- function(plane, idx) codes[plane, cur[idx]]
  list(seek = prepared_seek, read = prepared_read)
}

ledgr_availability_provider_prepare <- function(data, config) {
  family_order <- c("membership", "sessions", "trading_status", "lifetime")
  families <- family_order[family_order %in% as.character(data$families$family)]
  universe_rule <- config$availability$universe_rule
  if (!is.null(universe_rule)) class(universe_rule) <- c("ledgr_universe_rule", "list")
  status_declared <- "trading_status" %in% families
  lifetime_declared <- "lifetime" %in% families
  fixed_ids <- as.character(config$universe$instrument_ids)
  has_status <- is.data.frame(data$status) && nrow(data$status) > 0L
  has_lifetime <- is.data.frame(data$lifetime) && nrow(data$lifetime) > 0L
  key <- ledgr_availability_stable_ids(c(
    fixed_ids,
    if (is.data.frame(data$membership) && nrow(data$membership) > 0L) as.character(data$membership$instrument_id),
    if (has_status) as.character(data$status$instrument_id),
    if (has_lifetime) as.character(data$lifetime$instrument_id)
  ))

  membership_plan <- if (is.null(universe_rule)) {
    NULL
  } else {
    ledgr_availability_prepared_membership_plan(
      data,
      as.character(universe_rule$universe_id),
      key
    )
  }

  status_levels <- c("unknown", "conflicting", "active", "halted", "quotation_only")
  status_segments <- NULL
  if (has_status) {
    rows <- data$status
    status_levels <- unique(c(status_levels, as.character(rows$status)))
    status_value <- as.character(rows$status)
    precedence <- as.integer(rows$precedence)
    fact_id <- as.character(rows$fact_id)
    supersedes <- as.character(rows$supersedes_fact_id)
    lineage <- ledgr_status_lineage(rows)
    resolve_status <- function(applicable) {
      answer <- ledgr_history_status_resolve_applicable(
        applicable,
        status_value,
        precedence,
        fact_id,
        lineage
      )
      match(answer$state, status_levels)
    }
    status_segments <- ledgr_availability_prepared_segments(
      rows, key, 1L, 1L, resolve_status
    )
  }

  lifetime_levels <- c("unknown", "known_active", "known_inactive")
  terminal_levels <- ""
  lifetime_fact_ids <- character()
  lifetime_segments <- NULL
  if (has_lifetime) {
    rows <- data$lifetime
    lifetime_levels <- unique(c(lifetime_levels, as.character(rows$assertion)))
    terminal <- as.character(rows$terminal_event)
    terminal[is.na(terminal)] <- ""
    terminal_levels <- unique(c("", terminal))
    lifetime_code <- match(as.character(rows$assertion), lifetime_levels)
    terminal_code <- match(terminal, terminal_levels)
    lifetime_fact_ids <- as.character(rows$fact_id %||% rep("", nrow(rows)))
    rank <- order(order(
      ledgr_availability_prepared_seconds(rows$effective_from),
      ledgr_availability_prepared_seconds(rows$knowledge_time),
      seq_len(nrow(rows))
    ))
    resolve_lifetime <- function(applicable) {
      answer <- ledgr_history_lifetime_resolve_applicable(
        applicable,
        as.character(rows$assertion),
        terminal,
        lifetime_fact_ids,
        rank
      )
      winner <- match(answer$winner, lifetime_fact_ids)
      c(
        match(answer$state, lifetime_levels),
        match(answer$terminal_event, terminal_levels),
        winner
      )
    }
    lifetime_segments <- ledgr_availability_prepared_segments(
      rows, key, 3L, c(1L, 1L, 0L), resolve_lifetime
    )
  }

  list(
    families = families,
    universe_rule = universe_rule,
    status_declared = status_declared,
    lifetime_declared = lifetime_declared,
    fixed_ids = fixed_ids,
    key = key,
    has_status = has_status,
    has_lifetime = has_lifetime,
    membership = membership_plan,
    status_segments = status_segments,
    status_levels = status_levels,
    lifetime_segments = lifetime_segments,
    lifetime_levels = lifetime_levels,
    terminal_levels = terminal_levels,
    lifetime_fact_ids = lifetime_fact_ids,
    sessions = data$sessions
  )
}

ledgr_availability_provider_from_plan <- function(plan,
                                                  config,
                                                  snapshot_hash,
                                                  history,
                                                  history_substrate_version = NULL) {
  families <- plan$families
  status_declared <- plan$status_declared
  lifetime_declared <- plan$lifetime_declared
  fixed_ids <- plan$fixed_ids
  key <- plan$key
  has_status <- plan$has_status
  has_lifetime <- plan$has_lifetime
  status_levels <- plan$status_levels
  lifetime_levels <- plan$lifetime_levels
  terminal_levels <- plan$terminal_levels
  lifetime_fact_ids <- plan$lifetime_fact_ids
  members_at <- if (is.null(plan$membership)) {
    function(cutoff) fixed_ids
  } else {
    ledgr_availability_prepared_membership_from_plan(plan$membership)
  }
  status_cursor <- if (has_status) {
    ledgr_availability_prepared_cursor(plan$status_segments)
  } else {
    NULL
  }
  lifetime_cursor <- if (has_lifetime) {
    ledgr_availability_prepared_cursor(plan$lifetime_segments)
  } else {
    NULL
  }

  prepared_facts <- function(cutoff, ids = config$universe$instrument_ids) {
    cutoff <- as.POSIXct(cutoff, tz = "UTC")
    seconds <- as.numeric(cutoff)
    idx <- match(as.character(ids), key)
    known <- !is.na(idx)
    status <- rep(if (has_status) "unknown" else "active", length(ids))
    lifetime <- rep("unknown", length(ids))
    terminal_event <- rep("", length(ids))
    lifetime_fact_id <- rep("", length(ids))
    if (has_status && any(known)) {
      status_cursor$seek(seconds)
      status[known] <- status_levels[status_cursor$read(1L, idx[known])]
    }
    if (has_lifetime && any(known)) {
      lifetime_cursor$seek(seconds)
      lifetime[known] <- lifetime_levels[lifetime_cursor$read(1L, idx[known])]
      terminal_event[known] <- terminal_levels[lifetime_cursor$read(2L, idx[known])]
      winner <- lifetime_cursor$read(3L, idx[known])
      lifetime_fact_id[known] <- ifelse(winner > 0L, lifetime_fact_ids[pmax(winner, 1L)], "")
    }
    list(
      status = stats::setNames(status, ids),
      lifetime = stats::setNames(lifetime, ids),
      terminal_event = stats::setNames(terminal_event, ids),
      lifetime_fact_id = stats::setNames(lifetime_fact_id, ids),
      cutoff = cutoff
    )
  }

  decision_view <- function(cutoff, positions) {
    cutoff <- as.POSIXct(cutoff, tz = "UTC")
    members <- members_at(as.numeric(cutoff))
    held <- names(positions)[as.numeric(positions) != 0]
    held_nonmembers <- ledgr_availability_stable_ids(setdiff(held, members))
    axis <- unique(c(members, held_nonmembers))
    resolved <- prepared_facts(cutoff, axis)
    restrictions <- ledgr_availability_restrictions(
      resolved$status,
      resolved$lifetime,
      status_declared,
      lifetime_declared
    )
    list(
      axis = axis,
      members = members,
      member = stats::setNames(axis %in% members, axis),
      held = stats::setNames(axis %in% held, axis),
      target_restricted = restrictions$restricted,
      target_restriction_reason = restrictions$reason,
      target_restriction_reasons = restrictions$reasons,
      status = resolved$status,
      lifetime = resolved$lifetime,
      terminal_event = resolved$terminal_event,
      lifetime_fact_id = resolved$lifetime_fact_id
    )
  }

  execution_view <- function(cutoff, ids) {
    resolved <- prepared_facts(cutoff, ids)
    members <- members_at(as.numeric(as.POSIXct(cutoff, tz = "UTC")))
    restrictions <- ledgr_availability_restrictions(
      resolved$status,
      resolved$lifetime,
      status_declared,
      lifetime_declared
    )
    c(
      resolved,
      list(member = stats::setNames(ids %in% members, ids)),
      restrictions
    )
  }

  identity <- function() {
    out <- list(
      provider_version = ledgr_availability_provider_version(),
      execution_timing_version = config$availability$execution_timing_version %||% NULL,
      snapshot_hash = snapshot_hash,
      declared_families = families
    )
    if (!is.null(history_substrate_version)) {
      out$history_substrate_version <- as.integer(history_substrate_version)
    }
    out
  }

  structure(
    list(
      facts = prepared_facts,
      decision_view = decision_view,
      execution_view = execution_view,
      history = history,
      identity = identity,
      sessions = plan$sessions,
      valuation_policy = config$availability$valuation_policy
    ),
    class = c("ledgr_availability_provider", "list")
  )
}

ledgr_availability_provider_build_prepared <- function(data,
                                                       config,
                                                       snapshot_hash,
                                                       history) {
  ledgr_availability_provider_from_plan(
    ledgr_availability_provider_prepare(data, config),
    config,
    snapshot_hash,
    history
  )
}
