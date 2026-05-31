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

ledgr_execute_fold <- function(execution, output_handler) {
  execution <- ledgr_validate_execution_spec(execution)
  run_id <- execution$run_id
  instrument_ids <- execution$instrument_ids
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
  state_prev_mem <- execution$state_prev
  bars_by_id <- execution$bars_by_id
  bars_mat <- execution$bars_mat
  feature_defs <- execution$feature_defs
  runtime_projection <- execution$runtime_projection
  if (is.null(runtime_projection)) {
    rlang::abort("Fold execution requires `runtime_projection`.", class = "ledgr_invalid_fold_execution")
  }
  active_alias_map <- ledgr_normalize_alias_map(execution$active_alias_map)
  cost_resolver <- execution$cost_resolver
  event_seq <- execution$event_seq_start
  telemetry <- execution$telemetry
  execution_seed <- execution$seed
  event_mode <- execution$event_mode
  use_fast_context <- isTRUE(execution$use_fast_context)

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
      if (sample_telemetry) {
        sample_now <- ledgr_time_now()
        t_feats <- ledgr_time_elapsed(sample_start, sample_now)
        sample_start <- sample_now
      }

      position_qty <- as.numeric(state$positions[instrument_ids])
      position_qty[is.na(position_qty)] <- 0
      active_positions <- position_qty != 0
      positions_value <- if (any(active_positions)) {
        sum(position_qty[active_positions] * bars_mat$close[active_positions, i])
      } else {
        0
      }
      if (sample_telemetry) {
        sample_now <- ledgr_time_now()
        t_bars <- ledgr_time_elapsed(sample_start, sample_now)
        sample_start <- sample_now
      }

      # The pulse context is the only strategy-visible boundary in the fold.
      # Everything below this point must preserve no-lookahead: bars/features are
      # the current pulse view, while fills are resolved against the next bar.
      ctx <- list(
        run_id = run_id,
        ts_utc = ts_iso,
        universe = instrument_ids,
        bars = bars_current,
        feature_table = features_current,
        positions = state$positions,
        cash = state$cash,
        equity = state$cash + positions_value,
        seed = execution_seed,
        pulse_seed = ledgr_derive_pulse_seed(execution_seed, i),
        state_prev = state_prev_mem,
        safety_state = "GREEN"
      )
      class(ctx) <- "ledgr_pulse_context"
      ctx <- if (!is.null(fast_context)) {
        ledgr_update_fast_pulse_context_helpers(
          ctx,
          fast_context = fast_context,
          bars = bars_current,
          features = features_current,
          features_wide = features_wide_current,
          positions = state$positions,
          universe = instrument_ids,
          pulse_idx = i,
          active_alias_map = active_alias_map
        )
      } else {
        ledgr_update_pulse_context_helpers(
          ctx,
          bars = bars_current,
          features = features_current,
          positions = state$positions,
          universe = instrument_ids,
          projection = runtime_projection,
          pulse_idx = i,
          feature_ids = def_ids,
          features_wide = features_wide_current,
          active_alias_map = active_alias_map
        )
      }
      if (sample_telemetry) {
        sample_now <- ledgr_time_now()
        t_ctx <- ledgr_time_elapsed(sample_start, sample_now)
        sample_start <- sample_now
      }

      result <- tryCatch(
        {
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
        instrument_ids
      )
      targets <- ledgr_apply_target_risk_noop(targets, ctx, strategy_params)
      if (sample_telemetry) {
        sample_now <- ledgr_time_now()
        t_target <- t_target + ledgr_time_elapsed(sample_start, sample_now)
        sample_start <- sample_now
      }

      # Target deltas are applied one instrument at a time today. Event emission
      # and state mutation must stay adjacent so in-memory sweep and durable run
      # replay see the exact same ordered event stream.
      for (instrument_id in names(targets)) {
        if (sample_telemetry) sample_start <- ledgr_time_now()
        desired <- as.numeric(targets[[instrument_id]])
        cur_qty <- as.numeric(state$positions[[instrument_id]] %||% 0)
        delta <- desired - cur_qty
        if (abs(delta) <= sqrt(.Machine$double.eps)) {
          if (sample_telemetry) {
            t_target <- t_target + ledgr_time_elapsed(sample_start, ledgr_time_now())
          }
          next
        }

        b <- bars_by_id[[instrument_id]]
        next_bar <- if (!is.null(b) && i < nrow(b)) b[i + 1L, , drop = FALSE] else NULL
        proposal <- ledgr_next_open_fill_proposal(
          desired_qty_delta = delta,
          next_bar = next_bar
        )
        if (sample_telemetry) {
          sample_now <- ledgr_time_now()
          t_target <- t_target + ledgr_time_elapsed(sample_start, sample_now)
          sample_start <- sample_now
        }
        fill <- ledgr_resolve_fill_proposal(proposal, cost_resolver)

        if (inherits(fill, "ledgr_fill_none")) {
          if (sample_telemetry) {
            t_fill <- t_fill + ledgr_time_elapsed(sample_start, ledgr_time_now())
          }
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
          next
        }

        if (!is.finite(fill$fill_price) || fill$fill_price <= 0) {
          if (sample_telemetry) {
            t_fill <- t_fill + ledgr_time_elapsed(sample_start, ledgr_time_now())
          }
          next
        }

        fill$instrument_id <- instrument_id
        fill$ts_signal_utc <- ts_iso
        if (sample_telemetry) {
          sample_now <- ledgr_time_now()
          t_fill <- t_fill + ledgr_time_elapsed(sample_start, sample_now)
          sample_start <- sample_now
        }

        write_res <- output_handler$write_fill_events(
          fill_intent = fill,
          event_seq = event_seq,
          use_transaction = identical(event_mode, "live")
        )
        event_seq <- write_res$next_event_seq
        if (sample_telemetry) {
          sample_now <- ledgr_time_now()
          t_event <- t_event + ledgr_time_elapsed(sample_start, sample_now)
          sample_start <- sample_now
        }

        qty <- if (identical(fill$side, "BUY")) fill$qty else -fill$qty
        cash_delta <- if (identical(fill$side, "BUY")) {
          -(fill$qty * fill$fill_price + fill$commission_fixed)
        } else {
          fill$qty * fill$fill_price - fill$commission_fixed
        }
        state$positions[[instrument_id]] <- cur_qty + qty
        state$cash <- state$cash + cash_delta
        if (sample_telemetry) {
          t_state <- t_state + ledgr_time_elapsed(sample_start, ledgr_time_now())
        }
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
          output_handler$pending_event_count() > 0L) {
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

    if (!identical(event_mode, "live") && output_handler$pending_event_count() > 0L) {
      output_handler$flush_pending()
    }
    invisible(NULL)
  }

  loop_start <- ledgr_time_now()
  output_handler$run_transaction(run_loop)
  telemetry$t_loop <- ledgr_time_elapsed(loop_start, ledgr_time_now())
  telemetry$telemetry_samples <- telemetry_idx

  list(
    processed = processed,
    full_run = full_run,
    telemetry = telemetry,
    state = state,
    state_prev = state_prev_mem,
    next_event_seq = event_seq
  )
}
