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
#'   model with zero spread and zero fixed commission. For
#'   `fill_model$spread_bps`, ledgr applies the full value on each fill leg:
#'   buys fill at `open * (1 + spread_bps / 10000)` and sells fill at
#'   `open * (1 - spread_bps / 10000)`. A buy/sell round trip therefore costs
#'   approximately `2 * spread_bps` basis points before commissions.
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
#' `spread_bps` is a per-leg execution adjustment, not a quoted bid/ask spread
#' split across the buy and sell legs. With `spread_bps = 5`, a buy fills five
#' basis points above the next open and a sell fills five basis points below the
#' next open, for an approximate ten basis-point round-trip cost before fixed
#' commissions.
#'
#' v0.1.x does not provide a supported broker-style short-selling contract.
#' Strategy authors should treat negative target quantities as outside the
#' supported public workflow until explicit shorting semantics are specified.
#'
#' @section Articles:
#' Strategy authoring:
#' `vignette("strategy-development", package = "ledgr")`
#' `system.file("doc", "strategy-development.html", package = "ledgr")`
#'
#' Metrics and accounting:
#' `vignette("metrics-and-accounting", package = "ledgr")`
#' `system.file("doc", "metrics-and-accounting.html", package = "ledgr")`
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
#' @section Articles:
#' Strategy authoring:
#' `vignette("strategy-development", package = "ledgr")`
#' `system.file("doc", "strategy-development.html", package = "ledgr")`
#'
#' Metrics and accounting:
#' `vignette("metrics-and-accounting", package = "ledgr")`
#' `system.file("doc", "metrics-and-accounting.html", package = "ledgr")`
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
    source_info <- ledgr_strategy_source_info(strategy)
    if (!isTRUE(source_info$preflight$allowed)) {
      ledgr_abort_strategy_preflight(source_info$preflight)
    }
    key <- ledgr_register_strategy_fn(strategy)
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
#' if (interactive()) print(bt$config)
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
    SELECT event_seq, ts_utc, event_type, instrument_id, side, qty, price, fee, meta_json
    FROM ledger_events
    WHERE run_id = ?
      AND event_type IN ('CASHFLOW', 'FILL', 'FILL_PARTIAL')
    ORDER BY event_seq
    ",
    params = list(bt$run_id)
  )
  on.exit(DBI::dbClearResult(ledger_res), add = TRUE)

  lot_state <- ledgr_lot_state()
  fetch_size <- 50000L

  repeat {
    rows <- DBI::dbFetch(ledger_res, n = fetch_size)
    if (nrow(rows) == 0) break

    out_rows <- vector("list", nrow(rows) * 2L)
    out_idx <- 0L

    for (i in seq_len(nrow(rows))) {
      event_type <- as.character(rows$event_type[[i]])
      inst <- as.character(rows$instrument_id[[i]])
      side <- as.character(rows$side[[i]])
      qty <- suppressWarnings(as.numeric(rows$qty[[i]]))
      price <- suppressWarnings(as.numeric(rows$price[[i]]))
      fee <- suppressWarnings(as.numeric(rows$fee[[i]]))
      meta_raw <- rows$meta_json[[i]]
      meta_parse_error <- FALSE
      meta <- NULL
      if (!is.null(meta_raw) &&
        !(is.atomic(meta_raw) && length(meta_raw) == 1 && is.na(meta_raw)) &&
        !(is.character(meta_raw) && length(meta_raw) == 1 && !nzchar(meta_raw))) {
        meta <- tryCatch(
          jsonlite::fromJSON(meta_raw, simplifyVector = FALSE),
          error = function(e) {
            meta_parse_error <<- TRUE
            NULL
          }
        )
      }

      if (identical(event_type, "CASHFLOW")) {
        lot_res <- ledgr_lot_apply_event(
          lot_state,
          event_type = event_type,
          instrument_id = inst,
          meta = meta
        )
        lot_state <- lot_res$state
        next
      }

      if (is.na(qty) || qty <= 0 || is.na(price)) {
        out_idx <- out_idx + 1L
        out_rows[[out_idx]] <- data.frame(
          event_seq = rows$event_seq[[i]],
          ts_utc = rows$ts_utc[[i]],
          instrument_id = inst,
          side = side,
          qty = qty,
          price = price,
          fee = fee,
          realized_pnl = NA_real_,
          action = NA_character_,
          stringsAsFactors = FALSE
        )
        next
      }

      side_norm <- toupper(side)
      if (!(side_norm %in% c("BUY", "COVER", "BUY_TO_COVER", "SELL", "SHORT", "SELL_SHORT"))) {
        out_idx <- out_idx + 1L
        out_rows[[out_idx]] <- data.frame(
          event_seq = rows$event_seq[[i]],
          ts_utc = rows$ts_utc[[i]],
          instrument_id = inst,
          side = side,
          qty = qty,
          price = price,
          fee = fee,
          realized_pnl = NA_real_,
          action = NA_character_,
          stringsAsFactors = FALSE
        )
        next
      }

      lots <- ledgr_lot_get(lot_state, inst)
      net_pos <- if (length(lots) > 0L) {
        sum(vapply(lots, function(lot) as.numeric(lot$qty), numeric(1)))
      } else {
        0
      }
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
          fee = fee,
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
          fee = fee,
          realized_pnl = NA_real_,
          action = "REJECTED",
          stringsAsFactors = FALSE
        )
        next
      }

      lot_res <- ledgr_lot_apply_event(
        lot_state,
        event_type = event_type,
        instrument_id = inst,
        side = side,
        qty = qty,
        price = price,
        fee = fee,
        meta = meta
      )
      lot_state <- lot_res$state
      close_qty <- lot_res$close_qty
      open_qty <- lot_res$open_qty
      realized_close <- lot_res$realized_close

      if (!is.null(meta_raw) &&
        !(is.atomic(meta_raw) && length(meta_raw) == 1 && is.na(meta_raw)) &&
        !(is.character(meta_raw) && length(meta_raw) == 1 && !nzchar(meta_raw))) {
        if (isTRUE(meta_parse_error)) {
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
          fee = fee,
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
          fee = fee,
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
  initial_equity <- as.numeric(equity$equity[[1]])
  final_equity <- as.numeric(equity$equity[[nrow(equity)]])
  if (!is.finite(initial_equity) || initial_equity == 0 || !is.finite(final_equity)) {
    return(NA_real_)
  }

  n_periods <- nrow(equity) - 1
  years <- n_periods / bars_per_year
  if (years <= 0) return(NA_real_)

  total_return <- (final_equity / initial_equity) - 1
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

ledgr_metric_sd_epsilon <- function() .Machine$double.eps

compute_period_returns <- function(equity_values) {
  equity_values <- as.numeric(equity_values)
  if (length(equity_values) < 2L) return(numeric(0))
  prev <- equity_values[-length(equity_values)]
  cur <- equity_values[-1L]
  out <- rep(NA_real_, length(cur))
  ok <- is.finite(prev) & is.finite(cur) & prev != 0
  out[ok] <- (cur[ok] / prev[ok]) - 1
  out
}

compute_rf_period_return <- function(risk_free_rate, bars_per_year) {
  if (!is.numeric(risk_free_rate) || length(risk_free_rate) != 1L ||
    !is.finite(risk_free_rate) || risk_free_rate <= -1) {
    return(NA_real_)
  }
  if (!is.numeric(bars_per_year) || length(bars_per_year) != 1L ||
    !is.finite(bars_per_year) || bars_per_year <= 0) {
    return(NA_real_)
  }
  (1 + risk_free_rate)^(1 / bars_per_year) - 1
}

compute_annualized_volatility <- function(returns, bars_per_year) {
  returns <- as.numeric(returns)
  if (length(returns) < 2L || any(!is.finite(returns))) return(NA_real_)
  if (!is.numeric(bars_per_year) || length(bars_per_year) != 1L ||
    !is.finite(bars_per_year) || bars_per_year <= 0) {
    return(NA_real_)
  }
  sd_returns <- stats::sd(returns)
  if (!is.finite(sd_returns)) {
    return(NA_real_)
  }
  sd_returns * sqrt(bars_per_year)
}

compute_sharpe_ratio <- function(returns, bars_per_year, risk_free_rate = 0) {
  returns <- as.numeric(returns)
  if (length(returns) < 2L || any(!is.finite(returns))) return(NA_real_)
  if (!is.numeric(bars_per_year) || length(bars_per_year) != 1L ||
    !is.finite(bars_per_year) || bars_per_year <= 0) {
    return(NA_real_)
  }
  rf_period_return <- compute_rf_period_return(risk_free_rate, bars_per_year)
  if (!is.finite(rf_period_return)) return(NA_real_)
  excess_returns <- returns - rf_period_return
  sd_excess <- stats::sd(excess_returns)
  if (!is.finite(sd_excess) || sd_excess <= ledgr_metric_sd_epsilon()) {
    return(NA_real_)
  }
  mean(excess_returns) / sd_excess * sqrt(bars_per_year)
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

ledgr_compute_metrics_internal <- function(bt, metrics = "standard", risk_free_rate = 0) {
  if (!identical(metrics, "standard")) {
    rlang::abort(
      "Only metrics = 'standard' is supported.",
      class = "ledgr_invalid_args"
    )
  }
  if (!is.numeric(risk_free_rate) || length(risk_free_rate) != 1L ||
    !is.finite(risk_free_rate) || risk_free_rate <= -1) {
    rlang::abort(
      "`risk_free_rate` must be a finite scalar annual rate greater than -1.",
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

  returns <- compute_period_returns(equity$equity)
  bars_per_year <- ledgr_estimate_bars_per_year(bt, equity, con = con)
  initial_equity <- if (nrow(equity) > 0) as.numeric(equity$equity[[1]]) else NA_real_
  final_equity <- if (nrow(equity) > 0) as.numeric(equity$equity[[nrow(equity)]]) else NA_real_
  total_return <- if (nrow(equity) > 0 && is.finite(initial_equity) && initial_equity != 0 && is.finite(final_equity)) {
    (final_equity / initial_equity) - 1
  } else {
    NA_real_
  }

  list(
    total_return = total_return,
    annualized_return = compute_annualized_return(equity, bars_per_year),
    volatility = compute_annualized_volatility(returns, bars_per_year),
    sharpe_ratio = compute_sharpe_ratio(returns, bars_per_year, risk_free_rate = risk_free_rate),
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
#' @param metrics Only `"standard"` is supported in v0.1.7.
#' @param risk_free_rate Scalar annual risk-free rate as a decimal. The default
#'   is `0`. For example, `0.02` means two percent per year.
#' @return Named list of metric values.
#'
#' @details
#' Standard metrics are derived from the ledger and equity curve:
#' - `total_return`: last public equity row divided by the first public equity
#'   row minus 1.
#' - `annualized_return`: geometric annualized return from the first and last
#'   public equity rows using the detected bar frequency, snapped to common
#'   frequencies such as daily or weekly.
#' - `volatility`: annualized standard deviation of adjacent public equity-row
#'   returns.
#' - `sharpe_ratio`: annualized Sharpe ratio over adjacent public equity-row
#'   excess returns, using the scalar annual `risk_free_rate` converted to a
#'   per-period return with the detected bar frequency. Flat, constant-return,
#'   invalid, or short return series return `NA_real_`.
#' - `max_drawdown`: maximum peak-to-trough percentage decline,
#'   `min(equity / cummax(equity) - 1)`.
#' - `n_trades`: number of closed trade rows. Open-only fills do not count until
#'   a later fill closes quantity.
#' - `win_rate`: share of closed trade rows with strict realized P&L `> 0`;
#'   breakeven is not a win, and open-position gains remain in equity until
#'   closed.
#' - `avg_trade`: mean realized P&L across closed trade rows.
#' - `time_in_market`: share of equity timestamps with absolute
#'   `positions_value > 1e-6`.
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
ledgr_compute_metrics <- function(bt, metrics = "standard", risk_free_rate = 0) {
  ledgr_compute_metrics_internal(bt, metrics = metrics, risk_free_rate = risk_free_rate)
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
#' Prints standard performance, risk, trade, and exposure metrics.
#'
#' @param object A `ledgr_backtest` object.
#' @param metrics Only `"standard"` is supported in v0.1.7.
#' @param risk_free_rate Scalar annual risk-free rate as a decimal. The default
#'   is `0`.
#' @param ... Unused.
#' @return The input `ledgr_backtest` object, invisibly. The printed values are
#'   descriptive output; use `ledgr_compute_metrics()` for a named list of the
#'   same metric values.
#'
#' @details
#' The standard summary displays:
#' - total return: last public equity row divided by the first public equity
#'   row minus 1;
#' - annualized return: geometric annualized return from the first and last
#'   public equity rows using the detected bar frequency;
#' - max drawdown: maximum peak-to-trough decline,
#'   `min(equity / cummax(equity) - 1)`;
#' - annualized volatility: standard deviation of adjacent equity-row returns
#'   multiplied by `sqrt(bars_per_year)`;
#' - Sharpe ratio: annualized ratio of average period excess return to
#'   excess-return standard deviation, using the scalar annual `risk_free_rate`
#'   converted to a per-period return;
#' - total trades: number of closed trade rows, not number of fill rows;
#' - win rate: share of closed trade rows with strict `realized_pnl > 0`;
#' - average trade: mean `realized_pnl` across closed trade rows;
#' - time in market: share of equity rows with absolute
#'   `positions_value > 1e-6`.
#'
#' If there are no closed trade rows, total trades is zero and win rate and
#' average trade are printed as not available. If registered features cannot
#' become usable because an instrument has fewer bars than the feature contract
#' requires, the summary prints a compact Warmup Diagnostics section naming the
#' feature ID, instrument ID, required bars, and available bars.
#'
#' @section Articles:
#' Metrics and accounting:
#' `vignette("metrics-and-accounting", package = "ledgr")`
#' `system.file("doc", "metrics-and-accounting.html", package = "ledgr")`
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
summary.ledgr_backtest <- function(object, metrics = "standard", risk_free_rate = 0, ...) {
  if (!inherits(object, "ledgr_backtest")) {
    rlang::abort("`object` must be a ledgr_backtest object.", class = "ledgr_invalid_backtest")
  }

  computed <- ledgr_compute_metrics(object, metrics = metrics, risk_free_rate = risk_free_rate)

  cat("ledgr Backtest Summary\n")
  cat("======================\n\n")

  cat("Performance Metrics:\n")
  cat(sprintf("  Total Return:        %.2f%%\n", computed$total_return * 100))
  cat(sprintf("  Annualized Return:   %.2f%%\n", computed$annualized_return * 100))
  cat(sprintf("  Max Drawdown:        %.2f%%\n", computed$max_drawdown * 100))

  cat("\nRisk Metrics:\n")
  cat(sprintf("  Volatility (annual): %.2f%%\n", computed$volatility * 100))
  sharpe_label <- if (is.finite(computed$sharpe_ratio)) sprintf("%.3f", computed$sharpe_ratio) else "N/A"
  cat(sprintf("  Sharpe Ratio:        %s\n", sharpe_label))

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

  diagnostics <- tryCatch(
    ledgr_backtest_warmup_diagnostics(object),
    error = function(e) NULL
  )
  ledgr_print_warmup_diagnostics(diagnostics)

  invisible(object)
}

ledgr_empty_warmup_diagnostics <- function() {
  out <- tibble::tibble(
    feature_id = character(),
    instrument_id = character(),
    required_bars = integer(),
    stable_after = integer(),
    available_bars = integer()
  )
  class(out) <- unique(c("ledgr_warmup_diagnostics", class(out)))
  out
}

ledgr_warmup_diagnostics_from_counts <- function(feature_contracts, bar_counts) {
  if (!is.data.frame(feature_contracts) || nrow(feature_contracts) == 0L ||
    !is.data.frame(bar_counts) || nrow(bar_counts) == 0L) {
    return(ledgr_empty_warmup_diagnostics())
  }

  required_cols <- c("feature_id", "required_bars", "stable_after")
  if (!all(required_cols %in% names(feature_contracts))) {
    rlang::abort("`feature_contracts` must include feature_id, required_bars, and stable_after.", class = "ledgr_invalid_args")
  }
  if (!all(c("instrument_id", "available_bars") %in% names(bar_counts))) {
    rlang::abort("`bar_counts` must include instrument_id and available_bars.", class = "ledgr_invalid_args")
  }

  feature_idx <- rep(seq_len(nrow(feature_contracts)), each = nrow(bar_counts))
  count_idx <- rep(seq_len(nrow(bar_counts)), times = nrow(feature_contracts))
  pairs <- data.frame(
    feature_contracts[feature_idx, required_cols, drop = FALSE],
    bar_counts[count_idx, c("instrument_id", "available_bars"), drop = FALSE],
    row.names = NULL,
    stringsAsFactors = FALSE
  )
  pairs$required_bars <- as.integer(pairs$required_bars)
  pairs$stable_after <- as.integer(pairs$stable_after)
  pairs$available_bars <- as.integer(pairs$available_bars)
  needed_bars <- pairs$stable_after
  out <- pairs[pairs$available_bars < needed_bars, , drop = FALSE]
  if (nrow(out) == 0L) {
    return(ledgr_empty_warmup_diagnostics())
  }
  out <- out[order(out$instrument_id, out$feature_id), , drop = FALSE]
  out <- tibble::as_tibble(out[, c("feature_id", "instrument_id", "required_bars", "stable_after", "available_bars"), drop = FALSE])
  class(out) <- unique(c("ledgr_warmup_diagnostics", class(out)))
  out
}

ledgr_feature_contracts_from_backtest_config <- function(bt) {
  cfg <- bt$config
  feats <- cfg$features
  if (is.null(feats) || !isTRUE(feats$enabled) || !is.list(feats$defs) || length(feats$defs) == 0L) {
    return(tibble::tibble(feature_id = character(), required_bars = integer(), stable_after = integer()))
  }
  rows <- lapply(feats$defs, function(def) {
    feature_id <- def$id
    if (is.null(feature_id)) feature_id <- def$name
    if (is.null(feature_id) || !is.character(feature_id) || length(feature_id) != 1L || is.na(feature_id) || !nzchar(feature_id)) {
      return(NULL)
    }
    required_bars <- def$requires_bars
    stable_after <- def$stable_after
    if (is.null(stable_after)) stable_after <- required_bars
    if (is.null(required_bars) || is.null(stable_after)) {
      return(NULL)
    }
    data.frame(
      feature_id = feature_id,
      required_bars = as.integer(required_bars),
      stable_after = as.integer(stable_after),
      stringsAsFactors = FALSE
    )
  })
  rows <- Filter(Negate(is.null), rows)
  if (length(rows) == 0L) {
    return(tibble::tibble(feature_id = character(), required_bars = integer(), stable_after = integer()))
  }
  tibble::as_tibble(do.call(rbind, rows))
}

ledgr_backtest_bar_counts <- function(bt, con = NULL) {
  cfg <- bt$config
  instrument_ids <- cfg$universe$instrument_ids
  if (!is.character(instrument_ids) || length(instrument_ids) == 0L) {
    return(tibble::tibble(instrument_id = character(), available_bars = integer()))
  }

  snapshot_id <- cfg$data$snapshot_id
  snapshot_db_path <- ledgr_snapshot_db_path_from_config(cfg, bt$db_path)
  use_existing <- !is.null(con) && DBI::dbIsValid(con)
  query_con <- con
  close_query <- function() invisible(FALSE)
  if (!isTRUE(use_existing)) {
    opened <- ledgr_open_duckdb_with_retry(bt$db_path)
    query_con <- opened$con
    close_query <- function() {
      suppressWarnings(try(DBI::dbDisconnect(opened$con, shutdown = TRUE), silent = TRUE))
      suppressWarnings(try(duckdb::duckdb_shutdown(opened$drv), silent = TRUE))
      invisible(TRUE)
    }
  }
  on.exit(close_query(), add = TRUE)

  start_iso <- ledgr_normalize_ts_utc(cfg$backtest$start_ts_utc)
  end_iso <- ledgr_normalize_ts_utc(cfg$backtest$end_ts_utc)
  start_str <- sub("Z$", "", sub("T", " ", start_iso))
  end_str <- sub("Z$", "", sub("T", " ", end_iso))
  ids_sql <- paste(DBI::dbQuoteString(query_con, instrument_ids), collapse = ", ")

  if (!is.null(snapshot_id) && is.character(snapshot_id) && length(snapshot_id) == 1L && !is.na(snapshot_id) && nzchar(snapshot_id)) {
    ledgr_prepare_snapshot_source_tables(query_con, snapshot_db_path, bt$db_path)
    ledgr_prepare_snapshot_runtime_views(
      query_con,
      snapshot_id = snapshot_id,
      instrument_ids = instrument_ids,
      start_ts_utc = cfg$backtest$start_ts_utc,
      end_ts_utc = cfg$backtest$end_ts_utc
    )
  }
  counts <- DBI::dbGetQuery(
    query_con,
    paste0(
      "SELECT instrument_id, COUNT(*) AS available_bars ",
      "FROM bars ",
      "WHERE instrument_id IN (", ids_sql, ") ",
      "AND ts_utc >= CAST(? AS TIMESTAMP) AND ts_utc <= CAST(? AS TIMESTAMP) ",
      "GROUP BY instrument_id"
    ),
    params = list(start_str, end_str)
  )

  out <- data.frame(instrument_id = instrument_ids, stringsAsFactors = FALSE)
  idx <- match(out$instrument_id, as.character(counts$instrument_id))
  out$available_bars <- ifelse(is.na(idx), 0L, as.integer(counts$available_bars[idx]))
  tibble::as_tibble(out)
}

ledgr_backtest_warmup_diagnostics <- function(bt, con = NULL) {
  if (!inherits(bt, "ledgr_backtest")) {
    rlang::abort("`bt` must be a ledgr_backtest object.", class = "ledgr_invalid_backtest")
  }
  feature_contracts <- ledgr_feature_contracts_from_backtest_config(bt)
  if (nrow(feature_contracts) == 0L) {
    return(ledgr_empty_warmup_diagnostics())
  }
  opened <- NULL
  query_con <- con
  if (is.null(query_con) || !DBI::dbIsValid(query_con)) {
    opened <- ledgr_backtest_read_connection(bt)
    query_con <- opened$con
    on.exit(opened$close(), add = TRUE)
  }
  bar_counts <- ledgr_backtest_bar_counts(bt, con = query_con)
  ledgr_warmup_diagnostics_from_counts(feature_contracts, bar_counts)
}

ledgr_print_warmup_diagnostics <- function(diagnostics, max_rows = 5L) {
  if (!inherits(diagnostics, "ledgr_warmup_diagnostics") || nrow(diagnostics) == 0L) {
    return(invisible(FALSE))
  }
  cat("\nWarmup Diagnostics:\n")
  shown <- utils::head(diagnostics, max_rows)
  for (i in seq_len(nrow(shown))) {
    stable_note <- ""
    if (!identical(shown$stable_after[[i]], shown$required_bars[[i]])) {
      stable_note <- sprintf(", stable after %d", shown$stable_after[[i]])
    }
    cat(sprintf(
      "  Feature `%s` for `%s` never became usable: required bars %d%s, available bars %d.\n",
      shown$feature_id[[i]],
      shown$instrument_id[[i]],
      shown$required_bars[[i]],
      stable_note,
      shown$available_bars[[i]]
    ))
  }
  remaining <- nrow(diagnostics) - nrow(shown)
  if (remaining > 0L) {
    cat(sprintf("  ... %d more warmup diagnostics omitted.\n", remaining))
  }
  invisible(TRUE)
}

#' Extract tidy backtest tables
#'
#' @param x A `ledgr_backtest` object.
#' @param what Result table to extract: `"equity"`, `"trades"`, `"fills"`, or
#'   `"ledger"`.
#' @param ... Unused.
#' @param type Deprecated alias for `what`.
#' @return A tibble with the requested result table.
#' @details
#' `what = "fills"` returns execution fill rows, including opening and closing
#' actions. Fill rows include execution `side`, absolute `qty`, `price`, `fee`,
#' derived `action`, and `realized_pnl`. Opening fills have `action = "OPEN"`
#' and do not count as closed trades.
#'
#' `what = "trades"` returns closed trade rows only. This table has the same
#' zero-row schema as fills, but only rows with `action = "CLOSE"` are present.
#' It is the source for `n_trades`, `win_rate`, and `avg_trade`.
#'
#' `what = "equity"` returns the public equity curve used for return,
#' drawdown, volatility, and exposure metrics. Open positions can affect equity
#' through `positions_value` even when there are zero closed trade rows.
#'
#' `ledgr_results()` does not support `what = "metrics"`. Metrics are derived
#' from the public result tables; use `summary(bt)` for printed interpretation
#' or `ledgr_compute_metrics(bt)` for a named list.
#'
#' @section Articles:
#' Metrics and accounting:
#' `vignette("metrics-and-accounting", package = "ledgr")`
#' `system.file("doc", "metrics-and-accounting.html", package = "ledgr")`
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
  what <- ledgr_match_result_table(what)
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
#' actions. Fill rows include execution `side`, absolute `qty`, `price`, `fee`,
#' derived `action`, and `realized_pnl`. Opening fills have `action = "OPEN"`
#' and do not count as closed trades.
#'
#' `what = "trades"` returns closed trade rows only. This table has the same
#' zero-row schema as fills, but only rows with `action = "CLOSE"` are present.
#' It is the source for `n_trades`, `win_rate`, and `avg_trade`.
#'
#' `what = "equity"` returns the public equity curve used for return,
#' drawdown, volatility, and exposure metrics. Open positions can affect equity
#' through `positions_value` even when there are zero closed trade rows.
#'
#' `ledgr_results()` does not support `what = "metrics"`. Metrics are derived
#' from the public result tables; use `summary(bt)` for printed interpretation
#' or `ledgr_compute_metrics(bt)` for a named list.
#'
#' @section Articles:
#' Metrics and accounting:
#' `vignette("metrics-and-accounting", package = "ledgr")`
#' `system.file("doc", "metrics-and-accounting.html", package = "ledgr")`
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
  what <- ledgr_match_result_table(what)
  ledgr_result_table(tibble::as_tibble(bt, what = what), what = what)
}

ledgr_match_result_table <- function(what) {
  choices <- c("equity", "fills", "trades", "ledger")
  if (length(what) > 1L) {
    return(match.arg(what, choices))
  }
  if (!is.character(what) || length(what) != 1L || is.na(what) || !nzchar(what)) {
    rlang::abort("`what` must be one of: equity, fills, trades, ledger.", class = "ledgr_invalid_result_table")
  }
  if (identical(what, "metrics")) {
    rlang::abort(
      "`ledgr_results()` does not support `what = \"metrics\"`. Use `summary(bt)` for printed interpretation or `ledgr_compute_metrics(bt)` for a named list.",
      class = "ledgr_invalid_result_table"
    )
  }
  if (!(what %in% choices)) {
    rlang::abort(
      sprintf("Unknown ledgr result table `%s`. Use one of: %s.", what, paste(choices, collapse = ", ")),
      class = "ledgr_invalid_result_table"
    )
  }
  what
}
