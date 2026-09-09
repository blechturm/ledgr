.ledgr_backtest_lifecycle_registry <- new.env(parent = emptyenv())

new_ledgr_backtest <- function(run_id, db_path, config) {
  if (!is.character(run_id) || length(run_id) != 1 || is.na(run_id) || !nzchar(run_id)) {
    rlang::abort("`run_id` must be a non-empty character scalar.", class = "ledgr_invalid_backtest")
  }
  if (!is.character(db_path) || length(db_path) != 1 || is.na(db_path) || !nzchar(db_path)) {
    rlang::abort("`db_path` must be a non-empty character scalar.", class = "ledgr_invalid_backtest")
  }
  if (!is.list(config)) {
    rlang::abort("`config` must be a list.", class = "ledgr_invalid_backtest")
  }

  state <- new.env(parent = emptyenv())
  state$con <- NULL
  state$drv <- NULL
  state$run_id <- run_id
  state$db_path <- db_path
  state$closed <- FALSE
  state$auto_checkpointed <- FALSE
  ledgr_backtest_register_finalizer(state)

  structure(
    list(
      run_id = run_id,
      db_path = db_path,
      config = config,
      .state = state
    ),
    class = c("ledgr_backtest", "ledgr_run")
  )
}

ledgr_backtest_register_finalizer <- function(state) {
  # Keep this off R-session shutdown. DuckDB driver cleanup during shutdown can
  # be order-sensitive; this finalizer is a GC safety net, while close(bt) is
  # the deterministic checkpoint path.
  reg.finalizer(
    state,
    function(env) {
      ledgr_backtest_auto_checkpoint_state(env)
      invisible(TRUE)
    },
    onexit = FALSE
  )
  invisible(state)
}

ledgr_backtest_auto_checkpoint_state <- function(state, emit_message = TRUE) {
  if (!is.environment(state)) {
    return(invisible(FALSE))
  }
  if (isTRUE(state$closed) || isTRUE(state$auto_checkpointed)) {
    return(invisible(FALSE))
  }
  state$auto_checkpointed <- TRUE
  if (!ledgr_backtest_state_is_durable(state)) {
    suppressWarnings(try(ledgr_backtest_disconnect_state(state), silent = TRUE))
    return(invisible(FALSE))
  }
  ok <- isTRUE(suppressWarnings(try(ledgr_backtest_checkpoint_state(state), silent = TRUE)))
  suppressWarnings(try(ledgr_backtest_disconnect_state(state), silent = TRUE))
  if (ok) {
    if (isTRUE(emit_message) && ledgr_backtest_should_emit_auto_checkpoint_message()) {
      message(
        sprintf(
          "ledgr auto-checkpointed durable run '%s'. Prefer close(bt) for deterministic cleanup.",
          state$run_id
        )
      )
    }
    return(invisible(TRUE))
  }
  invisible(FALSE)
}

ledgr_backtest_should_emit_auto_checkpoint_message <- function() {
  flag <- "auto_checkpoint_message_emitted"
  if (exists(flag, envir = .ledgr_backtest_lifecycle_registry, inherits = FALSE) &&
    isTRUE(get(flag, envir = .ledgr_backtest_lifecycle_registry, inherits = FALSE))) {
    return(FALSE)
  }
  assign(flag, TRUE, envir = .ledgr_backtest_lifecycle_registry)
  TRUE
}

ledgr_backtest_state_is_durable <- function(state) {
  is.environment(state) &&
    is.character(state$db_path) &&
    length(state$db_path) == 1L &&
    !is.na(state$db_path) &&
    nzchar(state$db_path) &&
    !identical(state$db_path, ":memory:") &&
    file.exists(state$db_path)
}

ledgr_backtest_checkpoint_state <- function(state, strict = FALSE) {
  if (!is.environment(state)) {
    return(invisible(FALSE))
  }
  if (!is.null(state$con) && DBI::dbIsValid(state$con)) {
    return(ledgr_checkpoint_duckdb(state$con, strict = strict))
  }
  if (!ledgr_backtest_state_is_durable(state)) {
    return(invisible(FALSE))
  }
  opened <- ledgr_open_duckdb_with_retry(state$db_path)
  on.exit({
    suppressWarnings(try(DBI::dbDisconnect(opened$con, shutdown = TRUE), silent = TRUE))
    suppressWarnings(try(duckdb::duckdb_shutdown(opened$drv), silent = TRUE))
  }, add = TRUE)
  ledgr_checkpoint_duckdb(opened$con, strict = strict)
}

ledgr_backtest_disconnect_state <- function(state) {
  if (!is.environment(state)) {
    return(invisible(FALSE))
  }
  if (!is.null(state$con) && DBI::dbIsValid(state$con)) {
    suppressWarnings(try(DBI::dbDisconnect(state$con, shutdown = TRUE), silent = TRUE))
  }
  if (!is.null(state$drv)) {
    suppressWarnings(try(duckdb::duckdb_shutdown(state$drv), silent = TRUE))
  }
  state$con <- NULL
  state$drv <- NULL
  invisible(TRUE)
}

backtest_state <- function(bt) {
  state <- bt$.state
  if (is.null(state) || !is.environment(state)) {
    state <- new.env(parent = emptyenv())
    state$con <- NULL
    state$drv <- NULL
    state$run_id <- bt$run_id
    state$db_path <- bt$db_path
    state$closed <- FALSE
    state$auto_checkpointed <- FALSE
    ledgr_backtest_register_finalizer(state)
    bt$.state <- state
  }
  state
}

ledgr_backtest_open <- function(bt) {
  if (!inherits(bt, "ledgr_backtest")) {
    rlang::abort("`bt` must be a ledgr_backtest object.", class = "ledgr_invalid_backtest")
  }

  state <- backtest_state(bt)
  con <- state$con
  if (!is.null(con) && DBI::dbIsValid(con)) {
    return(list(con = con, opened_new = FALSE))
  }

  opened <- ledgr_open_duckdb_with_retry(bt$db_path)
  state$con <- opened$con
  state$drv <- opened$drv
  attr(state$con, "ledgr_duckdb_drv") <- opened$drv

  list(con = state$con, opened_new = TRUE)
}

ledgr_backtest_read_connection <- function(bt) {
  if (!inherits(bt, "ledgr_backtest")) {
    rlang::abort("`bt` must be a ledgr_backtest object.", class = "ledgr_invalid_backtest")
  }

  state <- backtest_state(bt)
  if (!is.null(state$con) && DBI::dbIsValid(state$con)) {
    return(list(
      con = state$con,
      temporary = FALSE,
      close = function() invisible(FALSE)
    ))
  }

  if (identical(bt$db_path, ":memory:")) {
    opened <- ledgr_backtest_open(bt)
    return(list(
      con = opened$con,
      temporary = FALSE,
      close = function() invisible(FALSE)
    ))
  }

  opened <- ledgr_open_duckdb_with_retry(bt$db_path)
  list(
    con = opened$con,
    temporary = TRUE,
    close = function() {
      suppressWarnings(try(DBI::dbDisconnect(opened$con, shutdown = TRUE), silent = TRUE))
      suppressWarnings(try(duckdb::duckdb_shutdown(opened$drv), silent = TRUE))
      invisible(TRUE)
    }
  )
}

#' Close a backtest result connection
#'
#' Releases any open DuckDB connection held by a `ledgr_backtest` object and
#' checkpoints a durable run file when possible. Completed run artifacts are
#' already durable when `ledgr_run()` returns; `close(bt)` is resource
#' management for explicit opens, tests, and long sessions.
#' The underlying DuckDB file is not deleted.
#'
#' @param con A `ledgr_backtest` object.
#' @param ... Unused.
#' @return The input object, invisibly.
#' @examples
#' bars <- data.frame(
#'   ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:2,
#'   instrument_id = "AAA",
#'   open = c(100, 101, 102),
#'   high = c(101, 102, 103),
#'   low = c(99, 100, 101),
#'   close = c(100, 101, 102),
#'   volume = 1000
#' )
#' strategy <- function(ctx, params) {
#'   targets <- ctx$flat()
#'   targets["AAA"] <- 1
#'   targets
#' }
#' bt <- ledgr_backtest(data = bars, strategy = strategy, initial_cash = 1000, cost_model = ledgr_cost_zero())
#' close(bt)
#' @export
close.ledgr_backtest <- function(con, ...) {
  if (!inherits(con, "ledgr_backtest")) {
    rlang::abort("`con` must be a ledgr_backtest object.", class = "ledgr_invalid_backtest")
  }

  state <- backtest_state(con)
  if (isTRUE(state$closed)) {
    return(invisible(con))
  }
  on.exit({
    ledgr_backtest_disconnect_state(state)
    state$closed <- TRUE
  }, add = TRUE)
  ledgr_backtest_checkpoint_state(state, strict = TRUE)
  invisible(con)
}
