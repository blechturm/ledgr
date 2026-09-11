ledgr_availability_cash_tolerance <- 1e-8

ledgr_availability_valuation_marks <- function(bars_mat,
                                                instrument_ids,
                                                axis,
                                                pulse_idx,
                                                pulses_posix,
                                                max_sessions) {
  n <- length(axis)
  reference <- mark <- stats::setNames(rep(NA_real_, n), axis)
  source_ts <- stats::setNames(as.POSIXct(rep(NA_character_, n), tz = "UTC"), axis)
  age <- stats::setNames(rep(NA_integer_, n), axis)
  source <- stats::setNames(rep("missing", n), axis)
  permissible <- stats::setNames(rep(FALSE, n), axis)

  for (id in axis) {
    row <- match(id, instrument_ids)
    observed <- which(is.finite(bars_mat$close[row, seq_len(pulse_idx)]))
    if (length(observed) == 0L) next
    last <- utils::tail(observed, 1L)
    reference[[id]] <- as.numeric(bars_mat$close[row, last])
    source_ts[[id]] <- as.POSIXct(pulses_posix[[last]], tz = "UTC")
    age[[id]] <- as.integer(pulse_idx - last)
    permissible[[id]] <- age[[id]] <= as.integer(max_sessions)
    if (isTRUE(permissible[[id]])) {
      mark[[id]] <- reference[[id]]
      source[[id]] <- if (age[[id]] == 0L) "current_close" else "stale_close"
    } else {
      source[[id]] <- "expired_close"
    }
  }

  list(
    mark = mark,
    reference = reference,
    source_ts = source_ts,
    age = age,
    source = source,
    permissible = permissible,
    priced = is.finite(mark)
  )
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
                                                     pulses_posix,
                                                     bars_mat,
                                                     cost_resolver,
                                                     ts_signal_utc,
                                                     provider,
                                                     decision_member,
                                                     cash) {
  entries <- list()
  rejected <- list()
  execution_ts <- if (pulse_idx < length(pulses_posix)) {
    as.POSIXct(pulses_posix[[pulse_idx + 1L]], tz = "UTC")
  } else {
    as.POSIXct(NA, tz = "UTC")
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
      rejected[[length(rejected) + 1L]] <<- list(
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
    execution_view <- provider$execution_view(execution_ts, id)
    blocking_reasons <- if (isTRUE(execution_view$restricted[[id]])) {
      ledgr_availability_reason_values(execution_view$reasons[[id]])
    } else {
      character()
    }
    informational_reasons <- if (!identical(
      isTRUE(decision_member[[id]]),
      isTRUE(execution_view$member[[id]])
    )) "membership_changed_before_execution" else character()
    open <- bars_mat$open[inst_idx, pulse_idx + 1L]
    if (!is.finite(open) || open <= 0) {
      reject(c(blocking_reasons, "execution_bar_missing"), informational_reasons)
      next
    }
    proposal <- ledgr_next_open_fill_proposal(
      desired_qty_delta = delta,
      next_open_price = open,
      instrument_id = id,
      ts_utc = execution_ts,
      high = bars_mat$high[inst_idx, pulse_idx + 1L],
      low = bars_mat$low[inst_idx, pulse_idx + 1L],
      close = bars_mat$close[inst_idx, pulse_idx + 1L],
      volume = bars_mat$volume[inst_idx, pulse_idx + 1L]
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
    entries[[length(entries) + 1L]] <- list(
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

  affordability <- ledgr_availability_apply_affordability(entries, cash)
  rejected <- c(rejected, affordability$rejected)
  accepted_ids <- vapply(affordability$accepted, `[[`, integer(1), "target_idx")
  accepted <- affordability$accepted[order(accepted_ids)]
  structure(
    list(
      targets = targets,
      actionable_idx = as.integer(actionable_idx),
      fills = accepted,
      rejected = rejected,
      expected_final_cash = affordability$final_cash
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

ledgr_completion_json <- function(completion) {
  record <- ledgr_completion_record(completion)
  if (is.null(record)) NA_character_ else as.character(canonical_json(record))
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
