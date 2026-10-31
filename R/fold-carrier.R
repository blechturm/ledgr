# Typed fold carrier: the P1 observation and P2 decision groups
# (rfc/rfc_typed_fold_carrier_v0_2_3_synthesis.md Sections 3.1-3.2 and the
# carrier contract table of Section 4; ledgr_v0_2_3_spec_packet/
# ws4a_carrier_design.md Sections 2 and 3.2, LDG-3165).
#
# Four groups, each a plain list of typed columns validated once at
# construction:
# - decision packet (P1 -> P5): the provider and valuation planes of one
#   produced view, on the context axis in the provider's decision order;
#   `context_pos[k]` is the run-axis position of context ordinal k.
# - decision data (P1 -> P2 only): the current bar on the context axis, its
#   source locator (row and prepared pulse column) and the cutoff-bound
#   history view.
# - execution packet (P1 -> P3 only): the next-bar OHLCV on the run axis,
#   with an explicit `has_next`; P2 never receives it.
# - decision (P2 -> P5): strategy and post-risk target quantities on the
#   context axis and the actionable context ordinals. Dense joins here with
#   the identity context axis (Synthesis 3.1, Q1).

# Dictionaries (design note Sections 2.1-2.2). A code is a position in its
# level vector; code 0 is the empty string and never an R index.
.ledgr_carrier_restriction_levels <- c(
  "trading_halted", "quotation_only", "status_unknown",
  "status_unknown_or_conflicting", "lifetime_inactive", "valuation_frozen"
)
.ledgr_carrier_mark_source_levels <- c(
  "missing", "expired_close", "current_close", "stale_close", "frozen_close"
)
# The prepared provider's own status and lifetime levels
# (R/availability-provider-prepared.R); the snapshot schema closes both
# vocabularies, so the provider never extends them.
.ledgr_carrier_status_levels <- c("unknown", "conflicting", "active", "halted", "quotation_only")
.ledgr_carrier_lifetime_levels <- c("unknown", "known_active", "known_inactive")

# Field specifications: "<storage>:<axis>:<missingness>". Axis `context` is
# the group's context length, `run` the run axis, `segment` the restriction
# segment total, `any` free; missingness `none` refuses NA, `na` admits NA
# (doubles must otherwise be finite) and `-` marks opaque fields.
.ledgr_carrier_fields <- list(
  decision_packet = c(
    pulse_idx = "integer:scalar:none", ts = "double:scalar:none",
    context_pos = "integer:context:none",
    cash = "double:scalar:none", positions_value = "double:scalar:none",
    position = "double:context:none",
    member = "logical:context:none", held = "logical:context:none",
    buyable = "logical:context:none", target_restricted = "logical:context:none",
    restriction_offset = "integer:context:none", restriction_count = "integer:context:none",
    restriction_code = "integer:segment:none",
    status = "integer:context:none", lifetime = "integer:context:none",
    terminal_event = "character:context:none", lifetime_fact_id = "character:context:none",
    mark = "double:context:na", reference = "double:context:na",
    source_ts = "double:context:na", mark_age = "integer:context:na",
    mark_source = "integer:context:none",
    priced = "logical:context:none", permissible = "logical:context:none",
    frozen = "logical:context:none"
  ),
  decision_data = c(
    open = "double:context:na", high = "double:context:na", low = "double:context:na",
    close = "double:context:na", volume = "double:context:na",
    observed = "logical:context:none",
    source_row = "integer:context:none", source_column = "integer:scalar:none",
    history = "opaque:any:-"
  ),
  execution_packet = c(
    exec_ts = "double:scalar:na", has_next = "logical:scalar:none",
    open = "double:run:na", high = "double:run:na", low = "double:run:na",
    close = "double:run:na", volume = "double:run:na"
  ),
  decision = c(
    context_pos = "integer:context:none",
    strategy_qty = "double:context:none", target_qty = "double:context:none",
    actionable_k = "integer:any:none",
    state_update = "opaque:any:-", intent_reason = "opaque:any:-"
  )
)
# The specifications split once: storage, axis and missingness per field.
.ledgr_carrier_field_parts <- lapply(.ledgr_carrier_fields, strsplit, split = ":", fixed = TRUE)

# NULL, or the first violated rule of group `group` on run axis length
# `n_run`: the exact field set and order, storage types, axis lengths,
# missingness, bounds and the group's invariants.
ledgr_carrier_problem <- function(x, group, n_run) {
  spec <- .ledgr_carrier_fields[[group]]
  if (!is.list(x) || is.data.frame(x) || !identical(names(x), names(spec))) {
    return("the field set is not exact")
  }
  parts <- .ledgr_carrier_field_parts[[group]]
  axis_field <- switch(group, decision_data = "source_row", execution_packet = NULL, "context_pos")
  n_context <- if (is.null(axis_field)) NA_integer_ else length(x[[axis_field]])
  n_segment <- if (identical(group, "decision_packet") && is.integer(x$restriction_count)) {
    sum(x$restriction_count)
  } else {
    NA_integer_
  }
  # One check per declared field: a fixed census, not a data-sized loop.
  for (k in seq_along(spec)) {
    v <- x[[k]]
    storage <- parts[[k]][[1L]]
    if (identical(storage, "opaque")) next
    typed <- switch(storage, integer = is.integer(v), double = is.double(v),
      logical = is.logical(v), character = is.character(v))
    if (!typed || is.object(v) || !is.null(attributes(v))) {
      return(paste0("`", names(spec)[[k]], "` is not a plain ", storage, " vector"))
    }
    size <- switch(parts[[k]][[2L]], scalar = 1L, context = n_context, run = n_run,
      segment = n_segment, any = length(v))
    if (is.na(size) || length(v) != size) {
      return(paste0("`", names(spec)[[k]], "` does not have its axis length"))
    }
    if (identical(parts[[k]][[3L]], "none") && anyNA(v)) {
      return(paste0("`", names(spec)[[k]], "` contains a missing value"))
    }
    if (is.double(v) && any(is.infinite(v))) {
      return(paste0("`", names(spec)[[k]], "` contains a non-finite value"))
    }
  }
  valid_pos <- function(p) all(p >= 1L & p <= n_run) && !anyDuplicated(p)
  switch(group,
    decision_packet = {
      if (x$pulse_idx < 1L) return("`pulse_idx` is not a pulse")
      if (!valid_pos(x$context_pos)) return("`context_pos` is not unique run positions")
      if (any(x$buyable & !x$member)) return("a buyable instrument is not a member")
      count <- x$restriction_count
      # Segments are contiguous and in context order: offsets are zero-based
      # running totals of the counts.
      if (any(count < 0L) || !identical(x$restriction_offset, c(0L, cumsum(count))[seq_along(count)])) {
        return("the restriction segments are not contiguous")
      }
      if (!identical(x$target_restricted, count > 0L)) {
        return("`target_restricted` does not match its restriction segments")
      }
      if (any(x$restriction_code < 1L | x$restriction_code > length(.ledgr_carrier_restriction_levels))) {
        return("a restriction code is outside its dictionary")
      }
      if (any(x$status < 1L | x$status > length(.ledgr_carrier_status_levels)) ||
          any(x$lifetime < 1L | x$lifetime > length(.ledgr_carrier_lifetime_levels))) {
        return("a status or lifetime code is outside its levels")
      }
      if (any(x$mark_source < 1L | x$mark_source > length(.ledgr_carrier_mark_source_levels))) {
        return("a mark source code is outside its dictionary")
      }
      if (any(x$mark_age < 0L, na.rm = TRUE)) return("a mark age is negative")
      if (!identical(x$priced, is.finite(x$mark))) return("`priced` does not match the marks")
      NULL
    },
    decision_data = {
      if (!valid_pos(x$source_row)) return("`source_row` is not unique run positions")
      if (x$source_column < 1L) return("`source_column` is not a prepared pulse column")
      NULL
    },
    execution_packet = {
      bars <- x[c("open", "high", "low", "close", "volume")]
      if (!x$has_next && !all(is.na(unlist(bars, use.names = FALSE)))) {
        return("an absent next bar carries values")
      }
      NULL
    },
    decision = {
      if (!valid_pos(x$context_pos)) return("`context_pos` is not unique run positions")
      k <- x$actionable_k
      if (any(k < 1L | k > n_context) || is.unsorted(k, strictly = TRUE)) {
        return("`actionable_k` is not ordered context ordinals")
      }
      reason <- x$intent_reason
      if (!is.null(reason) && (!is.character(reason) || length(reason) != 1L ||
          is.na(reason) || !nzchar(reason))) {
        return("`intent_reason` is not NULL or one non-empty string")
      }
      NULL
    }
  )
}

# Constructors of the four groups (V-packet with its three subgroups and
# V-decision): each validates once and returns the group unchanged.
ledgr_carrier_packet <- function(x, group, n_run) {
  if (!group %in% c("decision_packet", "decision_data", "execution_packet")) {
    rlang::abort("Unknown carrier packet group.", class = "ledgr_internal_error")
  }
  ledgr_carrier_new(x, group, n_run)
}

ledgr_carrier_decision <- function(x, n_run) {
  ledgr_carrier_new(x, "decision", n_run)
}

ledgr_carrier_new <- function(x, group, n_run) {
  problem <- ledgr_carrier_problem(x, group, n_run)
  if (!is.null(problem)) {
    rlang::abort(
      paste0("Invalid internal ", gsub("_", " ", group, fixed = TRUE), ": ", problem, "."),
      class = "ledgr_internal_error"
    )
  }
  x
}

# Transitional provider adapter (remover WS4b): the provider's decision view
# and the valuation state of one produced view, both keyed by the view's own
# axis in axis order, become the decision packet's provider and valuation
# columns. It reuses that mapping (the valuation's `source_row` is the run
# position of each axis entry) and converts each plane once; unpriced
# provenance (reference, source time, age, source, frozen) is kept field by
# field.
ledgr_carrier_provider_view <- function(view, valuation) {
  axis <- as.character(view$axis)
  plane <- function(x) {
    if (!identical(names(x), axis)) {
      rlang::abort(
        "Provider and valuation outputs must be keyed by the decision axis in axis order.",
        class = "ledgr_internal_error"
      )
    }
    unname(x)
  }
  member <- plane(view$member)
  restricted <- plane(view$target_restricted)
  # A restricted entry's reasons are its ordered tokens, primary first
  # (design note 2.1); unrestricted entries own an empty segment.
  tokens <- strsplit(plane(view$target_restriction_reasons)[restricted], "|", fixed = TRUE)
  count <- integer(length(axis))
  count[restricted] <- lengths(tokens)
  list(
    context_pos = as.integer(plane(valuation$source_row)),
    member = member,
    held = plane(view$held),
    buyable = member & !restricted,
    target_restricted = restricted,
    restriction_offset = c(0L, cumsum(count))[seq_along(count)],
    restriction_count = count,
    restriction_code = match(unlist(tokens, use.names = FALSE), .ledgr_carrier_restriction_levels),
    status = match(plane(view$status), .ledgr_carrier_status_levels),
    lifetime = match(plane(view$lifetime), .ledgr_carrier_lifetime_levels),
    terminal_event = plane(view$terminal_event),
    lifetime_fact_id = plane(view$lifetime_fact_id),
    mark = plane(valuation$mark),
    reference = plane(valuation$reference),
    source_ts = as.numeric(plane(valuation$source_ts)),
    mark_age = plane(valuation$age),
    mark_source = match(plane(valuation$source), .ledgr_carrier_mark_source_levels),
    priced = plane(valuation$priced),
    permissible = plane(valuation$permissible),
    frozen = plane(valuation$frozen)
  )
}

# The restriction segments as text on the context axis: the primary reason
# (the first token) and the "|"-joined reasons, "" when unrestricted.
ledgr_carrier_restriction_text <- function(packet) {
  count <- packet$restriction_count
  reason <- character(length(count))
  hit <- which(count > 0L)
  if (length(hit) == 0L) return(list(reason = reason, reasons = reason))
  tokens <- .ledgr_carrier_restriction_levels[packet$restriction_code]
  first <- packet$restriction_offset[hit] + 1L
  reason[hit] <- tokens[first]
  reasons <- reason
  # Append the r-th token of every segment that has one; r is bounded by the
  # dictionary size, so the loop runs over token ranks, not instruments.
  for (r in seq_len(max(count) - 1L)) {
    more <- hit[count[hit] > r]
    reasons[more] <- paste(reasons[more], tokens[packet$restriction_offset[more] + r + 1L], sep = "|")
  }
  list(reason = reason, reasons = reasons)
}

ledgr_carrier_mark_source_text <- function(code) {
  .ledgr_carrier_mark_source_levels[code]
}

# P2 input boundary (availability): the public context's availability
# planes, keyed by the context IDs as ledgr_pulse_context_vec() reads them,
# with the restriction and mark-source text decoded once for the pulse.
ledgr_carrier_p2_input <- function(packet, context_ids) {
  named <- function(v) stats::setNames(v, context_ids)
  restriction <- ledgr_carrier_restriction_text(packet)
  mark_source <- ledgr_carrier_mark_source_text(packet$mark_source)
  list(
    view = list(
      member = named(packet$member),
      held = named(packet$held),
      target_restricted = named(packet$target_restricted),
      target_restriction_reason = named(restriction$reason),
      priced = named(packet$priced),
      mark_age = named(packet$mark_age),
      risk_mark = named(packet$mark),
      mark_source = named(mark_source)
    ),
    restriction = restriction,
    mark_source = mark_source,
    members = context_ids[packet$member]
  )
}

# P2 stop boundary: the valuation fields the affected-exposure record reads by
# instrument ID, rebuilt from the packet for the risk-mark stop only.
ledgr_carrier_p2_valuation <- function(packet, context_ids) {
  named <- function(v) stats::setNames(v, context_ids)
  list(
    reference = named(packet$reference),
    source_ts = named(.POSIXct(packet$source_ts, tz = "UTC")),
    age = named(packet$mark_age),
    permissible = named(packet$permissible)
  )
}
