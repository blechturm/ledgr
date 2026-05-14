.ledgr_sweep_id_state <- new.env(parent = emptyenv())
.ledgr_sweep_id_state$counter <- 0L

#' Run a sequential parameter sweep
#'
#' `ledgr_sweep()` evaluates a `ledgr_param_grid` against a `ledgr_experiment`
#' without writing candidate runs to the experiment store.
#'
#' @param exp A `ledgr_experiment`.
#' @param param_grid A `ledgr_param_grid`.
#' @param precomputed_features Optional `ledgr_precomputed_features` object.
#' @param seed Optional integer-like master seed. When supplied, each candidate
#'   receives a deterministic derived execution seed.
#' @param stop_on_error Logical. When `FALSE`, candidate-level execution errors
#'   are captured as failed rows; when `TRUE`, they are rethrown.
#' @return A `ledgr_sweep_results` tibble.
#' @export
ledgr_sweep <- function(exp,
                        param_grid,
                        precomputed_features = NULL,
                        seed = NULL,
                        stop_on_error = FALSE) {
  if (!inherits(exp, "ledgr_experiment")) {
    rlang::abort("`exp` must be a ledgr_experiment object.", class = "ledgr_invalid_args")
  }
  if (!inherits(param_grid, "ledgr_param_grid")) {
    rlang::abort("`param_grid` must be a ledgr_param_grid object.", class = "ledgr_invalid_args")
  }
  if (!is.logical(stop_on_error) || length(stop_on_error) != 1L || is.na(stop_on_error)) {
    rlang::abort("`stop_on_error` must be TRUE or FALSE.", class = "ledgr_invalid_args")
  }
  seed <- ledgr_seed_normalize(seed)

  preflight <- ledgr_strategy_preflight(exp$strategy)
  if (!isTRUE(preflight$allowed)) {
    ledgr_abort_strategy_preflight(preflight)
  }

  ledgr_warn_large_grid_without_precomputed_features(param_grid, precomputed_features)
  if (!is.null(precomputed_features)) {
    ledgr_validate_precomputed_features(
      precomputed = precomputed_features,
      exp = exp,
      param_grid = param_grid,
      resolve_features = FALSE
    )
  }

  meta <- ledgr_precompute_snapshot_meta(exp$snapshot)
  range <- ledgr_precompute_scoring_range(meta)
  bars_by_id <- ledgr_precompute_fetch_bars(
    exp$snapshot,
    exp$universe,
    range$warmup_start,
    range$scoring_end
  )
  bars_by_id <- ledgr_sweep_normalize_bars_by_id(bars_by_id, exp$universe)
  ledgr_precompute_validate_static_coverage(bars_by_id, exp$universe)
  bars_mat <- ledgr_sweep_bars_matrix(bars_by_id, exp$universe)
  pulses_posix <- as.POSIXct(bars_by_id[[exp$universe[[1L]]]]$ts_utc, tz = "UTC")
  pulses_iso <- vapply(pulses_posix, ledgr_normalize_ts_utc, character(1))
  bars_per_year <- ledgr_bars_per_year_from_pulses(pulses_posix)

  if (is.null(precomputed_features)) {
    resolved <- ledgr_resolve_feature_candidates(exp, param_grid, stop_on_error = FALSE)
  } else {
    resolved <- ledgr_sweep_resolved_from_precomputed(precomputed_features, param_grid)
  }

  sweep_id <- ledgr_generate_sweep_id()
  rows <- vector("list", length(param_grid$params))
  source_info <- ledgr_strategy_source_info(exp$strategy)
  strategy_hash <- source_info$hash

  for (i in seq_along(param_grid$params)) {
    label <- param_grid$labels[[i]]
    params <- param_grid$params[[i]]
    execution_seed <- if (is.null(seed)) {
      NA_integer_
    } else {
      ledgr_derive_seed(seed, list(run_id = label, params = params))
    }

    candidate <- resolved$candidates[[i]]
    feature_row <- resolved$candidate_features[i, , drop = FALSE]
    if (identical(feature_row$status[[1]], "failed")) {
      if (isTRUE(stop_on_error)) {
        stop(candidate$error)
      }
      rows[[i]] <- ledgr_sweep_failure_row(
        run_id = label,
        params = params,
        execution_seed = execution_seed,
        error_class = feature_row$error_class[[1]],
        error_msg = feature_row$error_msg[[1]],
        feature_fingerprints = feature_row$feature_fingerprints[[1]],
        provenance = ledgr_sweep_provenance(
          snapshot_hash = meta$snapshot_hash,
          strategy_hash = strategy_hash,
          feature_set_hash = feature_row$feature_set_hash[[1]],
          master_seed = seed
        ),
        warnings = list()
      )
      next
    }

    warnings <- list()
    row <- tryCatch(
      withCallingHandlers(
        ledgr_sweep_run_candidate(
          exp = exp,
          run_id = label,
          params = params,
          execution_seed = execution_seed,
          bars_by_id = bars_by_id,
          bars_mat = bars_mat,
          pulses_posix = pulses_posix,
          pulses_iso = pulses_iso,
          bars_per_year = bars_per_year,
          candidate = candidate,
          candidate_feature_row = feature_row,
          precomputed_features = precomputed_features,
          snapshot_hash = meta$snapshot_hash,
          strategy_hash = strategy_hash,
          master_seed = seed
        ),
        warning = function(w) {
          warnings <<- c(warnings, list(w))
          invokeRestart("muffleWarning")
        }
      ),
      error = function(e) {
        if (isTRUE(stop_on_error)) {
          stop(e)
        }
        ledgr_sweep_failure_row(
          run_id = label,
          params = params,
          execution_seed = execution_seed,
          error_class = ledgr_condition_class(e),
          error_msg = conditionMessage(e),
          feature_fingerprints = feature_row$feature_fingerprints[[1]],
          provenance = ledgr_sweep_provenance(
            snapshot_hash = meta$snapshot_hash,
            strategy_hash = strategy_hash,
            feature_set_hash = feature_row$feature_set_hash[[1]],
            master_seed = seed
          ),
          warnings = warnings
        )
      }
    )
    row$warnings[[1]] <- warnings
    rows[[i]] <- row
  }

  out <- tibble::as_tibble(do.call(rbind, rows))
  attr(out, "sweep_id") <- sweep_id
  attr(out, "snapshot_hash") <- meta$snapshot_hash
  attr(out, "master_seed") <- seed
  attr(out, "seed_contract") <- "ledgr_seed_v1"
  attr(out, "evaluation_scope") <- "exploratory"
  attr(out, "strategy_preflight") <- preflight
  attr(out, "candidate_features") <- resolved$candidate_features
  class(out) <- c("ledgr_sweep_results", class(out))
  out
}

ledgr_generate_sweep_id <- function() {
  .ledgr_sweep_id_state$counter <- as.integer(.ledgr_sweep_id_state$counter %||% 0L) + 1L
  payload <- list(
    pid = Sys.getpid(),
    counter = .ledgr_sweep_id_state$counter,
    time = ledgr_normalize_ts_utc(Sys.time())
  )
  paste0("sweep_", substr(digest::digest(canonical_json(payload), algo = "sha256"), 1L, 16L))
}

ledgr_sweep_run_candidate <- function(exp,
                                      run_id,
                                      params,
                                      execution_seed,
                                      bars_by_id,
                                      bars_mat,
                                      pulses_posix,
                                      pulses_iso,
                                      bars_per_year,
                                      candidate,
                                      candidate_feature_row,
                                      precomputed_features,
                                      snapshot_hash,
                                      strategy_hash,
                                      master_seed) {
  feature_defs <- candidate$feature_defs
  feature_fingerprints <- candidate_feature_row$feature_fingerprints[[1]]
  run_feature_matrix <- if (is.null(precomputed_features)) {
    ledgr_sweep_compute_feature_matrix(feature_defs, bars_by_id, exp$universe)
  } else {
    ledgr_sweep_feature_matrix_from_precomputed(
      precomputed_features,
      feature_fingerprints,
      bars_by_id,
      exp$universe
    )
  }

  output_handler <- ledgr_memory_output_handler(run_id)
  opening_positions <- exp$opening$positions
  opening_cost_basis <- exp$opening$cost_basis
  if (is.null(opening_cost_basis) && length(opening_positions) > 0L) {
    opening_cost_basis <- stats::setNames(rep(NA_real_, length(opening_positions)), names(opening_positions))
  }
  opening_rows <- ledgr_opening_position_event_rows(
    run_id = run_id,
    ts_utc = pulses_posix[[1L]],
    positions = opening_positions,
    cost_basis = opening_cost_basis,
    event_seq_start = 1L
  )
  output_handler$append_event_rows(opening_rows)

  initial_positions <- stats::setNames(rep(0, length(exp$universe)), exp$universe)
  if (length(opening_positions) > 0L) {
    initial_positions[names(opening_positions)] <- as.numeric(opening_positions)
  }
  telemetry <- ledgr_sweep_telemetry_env()
  cost_resolver <- ledgr_cost_spread_commission_internal(
    spread_bps = exp$fill_model$spread_bps,
    commission_fixed = exp$fill_model$commission_fixed
  )
  signature <- ledgr_strategy_signature(exp$strategy)
  execution <- list(
    run_id = run_id,
    instrument_ids = exp$universe,
    strategy_fn = exp$strategy,
    strategy_params = params,
    strategy_call_signature = signature,
    strategy_is_functional = TRUE,
    pulses_posix = pulses_posix,
    pulses_iso = pulses_iso,
    start_idx = 1L,
    max_pulses = Inf,
    checkpoint_every = 0L,
    telemetry_stride = 0L,
    state = list(cash = exp$opening$cash, positions = initial_positions),
    state_prev = NULL,
    bars_by_id = bars_by_id,
    bars_mat = bars_mat,
    feature_defs = feature_defs,
    run_feature_matrix = run_feature_matrix,
    cost_resolver = cost_resolver,
    event_seq_start = as.integer(nrow(opening_rows)) + 1L,
    telemetry = telemetry,
    seed = if (is.na(execution_seed)) NULL else execution_seed,
    event_mode = "buffered",
    use_fast_context = FALSE
  )
  ledgr_execute_fold(execution, output_handler)

  events <- output_handler$events()
  equity <- ledgr_equity_from_events(
    events = events,
    pulses_posix = pulses_posix,
    close_mat = bars_mat$close,
    initial_cash = exp$opening$cash,
    instrument_ids = exp$universe,
    run_id = run_id
  )
  fills <- ledgr_fills_from_events(events)
  metrics <- ledgr_metrics_from_equity_fills(
    equity = equity,
    fills = fills,
    bars_per_year = bars_per_year
  )
  final_equity <- if (nrow(equity) > 0L) equity$equity[[nrow(equity)]] else NA_real_

  ledgr_sweep_success_row(
    run_id = run_id,
    params = params,
    execution_seed = execution_seed,
    final_equity = final_equity,
    metrics = metrics,
    feature_fingerprints = feature_fingerprints,
    provenance = ledgr_sweep_provenance(
      snapshot_hash = snapshot_hash,
      strategy_hash = strategy_hash,
      feature_set_hash = candidate_feature_row$feature_set_hash[[1]],
      master_seed = master_seed
    ),
    warnings = list()
  )
}

ledgr_memory_output_handler <- function(run_id) {
  state <- new.env(parent = emptyenv())
  state$events <- list()
  state$status <- "RUNNING"
  handler <- list()

  handler$run_transaction <- function(fn) fn()
  handler$record_run_status <- function(status, error_msg = NA_character_) {
    state$status <- status
    state$error_msg <- error_msg
    invisible(TRUE)
  }
  handler$write_telemetry <- function(...) invisible(TRUE)
  handler$store_session_telemetry <- function(...) invisible(TRUE)
  handler$record_failure <- function(msg) {
    handler$record_run_status("FAILED", msg)
    invisible(TRUE)
  }
  handler$abort_run <- function(msg, class = "ledgr_run_failed") {
    handler$record_failure(msg)
    rlang::abort(msg, class = class)
  }
  handler$init_buffers <- function(max_events) {
    invisible(TRUE)
  }
  handler$append_event_rows <- function(rows) {
    if (!is.null(rows) && nrow(rows) > 0L) {
      for (i in seq_len(nrow(rows))) {
        state$events[[length(state$events) + 1L]] <- rows[i, , drop = FALSE]
      }
    }
    invisible(TRUE)
  }
  handler$buffer_event <- function(write_res) {
    if (inherits(write_res, "ledgr_ledger_write_result") &&
        identical(write_res$status, "WROTE")) {
      handler$append_event_rows(ledgr_event_row_df(write_res$row))
    }
    invisible(TRUE)
  }
  handler$pending_event_count <- function() 0L
  handler$flush_pending <- function() invisible(TRUE)
  handler$write_fill_events <- function(fill_intent, event_seq, use_transaction = FALSE) {
    write_res <- ledgr_fill_event_row(run_id, fill_intent, event_seq)
    handler$buffer_event(write_res)
    write_res
  }
  handler$buffer_strategy_state <- function(...) invisible(TRUE)
  handler$write_strategy_state <- function(...) invisible(TRUE)
  handler$events <- function() {
    if (length(state$events) == 0L) {
      return(ledgr_empty_event_table())
    }
    tibble::as_tibble(do.call(rbind, state$events))
  }
  structure(handler, class = "ledgr_memory_output_handler")
}

ledgr_event_row_df <- function(row) {
  data.frame(
    event_id = row$event_id,
    run_id = row$run_id,
    ts_utc = row$ts_utc,
    event_type = row$event_type,
    instrument_id = row$instrument_id,
    side = row$side,
    qty = row$qty,
    price = row$price,
    fee = row$fee,
    meta_json = row$meta_json,
    event_seq = row$event_seq,
    stringsAsFactors = FALSE
  )
}

ledgr_empty_event_table <- function() {
  tibble::tibble(
    event_id = character(),
    run_id = character(),
    ts_utc = as.POSIXct(character(), tz = "UTC"),
    event_type = character(),
    instrument_id = character(),
    side = character(),
    qty = numeric(),
    price = numeric(),
    fee = numeric(),
    meta_json = character(),
    event_seq = integer()
  )
}

ledgr_sweep_success_row <- function(run_id,
                                    params,
                                    execution_seed,
                                    final_equity,
                                    metrics,
                                    feature_fingerprints,
                                    provenance,
                                    warnings) {
  ledgr_sweep_row(
    run_id = run_id,
    status = "DONE",
    final_equity = final_equity,
    total_return = metrics$total_return,
    annualized_return = metrics$annualized_return,
    volatility = metrics$volatility,
    sharpe_ratio = metrics$sharpe_ratio,
    max_drawdown = metrics$max_drawdown,
    n_trades = metrics$n_trades,
    win_rate = metrics$win_rate,
    avg_trade = metrics$avg_trade,
    time_in_market = metrics$time_in_market,
    execution_seed = execution_seed,
    error_class = NA_character_,
    error_msg = NA_character_,
    params = params,
    warnings = warnings,
    feature_fingerprints = feature_fingerprints,
    provenance = provenance
  )
}

ledgr_sweep_failure_row <- function(run_id,
                                    params,
                                    execution_seed,
                                    error_class,
                                    error_msg,
                                    feature_fingerprints,
                                    provenance,
                                    warnings) {
  ledgr_sweep_row(
    run_id = run_id,
    status = "FAILED",
    final_equity = NA_real_,
    total_return = NA_real_,
    annualized_return = NA_real_,
    volatility = NA_real_,
    sharpe_ratio = NA_real_,
    max_drawdown = NA_real_,
    n_trades = NA_integer_,
    win_rate = NA_real_,
    avg_trade = NA_real_,
    time_in_market = NA_real_,
    execution_seed = execution_seed,
    error_class = error_class,
    error_msg = error_msg,
    params = params,
    warnings = warnings,
    feature_fingerprints = feature_fingerprints,
    provenance = provenance
  )
}

ledgr_sweep_row <- function(run_id,
                            status,
                            final_equity,
                            total_return,
                            annualized_return,
                            volatility,
                            sharpe_ratio,
                            max_drawdown,
                            n_trades,
                            win_rate,
                            avg_trade,
                            time_in_market,
                            execution_seed,
                            error_class,
                            error_msg,
                            params,
                            warnings,
                            feature_fingerprints,
                            provenance) {
  tibble::tibble(
    run_id = run_id,
    status = status,
    final_equity = final_equity,
    total_return = total_return,
    annualized_return = annualized_return,
    volatility = volatility,
    sharpe_ratio = sharpe_ratio,
    max_drawdown = max_drawdown,
    n_trades = as.integer(n_trades),
    win_rate = win_rate,
    avg_trade = avg_trade,
    time_in_market = time_in_market,
    execution_seed = as.integer(execution_seed),
    error_class = error_class,
    error_msg = error_msg,
    params = list(params),
    warnings = list(warnings),
    feature_fingerprints = list(feature_fingerprints),
    provenance = list(provenance)
  )
}

ledgr_sweep_provenance <- function(snapshot_hash,
                                   strategy_hash,
                                   feature_set_hash,
                                   master_seed) {
  list(
    provenance_version = "ledgr_provenance_v1",
    snapshot_hash = snapshot_hash,
    strategy_hash = strategy_hash,
    feature_set_hash = feature_set_hash,
    master_seed = master_seed,
    seed_contract = "ledgr_seed_v1",
    evaluation_scope = "exploratory"
  )
}

ledgr_sweep_telemetry_env <- function() {
  telemetry <- new.env(parent = emptyenv())
  telemetry$t_pre <- NA_real_
  telemetry$t_post <- NA_real_
  telemetry$t_loop <- NA_real_
  telemetry$telemetry_stride <- 0L
  telemetry$telemetry_samples <- 0L
  telemetry$t_pulse <- numeric()
  telemetry$t_bars <- numeric()
  telemetry$t_ctx <- numeric()
  telemetry$t_fill <- numeric()
  telemetry$t_state <- numeric()
  telemetry$t_feats <- numeric()
  telemetry$t_strat <- numeric()
  telemetry$t_exec <- numeric()
  telemetry$feature_cache_hits <- 0L
  telemetry$feature_cache_misses <- 0L
  telemetry
}

ledgr_sweep_normalize_bars_by_id <- function(bars_by_id, universe) {
  for (id in universe) {
    b <- bars_by_id[[id]]
    if (is.null(b)) next
    b <- b[order(b$ts_utc), , drop = FALSE]
    if (!"gap_type" %in% names(b)) {
      b$gap_type <- ""
    }
    if (!"is_synthetic" %in% names(b)) {
      b$is_synthetic <- FALSE
    }
    bars_by_id[[id]] <- b
  }
  bars_by_id
}

ledgr_sweep_bars_matrix <- function(bars_by_id, universe) {
  first <- bars_by_id[[universe[[1L]]]]
  n_inst <- length(universe)
  n_pulses <- nrow(first)
  out <- list(
    open = matrix(NA_real_, nrow = n_inst, ncol = n_pulses),
    high = matrix(NA_real_, nrow = n_inst, ncol = n_pulses),
    low = matrix(NA_real_, nrow = n_inst, ncol = n_pulses),
    close = matrix(NA_real_, nrow = n_inst, ncol = n_pulses),
    volume = matrix(NA_real_, nrow = n_inst, ncol = n_pulses),
    gap_type = matrix("", nrow = n_inst, ncol = n_pulses),
    is_synthetic = matrix(FALSE, nrow = n_inst, ncol = n_pulses)
  )
  for (j in seq_along(universe)) {
    b <- bars_by_id[[universe[[j]]]]
    out$open[j, ] <- as.numeric(b$open)
    out$high[j, ] <- as.numeric(b$high)
    out$low[j, ] <- as.numeric(b$low)
    out$close[j, ] <- as.numeric(b$close)
    out$volume[j, ] <- as.numeric(b$volume)
    out$gap_type[j, ] <- as.character(b$gap_type)
    out$is_synthetic[j, ] <- as.logical(b$is_synthetic)
  }
  out
}

ledgr_sweep_compute_feature_matrix <- function(feature_defs, bars_by_id, universe) {
  if (length(feature_defs) == 0L) {
    return(list())
  }
  def_ids <- vapply(feature_defs, function(def) def$id, character(1))
  out <- vector("list", length(feature_defs))
  for (d in seq_along(feature_defs)) {
    def <- feature_defs[[d]]
    mat <- matrix(NA_real_, nrow = length(universe), ncol = nrow(bars_by_id[[universe[[1L]]]]))
    for (j in seq_along(universe)) {
      mat[j, ] <- as.numeric(ledgr_compute_feature_series(bars_by_id[[universe[[j]]]], def))
    }
    out[[d]] <- mat
  }
  names(out) <- def_ids
  out
}

ledgr_sweep_feature_matrix_from_precomputed <- function(precomputed,
                                                        feature_fingerprints,
                                                        bars_by_id,
                                                        universe) {
  if (length(feature_fingerprints) == 0L) {
    return(list())
  }
  out <- vector("list", length(feature_fingerprints))
  feature_ids <- character(length(feature_fingerprints))
  for (d in seq_along(feature_fingerprints)) {
    fingerprint <- feature_fingerprints[[d]]
    payload <- precomputed$payload[[fingerprint]]
    if (is.null(payload)) {
      rlang::abort(
        sprintf("Missing precomputed payload for feature fingerprint %s.", fingerprint),
        class = "ledgr_precomputed_feature_mismatch"
      )
    }
    mat <- matrix(NA_real_, nrow = length(universe), ncol = nrow(bars_by_id[[universe[[1L]]]]))
    for (j in seq_along(universe)) {
      mat[j, ] <- as.numeric(payload$values[[universe[[j]]]])
    }
    out[[d]] <- mat
    feature_ids[[d]] <- payload$feature_id
  }
  names(out) <- feature_ids
  out
}

ledgr_sweep_resolved_from_precomputed <- function(precomputed, param_grid) {
  candidates <- vector("list", length(param_grid$params))
  for (i in seq_along(param_grid$params)) {
    row <- precomputed$candidate_features[i, , drop = FALSE]
    feature_ids <- row$feature_ids[[1]]
    fingerprints <- row$feature_fingerprints[[1]]
    feature_defs <- Map(function(id, fingerprint) {
      list(id = id, fingerprint = fingerprint)
    }, feature_ids, fingerprints)
    candidates[[i]] <- list(
      label = param_grid$labels[[i]],
      params = param_grid$params[[i]],
      feature_defs = feature_defs,
      feature_ids = feature_ids,
      fingerprints = fingerprints,
      feature_set_hash = row$feature_set_hash[[1]]
    )
  }
  list(candidates = candidates, candidate_features = precomputed$candidate_features)
}
