#' Run a backtest (v0.1.2)
#'
#' Thin wrapper around the canonical engine path.
#'
#' @param snapshot A `ledgr_snapshot` object, or a data frame for the data-first
#'   convenience path.
#' @param strategy Strategy function using `function(ctx, params)`, or a
#'   configured strategy list.
#' @param strategy_params JSON-safe list passed to `function(ctx, params)`
#'   strategies and stored as part of run provenance.
#' @param universe Character vector of instrument IDs. If `NULL`, it is inferred
#'   from the snapshot or data frame.
#' @param start Start timestamp (NULL = snapshot start).
#' @param end End timestamp (NULL = snapshot end).
#' @param initial_cash Starting capital. Must be a finite numeric scalar > 0.
#' @param features List of ledgr indicator or indicator-bundle definitions
#'   (optional). Bundles flatten into ordinary indicators before runtime.
#' @param timing_model Timing model object. Defaults to
#'   `ledgr_timing_next_open()`.
#' @param cost_model Required ledgr cost model object. Use `ledgr_cost_zero()`
#'   for explicit zero-cost execution.
#' @param risk_chain Target-risk chain object. Defaults to
#'   `ledgr_risk_none()` for explicit no-risk execution.
#' @param fill_model Legacy v0.1.8 fill model argument. Supplying it now fails
#'   with `ledgr_legacy_fill_model_shape`; use `timing_model` plus
#'   `cost_model`.
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
#' Strategies return target holdings. The default timing model is `next_open`: a
#' target decided at pulse `t` is filled at the next available bar. Targets on
#' the final pulse therefore cannot be filled unless another bar exists after
#' `end`.
#'
#' Cost models are explicit. Use `ledgr_cost_zero()` for no-cost execution.
#' `ledgr_cost_spread_bps()` treats `spread_bps` as a quoted bid/ask spread:
#' buys cross half the spread above the reference price and sells cross half the
#' spread below it, so a round trip crosses approximately `spread_bps` basis
#' points before explicit fees.
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
#' bt <- ledgr_backtest(
#'   data = bars,
#'   strategy = strategy,
#'   initial_cash = 1000,
#'   cost_model = ledgr_cost_zero()
#' )
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
                           timing_model = ledgr_timing_next_open(),
                           cost_model,
                           risk_chain = ledgr_risk_none(),
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

  if (!is.null(fill_model)) {
    ledgr_legacy_fill_model_abort()
  }
  if (missing(cost_model) || is.null(cost_model)) {
    ledgr_cost_model_unspecified()
  }
  timing_model <- ledgr_experiment_normalize_timing_model(timing_model)
  cost_model <- ledgr_experiment_normalize_cost_model(cost_model)
  risk_chain <- ledgr_experiment_normalize_risk_chain(risk_chain)
  cost_model_hash <- ledgr_cost_model_hash(cost_model)
  cost_plan_json <- ledgr_cost_plan_json(cost_model)
  risk_chain_hash <- ledgr_risk_chain_hash(risk_chain)
  risk_plan_json <- ledgr_risk_plan_json(risk_chain)

  features <- ledgr_flatten_feature_list(features, context = "`features`")

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
    timing_model = timing_model,
    cost_model_hash = cost_model_hash,
    cost_plan_json = cost_plan_json,
    risk_chain_hash = risk_chain_hash,
    risk_plan_json = risk_plan_json,
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

ledgr_run_config <- function(config, run_id = NULL, metric_context = NULL) {
  control <- list()
  if (is.list(config) &&
    is.list(config$engine) &&
    is.list(config$engine$control)) {
    control <- config$engine$control
  }
  ledgr_run_fold(
    config = config,
    run_id = run_id,
    control = control,
    metric_context = metric_context
  )
}

#' Run a ledgr experiment
#'
#' `ledgr_run()` is the public single-run API for the v0.1.7
#' experiment-first workflow. It evaluates run-time feature definitions,
#' builds the canonical backtest config, and delegates to the shared runner.
#'
#' @param exp A `ledgr_experiment` object.
#' @param params JSON-safe list passed to `function(ctx, params)` strategy.
#' @param feature_params JSON-safe list used to resolve parameterized feature
#'   declarations before execution.
#' @param run_id Optional run identifier.
#' @param seed Optional integer-like execution seed. When non-`NULL`, ledgr
#'   applies it at fold entry and stores it in run identity.
#' @param compiled_accounting_model Optional accounting accelerator selector.
#'   `NULL` uses the canonical R accounting path. `"spot_fifo"` is a scoped
#'   spot-asset FIFO accelerator for memory-backed sweep execution; committed
#'   durable runs currently fail closed because durable compiled integration is
#'   deferred.
#' @return A `ledgr_backtest` object.
#' @section Identity:
#' Run identity fields, including `config_hash`, `feature_set_hash`,
#' `cost_model_hash`, `cost_plan_json`, `risk_chain_hash`, and
#' `risk_plan_json`, are summarized in
#' [ledgr_identity_fields].
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
#' exp <- ledgr_experiment(snapshot, strategy, cost_model = ledgr_cost_zero())
#' bt <- ledgr_run(exp, params = list(qty = 1), run_id = "example-run")
#' close(bt)
#' ledgr_snapshot_close(snapshot)
#' @export
ledgr_run <- function(exp,
                      params = list(),
                      feature_params = list(),
                      run_id = NULL,
                      seed = NULL,
                      compiled_accounting_model = NULL) {
  if (!inherits(exp, "ledgr_experiment")) {
    rlang::abort("`exp` must be a ledgr_experiment object.", class = "ledgr_invalid_args")
  }
  if (!is.list(params) || is.data.frame(params)) {
    rlang::abort("`params` must be a list. Use `params = list()` when the strategy has no parameters.", class = "ledgr_invalid_args")
  }
  if (!is.list(feature_params) || is.data.frame(feature_params)) {
    rlang::abort("`feature_params` must be a list. Use `feature_params = list()` when features have no parameters.", class = "ledgr_invalid_args")
  }
  compiled_accounting_model <- ledgr_public_compiled_accounting_model(compiled_accounting_model)
  ledgr_run_experiment(
    exp = exp,
    params = params,
    feature_params = feature_params,
    run_id = run_id,
    seed = seed,
    compiled_accounting_model = compiled_accounting_model
  )
}

ledgr_run_experiment <- function(exp,
                                 params = list(),
                                 feature_params = list(),
                                 run_id = NULL,
                                 seed = NULL,
                                 compiled_accounting_model = NULL,
                                 window = NULL) {
  if (!inherits(exp, "ledgr_experiment")) {
    rlang::abort("`exp` must be a ledgr_experiment object.", class = "ledgr_invalid_args")
  }
  compiled_accounting_model <- ledgr_public_compiled_accounting_model(compiled_accounting_model)
  if (isTRUE(exp$availability$active) && identical(compiled_accounting_model, "spot_fifo")) {
    rlang::abort(
      "Compiled spot-FIFO execution is not supported for availability-aware experiments.",
      class = c("ledgr_compiled_availability_unsupported", "ledgr_invalid_args")
    )
  }
  if (identical(compiled_accounting_model, "spot_fifo")) {
    ledgr_compiled_spot_fifo_unavailable_error(
      paste0(
        "`ledgr_run(..., compiled_accounting_model = \"spot_fifo\")` is not ",
        "available for committed durable runs yet. Use `ledgr_sweep(..., ",
        "compiled_accounting_model = \"spot_fifo\")` for the current public ",
        "ephemeral opt-in. Default execution (compiled_accounting_model = NULL) ",
        "uses canonical R and works everywhere."
      )
    )
  }
  params_info <- ledgr_strategy_params_info(params)
  feature_params_info <- ledgr_strategy_params_info(feature_params)
  if (!is.null(run_id) && (!is.character(run_id) || length(run_id) != 1L || is.na(run_id) || !nzchar(run_id))) {
    rlang::abort("`run_id` must be NULL or a non-empty character scalar.", class = "ledgr_invalid_args")
  }
  feature_result <- ledgr_experiment_materialize_feature_result(
    exp,
    params = params_info$value,
    feature_params = feature_params_info$value
  )
  window <- ledgr_experiment_window_resolve(exp, window)
  if (is.null(window)) {
    start <- if (!is.null(exp$opening$date)) exp$opening$date else exp$snapshot$metadata$start_date
    end <- exp$snapshot$metadata$end_date
  } else {
    # Window-driven bar fetch uses scoring_start_utc here. Hydration-range bar
    # fetch and slice-aware feature precompute validation land in LDG-2615.
    start <- window$scoring_start_utc
    end <- window$scoring_end_utc
  }
  if (is.null(start) || is.null(end) || anyNA(c(start, end))) {
    rlang::abort("Experiment snapshot must provide start/end metadata, or opening$date must provide start.", class = "ledgr_invalid_experiment")
  }

  config <- ledgr_config(
    snapshot = exp$snapshot,
    universe = exp$universe,
    strategy = exp$strategy,
    strategy_params = params_info$value,
    feature_params = feature_params_info$value,
    backtest = ledgr_backtest_config(start = start, end = end, initial_cash = exp$opening$cash),
    features = feature_result$features,
    alias_map = feature_result$alias_map,
    alias_identity_map = feature_result$alias_identity_map,
    persist_features = exp$persist_features,
    execution_mode = exp$execution_mode,
    timing_model = exp$timing_model,
    cost_model_hash = exp$cost_model_hash,
    cost_plan_json = exp$cost_plan_json,
    risk_chain_hash = exp$risk_chain_hash,
    risk_plan_json = exp$risk_plan_json,
    db_path = exp$snapshot$db_path,
    run_id = run_id,
    opening = exp$opening,
    seed = seed,
    compiled_accounting_model = compiled_accounting_model,
    availability = exp$availability,
    universe_rule = exp$universe_rule,
    valuation_policy = exp$valuation_policy
  )

  result <- ledgr_run_config(config, metric_context = exp$metric_context)
  new_ledgr_backtest(
    run_id = result$run_id,
    db_path = result$db_path,
    config = config
  )
}
