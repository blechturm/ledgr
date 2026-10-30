# Probe namespace seam: availability producer only. Canonical observe/decide,
# commit, lifecycle, lot representation, JSON encoder and output buffer remain.
install_carrier <- function(folder, mutation = 'none', lot = 'native', indexed = FALSE) {
  ns <- asNamespace('ledgr')
  e <- new.env(parent = ns)
  source(file.path(folder, 'additional-arms.R'), local = e)
  if (lot == 'native') {
    Rcpp::sourceCpp(file.path(folder, 'carrier.cpp'), env = e,
      cacheDir = file.path(Sys.getenv('TEMP'), 'ws4a-cpp-cache'), verbose = FALSE)
  } else {
    e$carrier_lots <- e$carrier_lots_canonical
    e$carrier_afford <- e$carrier_afford_canonical
  }
  if (lot == 'typed') source(file.path(folder, 'typed-lots.R'), local = e)
  e$lot_kind <- lot
  e$indexed <- indexed
  e$mutation <- mutation
  e$original_plan <- ns$ledgr_fold_stage_plan
  e$original_apply <- ns$ledgr_fold_stage_apply
  patch <- function(name, fn) {
    environment(fn) <- e
    utils::assignInNamespace(name, fn, ns = 'ledgr')
  }
  # Metadata must retain the production encoder. This is the only deliberate
  # per-fill R traversal left in the event component; it is measured separately.
  e$carrier_payload <- function(b, serialize) {
    n <- length(b$qty)
    meta <- Map(function(fee, cash, signed) list(fee = as.numeric(fee),
      cash_delta = as.numeric(cash), position_delta = as.numeric(signed), realized_pnl = NULL),
      b$fee, b$cash_delta, b$signed)
    json <- if (serialize)
      vapply(meta, ledgr_canonical_json_encode, character(1)) else rep(NA_character_, n)
    list(meta = meta, json = json)
  }
  environment(e$carrier_payload) <- e
  e$carrier_events <- function(handler, b, lots, run_id, seq_start) {
    env <- environment(handler$buffer_event)
    n <- length(b$qty)
    seq <- as.integer(seq_start + seq_len(n) - 1L)
    if (mutation == 'drop_fee') {
      b$fee[1L] <- 0
      b$cash_delta <- ifelse(b$signed > 0, -(b$qty * b$price + b$fee), b$qty * b$price - b$fee)
    }
    payload <- carrier_payload(b, env$sink$serialize_meta_json)
    meta <- payload$meta; json <- payload$json
    rows <- list(event_id = paste0(run_id, '_', sprintf('%08d', seq)),
      run_id = rep(run_id, n), ts_utc = .POSIXct(b$ts, tz = 'UTC'),
      event_type = rep('FILL', n), instrument_id = b$id, side = b$side,
      qty = b$qty, price = b$price, fee = b$fee, meta_json = json, event_seq = seq)
    first <- env$state$event_count + 1L
    index <- first + seq_len(n) - 1L
    env$ensure_event_capacity(max(index))
    # Iteration is over the fixed schema, never over event rows.
    for (nm in names(rows)) ledgr_event_buffer_setv(env$state$event_cols, nm, index, rows[[nm]])
    if (env$typed) {
      values <- list(cash_delta = b$cash_delta, position_delta = b$signed,
        event_realized = lots$event_realized, event_cost_basis = lots$event_basis, meta = meta)
      for (nm in names(values)) ledgr_event_buffer_setv(env$state$event_cols, nm, index, values[[nm]])
      # Leg ordering is close then open for each event, as canonical accounting.
      leg_event <- rep(seq_len(n), each = 2L)
      leg_qty <- as.vector(rbind(lots$close_qty, lots$open_qty))
      keep <- which(leg_qty > 0); k <- leg_event[keep]
      closed <- keep %% 2L == 1L
      cf <- ifelse(lots$close_qty > 0, b$fee * lots$close_qty /
        (lots$close_qty + lots$open_qty), 0)
      of <- ifelse(lots$open_qty > 0, b$fee - cf, 0)
      leg_batch <- list(fill_event_seq = seq[k], fill_ts_utc = b$ts[k],
        fill_instrument_id = b$id[k], fill_side = b$side[k], fill_qty = leg_qty[keep],
        fill_price = b$price[k], fill_fee = ifelse(closed, cf[k], of[k]),
        fill_realized_pnl = ifelse(closed, lots$realized_close[k], 0),
        fill_action = ifelse(closed, 'CLOSE', 'OPEN'))
      if (indexed) carrier_retained_indexed(env$sink, leg_batch) else env$sink$add_legs_many(leg_batch)
    }
    env$state$event_count <- max(index)
    invisible(NULL)
  }
  environment(e$carrier_events) <- e
  patch('ledgr_fold_stage_plan', function(fold_state, services, observation, decision,
                                         sample_telemetry, sample_start) {
    if (!services$availability_active) stop('carrier probe requires availability producer')
    fold_state$current_stage <- 'execution'
    targets <- decision$targets; ids <- names(targets)
    idx <- as.integer(services$id_to_idx[ids])
    current <- as.numeric(fold_state$positions[idx])
    delta <- as.numeric(targets) - current
    act <- which(abs(delta) > sqrt(.Machine$double.eps))
    ts <- if (observation$pulse_idx <= length(services$execution_opportunities_posix))
      as.numeric(services$execution_opportunities_posix[observation$pulse_idx]) else NA_real_
    id <- ids[act]; inst <- idx[act]; before <- current[act]; signed <- delta[act]
    n <- length(act); qty <- abs(signed); side <- ifelse(signed > 0, 'BUY', 'SELL')
    reason <- info <- rep('', n)
    price <- rep(NA_real_, n); fee <- numeric(n)
    eligible <- rep(FALSE, n)
    if (n && !is.na(ts)) {
      view <- services$availability_provider$execution_view(.POSIXct(ts, tz = 'UTC'), id)
      reason <- ifelse(as.logical(view$restricted[id]), as.character(view$reasons[id]), '')
      info <- ifelse(as.logical(observation$availability_view$member[id]) !=
        as.logical(view$member[id]), 'membership_changed_before_execution', '')
      price <- observation$history_bars$next_bar$open[inst]
      eligible <- is.finite(price) & price > 0
      reason[!eligible] <- ifelse(nzchar(reason[!eligible]),
        paste0(reason[!eligible], '|execution_bar_missing'), 'execution_bar_missing')
    } else if (n) reason[] <- 'final_pulse_no_execution'
    # Cost program is resolved once for the pulse; its fixed steps operate on vectors.
    cost <- environment(services$cost_resolver)
    for (step in cost$steps) {
      type <- step$type_id
      if (type == 'spread_bps') price <- price * ifelse(signed > 0,
        1 + step$args$bps / 20000, 1 - step$args$bps / 20000)
      else if (type == 'fixed_fee') fee <- fee + step$args$amount
      else if (type == 'notional_bps_fee') fee <- fee + abs(qty * price) * step$args$bps / 10000
      else stop('unsupported probe cost step')
    }
    price <- round(price, digits = cost$price_round_digits)
    cd <- ifelse(signed > 0, -(qty * price + fee), qty * price - fee)
    candidates <- which(eligible)
    accepted <- rep(FALSE, n); virtual <- fold_state$cash
    if (length(candidates)) {
      generator <- side[candidates] == 'SELL' & before[candidates] > 0 &
        signed[candidates] < 0 & cd[candidates] >= 0 & !nzchar(reason[candidates])
      priority <- order(!generator, enc2utf8(id[candidates]), method = 'radix')
      afford <- carrier_afford(cd[candidates], as.integer(priority),
        nzchar(reason[candidates]), fold_state$cash, ledgr_availability_cash_tolerance)
      accepted[candidates] <- afford$accepted; virtual <- afford$cash
      # All declared probe/A0 shapes are long-only; retain the canonical guard.
      ledgr_availability_validate_short_exposure(setNames(before[candidates] + signed[candidates],
        id[candidates]), setNames(before[candidates], id[candidates]))
      insufficient <- candidates[!afford$accepted & !nzchar(reason[candidates])]
      reason[insufficient] <- 'insufficient_cash'
    }
    rejected <- c(which(!eligible), which(eligible & !accepted))
    kept <- which(accepted)
    b <- list(id = id[kept], inst = inst[kept], qty = qty[kept], side = side[kept],
      signed = signed[kept], price = price[kept], fee = fee[kept],
      cash_delta = cd[kept], ts = rep(ts, length(kept)))
    segments <- list()
    if (length(rejected)) {
      r <- rejected; why <- ifelse(nzchar(info[r]), paste(reason[r], info[r], sep = '|'), reason[r])
      segments[[length(segments)+1L]] <- list(n = length(r), instrument_id = id[r],
        stage = 'execution', outcome = 'no_fill', reason_code = sub('\\|.*', '', reason[r]),
        reasons = why, target = targets[id[r]], quantity = before[r],
        price = ifelse(eligible[r], price[r], NA_real_), decision_ts_utc = observation$ts,
        execution_ts_utc = rep(ts, length(r)), target_before_risk = decision$strategy_targets[id[r]],
        target_after_risk = targets[id[r]], position_before = before[r], position_after = before[r])
    }
    if (length(kept)) {
      k <- kept
      segments[[length(segments)+1L]] <- list(n = length(k), instrument_id = id[k],
        stage = 'execution', outcome = 'filled', reason_code = info[k], reasons = info[k],
        target = targets[id[k]], quantity = qty[k], price = price[k],
        decision_ts_utc = observation$ts, execution_ts_utc = rep(ts, length(k)),
        event_seq = fold_state$event_seq + seq_along(k) - 1L,
        target_before_risk = decision$strategy_targets[id[k]], target_after_risk = targets[id[k]],
        position_before = before[k], position_after = before[k] + signed[k])
    }
    list(pulse_plan = list(targets = targets, actionable_idx = act, batch = b,
      expected_final_cash = virtual), diagnostic_segments = segments,
      sample_start = sample_start, t_target = decision$t_target, t_fill = 0)
  })
  patch('ledgr_fold_stage_apply', function(fold_state, services, observation, plan,
                                          sample_telemetry, sample_start) {
    b <- plan$pulse_plan$batch
    # The existing scheduled-skip carrier contains no fills and needs no fork.
    if (is.null(b)) return(original_apply(fold_state, services, observation, plan,
      sample_telemetry, sample_start))
    fold_state$current_stage <- 'accounting'
    if (!is.null(services$corporate_action_plan) && observation$pulse_idx < length(services$pulses_posix))
      services$corporate_action_plan$bind_boundary(observation$pulse_idx + 1L,
        ledgr_fold_positions_snapshot(fold_state$positions, services$instrument_ids))
    n <- length(b$qty)
    if (n) {
      if (mutation == 'reorder' && n > 1L) {
        order <- c(2L, 1L, if (n > 2L) 3:n else integer())
        b <- lapply(b, `[`, order)
      }
      lot_idx <- as.integer(fold_state$lot_state$instrument_index[b$id])
      if (anyNA(lot_idx)) stop('probe lot axis incomplete')
      lots <- if (lot_kind == 'typed') carrier_lots_typed(fold_state, lot_idx,
        b$qty, b$price, b$fee, as.integer(ifelse(b$signed > 0, 1, -1)), fold_state$cash) else
        carrier_lots(fold_state$lot_state, lot_idx, b$qty, b$price, b$fee,
          as.integer(ifelse(b$signed > 0, 1, -1)), fold_state$cash)
      fold_state$lot_state <- lots$state
      # Position authority is canonical lots, read once after the pulse batch.
      fold_state$positions <- setNames(as.numeric(lots$state$net_by_inst[
        services$instrument_ids]), services$instrument_ids)
      fold_state$cash <- lots$cash
      carrier_events(services$output_handler, b, lots, services$run_id, fold_state$event_seq)
      fold_state$event_seq <- as.integer(fold_state$event_seq + n)
    }
    list(sample_start = sample_start, t_event = 0, t_state = 0)
  })
  # Adapt only commit's two reads of the old fill-list carrier. No economics,
  # lifecycle or commit logic is replaced; the typed plan supplies the same values.
  adapt <- function(x) {
    if (!is.call(x)) return(x)
    if (identical(x, quote(length(pulse_plan$fills)))) return(quote(length(pulse_plan$batch$qty)))
    if (identical(x[[1]], as.name('vapply')) && identical(x[[2]], quote(pulse_plan$fills))) {
      if (grepl('execution_ts_utc', paste(deparse(x), collapse = ' '), fixed = TRUE))
        return(quote(pulse_plan$batch$ts))
      return(quote(pulse_plan$batch$cash_delta))
    }
    as.call(lapply(as.list(x), adapt))
  }
  commit <- ns$ledgr_fold_stage_commit
  body(commit) <- adapt(body(commit))
  patch('ledgr_fold_stage_commit', commit)
  invisible(e)
}
