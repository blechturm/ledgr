# Prepared availability provider: the single chartered alternative arm of the
# provider-preparation spike (Charter v2). Selected through the seam in
# ledgr_availability_provider_build(); never the default.
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

ledgr_availability_prepared_membership <- function(data, universe_id, key) {
  headers <- data$membership_sets
  headers <- headers[as.character(headers$universe_id) == universe_id, , drop = FALSE]
  rows <- data$membership
  rows <- rows[as.character(rows$universe_id) == universe_id, , drop = FALSE]
  headers <- headers[order(headers$effective_from, headers$knowledge_time, headers$set_id), , drop = FALSE]
  n_headers <- nrow(headers)
  h_from <- pmax(
    ledgr_availability_prepared_seconds(headers$effective_from),
    ledgr_availability_prepared_seconds(headers$knowledge_time)
  )
  h_from[is.na(h_from)] <- Inf
  h_complete <- !is.na(headers$complete) & as.logical(headers$complete)
  set_rows <- rows[!is.na(rows$set_id), , drop = FALSE]
  h_sets <- split(
    match(as.character(set_rows$instrument_id), key),
    factor(as.character(set_rows$set_id), levels = as.character(headers$set_id))
  )
  h_sets <- lapply(h_sets, function(x) x[!is.na(x)])
  elig_order <- order(h_from)
  elig_times <- h_from[elig_order]

  interval <- rows[is.na(rows$set_id), , drop = FALSE]
  interval <- interval[order(interval$effective_from, interval$knowledge_time, interval$fact_id), , drop = FALSE]
  iv_start <- pmax(
    ledgr_availability_prepared_seconds(interval$effective_from),
    ledgr_availability_prepared_seconds(interval$knowledge_time)
  )
  iv_start[is.na(iv_start)] <- Inf
  iv_end <- ledgr_availability_prepared_seconds(interval$effective_to)
  iv_end[is.na(iv_end)] <- Inf
  iv_member <- !is.na(interval$member) & as.logical(interval$member)
  iv_idx <- match(as.character(interval$instrument_id), key)
  n_interval <- nrow(interval)

  n_key <- length(key)
  eligible_count <- 0L
  eligible_cached <- -1L
  last_cutoff <- NA_real_
  base <- logical(n_key)

  prepared_members_at <- function(cutoff) {
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
      complete_idx <- which(eligible & h_complete)
      last_complete <- if (length(complete_idx) > 0L) max(complete_idx) else 0L
      state <- logical(n_key)
      for (h in which(eligible & seq_len(n_headers) >= last_complete)) state[h_sets[[h]]] <- TRUE
      base <<- state
      eligible_cached <<- eligible_count
    }
    state <- base
    if (n_interval > 0L) {
      applicable <- which(iv_start <= cutoff & cutoff < iv_end)
      if (length(applicable) > 0L) {
        keep <- !duplicated(iv_idx[applicable], fromLast = TRUE)
        state[iv_idx[applicable][keep]] <- iv_member[applicable][keep]
      }
    }
    key[state]
  }
  prepared_members_at
}

# Piecewise-constant segments per instrument for one fact family. `resolve`
# receives the row indices applicable at a segment start and returns the code
# vector (one code per output plane) that the production rule assigns there.
ledgr_availability_prepared_segments <- function(rows, key, n_planes, default_codes, resolve) {
  n_key <- length(key)
  inst <- match(as.character(rows$instrument_id), key)
  start <- pmax(
    ledgr_availability_prepared_seconds(rows$effective_from),
    ledgr_availability_prepared_seconds(rows$knowledge_time)
  )
  start[is.na(start)] <- Inf
  end <- ledgr_availability_prepared_seconds(rows$effective_to)
  end[is.na(end)] <- Inf
  by_inst <- split(seq_len(nrow(rows)), factor(inst, levels = seq_len(n_key)))
  bound <- vector("list", n_key)
  codes <- vector("list", n_key)
  for (i in seq_len(n_key)) {
    r <- by_inst[[i]]
    b <- sort(unique(c(start[r], end[r])))
    b <- b[is.finite(b)]
    seg_codes <- matrix(default_codes, nrow = n_planes, ncol = length(b) + 1L)
    for (j in seq_along(b)) {
      t <- b[[j]]
      applicable <- r[start[r] <= t & t < end[r]]
      if (length(applicable) > 0L) seg_codes[, j + 1L] <- resolve(applicable)
    }
    bound[[i]] <- c(-Inf, b)
    codes[[i]] <- seg_codes
  }
  cnt <- lengths(bound)
  off <- cumsum(c(1L, cnt[-n_key]))
  list(
    off = as.integer(off), cnt = as.integer(cnt), bound = unlist(bound, use.names = FALSE),
    codes = do.call(cbind, codes), n_key = n_key
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

ledgr_availability_provider_build_prepared <- function(data, config, snapshot_hash, history) {
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

  members_at <- if (is.null(universe_rule)) {
    function(cutoff) fixed_ids
  } else {
    ledgr_availability_prepared_membership(data, as.character(universe_rule$universe_id), key)
  }

  status_levels <- c("unknown", "conflicting", "active", "halted", "quotation_only")
  status_cursor <- NULL
  if (has_status) {
    rows <- data$status
    status_levels <- unique(c(status_levels, as.character(rows$status)))
    status_code <- match(as.character(rows$status), status_levels)
    precedence <- as.integer(rows$precedence)
    fact_id <- as.character(rows$fact_id)
    supersedes <- as.character(rows$supersedes_fact_id)
    resolve_status <- function(applicable) {
      superseded <- supersedes[applicable]
      superseded <- superseded[!is.na(superseded) & nzchar(superseded)]
      remaining <- applicable[!fact_id[applicable] %in% superseded]
      if (length(remaining) == 0L) return(2L)
      top <- max(precedence[remaining])
      values <- unique(status_code[remaining][precedence[remaining] == top])
      if (length(values) == 1L) values else 2L
    }
    status_cursor <- ledgr_availability_prepared_cursor(
      ledgr_availability_prepared_segments(rows, key, 1L, 1L, resolve_status)
    )
  }

  lifetime_levels <- c("unknown", "known_active", "known_inactive")
  terminal_levels <- ""
  lifetime_cursor <- NULL
  if (has_lifetime) {
    rows <- data$lifetime
    lifetime_levels <- unique(c(lifetime_levels, as.character(rows$assertion)))
    terminal <- as.character(rows$terminal_event)
    terminal[is.na(terminal)] <- ""
    terminal_levels <- unique(c("", terminal))
    lifetime_code <- match(as.character(rows$assertion), lifetime_levels)
    terminal_code <- match(terminal, terminal_levels)
    rank <- order(order(
      ledgr_availability_prepared_seconds(rows$effective_from),
      ledgr_availability_prepared_seconds(rows$knowledge_time),
      seq_len(nrow(rows))
    ))
    resolve_lifetime <- function(applicable) {
      winner <- applicable[[which.max(rank[applicable])]]
      c(lifetime_code[[winner]], terminal_code[[winner]])
    }
    lifetime_cursor <- ledgr_availability_prepared_cursor(
      ledgr_availability_prepared_segments(rows, key, 2L, c(1L, 1L), resolve_lifetime)
    )
  }

  prepared_facts <- function(cutoff, ids = config$universe$instrument_ids) {
    cutoff <- as.POSIXct(cutoff, tz = "UTC")
    seconds <- as.numeric(cutoff)
    idx <- match(as.character(ids), key)
    known <- !is.na(idx)
    status <- rep(if (has_status) "unknown" else "active", length(ids))
    lifetime <- rep("unknown", length(ids))
    terminal_event <- rep("", length(ids))
    if (has_status && any(known)) {
      status_cursor$seek(seconds)
      status[known] <- status_levels[status_cursor$read(1L, idx[known])]
    }
    if (has_lifetime && any(known)) {
      lifetime_cursor$seek(seconds)
      lifetime[known] <- lifetime_levels[lifetime_cursor$read(1L, idx[known])]
      terminal_event[known] <- terminal_levels[lifetime_cursor$read(2L, idx[known])]
    }
    list(
      status = stats::setNames(status, ids),
      lifetime = stats::setNames(lifetime, ids),
      terminal_event = stats::setNames(terminal_event, ids),
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
      terminal_event = resolved$terminal_event
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
    list(
      provider_version = ledgr_availability_provider_version(),
      execution_timing_version = config$availability$execution_timing_version %||% NULL,
      snapshot_hash = snapshot_hash,
      declared_families = families
    )
  }

  structure(
    list(
      facts = prepared_facts,
      decision_view = decision_view,
      execution_view = execution_view,
      history = history,
      identity = identity,
      sessions = data$sessions,
      valuation_policy = config$availability$valuation_policy
    ),
    class = c("ledgr_availability_provider", "list")
  )
}
