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
  run_feature_matrix <- execution$run_feature_matrix
  cost_resolver <- execution$cost_resolver
  event_seq <- execution$event_seq_start
  telemetry <- execution$telemetry
  execution_seed <- execution$seed
  event_mode <- execution$event_mode

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

  bars_df <- data.frame(
    instrument_id = character(n_inst),
    ts_utc = as.POSIXct(rep(NA_character_, n_inst), tz = "UTC"),
    open = numeric(n_inst),
    high = numeric(n_inst),
    low = numeric(n_inst),
    close = numeric(n_inst),
    volume = numeric(n_inst),
    gap_type = character(n_inst),
    is_synthetic = logical(n_inst),
    stringsAsFactors = FALSE
  )
  features_df <- if (n_def > 0L) {
    data.frame(
      instrument_id = rep(instrument_ids, times = n_def),
      ts_utc = as.POSIXct(rep(NA_character_, n_inst * n_def), tz = "UTC"),
      feature_name = rep(def_ids, each = n_inst),
      feature_value = numeric(n_inst * n_def),
      stringsAsFactors = FALSE
    )
  } else {
    empty_df
  }

  full_run <- TRUE
  processed <- 0L
  telemetry_idx <- as.integer(telemetry$telemetry_samples %||% 0L)

  run_loop <- function() {
    if (length(pulses_posix) == 0L || start_idx > length(pulses_posix)) {
      return(invisible(NULL))
    }

    for (i in seq(from = start_idx, to = length(pulses_posix))) {
      ts <- pulses_posix[[i]]
      ts_iso <- pulses_iso[[i]]
      pulse_start <- ledgr_time_now()

      for (j in seq_along(instrument_ids)) {
        inst <- instrument_ids[[j]]
        bars_df$instrument_id[[j]] <- inst
        bars_df$ts_utc[[j]] <- ts
        bars_df$open[[j]] <- bars_mat$open[j, i]
        bars_df$high[[j]] <- bars_mat$high[j, i]
        bars_df$low[[j]] <- bars_mat$low[j, i]
        bars_df$close[[j]] <- bars_mat$close[j, i]
        bars_df$volume[[j]] <- bars_mat$volume[j, i]
        bars_df$gap_type[[j]] <- bars_mat$gap_type[j, i]
        bars_df$is_synthetic[[j]] <- bars_mat$is_synthetic[j, i]
      }
      bars_current <- bars_df

      if (n_def > 0L) {
        row_idx <- 1L
        for (def_id in def_ids) {
          m <- run_feature_matrix[[def_id]]
          for (j in seq_along(instrument_ids)) {
            inst <- instrument_ids[[j]]
            features_df$instrument_id[[row_idx]] <- inst
            features_df$ts_utc[[row_idx]] <- ts
            features_df$feature_name[[row_idx]] <- def_id
            features_df$feature_value[[row_idx]] <- m[j, i]
            row_idx <- row_idx + 1L
          }
        }
        features_current <- features_df
      } else {
        features_current <- empty_df
      }

      positions_value <- 0
      for (j in seq_along(instrument_ids)) {
        inst <- instrument_ids[[j]]
        qty <- as.numeric(state$positions[[inst]] %||% 0)
        if (qty == 0) next
        positions_value <- positions_value + qty * bars_mat$close[j, i]
      }

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
        state_prev = state_prev_mem,
        safety_state = "GREEN"
      )
      class(ctx) <- "ledgr_pulse_context"
      ctx <- ledgr_update_pulse_context_helpers(
        ctx,
        bars = bars_current,
        features = features_current,
        positions = state$positions,
        universe = instrument_ids
      )

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

      for (instrument_id in names(targets)) {
        desired <- as.numeric(targets[[instrument_id]])
        cur_qty <- as.numeric(state$positions[[instrument_id]] %||% 0)
        delta <- desired - cur_qty
        if (abs(delta) <= sqrt(.Machine$double.eps)) {
          next
        }

        b <- bars_by_id[[instrument_id]]
        next_bar <- if (!is.null(b) && i < nrow(b)) b[i + 1L, , drop = FALSE] else NULL
        proposal <- ledgr_next_open_fill_proposal(
          desired_qty_delta = delta,
          next_bar = next_bar
        )
        fill <- ledgr_resolve_fill_proposal(proposal, cost_resolver)

        if (inherits(fill, "ledgr_fill_none")) {
          if (is.character(fill$warn_code) &&
              identical(fill$warn_code, "LEDGR_LAST_BAR_NO_FILL")) {
            warning("LEDGR_LAST_BAR_NO_FILL", call. = FALSE)
          }
          next
        }

        if (!is.finite(fill$fill_price) || fill$fill_price <= 0) {
          next
        }

        fill$instrument_id <- instrument_id
        fill$ts_signal_utc <- ts_iso

        if (identical(event_mode, "live")) {
          write_res <- output_handler$write_fill_events(
            fill_intent = fill,
            event_seq = event_seq
          )
        } else {
          write_res <- ledgr_fill_event_row(run_id, fill, event_seq)
          output_handler$buffer_event(write_res)
        }
        event_seq <- write_res$next_event_seq

        qty <- if (identical(fill$side, "BUY")) fill$qty else -fill$qty
        cash_delta <- if (identical(fill$side, "BUY")) {
          -(fill$qty * fill$fill_price + fill$commission_fixed)
        } else {
          fill$qty * fill$fill_price - fill$commission_fixed
        }
        state$positions[[instrument_id]] <- cur_qty + qty
        state$cash <- state$cash + cash_delta
      }

      if (is.list(result) && !is.null(result$state_update)) {
        state_json <- canonical_json(result$state_update)
        state_prev_mem <- result$state_update
        if (identical(event_mode, "live")) {
          output_handler$write_strategy_state(ts_utc = ts_iso, state_json = state_json)
        } else {
          output_handler$buffer_strategy_state(ts_utc = ts_iso, state_json = state_json)
        }
      }

      processed <<- processed + 1L

      if (telemetry_stride > 0L && processed %% telemetry_stride == 0L) {
        telemetry_idx <- telemetry_idx + 1L
        telemetry$t_pulse[[telemetry_idx]] <- ledgr_time_elapsed(
          pulse_start,
          ledgr_time_now()
        )
        telemetry$t_bars[[telemetry_idx]] <- NA_real_
        telemetry$t_ctx[[telemetry_idx]] <- NA_real_
        telemetry$t_fill[[telemetry_idx]] <- NA_real_
        telemetry$t_state[[telemetry_idx]] <- NA_real_
        telemetry$t_feats[[telemetry_idx]] <- NA_real_
        telemetry$t_strat[[telemetry_idx]] <- NA_real_
        telemetry$t_exec[[telemetry_idx]] <- NA_real_
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
    next_event_seq = event_seq,
    run_feature_matrix = run_feature_matrix
  )
}

ledgr_opening_position_event_rows <- function(run_id,
                                              ts_utc,
                                              positions,
                                              cost_basis,
                                              event_seq_start) {
  if (length(positions) == 0L) {
    return(data.frame())
  }
  rows <- vector("list", length(positions))
  idx <- 0L
  event_seq <- event_seq_start
  for (instrument_id in names(positions)) {
    qty <- as.numeric(positions[[instrument_id]])
    if (!is.finite(qty) || qty == 0) {
      next
    }
    cb <- as.numeric(cost_basis[[instrument_id]] %||% NA_real_)
    if (!is.finite(cb)) {
      rlang::abort(
        paste0(
          "Opening position for instrument '", instrument_id,
          "' requires a finite cost basis."
        ),
        class = "ledgr_opening_cost_basis_missing"
      )
    }
    idx <- idx + 1L
    meta <- list(
      source = "opening_position",
      cash_delta = 0,
      position_delta = qty,
      cost_basis = cb,
      opening_position = TRUE
    )
    rows[[idx]] <- data.frame(
      event_id = paste0(run_id, "_", sprintf("%08d", event_seq)),
      run_id = run_id,
      ts_utc = as.POSIXct(ledgr_normalize_ts_utc(ts_utc), tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ"),
      event_type = "CASHFLOW",
      instrument_id = instrument_id,
      side = NA_character_,
      qty = qty,
      price = cb,
      fee = 0,
      meta_json = canonical_json(meta),
      event_seq = event_seq,
      stringsAsFactors = FALSE
    )
    event_seq <- event_seq + 1L
  }
  if (idx == 0L) {
    return(data.frame())
  }
  do.call(rbind, rows[seq_len(idx)])
}

ledgr_equity_from_events <- function(events,
                                     pulses_posix,
                                     close_mat,
                                     initial_cash,
                                     instrument_ids,
                                     run_id) {
  n_pulses <- length(pulses_posix)
  events <- if (is.null(events) || nrow(events) == 0L) {
    data.frame()
  } else {
    events[order(events$event_seq), , drop = FALSE]
  }
  n_events <- nrow(events)

  if (n_pulses == 0L) {
    return(ledgr_empty_equity_curve())
  }

  event_ts <- if (n_events > 0L) {
    as.POSIXct(events$ts_utc, tz = "UTC")
  } else {
    as.POSIXct(character(0), tz = "UTC")
  }
  event_ts_num <- as.numeric(event_ts)
  pulse_ts_num <- as.numeric(pulses_posix)

  cash_delta <- numeric(n_events)
  position_delta <- numeric(n_events)
  event_meta <- vector("list", n_events)
  if (n_events > 0L) {
    for (i in seq_len(n_events)) {
      meta <- jsonlite::fromJSON(events$meta_json[[i]], simplifyVector = FALSE)
      event_meta[[i]] <- meta
      cash_delta[[i]] <- as.numeric(meta$cash_delta %||% 0)
      position_delta[[i]] <- as.numeric(meta$position_delta %||% 0)
    }
  }

  idx <- findInterval(pulse_ts_num, event_ts_num)
  cash_cum <- if (n_events > 0L) cumsum(cash_delta) else numeric(0)
  cash_at <- rep(as.numeric(initial_cash), length(idx))
  has_event <- idx > 0L
  if (any(has_event)) {
    cash_at[has_event] <- as.numeric(initial_cash) + cash_cum[idx[has_event]]
  }

  n_inst <- length(instrument_ids)
  positions_mat <- matrix(0, nrow = n_inst, ncol = n_pulses)
  if (n_events > 0L) {
    for (j in seq_along(instrument_ids)) {
      id <- instrument_ids[[j]]
      ev_idx <- which(events$instrument_id == id)
      if (length(ev_idx) == 0L) next
      pos_cum <- cumsum(position_delta[ev_idx])
      idx_inst <- findInterval(pulse_ts_num, event_ts_num[ev_idx])
      has_inst_event <- idx_inst > 0L
      if (any(has_inst_event)) {
        positions_mat[j, has_inst_event] <- pos_cum[idx_inst[has_inst_event]]
      }
    }
  }

  positions_value <- if (n_pulses > 0L) colSums(positions_mat * close_mat) else numeric(0)

  reconstruction_lots <- ledgr_lot_state(instrument_ids)
  event_realized <- numeric(n_events)
  event_cost_basis <- numeric(n_events)
  if (n_events > 0L) {
    for (i in seq_len(n_events)) {
      lot_res <- ledgr_lot_apply_event(
        reconstruction_lots,
        event_type = events$event_type[[i]],
        instrument_id = events$instrument_id[[i]],
        side = events$side[[i]],
        qty = events$qty[[i]],
        price = events$price[[i]],
        fee = events$fee[[i]],
        meta = event_meta[[i]]
      )
      reconstruction_lots <- lot_res$state
      event_realized[[i]] <- reconstruction_lots$realized_pnl
      event_cost_basis[[i]] <- reconstruction_lots$total_cost_basis
    }
  }

  realized_at <- numeric(length(idx))
  cost_basis_at <- numeric(length(idx))
  if (any(has_event)) {
    realized_at[has_event] <- event_realized[idx[has_event]]
    cost_basis_at[has_event] <- event_cost_basis[idx[has_event]]
  }

  equity <- cash_at + positions_value
  unrealized <- positions_value - cost_basis_at

  data.frame(
    run_id = rep(run_id, length(pulses_posix)),
    ts_utc = pulses_posix,
    cash = cash_at,
    positions_value = positions_value,
    equity = equity,
    realized_pnl = realized_at,
    unrealized_pnl = unrealized,
    stringsAsFactors = FALSE
  )
}

ledgr_fills_from_events <- function(events) {
  if (is.null(events) || nrow(events) == 0L) {
    return(ledgr_empty_fills_table())
  }

  events <- events[order(events$event_seq), , drop = FALSE]
  instrument_ids <- unique(stats::na.omit(events$instrument_id))
  lot_state <- ledgr_lot_state(instrument_ids)
  rows <- list()
  out_idx <- 0L

  for (i in seq_len(nrow(events))) {
    ev <- events[i, , drop = FALSE]
    event_type <- as.character(ev$event_type[[1]])
    inst <- as.character(ev$instrument_id[[1]])
    side <- as.character(ev$side[[1]])
    qty <- suppressWarnings(as.numeric(ev$qty[[1]]))
    price <- suppressWarnings(as.numeric(ev$price[[1]]))
    fee <- suppressWarnings(as.numeric(ev$fee[[1]]))
    if (identical(ev$event_type[[1]], "CASHFLOW")) {
      meta <- jsonlite::fromJSON(ev$meta_json[[1]], simplifyVector = FALSE)
      lot_res <- ledgr_lot_apply_event(
        lot_state,
        event_type = event_type,
        instrument_id = inst,
        side = side,
        qty = qty,
        price = price,
        fee = fee,
        meta = meta
      )
      lot_state <- lot_res$state
      next
    }
    if (!identical(ev$event_type[[1]], "FILL") &&
        !identical(ev$event_type[[1]], "FILL_PARTIAL")) {
      next
    }

    meta <- jsonlite::fromJSON(ev$meta_json[[1]], simplifyVector = FALSE)
    if (is.na(qty) || qty <= 0 || is.na(price)) {
      out_idx <- out_idx + 1L
      rows[[out_idx]] <- data.frame(
        event_seq = ev$event_seq[[1]],
        ts_utc = ev$ts_utc[[1]],
        instrument_id = inst,
        side = side,
        qty = qty,
        price = price,
        fee = fee,
        realized_pnl = NA_real_,
        action = NA_character_,
        stringsAsFactors = FALSE
      )
      next
    }

    side_norm <- toupper(side)
    if (!(side_norm %in% c("BUY", "COVER", "BUY_TO_COVER", "SELL", "SHORT", "SELL_SHORT"))) {
      out_idx <- out_idx + 1L
      rows[[out_idx]] <- data.frame(
        event_seq = ev$event_seq[[1]],
        ts_utc = ev$ts_utc[[1]],
        instrument_id = inst,
        side = side,
        qty = qty,
        price = price,
        fee = fee,
        realized_pnl = NA_real_,
        action = NA_character_,
        stringsAsFactors = FALSE
      )
      next
    }

    lot_res <- ledgr_lot_apply_event(
      lot_state,
      event_type = event_type,
      instrument_id = inst,
      side = side,
      qty = qty,
      price = price,
      fee = fee,
      meta = meta
    )
    close_qty <- lot_res$close_qty
    open_qty <- lot_res$open_qty
    realized_close <- lot_res$realized_close
    lot_state <- lot_res$state

    if (close_qty > 0) {
      out_idx <- out_idx + 1L
      rows[[out_idx]] <- data.frame(
        event_seq = ev$event_seq[[1]],
        ts_utc = ev$ts_utc[[1]],
        instrument_id = inst,
        side = side,
        qty = close_qty,
        price = price,
        fee = fee,
        realized_pnl = realized_close,
        action = "CLOSE",
        stringsAsFactors = FALSE
      )
    }
    if (open_qty > 0) {
      out_idx <- out_idx + 1L
      rows[[out_idx]] <- data.frame(
        event_seq = ev$event_seq[[1]],
        ts_utc = ev$ts_utc[[1]],
        instrument_id = inst,
        side = side,
        qty = open_qty,
        price = price,
        fee = fee,
        realized_pnl = 0,
        action = "OPEN",
        stringsAsFactors = FALSE
      )
    }
  }

  if (out_idx == 0L) {
    return(ledgr_empty_fills_table())
  }
  tibble::as_tibble(do.call(rbind, rows))
}

ledgr_bars_per_year_from_pulses <- function(pulses_posix) {
  if (length(pulses_posix) < 2L) {
    return(252)
  }
  diffs <- as.numeric(diff(pulses_posix), units = "secs")
  snap_to_frequency(stats::median(diffs, na.rm = TRUE))
}

ledgr_metrics_from_equity_fills <- function(equity,
                                            fills,
                                            bars_per_year = 252,
                                            risk_free_rate = 0) {
  equity_values <- equity$equity
  total_return <- if (length(equity_values) == 0L ||
      !is.finite(equity_values[[1]]) ||
      equity_values[[1]] == 0) {
    NA_real_
  } else {
    equity_values[[length(equity_values)]] / equity_values[[1]] - 1
  }

  returns <- compute_period_returns(equity_values)
  closed <- ledgr_closed_trade_rows(fills)
  n_trades <- nrow(closed)
  win_rate <- if (n_trades == 0L) {
    NA_real_
  } else {
    mean(closed$realized_pnl > 0, na.rm = TRUE)
  }
  avg_trade <- if (n_trades == 0L) {
    NA_real_
  } else {
    mean(closed$realized_pnl, na.rm = TRUE)
  }

  list(
    total_return = total_return,
    annualized_return = compute_annualized_return(equity, bars_per_year),
    volatility = compute_annualized_volatility(returns, bars_per_year),
    sharpe_ratio = compute_sharpe_ratio(
      returns,
      bars_per_year = bars_per_year,
      risk_free_rate = risk_free_rate
    ),
    max_drawdown = compute_max_drawdown(equity_values),
    n_trades = n_trades,
    win_rate = win_rate,
    avg_trade = avg_trade,
    time_in_market = compute_time_in_market(equity)
  )
}
