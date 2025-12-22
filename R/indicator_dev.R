#' Interactive indicator development session
#'
#' @param snapshot A `ledgr_snapshot` object.
#' @param instrument_id Instrument to analyze.
#' @param ts_utc Window end timestamp.
#' @param lookback Number of bars to include.
#'
#' @return A `ledgr_indicator_dev` object.
ledgr_indicator_dev <- function(snapshot, instrument_id, ts_utc, lookback = 50L) {
  if (!inherits(snapshot, "ledgr_snapshot")) {
    rlang::abort("`snapshot` must be a ledgr_snapshot object.", class = "ledgr_invalid_args")
  }
  if (!is.character(instrument_id) || length(instrument_id) != 1 || is.na(instrument_id) || !nzchar(instrument_id)) {
    rlang::abort("`instrument_id` must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }
  if (!is.numeric(lookback) || length(lookback) != 1 || is.na(lookback) || lookback < 1 || lookback %% 1 != 0) {
    rlang::abort("`lookback` must be an integer >= 1.", class = "ledgr_invalid_args")
  }
  ts_norm <- ledgr_normalize_ts_utc(ts_utc)

  opened <- ledgr_open_dedicated_snapshot(snapshot)
  con <- opened$con

  window <- DBI::dbGetQuery(
    con,
    "
    SELECT instrument_id, ts_utc, open, high, low, close, volume
    FROM snapshot_bars
    WHERE snapshot_id = ? AND instrument_id = ? AND ts_utc <= ?
    ORDER BY ts_utc DESC
    LIMIT ?
    ",
    params = list(snapshot$snapshot_id, instrument_id, ts_norm, as.integer(lookback))
  )

  if (nrow(window) == 0) {
    ledgr_snapshot_close(opened$snapshot)
    rlang::abort("No bars available for the requested window.", class = "ledgr_invalid_args")
  }

  window <- window[rev(seq_len(nrow(window))), , drop = FALSE]
  window$ts_utc <- vapply(window$ts_utc, iso_utc, character(1))

  e <- new.env(parent = emptyenv())
  e$window <- window
  e$instrument_id <- instrument_id
  e$ts_utc <- ts_norm
  e$lookback <- as.integer(lookback)
  e$.snapshot <- opened$snapshot
  e$.con <- con

  e$test <- function(fn) {
    if (!is.function(fn)) {
      rlang::abort("`fn` must be a function.", class = "ledgr_invalid_args")
    }
    result <- fn(e$window)
    cat("Result:", result, "\n")
    invisible(result)
  }

  e$plot <- function() {
    plot(
      as.Date(e$window$ts_utc),
      e$window$close,
      type = "l",
      xlab = "Date",
      ylab = "Close Price",
      main = sprintf("%s - Window ending %s", e$instrument_id, e$ts_utc)
    )
    invisible(NULL)
  }

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

  structure(e, class = "ledgr_indicator_dev")
}

#' Close indicator development session
#'
#' @param x A `ledgr_indicator_dev` object.
#' @return The input object, invisibly.
close.ledgr_indicator_dev <- function(x, ...) {
  if (is.environment(x) && !is.null(x$.snapshot)) {
    ledgr_snapshot_close(x$.snapshot)
    x$.con <- NULL
    x$.snapshot <- NULL
  }
  invisible(x)
}

#' Freeze a pulse snapshot for interactive strategy development
#'
#' @param snapshot A `ledgr_snapshot` object.
#' @param universe Character vector of instruments.
#' @param ts_utc Timestamp to freeze at.
#' @param features List of `ledgr_indicator` objects to compute.
#' @param initial_cash Mock cash balance.
#' @param positions Named numeric vector of positions (NULL = flat).
#'
#' @return A `ledgr_pulse_context` object.
ledgr_pulse_snapshot <- function(snapshot,
                                 universe,
                                 ts_utc,
                                 features = list(),
                                 initial_cash = 100000,
                                 positions = NULL) {
  if (!inherits(snapshot, "ledgr_snapshot")) {
    rlang::abort("`snapshot` must be a ledgr_snapshot object.", class = "ledgr_invalid_args")
  }
  if (!is.character(universe) || length(universe) < 1 || anyNA(universe) || any(!nzchar(universe))) {
    rlang::abort("`universe` must be a non-empty character vector.", class = "ledgr_invalid_args")
  }
  if (anyDuplicated(universe)) {
    rlang::abort("`universe` must not contain duplicate instrument_ids.", class = "ledgr_invalid_args")
  }
  if (!is.list(features)) {
    rlang::abort("`features` must be a list.", class = "ledgr_invalid_args")
  }
  for (ind in features) {
    if (!inherits(ind, "ledgr_indicator")) {
      rlang::abort("`features` must contain ledgr_indicator objects.", class = "ledgr_invalid_args")
    }
  }
  if (!is.numeric(initial_cash) || length(initial_cash) != 1 || is.na(initial_cash) || !is.finite(initial_cash)) {
    rlang::abort("`initial_cash` must be a finite numeric scalar.", class = "ledgr_invalid_args")
  }
  ts_norm <- ledgr_normalize_ts_utc(ts_utc)

  if (is.null(positions)) {
    positions <- stats::setNames(rep(0, length(universe)), universe)
  } else {
    if (!is.numeric(positions) || is.null(names(positions)) || any(!nzchar(names(positions)))) {
      rlang::abort("`positions` must be a named numeric vector.", class = "ledgr_invalid_args")
    }
    if (anyDuplicated(names(positions))) {
      rlang::abort("`positions` must have unique instrument_id names.", class = "ledgr_invalid_args")
    }
  }

  opened <- ledgr_open_dedicated_snapshot(snapshot)
  con <- opened$con

  bars <- ledgr_fetch_latest_bars(con, snapshot$snapshot_id, universe, ts_norm)
  features_df <- ledgr_compute_pulse_features(con, snapshot$snapshot_id, universe, ts_norm, features)

  e <- new.env(parent = emptyenv())
  e$ts_utc <- ts_norm
  e$universe <- universe
  e$bars <- bars
  e$features <- features_df
  e$positions <- positions
  e$cash <- as.numeric(initial_cash)
  e$equity <- as.numeric(initial_cash)
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

  structure(e, class = "ledgr_pulse_context")
}

#' Close pulse context
#'
#' @param x A `ledgr_pulse_context` object.
#' @return The input object, invisibly.
close.ledgr_pulse_context <- function(x, ...) {
  if (is.environment(x) && !is.null(x$.snapshot)) {
    ledgr_snapshot_close(x$.snapshot)
    x$.con <- NULL
    x$.snapshot <- NULL
  }
  invisible(x)
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
      WHERE snapshot_id = ? AND instrument_id = ? AND ts_utc <= ?
      ORDER BY ts_utc DESC
      LIMIT 1
      ",
      params = list(snapshot_id, inst, ts_utc)
    )
    if (nrow(df) == 0) {
      rlang::abort(
        sprintf("No bars available for instrument '%s' at or before ts_utc.", inst),
        class = "ledgr_invalid_args"
      )
    }
    df$ts_utc <- vapply(df$ts_utc, iso_utc, character(1))
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

  max_lookback <- max(vapply(features, function(ind) ind$requires_bars, numeric(1)))
  feature_rows <- list()
  row_idx <- 1L

  for (inst in universe) {
    window <- DBI::dbGetQuery(
      con,
      "
      SELECT instrument_id, ts_utc, open, high, low, close, volume
      FROM snapshot_bars
      WHERE snapshot_id = ? AND instrument_id = ? AND ts_utc <= ?
      ORDER BY ts_utc DESC
      LIMIT ?
      ",
      params = list(snapshot_id, inst, ts_utc, as.integer(max_lookback))
    )
    if (nrow(window) == 0) next

    window <- window[rev(seq_len(nrow(window))), , drop = FALSE]
    window$ts_utc <- vapply(window$ts_utc, iso_utc, character(1))

    for (ind in features) {
      if (nrow(window) < ind$requires_bars) {
        value <- NA_real_
        feature_rows[[row_idx]] <- data.frame(
          ts_utc = ts_utc,
          instrument_id = inst,
          feature_name = ind$id,
          feature_value = value,
          stringsAsFactors = FALSE
        )
        row_idx <- row_idx + 1L
        next
      }

      window_sub <- window[(nrow(window) - ind$requires_bars + 1):nrow(window), , drop = FALSE]
      result <- ind$fn(window_sub)

      if (is.list(result) && length(result) > 1) {
        res_names <- names(result)
        if (is.null(res_names) || any(!nzchar(res_names))) {
          res_names <- as.character(seq_along(result))
        }
        for (i in seq_along(result)) {
          feature_rows[[row_idx]] <- data.frame(
            ts_utc = ts_utc,
            instrument_id = inst,
            feature_name = paste(ind$id, res_names[[i]], sep = "_"),
            feature_value = result[[i]],
            stringsAsFactors = FALSE
          )
          row_idx <- row_idx + 1L
        }
      } else {
        feature_rows[[row_idx]] <- data.frame(
          ts_utc = ts_utc,
          instrument_id = inst,
          feature_name = ind$id,
          feature_value = result,
          stringsAsFactors = FALSE
        )
        row_idx <- row_idx + 1L
      }
    }
  }

  out <- do.call(rbind, feature_rows)
  rownames(out) <- NULL
  out
}
