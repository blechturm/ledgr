#' Interactive indicator development session
#'
#' @param snapshot A `ledgr_snapshot` object.
#' @param instrument_id Instrument to analyze.
#' @param ts_utc Window end timestamp.
#' @param lookback Number of bars to include.
#'
#' @return A `ledgr_indicator_dev` object.
#' @examples
#' bars <- data.frame(
#'   ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:4,
#'   instrument_id = "AAA",
#'   open = 100:104,
#'   high = 101:105,
#'   low = 99:103,
#'   close = 100:104,
#'   volume = 1000
#' )
#' snapshot <- ledgr_snapshot_from_df(bars)
#' dev <- ledgr_indicator_dev(snapshot, "AAA", "2020-01-05T00:00:00Z", lookback = 3)
#' dev$test(function(window) mean(window$close))
#' close(dev)
#' ledgr_snapshot_close(snapshot)
#' @export
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

  e <- new.env(parent = emptyenv())
  e$instrument_id <- instrument_id
  e$ts_utc <- ts_norm
  e$lookback <- as.integer(lookback)
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

  window <- tryCatch(
    {
      DBI::dbGetQuery(
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
    },
    error = function(err) {
      ledgr_snapshot_close(opened$snapshot)
      stop(err)
    }
  )

  if (nrow(window) == 0) {
    ledgr_snapshot_close(opened$snapshot)
    rlang::abort("No bars available for the requested window.", class = "ledgr_invalid_args")
  }

  window <- window[rev(seq_len(nrow(window))), , drop = FALSE]
  window$ts_utc <- vapply(window$ts_utc, iso_utc, character(1))
  e$window <- window

  e$test <- function(fn) {
    if (!is.function(fn)) {
      rlang::abort("`fn` must be a function.", class = "ledgr_invalid_args")
    }
    result <- fn(e$window)
    cat("Result:", result, "\n")
    invisible(result)
  }

  e$test_dates <- function(fn, dates) {
    if (!is.function(fn)) {
      rlang::abort("`fn` must be a function.", class = "ledgr_invalid_args")
    }
    if (length(dates) < 1) {
      rlang::abort("`dates` must contain at least one timestamp.", class = "ledgr_invalid_args")
    }
    dates_norm <- vapply(dates, ledgr_normalize_ts_utc, character(1))
    values <- lapply(dates_norm, function(date_norm) {
      window_i <- DBI::dbGetQuery(
        e$.con,
        "
        SELECT instrument_id, ts_utc, open, high, low, close, volume
        FROM snapshot_bars
        WHERE snapshot_id = ? AND instrument_id = ? AND ts_utc <= ?
        ORDER BY ts_utc DESC
        LIMIT ?
        ",
        params = list(e$.snapshot$snapshot_id, e$instrument_id, date_norm, e$lookback)
      )
      if (nrow(window_i) == 0) return(NA_real_)
      window_i <- window_i[rev(seq_len(nrow(window_i))), , drop = FALSE]
      window_i$ts_utc <- vapply(window_i$ts_utc, iso_utc, character(1))
      fn(window_i)
    })
    tibble::tibble(ts_utc = dates_norm, value = ledgr_simplify_indicator_values(values))
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

  structure(e, class = "ledgr_indicator_dev")
}

#' Print an indicator development session
#'
#' @param x A `ledgr_indicator_dev` object.
#' @param ... Unused.
#' @return The input object, invisibly.
#' @examples
#' bars <- data.frame(
#'   ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:2,
#'   instrument_id = "AAA",
#'   open = 100:102,
#'   high = 101:103,
#'   low = 99:101,
#'   close = 100:102,
#'   volume = 1000
#' )
#' snapshot <- ledgr_snapshot_from_df(bars)
#' dev <- ledgr_indicator_dev(snapshot, "AAA", "2020-01-03T00:00:00Z", lookback = 2)
#' print(dev)
#' close(dev)
#' ledgr_snapshot_close(snapshot)
#' @export
print.ledgr_indicator_dev <- function(x, ...) {
  cat("ledgr Indicator Development Session\n")
  cat("Instrument: ", x$instrument_id, "\n", sep = "")
  cat("Window End: ", x$ts_utc, "\n", sep = "")
  cat("Lookback:   ", x$lookback, "\n", sep = "")
  cat("Rows:       ", nrow(x$window), "\n", sep = "")
  invisible(x)
}

#' Close indicator development session
#'
#' @param con A `ledgr_indicator_dev` object.
#' @param ... Unused.
#' @return The input object, invisibly.
#' @examples
#' bars <- data.frame(
#'   ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:2,
#'   instrument_id = "AAA",
#'   open = 100:102,
#'   high = 101:103,
#'   low = 99:101,
#'   close = 100:102,
#'   volume = 1000
#' )
#' snapshot <- ledgr_snapshot_from_df(bars)
#' dev <- ledgr_indicator_dev(snapshot, "AAA", "2020-01-03T00:00:00Z", lookback = 2)
#' close(dev)
#' ledgr_snapshot_close(snapshot)
#' @export
close.ledgr_indicator_dev <- function(con, ...) {
  if (is.environment(con) && !is.null(con$.snapshot)) {
    ledgr_snapshot_close(con$.snapshot)
    con$.con <- NULL
    con$.snapshot <- NULL
  }
  invisible(con)
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
#'   features = list(ledgr_ind_sma(2))
#' )
#' pulse$close("AAA")
#' pulse$feature("AAA", "sma_2")
#' close(pulse)
#' ledgr_snapshot_close(snapshot)
#' @export
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

  e <- new.env(parent = emptyenv())
  e$ts_utc <- ts_norm
  e$universe <- universe
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
  ledgr_update_pulse_context_helpers(
    e,
    bars = bars,
    features = features_df,
    positions = e$positions,
    universe = e$universe
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
