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
# LDG-3166 adds the P3 groups (Synthesis 3.3): the execution view (P3 only),
# and the plan with its fill and rejection groups (P3 -> P5), one row per
# actionable context ordinal, validated once by ledgr_carrier_plan().

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
# (doubles must otherwise be finite), `inf` admits Inf and arithmetic NaN
# only in resolved fee/cash columns, but refuses ordinary NA; accounting
# retains the base refusal for non-finite fees, and
# `-` marks opaque fields.
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
  ),
  # P3 (LDG-3166, Synthesis 3.3). Axis `row` is the group's own rows: the
  # candidate IDs of the execution view, the fills or the rejections.
  execution_view = c(
    member = "logical:row:none", restricted = "logical:row:none",
    reason_offset = "integer:row:none", reason_count = "integer:row:none",
    reason_code = "integer:segment:none"
  ),
  fill = c(
    k = "integer:row:none", pos = "integer:row:none", side = "integer:row:none",
    qty = "double:row:none", price = "double:row:none", fee = "double:row:inf",
    cash_delta = "double:row:inf", position_delta = "double:row:none",
    exec_ts = "double:row:none",
    position_before = "double:row:none", planned_position_after = "double:row:none",
    info_offset = "integer:row:none", info_count = "integer:row:none",
    info_code = "integer:segment:none"
  ),
  rejection = c(
    k = "integer:row:none", pos = "integer:row:none", emit = "integer:row:none",
    primary = "integer:row:none",
    reason_offset = "integer:row:none", reason_count = "integer:row:none",
    reason_code = "integer:segment:none",
    resolved_price = "double:row:na", exec_ts = "double:row:na",
    position = "double:row:none"
  ),
  plan = c(
    expected_final_cash = "double:scalar:na", economic_event_kinds = "integer:any:none",
    fill = "opaque:any:-", rejection = "opaque:any:-"
  )
)
# The specifications split once: storage, axis and missingness per field.
.ledgr_carrier_field_parts <- lapply(.ledgr_carrier_fields, strsplit, split = ":", fixed = TRUE)
# Per group: the field whose length is the group's own axis, and the count
# field of its code segment.
.ledgr_carrier_axes <- list(
  decision_packet = c("context_pos", "restriction_count"), decision_data = c("source_row", NA),
  execution_packet = c(NA, NA), decision = c("context_pos", NA),
  execution_view = c("member", "reason_count"), fill = c("k", "info_count"),
  rejection = c("k", "reason_count"), plan = c(NA, NA)
)

# P3 dictionaries (design note Sections 2.1-2.2): reason tokens of fills and
# rejections, and the economic event kinds. Code 0 is the empty string.
.ledgr_plan_reason_levels <- c(
  "final_pulse_no_execution", "execution_bar_missing", "insufficient_cash",
  "membership_changed_before_execution", "trading_halted", "quotation_only",
  "status_unknown", "status_unknown_or_conflicting", "lifetime_inactive"
)
.ledgr_plan_kind_levels <- c("FILL", "CASHFLOW", "DISPOSITION")

# NULL, or the first violated rule of group `group` on run axis length
# `n_run`: the exact field set and order, storage types, axis lengths,
# missingness, bounds and the group's invariants. The plan groups also take
# `plan_axis`: the decision's context_pos and actionable_k.
ledgr_carrier_problem <- function(x, group, n_run, plan_axis = NULL) {
  spec <- .ledgr_carrier_fields[[group]]
  if (!is.list(x) || is.data.frame(x) || !identical(names(x), names(spec))) {
    return("the field set is not exact")
  }
  parts <- .ledgr_carrier_field_parts[[group]]
  axes <- .ledgr_carrier_axes[[group]]
  n_context <- if (is.na(axes[[1L]])) NA_integer_ else length(x[[axes[[1L]]]])
  n_segment <- if (!is.na(axes[[2L]]) && is.integer(x[[axes[[2L]]]])) {
    sum(x[[axes[[2L]]]])
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
    size <- switch(parts[[k]][[2L]], scalar = 1L, context = , row = n_context, run = n_run,
      segment = n_segment, any = length(v))
    if (is.na(size) || length(v) != size) {
      return(paste0("`", names(spec)[[k]], "` does not have its axis length"))
    }
    if ((identical(parts[[k]][[3L]], "none") && anyNA(v)) ||
        (identical(parts[[k]][[3L]], "inf") && any(is.na(v) & !is.nan(v)))) {
      return(paste0("`", names(spec)[[k]], "` contains a missing value"))
    }
    if (is.double(v) && !identical(parts[[k]][[3L]], "inf") && any(is.infinite(v))) {
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
    },
    execution_view = {
      problem <- ledgr_carrier_segment_problem(x$reason_offset, x$reason_count, x$reason_code)
      if (!is.null(problem)) return(problem)
      if (!identical(x$restricted, x$reason_count > 0L)) {
        return("`restricted` does not match its reason segments")
      }
      NULL
    },
    fill = {
      problem <- ledgr_carrier_row_problem(x$k, x$pos, plan_axis, n_run)
      if (!is.null(problem)) return(problem)
      if (is.unsorted(x$k, strictly = TRUE)) return("fills are not in decision order")
      if (any(x$side != 1L & x$side != -1L)) return("a fill side is not +1 or -1")
      if (any(x$qty <= 0) || any(x$price <= 0) || any(x$fee < 0, na.rm = TRUE)) {
        return("a fill quantity, price or fee is out of range")
      }
      if (any(is.nan(x$cash_delta) & is.finite(x$fee))) {
        return("an undefined cash effect requires a non-finite fee")
      }
      if (!identical(x$position_delta, x$side * x$qty)) {
        return("`position_delta` is not the signed fill quantity")
      }
      if (!identical(x$planned_position_after, x$position_before + x$position_delta)) {
        return("`planned_position_after` is not the position before plus the fill")
      }
      ledgr_carrier_segment_problem(x$info_offset, x$info_count, x$info_code)
    },
    rejection = {
      problem <- ledgr_carrier_row_problem(x$k, x$pos, plan_axis, n_run)
      if (!is.null(problem)) return(problem)
      # Early rejections (emit 1) precede affordability rejections (emit 2);
      # each phase keeps decision order.
      if (any(x$emit != 1L & x$emit != 2L) ||
          is.unsorted(x$emit * (length(plan_axis$context_pos) + 1L) + x$k, strictly = TRUE)) {
        return("rejections are not in emission order")
      }
      problem <- ledgr_carrier_segment_problem(x$reason_offset, x$reason_count, x$reason_code)
      if (!is.null(problem)) return(problem)
      if (any(x$reason_count < 1L)) return("a rejection has no reason")
      if (!identical(x$primary, x$reason_code[x$reason_offset + 1L])) {
        return("`primary` is not the first reason")
      }
      # Only an unresolved (early) row lacks a price; only a row without an
      # execution opportunity (final_pulse_no_execution) lacks an epoch.
      if (any(is.na(x$resolved_price) != (x$emit == 1L))) {
        return("resolved-price missingness disagrees with rejection phase")
      }
      if (any(is.na(x$exec_ts) != (x$primary == 1L))) {
        return("execution-epoch missingness disagrees with opportunity")
      }
      if (any(x$resolved_price <= 0, na.rm = TRUE)) return("a resolved price is not positive")
      NULL
    },
    plan = {
      kinds <- x$economic_event_kinds
      if (any(kinds < 1L | kinds > length(.ledgr_plan_kind_levels)) || anyDuplicated(kinds)) {
        return("an economic event kind is outside its dictionary")
      }
      for (part in c("fill", "rejection")) {
        problem <- ledgr_carrier_problem(x[[part]], part, n_run, plan_axis)
        if (!is.null(problem)) return(paste0(part, ": ", problem))
      }
      if (length(x$fill$k) == 0L && length(x$rejection$k) == 0L && length(kinds) > 0L) {
        return("an empty plan declares economic event kinds")
      }
      if ((length(x$fill$k) > 0L) != (1L %in% kinds)) {
        return("the FILL kind is not declared exactly when the plan has fills")
      }
      if (!identical(sort(c(x$fill$k, x$rejection$k)), plan_axis$actionable_k)) {
        return("the plan does not hold one row per actionable context ordinal")
      }
      NULL
    }
  )
}

# Rows of a fill or rejection group: context ordinals on the decision's axis
# and pos = context_pos[k] on the run axis.
ledgr_carrier_row_problem <- function(k, pos, plan_axis, n_run) {
  context_pos <- plan_axis$context_pos
  if (any(k < 1L | k > length(context_pos)) || anyDuplicated(k)) {
    return("`k` is not distinct context ordinals")
  }
  if (!identical(pos, context_pos[k]) || any(pos > n_run)) {
    return("`pos` is not context_pos[k] on the run axis")
  }
  NULL
}

# A code segment of P3: contiguous offsets, codes in the P3 dictionary and
# no code twice within a row.
ledgr_carrier_segment_problem <- function(offset, count, code) {
  if (any(count < 0L) || !identical(offset, c(0L, cumsum(count))[seq_along(count)])) {
    return("the reason segments are not contiguous")
  }
  if (any(code < 1L | code > length(.ledgr_plan_reason_levels))) {
    return("a reason code is outside its dictionary")
  }
  if (anyDuplicated(rep.int(seq_along(count), count) * 16L + code)) {
    return("a reason segment repeats a code")
  }
  NULL
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

# The P3 plan (V-plan, with V-fill and V-rejection for its two groups) on the
# decision's context axis and actionable ordinals.
ledgr_carrier_plan <- function(x, context_pos, actionable_k, n_run) {
  ledgr_carrier_new(x, "plan", n_run, list(context_pos = context_pos, actionable_k = actionable_k))
}

# The P3 groups keep the existing pulse-plan condition class (design note
# 2.2); the P1 and P2 groups refuse as internal errors.
ledgr_carrier_new <- function(x, group, n_run, plan_axis = NULL) {
  problem <- ledgr_carrier_problem(x, group, n_run, plan_axis)
  if (!is.null(problem)) {
    rlang::abort(
      paste0("Invalid internal ", gsub("_", " ", group, fixed = TRUE), ": ", problem, "."),
      class = if (group %in% c("execution_view", "fill", "rejection", "plan")) {
        c("ledgr_invalid_pulse_plan", "ledgr_invalid_fold_execution")
      } else {
        "ledgr_internal_error"
      }
    )
  }
  x
}

# Ordered, deduplicated code segments of `n` rows (design note 2.1): `row`
# and `code` list the codes in emission order; within a row the first
# occurrence of a code is kept, in emission order.
ledgr_carrier_segments <- function(n, row, code) {
  row <- as.integer(row)
  ord <- order(row, method = "radix")
  row <- row[ord]
  code <- as.integer(code)[ord]
  keep <- !duplicated(row * 16L + code)
  count <- tabulate(row[keep], nbins = n)
  list(offset = c(0L, cumsum(count))[seq_len(n)], count = count, code = code[keep])
}

# The segments of rows `idx`, in that order.
ledgr_carrier_segment_rows <- function(offset, count, code, idx) {
  count <- count[idx]
  at <- rep.int(offset[idx], count) + sequence(count)
  list(offset = c(0L, cumsum(count))[seq_along(idx)], count = count, code = code[at])
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
  ledgr_carrier_segment_text(packet$restriction_offset, packet$restriction_count,
    packet$restriction_code, .ledgr_carrier_restriction_levels)
}

# Code segments as text, one entry per row: the first token and the
# "|"-joined tokens, "" for an empty segment.
ledgr_carrier_segment_text <- function(offset, count, code, levels) {
  reason <- character(length(count))
  hit <- which(count > 0L)
  if (length(hit) == 0L) return(list(reason = reason, reasons = reason))
  tokens <- levels[code]
  first <- offset[hit] + 1L
  reason[hit] <- tokens[first]
  reasons <- reason
  # Append the r-th token of every segment that has one; r is bounded by the
  # dictionary size, so the loop runs over token ranks, not instruments.
  for (r in seq_len(max(count) - 1L)) {
    more <- hit[count[hit] > r]
    reasons[more] <- paste(reasons[more], tokens[offset[more] + r + 1L], sep = "|")
  }
  list(reason = reason, reasons = reasons)
}

# Transitional execution-view adapter (remover WS4b), the declared P3
# service: the provider's execution view of the candidate IDs at the pulse's
# execution epoch, keyed by those IDs in order, becomes the typed view on the
# candidate axis. A restricted candidate carries its blocking reasons as an
# ordered, deduplicated segment; a token outside the P3 dictionary refuses.
ledgr_carrier_execution_view <- function(provider, exec_ts, ids) {
  ids <- as.character(ids)
  view <- provider$execution_view(.POSIXct(exec_ts, tz = "UTC"), ids)
  plane <- function(x) {
    if (!identical(names(x), ids)) {
      rlang::abort(
        "The execution view must be keyed by the candidate IDs in order.",
        class = "ledgr_internal_error"
      )
    }
    unname(x)
  }
  restricted <- plane(view$restricted)
  tokens <- strsplit(plane(view$reasons)[restricted], "|", fixed = TRUE)
  code <- match(unlist(tokens, use.names = FALSE), .ledgr_plan_reason_levels)
  if (anyNA(code)) {
    rlang::abort(
      "An execution-view reason is outside the pulse-plan dictionary.",
      class = c("ledgr_invalid_pulse_plan", "ledgr_invalid_fold_execution")
    )
  }
  segment <- ledgr_carrier_segments(length(ids), rep.int(which(restricted), lengths(tokens)), code)
  ledgr_carrier_new(list(
    member = plane(view$member),
    restricted = restricted,
    reason_offset = segment$offset,
    reason_count = segment$count,
    reason_code = segment$code
  ), "execution_view", NA_integer_)
}

# Execution epochs of the prepared opportunity axis (the next pulse on dense,
# the declared next-session openings on availability), validated once in E:
# TRUE where a fill may execute at a whole UTC second.
ledgr_plan_epoch_valid <- function(axis) {
  epoch <- as.numeric(axis)
  !is.na(epoch) & ledgr_whole_second_posix(epoch)
}

# The refusal of an invalid execution epoch, raised where a planned fill first
# needs it, with the fill model's condition.
ledgr_plan_refuse_epoch <- function(exec_ts) {
  ledgr_assert_whole_second_utc(
    .POSIXct(exec_ts, tz = "UTC"),
    label = "`next_bar$ts_utc`",
    class = "ledgr_invalid_fill_input"
  )
  rlang::abort("An execution epoch flagged invalid is a whole UTC second.", class = "ledgr_internal_error")
}

# The economic event kinds as their tokens; a code outside the dictionary
# shows as its number.
ledgr_plan_kind_text <- function(kinds) {
  out <- as.character(kinds)
  known <- kinds %in% seq_along(.ledgr_plan_kind_levels)
  out[known] <- .ledgr_plan_kind_levels[kinds[known]]
  out
}

# The next-open fill model's side of each signed target delta: +1 buys, -1
# sells; the quantity is abs(delta).
ledgr_plan_side <- function(delta) {
  side <- rep(-1L, length(delta))
  side[delta > 0] <- 1L
  side
}

# Price and fee of a batch of fills from the compiled cost steps: one
# resolver call per pulse, none for an empty batch.
ledgr_plan_resolve <- function(cost_resolver, side, qty, open) {
  if (length(qty) == 0L) return(list(price = numeric(), fee = numeric()))
  resolved <- cost_resolver(side, qty, open)
  if (!is.list(resolved) || !is.double(resolved$price) || !is.double(resolved$fee) ||
      length(resolved$price) != length(qty) || length(resolved$fee) != length(qty)) {
    rlang::abort(
      "The cost resolver must return one price and one fee per fill.",
      class = c("ledgr_invalid_pulse_plan", "ledgr_invalid_fold_execution")
    )
  }
  list(price = resolved$price, fee = resolved$fee)
}

# The fill and rejection groups of one pulse, gathered from the candidate
# columns (one entry per actionable ordinal) by row index. `fills` are in
# decision order, with `effects` computed once for exactly those rows by
# ledgr_fill_publication_deltas(); `rejected` and `emit` are in emission
# order. `segment` holds every candidate's ordered reason codes.
ledgr_plan_groups <- function(k, pos, side, qty, price, fee, exec_ts, before, segment,
                              fills, effects, rejected, emit, resolved_price) {
  info <- ledgr_carrier_segment_rows(segment$offset, segment$count, segment$code, fills)
  reasons <- ledgr_carrier_segment_rows(segment$offset, segment$count, segment$code, rejected)
  list(
    fill = list(
      k = k[fills], pos = pos[fills], side = side[fills],
      qty = qty[fills], price = price[fills], fee = fee[fills],
      cash_delta = effects$cash_delta, position_delta = effects$position_delta,
      exec_ts = rep(exec_ts, length(fills)),
      position_before = before[fills],
      planned_position_after = before[fills] + effects$position_delta,
      info_offset = info$offset, info_count = info$count, info_code = info$code
    ),
    rejection = list(
      k = k[rejected], pos = pos[rejected], emit = emit,
      primary = reasons$code[reasons$offset + 1L],
      reason_offset = reasons$offset, reason_count = reasons$count, reason_code = reasons$code,
      resolved_price = resolved_price,
      exec_ts = rep(exec_ts, length(rejected)),
      position = before[rejected]
    )
  )
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
