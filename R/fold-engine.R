ledgr_finalize_fold_telemetry <- function(output_handler,
                                          status,
                                          telemetry,
                                          processed,
                                          strict = TRUE) {
  if (!is.null(telemetry)) {
    samples <- as.integer(telemetry$telemetry_samples %||% 0L)
    keep <- if (samples > 0L) seq_len(samples) else integer()
    telemetry_names <- ls(telemetry, all.names = TRUE)
    telemetry_scalars <- c(
      "t_pre",
      "t_post",
      "t_loop",
      "telemetry_stride",
      "telemetry_samples"
    )
    trimmed <- lapply(telemetry_names, function(name) {
      x <- telemetry[[name]]
      if (name %in% telemetry_scalars) {
        return(x)
      }
      x[keep]
    })
    names(trimmed) <- telemetry_names
    output_handler$store_session_telemetry(trimmed)
    telemetry <- trimmed
  }
  output_handler$write_telemetry(
    status = status,
    telemetry = telemetry,
    processed = processed,
    strict = strict
  )
}

ledgr_fold_positions_to_vec <- function(positions, instrument_ids) {
  if (is.null(positions) || length(positions) == 0L) {
    return(rep(0, length(instrument_ids)))
  }
  if (!is.numeric(positions)) {
    rlang::abort("Fold state positions must be numeric.", class = "ledgr_invalid_fold_execution")
  }
  if (!is.null(names(positions))) {
    out <- rep(0, length(instrument_ids))
    matched <- intersect(names(positions), instrument_ids)
    if (length(matched) > 0L) {
      out[match(matched, instrument_ids)] <- as.numeric(positions[matched])
    }
    return(out)
  }
  if (length(positions) != length(instrument_ids)) {
    rlang::abort("Primitive fold state positions must align with instrument_ids.", class = "ledgr_invalid_fold_execution")
  }
  as.numeric(positions)
}

ledgr_fold_positions_snapshot <- function(position_vec, instrument_ids) {
  stats::setNames(as.numeric(position_vec), instrument_ids)
}

ledgr_fold_asset_state_normalize <- function(state_value, axis, drop_exited = FALSE) {
  if (is.null(state_value)) state_value <- list()
  if (!is.list(state_value)) {
    rlang::abort(
      "Availability-aware strategy state must be a list.",
      class = "ledgr_invalid_strategy_state"
    )
  }
  asset_state <- state_value$asset_state
  if (is.null(asset_state)) asset_state <- list()
  if (!is.list(asset_state)) {
    rlang::abort(
      "`state_update$asset_state` must be a named list.",
      class = "ledgr_invalid_strategy_state"
    )
  }
  if (length(asset_state) > 0L &&
      (is.null(names(asset_state)) || anyNA(names(asset_state)) ||
       any(!nzchar(names(asset_state))) || anyDuplicated(names(asset_state)))) {
    rlang::abort(
      "`state_update$asset_state` must use unique non-empty stable instrument IDs.",
      class = "ledgr_invalid_strategy_state"
    )
  }
  extra <- setdiff(names(asset_state), axis)
  if (length(extra) > 0L && !isTRUE(drop_exited)) {
    rlang::abort(
      sprintf(
        "`state_update$asset_state` contains IDs outside the current axis: %s.",
        paste(extra, collapse = ", ")
      ),
      class = "ledgr_invalid_strategy_state"
    )
  }
  # One positional match instead of a named assignment per axis ID; an entry
  # that is missing or NULL becomes list().
  normalized <- stats::setNames(rep(list(list()), length(axis)), axis)
  if (length(asset_state) > 0L) {
    idx <- match(axis, names(asset_state))
    present <- !is.na(idx)
    # Only zero-length entries can be NULL; is.null() runs on those alone.
    empty <- which(lengths(asset_state) == 0L)
    is_null <- logical(length(asset_state))
    is_null[empty] <- vapply(asset_state[empty], is.null, logical(1))
    present[present] <- !is_null[idx[present]]
    normalized[present] <- asset_state[idx[present]]
  }
  state_value$asset_state <- normalized
  state_value
}

ledgr_fold_warn_final_bar_no_fill <- function() {
  warning(
    paste(
      "LEDGR_LAST_BAR_NO_FILL:",
      "target changed on the final available bar, but the next-open fill model requires a following bar.",
      "No fill was emitted for this target change.",
      "Check the strategy's final-pulse behavior or extend the snapshot if this trade should be fillable."
    ),
    call. = FALSE
  )
  invisible(NULL)
}

# The dense planner (Synthesis 3.3 and Section 4, Q1): one candidate row per
# actionable context ordinal, executed at the next pulse's open read from
# bars_mat at pulse_idx + 1. On the final pulse every row is rejected for the
# missing opportunity and warns once per target, as before; a missing next
# open refuses in decision order; a non-positive resolved price is rejected.
# Rejections feed no diagnostics on this producer; its plan carries no
# reconciliation cash.
ledgr_fold_build_pulse_plan <- function(context_pos,
                                        target_qty,
                                        position,
                                        actionable_k,
                                        pulse_idx,
                                        has_next,
                                        exec_ts,
                                        epoch_valid,
                                        bars_mat,
                                        cost_resolver,
                                        n_run) {
  k <- actionable_k
  n <- length(k)
  pos <- context_pos[k]
  before <- position[k]
  delta <- target_qty[k] - before
  side <- ledgr_plan_side(delta)
  qty <- abs(delta)
  none <- integer()
  if (!has_next) {
    for (i in seq_len(n)) ledgr_fold_warn_final_bar_no_fill()
    exec_ts <- NA_real_
    price <- rep(NA_real_, n)
    fee <- price
    fills <- none
    reason <- 1L
  } else {
    open <- as.numeric(bars_mat$open[pos, pulse_idx + 1L])
    bad_open <- !is.finite(open) | open <= 0
    # The base order of refusals: the first row's open, then the shared
    # execution epoch, then any later row's open.
    if (n > 0L) {
      if (bad_open[[1L]]) ledgr_plan_refuse_open()
      if (!epoch_valid) ledgr_plan_refuse_epoch(exec_ts)
      if (any(bad_open)) ledgr_plan_refuse_open()
    }
    resolved <- ledgr_plan_resolve(cost_resolver, side, qty, open)
    price <- resolved$price
    fee <- resolved$fee
    fills <- which(is.finite(price) & price > 0)
    reason <- 2L
  }
  rejected <- setdiff(seq_len(n), fills)
  effects <- ledgr_fill_publication_deltas(side[fills], qty[fills], price[fills], fee[fills])
  segment <- ledgr_carrier_segments(n, rejected, rep(reason, length(rejected)))
  groups <- ledgr_plan_groups(k, pos, side, qty, price, fee, exec_ts, before, segment,
    fills, effects, rejected, rep(1L, length(rejected)), rep(NA_real_, length(rejected)))
  ledgr_carrier_plan(
    list(expected_final_cash = NA_real_, economic_event_kinds = if (length(fills) > 0L) 1L else none,
      fill = groups$fill, rejection = groups$rejection),
    context_pos, actionable_k, n_run
  )
}

ledgr_plan_refuse_open <- function() {
  rlang::abort("`next_open_price` must be a finite numeric scalar > 0.", class = "ledgr_invalid_fill_input")
}

ledgr_fold_apply_net_feasibility_noop <- function(pulse_plan, state) {
  force(state)
  pulse_plan
}

# P3's event-kind gate (before any mutation): a plan with fills declares
# FILL; canonical R accounting executes only `canonical_event_kinds`.
ledgr_fold_plan_event_kinds <- function(plan, canonical_event_kinds = NULL) {
  kinds <- unique(plan$economic_event_kinds)
  if (length(plan$fill$k) > 0L && !1L %in% kinds) {
    rlang::abort(
      "A pulse plan containing fills must declare the FILL economic-event kind.",
      class = c("ledgr_invalid_pulse_plan", "ledgr_invalid_fold_execution")
    )
  }
  if (!is.null(canonical_event_kinds)) {
    unsupported <- setdiff(kinds, canonical_event_kinds)
    if (length(unsupported) > 0L) {
      rlang::abort(
        paste0(
          "Canonical R accounting cannot execute pulse-plan economic event ",
          "kind(s): ", paste(ledgr_plan_kind_text(unsupported), collapse = ", "), "."
        ),
        class = c("ledgr_invalid_pulse_plan", "ledgr_invalid_fold_execution")
      )
    }
  }
  ledgr_plan_kind_text(kinds)
}

# E import boundary (Synthesis 3.1): opening, carried or resumed state into
# the fold's typed state. Named or run-aligned positions become the unnamed
# run-axis vector; the lot book must be a typed book on the run axis (a
# replayed book may extend the axis with entries that hold nothing). NULL
# means an empty book.
ledgr_carrier_import_state <- function(state, instrument_ids) {
  n <- length(instrument_ids)
  book <- state$lot_state %||% ledgr_lot_book(n)
  problem <- ledgr_lot_book_problem(book, reduction = FALSE)
  if (!is.null(problem)) {
    rlang::abort(
      paste0("Invalid typed lot book at fold entry: ", problem, "."),
      class = c("ledgr_lot_state_invariant", "ledgr_invalid_state")
    )
  }
  book <- ledgr_lot_book_restrict(book, n)
  list(
    cash = state$cash,
    positions = as.numeric(ledgr_fold_positions_to_vec(state$positions, instrument_ids)),
    lot_state = book
  )
}

# Transitional settlement boundary (corporate actions and dispositions; the
# remover is WS8): that code reads positions by instrument ID, so the
# adapter names them on the way out and installs them back by position.
ledgr_carrier_settlement_state <- function(fold_state, instrument_ids) {
  list(
    cash = fold_state$cash,
    positions = stats::setNames(fold_state$positions, instrument_ids),
    lot_state = fold_state$lot_state
  )
}

ledgr_carrier_settlement_install <- function(fold_state, value) {
  positions <- value$positions
  if (!is.double(positions) || length(positions) != length(fold_state$positions)) {
    rlang::abort(
      "Settlement returned positions that are not on the run axis.",
      class = "ledgr_invalid_fold_execution"
    )
  }
  fold_state$cash <- value$cash
  fold_state$positions <- as.numeric(positions)
  fold_state$lot_state <- value$lot_state
  invisible(NULL)
}

# Result boundary: the fold's returned state names positions by instrument
# ID; the typed book is handed out and never written again.
ledgr_carrier_result_state <- function(fold_state, instrument_ids) {
  list(
    cash = fold_state$cash,
    positions = stats::setNames(fold_state$positions, instrument_ids),
    lot_state = fold_state$lot_state
  )
}

ledgr_fold_flush_pulse_block <- function(
    fold_state,
    diagnostic_writer,
    run_id,
    ts) {
  if (length(fold_state$pending_segments) == 0L) {
    return(invisible(NULL))
  }
  block <- ledgr_availability_diagnostic_block(
    run_id,
    ts,
    fold_state$diagnostic_seq + 1L,
    fold_state$pending_segments
  )
  fold_state$pending_segments <- list()
  fold_state$diagnostic_seq <-
    fold_state$diagnostic_seq + length(block$diagnostic_seq)
  diagnostic_writer$append_block(block)
  invisible(NULL)
}

ledgr_fold_stage_observe_settle <- function(
    fold_state,
    services,
    pulse_idx,
    ts,
    ts_iso,
    sample_telemetry,
    sample_start) {
  fold_state$current_stage <- "valuation"
  history_bars <- if (services$availability_active) {
    services$history_reader$bars(pulse_idx)
  } else {
    NULL
  }
  decision_due <- is.null(services$decision_due) ||
    isTRUE(services$decision_due[[pulse_idx]])
  history_view <- if (services$availability_active) {
    if (decision_due) services$history_reader$view(pulse_idx) else NULL
  } else {
    NULL
  }
  add_segment <- function(segment) {
    fold_state$pending_segments[[length(fold_state$pending_segments) + 1L]] <- segment
    invisible(NULL)
  }
  # One produced view: the provider's input names the run-axis positions by
  # ID; its outputs and the valuation are converted once by the transitional
  # provider adapter (Synthesis 3.2). Settlement, terminal and stop handling
  # below keep reading the provider's named view and valuation (the
  # settlement boundary, remover WS8).
  availability_decision <- function(positions) {
    full_positions <- ledgr_fold_positions_snapshot(
      positions,
      services$instrument_ids
    )
    view <- services$availability_provider$decision_view(ts, full_positions)
    ids <- as.character(view$axis)
    valuation <- services$valuation_state$advance(
      pulse_idx,
      ids,
      held = as.logical(view$held[ids])
    )
    view <- ledgr_availability_restrict_frozen(view, valuation)
    columns <- ledgr_carrier_provider_view(view, valuation)
    list(
      view = view,
      valuation = valuation,
      columns = columns,
      ids = ids,
      held_ids = ids[columns$held],
      full_positions = full_positions
    )
  }
  stop_valuation <- function(ids, reason_code, reasons, positions, valuation) {
    affected <- ledgr_availability_affected_exposure(ids, positions, valuation)
    affected <- c(affected, list(ts_utc = ts, specified = TRUE))
    segment <- list(
      n = length(ids), instrument_id = ids, stage = "valuation", outcome = "stopped",
      reason_code = reason_code, reasons = reasons,
      quantity = positions[ids], price = valuation$reference[ids],
      mark_source = valuation$source[ids], mark_age = valuation$age[ids],
      position_before = positions[ids], position_after = positions[ids],
      detail_json = vapply(
        seq_along(ids),
        function(k) ledgr_availability_detail_json(affected$details[[k]]),
        character(1)
      )
    )
    ledgr_fold_stop_result(
      status = "INCOMPLETE",
      reason_code = reason_code,
      affected_instrument_ids = ids,
      affected_exposure = affected,
      diagnostic_segments = list(segment),
      counts_processed = FALSE
    )
  }

  if (!is.null(services$corporate_action_plan)) {
    marks <- stats::setNames(
      if (services$availability_active) {
        as.numeric(history_bars$current$close)
      } else {
        as.numeric(services$bars_mat$close[, pulse_idx])
      },
      services$instrument_ids
    )
    services$corporate_action_plan$check_clocks(pulse_idx)
    posted <- services$corporate_action_plan$post(
      index = pulse_idx,
      run_id = services$run_id,
      event_seq = fold_state$event_seq,
      output_handler = services$output_handler,
      state_value = ledgr_carrier_settlement_state(fold_state, services$instrument_ids),
      marks = marks
    )
    ledgr_carrier_settlement_install(fold_state, posted$state)
    fold_state$event_seq <- posted$next_event_seq
    refused <- posted$stopped %||%
      services$corporate_action_plan$check_quantity_effects(pulse_idx)
    if (!is.null(refused)) {
      if (!services$availability_active) {
        ledgr_corporate_action_refusal_abort(refused)
      }
      refusal_decision <- availability_decision(fold_state$positions)
      return(stop_valuation(
        refused$ids,
        refused$reason_code,
        rep(refused$reasons, length(refused$ids)),
        refusal_decision$full_positions,
        refusal_decision$valuation
      ))
    }
  }

  view_columns <- NULL
  if (services$availability_active) {
    decision <- availability_decision(fold_state$positions)
    if (!is.null(services$corporate_action_plan) &&
        isTRUE(services$corporate_action_plan$has_disposition())) {
      disposed <- services$corporate_action_plan$post_disposition(
        index = pulse_idx,
        run_id = services$run_id,
        event_seq = fold_state$event_seq,
        output_handler = services$output_handler,
        state_value = ledgr_carrier_settlement_state(fold_state, services$instrument_ids),
        valuation = decision$valuation
      )
      ledgr_carrier_settlement_install(fold_state, disposed$state)
      fold_state$event_seq <- disposed$next_event_seq
      if (!is.null(disposed$stopped)) {
        return(stop_valuation(
          disposed$stopped$ids,
          disposed$stopped$reason_code,
          disposed$stopped$reasons,
          decision$full_positions,
          decision$valuation
        ))
      }
      if (disposed$dispositions > 0L) {
        decision <- availability_decision(fold_state$positions)
      }
    }

    inactive_ids <- decision$held_ids[
      as.character(decision$view$lifetime[decision$held_ids]) %in% "known_inactive"
    ]
    if (length(inactive_ids) > 0L) {
      labels <- as.character(decision$view$terminal_event[inactive_ids])
      resolved <- ledgr_terminal_resolve(
        services$terminal_policy,
        inactive_ids,
        labels,
        decision$valuation
      )
      resolved$outcome[!nzchar(labels)] <- "unlabeled"
      blocked <- resolved$outcome != "dispose"
      if (any(blocked)) {
        unsupported <- resolved$outcome %in% c("unlabeled", "refuse")
        reasons <- ifelse(
          resolved$outcome == "unlabeled",
          "terminal_settlement_unsupported|terminal_label_missing",
          ifelse(
            resolved$outcome == "refuse",
            ifelse(
              resolved$basis == "frozen_fallback",
              "terminal_settlement_unsupported|frozen_terminal_refuse",
              "terminal_settlement_unsupported"
            ),
            paste("terminal_mark_unavailable", resolved$choice, sep = "|")
          )
        )
        return(stop_valuation(
          inactive_ids[blocked],
          if (any(unsupported)) {
            "terminal_settlement_unsupported"
          } else {
            "terminal_mark_unavailable"
          },
          reasons[blocked],
          decision$full_positions,
          decision$valuation
        ))
      }
      mark_meta <- ledgr_terminal_mark_meta(resolved, decision$valuation, ts)
      fact_ids <- as.character(decision$view$lifetime_fact_id[inactive_ids])
      meta <- lapply(seq_along(inactive_ids), function(k) {
        out <- list(
          source = "lifetime_terminal_disposition",
          source_fact_id = fact_ids[[k]],
          terminal_event = labels[[k]],
          matched_label = resolved$matched_label[[k]],
          disposition_policy_id = resolved$policy_id[[k]],
          disposition_choice = resolved$choice[[k]],
          disposition_basis = resolved$basis[[k]],
          mark_source = mark_meta$source[[k]],
          mark_source_ts_utc = mark_meta$source_ts[[k]],
          mark_age = mark_meta$age[[k]]
        )
        if (identical(resolved$choice[[k]], "haircut")) {
          out$haircut_fraction <- resolved$haircut
        }
        out
      })
      posted <- ledgr_disposition_post(
        ids = inactive_ids,
        price = resolved$price,
        meta = meta,
        ts = ts,
        run_id = services$run_id,
        event_seq = fold_state$event_seq,
        output_handler = services$output_handler,
        state_value = ledgr_carrier_settlement_state(fold_state, services$instrument_ids),
        instrument_ids = services$instrument_ids,
        exposure_mark = resolved$reference
      )
      ledgr_carrier_settlement_install(fold_state, posted$state)
      fold_state$event_seq <- posted$next_event_seq
      add_segment(list(
        n = length(inactive_ids), instrument_id = inactive_ids, stage = "valuation",
        outcome = "disposed", reason_code = "terminal_disposition",
        reasons = paste("terminal_disposition", resolved$choice, resolved$basis, sep = "|"),
        quantity = abs(posted$before), price = resolved$price,
        mark_source = mark_meta$source, mark_age = mark_meta$age,
        event_seq = posted$event_seq,
        position_before = posted$before, position_after = 0
      ))
      decision <- availability_decision(fold_state$positions)
    }

    view_columns <- decision$columns
    valuation <- decision$valuation
    context_ids <- decision$ids
    full_positions <- decision$full_positions
    unvalued_ids <- context_ids[view_columns$held & !view_columns$priced]
    if (length(unvalued_ids) > 0L) {
      return(stop_valuation(
        unvalued_ids,
        "valuation_horizon_exhausted",
        "valuation_horizon_exhausted",
        full_positions,
        valuation
      ))
    }
    frozen_now <- context_ids[view_columns$held & view_columns$frozen]
    entered <- setdiff(frozen_now, fold_state$frozen_set)
    exited <- setdiff(fold_state$frozen_set, frozen_now)
    if (length(entered) > 0L) {
      add_segment(list(
        n = length(entered), instrument_id = entered, stage = "valuation",
        outcome = "frozen", reason_code = "valuation_frozen",
        quantity = full_positions[entered], price = valuation$mark[entered],
        mark_source = valuation$source[entered], mark_age = valuation$age[entered],
        position_before = full_positions[entered], position_after = full_positions[entered]
      ))
    }
    if (length(exited) > 0L) {
      exit_source <- as.character(valuation$source[exited])
      exit_source[is.na(exit_source)] <- ""
      add_segment(list(
        n = length(exited), instrument_id = exited, stage = "valuation",
        outcome = "exited", reason_code = "valuation_freeze_exited",
        quantity = full_positions[exited], price = as.numeric(valuation$mark[exited]),
        mark_source = exit_source, mark_age = as.integer(valuation$age[exited]),
        position_before = full_positions[exited], position_after = full_positions[exited]
      ))
    }
    fold_state$frozen_set <- frozen_now
    if (!identical(context_ids, fold_state$state_axis)) {
      fold_state$state_prev <- ledgr_fold_asset_state_normalize(
        fold_state$state_prev,
        context_ids,
        drop_exited = TRUE
      )
      fold_state$state_axis <- context_ids
    }
  }
  if (sample_telemetry) {
    sample_now <- ledgr_time_now()
    t_feats <- ledgr_time_elapsed(sample_start, sample_now)
    sample_start <- sample_now
  } else {
    t_feats <- 0
  }

  position_qty <- as.numeric(fold_state$positions)
  active_positions <- position_qty != 0
  positions_value <- if (any(active_positions)) {
    if (services$availability_active) {
      # The valuation reduction keeps run order: marks are scattered from the
      # context axis onto the run axis, so a holding off the context has no
      # mark, then the products are summed in run order.
      run_mark <- rep(NA_real_, length(position_qty))
      run_mark[view_columns$context_pos] <- view_columns$mark
      sum(position_qty[active_positions] * run_mark[active_positions])
    } else {
      sum(
        position_qty[active_positions] *
          services$bars_mat$close[active_positions, pulse_idx]
      )
    }
  } else {
    0
  }
  # The decision packet (P1 -> P5), the decision data (P2 only) and the
  # private execution packet (P3 only), built once the pulse is valued.
  # Dense emits none of them and joins at the normalized decision (Synthesis
  # Section 4, producer scope).
  packet <- NULL
  data <- NULL
  execution <- NULL
  if (services$availability_active) {
    fold_state$last_fully_valued <- ts
    services$equity_fact_accumulator$append(list(
      ts_utc = ts,
      cash = fold_state$cash,
      positions_value = positions_value,
      realized_pnl = fold_state$lot_state$realized_pnl,
      cost_basis = fold_state$lot_state$total_cost_basis
    ))
    n_run <- length(services$instrument_ids)
    context_pos <- view_columns$context_pos
    packet <- ledgr_carrier_packet(c(
      list(pulse_idx = as.integer(pulse_idx), ts = as.numeric(ts)),
      view_columns["context_pos"],
      list(
        cash = as.numeric(fold_state$cash),
        positions_value = as.numeric(positions_value),
        position = fold_state$positions[context_pos]
      ),
      view_columns[-1L]
    ), "decision_packet", n_run)
    # The current bar gathered onto the context axis; its locator is the run
    # row and the prepared pulse column it was read from.
    current <- history_bars$current
    data <- ledgr_carrier_packet(list(
      open = current$open[context_pos],
      high = current$high[context_pos],
      low = current$low[context_pos],
      close = current$close[context_pos],
      volume = current$volume[context_pos],
      observed = current$observed[context_pos],
      source_row = context_pos,
      source_column = services$history_reader$pulse_columns[[pulse_idx]],
      history = history_view
    ), "decision_data", n_run)
    # The next bar on the run axis, explicitly absent (has_next FALSE, all
    # NA) beyond the prepared sessions; a carry window's final pulse reads
    # its continuation column through the reader's next_bar.
    next_bar <- history_bars$next_bar
    has_next <- !is.null(next_bar)
    absent <- rep(NA_real_, n_run)
    opportunities <- services$execution_opportunities_posix
    execution <- ledgr_carrier_packet(list(
      exec_ts = if (pulse_idx <= length(opportunities)) as.numeric(opportunities[[pulse_idx]]) else NA_real_,
      has_next = has_next,
      open = if (has_next) next_bar$open else absent,
      high = if (has_next) next_bar$high else absent,
      low = if (has_next) next_bar$low else absent,
      close = if (has_next) next_bar$close else absent,
      volume = if (has_next) next_bar$volume else absent
    ), "execution_packet", n_run)
  }
  if (is.function(services$output_handler$record_equity_fact)) {
    services$output_handler$record_equity_fact(
      ts_utc = ts,
      cash = fold_state$cash,
      positions_value = positions_value,
      realized_pnl = fold_state$lot_state$realized_pnl,
      cost_basis = fold_state$lot_state$total_cost_basis
    )
  }
  if (sample_telemetry) {
    sample_now <- ledgr_time_now()
    t_bars <- ledgr_time_elapsed(sample_start, sample_now)
    sample_start <- sample_now
  } else {
    t_bars <- 0
  }
  list(
    observation = list(
      pulse_idx = pulse_idx,
      ts = ts,
      ts_iso = ts_iso,
      positions_value = positions_value,
      packet = packet,
      data = data,
      sample_start = sample_start,
      t_feats = t_feats,
      t_bars = t_bars
    ),
    execution = execution
  )
}

# A scheduled skip holds every context position: the decision is the
# packet's positions on its own context axis, with no actionable ordinal.
# Held positions marked from a stale or frozen close are evidenced.
ledgr_fold_scheduled_skip_decision <- function(fold_state, services, observation) {
  packet <- observation$packet
  position <- packet$position
  mark_source <- ledgr_carrier_mark_source_text(packet$mark_source)
  evidenced <- which(position != 0 & mark_source %in% c("stale_close", "frozen_close"))
  diagnostic_segments <- if (length(evidenced) == 0L) {
    list()
  } else {
    list(list(
      n = length(evidenced),
      instrument_id = services$instrument_ids[packet$context_pos[evidenced]],
      stage = "valuation",
      outcome = "marked",
      reason_code = "",
      reasons = "",
      quantity = position[evidenced],
      price = packet$mark[evidenced],
      mark_source = mark_source[evidenced],
      mark_age = packet$mark_age[evidenced],
      position_before = position[evidenced],
      position_after = position[evidenced]
    ))
  }
  decision <- ledgr_carrier_decision(list(
    context_pos = packet$context_pos,
    strategy_qty = position,
    target_qty = position,
    actionable_k = integer(),
    state_update = NULL,
    intent_reason = NULL
  ), length(services$instrument_ids))
  c(decision, list(
    diagnostic_segments = diagnostic_segments,
    sample_start = observation$sample_start,
    t_ctx = 0,
    t_strat = 0,
    t_target = 0
  ))
}

# A scheduled skip plans nothing: its typed plan is empty, declares no
# economic event kind and expects the fold cash unchanged.
ledgr_fold_scheduled_skip_plan <- function(fold_state, decision) {
  none <- integer()
  empty <- numeric()
  batch <- ledgr_carrier_plan(
    list(
      expected_final_cash = fold_state$cash,
      economic_event_kinds = none,
      fill = list(k = none, pos = none, side = none, qty = empty, price = empty, fee = empty,
        cash_delta = empty, position_delta = empty, exec_ts = empty, position_before = empty,
        planned_position_after = empty, info_offset = none, info_count = none, info_code = none),
      rejection = list(k = none, pos = none, emit = none, primary = none, reason_offset = none,
        reason_count = none, reason_code = none, resolved_price = empty, exec_ts = empty, position = empty)
    ),
    decision$context_pos, none, length(fold_state$positions)
  )
  list(
    batch = batch,
    diagnostic_segments = list(),
    sample_start = decision$sample_start,
    t_target = 0,
    t_fill = 0
  )
}

ledgr_fold_stage_decide <- function(
    fold_state,
    services,
    observation,
    sample_telemetry,
    sample_start) {
  pulse_idx <- observation$pulse_idx
  ts <- observation$ts
  ts_iso <- observation$ts_iso
  packet <- observation$packet
  add_segment <- function(segment) {
    fold_state$pending_segments[[length(fold_state$pending_segments) + 1L]] <- segment
    invisible(NULL)
  }

  projection_idx <- services$projection_pulse_idx[[pulse_idx]]
  # P2 input: the decision axis and the public context's views. Context
  # ordinal k is run position context_pos[k]; dense keeps its frozen views on
  # the identity axis (Synthesis 3.1, Q1). P2 receives no execution packet.
  p2 <- NULL
  if (services$availability_active) {
    context_pos <- packet$context_pos
    position <- packet$position
    context_ids <- services$instrument_ids[context_pos]
    p2 <- ledgr_carrier_p2_input(packet, context_ids)
    data <- observation$data
    bars_current <- ledgr_history_bar_packet_frame(list(
      ts_utc = ts, instrument_id = context_ids, open = data$open, high = data$high,
      low = data$low, close = data$close, volume = data$volume, observed = data$observed
    ))
  } else {
    context_pos <- seq_along(services$instrument_ids)
    position <- fold_state$positions
    context_ids <- services$instrument_ids
    bars_current <- services$bars_views[[pulse_idx]]
  }
  positions_snapshot <- ledgr_fold_positions_snapshot(position, context_ids)
  # The long feature table is the schema-only frame the context contract
  # allows on the availability path; accessors and the wide view carry values.
  features_current <- if (services$availability_active) {
    services$empty_feature_table
  } else {
    services$feature_table_views[[pulse_idx]]
  }
  if (!is.data.frame(features_current)) {
    features_current <- services$empty_feature_table
  }
  features_wide_current <- if (services$availability_active) {
    ledgr_projection_features_wide(
      services$runtime_projection,
      projection_idx,
      feature_ids = services$def_ids
    )
  } else {
    services$features_wide_views[[pulse_idx]]
  }
  if (!is.data.frame(features_wide_current)) {
    features_wide_current <- services$empty_df
  }
  if (services$availability_active) {
    if (nrow(features_current) > 0L) {
      features_current <- features_current[
        as.character(features_current$instrument_id) %in% context_ids,
        ,
        drop = FALSE
      ]
    }
    if (nrow(features_wide_current) > 0L &&
        "instrument_id" %in% names(features_wide_current)) {
      features_wide_current <- features_wide_current[
        as.character(features_wide_current$instrument_id) %in% context_ids,
        ,
        drop = FALSE
      ]
    }
  }

  ctx <- list(
    run_id = services$run_id,
    ts_utc = ts_iso,
    universe = context_ids,
    bars = bars_current,
    feature_table = features_current,
    .positions = positions_snapshot,
    cash = fold_state$cash,
    equity = fold_state$cash + observation$positions_value,
    seed = services$execution_seed,
    pulse_seed = ledgr_pulse_seed_at(services, pulse_idx),
    state_prev = fold_state$state_prev,
    .safety_state = "GREEN"
  )
  if (services$availability_active) {
    ctx$availability_active <- TRUE
    ctx$members <- p2$members
    ctx$.history <- observation$data$history
  } else {
    ctx$members <- context_ids
  }
  class(ctx) <- "ledgr_pulse_context"
  ctx <- if (!is.null(services$fast_context) &&
      !services$availability_active) {
    ledgr_update_fast_pulse_context_helpers(
      ctx,
      fast_context = services$fast_context,
      bars = bars_current,
      features = features_current,
      features_wide = features_wide_current,
      positions = positions_snapshot,
      universe = services$instrument_ids,
      pulse_idx = pulse_idx,
      active_alias_map = services$active_alias_map,
      id_to_idx = services$id_to_idx,
      scalar_access_state = services$scalar_access_state,
      dense_planes = services$dense_planes
    )
  } else {
    ledgr_update_pulse_context_helpers(
      ctx,
      bars = bars_current,
      features = features_current,
      positions = positions_snapshot,
      universe = context_ids,
      projection = services$runtime_projection,
      pulse_idx = if (services$availability_active) projection_idx else pulse_idx,
      feature_ids = services$def_ids,
      features_wide = features_wide_current,
      active_alias_map = services$active_alias_map,
      feature_name_state = services$availability_feature_name_state,
      feature_lookup_state = services$availability_feature_lookup_state,
      id_to_idx = if (services$availability_active) NULL else services$id_to_idx,
      availability = p2$view,
      scalar_access_state = services$scalar_access_state,
      dense_planes = services$dense_planes
    )
  }
  if (services$availability_active) {
    ctx <- ledgr_filter_pulse_context_features(
      ctx,
      context_ids,
      services$instrument_ids
    )
  }
  if (sample_telemetry) {
    sample_now <- ledgr_time_now()
    t_ctx <- ledgr_time_elapsed(sample_start, sample_now)
    sample_start <- sample_now
  } else {
    t_ctx <- 0
  }

  services$pulse_notes$sizing_skipped <- character()
  ctx$.notes <- services$pulse_notes
  result <- tryCatch(
    {
      fold_state$current_stage <- "strategy"
      if (isTRUE(services$strategy_is_functional)) {
        ledgr_call_strategy_fn(
          services$strategy_fn,
          ctx,
          services$strategy_params,
          services$strategy_call_signature
        )
      } else {
        services$strategy_fn(ctx)
      }
    },
    error = function(e) ledgr_abort_strategy_error(e, ctx)
  )
  if (sample_telemetry) {
    sample_now <- ledgr_time_now()
    t_strat <- ledgr_time_elapsed(sample_start, sample_now)
    sample_start <- sample_now
  } else {
    t_strat <- 0
  }
  if (ledgr_is_strategy_intermediate(result)) {
    ledgr_abort_intermediate_strategy_result(result)
  }
  if (is.numeric(result)) {
    result <- list(targets = result, state_update = NULL)
  }
  if (!is.list(result) || is.null(result$targets)) {
    rlang::abort(
      sprintf(
        "Strategy must return %s or a list with `targets`.",
        ledgr_strategy_targets_contract()
      ),
      class = "ledgr_invalid_strategy_result"
    )
  }

  intent_reason <- ledgr_validate_strategy_intent_reason(result$intent_reason)

  # P2 return boundary: the strategy return is normalized once, on the
  # complete context axis; a missing or extra target is refused, never
  # filled. `targets` keeps the strategy's instrument names in context order
  # for the risk steps and the named admissibility validators; the decision
  # columns are its unnamed values.
  targets <- ledgr_validate_strategy_targets(
    result$targets,
    context_ids,
    allow_empty = services$availability_active
  )
  strategy_qty <- as.numeric(targets)
  target_qty <- strategy_qty
  if (!is.null(intent_reason)) {
    add_segment(list(
      n = 1L,
      instrument_id = "",
      stage = "decision",
      outcome = "recorded",
      reason_code = "strategy_intent",
      reasons = "strategy_intent",
      detail_json = canonical_json(list(intent_reason = intent_reason))
    ))
  }
  append_decision_trace <- function(target_after = NULL) {
    if (length(context_ids) == 0L) {
      add_segment(list(
        n = 1L,
        stage = "decision",
        outcome = "recorded",
        reason_code = "empty_public_domain"
      ))
      return(invisible(NULL))
    }
    restriction <- p2$restriction$reason
    restrictions <- p2$restriction$reasons
    reason <- ifelse(nzchar(restriction), restriction, "decision_recorded")
    reasons <- ifelse(nzchar(restrictions), restrictions, reason)
    skipped <- context_ids %in% services$pulse_notes$sizing_skipped
    if (any(skipped)) {
      reason[skipped] <- "sizing_unavailable"
      reasons[skipped] <- ifelse(
        nzchar(restrictions[skipped]),
        paste(restrictions[skipped], "sizing_unavailable", sep = "|"),
        "sizing_unavailable"
      )
    }
    add_segment(list(
      n = length(context_ids),
      instrument_id = context_ids,
      stage = "decision",
      outcome = "recorded",
      reason_code = reason,
      reasons = reasons,
      target = strategy_qty,
      quantity = position,
      price = packet$mark,
      mark_source = p2$mark_source,
      mark_age = packet$mark_age,
      target_before_risk = strategy_qty,
      target_after_risk = if (is.null(target_after)) NA_real_ else target_after,
      position_before = position,
      position_after = position
    ))
    invisible(NULL)
  }
  if (length(targets) > 0L) {
    if (services$availability_active) {
      ledgr_availability_validate_strategy_targets(
        targets,
        positions_snapshot,
        p2$view
      )
      new_positive <- strategy_qty > position & strategy_qty > 0 & !packet$permissible
      if (any(new_positive)) {
        append_decision_trace()
        stopped <- which(new_positive)
        stopped_ids <- context_ids[stopped]
        affected <- ledgr_availability_affected_exposure(
          stopped_ids,
          positions_snapshot,
          ledgr_carrier_p2_valuation(packet, context_ids)
        )
        affected <- c(affected, list(ts_utc = ts, specified = TRUE))
        segment <- list(
          n = length(stopped_ids),
          instrument_id = stopped_ids,
          stage = "risk",
          outcome = "stopped",
          reason_code = "risk_mark_unavailable",
          target = strategy_qty[stopped],
          quantity = position[stopped],
          mark_source = p2$mark_source[stopped],
          mark_age = packet$mark_age[stopped],
          target_before_risk = strategy_qty[stopped],
          position_before = position[stopped],
          position_after = position[stopped],
          detail_json = canonical_json(list(
            risk_step = "availability_risk_mark_gate"
          ))
        )
        return(ledgr_fold_stop_result(
          status = "INCOMPLETE",
          reason_code = "risk_mark_unavailable",
          affected_instrument_ids = stopped_ids,
          affected_exposure = affected,
          diagnostic_segments = list(segment),
          counts_processed = TRUE
        ))
      }
    }
    fold_state$current_stage <- "risk"
    # Risk applies to the normalized targets; the compiled plan was validated
    # once in E. Only the transformed quantities are checked again (dynamic
    # mark and equity checks stay inside the risk steps).
    risked <- ledgr_apply_risk_plan(targets, services$risk_plan, ctx)
    target_qty <- ledgr_validate_post_risk_quantities(risked, length(context_ids))
    if (services$availability_active) {
      ledgr_availability_validate_post_risk(risked, targets)
      ledgr_availability_validate_short_exposure(risked, positions_snapshot)
    }
  }
  if (services$availability_active) {
    append_decision_trace(target_qty)
    stale <- which(
      packet$permissible &
        !is.na(packet$mark_age) &
        packet$mark_age > 0L &
        (position != 0 | target_qty != 0)
    )
    if (length(stale) > 0L) {
      reduced <- vapply(stale, function(k) {
        !isTRUE(all.equal(target_qty[[k]], strategy_qty[[k]]))
      }, logical(1))
      add_segment(list(
        n = length(stale), instrument_id = context_ids[stale], stage = "risk",
        outcome = ifelse(reduced, "reduced", "passed"),
        reason_code = ifelse(
          reduced,
          "stale_mark_reduction",
          "stale_mark_pass_through"
        ),
        target = target_qty[stale],
        quantity = position[stale],
        price = packet$mark[stale],
        mark_source = p2$mark_source[stale],
        mark_age = packet$mark_age[stale],
        target_before_risk = strategy_qty[stale],
        target_after_risk = target_qty[stale],
        position_before = position[stale],
        position_after = position[stale]
      ))
    }
  }
  if (sample_telemetry) {
    sample_now <- ledgr_time_now()
    t_target <- ledgr_time_elapsed(sample_start, sample_now)
    sample_start <- sample_now
  } else {
    t_target <- 0
  }
  # The decision group on the context axis; context_pos is its only bridge
  # to the run axis. Actionable ordinals are the context ordinals whose
  # post-risk target moves the position beyond sqrt(eps).
  decision <- ledgr_carrier_decision(list(
    context_pos = context_pos,
    strategy_qty = strategy_qty,
    target_qty = target_qty,
    actionable_k = which(abs(target_qty - position) > sqrt(.Machine$double.eps)),
    state_update = result$state_update,
    intent_reason = intent_reason
  ), length(services$instrument_ids))
  c(decision, list(
    sample_start = sample_start,
    t_ctx = t_ctx,
    t_strat = t_strat,
    t_target = t_target
  ))
}

ledgr_fold_stage_plan <- function(
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
  # The decision columns live on the context axis; context_pos is the only
  # bridge to the run axis. The planners return the typed plan (Synthesis
  # 3.3): one row per actionable context ordinal, as fills and rejections.
  context_pos <- decision$context_pos
  target_qty <- decision$target_qty
  strategy_qty <- decision$strategy_qty
  position <- as.numeric(fold_state$positions[context_pos])
  actionable_k <- decision$actionable_k
  instrument_ids <- services$instrument_ids
  # Execution epochs were validated once in E from the opportunity axis.
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
  batch <- if (services$availability_active) {
    exec_ts <- execution$exec_ts
    execution_view <- if (!is.na(exec_ts) && length(actionable_k) > 0L) {
      ledgr_carrier_execution_view(
        services$availability_provider,
        exec_ts,
        instrument_ids[context_pos[actionable_k]]
      )
    }
    ledgr_fold_build_availability_pulse_plan(
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
  } else {
    has_next <- pulse_idx < length(services$pulses_posix)
    plan <- ledgr_fold_build_pulse_plan(
      context_pos = context_pos,
      target_qty = target_qty,
      position = position,
      actionable_k = actionable_k,
      pulse_idx = pulse_idx,
      has_next = has_next,
      exec_ts = if (has_next) epochs[[pulse_idx]] else NA_real_,
      epoch_valid = epoch_valid,
      bars_mat = services$bars_mat,
      cost_resolver = services$cost_resolver,
      n_run = length(instrument_ids)
    )
    ledgr_fold_apply_net_feasibility_noop(
      plan,
      ledgr_carrier_settlement_state(fold_state, instrument_ids)
    )
  }
  # Unsupported kinds refuse here, before any mutation.
  kinds <- ledgr_fold_plan_event_kinds(
    batch,
    canonical_event_kinds = if (services$use_compiled_spot_fifo) NULL else 1:2
  )
  if (services$use_compiled_spot_fifo) {
    ledgr_require_compiled_spot_fifo_event_kinds(kinds)
  }
  if (sample_telemetry) {
    sample_now <- ledgr_time_now()
    t_fill <- ledgr_time_elapsed(sample_start, sample_now)
    sample_start <- sample_now
  } else {
    t_fill <- 0
  }

  segments <- list()
  add_segment <- function(segment) {
    segments[[length(segments) + 1L]] <<- segment
    invisible(NULL)
  }
  if (services$availability_active) {
    fill <- batch$fill
    rejection <- batch$rejection
    # The reconciliation sum reuses the fills' computed cash effects.
    recorded_final_cash <- fold_state$cash + sum(fill$cash_delta)
    if (!isTRUE(all.equal(
      as.numeric(recorded_final_cash),
      as.numeric(batch$expected_final_cash),
      tolerance = ledgr_availability_cash_tolerance
    ))) {
      affordability_detail <- canonical_json(list(
        cash_before = fold_state$cash,
        virtual_final_cash = batch$expected_final_cash,
        recorded_final_cash = recorded_final_cash
      ))
      add_segment(list(
        n = 1L,
        stage = "affordability",
        outcome = "stopped",
        reason_code = "affordability_reconciliation_failed",
        detail_json = affordability_detail
      ))
      return(ledgr_fold_stop_result(
        status = "INCOMPLETE",
        reason_code = "affordability_reconciliation_failed",
        affected_instrument_ids = character(),
        affected_exposure = fold_state$affected_exposure,
        diagnostic_segments = segments,
        counts_processed = TRUE
      ))
    }
    # The reason text is built here, at the diagnostic boundary.
    if (length(rejection$k) > 0L) {
      reasons <- ledgr_carrier_segment_text(rejection$reason_offset, rejection$reason_count,
        rejection$reason_code, .ledgr_plan_reason_levels)
      add_segment(list(
        n = length(rejection$k), instrument_id = instrument_ids[rejection$pos],
        stage = "execution", outcome = "no_fill",
        reason_code = .ledgr_plan_reason_levels[rejection$primary],
        reasons = reasons$reasons,
        target = target_qty[rejection$k],
        quantity = rejection$position,
        price = rejection$resolved_price,
        decision_ts_utc = ts,
        execution_ts_utc = rejection$exec_ts,
        target_before_risk = strategy_qty[rejection$k],
        target_after_risk = target_qty[rejection$k],
        position_before = rejection$position,
        position_after = rejection$position
      ))
    }
    if (length(fill$k) > 0L) {
      # The primary of a fill row is its first informational reason or "".
      reasons <- ledgr_carrier_segment_text(fill$info_offset, fill$info_count,
        fill$info_code, .ledgr_plan_reason_levels)
      add_segment(list(
        n = length(fill$k), instrument_id = instrument_ids[fill$pos],
        stage = "execution", outcome = "filled",
        reason_code = reasons$reason,
        reasons = reasons$reasons,
        target = target_qty[fill$k],
        quantity = fill$qty,
        price = fill$price,
        decision_ts_utc = ts,
        execution_ts_utc = fill$exec_ts,
        event_seq = fold_state$event_seq + seq_along(fill$k) - 1L,
        target_before_risk = strategy_qty[fill$k],
        target_after_risk = target_qty[fill$k],
        position_before = fill$position_before,
        # The planned after-position: diagnostic evidence, not authority.
        position_after = fill$planned_position_after
      ))
    }
  }
  list(
    batch = batch,
    diagnostic_segments = segments,
    sample_start = sample_start,
    t_target = t_target,
    t_fill = t_fill
  )
}

ledgr_fold_stage_apply <- function(
    fold_state,
    services,
    observation,
    plan,
    sample_telemetry,
    sample_start) {
  fold_state$current_stage <- "accounting"
  pulse_idx <- observation$pulse_idx
  fill <- plan$batch$fill
  output_handler <- services$output_handler
  t_event <- 0
  t_state <- 0
  positions <- fold_state$positions
  cash <- fold_state$cash

  # Event emission and state mutation happen only after the private pulse plan
  # is complete. Event order still follows the validated target vector so
  # sweep and durable replay see the same canonical stream.
  if (!is.null(services$corporate_action_plan) &&
      pulse_idx < length(services$pulses_posix)) {
    services$corporate_action_plan$bind_boundary(
      pulse_idx + 1L,
      ledgr_fold_positions_snapshot(
        fold_state$positions,
        services$instrument_ids
      )
    )
  }
  if (services$use_compiled_spot_fifo) {
    if (length(fill$k) > 0L) {
      if (sample_telemetry) sample_start <- ledgr_time_now()
      # The compiled wrapper reads the fill columns.
      batch <- ledgr_run_compiled_spot_fifo_batch(
        run_id = services$run_id,
        fills = fill,
        state = list(
          cash = fold_state$cash,
          positions = fold_state$positions,
          lot_state = fold_state$lot_state
        ),
        instrument_ids = services$instrument_ids,
        event_seq_start = fold_state$event_seq
      )
      positions <- as.numeric(batch$positions)
      cash <- batch$cash
      fold_state$lot_state <- batch$lot_state
      fold_state$event_seq <- batch$next_event_seq
      if (sample_telemetry) {
        sample_now <- ledgr_time_now()
        t_state <- t_state + ledgr_time_elapsed(sample_start, sample_now)
        sample_start <- sample_now
      }
      output_handler$append_compiled_spot_batch(batch)
      if (sample_telemetry) {
        t_event <- t_event + ledgr_time_elapsed(sample_start, ledgr_time_now())
      }
    }
  } else {
    # One typed fill operation per fill row until LDG-3167 batches the
    # pulse; the instrument is the row's run-axis position.
    for (i in seq_along(fill$k)) {
      if (sample_telemetry) sample_start <- ledgr_time_now()
      pos <- fill$pos[[i]]

      lot_res <- ledgr_lot_fill(
        fold_state$lot_state,
        pos = pos,
        side = fill$side[[i]],
        qty = fill$qty[[i]],
        price = fill$price[[i]],
        fee = fill$fee[[i]]
      )
      fold_state$lot_state <- lot_res$book
      if (sample_telemetry) {
        sample_now <- ledgr_time_now()
        t_state <- t_state + ledgr_time_elapsed(sample_start, sample_now)
        sample_start <- sample_now
      }

      write_res <- output_handler$write_fill_events(
        fill = fill,
        i = i,
        instrument_id = services$instrument_ids[[pos]],
        event_seq = fold_state$event_seq,
        use_transaction = identical(services$event_mode, "live")
      )
      fold_state$event_seq <- write_res$next_event_seq
      if (is.function(output_handler$record_accounting_fact)) {
        output_handler$record_accounting_fact(
          write_res = write_res,
          applied = lot_res$applied
        )
      }
      if (sample_telemetry) {
        sample_now <- ledgr_time_now()
        t_event <- t_event + ledgr_time_elapsed(sample_start, sample_now)
        sample_start <- sample_now
      }

      # Lots alone determine the position; cash adds P3's computed effect.
      positions[[pos]] <- lot_res$book$net_by_inst[[pos]]
      cash <- cash + fill$cash_delta[[i]]
      if (sample_telemetry) {
        t_state <- t_state + ledgr_time_elapsed(sample_start, ledgr_time_now())
      }
    }
  }
  fold_state$positions <- positions
  fold_state$cash <- cash
  list(
    sample_start = sample_start,
    t_event = t_event,
    t_state = t_state
  )
}

ledgr_fold_stage_commit <- function(
    fold_state,
    services,
    observation,
    decision,
    plan,
    apply,
    sample_telemetry,
    pulse_start) {
  output_handler <- services$output_handler
  batch <- plan$batch
  ts <- observation$ts
  ts_iso <- observation$ts_iso
  packet <- observation$packet
  # The decision's context axis, named by run position for the state
  # normalization boundary.
  context_pos <- decision$context_pos
  context_ids <- services$instrument_ids[context_pos]
  state_update <- decision$state_update
  sample_start <- apply$sample_start
  t_state <- apply$t_state

  if (is.function(output_handler$flush_pulse_events)) {
    output_handler$flush_pulse_events()
  }

  if (services$availability_active) {
    fill <- batch$fill
    if (length(fill$k) > 0L) {
      fill_times <- as.POSIXct(fill$exec_ts, origin = "1970-01-01", tz = "UTC")
      fold_state$last_executed <- max(
        c(fold_state$last_executed, fill_times),
        na.rm = TRUE
      )
    }
    if (!isTRUE(all.equal(
      as.numeric(fold_state$cash),
      as.numeric(batch$expected_final_cash),
      tolerance = ledgr_availability_cash_tolerance
    ))) {
      rlang::abort(
        "Recorded cash does not reconcile with the availability affordability ledger.",
        class = c(
          "ledgr_affordability_reconciliation_failed",
          "ledgr_invalid_fold_execution"
        )
      )
    }
    # Gross exposures at the decision marks, each on the context axis.
    actual_positions <- fold_state$positions[context_pos]
    reconciliation_detail <- canonical_json(list(
      cash_before = fold_state$cash - sum(fill$cash_delta),
      virtual_final_cash = batch$expected_final_cash,
      recorded_final_cash = fold_state$cash,
      intended_gross_exposure = ledgr_availability_marked_gross(
        decision$strategy_qty,
        packet$mark
      ),
      post_risk_gross_exposure = ledgr_availability_marked_gross(
        decision$target_qty,
        packet$mark
      ),
      actual_gross_exposure = ledgr_availability_marked_gross(
        actual_positions,
        packet$mark
      ),
      exposure_basis = "decision_mark_gross"
    ))
    fold_state$pending_segments[[length(fold_state$pending_segments) + 1L]] <-
      list(
        n = 1L,
        stage = "reconciliation",
        outcome = "reconciled",
        reason_code = "affordability_reconciled",
        detail_json = reconciliation_detail
      )
    ledgr_fold_flush_pulse_block(
      fold_state,
      services$diagnostic_writer,
      services$run_id,
      ts
    )
  }
  if (length(fold_state$pending_segments) > 0L) {
    ledgr_fold_flush_pulse_block(
      fold_state,
      services$diagnostic_writer,
      services$run_id,
      ts
    )
  }

  if (services$availability_active) {
    if (is.null(state_update)) {
      # The carried state is already normalized for this pulse's axis.
      state_update <- fold_state$state_prev
    } else {
      state_update <- ledgr_fold_asset_state_normalize(state_update, context_ids)
    }
    fold_state$state_axis <- context_ids
  }
  if (!is.null(state_update)) {
    if (sample_telemetry) sample_start <- ledgr_time_now()
    # Serialised every pulse: the state object reaches user code, which may
    # change it in place, so no comparison with an earlier object is safe.
    state_json <- canonical_json(state_update)
    fold_state$state_prev <- state_update
    if (identical(services$event_mode, "live")) {
      output_handler$write_strategy_state(ts_utc = ts_iso, state_json = state_json)
    } else {
      output_handler$buffer_strategy_state(ts_utc = ts_iso, state_json = state_json)
    }
    if (sample_telemetry) {
      t_state <- t_state + ledgr_time_elapsed(sample_start, ledgr_time_now())
    }
  }

  fold_state$processed <- fold_state$processed + 1L

  if (services$telemetry_stride > 0L &&
      fold_state$processed %% services$telemetry_stride == 0L) {
    fold_state$telemetry_idx <- fold_state$telemetry_idx + 1L
    idx <- fold_state$telemetry_idx
    telemetry <- services$telemetry
    telemetry$t_pulse[[idx]] <- ledgr_time_elapsed(pulse_start, ledgr_time_now())
    telemetry$t_bars[[idx]] <- observation$t_bars
    telemetry$t_ctx[[idx]] <- decision$t_ctx
    telemetry$t_fill[[idx]] <- plan$t_fill
    telemetry$t_state[[idx]] <- t_state
    telemetry$t_feats[[idx]] <- observation$t_feats
    telemetry$t_strat[[idx]] <- decision$t_strat
    telemetry$t_target[[idx]] <- plan$t_target
    telemetry$t_event[[idx]] <- apply$t_event
    telemetry$t_exec[[idx]] <-
      plan$t_target + plan$t_fill + apply$t_event + t_state
  }

  if (services$checkpoint_every > 0L &&
      fold_state$processed %% services$checkpoint_every == 0L &&
      !identical(services$event_mode, "live") &&
      (output_handler$pending_event_count() > 0L ||
       output_handler$pending_state_count() > 0L)) {
    output_handler$flush_pending()
  }

  continue <- TRUE
  if (fold_state$processed >= services$max_pulses) {
    fold_state$full_run <- FALSE
    continue <- FALSE
  }
  if (isTRUE(getOption("ledgr.interrupt", FALSE))) {
    fold_state$full_run <- FALSE
    continue <- FALSE
  }
  list(continue = continue)
}

ledgr_execute_fold <- function(execution, output_handler) {
  ledgr_fold_envelope(execution, output_handler)
}

ledgr_fold_envelope <- function(execution, output_handler) {
  execution <- ledgr_validate_execution_spec(execution)
  run_id <- execution$run_id
  instrument_ids <- execution$instrument_ids
  id_to_idx <- execution$id_to_idx
  strategy_fn <- execution$strategy_fn
  strategy_params <- execution$strategy_params
  strategy_call_signature <- execution$strategy_call_signature
  strategy_is_functional <- isTRUE(execution$strategy_is_functional)
  pulses_posix <- execution$pulses_posix
  pulses_iso <- execution$pulses_iso
  start_idx <- execution$start_idx
  max_pulses <- execution$max_pulses
  checkpoint_every <- execution$checkpoint_every
  telemetry_stride <- execution$telemetry_stride
  state <- ledgr_carrier_import_state(execution$state, instrument_ids)
  bars_by_id <- execution$bars_by_id
  bars_mat <- execution$bars_mat
  history_substrate <- execution$history_substrate
  feature_defs <- execution$feature_defs
  runtime_projection <- if (!is.null(execution$availability_provider)) {
    history_substrate$feature_projection
  } else {
    execution$runtime_projection
  }
  if (is.null(runtime_projection)) {
    rlang::abort("Fold execution requires `runtime_projection`.", class = "ledgr_invalid_fold_execution")
  }
  active_alias_map <- ledgr_normalize_alias_map(execution$active_alias_map)
  risk_plan <- ledgr_risk_validate_compiled_plan(execution$risk_plan)
  cost_resolver <- execution$cost_resolver
  telemetry <- execution$telemetry
  execution_seed <- execution$seed
  # Rule v2 pulse seeds on the run's own calendar, computed once per seeded
  # fold and read by index; an unseeded fold builds no vector. Resume reads
  # from `start_idx` on the same calendar.
  pulse_seeds <- NULL
  if (!is.null(execution_seed)) {
    # The enforcing point of the pinned kind (decision (1)).
    rng_state <- ledgr_rng_caller_state()
    on.exit(ledgr_rng_restore(rng_state), add = TRUE)
    ledgr_rng_seed_pinned(as.integer(execution_seed))
    pulse_seeds <- ledgr_pulse_seeds(execution_seed, seq_len(length(pulses_posix)))
  }
  event_mode <- execution$event_mode
  use_fast_context <- isTRUE(execution$use_fast_context)
  compiled_accounting_model <- ledgr_normalize_compiled_accounting_model(
    execution$compiled_accounting_model
  )
  use_compiled_spot_fifo <- identical(compiled_accounting_model, "spot_fifo")
  availability_provider <- execution$availability_provider
  availability_active <- !is.null(availability_provider)
  history_reader <- if (availability_active) {
    ledgr_history_substrate_fold_reader(
      history_substrate,
      pulses_posix,
      feature_defs = feature_defs,
      active_alias_map = active_alias_map
    )
  } else {
    NULL
  }
  execution_opportunities_posix <- execution$execution_opportunities_posix
  # The prepared opportunity axis: a pulse's fills execute at its entry (the
  # declared next-session opening, or the next pulse). Its epochs are
  # validated once here, not per fill (Synthesis 3.3).
  execution_epochs <- as.numeric(execution_opportunities_posix %||% pulses_posix[-1L])
  execution_epoch_valid <- ledgr_plan_epoch_valid(execution_epochs)
  corporate_action_plan <- execution$corporate_action_plan
  max_stale_sessions <- if (availability_active) {
    as.integer(availability_provider$valuation_policy$max_sessions)
  } else {
    NA_integer_
  }
  valuation_state <- if (availability_active) {
    ledgr_availability_valuation_state(
      history_substrate$bars,
      instrument_ids,
      history_substrate$axis,
      max_stale_sessions,
      ledgr_availability_exhausted_choice(availability_provider$valuation_policy),
      pulse_columns = history_reader$pulse_columns
    )
  } else {
    NULL
  }
  if (use_compiled_spot_fifo) {
    ledgr_require_compiled_spot_fifo_dispatch(execution, output_handler)
    if (!is.null(corporate_action_plan)) {
      ledgr_require_compiled_spot_fifo_event_kinds(
        corporate_action_plan$event_kinds()
      )
    }
  }

  max_events <- max(1L, length(pulses_posix) * length(instrument_ids))
  output_handler$init_buffers(max_events)

  empty_df <- data.frame()
  n_def <- length(feature_defs)
  def_ids <- if (n_def > 0L) {
    vapply(feature_defs, function(def) def$id, character(1))
  } else {
    character()
  }
  n_inst <- length(instrument_ids)

  bars_views <- if (availability_active) NULL else execution$static_bars_views
  if (!availability_active && is.null(bars_views)) {
    bars_views <- ledgr_bars_pulse_views(
      bars_mat = bars_mat,
      instrument_ids = instrument_ids,
      pulses_posix = pulses_posix
    )
  }
  feature_views <- if (availability_active) NULL else execution$static_feature_views
  if (!availability_active && is.null(feature_views)) {
    feature_views <- ledgr_projection_pulse_views(
      runtime_projection,
      feature_ids = def_ids
    )
  }
  feature_table_views <- feature_views$feature_table %||% vector("list", length(pulses_posix))
  features_wide_views <- feature_views$features_wide %||% vector("list", length(pulses_posix))
  if ((!availability_active && length(bars_views) != length(pulses_posix)) ||
      (!availability_active && length(feature_table_views) != length(pulses_posix)) ||
      (!availability_active && length(features_wide_views) != length(pulses_posix))) {
    rlang::abort("Static pulse views must align with fold pulse timestamps.", class = "ledgr_invalid_fold_execution")
  }

  empty_feature_table <- if (n_def > 0L) {
    ledgr_projection_feature_table(runtime_projection, 1L, feature_ids = character())
  } else {
    empty_df
  }
  projection_pulse_idx <- unname(runtime_projection$pulse_index[
    ledgr_projection_pulse_names(pulses_posix)
  ])
  if (anyNA(projection_pulse_idx)) {
    rlang::abort(
      "Runtime projection must cover every fold pulse.",
      class = "ledgr_invalid_fold_execution"
    )
  }

  last_fully_valued_ts <- as.POSIXct(NA, tz = "UTC")
  last_executed_ts <- as.POSIXct(NA, tz = "UTC")
  # A resumed availability run continues the prefix committed with its strategy
  # state: every pulse before start_idx was valued, and its last fill is in the
  # ledger. The completion row then covers the whole run, not only this
  # invocation, even when the first resumed pulse stops.
  if (availability_active && start_idx > 1L) {
    last_fully_valued_ts <- as.POSIXct(pulses_posix[[start_idx - 1L]], tz = "UTC")
  }
  if (!is.null(execution$last_executed_at_resume)) {
    last_executed_ts <- execution$last_executed_at_resume
  }
  affected <- list(
    value = NA_real_,
    details = list(),
    ts_utc = as.POSIXct(NA, tz = "UTC"),
    specified = FALSE
  )
  fold_state <- ledgr_fold_state_new(
    cash = state$cash,
    positions = state$positions,
    lot_state = state$lot_state,
    state_prev = execution$state_prev,
    event_seq = as.integer(execution$event_seq_start),
    affected_exposure = affected,
    last_fully_valued = last_fully_valued_ts,
    last_executed = last_executed_ts,
    frozen_set = as.character(execution$frozen_at_resume %||% character()),
    telemetry_idx = as.integer(telemetry$telemetry_samples %||% 0L)
  )
  equity_fact_accumulator <- ledgr_fold_equity_fact_accumulator(
    if (availability_active) length(pulses_posix) else 0L
  )
  diagnostic_writer <- ledgr_fold_diagnostic_writer(run_id, output_handler)
  # Each pulse accumulates typed diagnostic segments in emission order and
  # appends one bounded block through the production writer.
  add_segment <- function(segment) {
    fold_state$pending_segments[[length(fold_state$pending_segments) + 1L]] <- segment
    invisible(NULL)
  }
  flush_pulse_block <- function(ts) {
    ledgr_fold_flush_pulse_block(
      fold_state,
      diagnostic_writer,
      run_id,
      ts
    )
  }
  fast_context <- if (isTRUE(use_fast_context) && !availability_active) {
    ledgr_fast_context_state(
      universe = instrument_ids,
      projection = runtime_projection,
      feature_ids = def_ids,
      active_alias_map = active_alias_map
    )
  } else {
    NULL
  }
  availability_feature_name_state <- if (
    availability_active && !is.null(runtime_projection)
  ) {
    ledgr_projection_feature_name_state(
      runtime_projection,
      feature_ids = def_ids,
      active_alias_map = active_alias_map
    )
  } else {
    NULL
  }
  # The physical axis is fixed for the run. Build its hashed instrument
  # lookups once; the changing decision axis is checked by the pulse lookup.
  availability_feature_lookup_state <- if (
    availability_active && !is.null(runtime_projection)
  ) {
    ledgr_projection_feature_lookup_state(
      runtime_projection,
      feature_ids = def_ids,
      universe = instrument_ids,
      active_alias_map = active_alias_map,
      feature_name_state = availability_feature_name_state
    )
  } else {
    NULL
  }
  scalar_access_state <- if (length(instrument_ids) >= 100L) {
    ledgr_pulse_context_scalar_access_state()
  } else {
    NULL
  }
  # A dense axis never changes during a run, so its eligibility planes are
  # prepared once here and shared by every pulse's context.
  dense_planes <- if (availability_active) NULL else ledgr_dense_eligibility_planes(length(instrument_ids))

  # Terminal and freeze handling (terminal-outcomes synthesis sections 3.1 to
  # 3.4). Current configs always carry the decoded policy.
  terminal_policy <- execution$corporate_action_policy
  pulse_notes <- new.env(parent = emptyenv())
  services <- list(
    run_id = run_id,
    instrument_ids = instrument_ids,
    id_to_idx = id_to_idx,
    bars_mat = bars_mat,
    bars_views = bars_views,
    history_reader = history_reader,
    feature_table_views = feature_table_views,
    features_wide_views = features_wide_views,
    empty_df = empty_df,
    empty_feature_table = empty_feature_table,
    runtime_projection = runtime_projection,
    projection_pulse_idx = as.integer(projection_pulse_idx),
    def_ids = def_ids,
    active_alias_map = active_alias_map,
    risk_plan = risk_plan,
    execution_seed = execution_seed,
    pulse_seeds = pulse_seeds,
    strategy_fn = strategy_fn,
    strategy_params = strategy_params,
    strategy_call_signature = strategy_call_signature,
    strategy_is_functional = strategy_is_functional,
    availability_active = availability_active,
    availability_provider = availability_provider,
    valuation_state = valuation_state,
    corporate_action_plan = corporate_action_plan,
    terminal_policy = terminal_policy,
    output_handler = output_handler,
    fast_context = fast_context,
    availability_feature_name_state = availability_feature_name_state,
    availability_feature_lookup_state = availability_feature_lookup_state,
    scalar_access_state = scalar_access_state,
    dense_planes = dense_planes,
    pulse_notes = pulse_notes,
    execution_opportunities_posix = execution_opportunities_posix,
    execution_epochs = execution_epochs,
    execution_epoch_valid = execution_epoch_valid,
    cost_resolver = cost_resolver,
    pulses_posix = pulses_posix,
    use_compiled_spot_fifo = use_compiled_spot_fifo,
    event_mode = event_mode,
    diagnostic_writer = diagnostic_writer,
    equity_fact_accumulator = equity_fact_accumulator,
    telemetry = telemetry,
    telemetry_stride = telemetry_stride,
    checkpoint_every = checkpoint_every,
    max_pulses = max_pulses
  )
  services$decision_due <- execution$decision_due %||% NULL

  run_loop <- function() {
    if (length(pulses_posix) == 0L || start_idx > length(pulses_posix)) {
      # A resume after the last pulse values nothing new; an availability run
      # still closes with its completion row, from the seeded prefix.
      diagnostics <- diagnostic_writer$drain()
      if (availability_active && length(pulses_posix) > 0L) {
        output_handler$write_run_evidence(
          ledgr_availability_completion_row(
            run_id = run_id,
            pulses_posix = pulses_posix,
            status = fold_state$status,
            stop_reason = fold_state$stop_reason,
            affected = fold_state$affected_exposure,
            last_fully_valued_ts_utc = fold_state$last_fully_valued,
            last_executed_ts_utc = fold_state$last_executed
          ),
          diagnostics
        )
      } else {
        output_handler$write_run_diagnostics(diagnostics)
      }
      diagnostic_writer$release()
      return(invisible(NULL))
    }

    if (!is.null(corporate_action_plan)) {
      corporate_action_plan$bind_boundary(
        start_idx,
        ledgr_fold_positions_snapshot(fold_state$positions, instrument_ids)
      )
    }

    for (i in seq(from = start_idx, to = length(pulses_posix))) {
      ts <- pulses_posix[[i]]
      ts_iso <- pulses_iso[[i]]
      fold_state$current_ts <- ts
      fold_state$current_stage <- "valuation"
      pulse_start <- ledgr_time_now()
      sample_telemetry <- telemetry_stride > 0L &&
        ((fold_state$processed + 1L) %% telemetry_stride == 0L)
      sample_start <- if (sample_telemetry) pulse_start else NULL

      observed <- ledgr_fold_stage_observe_settle(
        fold_state = fold_state,
        services = services,
        pulse_idx = i,
        ts = ts,
        ts_iso = ts_iso,
        sample_telemetry = sample_telemetry,
        sample_start = sample_start
      )
      if (ledgr_is_fold_stop_result(observed)) {
        fold_state$status <- observed$status
        fold_state$stop_reason <- observed$reason_code
        fold_state$affected_exposure <- observed$affected_exposure
        ledgr_fold_state_validate(fold_state)
        for (segment in observed$diagnostic_segments) {
          add_segment(segment)
        }
        if (isTRUE(observed$counts_processed)) {
          fold_state$processed <- fold_state$processed + 1L
        }
        flush_pulse_block(ts)
        break
      }
      # P2 receives the observation (decision packet and decision data);
      # the execution packet goes to P3 alone.
      observation <- observed$observation
      sample_start <- observation$sample_start

      decision_due <- is.null(services$decision_due) ||
        isTRUE(services$decision_due[[i]])
      decision_result <- if (decision_due) {
        ledgr_fold_stage_decide(
          fold_state = fold_state,
          services = services,
          observation = observation,
          sample_telemetry = sample_telemetry,
          sample_start = sample_start
        )
      } else {
        add_segment(list(
          n = 1L,
          instrument_id = "",
          stage = "decision",
          outcome = "skipped",
          reason_code = "scheduled_skip",
          reasons = "scheduled_skip",
          detail_json = "{}"
        ))
        skipped <- ledgr_fold_scheduled_skip_decision(fold_state, services, observation)
        for (segment in skipped$diagnostic_segments) {
          add_segment(segment)
        }
        skipped
      }
      if (ledgr_is_fold_stop_result(decision_result)) {
        fold_state$status <- decision_result$status
        fold_state$stop_reason <- decision_result$reason_code
        fold_state$affected_exposure <- decision_result$affected_exposure
        ledgr_fold_state_validate(fold_state)
        for (segment in decision_result$diagnostic_segments) {
          add_segment(segment)
        }
        if (isTRUE(decision_result$counts_processed)) {
          fold_state$processed <- fold_state$processed + 1L
        }
        flush_pulse_block(ts)
        break
      }
      sample_start <- decision_result$sample_start
      # The decision data (current bars, locator, history view) is P2-local:
      # P3-P5 see the decision packet only.
      observation$data <- NULL

      plan_result <- if (decision_due) {
        ledgr_fold_stage_plan(
          fold_state = fold_state,
          services = services,
          observation = observation,
          decision = decision_result,
          execution = observed$execution,
          sample_telemetry = sample_telemetry,
          sample_start = sample_start
        )
      } else {
        ledgr_fold_scheduled_skip_plan(fold_state, decision_result)
      }
      if (ledgr_is_fold_stop_result(plan_result)) {
        fold_state$status <- plan_result$status
        fold_state$stop_reason <- plan_result$reason_code
        fold_state$affected_exposure <- plan_result$affected_exposure
        ledgr_fold_state_validate(fold_state)
        for (segment in plan_result$diagnostic_segments) {
          add_segment(segment)
        }
        if (isTRUE(plan_result$counts_processed)) {
          fold_state$processed <- fold_state$processed + 1L
        }
        flush_pulse_block(ts)
        break
      }
      for (segment in plan_result$diagnostic_segments) {
        add_segment(segment)
      }
      sample_start <- plan_result$sample_start

      apply_result <- ledgr_fold_stage_apply(
        fold_state = fold_state,
        services = services,
        observation = observation,
        plan = plan_result,
        sample_telemetry = sample_telemetry,
        sample_start = sample_start
      )
      commit_result <- ledgr_fold_stage_commit(
        fold_state = fold_state,
        services = services,
        observation = observation,
        decision = decision_result,
        plan = plan_result,
        apply = apply_result,
        sample_telemetry = sample_telemetry,
        pulse_start = pulse_start
      )
      if (!isTRUE(commit_result$continue)) {
        break
      }
    }

    if (!identical(event_mode, "live") &&
        (output_handler$pending_event_count() > 0L ||
         output_handler$pending_state_count() > 0L)) {
      output_handler$flush_pending()
    }
    diagnostics <- diagnostic_writer$drain()
    if (availability_active) {
      if (isTRUE(fold_state$full_run)) {
        completion <- ledgr_availability_completion_row(
          run_id = run_id,
          pulses_posix = pulses_posix,
          status = fold_state$status,
          stop_reason = fold_state$stop_reason,
          affected = fold_state$affected_exposure,
          last_fully_valued_ts_utc = fold_state$last_fully_valued,
          last_executed_ts_utc = fold_state$last_executed
        )
        output_handler$write_run_evidence(completion, diagnostics)
      } else {
        output_handler$write_run_diagnostics(diagnostics)
      }
    } else {
      output_handler$write_run_diagnostics(diagnostics)
    }
    diagnostic_writer$release()
    invisible(NULL)
  }

  loop_start <- ledgr_time_now()
  fold_error <- tryCatch(
    {
      output_handler$run_transaction(run_loop)
      NULL
    },
    error = function(e) e
  )
  if (!is.null(fold_error)) {
    if (availability_active && is.function(output_handler$write_exception_diagnostic)) {
      reason <- as.character(fold_error$reason %||% "")
      if (!nzchar(reason)) reason <- "fold_exception"
      diagnostic <- ledgr_availability_diagnostic_row(
        run_id = run_id,
        diagnostic_seq = 1L,
        ts_utc = fold_state$current_ts,
        stage = fold_state$current_stage,
        outcome = "error",
        reason_code = reason,
        detail_json = canonical_json(list(
          condition_class = class(fold_error),
          message = conditionMessage(fold_error)
        ))
      )
      try(output_handler$write_exception_diagnostic(diagnostic), silent = TRUE)
    }
    rlang::cnd_signal(fold_error)
  }
  telemetry$t_loop <- ledgr_time_elapsed(loop_start, ledgr_time_now())
  telemetry$telemetry_samples <- fold_state$telemetry_idx

  list(
    status = fold_state$status,
    processed = fold_state$processed,
    full_run = fold_state$full_run,
    telemetry = telemetry,
    state = ledgr_carrier_result_state(fold_state, instrument_ids),
    state_prev = fold_state$state_prev,
    next_event_seq = fold_state$event_seq,
    equity_facts = equity_fact_accumulator$collect()
  )
}
