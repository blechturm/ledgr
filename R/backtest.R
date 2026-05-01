#' Run a backtest (v0.1.2)
#'
#' Thin wrapper around the canonical engine path.
#'
#' @param snapshot A `ledgr_snapshot` object, or a data frame for the data-first
#'   convenience path.
#' @param strategy Strategy function or object with `$on_pulse(ctx)` method.
#'   Functional strategies must use `function(ctx, params)`.
#' @param strategy_params JSON-safe list passed to `function(ctx, params)`
#'   strategies and stored as part of run provenance.
#' @param universe Character vector of instrument IDs. If `NULL`, it is inferred
#'   from the snapshot or data frame.
#' @param start Start timestamp (NULL = snapshot start).
#' @param end End timestamp (NULL = snapshot end).
#' @param initial_cash Starting capital. Must be a finite numeric scalar > 0.
#' @param features List of ledgr indicator definitions (optional).
#' @param fill_model Fill model config. `NULL` uses ledgr's default next-open
#'   model with zero spread and zero fixed commission.
#' @param execution_mode Execution mode ("db_live" or "audit_log").
#' @param checkpoint_every Flush interval for audit_log mode.
#' @param db_path Database path for the run ledger (NULL = snapshot DB).
#' @param persist_features If FALSE, skip persisting per-pulse features to DuckDB.
#' @param control Optional list of engine overrides (e.g., execution_mode).
#' @param run_id Optional run identifier to resume or reuse.
#' @param data Optional data frame/tibble or `ledgr_snapshot`. Exactly one of
#'   `snapshot` and `data` may be supplied.
#' @return A `ledgr_backtest` object.
#' @details
#' v0.1.7 introduces the experiment-first public workflow:
#' `ledgr_experiment()` plus `ledgr_run()`. `ledgr_backtest()` remains available
#' as a compatibility wrapper around the same canonical runner path.
#'
#' Strategies return target holdings. The default fill model is `next_open`: a
#' target decided at pulse `t` is filled at the next available bar. Targets on
#' the final pulse therefore cannot be filled unless another bar exists after
#' `end`.
#'
#' v0.1.x does not provide a supported broker-style short-selling contract.
#' Strategy authors should treat negative target quantities as outside the
#' supported public workflow until explicit shorting semantics are specified.
#' @examples
#' bars <- data.frame(
#'   ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:3,
#'   instrument_id = "AAA",
#'   open = c(100, 101, 102, 103),
#'   high = c(101, 102, 103, 104),
#'   low = c(99, 100, 101, 102),
#'   close = c(100, 101, 102, 103),
#'   volume = 1000
#' )
#' strategy <- function(ctx, params) {
#'   targets <- ctx$flat()
#'   targets["AAA"] <- if (ctx$close("AAA") > 100) 1 else 0
#'   targets
#' }
#' bt <- ledgr_backtest(data = bars, strategy = strategy, initial_cash = 1000)
#' print(bt)
#' close(bt)
#' @export
ledgr_backtest <- function(snapshot = NULL,
                           strategy,
                           universe = NULL,
                           start = NULL,
                           end = NULL,
                           initial_cash = 100000,
                           strategy_params = list(),
                           features = list(),
                           fill_model = NULL,
                           execution_mode = "audit_log",
                           checkpoint_every = 10000L,
                           persist_features = TRUE,
                           db_path = NULL,
                           control = list(),
                           run_id = NULL,
                           data = NULL) {
  ledgr_set_preflight_start(ledgr_time_now())
  if (!is.null(snapshot) && !is.null(data)) {
    rlang::abort(
      "Provide exactly one data source: `snapshot` or `data`, not both.",
      class = "ledgr_invalid_args"
    )
  }
  if (is.null(snapshot) && is.null(data)) {
    rlang::abort(
      "Provide a `snapshot` or data frame via `data`. Create snapshots with ledgr_snapshot_from_df().",
      class = "ledgr_invalid_args"
    )
  }

  source <- if (!is.null(data)) data else snapshot
  implicit_snapshot <- FALSE
  if (inherits(source, "ledgr_snapshot")) {
    snapshot <- source
  } else if (is.data.frame(source)) {
    if (is.null(db_path)) {
      db_path <- tempfile("ledgr_backtest_", fileext = ".duckdb")
    }
    if (is.null(universe)) {
      universe <- ledgr_infer_universe_from_data(source)
    }
    snapshot <- ledgr_snapshot_from_df(source, db_path = db_path)
    implicit_snapshot <- TRUE
    on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  } else {
    rlang::abort(
      "`snapshot`/`data` must be a ledgr_snapshot object or a data frame with OHLCV bars.",
      class = "ledgr_invalid_args"
    )
  }

  if (!inherits(snapshot, "ledgr_snapshot")) {
    rlang::abort(
      "'snapshot' must be a ledgr_snapshot object. Create with: ledgr_snapshot_from_df() or ledgr_snapshot_from_yahoo().",
      class = "ledgr_invalid_args"
    )
  }
  ledgr_snapshot_validate(snapshot)

  if (is.null(universe)) {
    universe <- ledgr_infer_universe_from_snapshot(snapshot)
  }
  if (!is.character(universe) || length(universe) < 1 || anyNA(universe) || any(!nzchar(universe))) {
    rlang::abort("'universe' must contain at least one instrument.", class = "ledgr_invalid_args")
  }
  if (anyDuplicated(universe)) {
    rlang::abort("'universe' must not contain duplicates.", class = "ledgr_invalid_args")
  }

  if (!is.logical(persist_features) || length(persist_features) != 1 || is.na(persist_features)) {
    rlang::abort("`persist_features` must be TRUE or FALSE.", class = "ledgr_invalid_args")
  }

  if (is.null(db_path)) db_path <- snapshot$db_path
  if (!is.character(db_path) || length(db_path) != 1 || is.na(db_path) || !nzchar(db_path)) {
    rlang::abort("`db_path` must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }
  if (!ledgr_same_db_path(db_path, snapshot$db_path) && identical(ledgr_db_path_key(snapshot$db_path), ":memory:")) {
    rlang::abort(
      "`db_path` cannot point to a separate run database when `snapshot` is backed by :memory:.",
      class = "ledgr_invalid_args"
    )
  }

  if (!is.character(execution_mode) || length(execution_mode) != 1 || is.na(execution_mode) || !nzchar(execution_mode)) {
    rlang::abort("`execution_mode` must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }
  if (!execution_mode %in% c("db_live", "audit_log")) {
    rlang::abort("`execution_mode` must be \"db_live\" or \"audit_log\".", class = "ledgr_invalid_args")
  }
  if (!is.numeric(checkpoint_every) || length(checkpoint_every) != 1 || is.na(checkpoint_every) ||
      !is.finite(checkpoint_every) || checkpoint_every < 1 || (checkpoint_every %% 1) != 0) {
    rlang::abort("`checkpoint_every` must be an integer >= 1.", class = "ledgr_invalid_args")
  }

  if (!is.null(run_id)) {
    if (!is.character(run_id) || length(run_id) != 1 || is.na(run_id) || !nzchar(run_id)) {
      rlang::abort("`run_id` must be NULL or a non-empty character scalar.", class = "ledgr_invalid_args")
    }
  }

  if (!is.list(features)) {
    rlang::abort("`features` must be a list.", class = "ledgr_invalid_args")
  }

  if (is.null(start)) start <- snapshot$metadata$start_date
  if (is.null(end)) end <- snapshot$metadata$end_date
  if (is.null(start) || is.null(end) || anyNA(c(start, end))) {
    rlang::abort("`start` and `end` must be provided or available in snapshot metadata.", class = "ledgr_invalid_args")
  }

  # Validate universe against snapshot instruments.
  con_snap <- get_connection(snapshot)
  inst <- DBI::dbGetQuery(
    con_snap,
    "SELECT instrument_id FROM snapshot_instruments WHERE snapshot_id = ?",
    params = list(snapshot$snapshot_id)
  )$instrument_id
  missing <- setdiff(universe, inst)
  if (length(missing) > 0) {
    rlang::abort(
      sprintf(
        "Instruments not found in snapshot: %s. Available instruments: %s",
        paste(missing, collapse = ", "),
        paste(inst, collapse = ", ")
      ),
      class = "ledgr_invalid_args"
    )
  }
  if (!implicit_snapshot && !ledgr_same_db_path(db_path, snapshot$db_path)) {
    ledgr_snapshot_close(snapshot)
  }

  config <- ledgr_config(
    snapshot = snapshot,
    universe = universe,
    strategy = strategy,
    strategy_params = strategy_params,
    backtest = ledgr_backtest_config(start = start, end = end, initial_cash = initial_cash),
    features = features,
    persist_features = persist_features,
    execution_mode = execution_mode,
    checkpoint_every = checkpoint_every,
    fill_model = fill_model,
    db_path = db_path,
    control = control,
    run_id = run_id
  )

  result <- ledgr_run_config(config)

  new_ledgr_backtest(
    run_id = result$run_id,
    db_path = result$db_path,
    config = config
  )
}

ledgr_infer_universe_from_data <- function(data) {
  if (!is.data.frame(data) || !("instrument_id" %in% names(data))) {
    rlang::abort(
      "`data` must include an `instrument_id` column so `universe` can be inferred.",
      class = "ledgr_invalid_args"
    )
  }
  universe <- sort(unique(as.character(data$instrument_id)))
  universe <- universe[!is.na(universe) & nzchar(universe)]
  if (length(universe) < 1) {
    rlang::abort("`data$instrument_id` must contain at least one non-empty instrument id.", class = "ledgr_invalid_args")
  }
  universe
}

ledgr_infer_universe_from_snapshot <- function(snapshot) {
  con <- get_connection(snapshot)
  universe <- DBI::dbGetQuery(
    con,
    "
    SELECT instrument_id
    FROM snapshot_instruments
    WHERE snapshot_id = ?
    ORDER BY instrument_id
    ",
    params = list(snapshot$snapshot_id)
  )$instrument_id
  universe <- as.character(universe)
  if (length(universe) < 1) {
    rlang::abort(
      "Cannot infer `universe`: snapshot contains no instruments.",
      class = "ledgr_invalid_args"
    )
  }
  universe
}

ledgr_run_config <- function(config, run_id = NULL) {
  ledgr_backtest_run(config = config, run_id = run_id)
}

#' Run a ledgr experiment
#'
#' `ledgr_run()` is the public single-run API for the v0.1.7
#' experiment-first workflow. It evaluates run-time feature definitions,
#' builds the canonical backtest config, and delegates to the shared runner.
#'
#' @param exp A `ledgr_experiment` object.
#' @param params JSON-safe list passed to `function(ctx, params)` strategy and
#'   `function(params)` feature definitions.
#' @param run_id Optional run identifier.
#' @param seed Reserved for future deterministic stochastic workflows. v0.1.7
#'   stores `seed = NULL` in run identity and rejects non-NULL seeds.
#' @return A `ledgr_backtest` object.
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
#' snapshot <- ledgr_snapshot_from_df(bars)
#' strategy <- function(ctx, params) {
#'   targets <- ctx$flat()
#'   targets["AAA"] <- params$qty
#'   targets
#' }
#' exp <- ledgr_experiment(snapshot, strategy)
#' bt <- ledgr_run(exp, params = list(qty = 1), run_id = "example-run")
#' close(bt)
#' ledgr_snapshot_close(snapshot)
#' @export
ledgr_run <- function(exp, params = list(), run_id = NULL, seed = NULL) {
  if (!inherits(exp, "ledgr_experiment")) {
    rlang::abort("`exp` must be a ledgr_experiment object.", class = "ledgr_invalid_args")
  }
  if (!is.list(params) || is.data.frame(params)) {
    rlang::abort("`params` must be a list. Use `params = list()` when the strategy has no parameters.", class = "ledgr_invalid_args")
  }
  ledgr_run_experiment(exp = exp, params = params, run_id = run_id, seed = seed)
}

ledgr_run_experiment <- function(exp, params = list(), run_id = NULL, seed = NULL) {
  if (!inherits(exp, "ledgr_experiment")) {
    rlang::abort("`exp` must be a ledgr_experiment object.", class = "ledgr_invalid_args")
  }
  params_info <- ledgr_strategy_params_info(params)
  if (!is.null(seed)) {
    rlang::abort(
      "`seed` is reserved for v0.1.8 stochastic workflows. v0.1.7 stores seed = NULL in run identity.",
      class = "ledgr_seed_not_supported"
    )
  }
  if (!is.null(run_id) && (!is.character(run_id) || length(run_id) != 1L || is.na(run_id) || !nzchar(run_id))) {
    rlang::abort("`run_id` must be NULL or a non-empty character scalar.", class = "ledgr_invalid_args")
  }
  features <- ledgr_experiment_materialize_features(exp, params_info$value)
  start <- if (!is.null(exp$opening$date)) exp$opening$date else exp$snapshot$metadata$start_date
  end <- exp$snapshot$metadata$end_date
  if (is.null(start) || is.null(end) || anyNA(c(start, end))) {
    rlang::abort("Experiment snapshot must provide start/end metadata, or opening$date must provide start.", class = "ledgr_invalid_experiment")
  }

  config <- ledgr_config(
    snapshot = exp$snapshot,
    universe = exp$universe,
    strategy = exp$strategy,
    strategy_params = params_info$value,
    backtest = ledgr_backtest_config(start = start, end = end, initial_cash = exp$opening$cash),
    features = features,
    persist_features = exp$persist_features,
    execution_mode = exp$execution_mode,
    fill_model = exp$fill_model,
    db_path = exp$snapshot$db_path,
    run_id = run_id,
    opening = exp$opening,
    seed = NULL
  )

  result <- ledgr_run_config(config)
  new_ledgr_backtest(
    run_id = result$run_id,
    db_path = result$db_path,
    config = config
  )
}

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
#' management for explicit opens, lazy result cursors, tests, and long sessions.
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
#' bt <- ledgr_backtest(data = bars, strategy = strategy, initial_cash = 1000)
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

# Internal helper for cleaning up lazy fill streaming results.
ledgr_fills_close <- function(res, con = NULL) {
  if (is.null(res)) return(invisible(TRUE))
  if (inherits(res, "ledgr_fills_cursor")) {
    state <- res$.state
    return(ledgr_fills_close(state$res, con = state$con))
  }
  if (!inherits(res, "DBIResult")) {
    rlang::abort("`res` must be a DBIResult from ledgr_extract_fills(lazy = TRUE).", class = "ledgr_invalid_args")
  }

  temp_table <- attr(res, "ledgr_temp_table", exact = TRUE)

  if (DBI::dbIsValid(res)) {
    DBI::dbClearResult(res)
  }
  if (!is.null(con) && !is.null(temp_table)) {
    DBI::dbExecute(con, sprintf("DROP TABLE IF EXISTS %s", temp_table))
  }
  invisible(TRUE)
}

new_ledgr_fills_cursor <- function(res, temp_table, con) {
  state <- new.env(parent = emptyenv())
  state$res <- res
  state$con <- con
  state$temp_table <- temp_table
  attr(res, "ledgr_temp_table") <- temp_table

  reg.finalizer(
    state,
    function(env) {
      if (!is.null(env$res) && DBI::dbIsValid(env$res)) {
        suppressWarnings(try(DBI::dbClearResult(env$res), silent = TRUE))
      }
      if (!is.null(env$con) && !is.null(env$temp_table)) {
        suppressWarnings(try(DBI::dbExecute(env$con, sprintf("DROP TABLE IF EXISTS %s", env$temp_table)), silent = TRUE))
      }
      invisible(TRUE)
    },
    onexit = TRUE
  )

  structure(list(res = res, .state = state), class = "ledgr_fills_cursor")
}

ledgr_backtest_config <- function(start, end, initial_cash = 100000) {
  start_iso <- iso_utc(start)
  end_iso <- iso_utc(end)

  start_ts <- as.POSIXct(start_iso, tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ")
  end_ts <- as.POSIXct(end_iso, tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ")
  if (is.na(start_ts) || is.na(end_ts)) {
    rlang::abort("`start` and `end` must be parseable timestamps.", class = "ledgr_invalid_args")
  }
  if (start_ts > end_ts) {
    rlang::abort("`start` must be before or equal to `end`.", class = "ledgr_invalid_args")
  }
  if (!is.numeric(initial_cash) || length(initial_cash) != 1 || is.na(initial_cash) || !is.finite(initial_cash)) {
    rlang::abort("`initial_cash` must be a finite numeric scalar.", class = "ledgr_invalid_args")
  }
  if (initial_cash <= 0) {
    rlang::abort("`initial_cash` must be > 0.", class = "ledgr_invalid_args")
  }

  list(start = start_iso, end = end_iso, initial_cash = as.numeric(initial_cash))
}

ledgr_fill_model_instant <- function() {
  list(type = "next_open", spread_bps = 0, commission_fixed = 0)
}

ledgr_strategy_spec <- function(strategy) {
  if (is.function(strategy)) {
    signature <- ledgr_strategy_signature(strategy)
    key <- ledgr_register_strategy_fn(strategy)
    source_info <- ledgr_strategy_source_info(strategy)
    return(list(
      id = "functional",
      params = list(strategy_key = key, call_signature = signature),
      provenance = list(
        strategy_type = "functional",
        strategy_source = source_info$source,
        strategy_source_hash = source_info$hash,
        strategy_source_capture_method = source_info$capture_method,
        reproducibility_level = ledgr_strategy_reproducibility_level("functional", signature, source_info)
      )
    ))
  }

  if (is.list(strategy) && is.character(strategy$id)) {
    params <- strategy$params
    if (is.null(params)) params <- list()
    if (!is.list(params)) {
      rlang::abort("strategy.params must be a list.", class = "ledgr_invalid_args")
    }
    return(list(
      id = strategy$id,
      params = params,
      provenance = list(
        strategy_type = "configured",
        strategy_source = NA_character_,
        strategy_source_hash = NA_character_,
        strategy_source_capture_method = "configured_strategy",
        reproducibility_level = "tier_2"
      )
    ))
  }

  if (!is.null(strategy) && is.function(strategy$on_pulse)) {
    fn <- function(ctx, params) strategy$on_pulse(ctx)
    r6_key_payload <- list(
      type = "R6_object",
      class = class(strategy),
      params = if (is.list(strategy$params)) strategy$params else list()
    )
    key <- ledgr_register_strategy_fn(
      fn,
      include_captures = FALSE,
      key = digest::digest(canonical_json(r6_key_payload), algo = "sha256")
    )
    return(list(
      id = "functional",
      params = list(strategy_key = key, call_signature = "ctx_params"),
      provenance = list(
        strategy_type = "R6_object",
        strategy_source = NA_character_,
        strategy_source_hash = NA_character_,
        strategy_source_capture_method = "R6_object",
        reproducibility_level = "tier_2"
      )
    ))
  }

  rlang::abort(
    "`strategy` must be a function or an object with $on_pulse(ctx).",
    class = "ledgr_invalid_args"
  )
}

ledgr_config <- function(snapshot,
                         universe,
                         strategy,
                         strategy_params = list(),
                         backtest,
                         features = list(),
                         persist_features = TRUE,
                         execution_mode = "audit_log",
                         checkpoint_every = 10000L,
                         fill_model = NULL,
                         db_path = NULL,
                         control = list(),
                         run_id = NULL,
                         opening = NULL,
                         seed = NULL) {
  if (!inherits(snapshot, "ledgr_snapshot")) {
    rlang::abort("`snapshot` must be a ledgr_snapshot object.", class = "ledgr_invalid_args")
  }
  if (!is.character(universe) || length(universe) < 1 || anyNA(universe) || any(!nzchar(universe))) {
    rlang::abort("`universe` must be a non-empty character vector.", class = "ledgr_invalid_args")
  }
  if (!is.list(backtest)) {
    rlang::abort("`backtest` must be a list from ledgr_backtest_config().", class = "ledgr_invalid_args")
  }
  if (is.null(db_path)) db_path <- snapshot$db_path
  if (!is.character(db_path) || length(db_path) != 1 || is.na(db_path) || !nzchar(db_path)) {
    rlang::abort("`db_path` must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }
  if (!ledgr_same_db_path(db_path, snapshot$db_path) && identical(ledgr_db_path_key(snapshot$db_path), ":memory:")) {
    rlang::abort(
      "`db_path` cannot point to a separate run database when `snapshot` is backed by :memory:.",
      class = "ledgr_invalid_args"
    )
  }
  if (!is.list(features)) {
    rlang::abort("`features` must be a list.", class = "ledgr_invalid_args")
  }
  if (!is.logical(persist_features) || length(persist_features) != 1 || is.na(persist_features)) {
    rlang::abort("`persist_features` must be TRUE or FALSE.", class = "ledgr_invalid_args")
  }
  if (!is.character(execution_mode) || length(execution_mode) != 1 || is.na(execution_mode) || !nzchar(execution_mode)) {
    rlang::abort("`execution_mode` must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }
  if (!execution_mode %in% c("db_live", "audit_log")) {
    rlang::abort("`execution_mode` must be \"db_live\" or \"audit_log\".", class = "ledgr_invalid_args")
  }
  if (!is.numeric(checkpoint_every) || length(checkpoint_every) != 1 || is.na(checkpoint_every) ||
      !is.finite(checkpoint_every) || checkpoint_every < 1 || (checkpoint_every %% 1) != 0) {
    rlang::abort("`checkpoint_every` must be an integer >= 1.", class = "ledgr_invalid_args")
  }
  if (!is.list(control)) {
    rlang::abort("`control` must be a list.", class = "ledgr_invalid_args")
  }
  if (!is.null(seed)) {
    if (!is.numeric(seed) || length(seed) != 1L || is.na(seed) || !is.finite(seed) || (seed %% 1) != 0) {
      rlang::abort("`seed` must be NULL or an integer-like scalar.", class = "ledgr_invalid_args")
    }
    seed <- as.integer(seed)
  }

  if (!is.null(control$execution_mode)) {
    execution_mode <- control$execution_mode
    if (!is.character(execution_mode) || length(execution_mode) != 1 || is.na(execution_mode) || !nzchar(execution_mode)) {
      rlang::abort("control$execution_mode must be a non-empty character scalar.", class = "ledgr_invalid_args")
    }
    if (!execution_mode %in% c("db_live", "audit_log")) {
      rlang::abort("control$execution_mode must be \"db_live\" or \"audit_log\".", class = "ledgr_invalid_args")
    }
  }
  if (!is.null(control$checkpoint_every)) {
    checkpoint_every <- control$checkpoint_every
    if (!is.numeric(checkpoint_every) || length(checkpoint_every) != 1 || is.na(checkpoint_every) ||
        !is.finite(checkpoint_every) || checkpoint_every < 1 || (checkpoint_every %% 1) != 0) {
      rlang::abort("control$checkpoint_every must be an integer >= 1.", class = "ledgr_invalid_args")
    }
  }

  if (is.null(fill_model)) fill_model <- ledgr_fill_model_instant()
  if (!is.list(fill_model)) {
    rlang::abort("`fill_model` must be a list.", class = "ledgr_invalid_args")
  }

  strategy_params_info <- ledgr_strategy_params_info(strategy_params)
  strat <- ledgr_strategy_spec(strategy)
  opening <- ledgr_config_normalize_opening(opening, backtest$initial_cash)

  config <- list(
    db_path = db_path,
    engine = list(
      seed = seed,
      tz = "UTC",
      execution_mode = execution_mode,
      checkpoint_every = as.integer(checkpoint_every),
      control = control
    ),
    universe = list(instrument_ids = universe),
    backtest = list(
      start_ts_utc = backtest$start,
      end_ts_utc = backtest$end,
      pulse = "EOD",
      initial_cash = backtest$initial_cash
    ),
    fill_model = list(
      type = fill_model$type,
      spread_bps = fill_model$spread_bps,
      commission_fixed = fill_model$commission_fixed
    ),
    features = if (length(features) > 0) {
      defs <- lapply(features, function(feat) {
        if (inherits(feat, "ledgr_indicator")) {
          ledgr_register_indicator(feat)
          return(list(
            id = feat$id,
            params = feat$params,
            requires_bars = feat$requires_bars,
            stable_after = feat$stable_after,
            fingerprint = ledgr_indicator_fingerprint(feat)
          ))
        }
        feat
      })
      list(enabled = TRUE, defs = defs, persist = isTRUE(persist_features))
    } else {
      list(enabled = FALSE, defs = list(), persist = isTRUE(persist_features))
    },
    strategy = list(
      id = strat$id,
      params = strat$params,
      provenance = strat$provenance
    ),
    strategy_params = strategy_params_info$value,
    strategy_params_json = strategy_params_info$json,
    strategy_params_hash = strategy_params_info$hash,
    opening = opening,
    data = list(
      source = "snapshot",
      snapshot_id = snapshot$snapshot_id,
      snapshot_db_path = snapshot$db_path
    )
  )

  if (!is.null(run_id)) config$run_id <- run_id

  class(config) <- c("ledgr_config", class(config))
  validate_ledgr_config(config)
  config
}

ledgr_config_normalize_opening <- function(opening, initial_cash) {
  if (is.null(opening)) {
    return(list(
      cash = as.numeric(initial_cash),
      date = NULL,
      positions = stats::setNames(numeric(), character()),
      cost_basis = NULL
    ))
  }
  if (!inherits(opening, "ledgr_opening")) {
    rlang::abort("`opening` must be NULL or a ledgr_opening object.", class = "ledgr_invalid_args")
  }
  if (!isTRUE(all.equal(as.numeric(opening$cash), as.numeric(initial_cash), tolerance = 0))) {
    rlang::abort("`opening$cash` must match `backtest$initial_cash`.", class = "ledgr_invalid_args")
  }
  list(
    cash = as.numeric(opening$cash),
    date = opening$date,
    positions = opening$positions,
    cost_basis = opening$cost_basis
  )
}

#' Print a ledgr config
#'
#' @param x A `ledgr_config` object.
#' @param ... Unused.
#' @return The input config, invisibly.
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
#' strategy <- function(ctx, params) ctx$flat()
#' bt <- ledgr_backtest(data = bars, strategy = strategy, initial_cash = 1000)
#' print(bt$config)
#' close(bt)
#' @export
print.ledgr_config <- function(x, ...) {
  cat("ledgr_config\n")
  cat("============\n")
  cat("Database:    ", x$db_path, "\n", sep = "")
  snapshot_id <- if (is.list(x$data) && !is.null(x$data$snapshot_id)) x$data$snapshot_id else NA_character_
  cat("Snapshot ID: ", snapshot_id, "\n", sep = "")
  cat("Universe:    ", paste(x$universe$instrument_ids, collapse = ", "), "\n", sep = "")
  cat("Backtest:    ", x$backtest$start_ts_utc, " to ", x$backtest$end_ts_utc, "\n", sep = "")
  cat("Initial Cash:", x$backtest$initial_cash, "\n")
  cat("Fill Model:  ", x$fill_model$type, "\n", sep = "")
  cat("Strategy:    ", x$strategy$id, "\n", sep = "")
  invisible(x)
}

ledgr_backtest_equity <- function(con, run_id) {
  DBI::dbGetQuery(
    con,
    "
    SELECT ts_utc, equity, cash, positions_value
    FROM equity_curve
    WHERE run_id = ?
    ORDER BY ts_utc
    ",
    params = list(run_id)
  )
}

ledgr_empty_fills_table <- function() {
  tibble::tibble(
    event_seq = integer(),
    ts_utc = as.POSIXct(character(), tz = "UTC"),
    instrument_id = character(),
    side = character(),
    qty = numeric(),
    price = numeric(),
    fee = numeric(),
    realized_pnl = numeric(),
    action = character()
  )
}

ledgr_empty_equity_curve <- function() {
  tibble::tibble(
    ts_utc = as.POSIXct(character(), tz = "UTC"),
    equity = numeric(),
    cash = numeric(),
    positions_value = numeric(),
    running_max = numeric(),
    drawdown = numeric()
  )
}

#' Extract fill events from a backtest
#'
#' @param bt A `ledgr_backtest` object.
#' @param lazy If `TRUE`, return a streaming cursor instead of materializing all rows.
#' @param stream_threshold Number of fill rows above which lazy mode is forced.
#' @return A tibble of fill rows, or a `ledgr_fills_cursor` when `lazy = TRUE`.
#' @details Fill rows describe execution events and may include both opening and
#'   closing actions. Closed trades are exposed by `ledgr_results(bt, what =
#'   "trades")`.
#' @examples
#' bars <- data.frame(
#'   ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:3,
#'   instrument_id = "AAA",
#'   open = c(100, 101, 102, 103),
#'   high = c(101, 102, 103, 104),
#'   low = c(99, 100, 101, 102),
#'   close = c(100, 101, 102, 103),
#'   volume = 1000
#' )
#' strategy <- function(ctx, params) {
#'   targets <- ctx$flat()
#'   targets["AAA"] <- 1
#'   targets
#' }
#' bt <- ledgr_backtest(data = bars, strategy = strategy, initial_cash = 1000)
#' ledgr_extract_fills(bt)
#' close(bt)
#' @export
ledgr_extract_fills <- function(bt, lazy = FALSE, stream_threshold = 100000L) {
  ledgr_extract_fills_impl(bt, lazy = lazy, stream_threshold = stream_threshold)
}

ledgr_extract_fills_impl <- function(bt, lazy = FALSE, stream_threshold = 100000L, con = NULL) {
  requested_lazy <- isTRUE(lazy)
  owns_connection <- FALSE
  if (is.null(con)) {
    opened <- if (requested_lazy) {
      list(con = get_connection(bt), close = function() invisible(FALSE))
    } else {
      ledgr_backtest_read_connection(bt)
    }
    con <- opened$con
    owns_connection <- TRUE
    on.exit(opened$close(), add = TRUE)
  }
  total_rows <- DBI::dbGetQuery(
    con,
    "
    SELECT COUNT(*) AS n
    FROM ledger_events
    WHERE run_id = ? AND event_type IN ('FILL', 'FILL_PARTIAL')
    ",
    params = list(bt$run_id)
  )$n[[1]]
  total_rows <- as.integer(total_rows)
  if (is.na(total_rows) || total_rows < 1L) {
    return(ledgr_empty_fills_table())
  }

  if (!is.numeric(stream_threshold) || length(stream_threshold) != 1 || is.na(stream_threshold)) {
    rlang::abort("`stream_threshold` must be a finite numeric scalar.", class = "ledgr_invalid_args")
  }
  stream_threshold <- as.integer(stream_threshold)

  if (total_rows > stream_threshold) {
    lazy <- TRUE
    if (!requested_lazy && isTRUE(owns_connection)) {
      opened$close()
      return(ledgr_extract_fills(bt, lazy = TRUE, stream_threshold = stream_threshold))
    }
  }

  # Temp-table accumulation handles dynamic sizing; no R-side caps needed.
  temp_table <- paste0("temp_fills_", paste(sample(c(letters, LETTERS, 0:9), 12, replace = TRUE), collapse = ""))
  DBI::dbExecute(con, sprintf("DROP TABLE IF EXISTS %s", temp_table))
  DBI::dbExecute(
    con,
    sprintf(
      "
    CREATE TEMP TABLE %s (
      event_seq INTEGER,
      ts_utc TIMESTAMP,
      instrument_id TEXT,
      side TEXT,
      qty DOUBLE,
      price DOUBLE,
      fee DOUBLE,
      realized_pnl DOUBLE,
      action TEXT
    )
    ",
      temp_table
    )
  )

  if (!is.logical(lazy) || length(lazy) != 1 || is.na(lazy)) {
    rlang::abort("`lazy` must be TRUE or FALSE.", class = "ledgr_invalid_args")
  }
  if (!lazy && !(exists("opened", inherits = FALSE) && isTRUE(opened$temporary))) {
    on.exit(DBI::dbExecute(con, sprintf("DROP TABLE IF EXISTS %s", temp_table)), add = TRUE)
  }

  ledger_res <- DBI::dbSendQuery(
    con,
    "
    SELECT event_seq, ts_utc, instrument_id, side, qty, price, fee, meta_json
    FROM ledger_events
    WHERE run_id = ? AND event_type IN ('FILL', 'FILL_PARTIAL')
    ORDER BY event_seq
    ",
    params = list(bt$run_id)
  )
  on.exit(DBI::dbClearResult(ledger_res), add = TRUE)

  fifo <- new.env(parent = emptyenv())
  fetch_size <- 50000L

  repeat {
    rows <- DBI::dbFetch(ledger_res, n = fetch_size)
    if (nrow(rows) == 0) break

    out_rows <- vector("list", nrow(rows) * 2L)
    out_idx <- 0L

    for (i in seq_len(nrow(rows))) {
      inst <- as.character(rows$instrument_id[[i]])
      side <- as.character(rows$side[[i]])
      qty <- suppressWarnings(as.numeric(rows$qty[[i]]))
      price <- suppressWarnings(as.numeric(rows$price[[i]]))

      if (is.na(qty) || qty <= 0 || is.na(price)) {
        out_idx <- out_idx + 1L
        out_rows[[out_idx]] <- data.frame(
          event_seq = rows$event_seq[[i]],
          ts_utc = rows$ts_utc[[i]],
          instrument_id = inst,
          side = side,
          qty = qty,
          price = price,
          fee = rows$fee[[i]],
          realized_pnl = NA_real_,
          action = NA_character_,
          stringsAsFactors = FALSE
        )
        next
      }

      side_norm <- toupper(side)
      if (side_norm %in% c("BUY", "COVER", "BUY_TO_COVER")) {
        direction <- 1L
      } else if (side_norm %in% c("SELL", "SHORT", "SELL_SHORT")) {
        direction <- -1L
      } else {
        out_idx <- out_idx + 1L
        out_rows[[out_idx]] <- data.frame(
          event_seq = rows$event_seq[[i]],
          ts_utc = rows$ts_utc[[i]],
          instrument_id = inst,
          side = side,
          qty = qty,
          price = price,
          fee = rows$fee[[i]],
          realized_pnl = NA_real_,
          action = NA_character_,
          stringsAsFactors = FALSE
        )
        next
      }

      key <- inst
      lots <- if (exists(key, envir = fifo, inherits = FALSE)) {
        get(key, envir = fifo, inherits = FALSE)
      } else {
        data.frame(qty = numeric(), price = numeric(), stringsAsFactors = FALSE)
      }

      net_pos <- if (nrow(lots) > 0) sum(lots$qty) else 0
      if (side_norm == "BUY_TO_COVER" && net_pos >= 0) {
        warning(
          sprintf("[%s:%d] Semantic Violation: BUY_TO_COVER rejected (currently Long)", inst, rows$event_seq[[i]]),
          call. = FALSE
        )
        out_idx <- out_idx + 1L
        out_rows[[out_idx]] <- data.frame(
          event_seq = rows$event_seq[[i]],
          ts_utc = rows$ts_utc[[i]],
          instrument_id = inst,
          side = side,
          qty = qty,
          price = price,
          fee = rows$fee[[i]],
          realized_pnl = NA_real_,
          action = "REJECTED",
          stringsAsFactors = FALSE
        )
        next
      }
      if (side_norm == "SELL_SHORT" && net_pos <= 0) {
        warning(
          sprintf("[%s:%d] Semantic Violation: SELL_SHORT rejected (currently Short)", inst, rows$event_seq[[i]]),
          call. = FALSE
        )
        out_idx <- out_idx + 1L
        out_rows[[out_idx]] <- data.frame(
          event_seq = rows$event_seq[[i]],
          ts_utc = rows$ts_utc[[i]],
          instrument_id = inst,
          side = side,
          qty = qty,
          price = price,
          fee = rows$fee[[i]],
          realized_pnl = NA_real_,
          action = "REJECTED",
          stringsAsFactors = FALSE
        )
        next
      }

      remaining <- qty
      realized_close <- 0
      compensation <- 0
      close_qty <- 0
      open_qty <- 0

      if (direction > 0) {
        if (net_pos < 0) {
          close_qty <- min(remaining, abs(net_pos))
        }
      } else if (net_pos > 0) {
        close_qty <- min(remaining, net_pos)
      }
      open_qty <- remaining - close_qty

      if (close_qty > 0) {
        remaining_close <- close_qty
        if (direction > 0) {
          while (remaining_close > 0 && nrow(lots) > 0 && lots$qty[[1]] < 0) {
            cover_qty <- min(remaining_close, abs(lots$qty[[1]]))
            delta <- (lots$price[[1]] - price) * cover_qty
            y <- delta - compensation
            t <- realized_close + y
            compensation <- (t - realized_close) - y
            realized_close <- t
            lots$qty[[1]] <- lots$qty[[1]] + cover_qty
            remaining_close <- remaining_close - cover_qty
            if (abs(lots$qty[[1]]) < 1e-12) {
              lots <- lots[-1, , drop = FALSE]
            }
          }
        } else {
          while (remaining_close > 0 && nrow(lots) > 0 && lots$qty[[1]] > 0) {
            cover_qty <- min(remaining_close, lots$qty[[1]])
            delta <- (price - lots$price[[1]]) * cover_qty
            y <- delta - compensation
            t <- realized_close + y
            compensation <- (t - realized_close) - y
            realized_close <- t
            lots$qty[[1]] <- lots$qty[[1]] - cover_qty
            remaining_close <- remaining_close - cover_qty
            if (abs(lots$qty[[1]]) < 1e-12) {
              lots <- lots[-1, , drop = FALSE]
            }
          }
        }
      }

      if (open_qty > 0) {
        if (direction > 0) {
          lots <- rbind(
            lots,
            data.frame(qty = open_qty, price = price, stringsAsFactors = FALSE)
          )
        } else {
          lots <- rbind(
            lots,
            data.frame(qty = -open_qty, price = price, stringsAsFactors = FALSE)
          )
        }
      }

      assign(key, lots, envir = fifo)

      meta_raw <- rows$meta_json[[i]]
      if (!is.null(meta_raw) &&
        !(is.atomic(meta_raw) && length(meta_raw) == 1 && is.na(meta_raw)) &&
        !(is.character(meta_raw) && length(meta_raw) == 1 && !nzchar(meta_raw))) {
        meta <- tryCatch(jsonlite::fromJSON(meta_raw, simplifyVector = TRUE), error = function(e) e)
        if (inherits(meta, "error")) {
          warning("Malformed meta_json for fill; realized_pnl set to NA.", call. = FALSE)
        } else if (!is.null(meta$realized_pnl)) {
          meta_val <- suppressWarnings(as.numeric(meta$realized_pnl))
          if (is.na(meta_val)) {
            warning("Malformed meta_json for fill; realized_pnl set to NA.", call. = FALSE)
          } else {
            tol <- max(1e-6, 1e-7 * abs(meta_val))
            if (abs(meta_val - realized_close) > tol) {
              warning(
                sprintf(
                  "[%s:%d] FIFO Mismatch: Expected %.8f, Found %.8f",
                  inst,
                  rows$event_seq[[i]],
                  realized_close,
                  meta_val
                ),
                call. = FALSE
              )
            }
          }
        }
      }

      if (close_qty > 0) {
        out_idx <- out_idx + 1L
        out_rows[[out_idx]] <- data.frame(
          event_seq = rows$event_seq[[i]],
          ts_utc = rows$ts_utc[[i]],
          instrument_id = inst,
          side = side,
          qty = close_qty,
          price = price,
          fee = rows$fee[[i]],
          realized_pnl = realized_close,
          action = "CLOSE",
          stringsAsFactors = FALSE
        )
      }
      if (open_qty > 0) {
        out_idx <- out_idx + 1L
        out_rows[[out_idx]] <- data.frame(
          event_seq = rows$event_seq[[i]],
          ts_utc = rows$ts_utc[[i]],
          instrument_id = inst,
          side = side,
          qty = open_qty,
          price = price,
          fee = rows$fee[[i]],
          realized_pnl = 0,
          action = "OPEN",
          stringsAsFactors = FALSE
        )
      }
    }

    if (out_idx > 0) {
      chunk_df <- do.call(rbind, out_rows[seq_len(out_idx)])
      DBI::dbAppendTable(con, temp_table, chunk_df)
    }
  }

  if (isTRUE(lazy)) {
    fills_res <- DBI::dbSendQuery(con, sprintf("SELECT * FROM %s ORDER BY event_seq", temp_table))
    return(new_ledgr_fills_cursor(fills_res, temp_table, con))
  }

  if (total_rows > stream_threshold) {
    warning("Large fill set materialized (N > threshold). Consider lazy = TRUE for performance.", call. = FALSE)
  }

  tibble::as_tibble(DBI::dbGetQuery(con, sprintf("SELECT * FROM %s ORDER BY event_seq", temp_table)))
}

ledgr_closed_trade_rows <- function(fills) {
  if (nrow(fills) == 0L) {
    return(fills)
  }
  tibble::as_tibble(fills[ledgr_col_equals(fills$action, "CLOSE"), , drop = FALSE])
}

ledgr_extract_trades <- function(bt, con = NULL) {
  ledgr_closed_trade_rows(ledgr_extract_fills_impl(bt, con = con))
}

ledgr_col_equals <- function(x, value) {
  !is.na(x) & as.character(x) == value
}

compute_annualized_return <- function(equity, bars_per_year) {
  if (!is.data.frame(equity) || nrow(equity) < 2) return(NA_real_)
  if (!is.numeric(bars_per_year) || length(bars_per_year) != 1 || !is.finite(bars_per_year) || bars_per_year <= 0) {
    return(NA_real_)
  }

  n_periods <- nrow(equity) - 1
  years <- n_periods / bars_per_year
  if (years <= 0) return(NA_real_)

  total_return <- (equity$equity[[nrow(equity)]] / equity$equity[[1]]) - 1
  (1 + total_return)^(1 / years) - 1
}

compute_max_drawdown <- function(equity_values) {
  if (length(equity_values) < 1) return(NA_real_)
  running_max <- cummax(equity_values)
  drawdown <- (equity_values / running_max) - 1
  min(drawdown, na.rm = TRUE)
}

compute_time_in_market <- function(equity) {
  if (!is.data.frame(equity) || nrow(equity) == 0) return(NA_real_)
  mean(abs(equity$positions_value) > 1e-6)
}

ledgr_estimate_bars_per_year <- function(bt, equity, con = NULL) {
  fallback <- 252
  if (!inherits(bt, "ledgr_backtest")) return(fallback)
  if (!is.list(bt$config) || is.null(bt$config$data$snapshot_id)) return(fallback)

  if (is.null(con)) {
    opened <- ledgr_backtest_read_connection(bt)
    con <- opened$con
    on.exit(opened$close(), add = TRUE)
  }
  snapshot_id <- bt$config$data$snapshot_id
  if (!is.null(bt$config$data) && is.list(bt$config$data) && identical(bt$config$data$source, "snapshot")) {
    run_db_path <- bt$config$db_path
    snapshot_db_path <- ledgr_snapshot_db_path_from_config(bt$config, run_db_path)
    ledgr_prepare_snapshot_source_tables(con, snapshot_db_path, run_db_path)
  }

  inst <- DBI::dbGetQuery(
    con,
    "SELECT instrument_id FROM snapshot_instruments WHERE snapshot_id = ? ORDER BY instrument_id LIMIT 1",
    params = list(snapshot_id)
  )$instrument_id[[1]]
  if (is.null(inst) || is.na(inst) || !nzchar(inst)) return(fallback)

  median_seconds <- DBI::dbGetQuery(
    con,
    "
    SELECT median(diff_seconds) AS median_diff
    FROM (
      SELECT datediff('second', LAG(ts_utc) OVER (ORDER BY ts_utc), ts_utc) AS diff_seconds
      FROM snapshot_bars
      WHERE snapshot_id = ? AND instrument_id = ?
    )
    WHERE diff_seconds IS NOT NULL
    ",
    params = list(snapshot_id, inst)
  )$median_diff[[1]]

  median_seconds <- suppressWarnings(as.numeric(median_seconds))
  if (!is.finite(median_seconds) || median_seconds <= 0) return(fallback)

  bars_per_year <- snap_to_frequency(median_seconds)
  if (!is.finite(bars_per_year) || bars_per_year <= 0) return(fallback)
  bars_per_year
}

snap_to_frequency <- function(median_seconds) {
  if (!is.numeric(median_seconds) || length(median_seconds) != 1 || !is.finite(median_seconds) || median_seconds <= 0) {
    return(NA_real_)
  }

  standard <- data.frame(
    seconds = c(60, 300, 900, 3600, 86400, 604800),
    bars_per_year = c(525600, 105120, 35040, 8760, 252, 52),
    stringsAsFactors = FALSE
  )
  raw <- (365.25 * 24 * 3600) / median_seconds
  idx <- which.min(abs(standard$seconds - median_seconds))
  distance <- abs(standard$seconds[[idx]] - median_seconds) / standard$seconds[[idx]]
  if (distance < 0.2) {
    return(standard$bars_per_year[[idx]])
  }
  message(sprintf("Frequency snap fallback to 252 (raw=%.2f).", raw))
  252
}

ledgr_compute_metrics_internal <- function(bt, metrics = "standard") {
  if (!identical(metrics, "standard")) {
    rlang::abort(
      "Only metrics='standard' supported in v0.1.2. Advanced metrics are deferred to v0.1.3.",
      class = "ledgr_invalid_args"
    )
  }

  opened <- ledgr_backtest_read_connection(bt)
  con <- opened$con
  on.exit(opened$close(), add = TRUE)
  equity <- ledgr_backtest_equity(con, bt$run_id)
  equity$equity <- as.numeric(equity$equity)
  equity$positions_value <- as.numeric(equity$positions_value)

  fills <- ledgr_extract_fills_impl(bt, con = con)
  trades <- ledgr_closed_trade_rows(fills)

  returns <- numeric(0)
  if (nrow(equity) > 1) {
    prev <- equity$equity[-nrow(equity)]
    cur <- equity$equity[-1]
    returns <- (cur / prev) - 1
  }
  bars_per_year <- ledgr_estimate_bars_per_year(bt, equity, con = con)

  list(
    total_return = if (nrow(equity) > 0) (equity$equity[[nrow(equity)]] / equity$equity[[1]]) - 1 else NA_real_,
    annualized_return = compute_annualized_return(equity, bars_per_year),
    volatility = if (length(returns) > 1) stats::sd(returns, na.rm = TRUE) * sqrt(bars_per_year) else NA_real_,
    max_drawdown = compute_max_drawdown(equity$equity),
    n_trades = nrow(trades),
    win_rate = if (nrow(trades) > 0) sum(trades$realized_pnl > 0, na.rm = TRUE) / nrow(trades) else NA_real_,
    avg_trade = if (nrow(trades) > 0) mean(trades$realized_pnl, na.rm = TRUE) else NA_real_,
    time_in_market = compute_time_in_market(equity)
  )
}

#' Compute an equity curve from a backtest
#'
#' @param bt A `ledgr_backtest` object.
#' @return A tibble containing equity, running maximum, and drawdown.
#' @examples
#' bars <- data.frame(
#'   ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:3,
#'   instrument_id = "AAA",
#'   open = c(100, 101, 102, 103),
#'   high = c(101, 102, 103, 104),
#'   low = c(99, 100, 101, 102),
#'   close = c(100, 101, 102, 103),
#'   volume = 1000
#' )
#' strategy <- function(ctx, params) {
#'   targets <- ctx$flat()
#'   targets["AAA"] <- 1
#'   targets
#' }
#' bt <- ledgr_backtest(data = bars, strategy = strategy, initial_cash = 1000)
#' ledgr_compute_equity_curve(bt)
#' close(bt)
#' @export
ledgr_compute_equity_curve <- function(bt) {
  ledgr_compute_equity_curve_impl(bt)
}

ledgr_compute_equity_curve_impl <- function(bt, con = NULL) {
  if (is.null(con)) {
    opened <- ledgr_backtest_read_connection(bt)
    con <- opened$con
    on.exit(opened$close(), add = TRUE)
  }
  equity <- ledgr_backtest_equity(con, bt$run_id)
  if (nrow(equity) == 0) {
    return(ledgr_empty_equity_curve())
  }

  equity$equity <- as.numeric(equity$equity)
  equity$running_max <- cummax(equity$equity)
  equity$drawdown <- (equity$equity / equity$running_max - 1)
  tibble::as_tibble(equity)
}

#' Summarize per-pulse telemetry
#'
#' @param bt A `ledgr_backtest` object. This function does not accept a DuckDB
#'   file path; use `ledgr_run_info()` for persisted run-level telemetry.
#' @return A tibble with mean/median/p99 values per telemetry component.
#' @details
#' This is a diagnostic helper for engine profiling. It only reports detailed
#' telemetry captured for runs executed in the current R session. Timing
#' components are reported in seconds; feature-cache hit/miss rows are counts.
#' The compact telemetry persisted in durable experiment stores is available
#' through `ledgr_run_info()`.
#'
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
#' bt <- ledgr_backtest(data = bars, strategy = strategy, initial_cash = 1000)
#' ledgr_backtest_bench(bt)
#' close(bt)
#' @export
ledgr_backtest_bench <- function(bt) {
  if (!inherits(bt, "ledgr_backtest")) {
    rlang::abort("`bt` must be a ledgr_backtest object.", class = "ledgr_invalid_backtest")
  }

  telemetry <- ledgr_get_run_telemetry(bt$run_id)
  if (is.null(telemetry)) {
    rlang::abort("No telemetry found for this run_id. Run ledgr_backtest() to capture telemetry.", class = "ledgr_invalid_args")
  }

  summarize_vec <- function(x) {
    if (length(x) == 0) return(c(mean = NA_real_, median = NA_real_, p99 = NA_real_))
    c(
      mean = mean(x, na.rm = TRUE),
      median = stats::median(x, na.rm = TRUE),
      p99 = stats::quantile(x, 0.99, na.rm = TRUE, names = FALSE)
    )
  }

  components <- c(
    "t_pre",
    "t_post",
    "t_loop",
    "t_pulse",
    "t_bars",
    "t_ctx",
    "t_fill",
    "t_state",
    "t_feats",
    "t_strat",
    "t_exec",
    "feature_cache_hits",
    "feature_cache_misses"
  )
  out <- lapply(components, function(name) summarize_vec(telemetry[[name]]))

  tibble::tibble(
    component = components,
    mean = vapply(out, `[[`, numeric(1), "mean"),
    median = vapply(out, `[[`, numeric(1), "median"),
    p99 = vapply(out, `[[`, numeric(1), "p99")
  )
}

#' Compute standard metrics from backtest results
#'
#' @param bt A `ledgr_backtest` object. This function does not accept an equity
#'   tibble directly.
#' @param metrics Only `"standard"` is supported in v0.1.2.
#' @return Named list of metric values.
#'
#' @details
#' Standard metrics are derived from the ledger and equity curve:
#' - `total_return`: final equity divided by initial equity minus 1.
#' - `annualized_return`: geometric annualized return using the detected bar
#'   frequency, snapped to common frequencies such as daily or weekly.
#' - `volatility`: annualized standard deviation of period equity returns.
#' - `max_drawdown`: worst percentage decline from the running equity maximum.
#' - `n_trades`: number of closed trade rows. Open-only fills do not count until
#'   a later fill closes quantity.
#' - `win_rate`: share of closed trade rows with strict realized P&L `> 0`;
#'   breakeven is not a win, and open-position gains remain in equity until
#'   closed.
#' - `avg_trade`: mean realized P&L across closed trade rows.
#' - `time_in_market`: share of equity timestamps with non-zero position value.
#'
#' @examples
#' bars <- data.frame(
#'   ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:3,
#'   instrument_id = "AAA",
#'   open = c(100, 101, 102, 103),
#'   high = c(101, 102, 103, 104),
#'   low = c(99, 100, 101, 102),
#'   close = c(100, 101, 102, 103),
#'   volume = 1000
#' )
#' strategy <- function(ctx, params) {
#'   targets <- ctx$flat()
#'   targets["AAA"] <- 1
#'   targets
#' }
#' bt <- ledgr_backtest(data = bars, strategy = strategy, initial_cash = 1000)
#' ledgr_compute_metrics(bt)
#' close(bt)
#' @export
ledgr_compute_metrics <- function(bt, metrics = "standard") {
  ledgr_compute_metrics_internal(bt, metrics = metrics)
}

#' Print a backtest result
#'
#' @param x A `ledgr_backtest` object.
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
#' bt <- ledgr_backtest(data = bars, strategy = strategy, initial_cash = 1000)
#' print(bt)
#' close(bt)
#' @export
print.ledgr_backtest <- function(x, ...) {
  if (!inherits(x, "ledgr_backtest")) {
    rlang::abort("`x` must be a ledgr_backtest object.", class = "ledgr_invalid_backtest")
  }

  cfg <- x$config
  universe <- cfg$universe$instrument_ids
  start <- cfg$backtest$start_ts_utc
  end <- cfg$backtest$end_ts_utc
  initial_cash <- cfg$backtest$initial_cash
  execution_mode <- if (is.list(cfg$engine) && !is.null(cfg$engine$execution_mode)) {
    cfg$engine$execution_mode
  } else {
    NA_character_
  }

  opened <- ledgr_backtest_read_connection(x)
  con <- opened$con
  on.exit(opened$close(), add = TRUE)
  final_equity <- DBI::dbGetQuery(
    con,
    "
    SELECT equity
    FROM equity_curve
    WHERE run_id = ?
    ORDER BY ts_utc DESC
    LIMIT 1
    ",
    params = list(x$run_id)
  )$equity[[1]]
  final_equity <- as.numeric(final_equity)

  pnl <- final_equity - initial_cash
  pnl_pct <- (pnl / initial_cash) * 100

  cat("ledgr Backtest Results\n")
  cat("======================\n\n")
  cat("Run ID:        ", x$run_id, "\n")
  cat("Universe:      ", paste(universe, collapse = ", "), "\n")
  cat("Date Range:    ", start, "to", end, "\n")
  cat("Execution Mode:", execution_mode, "\n")
  cat("Initial Cash:  ", sprintf("$%.2f", initial_cash), "\n")
  cat("Final Equity:  ", sprintf("$%.2f", final_equity), "\n")
  cat("P&L:           ", sprintf("$%.2f (%.2f%%)", pnl, pnl_pct), "\n\n")
  cat("Use summary(bt) for detailed metrics\n")
  cat("Use plot(bt) for equity curve visualization\n")

  invisible(x)
}

#' Summarize a backtest result
#'
#' Prints standard performance, risk, trade, and exposure metrics. See
#' `ledgr_compute_metrics()` for metric definitions.
#'
#' @param object A `ledgr_backtest` object.
#' @param metrics Only `"standard"` is supported in v0.1.2.
#' @param ... Unused.
#' @return The input object, invisibly.
#' @examples
#' bars <- data.frame(
#'   ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:3,
#'   instrument_id = "AAA",
#'   open = c(100, 101, 102, 103),
#'   high = c(101, 102, 103, 104),
#'   low = c(99, 100, 101, 102),
#'   close = c(100, 101, 102, 103),
#'   volume = 1000
#' )
#' strategy <- function(ctx, params) {
#'   targets <- ctx$flat()
#'   targets["AAA"] <- 1
#'   targets
#' }
#' bt <- ledgr_backtest(data = bars, strategy = strategy, initial_cash = 1000)
#' summary(bt)
#' close(bt)
#' @export
summary.ledgr_backtest <- function(object, metrics = "standard", ...) {
  if (!inherits(object, "ledgr_backtest")) {
    rlang::abort("`object` must be a ledgr_backtest object.", class = "ledgr_invalid_backtest")
  }

  computed <- ledgr_compute_metrics(object, metrics = metrics)

  cat("ledgr Backtest Summary\n")
  cat("======================\n\n")

  cat("Performance Metrics:\n")
  cat(sprintf("  Total Return:        %.2f%%\n", computed$total_return * 100))
  cat(sprintf("  Annualized Return:   %.2f%%\n", computed$annualized_return * 100))
  cat(sprintf("  Max Drawdown:        %.2f%%\n", computed$max_drawdown * 100))

  cat("\nRisk Metrics:\n")
  cat(sprintf("  Volatility (annual): %.2f%%\n", computed$volatility * 100))

  cat("\nTrade Statistics:\n")
  cat(sprintf("  Total Trades:        %d\n", computed$n_trades))
  if (computed$n_trades > 0) {
    cat(sprintf("  Win Rate:            %.2f%%\n", computed$win_rate * 100))
    cat(sprintf("  Avg Trade:           $%.2f\n", computed$avg_trade))
  } else {
    cat("  Win Rate:            N/A (no trades)\n")
    cat("  Avg Trade:           N/A (no trades)\n")
  }

  cat("\nExposure:\n")
  cat(sprintf("  Time in Market:      %.2f%%\n", computed$time_in_market * 100))

  invisible(object)
}

#' Extract tidy backtest tables
#'
#' @param x A `ledgr_backtest` object.
#' @param what Result table to extract: `"equity"`, `"trades"`, `"fills"`, or
#'   `"ledger"`.
#' @param ... Unused.
#' @param type Deprecated alias for `what`.
#' @return A tibble with the requested result table.
#' @details `what = "fills"` returns execution fill rows, including opening
#'   and closing actions. `what = "trades"` returns closed trade rows only.
#' @examples
#' bars <- data.frame(
#'   ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:3,
#'   instrument_id = "AAA",
#'   open = c(100, 101, 102, 103),
#'   high = c(101, 102, 103, 104),
#'   low = c(99, 100, 101, 102),
#'   close = c(100, 101, 102, 103),
#'   volume = 1000
#' )
#' strategy <- function(ctx, params) {
#'   targets <- ctx$flat()
#'   targets["AAA"] <- 1
#'   targets
#' }
#' bt <- ledgr_backtest(data = bars, strategy = strategy, initial_cash = 1000)
#' tibble::as_tibble(bt, what = "trades")
#' tibble::as_tibble(bt, what = "equity")
#' close(bt)
#' @export
as_tibble.ledgr_backtest <- function(x, what = "equity", ..., type = NULL) {
  if (!inherits(x, "ledgr_backtest")) {
    rlang::abort("`x` must be a ledgr_backtest object.", class = "ledgr_invalid_backtest")
  }

  if (!is.null(type)) what <- type
  what <- match.arg(what, c("equity", "fills", "trades", "ledger"))
  opened <- ledgr_backtest_read_connection(x)
  con <- opened$con
  on.exit(opened$close(), add = TRUE)

  switch(
    what,
    equity = {
      ledgr_compute_equity_curve_impl(x, con = con)
    },
    fills = ledgr_extract_fills_impl(x, con = con),
    trades = ledgr_extract_trades(x, con = con),
    ledger = tibble::as_tibble(
      DBI::dbGetQuery(
        con,
        "
        SELECT *
        FROM ledger_events
        WHERE run_id = ?
        ORDER BY event_seq
        ",
        params = list(x$run_id)
      )
    )
  )
}

#' Extract ledgr result tables
#'
#' Package-prefixed convenience wrapper around `tibble::as_tibble()` for
#' backtest result tables.
#'
#' The returned object is tibble-compatible. Its print method may compact
#' all-midnight UTC timestamps for EOD output according to
#' `options(ledgr.print_ts_utc)`, but programmatic access keeps `ts_utc` as
#' POSIXct UTC.
#'
#' `what = "fills"` returns execution fill rows, including opening and closing
#' actions. `what = "trades"` returns closed trade rows only; this is the same
#' definition used by `summary()` and `ledgr_compare_runs()` for `n_trades`.
#'
#' @param bt A `ledgr_backtest` object.
#' @param what Result table to extract: `"equity"`, `"fills"`, `"trades"`, or
#'   `"ledger"`.
#' @return A ledgr result table, which is a classed tibble with the requested
#'   result columns.
#' @examples
#' bars <- data.frame(
#'   ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:3,
#'   instrument_id = "AAA",
#'   open = c(100, 101, 102, 103),
#'   high = c(101, 102, 103, 104),
#'   low = c(99, 100, 101, 102),
#'   close = c(100, 101, 102, 103),
#'   volume = 1000
#' )
#' strategy <- function(ctx, params) {
#'   targets <- ctx$flat()
#'   targets["AAA"] <- 1
#'   targets
#' }
#' bt <- ledgr_backtest(data = bars, strategy = strategy, initial_cash = 1000)
#' ledgr_results(bt, what = "trades")
#' close(bt)
#' @export
ledgr_results <- function(bt, what = c("equity", "fills", "trades", "ledger")) {
  what <- match.arg(what)
  ledgr_result_table(tibble::as_tibble(bt, what = what), what = what)
}
