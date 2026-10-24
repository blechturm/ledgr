#' Freeze a pulse snapshot for strategy development
#'
#' `ledgr_pulse_snapshot()` constructs one strategy context outside execution
#' so that an author can inspect it or call a strategy manually. It is an
#' external development and inspection helper: a strategy never calls it.
#'
#' Called with an availability-aware `ledgr_experiment`, it derives everything
#' from that experiment and its concrete parameters: snapshot, universe,
#' features, history policy, data start and opening state. It returns the
#' context that a run of the experiment starting at `ts_utc` passes to its
#' strategy on that first pulse, built by the same observe-and-settle and
#' context stages over the same shared preparation. It calls no strategy and
#' creates no fills, events, run rows or other durable state. The context
#' supports [ledgr_history_frame()].
#'
#' Called with a `ledgr_snapshot`, the snapshot-and-universe form builds a
#' dense context from the given universe, features and positions. That form
#' has no causal history: [ledgr_history_frame()] refuses it.
#'
#' @param snapshot A `ledgr_snapshot`, or an availability-aware
#'   `ledgr_experiment` for experiment-derived inspection. With an experiment,
#'   supply only `ts_utc` (by name), `params` and `feature_params`.
#' @param universe Character vector of instruments (snapshot form only).
#' @param ts_utc Timestamp to freeze at. For an experiment it must name one
#'   session close of the declared venue; a `Date` selects that session's
#'   close.
#' @param features List of `ledgr_indicator` objects to compute.
#' @param feature_params JSON-safe list used to resolve parameterized feature
#'   declarations when `features` (or the experiment's features) is a feature
#'   map.
#' @param params JSON-safe strategy parameters used to resolve the experiment's
#'   feature factory and risk plan, as in [ledgr_run()] (experiment form
#'   only).
#' @param cash Cash held alongside `positions`. It is not total account value;
#'   pulse equity is `cash + sum(positions * current close)`.
#' @param positions Named numeric vector of positions (NULL = flat).
#' @param state_prev Optional JSON-safe previous strategy state. This supports
#'   dense one-pulse strategy checks; availability-aware state normalization is
#'   not simulated.
#'
#' @return A `ledgr_pulse_context` object with the accessors and planes of the
#'   strategy context (see `?ledgr_strategy_context`). The snapshot form makes
#'   every instrument a member.
#' @examples
#' bars <- data.frame(
#'   ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:3,
#'   instrument_id = "AAA",
#'   open = 100:103,
#'   high = 101:104,
#'   low = 99:102,
#'   close = 100:103,
#'   volume = 1000
#' )
#' snapshot <- ledgr_snapshot_from_df(bars)
#' pulse <- ledgr_pulse_snapshot(
#'   snapshot,
#'   universe = "AAA",
#'   ts_utc = "2020-01-03T00:00:00Z",
#'   features = list(ledgr_ind_sma(2)),
#'   positions = c(AAA = 2),
#'   state_prev = list(pulses_seen = 1)
#' )
#' pulse$close("AAA")
#' pulse$feature("AAA", "sma_2")
#' pulse$state_prev
#' close(pulse)
#' ledgr_snapshot_close(snapshot)
#' @export
ledgr_pulse_snapshot <- function(snapshot,
                                 universe,
                                 ts_utc,
                                 features = list(),
                                 feature_params = list(),
                                 cash = 100000,
                                 positions = NULL,
                                 state_prev = NULL,
                                 params = NULL) {
  if (inherits(snapshot, "ledgr_experiment")) {
    supplied <- c(
      universe = !missing(universe),
      features = !missing(features),
      cash = !missing(cash),
      positions = !missing(positions),
      state_prev = !missing(state_prev)
    )
    if (any(supplied)) {
      rlang::abort(
        sprintf(
          paste(
            "An experiment is the configuration authority for pulse inspection;",
            "supply only `ts_utc`, `params` and `feature_params`, not %s."
          ),
          paste(sprintf("`%s`", names(supplied)[supplied]), collapse = ", ")
        ),
        class = "ledgr_invalid_args"
      )
    }
    if (!isTRUE(snapshot$availability$active)) {
      rlang::abort(
        paste(
          "Experiment-derived pulse inspection requires an availability-aware",
          "experiment. Use ledgr_pulse_snapshot(snapshot, universe, ts_utc) for",
          "a dense inspection context."
        ),
        class = c("ledgr_pulse_snapshot_availability_required", "ledgr_invalid_args")
      )
    }
    if (is.null(params)) params <- list()
    if (!is.list(params) || is.data.frame(params)) {
      rlang::abort("`params` must be a list. Use `params = list()` when the strategy has no parameters.", class = "ledgr_invalid_args")
    }
    if (!is.list(feature_params) || is.data.frame(feature_params)) {
      rlang::abort("`feature_params` must be a list. Use `feature_params = list()` when features have no parameters.", class = "ledgr_invalid_args")
    }
    return(ledgr_pulse_inspection(snapshot, ts_utc, params, feature_params))
  }
  if (!inherits(snapshot, "ledgr_snapshot")) {
    rlang::abort(
      "`snapshot` must be a ledgr_snapshot object or an availability-aware ledgr_experiment.",
      class = "ledgr_invalid_args"
    )
  }
  if (!is.null(params)) {
    rlang::abort(
      "`params` applies only to experiment-derived pulse inspection.",
      class = "ledgr_invalid_args"
    )
  }
  if (!is.character(universe) || length(universe) < 1 || anyNA(universe) || any(!nzchar(universe))) {
    rlang::abort("`universe` must be a non-empty character vector.", class = "ledgr_invalid_args")
  }
  if (anyDuplicated(universe)) {
    rlang::abort("`universe` must not contain duplicate instrument_ids.", class = "ledgr_invalid_args")
  }
  if (!is.list(feature_params) || is.data.frame(feature_params)) {
    rlang::abort("`feature_params` must be a list. Use `feature_params = list()` when features have no parameters.", class = "ledgr_invalid_args")
  }
  alias_map_info <- ledgr_alias_map_storage(NULL)
  if (inherits(features, "ledgr_feature_map")) {
    ledgr_validate_feature_params_for_declarations(features, feature_params)
    features <- ledgr_resolve_feature_map(features, feature_params = feature_params)
    alias_map_info <- ledgr_alias_map_storage(ledgr_alias_map_from_feature_map(features))
    features <- ledgr_feature_map_indicators(features)
  }
  if (!is.list(features)) {
    rlang::abort("`features` must be a list or ledgr_feature_map.", class = "ledgr_invalid_args")
  }
  for (ind in features) {
    if (!inherits(ind, "ledgr_indicator")) {
      rlang::abort("`features` must contain ledgr_indicator objects.", class = "ledgr_invalid_args")
    }
  }
  if (!is.numeric(cash) || length(cash) != 1 || is.na(cash) || !is.finite(cash)) {
    rlang::abort("`cash` must be a finite numeric scalar.", class = "ledgr_invalid_args")
  }
  if (!is.null(state_prev)) invisible(canonical_json(state_prev))
  ts_norm <- ledgr_normalize_ts_utc(ts_utc)

  if (is.null(positions)) {
    positions <- stats::setNames(rep(0, length(universe)), universe)
  } else {
    if (!is.numeric(positions) || is.null(names(positions)) || anyNA(names(positions)) ||
        any(!nzchar(names(positions)))) {
      rlang::abort("`positions` must be a named numeric vector.", class = "ledgr_invalid_args")
    }
    if (anyDuplicated(names(positions))) {
      rlang::abort("`positions` must have unique instrument_id names.", class = "ledgr_invalid_args")
    }
    if (anyNA(positions) || any(!is.finite(positions))) {
      rlang::abort("`positions` must contain finite numeric quantities.", class = "ledgr_invalid_args")
    }
    extra <- setdiff(names(positions), universe)
    if (length(extra) > 0L) {
      rlang::abort(
        sprintf("`positions` contains instrument_ids outside `universe`: %s.", paste(extra, collapse = ", ")),
        class = "ledgr_invalid_args"
      )
    }
  }

  # The context verifies and reads bars and features once through the same
  # dedicated connection; it keeps no connection.
  opened <- ledgr_open_dedicated_snapshot(snapshot)
  on.exit(ledgr_snapshot_close(opened$snapshot), add = TRUE)
  con <- opened$con
  ledgr_snapshot_ensure_verified(
    con,
    snapshot$snapshot_id,
    snapshot_db_path = snapshot$db_path
  )

  e <- new.env(parent = emptyenv())
  e$ts_utc <- ts_norm
  e$universe <- universe
  e$members <- e$universe
  e$positions <- positions
  e$cash <- as.numeric(cash)
  e$state_prev <- state_prev
  e$feature_params <- feature_params
  e$active_alias_map <- alias_map_info$alias_map
  e$alias_map_json <- alias_map_info$alias_map_json
  e$alias_map_hash <- alias_map_info$alias_map_hash
  e$alias_map_version <- alias_map_info$alias_map_version
  e$.snapshot <- opened$snapshot

  bars <- tryCatch(
    {
      ledgr_fetch_latest_bars(con, snapshot$snapshot_id, universe, ts_norm)
    },
    error = function(err) {
      ledgr_snapshot_close(opened$snapshot)
      stop(err)
    }
  )
  features_df <- tryCatch(
    {
      ledgr_compute_pulse_features(con, snapshot$snapshot_id, universe, ts_norm, features)
    },
    error = function(err) {
      ledgr_snapshot_close(opened$snapshot)
      stop(err)
    }
  )

  e$bars <- bars
  e$features <- features_df
  position_vec <- stats::setNames(rep(0, length(universe)), universe)
  position_vec[names(positions)] <- as.numeric(positions)
  close_vec <- as.numeric(bars$close[match(universe, as.character(bars$instrument_id))])
  e$equity <- as.numeric(cash) + sum(position_vec * close_vec)
  ledgr_update_pulse_context_helpers(
    e,
    bars = bars,
    features = features_df,
    positions = e$positions,
    universe = e$universe,
    active_alias_map = e$active_alias_map
  )

  structure(e, class = "ledgr_pulse_context")
}

#' Print a pulse snapshot context
#'
#' @param x A `ledgr_pulse_context` object.
#' @param ... Unused.
#' @return The input object, invisibly.
#' @examples
#' bars <- data.frame(
#'   ts_utc = as.POSIXct("2020-01-01", tz = "UTC"),
#'   instrument_id = "AAA",
#'   open = 100,
#'   high = 101,
#'   low = 99,
#'   close = 100,
#'   volume = 1000
#' )
#' snapshot <- ledgr_snapshot_from_df(bars)
#' pulse <- ledgr_pulse_snapshot(snapshot, universe = "AAA", ts_utc = "2020-01-01T00:00:00Z")
#' print(pulse)
#' close(pulse)
#' ledgr_snapshot_close(snapshot)
#' @export
print.ledgr_pulse_context <- function(x, ...) {
  cat("ledgr Pulse Snapshot\n")
  cat("Timestamp: ", x$ts_utc, "\n", sep = "")
  cat("Universe:  ", paste(x$universe, collapse = ", "), "\n", sep = "")
  cat("Cash:      ", format(x$cash, scientific = FALSE, trim = TRUE), "\n", sep = "")
  cat("Equity:    ", format(x$equity, scientific = FALSE, trim = TRUE), "\n", sep = "")
  cat("Positions: ", sum(as.numeric(x$vec$position) != 0), " nonzero\n", sep = "")
  cat("State:     ", if (is.null(x$state_prev)) "none" else "supplied", "\n", sep = "")
  cat("Bars:      ", nrow(x$bars), "\n", sep = "")
  cat("Features:  ", nrow(x$features), "\n", sep = "")
  invisible(x)
}

#' Close pulse context
#'
#' @param con A `ledgr_pulse_context` object.
#' @param ... Unused.
#' @return The input object, invisibly.
#' @examples
#' bars <- data.frame(
#'   ts_utc = as.POSIXct("2020-01-01", tz = "UTC"),
#'   instrument_id = "AAA",
#'   open = 100,
#'   high = 101,
#'   low = 99,
#'   close = 100,
#'   volume = 1000
#' )
#' snapshot <- ledgr_snapshot_from_df(bars)
#' pulse <- ledgr_pulse_snapshot(snapshot, universe = "AAA", ts_utc = "2020-01-01T00:00:00Z")
#' close(pulse)
#' ledgr_snapshot_close(snapshot)
#' @export
close.ledgr_pulse_context <- function(con, ...) {
  if (is.environment(con) && !is.null(con$.snapshot)) {
    ledgr_snapshot_close(con$.snapshot)
    con$.con <- NULL
    con$.snapshot <- NULL
  }
  invisible(con)
}

ledgr_open_dedicated_snapshot <- function(snapshot) {
  temp <- new_ledgr_snapshot(snapshot$db_path, snapshot$snapshot_id, metadata = list())
  con <- get_connection(temp)
  list(con = con, snapshot = temp)
}

ledgr_fetch_latest_bars <- function(con, snapshot_id, universe, ts_utc) {
  if (length(universe) == 0L) return(NULL)
  rows <- ledgr_fetch_latest_bars_query(
    con, snapshot_id, unique(as.character(universe)), ts_utc
  )
  row_index <- match(as.character(universe), as.character(rows$instrument_id))
  missing <- which(is.na(row_index))
  if (length(missing) > 0L) {
    rlang::abort(
      sprintf(
        "No bars available for instrument '%s' at ts_utc.",
        universe[[missing[[1L]]]]
      ),
      class = "ledgr_invalid_args"
    )
  }
  out <- rows[row_index, , drop = FALSE]
  out$ts_utc <- vapply(out$ts_utc, ledgr_iso_utc, character(1))
  rownames(out) <- NULL
  out
}

ledgr_fetch_latest_bars_query <- function(con, snapshot_id, universe, ts_utc) {
  quoted_ids <- paste(DBI::dbQuoteString(con, universe), collapse = ", ")
  DBI::dbGetQuery(
    con,
    paste0(
      "SELECT instrument_id, ts_utc, open, high, low, close, volume ",
      "FROM snapshot_bars WHERE snapshot_id = ? ",
      "AND instrument_id IN (", quoted_ids, ") AND ts_utc = ?"
    ),
    params = list(snapshot_id, ts_utc)
  )
}

ledgr_compute_pulse_features <- function(con, snapshot_id, universe, ts_utc, features) {
  if (length(features) == 0) {
    return(data.frame())
  }

  quoted_ids <- paste(DBI::dbQuoteString(con, universe), collapse = ", ")
  history <- DBI::dbGetQuery(
    con,
    paste0(
      "SELECT instrument_id, ts_utc, open, high, low, close, volume ",
      "FROM snapshot_bars ",
      "WHERE snapshot_id = ? AND instrument_id IN (", quoted_ids, ") ",
      "AND ts_utc <= ? ",
      "ORDER BY instrument_id, ts_utc"
    ),
    params = list(snapshot_id, ts_utc)
  )
  history$instrument_id <- as.character(history$instrument_id)
  history_by_instrument <- split(history, history$instrument_id)

  n_features <- length(features)
  n_rows <- length(universe) * n_features
  instrument_id <- rep(as.character(universe), each = n_features)
  feature_name <- rep(
    vapply(features, function(feature) feature$id, character(1)),
    times = length(universe)
  )
  feature_value <- rep(NA_real_, n_rows)

  row_idx <- 1L
  for (inst in universe) {
    bars <- history_by_instrument[[inst]]
    if (is.null(bars) || nrow(bars) == 0L) {
      row_idx <- row_idx + n_features
      next
    }
    for (feature in features) {
      feature_value[[row_idx]] <- if (is.null(feature$series_fn)) {
        ledgr_compute_feature_latest(bars, feature)
      } else {
        values <- ledgr_compute_feature_series(bars, feature)
        values[[length(values)]]
      }
      row_idx <- row_idx + 1L
    }
  }

  data.frame(
    ts_utc = rep(ts_utc, n_rows),
    instrument_id = instrument_id,
    feature_name = feature_name,
    feature_value = feature_value,
    stringsAsFactors = FALSE
  )
}

ledgr_simplify_indicator_values <- function(values) {
  is_scalar_atomic <- vapply(
    values,
    function(x) {
      !is.null(x) && is.atomic(x) && !is.list(x) && length(x) == 1L
    },
    logical(1)
  )

  if (!all(is_scalar_atomic)) {
    return(I(values))
  }

  unlist(values, recursive = FALSE, use.names = FALSE)
}

# Experiment-derived pulse inspection (v12 Section 8, Cut 16 decision 10).
# It prepares exactly what a run of `exp` starting at the cutoff prepares, runs
# the shared fold core for that first pulse and stops when P2 hands the
# context to the strategy: P1 observe-and-settle and P2 context construction
# run, no strategy is called and P3 through P5 never run. The memory output
# handler is discarded, so no event, fill or run row is kept.
ledgr_pulse_inspection <- function(exp, ts_utc, params, feature_params) {
  release <- ledgr_snapshot_hold(exp$snapshot)
  on.exit(release(), add = TRUE)
  ledgr_snapshot_ensure_handle(exp$snapshot)
  meta <- ledgr_precompute_snapshot_meta(exp$snapshot)
  params_info <- ledgr_strategy_params_info(params)
  feature_params_info <- ledgr_strategy_params_info(feature_params)
  feature_result <- ledgr_experiment_materialize_feature_result(
    exp,
    params = params_info$value,
    feature_params = feature_params_info$value
  )
  cutoff <- ledgr_history_utc(
    ledgr_snapshot_resolve_civil_boundary(exp$snapshot, ts_utc, edge = "close")
  )
  substrate <- ledgr_history_substrate_for_experiment(exp, meta, end = meta$end)
  calendar <- ledgr_availability_calendar(
    list(sessions = substrate$sessions), meta$start, meta$end
  )
  first <- match(as.numeric(cutoff), as.numeric(calendar$pulses_posix))
  if (length(cutoff) != 1L || is.na(first)) {
    rlang::abort(
      sprintf(
        "Pulse inspection cutoff %s is not a session close on the experiment's prepared venue axis.",
        if (length(cutoff) == 1L && !is.na(cutoff)) ledgr_normalize_ts_utc(cutoff) else "NA"
      ),
      class = c("ledgr_history_outside_axis", "ledgr_invalid_args")
    )
  }
  n_pulses <- length(calendar$pulses_posix)
  pulses_posix <- calendar$pulses_posix[seq.int(first, n_pulses)]
  opportunities <- calendar$execution_opportunities_posix
  opportunities <- if (first < n_pulses) {
    opportunities[seq.int(first, n_pulses - 1L)]
  } else {
    opportunities[0L]
  }
  unique_defs <- ledgr_precompute_unique_feature_defs(
    list(list(feature_defs = feature_result$features))
  )
  payload <- ledgr_history_precompute_payload(
    unique_defs,
    substrate,
    calculation_start = ledgr_history_calculation_start(substrate),
    calculation_end = cutoff
  )
  projection <- ledgr_projection_from_payload(
    payload = payload,
    universe = exp$universe,
    pulses_posix = substrate$axis,
    feature_engine_version = ledgr_feature_engine_version(TRUE),
    alias_index = NULL
  )
  # Released at its last read; the projection holds every value (audit F01).
  rm(payload)
  substrate <- ledgr_history_substrate_bind_features(substrate, projection)
  exp_payload <- ledgr_sweep_exp_payload(exp)
  exp_payload$strategy <- ledgr_pulse_inspection_capture
  prepared <- ledgr_sweep_candidate_execution(
    exp = exp_payload,
    run_id = "pulse_inspection",
    params = params_info$value,
    feature_params = feature_params_info$value,
    execution_seed = NA_integer_,
    bars_by_id = list(),
    bars_mat = NULL,
    static_bars_views = NULL,
    pulses_posix = pulses_posix,
    pulses_iso = ledgr_projection_pulse_names(pulses_posix),
    metric_kernel = NULL,
    candidate = list(
      feature_defs = feature_result$features,
      alias_map = feature_result$alias_map
    ),
    candidate_feature_row = NULL,
    runtime_projection = NULL,
    snapshot_hash = meta$snapshot_hash,
    strategy_hash = NA_character_,
    master_seed = NULL,
    candidate_id = "pulse_inspection",
    candidate_row = 1L,
    retain = ledgr_sweep_retention(),
    history_substrate = substrate,
    availability_config = ledgr_sweep_availability_config(exp),
    execution_opportunities_posix = opportunities,
    corporate_action_rows = ledgr_corporate_action_rows(
      get_connection(exp$snapshot),
      exp$snapshot$snapshot_id
    )
  )
  captured <- tryCatch(
    {
      ledgr_execute_fold(prepared$execution, prepared$output_handler)
      NULL
    },
    ledgr_internal_pulse_inspection_capture = function(cnd) cnd$ctx
  )
  if (!inherits(captured, "ledgr_pulse_context")) {
    completion <- prepared$output_handler$completion()
    rlang::abort(
      sprintf(
        "Pulse inspection stopped in observe-and-settle at %s (%s) before the context was built.",
        ledgr_normalize_ts_utc(cutoff),
        as.character(completion$stop_reason %||% "no stop reason")
      ),
      class = c("ledgr_pulse_inspection_stopped", "ledgr_invalid_args")
    )
  }
  captured
}

ledgr_pulse_inspection_capture <- function(ctx, params) {
  signalCondition(structure(
    class = c("ledgr_internal_pulse_inspection_capture", "condition"),
    list(message = "pulse inspection capture", call = NULL, ctx = ctx)
  ))
  rlang::abort(
    "Pulse inspection capture was not handled.",
    class = "ledgr_invalid_fold_execution"
  )
}
