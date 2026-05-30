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

      bars_current <- bars_views[[i]]
      features_current <- feature_table_views[[i]]
      if (!is.data.frame(features_current)) {
        features_current <- empty_feature_table
      }
      features_wide_current <- features_wide_views[[i]]
      if (!is.data.frame(features_wide_current)) {
        features_wide_current <- empty_df
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
          next
        }

        fill$instrument_id <- instrument_id
        fill$ts_signal_utc <- ts_iso

        write_res <- output_handler$write_fill_events(
          fill_intent = fill,
          event_seq = event_seq,
          use_transaction = identical(event_mode, "live")
        )
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
    next_event_seq = event_seq
  )
}

ledgr_event_buffer_initial_capacity <- function(max_events, initial_capacity = 1024L) {
  max_events <- ledgr_event_buffer_checked_capacity(max_events, "`max_events`")
  initial_capacity <- ledgr_event_buffer_checked_capacity(initial_capacity, "`initial_capacity`")
  as.integer(max(1L, min(max_events, initial_capacity)))
}

ledgr_event_buffer_next_capacity <- function(current_capacity,
                                             required,
                                             max_events,
                                             initial_capacity = 1024L,
                                             growth_factor = 2) {
  current_capacity <- as.integer(max(0L, current_capacity %||% 0L))
  required <- ledgr_event_buffer_checked_capacity(required, "`required`")
  max_events <- ledgr_event_buffer_checked_capacity(max_events, "`max_events`")
  if (required > max_events) {
    rlang::abort(
      "Ledger event buffer exceeded the run's maximum event capacity.",
      class = "ledgr_event_buffer_capacity_exceeded"
    )
  }
  if (required <= current_capacity) {
    return(as.integer(current_capacity))
  }
  if (!is.numeric(growth_factor) || length(growth_factor) != 1L || is.na(growth_factor) ||
      !is.finite(growth_factor) || growth_factor <= 1) {
    rlang::abort("`growth_factor` must be a finite numeric scalar > 1.", class = "ledgr_invalid_args")
  }
  capacity <- max(current_capacity, ledgr_event_buffer_initial_capacity(max_events, initial_capacity))
  while (capacity < required) {
    grown <- ceiling(capacity * growth_factor)
    if (grown <= capacity) {
      grown <- capacity + 1L
    }
    capacity <- min(max_events, max(required, grown))
  }
  as.integer(capacity)
}

ledgr_event_buffer_checked_capacity <- function(x, label) {
  if (!is.numeric(x) || length(x) != 1L || is.na(x) || !is.finite(x) || x < 1 || x != floor(x)) {
    rlang::abort(sprintf("%s must be a positive integer-like scalar.", label), class = "ledgr_invalid_args")
  }
  if (x > .Machine$integer.max) {
    rlang::abort(sprintf("%s exceeds R's integer vector length limit.", label), class = "ledgr_invalid_args")
  }
  as.integer(x)
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

ledgr_typed_event_metadata <- function(events, order_idx = NULL) {
  n_events <- if (is.null(events)) 0L else nrow(events)
  if (n_events == 0L) {
    return(NULL)
  }
  cash_delta <- attr(events, "ledgr_event_cash_delta", exact = TRUE)
  position_delta <- attr(events, "ledgr_event_position_delta", exact = TRUE)
  meta <- attr(events, "ledgr_event_meta", exact = TRUE)
  if (length(cash_delta) != n_events ||
      length(position_delta) != n_events ||
      length(meta) != n_events) {
    return(NULL)
  }
  if (!is.null(order_idx)) {
    cash_delta <- cash_delta[order_idx]
    position_delta <- position_delta[order_idx]
    meta <- meta[order_idx]
  }
  list(
    cash_delta = as.numeric(cash_delta),
    position_delta = as.numeric(position_delta),
    meta = meta
  )
}

ledgr_event_meta_at <- function(events, typed_meta, i) {
  if (!is.null(typed_meta)) {
    meta <- typed_meta$meta[[i]]
    if (!is.null(meta)) {
      return(meta)
    }
  }
  jsonlite::fromJSON(events$meta_json[[i]], simplifyVector = FALSE)
}

ledgr_equity_from_events <- function(events,
                                     pulses_posix,
                                     close_mat,
                                     initial_cash,
                                     instrument_ids,
                                     run_id) {
  n_pulses <- length(pulses_posix)
  typed_meta <- NULL
  events <- if (is.null(events) || nrow(events) == 0L) {
    data.frame()
  } else {
    order_idx <- order(events$event_seq)
    typed_meta <- ledgr_typed_event_metadata(events, order_idx = order_idx)
    events[order_idx, , drop = FALSE]
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
    if (!is.null(typed_meta)) {
      cash_delta <- typed_meta$cash_delta
      position_delta <- typed_meta$position_delta
    }
    for (i in seq_len(n_events)) {
      meta <- ledgr_event_meta_at(events, typed_meta, i)
      event_meta[[i]] <- meta
      if (is.null(typed_meta)) {
        cash_delta[[i]] <- as.numeric(meta$cash_delta %||% 0)
        position_delta[[i]] <- as.numeric(meta$position_delta %||% 0)
      }
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

ledgr_fill_row_buffer <- function(capacity) {
  capacity <- max(1L, as.integer(capacity %||% 1L))
  buffer <- new.env(parent = emptyenv())
  buffer$capacity <- capacity
  buffer$n <- 0L
  buffer$event_seq <- integer(capacity)
  buffer$ts_utc <- rep(as.POSIXct(NA_real_, origin = "1970-01-01", tz = "UTC"), capacity)
  buffer$instrument_id <- character(capacity)
  buffer$side <- character(capacity)
  buffer$qty <- numeric(capacity)
  buffer$price <- numeric(capacity)
  buffer$fee <- numeric(capacity)
  buffer$realized_pnl <- numeric(capacity)
  buffer$action <- character(capacity)
  buffer
}

ledgr_fill_row_buffer_grow <- function(buffer, required) {
  if (required <= buffer$capacity) {
    return(invisible(buffer))
  }
  old_capacity <- buffer$capacity
  new_capacity <- old_capacity
  while (new_capacity < required) {
    new_capacity <- max(required, new_capacity * 2L)
  }
  idx <- seq_len(buffer$n)
  grow_posix <- function(x) {
    out <- rep(as.POSIXct(NA_real_, origin = "1970-01-01", tz = "UTC"), new_capacity)
    if (buffer$n > 0L) out[idx] <- x[idx]
    out
  }
  grow_vector <- function(x, prototype) {
    out <- rep(prototype, new_capacity)
    if (buffer$n > 0L) out[idx] <- x[idx]
    out
  }
  buffer$event_seq <- grow_vector(buffer$event_seq, integer(1))
  buffer$ts_utc <- grow_posix(buffer$ts_utc)
  buffer$instrument_id <- grow_vector(buffer$instrument_id, character(1))
  buffer$side <- grow_vector(buffer$side, character(1))
  buffer$qty <- grow_vector(buffer$qty, numeric(1))
  buffer$price <- grow_vector(buffer$price, numeric(1))
  buffer$fee <- grow_vector(buffer$fee, numeric(1))
  buffer$realized_pnl <- grow_vector(buffer$realized_pnl, numeric(1))
  buffer$action <- grow_vector(buffer$action, character(1))
  buffer$capacity <- as.integer(new_capacity)
  invisible(buffer)
}

ledgr_fill_row_buffer_add <- function(buffer,
                                      event_seq,
                                      ts_utc,
                                      instrument_id,
                                      side,
                                      qty,
                                      price,
                                      fee,
                                      realized_pnl,
                                      action) {
  i <- buffer$n + 1L
  if (i > buffer$capacity) {
    ledgr_fill_row_buffer_grow(buffer, i)
  }
  buffer$event_seq[[i]] <- as.integer(event_seq)
  buffer$ts_utc[[i]] <- as.POSIXct(ts_utc, tz = "UTC")
  buffer$instrument_id[[i]] <- as.character(instrument_id)
  buffer$side[[i]] <- as.character(side)
  buffer$qty[[i]] <- as.numeric(qty)
  buffer$price[[i]] <- as.numeric(price)
  buffer$fee[[i]] <- as.numeric(fee)
  buffer$realized_pnl[[i]] <- as.numeric(realized_pnl)
  buffer$action[[i]] <- as.character(action)
  buffer$n <- i
  invisible(buffer)
}

ledgr_fill_row_buffer_data_frame <- function(buffer) {
  if (buffer$n == 0L) {
    return(as.data.frame(ledgr_empty_fills_table()))
  }
  idx <- seq_len(buffer$n)
  data.frame(
    event_seq = buffer$event_seq[idx],
    ts_utc = buffer$ts_utc[idx],
    instrument_id = buffer$instrument_id[idx],
    side = buffer$side[idx],
    qty = buffer$qty[idx],
    price = buffer$price[idx],
    fee = buffer$fee[idx],
    realized_pnl = buffer$realized_pnl[idx],
    action = buffer$action[idx],
    stringsAsFactors = FALSE
  )
}

ledgr_fill_row_buffer_tibble <- function(buffer) {
  tibble::as_tibble(ledgr_fill_row_buffer_data_frame(buffer))
}

ledgr_fills_from_events <- function(events) {
  if (is.null(events) || nrow(events) == 0L) {
    return(ledgr_empty_fills_table())
  }

  order_idx <- order(events$event_seq)
  typed_meta <- ledgr_typed_event_metadata(events, order_idx = order_idx)
  events <- events[order_idx, , drop = FALSE]
  instrument_ids <- unique(stats::na.omit(events$instrument_id))
  lot_state <- ledgr_lot_state(instrument_ids)
  fill_rows <- ledgr_fill_row_buffer(nrow(events) * 2L)

  event_seq_col <- .subset2(events, "event_seq")
  ts_utc_col <- .subset2(events, "ts_utc")
  event_type_col <- .subset2(events, "event_type")
  instrument_col <- .subset2(events, "instrument_id")
  side_col <- .subset2(events, "side")
  qty_col <- .subset2(events, "qty")
  price_col <- .subset2(events, "price")
  fee_col <- .subset2(events, "fee")

  for (i in seq_len(nrow(events))) {
    event_type <- as.character(event_type_col[[i]])
    inst <- as.character(instrument_col[[i]])
    side <- as.character(side_col[[i]])
    qty <- suppressWarnings(as.numeric(qty_col[[i]]))
    price <- suppressWarnings(as.numeric(price_col[[i]]))
    fee <- suppressWarnings(as.numeric(fee_col[[i]]))
    if (identical(event_type, "CASHFLOW")) {
      meta <- ledgr_event_meta_at(events, typed_meta, i)
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
    if (!identical(event_type, "FILL") &&
        !identical(event_type, "FILL_PARTIAL")) {
      next
    }

    meta <- ledgr_event_meta_at(events, typed_meta, i)
    if (is.na(qty) || qty <= 0 || is.na(price)) {
      ledgr_fill_row_buffer_add(
        fill_rows,
        event_seq_col[[i]], ts_utc_col[[i]], inst, side, qty, price, fee,
        NA_real_, NA_character_
      )
      next
    }

    side_norm <- toupper(side)
    if (!(side_norm %in% c("BUY", "COVER", "BUY_TO_COVER", "SELL", "SHORT", "SELL_SHORT"))) {
      ledgr_fill_row_buffer_add(
        fill_rows,
        event_seq_col[[i]], ts_utc_col[[i]], inst, side, qty, price, fee,
        NA_real_, NA_character_
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
      ledgr_fill_row_buffer_add(
        fill_rows,
        event_seq_col[[i]], ts_utc_col[[i]], inst, side, close_qty, price, fee,
        realized_close, "CLOSE"
      )
    }
    if (open_qty > 0) {
      ledgr_fill_row_buffer_add(
        fill_rows,
        event_seq_col[[i]], ts_utc_col[[i]], inst, side, open_qty, price, fee,
        0, "OPEN"
      )
    }
  }

  if (fill_rows$n == 0L) {
    return(ledgr_empty_fills_table())
  }
  ledgr_fill_row_buffer_tibble(fill_rows)
}

ledgr_assert_events_in_fold_order <- function(events) {
  if (is.null(events) || nrow(events) < 2L) {
    return(invisible(TRUE))
  }
  event_seq <- suppressWarnings(as.integer(events$event_seq))
  if (any(is.na(event_seq)) || any(diff(event_seq) <= 0L)) {
    rlang::abort(
      "Sweep memory events must be in strictly increasing fold-produced event sequence order.",
      class = "ledgr_invalid_event_order"
    )
  }
  invisible(TRUE)
}

ledgr_sweep_summary_from_ordered_events <- function(events,
                                                    pulses_posix,
                                                    close_mat,
                                                    initial_cash,
                                                    instrument_ids,
                                                    run_id,
                                                    metric_kernel) {
  n_pulses <- length(pulses_posix)
  if (n_pulses == 0L) {
    equity <- ledgr_empty_equity_curve()
    fills <- ledgr_empty_fills_table()
    return(list(
      equity = equity,
      fills = fills,
      metrics = ledgr_metrics_from_equity_fills(
        equity = equity,
        fills = fills,
        metric_kernel = metric_kernel
      ),
      final_equity = NA_real_
    ))
  }

  events <- if (is.null(events) || nrow(events) == 0L) {
    data.frame()
  } else {
    ledgr_assert_events_in_fold_order(events)
    events
  }
  n_events <- nrow(events)
  typed_meta <- ledgr_typed_event_metadata(events)

  event_ts <- if (n_events > 0L) {
    as.POSIXct(events$ts_utc, tz = "UTC")
  } else {
    as.POSIXct(character(0), tz = "UTC")
  }
  event_ts_num <- as.numeric(event_ts)
  pulse_ts_num <- as.numeric(pulses_posix)
  idx <- findInterval(pulse_ts_num, event_ts_num)
  has_event <- idx > 0L

  cash_delta <- numeric(n_events)
  position_delta <- numeric(n_events)
  event_realized <- numeric(n_events)
  event_cost_basis <- numeric(n_events)
  if (!is.null(typed_meta)) {
    cash_delta <- typed_meta$cash_delta
    position_delta <- typed_meta$position_delta
  }

  max_fill_rows <- max(1L, n_events * 2L)
  fill_event_seq <- integer(max_fill_rows)
  fill_ts_utc <- rep(as.POSIXct(NA_real_, origin = "1970-01-01", tz = "UTC"), max_fill_rows)
  fill_instrument_id <- character(max_fill_rows)
  fill_side <- character(max_fill_rows)
  fill_qty <- numeric(max_fill_rows)
  fill_price <- numeric(max_fill_rows)
  fill_fee <- numeric(max_fill_rows)
  fill_realized_pnl <- numeric(max_fill_rows)
  fill_action <- character(max_fill_rows)
  fill_idx <- 0L

  add_fill_row <- function(i, inst, side, qty, price, fee, realized_pnl, action) {
    fill_idx <<- fill_idx + 1L
    fill_event_seq[[fill_idx]] <<- events$event_seq[[i]]
    fill_ts_utc[[fill_idx]] <<- event_ts[[i]]
    fill_instrument_id[[fill_idx]] <<- inst
    fill_side[[fill_idx]] <<- side
    fill_qty[[fill_idx]] <<- qty
    fill_price[[fill_idx]] <<- price
    fill_fee[[fill_idx]] <<- fee
    fill_realized_pnl[[fill_idx]] <<- realized_pnl
    fill_action[[fill_idx]] <<- action
    invisible(TRUE)
  }

  reconstruction_lots <- ledgr_lot_state(instrument_ids)
  if (n_events > 0L) {
    for (i in seq_len(n_events)) {
      event_type <- as.character(events$event_type[[i]])
      inst <- as.character(events$instrument_id[[i]])
      side <- as.character(events$side[[i]])
      qty <- suppressWarnings(as.numeric(events$qty[[i]]))
      price <- suppressWarnings(as.numeric(events$price[[i]]))
      fee <- suppressWarnings(as.numeric(events$fee[[i]]))
      meta <- ledgr_event_meta_at(events, typed_meta, i)
      if (is.null(typed_meta)) {
        cash_delta[[i]] <- as.numeric(meta$cash_delta %||% 0)
        position_delta[[i]] <- as.numeric(meta$position_delta %||% 0)
      }

      lot_res <- ledgr_lot_apply_event(
        reconstruction_lots,
        event_type = event_type,
        instrument_id = inst,
        side = side,
        qty = qty,
        price = price,
        fee = fee,
        meta = meta
      )
      reconstruction_lots <- lot_res$state
      event_realized[[i]] <- reconstruction_lots$realized_pnl
      event_cost_basis[[i]] <- reconstruction_lots$total_cost_basis

      if (identical(event_type, "CASHFLOW")) {
        next
      }
      if (!identical(event_type, "FILL") && !identical(event_type, "FILL_PARTIAL")) {
        next
      }
      if (is.na(qty) || qty <= 0 || is.na(price)) {
        add_fill_row(i, inst, side, qty, price, fee, NA_real_, NA_character_)
        next
      }
      side_norm <- toupper(side)
      if (!(side_norm %in% c("BUY", "COVER", "BUY_TO_COVER", "SELL", "SHORT", "SELL_SHORT"))) {
        add_fill_row(i, inst, side, qty, price, fee, NA_real_, NA_character_)
        next
      }
      if (isTRUE(lot_res$close_qty > 0)) {
        add_fill_row(i, inst, side, lot_res$close_qty, price, fee, lot_res$realized_close, "CLOSE")
      }
      if (isTRUE(lot_res$open_qty > 0)) {
        add_fill_row(i, inst, side, lot_res$open_qty, price, fee, 0, "OPEN")
      }
    }
  }

  cash_cum <- if (n_events > 0L) cumsum(cash_delta) else numeric(0)
  cash_at <- rep(as.numeric(initial_cash), length(idx))
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

  realized_at <- numeric(length(idx))
  cost_basis_at <- numeric(length(idx))
  if (any(has_event)) {
    realized_at[has_event] <- event_realized[idx[has_event]]
    cost_basis_at[has_event] <- event_cost_basis[idx[has_event]]
  }

  equity <- data.frame(
    run_id = rep(run_id, length(pulses_posix)),
    ts_utc = pulses_posix,
    cash = cash_at,
    positions_value = positions_value,
    equity = cash_at + positions_value,
    realized_pnl = realized_at,
    unrealized_pnl = positions_value - cost_basis_at,
    stringsAsFactors = FALSE
  )
  fills <- if (fill_idx == 0L) {
    ledgr_empty_fills_table()
  } else {
    tibble::tibble(
      event_seq = fill_event_seq[seq_len(fill_idx)],
      ts_utc = fill_ts_utc[seq_len(fill_idx)],
      instrument_id = fill_instrument_id[seq_len(fill_idx)],
      side = fill_side[seq_len(fill_idx)],
      qty = fill_qty[seq_len(fill_idx)],
      price = fill_price[seq_len(fill_idx)],
      fee = fill_fee[seq_len(fill_idx)],
      realized_pnl = fill_realized_pnl[seq_len(fill_idx)],
      action = fill_action[seq_len(fill_idx)]
    )
  }
  metrics <- ledgr_metrics_from_equity_fills(
    equity = equity,
    fills = fills,
    metric_kernel = metric_kernel
  )
  list(
    equity = equity,
    fills = fills,
    metrics = metrics,
    final_equity = equity$equity[[nrow(equity)]]
  )
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
                                            risk_free_rate = 0,
                                            metric_kernel = NULL) {
  if (!is.null(metric_kernel)) {
    bars_per_year <- metric_kernel$bars_per_year
    rf_period_return <- metric_kernel$rf_period_return
  } else {
    rf_period_return <- compute_rf_period_return(risk_free_rate, bars_per_year)
  }
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
      rf_period_return = rf_period_return
    ),
    max_drawdown = compute_max_drawdown(equity_values),
    n_trades = n_trades,
    win_rate = win_rate,
    avg_trade = avg_trade,
    time_in_market = compute_time_in_market(equity)
  )
}
