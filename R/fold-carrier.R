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
# only in resolved fee/cash columns and the packet's derived valuation, but
# refuses ordinary NA; accounting retains the base refusal for non-finite
# fees, and `-` marks opaque fields.
.ledgr_carrier_fields <- list(
  decision_packet = c(
    pulse_idx = "integer:scalar:none", ts = "double:scalar:none",
    context_pos = "integer:context:none",
    # The run-order valuation is derived from finite positions and marks; its
    # sum may overflow to Inf or NaN, which the run carries to the base
    # refusal point (amendment_valuation), but it is never NA.
    cash = "double:scalar:none", positions_value = "double:scalar:inf",
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
    # NA on dense; on availability the affordability scan's cash, which an
    # accepted sale's infinite proceeds (`inf` cash effects) carry to Inf.
    expected_final_cash = "double:scalar:any", economic_event_kinds = "integer:any:none",
    fill = "opaque:any:-", rejection = "opaque:any:-"
  ),
  # P4 (LDG-3167, Synthesis 3.5): one published fill block and its legs; the
  # row axis is the block's events or legs. `cash_delta` admits the overflow
  # the fill carried (`inf`); `meta` is the routed per-row metadata list.
  publication = c(
    status = "character:scalar:none", next_event_seq = "integer:scalar:none",
    event_id = "character:row:none", run_id = "character:row:none", ts_utc = "double:row:none",
    event_type = "character:row:none", instrument_id = "character:row:none", side = "character:row:none",
    qty = "double:row:none", price = "double:row:none", fee = "double:row:none",
    meta_json = "character:row:na", event_seq = "integer:row:none",
    cash_delta = "double:row:inf", position_delta = "double:row:none", meta = "opaque:any:-"
  ),
  leg = c(
    event_seq = "integer:row:none", instrument_id = "character:row:none", side = "character:row:none",
    action = "character:row:none", ts_utc = "double:row:none", qty = "double:row:none",
    price = "double:row:none", fee = "double:row:none", realized_pnl = "double:row:none"
  ),
  # LDG-3168 (Synthesis 3.6): the pulse diagnostic staging, its row axis
  # preallocated to `capacity` rows of which the first `n` are staged, and
  # the per-row columns in the writer's order; run_id, diagnostic_seq and
  # ts_utc are the pulse's constants and logical sequence, added at drain.
  # Missingness and bounds apply to the used prefix only. Defaults are the
  # persisted schema's (instrument_id "", stage and outcome NA, reasons the
  # reason_code, decision time the pulse, detail "{}").
  diagnostics = c(
    n = "integer:scalar:none", capacity = "integer:scalar:none",
    instrument_id = "character:row:none", stage = "character:row:na", outcome = "character:row:na",
    reason_code = "character:row:none", reasons = "character:row:none",
    target = "double:row:na", quantity = "double:row:na", price = "double:row:na",
    mark_source = "character:row:na", mark_age = "integer:row:na",
    decision_ts_utc = "double:row:none", execution_ts_utc = "double:row:na", event_seq = "integer:row:na",
    target_before_risk = "double:row:na", target_after_risk = "double:row:na",
    position_before = "double:row:na", position_after = "double:row:na",
    feature_identity_json = "character:row:na", detail_json = "character:row:none"
  ),
  # One row per valued pulse, preallocated to the fold's pulse count; only
  # the first `n` rows are valid. Values are kept as valued (`any`).
  equity = c(
    ts = "double:row:none", cash = "double:row:any", positions_value = "double:row:any",
    realized_pnl = "double:row:any", cost_basis = "double:row:any", n = "integer:scalar:none"
  ),
  # A stage's stop result, installed only by E; its diagnostics are a fully
  # used block of the staging schema.
  stop = c(
    status = "character:scalar:none", reason_code = "character:scalar:none",
    affected_instrument_ids = "character:any:none", affected_exposure = "opaque:any:-",
    diagnostics = "opaque:any:-", counts_processed = "logical:scalar:none"
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
  rejection = c("k", "reason_count"), plan = c(NA, NA),
  publication = c("event_id", NA), leg = c("event_seq", NA),
  diagnostics = c("instrument_id", NA), equity = c("ts", NA), stop = c(NA, NA)
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
  # The staging and equity groups (LDG-3168) first bound their used-row
  # count by the row axis; missingness then applies to the used prefix.
  used <- NULL
  if (group %in% c("diagnostics", "equity")) {
    n <- x$n
    if (!is.integer(n) || length(n) != 1L || !is.null(attributes(n)) || is.na(n) ||
        n < 0L || n > n_context) {
      return("`n` is not a used-row count within the capacity")
    }
    used <- seq_len(n)
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
    if (!is.null(used) && identical(parts[[k]][[2L]], "row")) v <- v[used]
    if ((identical(parts[[k]][[3L]], "none") && anyNA(v)) ||
        (identical(parts[[k]][[3L]], "inf") && any(is.na(v) & !is.nan(v)))) {
      return(paste0("`", names(spec)[[k]], "` contains a missing value"))
    }
    if (is.double(v) && !parts[[k]][[3L]] %in% c("inf", "any") && any(is.infinite(v))) {
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
    },
    publication = {
      n <- length(x$event_id)
      if (!identical(x$status, if (n > 0L) "WROTE" else "NO_OP")) {
        return("`status` does not match the block's rows")
      }
      # Sequences are contiguous within the block and generate their IDs.
      if (n > 0L && (x$event_seq[[1L]] < 1L || !identical(x$event_seq, x$event_seq[[1L]] + seq_len(n) - 1L) ||
          !identical(x$next_event_seq, x$event_seq[[n]] + 1L))) {
        return("the block's event sequences are not contiguous")
      }
      if (x$next_event_seq < 1L) return("`next_event_seq` is not a sequence")
      if (!identical(x$event_id, paste0(x$run_id, "_", sprintf("%08d", x$event_seq), recycle0 = TRUE))) {
        return("an event ID is not its run and sequence")
      }
      if (any(x$event_type != "FILL") || any(!nzchar(x$instrument_id)) || any(x$side != "BUY" & x$side != "SELL")) {
        return("an event type, instrument ID or side token is invalid")
      }
      if (any(x$qty <= 0) || any(x$price <= 0) || any(x$fee < 0)) {
        return("an event quantity, price or fee is out of range")
      }
      signed <- x$qty
      signed[x$side == "SELL"] <- -signed[x$side == "SELL"]
      if (!identical(x$position_delta, signed)) {
        return("`position_delta` is not the signed event quantity")
      }
      if (!is.list(x$meta) || !is.null(attributes(x$meta)) || length(x$meta) != n || !all(vapply(x$meta, is.list, NA))) {
        return("`meta` is not one metadata list per event")
      }
      NULL
    },
    leg = {
      if (any(x$action != "CLOSE" & x$action != "OPEN") || any(x$side != "BUY" & x$side != "SELL")) {
        return("a leg action or side token is invalid")
      }
      # Legs follow their events; within an event CLOSE precedes OPEN, once each.
      if (is.unsorted(2 * as.numeric(x$event_seq) + (x$action == "OPEN"), strictly = TRUE)) {
        return("legs are not in event order with CLOSE before OPEN")
      }
      if (any(x$qty <= 0) || any(x$price <= 0) || any(x$fee < 0)) {
        return("a leg quantity, price or fee is out of range")
      }
      if (any(x$realized_pnl[x$action == "OPEN"] != 0)) return("an OPEN leg realizes P&L")
      NULL
    },
    diagnostics = {
      if (x$capacity != n_context) return("`capacity` is not the staging's row count")
      if (any(x$mark_age[used] < 0L, na.rm = TRUE)) return("a mark age is negative")
      if (any(x$event_seq[used] < 1L, na.rm = TRUE)) return("an event sequence is below 1")
      NULL
    },
    equity = {
      if (is.unsorted(x$ts[used], strictly = TRUE)) return("the valued pulses are not in time order")
      NULL
    },
    stop = {
      if (!nzchar(x$status) || !nzchar(x$reason_code)) return("the stop status or reason is empty")
      if (!is.list(x$affected_exposure)) return("`affected_exposure` is not a list")
      problem <- ledgr_carrier_problem(x$diagnostics, "diagnostics", n_run)
      if (!is.null(problem)) return(paste0("diagnostics: ", problem))
      if (x$diagnostics$n != x$diagnostics$capacity) return("the stop diagnostics are not one fully used block")
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

# --- LDG-3168: diagnostics staging, equity record, stop results -----------
# (Synthesis 3.6 and Section 4; design note Sections 2.4 and 3.2.)

# The per-row staging columns, their defaults and the epoch columns.
.ledgr_diagnostic_row_fields <- names(.ledgr_carrier_fields$diagnostics)[-(1:2)]
.ledgr_diagnostic_defaults <- list(
  instrument_id = "", stage = NA_character_, outcome = NA_character_, reason_code = "",
  reasons = "", target = NA_real_, quantity = NA_real_, price = NA_real_, mark_source = "",
  mark_age = NA_integer_, decision_ts_utc = NA_real_, execution_ts_utc = NA_real_,
  event_seq = NA_integer_, target_before_risk = NA_real_, target_after_risk = NA_real_,
  position_before = NA_real_, position_after = NA_real_, feature_identity_json = NA_character_,
  detail_json = "{}"
)
.ledgr_diagnostic_epoch_fields <- c("decision_ts_utc", "execution_ts_utc")
.ledgr_diagnostic_storage <- vapply(.ledgr_carrier_field_parts$diagnostics[.ledgr_diagnostic_row_fields],
  function(p) p[[1L]], "")

# The pulse staging, allocated once in E (design note 2.4): every column is
# preallocated to `capacity` rows and nothing is staged.
ledgr_fold_diagnostic_staging <- function(capacity) {
  capacity <- as.integer(capacity)
  columns <- lapply(.ledgr_diagnostic_storage, vector, length = capacity)
  ledgr_carrier_new(c(list(n = 0L, capacity = capacity), columns), "diagnostics", NA_integer_)
}

# Design note 2.4's pinned bound: max(5N + 3, Q_pulse), where Q_pulse is the
# most due disposition rows of any pulse (0 without a corporate-action plan).
ledgr_fold_diagnostic_capacity <- function(n_inst, corporate_action_plan) {
  due <- lengths(corporate_action_plan$state$disposition_due_by_pulse)
  max(5L * as.integer(n_inst) + 3L, due, 0L)
}

# One producer segment as a fully used block of the staging schema: each
# field has length 1 or n (absent fields take the defaults), coerced as the
# persisted diagnostic schema stores it; times are UTC epoch seconds.
ledgr_fold_diagnostic_rows <- function(segment, ts) {
  m <- as.integer(segment$n)
  if (is.null(segment$reasons)) segment$reasons <- if (is.null(segment$reason_code)) "" else segment$reason_code
  ts_num <- as.numeric(as.POSIXct(ts, tz = "UTC"))
  out <- list(n = m, capacity = m)
  # A fixed census of the 19 row fields, not a data-sized loop.
  for (name in .ledgr_diagnostic_row_fields) {
    v <- segment[[name]]
    if (is.null(v)) v <- if (identical(name, "decision_ts_utc")) ts_num else .ledgr_diagnostic_defaults[[name]]
    if (!length(v) %in% c(1L, m)) {
      rlang::abort(sprintf("Diagnostic block field `%s` has length %d for a segment of %d rows.", name, length(v), m),
                   class = "ledgr_invalid_fold_execution")
    }
    v <- unname(v)
    v <- switch(.ledgr_diagnostic_storage[[name]],
      character = as.character(v),
      integer = as.integer(v),
      double = if (name %in% .ledgr_diagnostic_epoch_fields &&
        !(inherits(v, "POSIXct") || is.numeric(v))) {
        as.numeric(as.POSIXct(v, tz = "UTC"))
      } else {
        as.numeric(v)
      }
    )
    out[[name]] <- rep_len(v, m)
  }
  # The segment is validated once where it enters production (U-3168).
  ledgr_carrier_new(out, "diagnostics", NA_integer_)
}

# Stages a fully used block after the staging's used rows, by index into its
# preallocated columns. A row beyond the pinned capacity is a bug.
ledgr_fold_staging_write <- function(fold_state, rows) {
  m <- rows$n
  if (m == 0L) return(invisible(NULL))
  used <- fold_state$pending_segments$n
  if (used + m > fold_state$pending_segments$capacity) {
    rlang::abort("Pulse diagnostic staging exceeded its capacity.", class = "ledgr_invalid_fold_execution")
  }
  dest <- seq.int(used + 1L, length.out = m)
  for (name in .ledgr_diagnostic_row_fields) {
    collapse::setv(fold_state$pending_segments[[name]], dest, rows[[name]], vind1 = TRUE)
  }
  fold_state$pending_segments$n <- used + m
  invisible(NULL)
}

ledgr_fold_staging_add <- function(fold_state, segment, ts) {
  ledgr_fold_staging_write(fold_state, ledgr_fold_diagnostic_rows(segment, ts))
}

# The writer block of a staging-schema object's used prefix: the run ID,
# the logical sequence from `first_seq` and the pulse time on every row.
ledgr_fold_diagnostic_block <- function(rows, run_id, ts, first_seq) {
  n <- rows$n
  used <- seq_len(n)
  ts_num <- as.numeric(as.POSIXct(ts, tz = "UTC"))
  col <- function(name) rows[[name]][used]
  epoch <- function(name) .POSIXct(rows[[name]][used], tz = "UTC")
  list(
    run_id = rep_len(as.character(run_id), n),
    diagnostic_seq = as.integer(first_seq) + used - 1L,
    ts_utc = .POSIXct(rep_len(ts_num, n), tz = "UTC"),
    instrument_id = col("instrument_id"), stage = col("stage"), outcome = col("outcome"),
    reason_code = col("reason_code"), reasons = col("reasons"), target = col("target"),
    quantity = col("quantity"), price = col("price"), mark_source = col("mark_source"),
    mark_age = col("mark_age"), decision_ts_utc = epoch("decision_ts_utc"),
    execution_ts_utc = epoch("execution_ts_utc"), event_seq = col("event_seq"),
    target_before_risk = col("target_before_risk"), target_after_risk = col("target_after_risk"),
    position_before = col("position_before"), position_after = col("position_after"),
    feature_identity_json = col("feature_identity_json"), detail_json = col("detail_json")
  )
}

# The equity record (Synthesis 3.6): five columns preallocated to the fold's
# pulse count, the first `n` rows valued.
ledgr_fold_equity_record <- function(capacity) {
  capacity <- as.integer(capacity)
  ledgr_carrier_new(list(
    ts = numeric(capacity), cash = numeric(capacity), positions_value = numeric(capacity),
    realized_pnl = numeric(capacity), cost_basis = numeric(capacity), n = 0L
  ), "equity", NA_integer_)
}

# P1's one write per valued pulse, by index into the record's next row.
ledgr_fold_equity_append <- function(record, ts, cash, positions_value, realized_pnl, cost_basis) {
  i <- record$n + 1L
  if (i > length(record$ts)) {
    rlang::abort("Internal equity record exceeded its capacity.", class = "ledgr_internal_error")
  }
  collapse::setv(record$ts, i, as.numeric(ts), vind1 = TRUE)
  collapse::setv(record$cash, i, as.numeric(cash), vind1 = TRUE)
  collapse::setv(record$positions_value, i, as.numeric(positions_value), vind1 = TRUE)
  collapse::setv(record$realized_pnl, i, as.numeric(realized_pnl), vind1 = TRUE)
  collapse::setv(record$cost_basis, i, as.numeric(cost_basis), vind1 = TRUE)
  record$n <- i
  record
}

# E's frozen handoff: the valued prefix as fresh columns, never written again.
ledgr_fold_equity_prefix <- function(record) {
  used <- seq_len(record$n)
  ledgr_carrier_new(list(
    ts = record$ts[used], cash = record$cash[used], positions_value = record$positions_value[used],
    realized_pnl = record$realized_pnl[used], cost_basis = record$cost_basis[used], n = record$n
  ), "equity", NA_integer_)
}
