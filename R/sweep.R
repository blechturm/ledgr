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
  strategy_name <- ledgr_sweep_strategy_name(exp$strategy)

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
  feature_union <- ledgr_sweep_feature_union(resolved$candidate_features)
  attr(out, "sweep_id") <- sweep_id
  attr(out, "snapshot_id") <- exp$snapshot$snapshot_id
  attr(out, "snapshot_hash") <- meta$snapshot_hash
  attr(out, "scoring_range") <- list(start = range$scoring_start, end = range$scoring_end)
  attr(out, "universe") <- exp$universe
  attr(out, "master_seed") <- seed
  attr(out, "seed_contract") <- "ledgr_seed_v1"
  attr(out, "evaluation_scope") <- "exploratory"
  attr(out, "strategy_hash") <- strategy_hash
  attr(out, "strategy_name") <- strategy_name
  attr(out, "strategy_source_capture_method") <- source_info$capture_method
  attr(out, "strategy_preflight") <- preflight
  attr(out, "feature_union") <- feature_union
  attr(out, "feature_union_hash") <- ledgr_feature_set_hash(feature_union)
  attr(out, "candidate_features") <- resolved$candidate_features
  attr(out, "execution_assumptions") <- list(
    execution_mode = exp$execution_mode,
    fill_model = exp$fill_model,
    opening = exp$opening,
    precomputed_features = !is.null(precomputed_features),
    stop_on_error = stop_on_error
  )
  class(out) <- c("ledgr_sweep_results", class(out))
  out
}

#' Select one sweep candidate for promotion
#'
#' @param results A `ledgr_sweep_results` object or tibble-like object with
#'   `run_id`, `params`, `execution_seed`, and `provenance` columns.
#' @param which Candidate selector. A character scalar selects by `run_id`; an
#'   integer-like scalar selects by row position.
#' @param allow_failed Logical. Failed candidates error by default.
#' @return A `ledgr_sweep_candidate` object.
#' @details The returned candidate carries `selection_view`, the tibble-like
#'   view passed to `ledgr_candidate()`. Promotion-context storage uses that
#'   view to record the filtered/sorted candidate table the user selected from.
#' @export
ledgr_candidate <- function(results, which = 1L, allow_failed = FALSE) {
  if (!is.logical(allow_failed) || length(allow_failed) != 1L || is.na(allow_failed)) {
    rlang::abort("`allow_failed` must be TRUE or FALSE.", class = "ledgr_invalid_args")
  }
  is_sweep_results <- inherits(results, "ledgr_sweep_results")
  view <- tibble::as_tibble(results)
  required <- c("run_id", "params", "execution_seed", "provenance")
  missing <- setdiff(required, names(view))
  if (length(missing) > 0L) {
    rlang::abort(
      sprintf("`results` is missing required candidate column(s): %s.", paste(missing, collapse = ", ")),
      class = "ledgr_invalid_sweep_candidate_input"
    )
  }
  if (nrow(view) < 1L) {
    rlang::abort("`results` must contain at least one candidate row.", class = "ledgr_invalid_sweep_candidate_input")
  }

  row_idx <- ledgr_candidate_row_index(view, which)
  row <- view[row_idx, , drop = FALSE]
  status <- if ("status" %in% names(row)) as.character(row$status[[1]]) else NA_character_
  if (!isTRUE(allow_failed) && identical(status, "FAILED")) {
    rlang::abort(
      sprintf("Candidate '%s' has status FAILED. Use `allow_failed = TRUE` for diagnostic extraction.", row$run_id[[1]]),
      class = "ledgr_failed_sweep_candidate"
    )
  }

  if (!is_sweep_results) {
    message("Note: input is not a `ledgr_sweep_results` object; sweep-level metadata will not be available in the candidate.")
  }

  sweep_meta <- ledgr_candidate_sweep_meta(results, is_sweep_results)
  out <- list(
    run_id = as.character(row$run_id[[1]]),
    status = status,
    params = row$params[[1]],
    execution_seed = as.integer(row$execution_seed[[1]]),
    provenance = row$provenance[[1]],
    row = row,
    selection_view = view,
    sweep_meta = sweep_meta
  )
  if ("warnings" %in% names(row)) out$warnings <- row$warnings[[1]]
  if ("feature_fingerprints" %in% names(row)) out$feature_fingerprints <- row$feature_fingerprints[[1]]
  structure(out, class = c("ledgr_sweep_candidate", "list"))
}

#' Promote a sweep candidate to a committed run
#'
#' @param exp A `ledgr_experiment`.
#' @param candidate A `ledgr_sweep_candidate`.
#' @param run_id Non-empty run identifier for the committed run.
#' @param note Optional plain-text note. Stored by the promotion-context ticket.
#' @param require_same_snapshot Logical. If `TRUE`, require the candidate
#'   provenance snapshot hash to match `exp`. Defaults to `TRUE`; train/test
#'   promotion must opt into cross-snapshot execution with `FALSE`.
#' @return A committed `ledgr_backtest`.
#' @export
ledgr_promote <- function(exp,
                          candidate,
                          run_id,
                          note = NULL,
                          require_same_snapshot = TRUE) {
  if (!inherits(exp, "ledgr_experiment")) {
    rlang::abort("`exp` must be a ledgr_experiment object.", class = "ledgr_invalid_args")
  }
  if (!inherits(candidate, "ledgr_sweep_candidate")) {
    rlang::abort("`candidate` must be a ledgr_sweep_candidate object.", class = "ledgr_invalid_args")
  }
  if (!is.character(run_id) || length(run_id) != 1L || is.na(run_id) || !nzchar(run_id)) {
    rlang::abort("`run_id` must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }
  if (!is.null(note) && (!is.character(note) || length(note) != 1L || is.na(note) || !nzchar(note))) {
    rlang::abort("`note` must be NULL or a non-empty character scalar.", class = "ledgr_invalid_args")
  }
  if (!is.logical(require_same_snapshot) || length(require_same_snapshot) != 1L || is.na(require_same_snapshot)) {
    rlang::abort("`require_same_snapshot` must be TRUE or FALSE.", class = "ledgr_invalid_args")
  }
  if (identical(candidate$status, "FAILED")) {
    rlang::abort(
      sprintf(
        "Cannot promote failed candidate '%s'. Use `allow_failed = TRUE` only for diagnostic extraction.",
        candidate$run_id
      ),
      class = "ledgr_promote_failed_candidate"
    )
  }

  if (isTRUE(require_same_snapshot)) {
    ledgr_candidate_validate_same_snapshot(exp, candidate)
  }

  seed <- candidate$execution_seed
  if (length(seed) != 1L || is.na(seed)) {
    seed <- NULL
  }
  bt <- ledgr_run(
    exp = exp,
    params = candidate$params,
    run_id = run_id,
    seed = seed
  )
  ledgr_promote_write_context_or_warn(bt, candidate, note)
  attr(bt, "promotion_note") <- note
  bt
}

#' @export
print.ledgr_sweep_candidate <- function(x, ...) {
  strategy <- ledgr_candidate_strategy_label(x)
  seed <- if (length(x$execution_seed) == 1L && !is.na(x$execution_seed)) {
    as.character(x$execution_seed)
  } else {
    "-"
  }
  feature_hash <- x$provenance$feature_set_hash %||% NA_character_
  snapshot_hash <- x$provenance$snapshot_hash %||% NA_character_
  evaluation_scope <- x$provenance$evaluation_scope %||% NA_character_

  cat("ledgr_sweep_candidate\n")
  cat("=====================\n")
  cat("Run label:        ", x$run_id, "\n", sep = "")
  cat("Status:           ", x$status %||% NA_character_, "\n", sep = "")
  cat("Execution seed:   ", seed, "\n", sep = "")
  cat("Strategy:         ", strategy, "\n", sep = "")
  cat("Snapshot hash:    ", snapshot_hash, "\n", sep = "")
  cat("Feature-set hash: ", feature_hash, "\n", sep = "")
  cat("Evaluation scope: ", evaluation_scope, "\n", sep = "")
  cat("Params:           ", canonical_json(x$params), "\n", sep = "")
  invisible(x)
}

#' @export
print.ledgr_sweep_results <- function(x, ...) {
  status <- as.character(x$status)
  n_done <- sum(status == "DONE", na.rm = TRUE)
  n_failed <- sum(status == "FAILED", na.rm = TRUE)
  visible <- c(
    "run_id", "status", "sharpe_ratio", "total_return",
    "max_drawdown", "n_trades", "execution_seed"
  )
  hidden <- setdiff(names(x), visible)
  ledgr_print_curated_tibble(
    sprintf("# ledgr sweep -- %s", attr(x, "sweep_id") %||% "<unknown>"),
    x,
    cols = visible,
    footer = c(
      sprintf("%d combinations: %d done, %d failed.", nrow(x), n_done, n_failed),
      "Rows are in parameter-grid order; rank explicitly with dplyr when needed.",
      sprintf("Hidden columns (%d): %s", length(hidden), paste(hidden, collapse = ", "))
    ),
    ...
  )
}

ledgr_candidate_row_index <- function(view, which) {
  if (is.character(which) && length(which) == 1L && !is.na(which) && nzchar(which)) {
    matches <- base::which(as.character(view$run_id) == which)
    if (length(matches) != 1L) {
      rlang::abort(
        sprintf("Expected exactly one candidate with run_id '%s'; found %d.", which, length(matches)),
        class = "ledgr_sweep_candidate_not_found"
      )
    }
    return(matches[[1]])
  }
  if (is.numeric(which) && length(which) == 1L && !is.na(which) &&
      is.finite(which) && which == as.integer(which)) {
    idx <- as.integer(which)
    if (idx < 1L || idx > nrow(view)) {
      rlang::abort("Candidate row position is out of bounds.", class = "ledgr_sweep_candidate_not_found")
    }
    return(idx)
  }
  rlang::abort("`which` must be a character run_id or integer row position.", class = "ledgr_invalid_args")
}

ledgr_candidate_sweep_meta <- function(results, is_sweep_results) {
  if (!isTRUE(is_sweep_results)) {
    return(NULL)
  }
  keys <- c(
    "sweep_id", "snapshot_id", "snapshot_hash", "scoring_range", "universe",
    "master_seed", "seed_contract", "evaluation_scope", "strategy_hash",
    "strategy_name", "strategy_source_capture_method", "strategy_preflight",
    "feature_union", "feature_union_hash", "execution_assumptions"
  )
  stats::setNames(lapply(keys, function(key) attr(results, key, exact = TRUE)), keys)
}

ledgr_candidate_validate_same_snapshot <- function(exp, candidate) {
  provenance <- candidate$provenance
  if (!is.list(provenance) ||
      is.null(provenance$snapshot_hash) ||
      !is.character(provenance$snapshot_hash) ||
      length(provenance$snapshot_hash) != 1L ||
      is.na(provenance$snapshot_hash) ||
      !nzchar(provenance$snapshot_hash)) {
    rlang::abort(
      "`require_same_snapshot = TRUE` needs candidate provenance with `snapshot_hash`.",
      class = "ledgr_candidate_missing_snapshot_hash"
    )
  }
  meta <- ledgr_precompute_snapshot_meta(exp$snapshot)
  if (!identical(provenance$snapshot_hash, meta$snapshot_hash)) {
    rlang::abort(
      "Candidate snapshot hash does not match the target experiment snapshot.",
      class = "ledgr_candidate_snapshot_mismatch"
    )
  }
  invisible(TRUE)
}

ledgr_candidate_strategy_label <- function(candidate) {
  meta <- candidate$sweep_meta
  name <- if (is.list(meta)) meta$strategy_name else NULL
  hash <- if (is.list(meta)) meta$strategy_hash else candidate$provenance$strategy_hash
  has_name <- is.character(name) && length(name) == 1L && !is.na(name) && nzchar(name)
  has_hash <- is.character(hash) && length(hash) == 1L && !is.na(hash) && nzchar(hash)
  if (has_name && has_hash) {
    return(sprintf("%s (%s)", name, substr(hash, 1L, 12L)))
  }
  if (has_hash) {
    return(substr(hash, 1L, 12L))
  }
  if (has_name) {
    return(name)
  }
  "<unknown>"
}

ledgr_sweep_strategy_name <- function(strategy) {
  name <- attr(strategy, "name", exact = TRUE)
  if (is.character(name) && length(name) == 1L && !is.na(name) && nzchar(name)) {
    return(name)
  }
  name <- attr(strategy, "ledgr_strategy_name", exact = TRUE)
  if (is.character(name) && length(name) == 1L && !is.na(name) && nzchar(name)) {
    return(name)
  }
  NULL
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

ledgr_sweep_feature_union <- function(candidate_features) {
  if (!"feature_fingerprints" %in% names(candidate_features)) {
    return(character())
  }
  values <- unlist(candidate_features$feature_fingerprints, use.names = FALSE)
  sort(unique(as.character(values)))
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
