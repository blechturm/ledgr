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
  window$ts_utc <- vapply(window$ts_utc, ledgr_iso_utc, character(1))
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
      window_i$ts_utc <- vapply(window_i$ts_utc, ledgr_iso_utc, character(1))
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

