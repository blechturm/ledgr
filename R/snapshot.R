new_ledgr_snapshot <- function(db_path, snapshot_id, metadata = list()) {
  if (!is.character(db_path) || length(db_path) != 1 || is.na(db_path) || !nzchar(db_path)) {
    rlang::abort("`db_path` must be a non-empty character scalar.", class = "ledgr_invalid_snapshot")
  }
  if (!is.character(snapshot_id) || length(snapshot_id) != 1 || is.na(snapshot_id) || !nzchar(snapshot_id)) {
    rlang::abort("`snapshot_id` must be a non-empty character scalar.", class = "ledgr_invalid_snapshot")
  }
  if (!is.list(metadata)) {
    rlang::abort("`metadata` must be a list.", class = "ledgr_invalid_snapshot")
  }

  state <- new.env(parent = emptyenv())
  state$con <- NULL
  state$drv <- NULL
  ledgr_snapshot_register_finalizer(state)

  structure(
    list(
      db_path = db_path,
      snapshot_id = snapshot_id,
      metadata = metadata,
      .state = state
    ),
    class = "ledgr_snapshot"
  )
}

ledgr_snapshot_register_finalizer <- function(state) {
  reg.finalizer(
    state,
    function(env) {
      con <- env$con
      drv <- env$drv
      if (isTRUE(env$borrowed)) {
        con <- NULL
      }
      if (!is.null(con) && DBI::dbIsValid(con)) {
        suppressWarnings(try(DBI::dbDisconnect(con, shutdown = TRUE), silent = TRUE))
      }
      if (!is.null(drv)) {
        suppressWarnings(try(duckdb::duckdb_shutdown(drv), silent = TRUE))
      }
      env$con <- NULL
      env$drv <- NULL
      invisible(TRUE)
    },
    onexit = TRUE
  )
  invisible(state)
}

snapshot_state <- function(snapshot) {
  state <- snapshot$.state
  if (is.null(state) || !is.environment(state)) {
    state <- new.env(parent = emptyenv())
    state$con <- NULL
    state$drv <- NULL
    ledgr_snapshot_register_finalizer(state)
    snapshot$.state <- state
  }
  state
}

ledgr_snapshot_connection <- function(snapshot) {
  if (!inherits(snapshot, "ledgr_snapshot")) {
    rlang::abort("`snapshot` must be a ledgr_snapshot object.", class = "ledgr_invalid_snapshot")
  }

  state <- snapshot_state(snapshot)
  con <- state$con
  if (!is.null(con) && DBI::dbIsValid(con)) {
    return(list(con = con, opened_new = FALSE))
  }
  held <- ledgr_held_store(snapshot$db_path)
  if (!is.null(held)) {
    state$con <- held
    state$drv <- NULL
    state$borrowed <- TRUE
    return(list(con = held, opened_new = FALSE))
  }

  opened <- ledgr_open_duckdb_with_retry(snapshot$db_path)
  state$con <- opened$con
  state$drv <- opened$drv
  state$borrowed <- FALSE
  attr(state$con, "ledgr_duckdb_drv") <- opened$drv

  list(con = state$con, opened_new = TRUE)
}

# Connections held for one public call, keyed by store file. A nested open of
# the same file within the call borrows the held connection instead of opening
# another, and only the holder closes it. DuckDB shares one database per file
# within a session, so a borrower also sees what a run's own write connection
# committed. In-memory stores are never shared.
.ledgr_held_stores <- new.env(parent = emptyenv())

ledgr_store_key <- function(db_path) {
  if (!is.character(db_path) || length(db_path) != 1L || is.na(db_path) ||
      !nzchar(db_path) || identical(db_path, ":memory:")) {
    return(NULL)
  }
  normalizePath(db_path, winslash = "/", mustWork = FALSE)
}

ledgr_held_store <- function(db_path) {
  key <- ledgr_store_key(db_path)
  if (is.null(key)) {
    return(NULL)
  }
  con <- .ledgr_held_stores[[key]]
  if (is.null(con) || !DBI::dbIsValid(con)) {
    return(NULL)
  }
  con
}

# Registers `con` as the held connection of `db_path` unless one is held
# already, and returns the closer that unregisters it.
ledgr_store_register <- function(db_path, con) {
  key <- ledgr_store_key(db_path)
  if (is.null(key) || !is.null(ledgr_held_store(db_path))) {
    return(function() invisible(FALSE))
  }
  assign(key, con, envir = .ledgr_held_stores)
  function() {
    if (exists(key, envir = .ledgr_held_stores, inherits = FALSE)) {
      rm(list = key, envir = .ledgr_held_stores)
    }
    invisible(TRUE)
  }
}

# Holds a store file's connection for one call, for code that has a path but no
# snapshot yet. The closer checkpoints and closes it.
ledgr_store_hold <- function(db_path) {
  if (is.null(ledgr_store_key(db_path)) || !is.null(ledgr_held_store(db_path)) ||
      !file.exists(db_path)) {
    return(function() invisible(FALSE))
  }
  con <- ledgr_db_init(db_path)
  unregister <- ledgr_store_register(db_path, con)
  function() {
    unregister()
    ledgr_checkpoint_duckdb(con)
    suppressWarnings(try(DBI::dbDisconnect(con, shutdown = TRUE), silent = TRUE))
    drv <- attr(con, "ledgr_duckdb_drv", exact = TRUE)
    if (!is.null(drv)) {
      suppressWarnings(try(duckdb::duckdb_shutdown(drv), silent = TRUE))
    }
    invisible(TRUE)
  }
}

# Holds a snapshot's connection for one call and registers it for its store
# file. The returned closer, registered with on.exit(), closes the connection
# only when this call opened it, so a public call never leaves one open and
# nested reads share one open.
ledgr_snapshot_hold <- function(snapshot) {
  if (!inherits(snapshot, "ledgr_snapshot")) {
    return(function() invisible(FALSE))
  }
  opened <- ledgr_snapshot_connection(snapshot)
  unregister <- ledgr_store_register(snapshot$db_path, opened$con)
  if (!isTRUE(opened$opened_new)) {
    return(unregister)
  }
  function() {
    unregister()
    ledgr_snapshot_close(snapshot)
  }
}

get_connection <- function(x) {
  if (inherits(x, "ledgr_snapshot")) {
    return(ledgr_snapshot_connection(x)$con)
  }
  if (inherits(x, "ledgr_backtest")) {
    return(ledgr_backtest_open(x)$con)
  }
  rlang::abort("`x` must be a ledgr_snapshot or ledgr_backtest object.", class = "ledgr_invalid_args")
}

#' Close snapshot database connection
#'
#' Closes any open DuckDB connection held by a `ledgr_snapshot`.
#'
#' @param snapshot A `ledgr_snapshot` object.
#' @return The input snapshot (invisibly).
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
#' ledgr_snapshot_close(snapshot)
#' @export
ledgr_snapshot_close <- function(snapshot) {
  if (!inherits(snapshot, "ledgr_snapshot")) {
    rlang::abort("`snapshot` must be a ledgr_snapshot object.", class = "ledgr_invalid_snapshot")
  }

  state <- snapshot_state(snapshot)
  con <- state$con
  drv <- state$drv

  # A borrowed connection belongs to the call that holds it.
  if (isTRUE(state$borrowed)) {
    con <- NULL
    state$borrowed <- FALSE
  }
  if (!is.null(con) && DBI::dbIsValid(con)) {
    suppressWarnings(try(DBI::dbDisconnect(con, shutdown = TRUE), silent = TRUE))
  }
  if (!is.null(drv)) {
    suppressWarnings(try(duckdb::duckdb_shutdown(drv), silent = TRUE))
  }

  state$con <- NULL
  state$drv <- NULL
  invisible(snapshot)
}

#' Close a snapshot connection
#'
#' @param con A `ledgr_snapshot` object.
#' @param ... Unused.
#' @return The input snapshot (invisibly).
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
#' close(snapshot)
#' @export
close.ledgr_snapshot <- function(con, ...) {
  ledgr_snapshot_close(con)
}

#' Print a snapshot
#'
#' @param x A `ledgr_snapshot` object.
#' @param ... Unused.
#' @return The input snapshot, invisibly.
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
#' if (interactive()) print(snapshot)
#' ledgr_snapshot_close(snapshot)
#' @export
print.ledgr_snapshot <- function(x, ...) {
  meta <- x$metadata
  if (!is.list(meta)) meta <- list()

  n_bars <- meta$n_bars
  n_instruments <- meta$n_instruments
  start_date <- meta$start_date
  end_date <- meta$end_date

  cat("ledgr_snapshot\n")
  cat("==============\n")
  cat("Bars:        ", if (is.null(n_bars)) NA else n_bars, "\n")
  cat("Instruments: ", if (is.null(n_instruments)) NA else n_instruments, "\n")
  cat("Date Range:  ", if (is.null(start_date)) NA else start_date, "to", if (is.null(end_date)) NA else end_date, "\n")
  if (!is.null(meta$fact_family_count)) {
    cat("Fact families:", meta$fact_family_count, "\n")
    cat("Quarantined: ", meta$quarantined_observation_count %||% 0L, "\n")
  }
  cat("Database:    ", x$db_path, "\n")
  cat("Snapshot ID: ", paste0(substr(x$snapshot_id, 1, 32), if (nchar(x$snapshot_id) > 32) "..." else ""), "\n")

  state <- snapshot_state(x)
  if (!is.null(state$con) && DBI::dbIsValid(state$con)) {
    cat("Connection:  Open\n")
  } else {
    cat("Connection:  Closed (opens on-demand)\n")
  }

  invisible(x)
}

#' Summarize a snapshot
#'
#' @param object A `ledgr_snapshot` object.
#' @param ... Unused.
#' @return The input snapshot, invisibly.
#' @examples
#' bars <- data.frame(
#'   ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:1,
#'   instrument_id = "AAA",
#'   open = c(100, 101),
#'   high = c(101, 102),
#'   low = c(99, 100),
#'   close = c(100, 101),
#'   volume = 1000
#' )
#' snapshot <- ledgr_snapshot_from_df(bars)
#' if (interactive()) summary(snapshot)
#' ledgr_snapshot_close(snapshot)
#' @export
summary.ledgr_snapshot <- function(object, ...) {
  opened <- ledgr_snapshot_connection(object)
  if (isTRUE(opened$opened_new)) {
    on.exit(ledgr_snapshot_close(object), add = TRUE)
  }
  con <- opened$con

  stats <- DBI::dbGetQuery(
    con,
    "
    SELECT
      instrument_id,
      COUNT(*) AS n_bars,
      MIN(ts_utc) AS start_date,
      MAX(ts_utc) AS end_date
    FROM snapshot_bars
    WHERE snapshot_id = ?
    GROUP BY instrument_id
    ",
    params = list(object$snapshot_id)
  )

  print(object)
  cat("\nPer-Instrument Summary:\n")
  print(stats)
  invisible(object)
}
