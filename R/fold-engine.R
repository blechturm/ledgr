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
      "telemetry_samples",
      "feature_cache_hits",
      "feature_cache_misses"
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
  normalized <- stats::setNames(vector("list", length(axis)), axis)
  for (id in axis) normalized[[id]] <- asset_state[[id]] %||% list()
  state_value$asset_state <- normalized
  state_value
}

ledgr_fold_availability_mark_age <- function(bars_mat, instrument_ids, axis, pulse_idx) {
  out <- stats::setNames(rep(NA_integer_, length(axis)), axis)
  for (id in axis) {
    row <- match(id, instrument_ids)
    observed <- which(is.finite(bars_mat$close[row, seq_len(pulse_idx)]))
    if (length(observed) > 0L) out[[id]] <- as.integer(pulse_idx - utils::tail(observed, 1L))
  }
  out
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
      fills = fills
    ),
    class = c("ledgr_pulse_plan", "list")
  )
}

ledgr_fold_apply_net_feasibility_noop <- function(pulse_plan, state) {
  force(state)
  pulse_plan
}

ledgr_fold_pulse_plan_fill_intents <- function(pulse_plan) {
  lapply(pulse_plan$fills, function(entry) entry$fill)
}

ledgr_execute_fold <- function(execution, output_handler) {
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
  state_prev_mem <- execution$state_prev
  bars_by_id <- execution$bars_by_id
  bars_mat <- execution$bars_mat
  feature_defs <- execution$feature_defs
  runtime_projection <- execution$runtime_projection
  if (is.null(runtime_projection)) {
    rlang::abort("Fold execution requires `runtime_projection`.", class = "ledgr_invalid_fold_execution")
  }
  active_alias_map <- ledgr_normalize_alias_map(execution$active_alias_map)
  risk_plan <- ledgr_risk_validate_compiled_plan(execution$risk_plan)
  cost_resolver <- execution$cost_resolver
  event_seq <- execution$event_seq_start
  telemetry <- execution$telemetry
  execution_seed <- execution$seed
  event_mode <- execution$event_mode
  use_fast_context <- isTRUE(execution$use_fast_context)
  compiled_accounting_model <- ledgr_normalize_compiled_accounting_model(
    execution$compiled_accounting_model
  )
  use_compiled_spot_fifo <- identical(compiled_accounting_model, "spot_fifo")
  availability_provider <- execution$availability_provider
  availability_active <- !is.null(availability_provider)
  max_stale_sessions <- if (availability_active) {
    as.integer(availability_provider$valuation_policy$max_sessions)
  } else {
    NA_integer_
  }
  if (use_compiled_spot_fifo) {
    ledgr_require_compiled_spot_fifo_dispatch(execution, output_handler)
  }

  if (!is.null(execution_seed)) {
    set.seed(as.integer(execution_seed))
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

  bars_views <- execution$static_bars_views
  if (is.null(bars_views)) {
    bars_views <- ledgr_bars_pulse_views(
      bars_mat = bars_mat,
      instrument_ids = instrument_ids,
      pulses_posix = pulses_posix
    )
  }
  feature_views <- execution$static_feature_views
  if (is.null(feature_views)) {
    feature_views <- ledgr_projection_pulse_views(
      runtime_projection,
      feature_ids = def_ids
    )
  }
  feature_table_views <- feature_views$feature_table %||% vector("list", length(pulses_posix))
  features_wide_views <- feature_views$features_wide %||% vector("list", length(pulses_posix))
  if (length(bars_views) != length(pulses_posix) ||
      length(feature_table_views) != length(pulses_posix) ||
      length(features_wide_views) != length(pulses_posix)) {
    rlang::abort("Static pulse views must align with fold pulse timestamps.", class = "ledgr_invalid_fold_execution")
  }

  empty_feature_table <- if (n_def > 0L) {
    ledgr_projection_feature_table(runtime_projection, 1L, feature_ids = character())
  } else {
    empty_df
  }

  full_run <- TRUE
  processed <- 0L
  terminal_status <- "DONE"
  stop_reason <- NA_character_
  last_fully_valued_ts <- as.POSIXct(NA, tz = "UTC")
  last_executed_ts <- as.POSIXct(NA, tz = "UTC")
  affected <- list(
    value = NA_real_,
    details = list(),
    ts_utc = as.POSIXct(NA, tz = "UTC"),
    specified = FALSE
  )
  diagnostic_rows <- list()
  diagnostic_seq <- 0L
  equity_facts <- list()
  current_fold_ts <- as.POSIXct(NA, tz = "UTC")
  current_fold_stage <- "fold"
  append_diagnostic <- function(row) {
    diagnostic_seq <<- diagnostic_seq + 1L
    row$diagnostic_seq <- diagnostic_seq
    diagnostic_rows[[diagnostic_seq]] <<- row
    invisible(NULL)
  }
  telemetry_idx <- as.integer(telemetry$telemetry_samples %||% 0L)
  fast_context <- if (isTRUE(use_fast_context)) {
    ledgr_fast_context_state(
      universe = instrument_ids,
      projection = runtime_projection,
      feature_ids = def_ids,
      active_alias_map = active_alias_map
    )
  } else {
    NULL
  }

  run_loop <- function() {
    if (length(pulses_posix) == 0L || start_idx > length(pulses_posix)) {
      return(invisible(NULL))
    }

    for (i in seq(from = start_idx, to = length(pulses_posix))) {
      ts <- pulses_posix[[i]]
      ts_iso <- pulses_iso[[i]]
      current_fold_ts <<- ts
      current_fold_stage <<- "valuation"
      pulse_start <- ledgr_time_now()
      sample_telemetry <- telemetry_stride > 0L &&
        ((processed + 1L) %% telemetry_stride == 0L)
      sample_start <- if (sample_telemetry) pulse_start else NULL
      t_bars <- 0
      t_feats <- 0
      t_ctx <- 0
      t_strat <- 0
      t_target <- 0
      t_fill <- 0
      t_event <- 0
      t_state <- 0

      bars_current <- bars_views[[i]]
      features_current <- feature_table_views[[i]]
      if (!is.data.frame(features_current)) {
        features_current <- empty_feature_table
      }
      features_wide_current <- features_wide_views[[i]]
      if (!is.data.frame(features_wide_current)) {
        features_wide_current <- empty_df
      }

      availability_view <- NULL
      valuation <- NULL
      context_ids <- instrument_ids
      if (availability_active) {
        full_positions <- ledgr_fold_positions_snapshot(state$positions, instrument_ids)
        availability_view <- availability_provider$decision_view(ts, full_positions)
        context_ids <- as.character(availability_view$axis)
        valuation <- ledgr_availability_valuation_marks(
          bars_mat = bars_mat,
          instrument_ids = instrument_ids,
          axis = context_ids,
          pulse_idx = i,
          pulses_posix = pulses_posix,
          max_sessions = max_stale_sessions
        )
        availability_view$priced <- valuation$priced
        availability_view$mark_age <- valuation$age
        availability_view$risk_mark <- valuation$mark
        availability_view$mark_source <- valuation$source
        held_ids <- context_ids[as.logical(availability_view$held)]
        terminal_ids <- held_ids[nzchar(as.character(availability_view$terminal_event[held_ids]))]
        expired_ids <- setdiff(held_ids[!valuation$permissible[held_ids]], terminal_ids)
        if (length(terminal_ids) > 0L || length(expired_ids) > 0L) {
          stopped_ids <- if (length(terminal_ids) > 0L) terminal_ids else expired_ids
          terminal_status <<- "INCOMPLETE"
          stop_reason <<- if (length(terminal_ids) > 0L) {
            "terminal_settlement_unsupported"
          } else {
            "valuation_horizon_exhausted"
          }
          affected_value <- ledgr_availability_affected_exposure(
            stopped_ids,
            full_positions,
            valuation
          )
          affected <<- c(affected_value, list(ts_utc = ts, specified = TRUE))
          for (id in stopped_ids) {
            stop_reasons <- stop_reason
            if (
              identical(stop_reason, "valuation_horizon_exhausted") &&
                identical(as.character(availability_view$lifetime[[id]]), "known_inactive")
            ) {
              stop_reasons <- paste(stop_reasons, "lifetime_inactive", sep = "|")
            }
            append_diagnostic(ledgr_availability_diagnostic_row(
              run_id = run_id,
              diagnostic_seq = diagnostic_seq + 1L,
              ts_utc = ts,
              instrument_id = id,
              stage = "valuation",
              outcome = "stopped",
              reason_code = stop_reason,
              reasons = stop_reasons,
              quantity = full_positions[[id]],
              price = valuation$reference[[id]],
              mark_source = valuation$source[[id]],
              mark_age = valuation$age[[id]],
              position_before = full_positions[[id]],
              position_after = full_positions[[id]],
              detail_json = canonical_json(affected_value$details[[match(id, stopped_ids)]])
            ))
          }
          break
        }
        keep_bars <- match(context_ids, as.character(bars_current$instrument_id), nomatch = 0L)
        bars_current <- bars_current[keep_bars[keep_bars > 0L], , drop = FALSE]
        if (nrow(features_current) > 0L) {
          features_current <- features_current[
            as.character(features_current$instrument_id) %in% context_ids,
            ,
            drop = FALSE
          ]
        }
        if (nrow(features_wide_current) > 0L && "instrument_id" %in% names(features_wide_current)) {
          features_wide_current <- features_wide_current[
            as.character(features_wide_current$instrument_id) %in% context_ids,
            ,
            drop = FALSE
          ]
        }
        state_prev_mem <- ledgr_fold_asset_state_normalize(
          state_prev_mem,
          context_ids,
          drop_exited = TRUE
        )
      }
      if (sample_telemetry) {
        sample_now <- ledgr_time_now()
        t_feats <- ledgr_time_elapsed(sample_start, sample_now)
        sample_start <- sample_now
      }

      position_qty <- as.numeric(state$positions)
      active_positions <- position_qty != 0
      positions_value <- if (any(active_positions)) {
        if (availability_active) {
          mark_idx <- match(instrument_ids[active_positions], context_ids)
          sum(position_qty[active_positions] * valuation$mark[mark_idx])
        } else {
          sum(position_qty[active_positions] * bars_mat$close[active_positions, i])
        }
      } else {
        0
      }
      if (availability_active) {
        last_fully_valued_ts <<- ts
        equity_facts[[length(equity_facts) + 1L]] <<- list(
          ts_utc = ts,
          cash = state$cash,
          positions_value = positions_value,
          realized_pnl = state$lot_state$realized_pnl,
          cost_basis = state$lot_state$total_cost_basis
        )
      }
      if (is.function(output_handler$record_equity_fact)) {
        output_handler$record_equity_fact(
          ts_utc = ts,
          cash = state$cash,
          positions_value = positions_value,
          realized_pnl = state$lot_state$realized_pnl,
          cost_basis = state$lot_state$total_cost_basis
        )
      }
      if (sample_telemetry) {
        sample_now <- ledgr_time_now()
        t_bars <- ledgr_time_elapsed(sample_start, sample_now)
        sample_start <- sample_now
      }

      # The pulse context is the only strategy-visible boundary in the fold.
      # Everything below this point must preserve no-lookahead: bars/features are
      # the current pulse view, while fills are resolved against the next bar.
      context_position_idx <- match(context_ids, instrument_ids)
      positions_snapshot <- ledgr_fold_positions_snapshot(
        state$positions[context_position_idx],
        context_ids
      )
      ctx <- list(
        run_id = run_id,
        ts_utc = ts_iso,
        universe = context_ids,
        bars = bars_current,
        feature_table = features_current,
        positions = positions_snapshot,
        cash = state$cash,
        equity = state$cash + positions_value,
        seed = execution_seed,
        pulse_seed = ledgr_derive_pulse_seed(execution_seed, i),
        state_prev = state_prev_mem,
        safety_state = "GREEN"
      )
      if (availability_active) {
        ctx$availability_active <- TRUE
        ctx$members <- as.character(availability_view$members)
      }
      class(ctx) <- "ledgr_pulse_context"
      ctx <- if (!is.null(fast_context) && !availability_active) {
        ledgr_update_fast_pulse_context_helpers(
          ctx,
          fast_context = fast_context,
          bars = bars_current,
          features = features_current,
          features_wide = features_wide_current,
          positions = state$positions,
          universe = instrument_ids,
          pulse_idx = i,
          active_alias_map = active_alias_map,
          id_to_idx = id_to_idx
        )
      } else {
        ledgr_update_pulse_context_helpers(
          ctx,
          bars = bars_current,
          features = features_current,
          positions = positions_snapshot,
          universe = context_ids,
          projection = runtime_projection,
          pulse_idx = i,
          feature_ids = def_ids,
          features_wide = features_wide_current,
          active_alias_map = active_alias_map,
          id_to_idx = if (availability_active) NULL else id_to_idx,
          availability = availability_view
        )
      }
      if (availability_active) {
        ctx <- ledgr_filter_pulse_context_features(ctx, context_ids, instrument_ids)
      }
      if (sample_telemetry) {
        sample_now <- ledgr_time_now()
        t_ctx <- ledgr_time_elapsed(sample_start, sample_now)
        sample_start <- sample_now
      }

      result <- tryCatch(
        {
          current_fold_stage <<- "strategy"
          if (isTRUE(strategy_is_functional)) {
            ledgr_call_strategy_fn(
              strategy_fn,
              ctx,
              strategy_params,
              strategy_call_signature
            )
          } else {
            strategy_fn(ctx)
          }
        },
        error = function(e) ledgr_abort_strategy_error(e, ctx)
      )
      if (sample_telemetry) {
        sample_now <- ledgr_time_now()
        t_strat <- ledgr_time_elapsed(sample_start, sample_now)
        sample_start <- sample_now
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

      targets <- ledgr_validate_strategy_targets(
        result$targets,
        context_ids,
        allow_empty = availability_active
      )
      strategy_targets <- targets
      append_decision_trace <- function(target_after = NULL) {
        if (length(context_ids) == 0L) {
          append_diagnostic(ledgr_availability_diagnostic_row(
            run_id = run_id,
            diagnostic_seq = diagnostic_seq + 1L,
            ts_utc = ts,
            stage = "decision",
            outcome = "recorded",
            reason_code = "empty_public_domain"
          ))
          return(invisible(NULL))
        }
        for (id in context_ids) {
          restriction <- as.character(
            availability_view$target_restriction_reason[[id]]
          )
          restrictions <- as.character(
            availability_view$target_restriction_reasons[[id]]
          )
          reason <- if (nzchar(restriction)) restriction else "decision_recorded"
          reasons <- if (nzchar(restrictions)) restrictions else reason
          append_diagnostic(ledgr_availability_diagnostic_row(
            run_id = run_id,
            diagnostic_seq = diagnostic_seq + 1L,
            ts_utc = ts,
            instrument_id = id,
            stage = "decision",
            outcome = "recorded",
            reason_code = reason,
            reasons = reasons,
            target = strategy_targets[[id]],
            quantity = positions_snapshot[[id]],
            price = valuation$mark[[id]],
            mark_source = valuation$source[[id]],
            mark_age = valuation$age[[id]],
            target_before_risk = strategy_targets[[id]],
            target_after_risk = if (is.null(target_after)) NA_real_ else target_after[[id]],
            position_before = positions_snapshot[[id]],
            position_after = positions_snapshot[[id]]
          ))
        }
        invisible(NULL)
      }
      if (length(targets) > 0L) {
        if (availability_active) {
          ledgr_availability_validate_strategy_targets(
            targets,
            positions_snapshot,
            availability_view
          )
          new_positive <- as.numeric(targets) > as.numeric(positions_snapshot) &
            as.numeric(targets) > 0 & !valuation$permissible[names(targets)]
          if (any(new_positive)) {
            append_decision_trace()
            stopped_ids <- names(targets)[new_positive]
            terminal_status <<- "INCOMPLETE"
            stop_reason <<- "risk_mark_unavailable"
            affected_value <- ledgr_availability_affected_exposure(
              stopped_ids,
              positions_snapshot,
              valuation
            )
            affected <<- c(affected_value, list(ts_utc = ts, specified = TRUE))
            for (id in stopped_ids) {
              append_diagnostic(ledgr_availability_diagnostic_row(
                run_id = run_id,
                diagnostic_seq = diagnostic_seq + 1L,
                ts_utc = ts,
                instrument_id = id,
                stage = "risk",
                outcome = "stopped",
                reason_code = stop_reason,
                target = targets[[id]],
                quantity = positions_snapshot[[id]],
                mark_source = valuation$source[[id]],
                mark_age = valuation$age[[id]],
                target_before_risk = targets[[id]],
                position_before = positions_snapshot[[id]],
                position_after = positions_snapshot[[id]],
                detail_json = canonical_json(list(
                  risk_step = "availability_risk_mark_gate"
                ))
              ))
            }
            processed <<- processed + 1L
            break
          }
        }
        current_fold_stage <<- "risk"
        targets <- ledgr_apply_risk_plan(targets, risk_plan, ctx)
        targets <- ledgr_validate_post_risk_targets(targets, context_ids)
        if (availability_active) {
          ledgr_availability_validate_post_risk(targets, strategy_targets)
          ledgr_availability_validate_short_exposure(targets, positions_snapshot)
        }
      }
      if (availability_active) {
        append_decision_trace(targets)
        stale_ids <- context_ids[
          valuation$permissible[context_ids] &
            !is.na(valuation$age[context_ids]) &
            valuation$age[context_ids] > 0L &
            (positions_snapshot[context_ids] != 0 | targets[context_ids] != 0)
        ]
        for (id in stale_ids) {
          reduced <- !isTRUE(all.equal(
            as.numeric(targets[[id]]),
            as.numeric(strategy_targets[[id]])
          ))
          append_diagnostic(ledgr_availability_diagnostic_row(
            run_id = run_id,
            diagnostic_seq = diagnostic_seq + 1L,
            ts_utc = ts,
            instrument_id = id,
            stage = "risk",
            outcome = if (reduced) "reduced" else "passed",
            reason_code = if (reduced) "stale_mark_reduction" else "stale_mark_pass_through",
            target = targets[[id]],
            quantity = positions_snapshot[[id]],
            price = valuation$mark[[id]],
            mark_source = valuation$source[[id]],
            mark_age = valuation$age[[id]],
            target_before_risk = strategy_targets[[id]],
            target_after_risk = targets[[id]],
            position_before = positions_snapshot[[id]],
            position_after = positions_snapshot[[id]]
          ))
        }
      }
      if (sample_telemetry) {
        sample_now <- ledgr_time_now()
        t_target <- t_target + ledgr_time_elapsed(sample_start, sample_now)
        sample_start <- sample_now
      }

      target_names <- names(targets)
      desired_vec <- as.numeric(targets)
      target_inst_idx <- as.integer(id_to_idx[target_names])
      current_qty_vec <- as.numeric(state$positions[target_inst_idx])
      delta_vec <- desired_vec - current_qty_vec
      actionable_idx <- which(abs(delta_vec) > sqrt(.Machine$double.eps))
      if (sample_telemetry) {
        sample_now <- ledgr_time_now()
        t_target <- t_target + ledgr_time_elapsed(sample_start, sample_now)
        sample_start <- sample_now
      }

      if (sample_telemetry) sample_start <- ledgr_time_now()
      current_fold_stage <<- "execution"
      pulse_plan <- if (availability_active) {
        ledgr_fold_build_availability_pulse_plan(
          targets = targets,
          target_names = target_names,
          target_inst_idx = target_inst_idx,
          current_qty_vec = current_qty_vec,
          delta_vec = delta_vec,
          actionable_idx = actionable_idx,
          pulse_idx = i,
          pulses_posix = pulses_posix,
          bars_mat = bars_mat,
          cost_resolver = cost_resolver,
          ts_signal_utc = ts_iso,
          provider = availability_provider,
          decision_member = availability_view$member,
          cash = state$cash
        )
      } else {
        plan <- ledgr_fold_build_pulse_plan(
          targets = targets,
          target_names = target_names,
          target_inst_idx = target_inst_idx,
          current_qty_vec = current_qty_vec,
          delta_vec = delta_vec,
          actionable_idx = actionable_idx,
          pulse_idx = i,
          pulses_posix = pulses_posix,
          bars_mat = bars_mat,
          cost_resolver = cost_resolver,
          ts_signal_utc = ts_iso
        )
        ledgr_fold_apply_net_feasibility_noop(plan, state)
      }
      if (sample_telemetry) {
        sample_now <- ledgr_time_now()
        t_fill <- t_fill + ledgr_time_elapsed(sample_start, sample_now)
        sample_start <- sample_now
      }

      if (availability_active) {
        recorded_final_cash <- state$cash + sum(vapply(
          pulse_plan$fills,
          function(entry) ledgr_availability_fill_cash_delta(entry$fill),
          numeric(1)
        ))
        if (!isTRUE(all.equal(
          as.numeric(recorded_final_cash),
          as.numeric(pulse_plan$expected_final_cash),
          tolerance = ledgr_availability_cash_tolerance
        ))) {
          terminal_status <<- "INCOMPLETE"
          stop_reason <<- "affordability_reconciliation_failed"
          append_diagnostic(ledgr_availability_diagnostic_row(
            run_id = run_id,
            diagnostic_seq = diagnostic_seq + 1L,
            ts_utc = ts,
            stage = "affordability",
            outcome = "stopped",
            reason_code = stop_reason,
            detail_json = canonical_json(list(
              cash_before = state$cash,
              virtual_final_cash = pulse_plan$expected_final_cash,
              recorded_final_cash = recorded_final_cash
            ))
          ))
          processed <<- processed + 1L
          break
        }
        for (entry in pulse_plan$rejected) {
          append_diagnostic(ledgr_availability_diagnostic_row(
            run_id = run_id,
            diagnostic_seq = diagnostic_seq + 1L,
            ts_utc = ts,
            instrument_id = entry$instrument_id,
            stage = "execution",
            outcome = "no_fill",
            reason_code = entry$reason_code,
            reasons = entry$reasons %||% entry$reason_code,
            target = targets[[entry$instrument_id]],
            quantity = entry$current_qty,
            price = as.numeric(entry$fill$fill_price %||% NA_real_),
            decision_ts_utc = ts,
            execution_ts_utc = entry$execution_ts_utc,
            target_before_risk = strategy_targets[[entry$instrument_id]],
            target_after_risk = targets[[entry$instrument_id]],
            position_before = entry$current_qty,
            position_after = entry$current_qty
          ))
        }
        for (entry in pulse_plan$fills) {
          informational <- ledgr_availability_reason_values(
            entry$informational_reasons
          )
          append_diagnostic(ledgr_availability_diagnostic_row(
            run_id = run_id,
            diagnostic_seq = diagnostic_seq + 1L,
            ts_utc = ts,
            instrument_id = entry$instrument_id,
            stage = "execution",
            outcome = "filled",
            reason_code = if (length(informational) > 0L) informational[[1L]] else "",
            reasons = ledgr_availability_reason_text(informational),
            target = targets[[entry$instrument_id]],
            quantity = entry$fill$qty,
            price = entry$fill$fill_price,
            decision_ts_utc = ts,
            execution_ts_utc = entry$execution_ts_utc,
            target_before_risk = strategy_targets[[entry$instrument_id]],
            target_after_risk = targets[[entry$instrument_id]],
            position_before = entry$current_qty,
            position_after = entry$resulting_qty
          ))
        }
      }

      # Event emission and state mutation happen only after the private pulse
      # plan is complete. Event order still follows the validated target vector
      # so sweep and durable replay see the same canonical stream.
      current_fold_stage <<- "accounting"
      if (use_compiled_spot_fifo) {
        compiled_fills <- ledgr_fold_pulse_plan_fill_intents(pulse_plan)
        if (length(compiled_fills) > 0L) {
          if (sample_telemetry) sample_start <- ledgr_time_now()
          batch <- ledgr_run_compiled_spot_fifo_batch(
            run_id = run_id,
            fills = compiled_fills,
            state = state,
            instrument_ids = instrument_ids,
            event_seq_start = event_seq
          )
          state$positions <- batch$positions
          state$cash <- batch$cash
          state$lot_state <- batch$lot_state
          event_seq <- batch$next_event_seq
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
        for (entry in pulse_plan$fills) {
          if (sample_telemetry) sample_start <- ledgr_time_now()
          fill <- entry$fill
          instrument_id <- entry$instrument_id
          inst_idx <- entry$inst_idx
          cur_qty <- entry$current_qty

          lot_res <- ledgr_lot_apply_fill(
            state$lot_state,
            instrument_id = instrument_id,
            side = fill$side,
            qty = fill$qty,
            price = fill$fill_price,
            fee = fill$fee
          )
          state$lot_state <- lot_res$state
          if (sample_telemetry) {
            sample_now <- ledgr_time_now()
            t_state <- t_state + ledgr_time_elapsed(sample_start, sample_now)
            sample_start <- sample_now
          }

          write_res <- output_handler$write_fill_events(
            fill_intent = fill,
            event_seq = event_seq,
            use_transaction = identical(event_mode, "live")
          )
          event_seq <- write_res$next_event_seq
          if (is.function(output_handler$record_accounting_fact)) {
            output_handler$record_accounting_fact(
              write_res = write_res,
              lot_res = lot_res,
              lot_state = state$lot_state
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
          state$positions[[inst_idx]] <- cur_qty + qty
          state$cash <- state$cash + cash_delta
          if (sample_telemetry) {
            t_state <- t_state + ledgr_time_elapsed(sample_start, ledgr_time_now())
          }
        }
      }

      if (availability_active) {
        if (length(pulse_plan$fills) > 0L) {
          fill_times <- as.POSIXct(vapply(
            pulse_plan$fills,
            function(entry) as.numeric(entry$execution_ts_utc),
            numeric(1)
          ), origin = "1970-01-01", tz = "UTC")
          last_executed_ts <<- max(c(last_executed_ts, fill_times), na.rm = TRUE)
        }
        if (!isTRUE(all.equal(
          as.numeric(state$cash),
          as.numeric(pulse_plan$expected_final_cash),
          tolerance = ledgr_availability_cash_tolerance
        ))) {
          rlang::abort(
            "Recorded cash does not reconcile with the availability affordability ledger.",
            class = c("ledgr_affordability_reconciliation_failed", "ledgr_invalid_fold_execution")
          )
        }
        actual_positions <- ledgr_fold_positions_snapshot(
          state$positions[match(context_ids, instrument_ids)],
          context_ids
        )
        append_diagnostic(ledgr_availability_diagnostic_row(
          run_id = run_id,
          diagnostic_seq = diagnostic_seq + 1L,
          ts_utc = ts,
          stage = "reconciliation",
          outcome = "reconciled",
          reason_code = "affordability_reconciled",
          detail_json = canonical_json(list(
            cash_before = state$cash - sum(vapply(
              pulse_plan$fills,
              function(entry) ledgr_availability_fill_cash_delta(entry$fill),
              numeric(1)
            )),
            virtual_final_cash = pulse_plan$expected_final_cash,
            recorded_final_cash = state$cash,
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
        ))
      }

      if (availability_active) {
        if (is.null(result$state_update)) {
          result$state_update <- state_prev_mem
        }
        result$state_update <- ledgr_fold_asset_state_normalize(
          result$state_update,
          context_ids
        )
      }
      if (is.list(result) && !is.null(result$state_update)) {
        if (sample_telemetry) sample_start <- ledgr_time_now()
        state_json <- canonical_json(result$state_update)
        state_prev_mem <- result$state_update
        if (identical(event_mode, "live")) {
          output_handler$write_strategy_state(ts_utc = ts_iso, state_json = state_json)
        } else {
          output_handler$buffer_strategy_state(ts_utc = ts_iso, state_json = state_json)
        }
        if (sample_telemetry) {
          t_state <- t_state + ledgr_time_elapsed(sample_start, ledgr_time_now())
        }
      }

      processed <<- processed + 1L

      if (telemetry_stride > 0L && processed %% telemetry_stride == 0L) {
        telemetry_idx <<- telemetry_idx + 1L
        telemetry$t_pulse[[telemetry_idx]] <- ledgr_time_elapsed(
          pulse_start,
          ledgr_time_now()
        )
        telemetry$t_bars[[telemetry_idx]] <- t_bars
        telemetry$t_ctx[[telemetry_idx]] <- t_ctx
        telemetry$t_fill[[telemetry_idx]] <- t_fill
        telemetry$t_state[[telemetry_idx]] <- t_state
        telemetry$t_feats[[telemetry_idx]] <- t_feats
        telemetry$t_strat[[telemetry_idx]] <- t_strat
        telemetry$t_target[[telemetry_idx]] <- t_target
        telemetry$t_event[[telemetry_idx]] <- t_event
        telemetry$t_exec[[telemetry_idx]] <- t_target + t_fill + t_event + t_state
      }

      if (checkpoint_every > 0L &&
          processed %% checkpoint_every == 0L &&
          !identical(event_mode, "live") &&
          (output_handler$pending_event_count() > 0L ||
           output_handler$pending_state_count() > 0L)) {
        output_handler$flush_pending()
      }

      if (processed >= max_pulses) {
        full_run <<- FALSE
        break
      }
      if (isTRUE(getOption("ledgr.interrupt", FALSE))) {
        full_run <<- FALSE
        break
      }
    }

    if (!identical(event_mode, "live") &&
        (output_handler$pending_event_count() > 0L ||
         output_handler$pending_state_count() > 0L)) {
      output_handler$flush_pending()
    }
    if (availability_active) {
      diagnostics <- if (length(diagnostic_rows) == 0L) {
        ledgr_availability_diagnostic_row(
          run_id = run_id,
          diagnostic_seq = 1L,
          ts_utc = pulses_posix[[1L]],
          stage = "decision",
          outcome = "observed",
          reason_code = "no_diagnostics"
        )[0, , drop = FALSE]
      } else {
        do.call(rbind, diagnostic_rows)
      }
      if (isTRUE(full_run)) {
        completion <- ledgr_availability_completion_row(
          run_id = run_id,
          pulses_posix = pulses_posix,
          status = terminal_status,
          stop_reason = stop_reason,
          affected = affected,
          last_fully_valued_ts_utc = last_fully_valued_ts,
          last_executed_ts_utc = last_executed_ts
        )
        output_handler$write_run_evidence(completion, diagnostics)
      } else {
        output_handler$write_run_diagnostics(diagnostics)
      }
    }
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
        ts_utc = current_fold_ts,
        stage = current_fold_stage,
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
  telemetry$telemetry_samples <- telemetry_idx

  list(
    status = terminal_status,
    processed = processed,
    full_run = full_run,
    telemetry = telemetry,
    state = state,
    state_prev = state_prev_mem,
    next_event_seq = event_seq,
    equity_facts = equity_facts
  )
}
