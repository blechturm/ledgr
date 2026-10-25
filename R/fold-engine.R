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

ledgr_fold_warn_final_bar_no_fill <- function(fill) {
  if (is.character(fill$warn_code) &&
      identical(fill$warn_code, "LEDGR_LAST_BAR_NO_FILL")) {
    warning(
      paste(
        "LEDGR_LAST_BAR_NO_FILL:",
        "target changed on the final available bar, but the next-open fill model requires a following bar.",
        "No fill was emitted for this target change.",
        "Check the strategy's final-pulse behavior or extend the snapshot if this trade should be fillable."
      ),
      call. = FALSE
    )
  }
  invisible(NULL)
}

ledgr_fold_build_pulse_plan <- function(targets,
                                        target_names,
                                        target_inst_idx,
                                        current_qty_vec,
                                        delta_vec,
                                        actionable_idx,
                                        pulse_idx,
                                        pulses_posix,
                                        bars_mat,
                                        cost_resolver,
                                        ts_signal_utc) {
  fills <- vector("list", length(actionable_idx))
  fill_n <- 0L
  has_next_pulse <- pulse_idx < length(pulses_posix)

  for (target_idx in actionable_idx) {
    instrument_id <- target_names[[target_idx]]
    inst_idx <- target_inst_idx[[target_idx]]
    delta <- delta_vec[[target_idx]]

    proposal <- ledgr_next_open_fill_proposal(
      desired_qty_delta = delta,
      next_open_price = if (has_next_pulse) bars_mat$open[inst_idx, pulse_idx + 1L] else NULL,
      instrument_id = instrument_id,
      ts_utc = if (has_next_pulse) pulses_posix[[pulse_idx + 1L]] else NULL,
      high = if (has_next_pulse) bars_mat$high[inst_idx, pulse_idx + 1L] else NA_real_,
      low = if (has_next_pulse) bars_mat$low[inst_idx, pulse_idx + 1L] else NA_real_,
      close = if (has_next_pulse) bars_mat$close[inst_idx, pulse_idx + 1L] else NA_real_,
      volume = if (has_next_pulse) bars_mat$volume[inst_idx, pulse_idx + 1L] else NA_real_
    )
    fill <- ledgr_resolve_fill_proposal(proposal, cost_resolver)

    if (inherits(fill, "ledgr_fill_none")) {
      ledgr_fold_warn_final_bar_no_fill(fill)
      next
    }
    if (!is.finite(fill$fill_price) || fill$fill_price <= 0) {
      next
    }

    fill$instrument_id <- instrument_id
    fill$ts_signal_utc <- ts_signal_utc
    fill$inst_idx <- inst_idx

    fill_n <- fill_n + 1L
    fills[[fill_n]] <- list(
      target_idx = as.integer(target_idx),
      instrument_id = instrument_id,
      inst_idx = as.integer(inst_idx),
      current_qty = as.numeric(current_qty_vec[[target_idx]]),
      delta = as.numeric(delta),
      fill = fill
    )
  }

  if (fill_n == 0L) {
    fills <- list()
  } else {
    fills <- fills[seq_len(fill_n)]
  }

  structure(
    list(
      targets = targets,
      actionable_idx = as.integer(actionable_idx),
      fills = fills,
      economic_event_kinds = if (length(fills) > 0L) "FILL" else character()
    ),
    class = c("ledgr_pulse_plan", "list")
  )
}

ledgr_fold_apply_net_feasibility_noop <- function(pulse_plan, state) {
  force(state)
  pulse_plan
}

ledgr_fold_pulse_plan_accounting_events <- function(pulse_plan,
                                                    canonical_event_kinds = NULL) {
  fills <- pulse_plan$fills %||% list()
  event_kinds <- unique(as.character(
    pulse_plan$economic_event_kinds %||% character()
  ))
  if (length(fills) > 0L && !"FILL" %in% event_kinds) {
    rlang::abort(
      "A pulse plan containing fills must declare the FILL economic-event kind.",
      class = c("ledgr_invalid_pulse_plan", "ledgr_invalid_fold_execution")
    )
  }
  if (!is.null(canonical_event_kinds)) {
    unsupported <- setdiff(event_kinds, canonical_event_kinds)
    if (length(unsupported) > 0L) {
      rlang::abort(
        paste0(
          "Canonical R accounting cannot execute pulse-plan economic event ",
          "kind(s): ", paste(unsupported, collapse = ", "), "."
        ),
        class = c("ledgr_invalid_pulse_plan", "ledgr_invalid_fold_execution")
      )
    }
  }
  list(fills = fills, kinds = event_kinds)
}

ledgr_fold_pulse_plan_fill_intents <- function(accounting_events) {
  lapply(accounting_events$fills, function(entry) entry$fill)
}

ledgr_fold_state_value <- function(fold_state) {
  list(
    cash = fold_state$cash,
    positions = fold_state$positions,
    lot_state = fold_state$lot_state
  )
}

ledgr_fold_state_install_value <- function(fold_state, value) {
  fold_state$cash <- value$cash
  fold_state$positions <- value$positions
  fold_state$lot_state <- value$lot_state
  invisible(NULL)
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
  history_view <- if (services$availability_active) {
    services$history_reader$view(pulse_idx)
  } else {
    NULL
  }
  add_segment <- function(segment) {
    fold_state$pending_segments[[length(fold_state$pending_segments) + 1L]] <- segment
    invisible(NULL)
  }
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
    view$priced <- valuation$priced
    view$mark_age <- valuation$age
    view$risk_mark <- valuation$mark
    view$mark_source <- valuation$source
    view <- ledgr_availability_restrict_frozen(view, valuation)
    list(
      view = view,
      valuation = valuation,
      ids = ids,
      held_ids = ids[as.logical(view$held[ids])],
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
      state_value = ledgr_fold_state_value(fold_state),
      marks = marks
    )
    ledgr_fold_state_install_value(fold_state, posted$state)
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

  availability_view <- NULL
  valuation <- NULL
  context_ids <- services$instrument_ids
  if (services$availability_active) {
    decision <- availability_decision(fold_state$positions)
    if (!is.null(services$corporate_action_plan) &&
        isTRUE(services$corporate_action_plan$has_disposition())) {
      disposed <- services$corporate_action_plan$post_disposition(
        index = pulse_idx,
        run_id = services$run_id,
        event_seq = fold_state$event_seq,
        output_handler = services$output_handler,
        state_value = ledgr_fold_state_value(fold_state),
        valuation = decision$valuation
      )
      ledgr_fold_state_install_value(fold_state, disposed$state)
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
        state_value = ledgr_fold_state_value(fold_state),
        instrument_ids = services$instrument_ids,
        exposure_mark = resolved$reference
      )
      ledgr_fold_state_install_value(fold_state, posted$state)
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

    availability_view <- decision$view
    valuation <- decision$valuation
    context_ids <- decision$ids
    full_positions <- decision$full_positions
    held_ids <- decision$held_ids
    unvalued_ids <- held_ids[!valuation$priced[held_ids]]
    if (length(unvalued_ids) > 0L) {
      return(stop_valuation(
        unvalued_ids,
        "valuation_horizon_exhausted",
        "valuation_horizon_exhausted",
        full_positions,
        valuation
      ))
    }
    frozen_now <- held_ids[valuation$frozen[held_ids]]
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
      sum(
        position_qty[active_positions] *
          valuation$mark[services$instrument_ids[active_positions]]
      )
    } else {
      sum(
        position_qty[active_positions] *
          services$bars_mat$close[active_positions, pulse_idx]
      )
    }
  } else {
    0
  }
  if (services$availability_active) {
    fold_state$last_fully_valued <- ts
    services$equity_fact_accumulator$append(list(
      ts_utc = ts,
      cash = fold_state$cash,
      positions_value = positions_value,
      realized_pnl = fold_state$lot_state$realized_pnl,
      cost_basis = fold_state$lot_state$total_cost_basis
    ))
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
  context_position_idx <- if (services$availability_active) {
    unname(valuation$source_row)
  } else {
    seq_along(services$instrument_ids)
  }
  positions_snapshot <- ledgr_fold_positions_snapshot(
    fold_state$positions[context_position_idx],
    context_ids
  )
  list(
    pulse_idx = pulse_idx,
    ts = ts,
    ts_iso = ts_iso,
    context_ids = context_ids,
    context_position_idx = context_position_idx,
    positions_snapshot = positions_snapshot,
    positions_value = positions_value,
    availability_view = availability_view,
    valuation = valuation,
    members = if (services$availability_active) {
      as.character(availability_view$members)
    } else {
      context_ids
    },
    history_bars = history_bars,
    history_view = history_view,
    sample_start = sample_start,
    t_feats = t_feats,
    t_bars = t_bars
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
  context_ids <- observation$context_ids
  positions_snapshot <- observation$positions_snapshot
  availability_view <- observation$availability_view
  valuation <- observation$valuation
  add_segment <- function(segment) {
    fold_state$pending_segments[[length(fold_state$pending_segments) + 1L]] <- segment
    invisible(NULL)
  }

  projection_idx <- services$projection_pulse_idx[[pulse_idx]]
  bars_current <- if (services$availability_active) {
    ledgr_history_bar_packet_frame(
      observation$history_bars$current,
      observation$context_position_idx
    )
  } else {
    services$bars_views[[pulse_idx]]
  }
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
    pulse_seed = ledgr_derive_pulse_seed(services$execution_seed, pulse_idx),
    state_prev = fold_state$state_prev,
    .safety_state = "GREEN"
  )
  if (services$availability_active) {
    ctx$availability_active <- TRUE
    ctx$members <- observation$members
    ctx$.history <- observation$history_view
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
      positions = fold_state$positions,
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
      availability = availability_view,
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

  targets <- ledgr_validate_strategy_targets(
    result$targets,
    context_ids,
    allow_empty = services$availability_active
  )
  strategy_targets <- targets
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
    restriction <- as.character(
      availability_view$target_restriction_reason[context_ids]
    )
    restrictions <- as.character(
      availability_view$target_restriction_reasons[context_ids]
    )
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
      target = strategy_targets[context_ids],
      quantity = positions_snapshot[context_ids],
      price = valuation$mark[context_ids],
      mark_source = valuation$source[context_ids],
      mark_age = valuation$age[context_ids],
      target_before_risk = strategy_targets[context_ids],
      target_after_risk = if (is.null(target_after)) {
        NA_real_
      } else {
        target_after[context_ids]
      },
      position_before = positions_snapshot[context_ids],
      position_after = positions_snapshot[context_ids]
    ))
    invisible(NULL)
  }
  if (length(targets) > 0L) {
    if (services$availability_active) {
      ledgr_availability_validate_strategy_targets(
        targets,
        positions_snapshot,
        availability_view
      )
      new_positive <- as.numeric(targets) > as.numeric(positions_snapshot) &
        as.numeric(targets) > 0 &
        !valuation$permissible[names(targets)]
      if (any(new_positive)) {
        append_decision_trace()
        stopped_ids <- names(targets)[new_positive]
        affected <- ledgr_availability_affected_exposure(
          stopped_ids,
          positions_snapshot,
          valuation
        )
        affected <- c(affected, list(ts_utc = ts, specified = TRUE))
        segment <- list(
          n = length(stopped_ids),
          instrument_id = stopped_ids,
          stage = "risk",
          outcome = "stopped",
          reason_code = "risk_mark_unavailable",
          target = targets[stopped_ids],
          quantity = positions_snapshot[stopped_ids],
          mark_source = valuation$source[stopped_ids],
          mark_age = valuation$age[stopped_ids],
          target_before_risk = targets[stopped_ids],
          position_before = positions_snapshot[stopped_ids],
          position_after = positions_snapshot[stopped_ids],
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
    targets <- ledgr_apply_risk_plan(targets, services$risk_plan, ctx)
    targets <- ledgr_validate_post_risk_targets(targets, context_ids)
    if (services$availability_active) {
      ledgr_availability_validate_post_risk(targets, strategy_targets)
      ledgr_availability_validate_short_exposure(targets, positions_snapshot)
    }
  }
  if (services$availability_active) {
    append_decision_trace(targets)
    stale_ids <- context_ids[
      valuation$permissible[context_ids] &
        !is.na(valuation$age[context_ids]) &
        valuation$age[context_ids] > 0L &
        (positions_snapshot[context_ids] != 0 | targets[context_ids] != 0)
    ]
    if (length(stale_ids) > 0L) {
      reduced <- vapply(stale_ids, function(id) {
        !isTRUE(all.equal(
          as.numeric(targets[[id]]),
          as.numeric(strategy_targets[[id]])
        ))
      }, logical(1))
      add_segment(list(
        n = length(stale_ids), instrument_id = stale_ids, stage = "risk",
        outcome = ifelse(reduced, "reduced", "passed"),
        reason_code = ifelse(
          reduced,
          "stale_mark_reduction",
          "stale_mark_pass_through"
        ),
        target = targets[stale_ids],
        quantity = positions_snapshot[stale_ids],
        price = valuation$mark[stale_ids],
        mark_source = valuation$source[stale_ids],
        mark_age = valuation$age[stale_ids],
        target_before_risk = strategy_targets[stale_ids],
        target_after_risk = targets[stale_ids],
        position_before = positions_snapshot[stale_ids],
        position_after = positions_snapshot[stale_ids]
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
  list(
    strategy_targets = strategy_targets,
    targets = targets,
    state_update = result$state_update,
    sample_start = sample_start,
    t_ctx = t_ctx,
    t_strat = t_strat,
    t_target = t_target
  )
}

ledgr_fold_stage_plan <- function(
    fold_state,
    services,
    observation,
    decision,
    sample_telemetry,
    sample_start) {
  fold_state$current_stage <- "execution"
  pulse_idx <- observation$pulse_idx
  ts <- observation$ts
  ts_iso <- observation$ts_iso
  targets <- decision$targets
  strategy_targets <- decision$strategy_targets
  positions_snapshot <- observation$positions_snapshot
  availability_view <- observation$availability_view
  valuation <- observation$valuation

  target_names <- names(targets)
  desired_vec <- as.numeric(targets)
  target_inst_idx <- as.integer(services$id_to_idx[target_names])
  current_qty_vec <- as.numeric(fold_state$positions[target_inst_idx])
  delta_vec <- desired_vec - current_qty_vec
  actionable_idx <- which(abs(delta_vec) > sqrt(.Machine$double.eps))
  if (sample_telemetry) {
    sample_now <- ledgr_time_now()
    t_target <- decision$t_target + ledgr_time_elapsed(sample_start, sample_now)
    sample_start <- sample_now
  } else {
    t_target <- decision$t_target
  }

  if (sample_telemetry) sample_start <- ledgr_time_now()
  pulse_plan <- if (services$availability_active) {
    ledgr_fold_build_availability_pulse_plan(
      targets = targets,
      target_names = target_names,
      target_inst_idx = target_inst_idx,
      current_qty_vec = current_qty_vec,
      delta_vec = delta_vec,
      actionable_idx = actionable_idx,
      pulse_idx = pulse_idx,
      execution_opportunities_posix = services$execution_opportunities_posix,
      bars_mat = NULL,
      cost_resolver = services$cost_resolver,
      ts_signal_utc = ts_iso,
      provider = services$availability_provider,
      decision_member = availability_view$member,
      cash = fold_state$cash,
      next_bars = observation$history_bars$next_bar
    )
  } else {
    plan <- ledgr_fold_build_pulse_plan(
      targets = targets,
      target_names = target_names,
      target_inst_idx = target_inst_idx,
      current_qty_vec = current_qty_vec,
      delta_vec = delta_vec,
      actionable_idx = actionable_idx,
      pulse_idx = pulse_idx,
      pulses_posix = services$pulses_posix,
      bars_mat = services$bars_mat,
      cost_resolver = services$cost_resolver,
      ts_signal_utc = ts_iso
    )
    ledgr_fold_apply_net_feasibility_noop(
      plan,
      ledgr_fold_state_value(fold_state)
    )
  }
  accounting_events <- ledgr_fold_pulse_plan_accounting_events(
    pulse_plan,
    canonical_event_kinds = if (services$use_compiled_spot_fifo) {
      NULL
    } else {
      c("FILL", "CASHFLOW")
    }
  )
  if (services$use_compiled_spot_fifo) {
    ledgr_require_compiled_spot_fifo_event_kinds(accounting_events$kinds)
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
    recorded_final_cash <- fold_state$cash + sum(vapply(
      pulse_plan$fills,
      function(entry) ledgr_availability_fill_cash_delta(entry$fill),
      numeric(1)
    ))
    if (!isTRUE(all.equal(
      as.numeric(recorded_final_cash),
      as.numeric(pulse_plan$expected_final_cash),
      tolerance = ledgr_availability_cash_tolerance
    ))) {
      affordability_detail <- canonical_json(list(
        cash_before = fold_state$cash,
        virtual_final_cash = pulse_plan$expected_final_cash,
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
    if (length(pulse_plan$rejected) > 0L) {
      rejected <- pulse_plan$rejected
      rejected_ids <- vapply(
        rejected,
        function(entry) as.character(entry$instrument_id),
        character(1)
      )
      rejected_qty <- vapply(
        rejected,
        function(entry) as.numeric(entry$current_qty),
        numeric(1)
      )
      add_segment(list(
        n = length(rejected), instrument_id = rejected_ids,
        stage = "execution", outcome = "no_fill",
        reason_code = vapply(
          rejected,
          function(entry) as.character(entry$reason_code),
          character(1)
        ),
        reasons = vapply(
          rejected,
          function(entry) as.character(entry$reasons %||% entry$reason_code),
          character(1)
        ),
        target = targets[rejected_ids],
        quantity = rejected_qty,
        price = vapply(
          rejected,
          function(entry) as.numeric(entry$fill$fill_price %||% NA_real_),
          numeric(1)
        ),
        decision_ts_utc = ts,
        execution_ts_utc = vapply(
          rejected,
          function(entry) as.numeric(as.POSIXct(entry$execution_ts_utc, tz = "UTC")),
          numeric(1)
        ),
        target_before_risk = strategy_targets[rejected_ids],
        target_after_risk = targets[rejected_ids],
        position_before = rejected_qty,
        position_after = rejected_qty
      ))
    }
    if (length(pulse_plan$fills) > 0L) {
      fills <- pulse_plan$fills
      fill_ids <- vapply(
        fills,
        function(entry) as.character(entry$instrument_id),
        character(1)
      )
      informational <- lapply(
        fills,
        function(entry) {
          ledgr_availability_reason_values(entry$informational_reasons)
        }
      )
      add_segment(list(
        n = length(fills), instrument_id = fill_ids,
        stage = "execution", outcome = "filled",
        reason_code = vapply(
          informational,
          function(x) if (length(x) > 0L) x[[1L]] else "",
          character(1)
        ),
        reasons = vapply(
          informational,
          ledgr_availability_reason_text,
          character(1)
        ),
        target = targets[fill_ids],
        quantity = vapply(
          fills,
          function(entry) as.numeric(entry$fill$qty),
          numeric(1)
        ),
        price = vapply(
          fills,
          function(entry) as.numeric(entry$fill$fill_price),
          numeric(1)
        ),
        decision_ts_utc = ts,
        execution_ts_utc = vapply(
          fills,
          function(entry) as.numeric(as.POSIXct(entry$execution_ts_utc, tz = "UTC")),
          numeric(1)
        ),
        event_seq = fold_state$event_seq + seq_along(fills) - 1L,
        target_before_risk = strategy_targets[fill_ids],
        target_after_risk = targets[fill_ids],
        position_before = vapply(
          fills,
          function(entry) as.numeric(entry$current_qty),
          numeric(1)
        ),
        position_after = vapply(
          fills,
          function(entry) as.numeric(entry$resulting_qty),
          numeric(1)
        )
      ))
    }
  }
  list(
    pulse_plan = pulse_plan,
    accounting_events = accounting_events,
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
  accounting_events <- plan$accounting_events
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
    compiled_fills <- ledgr_fold_pulse_plan_fill_intents(accounting_events)
    if (length(compiled_fills) > 0L) {
      if (sample_telemetry) sample_start <- ledgr_time_now()
      batch <- ledgr_run_compiled_spot_fifo_batch(
        run_id = services$run_id,
        fills = compiled_fills,
        state = ledgr_fold_state_value(fold_state),
        instrument_ids = services$instrument_ids,
        event_seq_start = fold_state$event_seq
      )
      positions <- stats::setNames(
        as.numeric(batch$positions),
        services$instrument_ids
      )
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
    for (entry in accounting_events$fills) {
      if (sample_telemetry) sample_start <- ledgr_time_now()
      fill <- entry$fill
      instrument_id <- entry$instrument_id
      inst_idx <- entry$inst_idx
      cur_qty <- entry$current_qty

      lot_res <- ledgr_lot_apply_fill(
        fold_state$lot_state,
        instrument_id = instrument_id,
        side = fill$side,
        qty = fill$qty,
        price = fill$fill_price,
        fee = fill$fee
      )
      fold_state$lot_state <- lot_res$state
      if (sample_telemetry) {
        sample_now <- ledgr_time_now()
        t_state <- t_state + ledgr_time_elapsed(sample_start, sample_now)
        sample_start <- sample_now
      }

      write_res <- output_handler$write_fill_events(
        fill_intent = fill,
        event_seq = fold_state$event_seq,
        use_transaction = identical(services$event_mode, "live")
      )
      fold_state$event_seq <- write_res$next_event_seq
      if (is.function(output_handler$record_accounting_fact)) {
        output_handler$record_accounting_fact(
          write_res = write_res,
          lot_res = lot_res,
          lot_state = fold_state$lot_state
        )
      }
      if (sample_telemetry) {
        sample_now <- ledgr_time_now()
        t_event <- t_event + ledgr_time_elapsed(sample_start, sample_now)
        sample_start <- sample_now
      }

      qty <- if (identical(fill$side, "BUY")) fill$qty else -fill$qty
      cash_delta <- if (identical(fill$side, "BUY")) {
        -(fill$qty * fill$fill_price + fill$fee)
      } else {
        fill$qty * fill$fill_price - fill$fee
      }
      positions[[inst_idx]] <- ledgr_position_from_lots(
        fold_state$lot_state,
        instrument_id
      )
      cash <- cash + cash_delta
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
  pulse_plan <- plan$pulse_plan
  ts <- observation$ts
  ts_iso <- observation$ts_iso
  context_ids <- observation$context_ids
  valuation <- observation$valuation
  strategy_targets <- decision$strategy_targets
  targets <- decision$targets
  state_update <- decision$state_update
  sample_start <- apply$sample_start
  t_state <- apply$t_state

  if (is.function(output_handler$flush_pulse_events)) {
    output_handler$flush_pulse_events()
  }

  if (services$availability_active) {
    if (length(pulse_plan$fills) > 0L) {
      fill_times <- as.POSIXct(vapply(
        pulse_plan$fills,
        function(entry) as.numeric(entry$execution_ts_utc),
        numeric(1)
      ), origin = "1970-01-01", tz = "UTC")
      fold_state$last_executed <- max(
        c(fold_state$last_executed, fill_times),
        na.rm = TRUE
      )
    }
    if (!isTRUE(all.equal(
      as.numeric(fold_state$cash),
      as.numeric(pulse_plan$expected_final_cash),
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
    actual_positions <- ledgr_fold_positions_snapshot(
      fold_state$positions[valuation$source_row],
      context_ids
    )
    reconciliation_detail <- canonical_json(list(
      cash_before = fold_state$cash - sum(vapply(
        pulse_plan$fills,
        function(entry) ledgr_availability_fill_cash_delta(entry$fill),
        numeric(1)
      )),
      virtual_final_cash = pulse_plan$expected_final_cash,
      recorded_final_cash = fold_state$cash,
      intended_gross_exposure = ledgr_availability_marked_gross(
        strategy_targets,
        valuation$mark[names(strategy_targets)]
      ),
      post_risk_gross_exposure = ledgr_availability_marked_gross(
        targets,
        valuation$mark[names(targets)]
      ),
      actual_gross_exposure = ledgr_availability_marked_gross(
        actual_positions,
        valuation$mark[names(actual_positions)]
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
  state <- execution$state
  state$positions <- ledgr_fold_positions_to_vec(state$positions, instrument_ids)
  if (!is.list(state$lot_state)) {
    state$lot_state <- ledgr_lot_state(instrument_ids)
  }
  state$positions <- stats::setNames(state$positions, instrument_ids)
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
  if (!is.null(execution_seed)) {
    had_seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
    old_seed <- if (had_seed) {
      get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
    } else {
      NULL
    }
    on.exit({
      if (had_seed) {
        assign(".Random.seed", old_seed, envir = .GlobalEnv)
      } else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
        rm(".Random.seed", envir = .GlobalEnv)
      }
    }, add = TRUE)
    set.seed(as.integer(execution_seed))
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

      observation <- ledgr_fold_stage_observe_settle(
        fold_state = fold_state,
        services = services,
        pulse_idx = i,
        ts = ts,
        ts_iso = ts_iso,
        sample_telemetry = sample_telemetry,
        sample_start = sample_start
      )
      if (ledgr_is_fold_stop_result(observation)) {
        fold_state$status <- observation$status
        fold_state$stop_reason <- observation$reason_code
        fold_state$affected_exposure <- observation$affected_exposure
        for (segment in observation$diagnostic_segments) {
          add_segment(segment)
        }
        if (isTRUE(observation$counts_processed)) {
          fold_state$processed <- fold_state$processed + 1L
        }
        flush_pulse_block(ts)
        break
      }
      sample_start <- observation$sample_start

      decision_result <- ledgr_fold_stage_decide(
        fold_state = fold_state,
        services = services,
        observation = observation,
        sample_telemetry = sample_telemetry,
        sample_start = sample_start
      )
      if (ledgr_is_fold_stop_result(decision_result)) {
        fold_state$status <- decision_result$status
        fold_state$stop_reason <- decision_result$reason_code
        fold_state$affected_exposure <- decision_result$affected_exposure
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

      plan_result <- ledgr_fold_stage_plan(
        fold_state = fold_state,
        services = services,
        observation = observation,
        decision = decision_result,
        sample_telemetry = sample_telemetry,
        sample_start = sample_start
      )
      if (ledgr_is_fold_stop_result(plan_result)) {
        fold_state$status <- plan_result$status
        fold_state$stop_reason <- plan_result$reason_code
        fold_state$affected_exposure <- plan_result$affected_exposure
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
    state = ledgr_fold_state_value(fold_state),
    state_prev = fold_state$state_prev,
    next_event_seq = fold_state$event_seq,
    equity_facts = equity_fact_accumulator$collect()
  )
}
