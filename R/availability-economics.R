ledgr_availability_cash_tolerance <- 1e-8

ledgr_availability_valuation_state <- function(bars_mat,
                                                instrument_ids,
                                                pulses_posix,
                                                max_sessions,
                                                exhausted = "refuse",
                                                pulse_columns = NULL) {
  instrument_ids <- as.character(instrument_ids)
  pulses_posix <- as.POSIXct(pulses_posix, tz = "UTC")
  close <- bars_mat$close
  if (!is.matrix(close) || !is.numeric(close) ||
      nrow(close) != length(instrument_ids) ||
      ncol(close) != length(pulses_posix) ||
      anyNA(instrument_ids) || any(!nzchar(instrument_ids)) ||
      anyDuplicated(instrument_ids)) {
    rlang::abort(
      "Availability valuation state requires a numeric close matrix aligned to unique instrument IDs and pulses.",
      class = "ledgr_invalid_fold_execution"
    )
  }
  max_sessions <- as.integer(max_sessions)
  if (length(max_sessions) != 1L || is.na(max_sessions) || max_sessions < 0L) {
    rlang::abort(
      "Availability valuation state requires one non-negative stale-session limit.",
      class = "ledgr_invalid_fold_execution"
    )
  }

  if (!is.character(exhausted) || length(exhausted) != 1L ||
      !exhausted %in% ledgr_valuation_exhausted_choices()) {
    rlang::abort(
      "Availability valuation state requires one declared exhaustion choice.",
      class = "ledgr_invalid_fold_execution"
    )
  }
  freeze <- identical(exhausted, "freeze")
  if (is.null(pulse_columns)) pulse_columns <- seq_along(pulses_posix)
  pulse_columns <- as.integer(pulse_columns)
  if (anyNA(pulse_columns) || any(pulse_columns < 1L) ||
      any(pulse_columns > ncol(close)) || is.unsorted(pulse_columns, strictly = TRUE)) {
    rlang::abort(
      "Availability valuation pulse columns must be a strictly increasing subset of the prepared calendar.",
      class = "ledgr_invalid_fold_execution"
    )
  }

  n_source <- length(instrument_ids)
  row_index_builds <- 0L
  row_by_id <- stats::setNames(seq_len(n_source), instrument_ids)
  row_index_builds <- row_index_builds + 1L
  row_index_cells <- length(row_by_id)
  last_close <- rep(NA_real_, n_source)
  last_pulse <- rep(NA_integer_, n_source)
  current_pulse <- 0L
  close_cells_read <- 0
  source_index_lookups <- 0

  # `held` marks axis holdings. Under exhausted = "freeze" a held holding
  # whose last observed close is older than max_sessions keeps that close as an
  # assumption-backed frozen mark; quantity and cash are never touched here.
  advance <- function(pulse_idx, axis, held = NULL) {
    pulse_idx <- as.integer(pulse_idx)
    if (length(pulse_idx) != 1L || is.na(pulse_idx) ||
        pulse_idx < 1L || pulse_idx > length(pulse_columns)) {
      rlang::abort(
        "Availability valuation pulse is outside the prepared calendar.",
        class = "ledgr_invalid_fold_execution"
      )
    }
    if (pulse_idx < current_pulse) {
      rlang::abort(
        "Availability valuation pulses must be nondecreasing.",
        class = c(
          "ledgr_availability_valuation_out_of_order",
          "ledgr_invalid_fold_execution"
        )
      )
    }
    axis <- as.character(axis)
    source_row <- unname(row_by_id[axis])
    source_index_lookups <<- source_index_lookups + length(source_row)
    if (anyNA(axis) || any(!nzchar(axis)) || anyDuplicated(axis) || anyNA(source_row)) {
      rlang::abort(
        "Availability valuation axis must contain unique prepared instrument IDs.",
        class = "ledgr_invalid_fold_execution"
      )
    }

    target_column <- pulse_columns[[pulse_idx]]
    # Mark history starts at the data start (the first prepared column), not
    # at the first scoring pulse, so the first pulse sees the latest earlier
    # observed close and its true age (v12 Section 2).
    current_column <- if (current_pulse == 0L) {
      0L
    } else {
      pulse_columns[[current_pulse]]
    }
    if (pulse_idx > current_pulse) {
      for (j in seq.int(current_column + 1L, target_column)) {
        current_close <- as.numeric(close[, j])
        close_cells_read <<- close_cells_read + length(current_close)
        observed <- is.finite(current_close)
        last_close[observed] <<- current_close[observed]
        last_pulse[observed] <<- j
      }
      current_pulse <<- pulse_idx
    }

    reference <- stats::setNames(last_close[source_row], axis)
    source_position <- last_pulse[source_row]
    age <- stats::setNames(as.integer(target_column - source_position), axis)
    age[is.na(source_position)] <- NA_integer_
    permissible <- stats::setNames(!is.na(age) & age <= max_sessions, axis)
    mark <- reference
    mark[!permissible] <- NA_real_
    source <- rep("missing", length(axis))
    source[!is.na(age) & !permissible] <- "expired_close"
    source[permissible & age == 0L] <- "current_close"
    source[permissible & age > 0L] <- "stale_close"
    frozen <- rep(FALSE, length(axis))
    if (freeze && !is.null(held)) {
      frozen <- as.logical(held) & !permissible & !is.na(age)
      mark[frozen] <- reference[frozen]
      source[frozen] <- "frozen_close"
    }
    names(source) <- axis
    source_ts <- stats::setNames(
      as.POSIXct(rep(NA_real_, length(axis)), origin = "1970-01-01", tz = "UTC"),
      axis
    )
    has_source <- !is.na(source_position)
    source_ts[has_source] <- pulses_posix[source_position[has_source]]

    list(
      mark = mark,
      reference = reference,
      source_ts = source_ts,
      age = age,
      source = source,
      permissible = permissible,
      frozen = stats::setNames(frozen, axis),
      priced = is.finite(mark),
      source_row = stats::setNames(as.integer(source_row), axis)
    )
  }

  stats <- function() {
    list(
      source_instruments = n_source,
      current_pulse = current_pulse,
      current_column = if (current_pulse == 0L) 0L else pulse_columns[[current_pulse]],
      row_index_builds = row_index_builds,
      row_index_cells = row_index_cells,
      close_cells_read = close_cells_read,
      source_index_lookups = source_index_lookups
    )
  }

  list(advance = advance, stats = stats)
}

# The exhaustion choice declared by the current valuation policy.
ledgr_availability_exhausted_choice <- function(valuation_policy) {
  valuation_policy$exhausted
}

# A frozen holding stays on the decision axis but is target-restricted, so
# ctx$tradable() and helper allocation exclude it while hold and zero targets
# remain admissible.
ledgr_availability_restrict_frozen <- function(view, valuation) {
  frozen <- valuation$frozen
  if (is.null(frozen) || !any(frozen)) {
    return(view)
  }
  ids <- names(frozen)[frozen]
  view$target_restricted[ids] <- TRUE
  reason <- as.character(view$target_restriction_reason[ids])
  view$target_restriction_reason[ids] <- ifelse(nzchar(reason), reason, "valuation_frozen")
  reasons <- as.character(view$target_restriction_reasons[ids])
  view$target_restriction_reasons[ids] <- ifelse(
    nzchar(reasons),
    paste(reasons, "valuation_frozen", sep = "|"),
    "valuation_frozen"
  )
  view
}

# Holdings frozen at one committed pulse, rebuilt for a resume. Ledger events
# up to the pulse timestamp give the decision-time holdings after that pulse's
# dispositions, so freeze entry and exit diagnostics after the resume match an
# uninterrupted run.
ledgr_availability_frozen_at <- function(con,
                                         run_id,
                                         initial_cash,
                                         provider,
                                         bars_mat,
                                         instrument_ids,
                                         pulses_posix,
                                         pulse_idx,
                                         source_pulses_posix = pulses_posix,
                                         pulse_columns = NULL) {
  exhausted <- ledgr_availability_exhausted_choice(provider$valuation_policy)
  if (!identical(exhausted, "freeze")) return(character())
  ts <- pulses_posix[[pulse_idx]]
  state <- ledgr_state_asof(con, run_id, initial_cash, ts, instrument_ids = instrument_ids)
  positions <- stats::setNames(rep(0, length(instrument_ids)), instrument_ids)
  present <- intersect(names(state$positions), instrument_ids)
  positions[present] <- as.numeric(state$positions[present])
  view <- provider$decision_view(ts, positions)
  ids <- as.character(view$axis)
  valuation <- ledgr_availability_valuation_state(
    bars_mat,
    instrument_ids,
    source_pulses_posix,
    as.integer(provider$valuation_policy$max_sessions),
    exhausted,
    pulse_columns = pulse_columns
  )$advance(pulse_idx, ids, held = as.logical(view$held[ids]))
  ids[valuation$frozen[ids]]
}

# Diagnostic detail JSON omits values that do not exist, such as the reference
# price of a holding that never had a mark; canonical JSON rejects NA.
ledgr_availability_detail_json <- function(detail) {
  missing <- vapply(detail, function(v) {
    length(v) == 1L && (is.na(v) || (is.numeric(v) && !is.finite(v)))
  }, logical(1))
  canonical_json(detail[!missing])
}

ledgr_availability_affected_exposure <- function(ids, positions, valuation) {
  if (is.null(ids)) {
    return(list(value = NA_real_, details = list()))
  }
  ids <- ledgr_availability_stable_ids(ids)
  details <- lapply(ids, function(id) {
    quantity <- as.numeric(positions[[id]] %||% 0)
    price <- as.numeric(valuation$reference[[id]] %||% NA_real_)
    contribution <- if (quantity == 0) 0 else if (is.finite(price)) abs(quantity * price) else NA_real_
    list(
      instrument_id = id,
      quantity = quantity,
      reference_price = price,
      source_ts_utc = valuation$source_ts[[id]] %||% as.POSIXct(NA, tz = "UTC"),
      mark_age = valuation$age[[id]] %||% NA_integer_,
      mark_permissible = isTRUE(valuation$permissible[[id]]),
      contribution = contribution
    )
  })
  contributions <- vapply(details, `[[`, numeric(1), "contribution")
  value <- if (anyNA(contributions)) NA_real_ else sum(contributions)
  list(value = value, details = details)
}

ledgr_availability_marked_gross <- function(quantities, marks) {
  quantities <- as.numeric(quantities)
  marks <- as.numeric(marks)
  contributions <- ifelse(quantities == 0, 0, abs(quantities * marks))
  if (anyNA(contributions) || any(!is.finite(contributions))) NA_real_ else sum(contributions)
}

ledgr_availability_validate_strategy_targets <- function(targets, current, view) {
  ids <- names(targets)
  current <- stats::setNames(as.numeric(current[ids]), ids)
  member <- as.logical(view$member[ids])
  restricted <- as.logical(view$target_restricted[ids])
  same <- targets == current
  zero <- targets == 0
  reduced <- sign(targets) == sign(current) & abs(targets) <= abs(current)

  bad_restricted <- restricted & !(same | zero)
  if (any(bad_restricted)) {
    bad <- ids[bad_restricted]
    rlang::abort(
      sprintf("Restricted targets must hold the current quantity or be zero: %s.", paste(bad, collapse = ", ")),
      class = c("ledgr_restricted_target", "ledgr_invalid_strategy_result"),
      reason = "restricted_target",
      instrument_ids = bad
    )
  }
  bad_nonmember <- !member & !restricted & !(same | zero | reduced)
  if (any(bad_nonmember)) {
    bad <- ids[bad_nonmember]
    rlang::abort(
      sprintf("Held nonmembers may only hold, exit, or reduce existing exposure: %s.", paste(bad, collapse = ", ")),
      class = c("ledgr_nonmember_exposure_increase", "ledgr_invalid_strategy_result"),
      reason = "nonmember_exposure_increase",
      instrument_ids = bad
    )
  }
  invisible(targets)
}

ledgr_availability_validate_post_risk <- function(targets, strategy_targets) {
  zero <- targets == 0
  reduced <- sign(targets) == sign(strategy_targets) & abs(targets) <= abs(strategy_targets)
  bad <- !(zero | reduced)
  if (any(bad)) {
    ids <- names(targets)[bad]
    rlang::abort(
      sprintf("Post-risk targets may only preserve or reduce strategy exposure: %s.", paste(ids, collapse = ", ")),
      class = c("ledgr_post_risk_inadmissible", "ledgr_risk_application_error"),
      reason = "post_risk_inadmissible",
      instrument_ids = ids
    )
  }
  invisible(targets)
}

ledgr_availability_validate_short_exposure <- function(targets, current) {
  floor_qty <- pmin(as.numeric(current), 0)
  bad <- as.numeric(targets) < floor_qty
  if (any(bad)) {
    ids <- names(targets)[bad]
    rlang::abort(
      sprintf("Availability-aware execution cannot open or enlarge short exposure: %s.", paste(ids, collapse = ", ")),
      class = c("ledgr_short_exposure_unsupported", "ledgr_invalid_strategy_result"),
      reason = "short_exposure_unsupported",
      instrument_ids = ids
    )
  }
  invisible(targets)
}

ledgr_availability_fill_cash_delta <- function(fill) {
  if (identical(fill$side, "BUY")) {
    -(fill$qty * fill$fill_price + fill$fee)
  } else {
    fill$qty * fill$fill_price - fill$fee
  }
}

ledgr_availability_reason_values <- function(x) {
  x <- as.character(x %||% character())
  x <- x[!is.na(x) & nzchar(x)]
  unique(unlist(strsplit(x, "|", fixed = TRUE), use.names = FALSE))
}

ledgr_availability_reason_text <- function(x) {
  paste(ledgr_availability_reason_values(x), collapse = "|")
}

ledgr_availability_apply_affordability <- function(entries,
                                                    cash,
                                                    tolerance = ledgr_availability_cash_tolerance) {
  if (length(entries) == 0L) {
    return(list(accepted = entries, rejected = list(), final_cash = as.numeric(cash)))
  }
  cash_delta <- vapply(entries, function(x) ledgr_availability_fill_cash_delta(x$fill), numeric(1))
  blocked <- vapply(entries, function(x) {
    length(ledgr_availability_reason_values(x$blocking_reasons)) > 0L
  }, logical(1))
  generator <- vapply(entries, function(x) {
    identical(x$fill$side, "SELL") && x$current_qty > 0 && x$delta < 0
  }, logical(1)) & cash_delta >= 0 & !blocked
  stable_id <- vapply(entries, `[[`, character(1), "instrument_id")
  priority <- c(which(generator), which(!generator))
  priority <- priority[order(!generator[priority], enc2utf8(stable_id[priority]), method = "radix")]
  accepted <- rep(FALSE, length(entries))
  virtual_cash <- as.numeric(cash)
  for (idx in priority) {
    next_cash <- virtual_cash + cash_delta[[idx]]
    affordable <- cash_delta[[idx]] >= 0 || next_cash >= -tolerance
    if (!blocked[[idx]] && affordable) {
      accepted[[idx]] <- TRUE
      virtual_cash <- next_cash
    } else if (!affordable) {
      entries[[idx]]$blocking_reasons <- c(
        ledgr_availability_reason_values(entries[[idx]]$blocking_reasons),
        "insufficient_cash"
      )
    }
  }
  rejected <- entries[!accepted]
  for (i in seq_along(rejected)) {
    reasons <- c(
      ledgr_availability_reason_values(rejected[[i]]$blocking_reasons),
      ledgr_availability_reason_values(rejected[[i]]$informational_reasons)
    )
    rejected[[i]]$reason_code <- reasons[[1L]]
    rejected[[i]]$reasons <- ledgr_availability_reason_text(reasons)
  }
  list(
    accepted = entries[accepted],
    rejected = rejected,
    final_cash = virtual_cash
  )
}

ledgr_fold_build_availability_pulse_plan <- function(targets,
                                                     target_names,
                                                     target_inst_idx,
                                                     current_qty_vec,
                                                     delta_vec,
                                                     actionable_idx,
                                                     pulse_idx,
                                                     execution_opportunities_posix,
                                                     bars_mat,
                                                     cost_resolver,
                                                     ts_signal_utc,
                                                     provider,
                                                     decision_member,
                                                     cash,
                                                     next_bars = NULL) {
  # Accepted and rejected entries are written by index into lists sized for
  # every actionable target, then trimmed.
  entries <- vector("list", length(actionable_idx))
  n_entries <- 0L
  rejected <- vector("list", length(actionable_idx))
  n_rejected <- 0L
  execution_ts <- if (pulse_idx <= length(execution_opportunities_posix)) {
    as.POSIXct(execution_opportunities_posix[[pulse_idx]], tz = "UTC")
  } else {
    as.POSIXct(NA, tz = "UTC")
  }
  # One execution view per pulse for every actionable ID; each ID resolves
  # independently, so it equals one view per target.
  execution_view <- if (!is.na(execution_ts) && length(actionable_idx) > 0L) {
    provider$execution_view(execution_ts, target_names[actionable_idx])
  }
  if (is.null(next_bars) && !is.null(bars_mat) &&
      pulse_idx < ncol(bars_mat$open)) {
    next_bars <- list(
      open = as.numeric(bars_mat$open[, pulse_idx + 1L]),
      high = as.numeric(bars_mat$high[, pulse_idx + 1L]),
      low = as.numeric(bars_mat$low[, pulse_idx + 1L]),
      close = as.numeric(bars_mat$close[, pulse_idx + 1L]),
      volume = as.numeric(bars_mat$volume[, pulse_idx + 1L])
    )
  }

  for (target_idx in actionable_idx) {
    id <- target_names[[target_idx]]
    inst_idx <- target_inst_idx[[target_idx]]
    current_qty <- as.numeric(current_qty_vec[[target_idx]])
    delta <- as.numeric(delta_vec[[target_idx]])
    reject <- function(blocking_reasons, informational_reasons = character()) {
      reasons <- c(
        ledgr_availability_reason_values(blocking_reasons),
        ledgr_availability_reason_values(informational_reasons)
      )
      n_rejected <<- n_rejected + 1L
      rejected[[n_rejected]] <<- list(
        target_idx = as.integer(target_idx),
        instrument_id = id,
        inst_idx = as.integer(inst_idx),
        current_qty = current_qty,
        delta = delta,
        reason_code = reasons[[1L]],
        reasons = ledgr_availability_reason_text(reasons),
        execution_ts_utc = execution_ts
      )
    }

    if (is.na(execution_ts)) {
      reject("final_pulse_no_execution")
      next
    }
    blocking_reasons <- if (isTRUE(execution_view$restricted[[id]])) {
      ledgr_availability_reason_values(execution_view$reasons[[id]])
    } else {
      character()
    }
    informational_reasons <- if (!identical(
      isTRUE(decision_member[[id]]),
      isTRUE(execution_view$member[[id]])
    )) "membership_changed_before_execution" else character()
    open <- if (is.null(next_bars)) NA_real_ else next_bars$open[[inst_idx]]
    if (!is.finite(open) || open <= 0) {
      reject(c(blocking_reasons, "execution_bar_missing"), informational_reasons)
      next
    }
    proposal <- ledgr_next_open_fill_proposal(
      desired_qty_delta = delta,
      next_open_price = open,
      instrument_id = id,
      ts_utc = execution_ts,
      high = next_bars$high[[inst_idx]],
      low = next_bars$low[[inst_idx]],
      close = next_bars$close[[inst_idx]],
      volume = next_bars$volume[[inst_idx]]
    )
    fill <- ledgr_resolve_fill_proposal(proposal, cost_resolver)
    if (inherits(fill, "ledgr_fill_none") || !is.finite(fill$fill_price) || fill$fill_price <= 0) {
      reject(c(blocking_reasons, "execution_bar_missing"), informational_reasons)
      next
    }
    signed_qty <- if (identical(fill$side, "BUY")) fill$qty else -fill$qty
    resulting_qty <- current_qty + signed_qty
    ledgr_availability_validate_short_exposure(
      stats::setNames(resulting_qty, id),
      stats::setNames(current_qty, id)
    )
    fill$instrument_id <- id
    fill$ts_signal_utc <- ts_signal_utc
    fill$inst_idx <- inst_idx
    n_entries <- n_entries + 1L
    entries[[n_entries]] <- list(
      target_idx = as.integer(target_idx),
      instrument_id = id,
      inst_idx = as.integer(inst_idx),
      current_qty = current_qty,
      delta = delta,
      resulting_qty = resulting_qty,
      fill = fill,
      blocking_reasons = blocking_reasons,
      informational_reasons = informational_reasons,
      execution_ts_utc = execution_ts
    )
  }

  affordability <- ledgr_availability_apply_affordability(entries[seq_len(n_entries)], cash)
  rejected <- c(rejected[seq_len(n_rejected)], affordability$rejected)
  accepted_ids <- vapply(affordability$accepted, `[[`, integer(1), "target_idx")
  accepted <- affordability$accepted[order(accepted_ids)]
  structure(
    list(
      targets = targets,
      actionable_idx = as.integer(actionable_idx),
      fills = accepted,
      rejected = rejected,
      expected_final_cash = affordability$final_cash,
      economic_event_kinds = if (length(accepted) > 0L) "FILL" else character()
    ),
    class = c("ledgr_pulse_plan", "list")
  )
}

ledgr_availability_completion_row <- function(run_id,
                                              pulses_posix,
                                              status,
                                              stop_reason,
                                              affected,
                                              last_fully_valued_ts_utc,
                                              last_executed_ts_utc) {
  valued <- as.POSIXct(last_fully_valued_ts_utc, tz = "UTC")
  achieved_start <- if (length(valued) == 1L && !is.na(valued)) {
    as.POSIXct(pulses_posix[[1L]], tz = "UTC")
  } else {
    as.POSIXct(NA, tz = "UTC")
  }
  data.frame(
    run_id = run_id,
    intended_start_utc = as.POSIXct(pulses_posix[[1L]], tz = "UTC"),
    intended_end_utc = as.POSIXct(utils::tail(pulses_posix, 1L), tz = "UTC"),
    achieved_start_utc = achieved_start,
    achieved_end_utc = valued,
    intended_terminal_status = status,
    stop_reason = if (identical(status, "DONE")) NA_character_ else stop_reason,
    affected_exposure = as.numeric(affected$value %||% NA_real_),
    affected_exposure_ts_utc = as.POSIXct(affected$ts_utc %||% NA, tz = "UTC"),
    affected_exposure_basis = if (
      identical(status, "DONE") || !isTRUE(affected$specified)
    ) NA_character_ else "last_accepted_close_gross",
    last_fully_valued_ts_utc = valued,
    last_executed_ts_utc = as.POSIXct(last_executed_ts_utc, tz = "UTC"),
    complete_performance = identical(status, "DONE"),
    stringsAsFactors = FALSE
  )
}

ledgr_completion_record <- function(completion) {
  if (is.null(completion) || !is.data.frame(completion) || nrow(completion) != 1L) {
    return(NULL)
  }
  time_value <- function(name) {
    value <- completion[[name]][[1L]]
    if (is.na(value)) NULL else ledgr_normalize_ts_utc(value)
  }
  scalar <- function(name) {
    value <- completion[[name]][[1L]]
    if (length(value) != 1L || is.na(value)) NULL else value
  }
  list(
    intended_start_utc = time_value("intended_start_utc"),
    intended_end_utc = time_value("intended_end_utc"),
    achieved_start_utc = time_value("achieved_start_utc"),
    achieved_end_utc = time_value("achieved_end_utc"),
    intended_terminal_status = as.character(completion$intended_terminal_status[[1L]]),
    stop_reason = scalar("stop_reason"),
    affected_exposure = scalar("affected_exposure"),
    affected_exposure_ts_utc = time_value("affected_exposure_ts_utc"),
    affected_exposure_basis = scalar("affected_exposure_basis"),
    last_fully_valued_ts_utc = time_value("last_fully_valued_ts_utc"),
    last_executed_ts_utc = time_value("last_executed_ts_utc"),
    complete_performance = isTRUE(completion$complete_performance[[1L]])
  )
}

# Selection surfaces store the completion record with two optional
# extensions: the stopped instrument IDs and the compact assumption flags.
ledgr_completion_json <- function(completion,
                                  affected_instrument_ids = NULL,
                                  assumptions = NULL) {
  record <- ledgr_completion_record(completion)
  if (is.null(record)) return(NA_character_)
  if (length(affected_instrument_ids) > 0L) {
    record$affected_instrument_ids <- as.list(as.character(affected_instrument_ids))
  }
  if (!is.null(assumptions)) {
    record$assumptions <- assumptions
  }
  as.character(canonical_json(record))
}

ledgr_stopped_instrument_ids <- function(diagnostics) {
  if (is.null(diagnostics) || nrow(diagnostics) == 0L) return(character())
  ids <- as.character(diagnostics$instrument_id[diagnostics$outcome %in% "stopped"])
  unique(ids[!is.na(ids) & nzchar(ids)])
}

ledgr_availability_diagnostic_row <- function(run_id,
                                              diagnostic_seq,
                                              ts_utc,
                                              instrument_id = "",
                                              stage,
                                              outcome,
                                              reason_code = "",
                                              reasons = reason_code,
                                              target = NA_real_,
                                              quantity = NA_real_,
                                              price = NA_real_,
                                              mark_source = "",
                                              mark_age = NA_integer_,
                                              decision_ts_utc = ts_utc,
                                              execution_ts_utc = as.POSIXct(NA, tz = "UTC"),
                                              event_seq = NA_integer_,
                                              target_before_risk = NA_real_,
                                              target_after_risk = NA_real_,
                                              position_before = NA_real_,
                                              position_after = NA_real_,
                                              feature_identity_json = NA_character_,
                                              detail_json = "{}") {
  data.frame(
    run_id = as.character(run_id),
    diagnostic_seq = as.integer(diagnostic_seq),
    ts_utc = as.POSIXct(ts_utc, tz = "UTC"),
    instrument_id = as.character(instrument_id),
    stage = as.character(stage),
    outcome = as.character(outcome),
    reason_code = as.character(reason_code),
    reasons = as.character(reasons),
    target = as.numeric(target),
    quantity = as.numeric(quantity),
    price = as.numeric(price),
    mark_source = as.character(mark_source),
    mark_age = as.integer(mark_age),
    decision_ts_utc = as.POSIXct(decision_ts_utc, tz = "UTC"),
    execution_ts_utc = as.POSIXct(execution_ts_utc, tz = "UTC"),
    event_seq = as.integer(event_seq),
    target_before_risk = as.numeric(target_before_risk),
    target_after_risk = as.numeric(target_after_risk),
    position_before = as.numeric(position_before),
    position_after = as.numeric(position_after),
    feature_identity_json = as.character(feature_identity_json),
    detail_json = as.character(detail_json),
    stringsAsFactors = FALSE
  )
}
