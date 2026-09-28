#' Freeze a pulse snapshot for interactive strategy development
#'
#' @param snapshot A `ledgr_snapshot` object.
#' @param universe Character vector of instruments.
#' @param ts_utc Timestamp to freeze at.
#' @param features List of `ledgr_indicator` objects to compute.
#' @param feature_params JSON-safe list used to resolve parameterized feature
#'   declarations when `features` is a feature map.
#' @param cash Cash held alongside `positions`. It is not total account value;
#'   pulse equity is `cash + sum(positions * current close)`.
#' @param positions Named numeric vector of positions (NULL = flat).
#' @param state_prev Optional JSON-safe previous strategy state. This supports
#'   dense one-pulse strategy checks; availability-aware state normalization is
#'   not simulated.
#'
#' @return A `ledgr_pulse_context` object.
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
                                 state_prev = NULL) {
  if (!inherits(snapshot, "ledgr_snapshot")) {
    rlang::abort("`snapshot` must be a ledgr_snapshot object.", class = "ledgr_invalid_args")
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

  opened <- ledgr_open_dedicated_snapshot(snapshot)
  con <- opened$con

  e <- new.env(parent = emptyenv())
  e$ts_utc <- ts_norm
  e$universe <- universe
  e$positions <- positions
  e$cash <- as.numeric(cash)
  e$state_prev <- state_prev
  e$feature_params <- feature_params
  e$active_alias_map <- alias_map_info$alias_map
  e$alias_map_json <- alias_map_info$alias_map_json
  e$alias_map_hash <- alias_map_info$alias_map_hash
  e$alias_map_version <- alias_map_info$alias_map_version
  e$.snapshot <- opened$snapshot
  e$.con <- con

  reg.finalizer(
    e,
    function(env) {
      if (!is.null(env$.snapshot)) {
        ledgr_snapshot_close(env$.snapshot)
      }
      env$.con <- NULL
      env$.snapshot <- NULL
      invisible(TRUE)
    },
    onexit = TRUE
  )

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
  rows <- lapply(universe, function(inst) {
    df <- DBI::dbGetQuery(
      con,
      "
      SELECT instrument_id, ts_utc, open, high, low, close, volume
      FROM snapshot_bars
      WHERE snapshot_id = ? AND instrument_id = ? AND ts_utc = ?
      ",
      params = list(snapshot_id, inst, ts_utc)
    )
    if (nrow(df) == 0) {
      rlang::abort(
        sprintf("No bars available for instrument '%s' at ts_utc.", inst),
        class = "ledgr_invalid_args"
      )
    }
    df$ts_utc <- vapply(df$ts_utc, ledgr_iso_utc, character(1))
    df
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
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
      values <- ledgr_compute_feature_series(bars, feature)
      feature_value[[row_idx]] <- values[[length(values)]]
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
