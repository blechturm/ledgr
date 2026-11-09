# Lean P3 (macro WS16 family method; first family after the first
# checkpoint, chosen by the per-stage profile, maintainer 2026-11-09).
#
# lean_stage_plan() replaces the pinned ledgr_fold_stage_plan
# (R/fold-engine.R:1086, pin d5b3a151) inside an otherwise pinned run, through
# lean_plan_install(), which only harnesses call. It reads and writes the
# pin's fold state and stage groups unchanged: the plan (`batch`) it returns
# is the pin's, field for field, and it stages the same diagnostic rows and
# implicit blocks in the same order.
#
# What changes (profile: dev/bench/v0_2_3_ws16_stage_profile/):
#   - internal hand-offs are checked only in debug (AGENTS.md, interface
#     Section 13): the execution view, plan, fill and rejection carriers, the
#     staged diagnostic rows and the event-kind gates, whose inputs are this
#     stage's own output (kinds are {} or FILL);
#   - empty reason segments are built directly;
#   - fill and rejection diagnostic segments are built only when a row of
#     them is staged; logical positions advance as before;
#   - the reconciliation compares exactly first and calls all.equal() only
#     when the sums differ.
# Kept in production: the cost resolver's shape refusal, the target-delta,
# epoch and short-exposure refusals, the execution-view dictionary refusal,
# the affordability scan and the reconciliation stop.

lean_plan_empty_segments <- function(n) list(offset = integer(n), count = integer(n), code = integer())

lean_plan_segments <- function(n, row, code) {
  if (length(row) == 0L) return(lean_plan_empty_segments(n))
  ledgr_carrier_segments(n, row, code)
}

lean_plan_segment_rows <- function(segment, idx) {
  if (length(segment$code) == 0L) return(lean_plan_empty_segments(length(idx)))
  ledgr_carrier_segment_rows(segment$offset, segment$count, segment$code, idx)
}

# The provider's execution view of the candidates as the typed view
# (pinned: ledgr_carrier_execution_view, R/fold-carrier.R:622).
lean_plan_execution_view <- function(provider, exec_ts, ids) {
  view <- provider$execution_view(.POSIXct(exec_ts, tz = "UTC"), ids)
  if (.lean_debug && !(identical(names(view$member), ids) && identical(names(view$restricted), ids) &&
                       identical(names(view$reasons), ids))) {
    rlang::abort("The execution view must be keyed by the candidate IDs in order.", class = "ledgr_internal_error")
  }
  n <- length(ids)
  restricted <- unname(view$restricted)
  segment <- if (anyNA(restricted) || any(restricted)) {
    tokens <- strsplit(unname(view$reasons)[restricted], "|", fixed = TRUE)
    code <- match(unlist(tokens, use.names = FALSE), .ledgr_plan_reason_levels)
    if (anyNA(code)) {
      rlang::abort(
        "An execution-view reason is outside the pulse-plan dictionary.",
        class = c("ledgr_invalid_pulse_plan", "ledgr_invalid_fold_execution")
      )
    }
    ledgr_carrier_segments(n, rep.int(which(restricted), lengths(tokens)), code)
  } else {
    lean_plan_empty_segments(n)
  }
  x <- list(member = unname(view$member), restricted = restricted,
            reason_offset = segment$offset, reason_count = segment$count, reason_code = segment$code)
  if (.lean_debug) ledgr_carrier_new(x, "execution_view", NA_integer_) else x
}

# The fill and rejection groups (pinned: ledgr_plan_groups, R/fold-carrier.R:709).
lean_plan_groups <- function(k, pos, side, qty, price, fee, exec_ts, before, segment,
                             fills, effects, rejected, emit, resolved_price) {
  info <- lean_plan_segment_rows(segment, fills)
  reasons <- lean_plan_segment_rows(segment, rejected)
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

# The availability planner (pinned: ledgr_fold_build_availability_pulse_plan,
# R/availability-economics.R:365), same order of checks and rows.
lean_plan_pulse <- function(context_pos, target_qty, position, actionable_k, member, execution,
                            execution_view, epoch_valid, cost_resolver, cash, instrument_ids) {
  k <- actionable_k
  n <- length(k)
  pos <- context_pos[k]
  before <- position[k]
  delta <- target_qty[k] - before
  side <- ledgr_plan_side(delta)
  qty <- abs(delta)
  exec_ts <- execution$exec_ts
  plan <- function(groups, kinds, final_cash) {
    x <- list(expected_final_cash = as.numeric(final_cash), economic_event_kinds = kinds,
              fill = groups$fill, rejection = groups$rejection)
    if (.lean_debug) ledgr_carrier_plan(x, context_pos, actionable_k, length(instrument_ids)) else x
  }
  none <- integer()
  if (is.na(exec_ts)) {
    segment <- ledgr_carrier_segments(n, seq_len(n), rep(1L, n))
    groups <- lean_plan_groups(k, pos, side, qty, rep(NA_real_, n), rep(NA_real_, n), exec_ts, before, segment,
      none, list(cash_delta = numeric(), position_delta = numeric()), seq_len(n), rep(1L, n), rep(NA_real_, n))
    return(plan(groups, none, cash))
  }

  view_member <- if (n > 0L) execution_view$member else logical()
  informational <- which(member[k] != view_member)
  open <- execution$open[pos]
  bad_open <- !is.finite(open) | open <= 0
  bad_delta <- !is.finite(delta)
  passed <- which(!bad_open & !bad_delta & epoch_valid)
  resolved <- ledgr_plan_resolve(cost_resolver, side[passed], qty[passed], open[passed])
  price <- rep(NA_real_, n)
  fee <- rep(NA_real_, n)
  price[passed] <- resolved$price
  fee[passed] <- resolved$fee
  bad_price <- !bad_open & !(is.finite(price) & price > 0)
  candidates <- passed[!bad_price[passed]]

  effects <- ledgr_fill_publication_deltas(side[candidates], qty[candidates], price[candidates], fee[candidates])
  resulting <- rep(NA_real_, n)
  resulting[candidates] <- before[candidates] + effects$position_delta
  short <- logical(n)
  short[candidates] <- resulting[candidates] < pmin(before[candidates], 0)
  if (any(bad_delta) || (!epoch_valid && n > 0L) || any(short)) {
    ledgr_plan_refuse_first(
      list(!bad_open & bad_delta, !bad_open & !epoch_valid, short),
      list(
        function(i) ledgr_plan_refuse_delta(),
        function(i) ledgr_plan_refuse_epoch(exec_ts),
        function(i) {
          id <- instrument_ids[[pos[[i]]]]
          ledgr_availability_validate_short_exposure(stats::setNames(resulting[[i]], id), stats::setNames(before[[i]], id))
        }
      )
    )
  }
  early <- which(bad_open | bad_price)

  view_count <- if (n > 0L) execution_view$reason_count else integer()
  blocked <- view_count[candidates] > 0L
  generator <- side[candidates] == -1L & before[candidates] > 0 & delta[candidates] < 0 &
    effects$cash_delta >= 0 & !blocked
  scan <- ledgr_plan_affordability(effects$cash_delta, blocked, generator,
    instrument_ids[pos[candidates]], cash)
  fills <- candidates[scan$accepted]
  late <- candidates[!scan$accepted]

  view_code <- if (n > 0L) execution_view$reason_code else integer()
  short_cash <- candidates[scan$insufficient]
  segment <- lean_plan_segments(n,
    c(rep.int(seq_len(n), view_count), early, short_cash, informational),
    c(view_code, rep(2L, length(early)), rep(3L, length(short_cash)), rep(4L, length(informational))))
  groups <- lean_plan_groups(k, pos, side, qty, price, fee, exec_ts, before, segment,
    fills, list(cash_delta = effects$cash_delta[scan$accepted], position_delta = effects$position_delta[scan$accepted]),
    c(early, late), rep(c(1L, 2L), c(length(early), length(late))),
    c(rep(NA_real_, length(early)), price[late]))
  plan(groups, if (length(fills) > 0L) 1L else none, scan$final_cash)
}

# Stages rows `index` of a segment of `n` logical rows and reserves all n
# logical positions (pinned: ledgr_fold_staging_add_residual,
# R/fold-carrier.R:912). `segment` is a function so a segment none of whose
# rows is staged is never built.
lean_plan_stage <- function(fold_state, n, segment, index) {
  start <- fold_state$pending_segments$logical_n
  if (length(index) > 0L) {
    index <- as.integer(index)
    s <- segment()
    m <- length(index)
    rows <- list(n = m, logical_n = m, capacity = m, logical_offset = seq_len(m))
    for (name in .ledgr_diagnostic_row_fields) {
      v <- s[[name]]
      rows[[name]] <- if (length(v) == 1L) rep_len(v, m) else v[index]
    }
    if (.lean_debug) ledgr_carrier_new(rows, "diagnostics", NA_integer_)
    ledgr_fold_staging_write(fold_state, rows, start + index)
  }
  fold_state$pending_segments$logical_n <- start + n
  start + seq_len(n)
}

lean_stage_plan <- function(
    fold_state,
    services,
    observation,
    decision,
    execution,
    sample_telemetry,
    sample_start) {
  fold_state$current_stage <- "execution"
  pulse_idx <- observation$pulse_idx
  ts <- observation$ts
  context_pos <- decision$context_pos
  target_qty <- decision$target_qty
  strategy_qty <- decision$strategy_qty
  position <- as.numeric(fold_state$positions[context_pos])
  actionable_k <- decision$actionable_k
  instrument_ids <- services$instrument_ids
  epochs <- services$execution_epochs
  epoch_valid <- pulse_idx > length(epochs) || services$execution_epoch_valid[[pulse_idx]]
  if (sample_telemetry) {
    sample_now <- ledgr_time_now()
    t_target <- decision$t_target + ledgr_time_elapsed(sample_start, sample_now)
    sample_start <- sample_now
  } else {
    t_target <- decision$t_target
  }

  if (sample_telemetry) sample_start <- ledgr_time_now()
  exec_ts <- execution$exec_ts
  execution_view <- if (!is.na(exec_ts) && length(actionable_k) > 0L) {
    lean_plan_execution_view(services$availability_provider, exec_ts, instrument_ids[context_pos[actionable_k]])
  }
  batch <- lean_plan_pulse(
    context_pos = context_pos,
    target_qty = target_qty,
    position = position,
    actionable_k = actionable_k,
    member = observation$packet$member,
    execution = execution,
    execution_view = execution_view,
    epoch_valid = epoch_valid,
    cost_resolver = services$cost_resolver,
    cash = fold_state$cash,
    instrument_ids = instrument_ids
  )
  if (.lean_debug) {
    kinds <- ledgr_fold_plan_event_kinds(batch, canonical_event_kinds = if (services$use_compiled_spot_fifo) NULL else 1:2)
    if (services$use_compiled_spot_fifo) ledgr_require_compiled_spot_fifo_event_kinds(kinds)
  }
  if (sample_telemetry) {
    sample_now <- ledgr_time_now()
    t_fill <- ledgr_time_elapsed(sample_start, sample_now)
    sample_start <- sample_now
  } else {
    t_fill <- 0
  }

  fill <- batch$fill
  rejection <- batch$rejection
  decision_diagnostic <- decision$diagnostic_decision
  risk_diagnostic <- decision$diagnostic_risk
  n_decision <- decision_diagnostic$n
  stage_whole <- function(segment) {
    if (!is.null(segment)) lean_plan_stage(fold_state, segment$n, function() segment, seq_len(segment$n))
  }
  recorded_final_cash <- fold_state$cash + sum(fill$cash_delta)
  expected_final_cash <- batch$expected_final_cash
  if (!isTRUE(recorded_final_cash == expected_final_cash) && !isTRUE(all.equal(
    as.numeric(recorded_final_cash),
    as.numeric(expected_final_cash),
    tolerance = ledgr_availability_cash_tolerance
  ))) {
    stage_whole(decision_diagnostic)
    stage_whole(risk_diagnostic)
    affordability_detail <- canonical_json(list(
      cash_before = fold_state$cash,
      virtual_final_cash = expected_final_cash,
      recorded_final_cash = recorded_final_cash
    ))
    return(ledgr_fold_stop_result(
      status = "INCOMPLETE",
      reason_code = "affordability_reconciliation_failed",
      affected_instrument_ids = character(),
      affected_exposure = fold_state$affected_exposure,
      diagnostics = ledgr_fold_diagnostic_rows(list(
        n = 1L,
        stage = "affordability",
        outcome = "stopped",
        reason_code = "affordability_reconciliation_failed",
        detail_json = affordability_detail
      ), ts),
      counts_processed = TRUE
    ))
  }

  n_fill <- length(fill$k)
  n_rejection <- length(rejection$k)
  fill_reasons <- if (n_fill > 0L) {
    ledgr_carrier_segment_text(fill$info_offset, fill$info_count, fill$info_code, .ledgr_plan_reason_levels)
  }
  encode <- isTRUE(services$diagnostic_writer$can_encode)
  clean <- if (encode && n_fill > 0L) {
    ledgr_diagnostic_clean_fill(decision_diagnostic, risk_diagnostic, fill, fill_reasons)
  } else {
    rep(FALSE, n_fill)
  }
  clean[is.na(clean)] <- FALSE
  clean_rows <- which(clean)
  clean_k <- if (length(clean_rows) > 0L) fill$k[clean_rows] else integer()
  clean_hold <- if (encode) {
    ledgr_diagnostic_clean_hold(decision_diagnostic, risk_diagnostic, excluded_k = c(fill$k, rejection$k))
  } else {
    rep(FALSE, n_decision)
  }
  clean_hold_k <- which(clean_hold)
  implicit <- logical(n_decision)
  implicit[clean_k] <- TRUE
  implicit[clean_hold_k] <- TRUE

  decision_offsets <- lean_plan_stage(fold_state, n_decision, function() decision_diagnostic, which(!implicit))
  stage_whole(risk_diagnostic)
  if (n_rejection > 0L) {
    lean_plan_stage(fold_state, n_rejection, function() {
      rejection_reasons <- ledgr_carrier_segment_text(rejection$reason_offset, rejection$reason_count,
        rejection$reason_code, .ledgr_plan_reason_levels)
      ledgr_fold_diagnostic_segment(list(
        n = n_rejection, instrument_id = instrument_ids[rejection$pos],
        stage = "execution", outcome = "no_fill",
        reason_code = .ledgr_plan_reason_levels[rejection$primary],
        reasons = rejection_reasons$reasons,
        target = target_qty[rejection$k],
        quantity = rejection$position,
        price = rejection$resolved_price,
        decision_ts_utc = ts,
        execution_ts_utc = rejection$exec_ts,
        target_before_risk = strategy_qty[rejection$k],
        target_after_risk = target_qty[rejection$k],
        position_before = rejection$position,
        position_after = rejection$position
      ), ts)
    }, seq_len(n_rejection))
  }
  execution_offsets <- integer()
  if (n_fill > 0L) {
    event_seq <- fold_state$event_seq
    execution_offsets <- lean_plan_stage(fold_state, n_fill, function() {
      ledgr_fold_diagnostic_segment(list(
        n = n_fill, instrument_id = instrument_ids[fill$pos],
        stage = "execution", outcome = "filled",
        reason_code = fill_reasons$reason,
        reasons = fill_reasons$reasons,
        target = target_qty[fill$k],
        quantity = fill$qty,
        price = fill$price,
        decision_ts_utc = ts,
        execution_ts_utc = fill$exec_ts,
        event_seq = event_seq + seq_along(fill$k) - 1L,
        target_before_risk = strategy_qty[fill$k],
        target_after_risk = target_qty[fill$k],
        position_before = fill$position_before,
        position_after = fill$planned_position_after
      ), ts)
    }, which(!clean))
  }
  if (length(clean_rows) > 0L) {
    base <- fold_state$diagnostic_seq
    services$diagnostic_writer$append_implicit(
      ledgr_diagnostic_implicit_block(
        run_id = services$run_id,
        decision = decision_diagnostic,
        fill = fill,
        fill_rows = clean_rows,
        decision_seq = base + decision_offsets[clean_k],
        execution_seq = base + execution_offsets[clean_rows],
        event_seq = fold_state$event_seq + clean_rows - 1L,
        axis_size = length(instrument_ids)
      )
    )
  }
  if (length(clean_hold_k) > 0L) {
    base <- fold_state$diagnostic_seq
    services$diagnostic_writer$append_implicit(
      ledgr_diagnostic_implicit_hold_block(
        run_id = services$run_id,
        decision = decision_diagnostic,
        rows = clean_hold_k,
        decision_seq = base + decision_offsets[clean_hold_k],
        decision_order = as.numeric(
          (clean_hold_k - 1) * length(instrument_ids) +
            context_pos[clean_hold_k]
        )
      )
    )
  }
  list(
    batch = batch,
    sample_start = sample_start,
    t_target = t_target,
    t_fill = t_fill
  )
}

# Binds lean_stage_plan over the pinned P3 for the rest of the session;
# returns the function that restores the pin.
lean_plan_install <- function() {
  ns <- asNamespace("ledgr")
  name <- "ledgr_fold_stage_plan"
  pinned <- get(name, envir = ns)
  bind <- function(value) {
    unlockBinding(name, ns)
    assign(name, value, envir = ns)
    lockBinding(name, ns)
  }
  bind(lean_stage_plan)
  function() bind(pinned)
}
