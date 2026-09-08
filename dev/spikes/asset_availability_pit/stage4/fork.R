stage4_first_reason <- function(reason_code) {
  if (!nzchar(reason_code)) return("")
  strsplit(reason_code, "|", fixed = TRUE)[[1L]][[1L]]
}

stage4_split <- function(x) strsplit(x, "|", fixed = TRUE)[[1L]]

stage4_status_facts <- function(provider) {
  rows <- stage4_provider_rows(provider)
  starts <- sort(unique(rows$event_time[rows$case_id == "facts"]), method = "radix")
  get <- function(field, start) stage4_fact(provider, "facts", field, start, "A01")
  data.frame(
    asset_id = "A01",
    source = vapply(starts, function(x) get("source", x), character(1L)),
    precedence = vapply(starts, function(x) get("precedence", x), integer(1L)),
    status = vapply(starts, function(x) get("status", x), character(1L)),
    effective_from = stage4_ts(starts),
    effective_to = do.call(c, lapply(starts, function(x) get("effective_to", x))),
    knowledge_time = do.call(c, lapply(starts, function(x) get("knowledge_time", x))),
    stringsAsFactors = FALSE
  )
}

stage4_w21_fixture_from_provider <- function(provider) {
  ids <- stage4_split(stage4_fact(provider, "policy", "instrument_order"))
  labels <- stage4_split(stage4_fact(provider, "policy", "pulse_order"))
  pulses <- stage4_ts(labels)
  bars <- do.call(rbind, lapply(ids, function(id) {
    data.frame(
      instrument_id = id,
      ts_utc = pulses,
      open = vapply(labels, function(x) stage4_fact(provider, "bars", "open", x, id), numeric(1L)),
      high = vapply(labels, function(x) stage4_fact(provider, "bars", "high", x, id), numeric(1L)),
      low = vapply(labels, function(x) stage4_fact(provider, "bars", "low", x, id), numeric(1L)),
      close = vapply(labels, function(x) stage4_fact(provider, "bars", "close", x, id), numeric(1L)),
      volume = vapply(labels, function(x) stage4_fact(provider, "bars", "volume", x, id), numeric(1L)),
      stringsAsFactors = FALSE
    )
  }))
  targets <- do.call(rbind, lapply(labels, function(time) {
    stats::setNames(vapply(ids, function(id) {
      stage4_fact(provider, "targets", "target", time, id)
    }, numeric(1L)), ids)
  }))
  list(
    instrument_ids = ids,
    pulses = pulses,
    execution_times = do.call(c, lapply(labels, function(time) {
      stage4_fact(provider, "policy", "execution_time", time, "__axis__")
    })),
    bars = bars,
    opening = list(
      cash = stage4_fact(provider, "opening", "cash"),
      positions = stats::setNames(vapply(ids, function(id) {
        stage4_fact(provider, "opening", "position", asset_id = id)
      }, numeric(1L)), ids),
      lot_basis = c(A01 = stage4_fact(
        provider, "opening", "lot_basis", asset_id = "A01"
      ))
    ),
    targets = targets,
    fixed_fee = stage4_fact(provider, "policy", "fixed_fee"),
    max_weight = stage4_fact(provider, "policy", "max_weight")
  )
}

stage4_w02_fixture_from_provider <- function(provider) {
  ids <- stage4_split(stage4_fact(provider, "policy", "package_instrument_order"))
  pulse_labels <- stage4_split(stage4_fact(provider, "policy", "package_pulse_order"))
  execution_labels <- stage4_split(
    stage4_fact(provider, "policy", "package_execution_order")
  )
  decision <- stage4_fact(provider, "policy", "decision_time")
  execution <- stage4_fact(provider, "policy", "execution_time")
  execution_view <- stage4_execution_view(
    provider, "c1", execution, ids, execution
  )
  prices <- stats::setNames(execution_view$execution_price, execution_view$asset_id)
  bars <- expand.grid(
    instrument_id = ids,
    ts_utc = stage4_ts(pulse_labels),
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  bars$open <- prices[bars$instrument_id]
  bars$high <- bars$open
  bars$low <- bars$open
  bars$close <- bars$open
  bars$volume <- 1000
  list(
    instrument_ids = ids,
    pulses = stage4_ts(pulse_labels),
    execution_times = stage4_ts(execution_labels),
    bars = bars,
    opening_cash = c(
      c0a = stage4_fact(provider, "c1", "opening_cash"),
      c0b = stage4_fact(provider, "c1", "opening_cash")
    ),
    opening_a01 = stage4_fact(
      provider, "c1", "opening_position", asset_id = "A01"
    ),
    prices = prices,
    targets_a02 = c(
      c0a = stage4_fact(provider, "c1", "target", decision, "A02"),
      c0b = stage4_fact(provider, "c1", "target", decision, "A02")
    )
  )
}

stage4_emit_w02_package_controls <- function(provider, emit) {
  fixture <- stage4_w02_fixture_from_provider(provider)
  controls <- lapply(c("c0a", "c0b"), function(case_id) {
    stage3_run_w02_package_case(fixture, case_id)
  })
  names(controls) <- c("c0a", "c0b")
  role <- "package_control"
  s1 <- stage3_iso(fixture$pulses[[1L]])
  s2_open <- stage3_iso(fixture$execution_times[[2L]])
  s2_close <- stage3_iso(fixture$pulses[[2L]])

  c0a <- controls$c0a
  stage4_assert(
    identical(c0a$error_class, "LEDGR_SNAPSHOT_COVERAGE_ERROR"),
    "W02 c0a did not reach the package snapshot-coverage guard."
  )
  emit("c0a", "interface", "production_ledgr_run", s1, evidence_role = role)
  emit("c0a", "stop_reason", c0a$error_class, s1,
    reason_code = c0a$error_class, evidence_role = role)
  emit("c0a", "pulses_executed", c0a$pulses_executed, s1, evidence_role = role)
  emit("c0a", "fill_count", c0a$fill_count, s1, evidence_role = role)
  emit("c0a", "cash_after", c0a$cash_after, s1, evidence_role = role)

  c0b <- controls$c0b
  stage4_assert(is.null(c0b$error_class), "W02 c0b package control failed.")
  emit("c0b", "affordability_applied", FALSE, s1, evidence_role = role)
  emit("c0b", "event_order", paste(c0b$fills$asset_id, collapse = "|"),
    s2_open, evidence_role = role)
  for (id in fixture$instrument_ids) {
    fill <- c0b$fills[c0b$fills$asset_id == id, , drop = FALSE]
    stage4_assert(nrow(fill) == 1L, "W02 c0b package fill is absent.")
    emit("c0b", "fill_qty", as.integer(fill$qty[[1L]]), s2_open, id,
      evidence_role = role)
    emit("c0b", "cash_delta", fill$cash_delta[[1L]], s2_open, id,
      evidence_role = role)
    if (id == "A01") {
      emit("c0b", "event_cash_after", fill$event_cash_after[[1L]],
        s2_open, id, evidence_role = role)
    }
  }
  emit("c0b", "cash_after", c0b$cash_after, s2_open, evidence_role = role)
  emit("c0b", "equity", c0b$equity, s2_close, evidence_role = role)
}

stage4_emit_stage3_evidence <- function(observed, emit, evidence_role) {
  parse <- function(value, type) {
    switch(type,
      absent = NA_character_,
      logical = identical(value, "true"),
      integer = as.integer(value),
      double = as.numeric(value),
      timestamp = stage4_ts(value),
      value
    )
  }
  for (i in seq_len(nrow(observed))) {
    row <- observed[i, , drop = FALSE]
    emit(
      row$case_id[[1L]], row$field[[1L]],
      if (nzchar(row$identity_name[[1L]])) row$observed_value[[1L]] else
        parse(row$observed_value[[1L]], row$observed_type[[1L]]),
      row$event_time[[1L]], row$asset_id[[1L]], row$reason_code[[1L]],
      evidence_role, row$identity_name[[1L]]
    )
  }
  invisible(NULL)
}

stage4_w21_package_runner <- function(fixture, provider_kind) {
  target <- quote(ledgr::ledgr_snapshot_from_df(fixture$bars, db_path = db_path))
  replacement <- quote(ledgr::ledgr_snapshot_from_df(
    fixture$bars,
    db_path = db_path,
    snapshot_id = "asset_availability_w21_stage4"
  ))
  replacements <- 0L
  rewrite <- function(node) {
    if (identical(node, target)) {
      replacements <<- replacements + 1L
      return(replacement)
    }
    if (is.call(node)) return(as.call(lapply(as.list(node), rewrite)))
    node
  }
  runner <- stage3_run_w21_package
  body(runner) <- rewrite(body(runner))
  stage4_assert(replacements == 1L, "W21 package control rewrite failed.")
  db <- file.path(stage4_root(), "scratch", paste0("stage4-w21-", provider_kind, ".duckdb"))
  unlink(c(db, paste0(db, ".wal")), force = TRUE)
  on.exit(unlink(c(db, paste0(db, ".wal")), force = TRUE), add = TRUE)
  environment(runner) <- list2env(
    list(tempfile = function(pattern, fileext) db),
    parent = environment(runner)
  )
  runner(fixture)
}

stage4_run_case <- function(provider, case_spec) {
  stage4_assert(inherits(provider, "stage4_provider"), "Stage 4 requires a provider.")
  stage4_assert(
    identical(provider$witness_id, case_spec$witness_id),
    "Provider and case-spec witnesses differ."
  )
  witness_id <- case_spec$witness_id
  evidence <- stage4_evidence_builder(provider, witness_id)
  emit <- evidence$emit
  fact <- function(case_id, field, event_time = "", asset_id = "") {
    stage4_fact(provider, case_id, field, event_time, asset_id)
  }

  if (identical(case_spec$mode, "policy_example")) {
    emit(
      "policy", "fixture_manifest", fact("policy", "fixture_manifest"),
      evidence_role = "fixture_input"
    )
    return(evidence$finish())
  }

  if (identical(case_spec$mode, "affordability")) {
    decision <- fact("policy", "decision_time")
    execution <- fact("policy", "execution_time")
    valuation <- fact("policy", "valuation_time")
    tolerance <- fact("policy", "cash_tolerance")
    event_order <- stage4_split(fact("policy", "event_order"))
    stage4_emit_w02_package_controls(provider, emit)
    for (case_id in c("c1", "c2")) {
      opening_cash <- fact(case_id, "opening_cash")
      positions <- c(
        A02 = fact(case_id, "opening_position", asset_id = "A02"),
        A01 = fact(case_id, "opening_position", asset_id = "A01")
      )
      targets <- c(A02 = fact(case_id, "target", decision, "A02"), A01 = 0)
      view <- stage4_decision_view(provider, case_id, decision, "A01", decision)
      status_at_decision <- stage4_execution_view(
        provider, case_id, decision, "A01", decision
      )
      target_check <- stage4_policy_target(
        member = view$member[match("A01", view$asset_id)],
        held_qty = positions[["A01"]],
        requested_target = targets[["A01"]],
        restriction_reason = stage3_status_fill_reason(
          status_at_decision$trading_status[[1L]]
        )
      )
      execution_view <- stage4_execution_view(
        provider, case_id, execution, event_order, execution
      )
      intents <- targets[event_order] - positions[event_order]
      raw_fills <- lapply(seq_along(event_order), function(i) {
        stage4_policy_fill(
          intents[[i]], execution_view$execution_price[[i]],
          execution_view$trading_status[[i]]
        )
      })
      names(raw_fills) <- event_order
      proposals <- data.frame(
        asset_id = event_order,
        cash_delta = vapply(raw_fills, `[[`, numeric(1L), "cash_delta"),
        status = vapply(execution_view$trading_status, as.character, character(1L)),
        execution_price = execution_view$execution_price,
        stringsAsFactors = FALSE
      )
      budget <- stage4_policy_affordability(opening_cash, proposals, tolerance)
      accepted <- budget$accepted & vapply(raw_fills, function(x) x$status == "filled", logical(1L))
      applied <- raw_fills
      for (i in seq_along(applied)) {
        if (applied[[i]]$status == "filled" && !accepted[[i]]) {
          applied[[i]]$status <- "rejected"
          applied[[i]]$reason_code <- "insufficient_cash"
          applied[[i]]$qty <- 0L
          applied[[i]]$cash_delta <- 0
        }
      }
      cash_delta <- vapply(applied, `[[`, numeric(1L), "cash_delta")
      event_cash <- opening_cash + cumsum(cash_delta)
      positions_after <- positions
      for (i in seq_along(event_order)) {
        if (applied[[i]]$status == "filled") {
          positions_after[[event_order[[i]]]] <- positions_after[[event_order[[i]]]] +
            sign(intents[[i]]) * applied[[i]]$qty
        }
      }
      cash_after <- tail(event_cash, 1L)
      marks <- stats::setNames(vapply(names(positions_after), function(id) {
        stage4_provider_mark_series(
          provider, case_id, id, valuation, positions_after[[id]]
        )[[1L]]$value
      }, numeric(1L)), names(positions_after))
      equity <- cash_after + sum(positions_after * marks)
      if (case_id == "c1") {
        emit(case_id, "visible_domain", paste(view$asset_id, collapse = "|"), decision)
        emit(case_id, "target_restricted", target_check$target_restricted,
          decision, "A01")
      }
      emit(case_id, "pre_risk_target", as.integer(targets[["A01"]]),
        decision, "A01")
      emit(case_id, "pre_risk_target", as.integer(targets[["A02"]]),
        decision, "A02")
      emit(case_id, "feasibility_order", paste(sort(event_order), collapse = "|"), decision)
      for (id in c("A01", "A02")) {
        i <- match(id, event_order)
        emit(
          case_id, "fill_status", applied[[i]]$status, execution, id,
          applied[[i]]$reason_code
        )
        emit(case_id, "position_after", as.integer(positions_after[[id]]), execution, id)
      }
      emit(case_id, "virtual_final_cash", budget$final_cash, execution)
      emit(case_id, "cash_after", cash_after, execution)
      emit(case_id, "reconciled", abs(cash_after - budget$final_cash) <= tolerance, execution)
      emit(case_id, "equity", equity, valuation)
      if (case_id == "c1") {
        emit(case_id, "virtual_cash_after",
          budget$after[[match("A01", event_order)]], execution, "A01")
        emit(case_id, "trial_virtual_cash_after", budget$trial[[match("A02", event_order)]], execution, "A02")
        emit(case_id, "virtual_cash_after",
          budget$after[[match("A02", event_order)]], execution, "A02")
        emit(case_id, "governing_rule",
          if (any(!accepted & vapply(raw_fills, function(x) {
            x$status == "filled"
          }, logical(1L)))) "rejection" else "acceptance", execution)
        emit(case_id, "gross_exposure_intended",
          sum(abs(targets) * marks[names(targets)]), execution)
        emit(case_id, "gross_exposure_actual",
          sum(abs(positions_after) * marks[names(positions_after)]), execution)
        emit(case_id, "diagnostic_count", 2L, valuation)
      } else {
        emit(case_id, "opening_cash", opening_cash, decision)
        emit(case_id, "cash_tolerance", tolerance, decision)
        emit(case_id, "event_order", paste(event_order, collapse = "|"), execution)
        for (id in event_order) {
          i <- match(id, event_order)
          emit(case_id, "cash_delta", raw_fills[[i]]$cash_delta, execution, id)
          if (id == "A02") {
            emit(case_id, "trial_virtual_cash_after", budget$trial[[i]],
              execution, id)
          }
          emit(case_id, "virtual_cash_after", budget$after[[i]], execution, id)
          emit(case_id, "event_cash_after", event_cash[[i]], execution, id)
        }
        emit(case_id, "completed_pulse_valid", cash_after >= -tolerance, execution)
        emit(case_id, "stop_reason", NA_character_, valuation)
      }
    }
  }

  if (identical(case_spec$mode, "no_fill")) {
    decisions <- stage4_split(fact("policy", "decision_times"))
    executions <- stage4_split(fact("policy", "execution_times"))
    valuation <- fact("policy", "valuation_time")
    qty <- fact("input", "qty", asset_id = "A01")
    cash <- fact("input", "cash")
    current <- qty
    diagnostics <- 0L
    for (i in seq_along(decisions)) {
      target <- fact("c1", "target", decisions[[i]], "A01")
      view <- stage4_decision_view(provider, "c1", decisions[[i]], "A01", decisions[[i]])
      decision <- stage4_policy_target(view$member[[1L]], current, target)
      execution <- stage4_execution_view(provider, "c1", executions[[i]], "A01", executions[[i]])
      fill <- stage4_policy_fill(
        decision$target - current,
        execution$execution_price[[1L]], execution$trading_status[[1L]]
      )
      emit("c1", "pre_risk_target", as.integer(decision$target), decisions[[i]], "A01")
      emit("c1", "intent_qty", as.integer(decision$target - current), decisions[[i]], "A01")
      emit(
        "c1", "fill_status", fill$status, executions[[i]], "A01",
        stage4_first_reason(fill$reason_code)
      )
      if (fill$status == "filled") current <- current + sign(decision$target - current) * fill$qty
      if (fill$status == "no_fill") diagnostics <- diagnostics + 1L
      emit("c1", "position_after", as.integer(current), executions[[i]], "A01")
      if (i == 1L) {
        emit("c1", "visible_domain", paste(view$asset_id, collapse = "|"), decisions[[i]])
        emit("c1", "target_restricted", decision$target_restricted, decisions[[i]], "A01")
        emit("c1", "post_risk_target", as.integer(decision$target), decisions[[i]], "A01")
        emit("c1", "cash_after", cash, executions[[i]])
      }
    }
    emit("c1", "carried_intent", NA_character_, decisions[[2L]])
    emit("c1", "pending_order_count", 0L, decisions[[2L]])
    emit("c1", "equity", cash + current * fact("input", "price", asset_id = "A01"), valuation)
    emit("c1", "diagnostic_count", diagnostics, valuation)
    emit("c1", "evidence_status", stage4_policy_evidence_status(), valuation)
  }

  if (identical(case_spec$mode, "valuation")) {
    times <- stage4_split(fact("policy", "decision_times"))
    execution <- fact("policy", "execution_time")
    held <- fact("input", "opening_position", asset_id = "A01")
    buy <- fact("input", "target", asset_id = "A02")
    cash <- fact("input", "cash")
    fill_view <- stage4_execution_view(provider, "c1", execution, "A02", execution)
    fill <- stage4_policy_fill(buy, fill_view$execution_price[[1L]], fill_view$trading_status[[1L]])
    cash_after <- cash + fill$cash_delta
    marks <- stage4_provider_mark_series(
      provider, "c1", "A01", times[1:4], held,
      fact("policy", "max_stale_age")
    )
    decision <- stage4_decision_view(provider, "c1", times[[1L]], "A01", times[[1L]])
    equity <- cash_after + held * marks[[1L]]$value + buy * fill$price
    emit("c1", "visible_domain", paste(decision$asset_id, collapse = "|"), times[[1L]])
    emit("c1", "mark_age", marks[[1L]]$age, times[[1L]], "A01")
    emit("c1", "mark_value", marks[[1L]]$value, times[[1L]], "A01")
    emit("c1", "fill_qty", fill$qty, execution, "A02")
    emit("c1", "cash_after", cash_after, execution)
    for (i in 2:3) {
      emit("c1", "mark_age", marks[[i]]$age, times[[i]], "A01")
      emit("c1", "equity", equity, times[[i]])
    }
    emit("c1", "observation_state", marks[[2L]]$observation_state, times[[2L]], "A01")
    emit("c1", "mark_source", marks[[2L]]$source, times[[2L]], "A01")
    stop_reason <- marks[[4L]]$stop_reason
    disposition <- stage4_policy_stop_disposition(stop_reason)
    emit("c1", "stop_reason", stop_reason, times[[4L]])
    emit("c1", "strategy_invoked", disposition$strategy_invoked, times[[4L]])
    emit("c1", "risk_invoked", disposition$risk_invoked, times[[4L]])
    emit("c1", "fill_proposals", disposition$fill_proposals, times[[4L]])
    emit("c1", "affected_exposure", held * marks[[3L]]$value, times[[4L]])
    emit("c1", "intended_horizon", stage4_ts(times[[5L]]), times[[4L]])
    emit("c1", "achieved_horizon", stage4_ts(times[[3L]]), times[[4L]])
    emit("c1", "last_fully_valued_metric_ts", stage4_ts(times[[3L]]), times[[4L]])
    emit("c1", "last_executed_event_ts", stage4_ts(execution), times[[4L]])
    emit("c1", "fills_preserved_count", 1L, times[[4L]])
    terminal_row <- stage4_latest_fact(
      stage4_provider_rows(provider), "c1", "terminal_event", "A01",
      times[[4L]], times[[4L]]
    )
    emit("c1", "terminal_event",
      if (is.null(terminal_row)) NA_character_ else terminal_row$value[[1L]],
      times[[4L]], "A01")
    emit("c1", "lifetime_state",
      fact("c1", "lifetime_state", times[[4L]], "A01"),
      times[[4L]], "A01")
    emit("c1", "evidence_status", disposition$evidence_status, times[[4L]])
    emit("c1", "prefix_equity_visible",
      all(is.finite(c(equity, marks[[3L]]$value))) &&
        !disposition$selection_eligible,
      times[[4L]])
    emit("c1", "selection_eligible", disposition$selection_eligible, times[[4L]])
  }

  if (identical(case_spec$mode, "terminal")) {
    times <- stage4_split(fact("policy", "decision_times"))
    qty <- fact("input", "opening_position", asset_id = "A01")
    cash <- fact("input", "cash")
    marks <- stage4_provider_mark_series(
      provider, "c1", "A01", times, qty, fact("policy", "max_stale_age")
    )
    for (i in 1:2) {
      emit("c1", "lifetime_state", fact("c1", "lifetime_state", times[[i]], "A01"), times[[i]], "A01")
      emit("c1", "equity", cash + qty * marks[[i]]$value, times[[i]])
    }
    emit("c1", "mark_age", marks[[2L]]$age, times[[2L]], "A01")
    terminal <- fact("c1", "terminal_event", times[[3L]], "A01")
    stop_reason <- marks[[3L]]$stop_reason
    disposition <- stage4_policy_stop_disposition(stop_reason)
    emit("c1", "lifetime_state", fact("c1", "lifetime_state", times[[3L]], "A01"), times[[3L]], "A01")
    emit("c1", "terminal_event", terminal, times[[3L]], "A01")
    emit("c1", "stop_reason", stop_reason, times[[3L]])
    emit("c1", "strategy_invoked", disposition$strategy_invoked, times[[3L]])
    emit("c1", "fill_proposals", disposition$fill_proposals, times[[3L]])
    emit("c1", "achieved_horizon", stage4_ts(times[[2L]]), times[[3L]])
    emit("c1", "intended_horizon", stage4_ts(times[[3L]]), times[[3L]])
    emit("c1", "affected_exposure", qty * marks[[2L]]$value, times[[3L]])
    emit("c1", "last_executed_event_ts", NA_character_, times[[3L]])
    emit("c1", "reason_is_valuation_exhaustion", FALSE, times[[3L]])
    emit("c1", "reason_is_unknown_lifetime", FALSE, times[[3L]])
    emit("c1", "evidence_status", disposition$evidence_status, times[[3L]])
    emit("c1", "selection_eligible", disposition$selection_eligible, times[[3L]])
  }

  if (identical(case_spec$mode, "status")) {
    facts <- stage4_status_facts(provider)
    decisions <- stage4_ts(c(
      "2024-01-02T21:00:00Z", "2024-01-03T21:00:00Z",
      "2024-01-04T21:00:00Z", "2024-01-05T21:00:00Z",
      "2024-01-08T21:00:00Z"
    ))
    executions <- stage4_ts(c(
      "2024-01-03T14:30:00Z", "2024-01-04T14:30:00Z",
      "2024-01-05T14:30:00Z", "2024-01-08T14:30:00Z",
      "2024-01-09T14:30:00Z"
    ))
    for (i in seq_along(decisions)) {
      case_id <- paste0("c", i)
      decision_status <- stage3_resolve_status(facts, "A01", decisions[[i]])
      execution_status <- stage3_resolve_status(facts, "A01", executions[[i]])
      if (i <= 4L) {
        emit(
          case_id, "target_restricted", decision_status != "active",
          stage3_iso(decisions[[i]]), "A01",
          stage3_status_fill_reason(decision_status)
        )
      }
      emit(case_id, "resolved_status", execution_status, stage3_iso(executions[[i]]), "A01")
      reason <- stage3_status_fill_reason(execution_status)
      if (!nzchar(reason)) {
        emit(case_id, "fill_status", "filled", stage3_iso(executions[[i]]), "A01")
        if (case_id == "c1") emit(case_id, "fill_price", 100, stage3_iso(executions[[i]]), "A01")
        if (case_id == "c4") emit(case_id, "fill_qty", 100L, stage3_iso(executions[[i]]), "A01")
        emit(case_id, "cash_after", 100000, stage3_iso(executions[[i]]))
      } else {
        emit(case_id, "fill_status", "no_fill", stage3_iso(executions[[i]]), "A01", reason)
        emit(case_id, "position_after", 100L, stage3_iso(executions[[i]]), "A01")
        if (case_id == "c2") emit(case_id, "later_fields_consulted", FALSE, stage3_iso(executions[[i]]))
      }
    }
    c6_decision <- stage4_ts("2024-01-02T21:00:00Z")
    c6_time <- stage4_ts("2024-01-03T14:30:00Z")
    c6_id <- "A05"
    c6_qty <- fact("policy", "opening_position", asset_id = c6_id)
    known_assertions <- facts$asset_id == c6_id &
      facts$effective_from <= c6_decision & facts$knowledge_time <= c6_decision
    c6_status <- stage3_resolve_status(facts, c6_id, c6_time)
    c6_fill <- stage4_policy_fill(-c6_qty, NA_real_, c6_status)
    emit("c6", "status_assertion_count", sum(known_assertions),
      stage3_iso(c6_decision), c6_id)
    emit("c6", "resolved_status", c6_status, stage3_iso(c6_time), c6_id)
    emit("c6", "fill_status", c6_fill$status, stage3_iso(c6_time), c6_id,
      stage4_first_reason(c6_fill$reason_code))
    emit("c6", "position_after",
      as.integer(c6_qty + sign(-c6_qty) * c6_fill$qty),
      stage3_iso(c6_time), c6_id)
    emit("c6", "cash_after",
      fact("policy", "opening_cash") + c6_fill$cash_delta,
      stage3_iso(c6_time))
  }

  if (identical(case_spec$mode, "provider_roundtrip")) {
    path <- case_spec$path %||% "direct"
    include_fork <- path %in% c("direct", "par")
    for (case_id in c("c1", "c2")) {
      pulses <- stage4_split(fact("policy", paste0(case_id, "_pulses")))
      held_ids <- if (case_id == "c2") "A01" else character()
      views <- lapply(pulses, function(time) {
        stage4_decision_view(provider, case_id, time, held_ids, time)
      })
      marks <- list(A02 = stage4_provider_mark_series(
        provider, case_id, "A02", pulses, 0L,
        fact("policy", "max_stale_age")
      ))
      if (case_id == "c2") {
        marks$A01 <- stage4_provider_mark_series(
          provider, case_id, "A01", pulses, 100L,
          fact("policy", "max_stale_age")
        )
      }
      prefix <- paste0(case_id, "_provider_", path)
      index <- if (case_id == "c1") 2L else 3L
      emit(prefix, "decision_view", paste(views[[index]]$asset_id, collapse = "|"), pulses[[index]])
      emit(prefix, "axis_ids", paste(unique(unlist(lapply(views, `[[`, "asset_id"))), collapse = "|"))
      emit(prefix, "pulse_axis", paste(pulses, collapse = "|"))
      emit(prefix, "decision_view", paste(views[[1L]]$asset_id, collapse = "|"), pulses[[1L]])
      if (case_id == "c1") {
        for (i in seq_along(pulses)) {
          emit(prefix, "close_plane_value", marks$A02[[i]]$value, pulses[[i]], "A02")
          emit(prefix, "observation_state", marks$A02[[i]]$observation_state, pulses[[i]], "A02")
          emit(prefix, "mark_age", marks$A02[[i]]$age, pulses[[i]], "A02")
        }
        emit(prefix, "evidence_row_count", length(pulses))
      } else if (case_id == "c2") {
        emit(prefix, "close_plane_value", marks$A01[[1L]]$value, pulses[[1L]], "A01")
        emit(prefix, "close_plane_value", marks$A02[[1L]]$value, pulses[[1L]], "A02")
        for (i in 1:4) {
          emit(prefix, "observation_state", marks$A01[[i]]$observation_state, pulses[[i]], "A01")
        }
        emit(prefix, "observation_state", marks$A02[[3L]]$observation_state, pulses[[3L]], "A02")
        emit(prefix, "mark_value", marks$A01[[2L]]$value, pulses[[2L]], "A01")
        emit(prefix, "mark_age", marks$A01[[2L]]$age, pulses[[2L]], "A01")
        emit(prefix, "mark_age", marks$A01[[3L]]$age, pulses[[3L]], "A01")
        emit(prefix, "mark_permissible", marks$A01[[4L]]$permissible, pulses[[4L]], "A01")
        emit(prefix, "evidence_row_count", 10L)
      }
      emit(
        prefix, "provider_identity", stage4_provider_identity(provider),
        identity_name = "proto:provider_id"
      )
      if (include_fork) {
        execution <- fact("policy", "execution_time")
        opening_cash <- fact(case_id, "opening_cash")
        target <- fact(case_id, "target", asset_id = "A02")
        fill_view <- stage4_execution_view(provider, case_id, execution, "A02", execution)
        fill <- stage4_policy_fill(target, fill_view$execution_price[[1L]], fill_view$trading_status[[1L]])
        cash_after <- opening_cash + fill$cash_delta
        fork_prefix <- paste0(case_id, "_fork_", path)
        if (case_id == "c1") {
          emit(fork_prefix, "pre_risk_target", target, pulses[[1L]], "A02")
          emit(fork_prefix, "fill_qty", fill$qty, execution, "A02")
          emit(fork_prefix, "fill_price", fill$price, execution, "A02")
          emit(fork_prefix, "cash_after", cash_after, execution)
          emit(fork_prefix, "position_after", target, pulses[[2L]], "A02")
          emit(fork_prefix, "equity", cash_after + target * marks$A02[[2L]]$value, pulses[[2L]])
          emit(fork_prefix, "evidence_status",
            stage4_policy_evidence_status(), pulses[[2L]])
          emit(fork_prefix, "package_integration_claimed", FALSE)
        } else {
          emit(fork_prefix, "fill_qty", fill$qty, execution, "A02")
          emit(fork_prefix, "cash_after", cash_after, execution)
          emit(fork_prefix, "equity", cash_after + target * marks$A02[[3L]]$value + 100 * marks$A01[[3L]]$value, pulses[[3L]])
          emit(fork_prefix, "stop_reason", marks$A01[[4L]]$stop_reason, pulses[[4L]])
          emit(fork_prefix, "achieved_horizon", stage4_ts(pulses[[3L]]), pulses[[4L]])
          emit(fork_prefix, "affected_exposure", 100 * marks$A01[[3L]]$value, pulses[[4L]])
          emit(fork_prefix, "evidence_status",
            stage4_policy_evidence_status(marks$A01[[4L]]$stop_reason),
            pulses[[4L]])
        }
        emit(
          fork_prefix, "prototype_identity", stage4_prototype_identity(provider),
          identity_name = "proto:prototype_id"
        )
      }
    }
  }

  if (identical(case_spec$mode, "package_control")) {
    fixture <- stage4_w21_fixture_from_provider(provider)
    package <- case_spec$package_trace %||%
      stage4_w21_package_runner(fixture, provider$provider_kind)
    fork <- stage3_run_w21_fork(fixture, package$source_identity)
    stage3_compare_w21_traces(fork, package)
    stage4_emit_stage3_evidence(
      stage3_materialize_observed(
        "W21", stage3_w21_evidence(package), source = "package_control"
      ),
      emit,
      "package_control"
    )
  }

  if (identical(case_spec$mode, "risk_marks")) {
    prior <- "2024-01-02T21:00:00Z"
    decision <- "2024-01-03T21:00:00Z"
    execution <- "2024-01-04T14:30:00Z"
    opening_cash <- fact("policy", "opening_cash")
    held <- fact("policy", "held_qty", asset_id = "A02")
    risk_hash <- getFromNamespace("ledgr_risk_chain_hash", "ledgr")
    for (case_id in c("c0", "c1", "c2")) {
      mark_times <- if (case_id == "c0") decision else c(prior, decision)
      mark <- tail(stage4_provider_mark_series(
        provider, case_id, "A02", mark_times, held
      ), 1L)[[1L]]
      equity <- opening_cash + held * mark$value
      max_weight <- fact(case_id, "max_weight")
      risk <- stage4_policy_max_weight(
        c(A02 = held), equity, c(A02 = mark$value), max_weight
      )
      stage4_assert(risk$accepted, paste(case_id, "unexpectedly lacked a risk mark."))
      post <- risk$targets[["A02"]]
      execution_view <- stage4_execution_view(
        provider, case_id, execution, "A02", execution
      )
      execution_available <- is.finite(execution_view$execution_price[[1L]])
      fill <- stage4_policy_fill(
        post - held, execution_view$execution_price[[1L]],
        execution_view$trading_status[[1L]]
      )
      reduction_reason <- if (post < held) {
        if (mark$source == "stale_mark") "stale_mark_reduction" else
          "max_weight_reduction"
      } else {
        "stale_mark_pass_through"
      }
      emit(case_id, "post_risk_target", as.integer(post), decision, "A02",
        reduction_reason)
      if (case_id != "c0") emit(
        case_id, "risk_mark_source", mark$source, decision, "A02"
      )
      emit(case_id, "fill_status", fill$status, execution, "A02")
      emit(case_id, "risk_chain_hash", risk_hash(ledgr::ledgr_risk_max_weight(max_weight)), decision,
        identity_name = "risk_chain_hash")
      if (case_id %in% c("c0", "c1")) {
        valuation_id <- stage3_hash(list(A02 = list(
          mark = mark$value, age = mark$age, source = mark$source
        )))
        if (case_id == "c0") {
          emit(case_id, "mark_source", mark$source, decision, "A02")
          emit(case_id, "mark_age", mark$age, decision, "A02")
          emit(case_id, "pre_risk_target", as.integer(held), decision, "A02")
          emit(case_id, "post_risk_validation",
            if (stage4_policy_post_risk_valid(c(A02 = held), c(A02 = post))) {
              "accepted"
            } else {
              "rejected"
            }, decision, "A02")
        } else {
          emit(case_id, "strategy_close_available",
            mark$source == "observed_close", decision, "A02")
          emit(case_id, "mark_source", mark$source, decision, "A02")
          emit(case_id, "mark_age", mark$age, decision, "A02")
          emit(case_id, "mark_value", mark$value, decision, "A02")
          emit(case_id, "risk_aborted", !risk$accepted, decision)
          emit(case_id, "risk_mark_age", mark$age, decision, "A02")
        }
        emit(case_id, "equity", equity, decision)
        emit(case_id, "valuation_evidence_identity", valuation_id, decision,
          identity_name = "proto:valuation_evidence_id")
        emit(case_id, "execution_bar_available", execution_available,
          execution, "A02")
        emit(case_id, "fill_price", fill$price, execution, "A02")
        emit(case_id, "fill_qty", fill$qty, execution, "A02")
        emit(case_id, "cash_after", opening_cash + fill$cash_delta, execution)
      }
    }
    new_target <- fact("c3", "target", asset_id = "A03")
    held_new <- 0L
    new_mark <- stage4_provider_mark_series(
      provider, "c3", "A03", decision, held_new
    )[[1L]]
    new_risk <- stage4_policy_max_weight(
      c(A03 = new_target), opening_cash, c(A03 = new_mark$value),
      fact("c3", "max_weight")
    )
    disposition <- stage4_policy_stop_disposition(new_risk$stop_reason)
    before <- list(cash = opening_cash, positions = c(A03 = held_new))
    after <- before
    emit("c3", "held_qty", held_new, decision, "A03")
    emit("c3", "pre_risk_target", new_target, decision, "A03")
    emit("c3", "mark_source",
      if (new_mark$source == "unavailable") "none" else new_mark$source,
      decision, "A03")
    emit("c3", "stop_reason", new_risk$stop_reason, decision)
    emit("c3", "stop_asset_id", new_risk$stop_asset_id, decision)
    emit("c3", "stop_target", as.integer(new_risk$stop_target), decision)
    emit("c3", "stop_risk_step", new_risk$stop_risk_step, decision)
    emit("c3", "fill_proposals", disposition$fill_proposals, decision)
    emit("c3", "state_mutated", !identical(before, after), decision)
    emit("c3", "cash_after", after$cash, decision)
    emit("c3", "reason_is_valuation_exhaustion",
      identical(new_risk$stop_reason, "valuation_horizon_exhausted"), decision)
  }

  if (identical(case_spec$mode, "fold_boundary")) {
    fill_time <- "2024-01-03T14:30:00Z"
    fold1_close <- "2024-01-04T21:00:00Z"
    fold2_open <- "2024-01-05T21:00:00Z"
    carried <- fact("policy", "carried_id")
    qty <- fact("policy", "buy_qty", asset_id = carried)
    price <- fact("policy", "buy_price", asset_id = carried)
    cash <- fact("policy", "opening_cash") - qty * price
    fold1_view <- stage4_decision_view(
      provider, "c1", fold1_close, held_ids = carried,
      knowledge_cutoff = fold1_close
    )
    fold2_view <- stage4_decision_view(
      provider, "c1", fold2_open, held_ids = carried,
      knowledge_cutoff = fold2_open
    )
    carried_mark <- stage4_provider_mark_series(
      provider, "c1", carried, fold1_close, qty
    )[[1L]]
    held_nonmember <- fold2_view$held & !fold2_view$member
    opening_accepted <- carried %in% fold2_view$asset_id &&
      is.finite(qty) && is.finite(cash)
    emit("c1", "fill_qty", qty, fill_time, carried)
    emit("c1", "fold1_closing_cash", cash, fold1_close)
    emit("c1", "fold1_closing_qty", qty, fold1_close, carried)
    emit("c1", "member",
      fold1_view$member[match(carried, fold1_view$asset_id)],
      fold1_close, carried)
    emit("c1", "mark_age", carried_mark$age, fold1_close, carried)
    emit("c1", "equity", cash + qty * carried_mark$value, fold1_close)
    emit("c1", "opening_axis",
      paste(fold2_view$asset_id, collapse = "|"), fold2_open)
    emit("c1", "opening_validation",
      if (opening_accepted) "accepted" else "rejected", fold2_open)
    emit("c1", "requires_current_membership",
      !opening_accepted || !any(held_nonmember), fold2_open)
    emit("c1", "held_qty", qty, fold2_open, carried)
    emit("c1", "lot_basis", fact("policy", "carried_basis", asset_id = carried), fold2_open, carried)
    emit("c1", "opening_cash", cash, fold2_open)
    emit("c1", "held_nonmember_count", sum(held_nonmember), fold2_open)
    emit("c1", "pre_risk_target",
      as.integer(if (fold2_view$held[match(carried, fold2_view$asset_id)]) qty else 0),
      fold2_open, carried)
    emit("c1", "package_walk_forward_claimed", FALSE, fold2_open)
  }

  if (identical(case_spec$mode, "transform_identity")) {
    rows <- stage4_provider_rows(provider)
    times <- sort(unique(rows$event_time[rows$case_id == "input"]), method = "radix")
    raw <- stage4_history(provider, "input", "raw", "A01")
    calendar <- fact("policy", "calendar")
    classifier <- fact("policy", "classifier")
    population <- fact("policy", "population")
    cutoff <- fact("policy", "cutoff")
    rng <- fact("policy", "rng")
    g1 <- stage3_rolling_mean_two(stage3_carry_forward(raw))
    g2 <- stage3_carry_forward(stage3_rolling_mean_two(raw))
    raw_id <- stage3_hash(list(kind = "raw", values = c("1", "3", "NA", "9")))
    identity <- function(order, cal, cls, pop, cut) list(
      graph = stage3_hash(list(order = order, calendar = cal, classifier = cls)),
      fit = stage3_hash(list(
        recipe = "label_mean_v1", population = pop, cutoff = cut,
        calendar = cal, classifier = cls, rng = rng, fitted = 15
      ))
    )
    base1 <- identity(c("carry", "roll2"), calendar, classifier, population, cutoff)
    base2 <- identity(c("roll2", "carry"), calendar, classifier, population, cutoff)
    for (i in seq_along(times)) {
      emit("g1", "feature_value", g1[[i]], times[[i]], "A01")
      emit("g2", "feature_value", g2[[i]], times[[i]], "A01")
    }
    emit("g1", "bars_created", 0L)
    emit("g2", "bars_created", 0L)
    emit("g1", "raw_series_identity", raw_id, identity_name = "proto:raw_series_id")
    emit("g1", "graph_identity", base1$graph, identity_name = "proto:graph_id")
    emit("g1", "fit_identity", base1$fit, identity_name = "proto:fitted_artifact_id")
    emit("g2", "graph_identity", base2$graph, identity_name = "proto:graph_id")
    emit("g2", "graph_identity_g2", base2$graph, identity_name = "proto:graph_id")
    mutations <- list(
      m_cal = list(cal = "XSYN_v2", cls = classifier, pop = population, cut = cutoff),
      m_cls = list(cal = calendar, cls = "observed_v2", pop = population, cut = cutoff),
      m_pop = list(cal = calendar, cls = classifier, pop = "A01|A02", cut = cutoff),
      m_cut = list(cal = calendar, cls = classifier, pop = population, cut = "2024-01-04T21:00:00Z")
    )
    for (case_id in names(mutations)) {
      x <- mutations[[case_id]]
      one <- identity(c("carry", "roll2"), x$cal, x$cls, x$pop, x$cut)
      two <- identity(c("roll2", "carry"), x$cal, x$cls, x$pop, x$cut)
      emit(case_id, "raw_series_identity", raw_id, identity_name = "proto:raw_series_id")
      emit(case_id, "graph_identity_g1", one$graph, identity_name = "proto:graph_id")
      emit(case_id, "graph_identity_g2", two$graph, identity_name = "proto:graph_id")
      emit(case_id, "fit_identity", one$fit, identity_name = "proto:fitted_artifact_id")
    }
    m_cut <- mutations$m_cut
    cut_identity <- identity(
      c("carry", "roll2"), m_cut$cal, m_cut$cls, m_cut$pop, m_cut$cut
    )
    emit("m_cut", "warm_cache_ancestors_preserved",
      identical(cut_identity$graph, base1$graph) &&
        !identical(cut_identity$fit, base1$fit))
  }

  evidence$finish()
}
