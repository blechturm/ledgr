# Two-clock history spike core: bitemporal segments built from the unchanged
# production provider and membership resolver.
#
# Charter: inst/design/spikes/two_clock_history_spike/charter.md, section 3.
# For each knowledge epoch e, the provider input tables are filtered to facts
# known by e. Knowledge times are then mapped to effective time plus their
# global knowledge rank in seconds, which keeps every knowledge-ordered rule
# (lifetime rank, membership header order) intact while letting a fact apply
# from its effective time. The production builder and resolver evaluate each
# effective interval once per epoch; a segment is written only when an epoch
# changes it, stamped with the knowledge interval in which it held.

spike_seconds <- function(x) as.numeric(as.POSIXct(x, tz = "UTC"))
spike_col <- function(df, col) if (is.data.frame(df) && col %in% names(df)) df[[col]] else NULL

spike_epochs <- function(data) {
  interval_rows <- data$membership[is.na(spike_col(data$membership, "set_id")), , drop = FALSE]
  sort(unique(spike_seconds(c(
    spike_col(data$status, "knowledge_time"), spike_col(data$lifetime, "knowledge_time"),
    spike_col(data$membership_sets, "knowledge_time"), spike_col(interval_rows, "knowledge_time")
  ))))
}

# Facts known by epoch `e`, with knowledge re-expressed as effective time plus
# the fact's global knowledge rank (seconds), so ordering by knowledge holds.
spike_known_by <- function(data, e, ranks) {
  keep <- function(df) {
    if (!is.data.frame(df) || nrow(df) == 0L) return(df)
    df[spike_seconds(df$knowledge_time) <= e, , drop = FALSE]
  }
  retime <- function(df) {
    if (!is.data.frame(df) || nrow(df) == 0L) return(df)
    rank <- match(spike_seconds(df$knowledge_time), ranks)
    df$knowledge_time <- as.POSIXct(spike_seconds(df$effective_from) + rank, origin = "1970-01-01", tz = "UTC")
    df
  }
  out <- data
  out$status <- retime(keep(data$status))
  out$lifetime <- retime(keep(data$lifetime))
  sets <- keep(data$membership_sets)
  rows <- data$membership
  if (is.data.frame(rows) && nrow(rows) > 0L) {
    in_set <- !is.na(rows$set_id)
    rows <- rows[(in_set & rows$set_id %in% sets$set_id) |
                   (!in_set & spike_seconds(rows$knowledge_time) <= e), , drop = FALSE]
  }
  out$membership_sets <- retime(sets)
  out$membership <- retime(rows)
  out
}

spike_provider <- function(data, ids) {
  config <- list(universe = list(instrument_ids = ids), availability = list(universe_rule = NULL))
  ledgr:::ledgr_availability_provider_build_prepared(data, config, "spike", function(...) NULL)
}

# One state for a plane at a cutoff: status or lifetime of one instrument, or a
# membership universe's member flags over `ids` (TRUE, FALSE or NA).
spike_state <- function(provider, data, plane, key, ids, cutoff) {
  cutoff <- as.POSIXct(cutoff, origin = "1970-01-01", tz = "UTC")
  if (identical(plane, "membership")) {
    rows <- ledgr:::ledgr_membership_resolve_at(data, key, cutoff, instruments = ids)$rows
    rows <- rows[order(as.character(rows$instrument_id)), , drop = FALSE]
    return(paste0(rows$instrument_id, ":", rows$member, collapse = "|"))
  }
  # Spike finding, not a resolution rule: the production builder infers a
  # declared trading-status family from row presence, so a family whose facts
  # are not yet known would default to "active". Before any status fact is
  # known, a declared family answers "unknown", as the shipped provider does.
  if (identical(plane, "status") && "trading_status" %in% data$families$family &&
      (!is.data.frame(data$status) || nrow(data$status) == 0L)) {
    return("unknown")
  }
  facts <- provider$facts(cutoff, ids = ids)
  facts[[plane]][[key]]
}

spike_boundaries <- function(data, plane, key) {
  if (identical(plane, "membership")) {
    sets <- data$membership_sets
    rows <- data$membership
    times <- c(spike_col(sets[sets$universe_id == key, , drop = FALSE], "effective_from"),
               spike_col(rows[rows$universe_id == key & is.na(rows$set_id), , drop = FALSE], "effective_from"),
               spike_col(rows[rows$universe_id == key & is.na(rows$set_id), , drop = FALSE], "effective_to"))
  } else {
    table <- if (identical(plane, "status")) data$status else data$lifetime
    table <- if (is.data.frame(table) && nrow(table) > 0L) table[table$instrument_id == key, , drop = FALSE] else table
    times <- c(spike_col(table, "effective_from"), spike_col(table, "effective_to"))
  }
  b <- sort(unique(spike_seconds(times)))
  b[is.finite(b)]
}

# Build the bitemporal segments for one plane and key over every epoch.
spike_build <- function(data, plane, key, ids) {
  ranks <- spike_epochs(data)
  epochs <- c(-Inf, ranks)
  segments <- data.frame(eff_from = numeric(), eff_to = numeric(), k_from = numeric(),
                         k_to = numeric(), state = character(), stringsAsFactors = FALSE)
  # Each effective interval is evaluated at its start plus 12 hours. This
  # assumes intervals of at least a day and knowledge-rank offsets (seconds)
  # well under 12 hours, which holds for every fixture here.
  probe_offset <- 12 * 3600
  for (e in epochs) {
    known <- spike_known_by(data, e, ranks)
    provider <- spike_provider(known, ids)
    b <- spike_boundaries(known, plane, key)
    starts <- c(-Inf, b)
    ends <- c(b, Inf)
    probe_at <- ifelse(is.finite(starts), starts + probe_offset, ends - 86400)
    probe_at[!is.finite(probe_at)] <- 0
    states <- vapply(probe_at, function(t) as.character(spike_state(provider, known, plane, key, ids, t)), character(1))
    open <- which(is.infinite(segments$k_to))
    matched <- logical(length(open))
    for (j in seq_along(starts)) {
      hit <- open[segments$eff_from[open] == starts[[j]] & segments$eff_to[open] == ends[[j]] &
                    segments$state[open] == states[[j]]]
      if (length(hit)) {
        matched[match(hit[[1L]], open)] <- TRUE
      } else {
        segments[nrow(segments) + 1L, ] <- list(starts[[j]], ends[[j]], e, Inf, states[[j]])
      }
    }
    segments$k_to[open[!matched]] <- e
  }
  segments
}

spike_query <- function(segments, s, t) {
  hit <- segments$eff_from <= s & s < segments$eff_to & segments$k_from <= t & t < segments$k_to
  if (sum(hit) != 1L) return(sprintf("ERROR:%d segments", sum(hit)))
  segments$state[hit]
}
