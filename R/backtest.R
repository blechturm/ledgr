ledgr_run_config <- function(config,
                             run_id = NULL,
                             metric_context = NULL,
                             history_substrate = NULL) {
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
    metric_context = metric_context,
    history_substrate = history_substrate
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
#'   seeds R's RNG with it at fold entry under the kind
#'   `Mersenne-Twister`/`Inversion`/`Rejection`, derives `ctx$pulse_seed` from
#'   it by pulse-seed rule v2, and stores the seed and
#'   `engine.pulse_seed_rule` in run identity. With `NULL`, `ctx$pulse_seed`
#'   is `NULL` and ledgr sets neither seed nor kind. For every value, your RNG
#'   kind and `.Random.seed` are restored when the call returns or fails; the
#'   reproducibility article (see Articles) states the boundary.
#' @param compiled_accounting_model Optional accounting accelerator selector.
#'   `NULL` uses the canonical R accounting path. `"spot_fifo"` is a scoped
#'   spot-asset FIFO accelerator for memory-backed sweep execution; committed
#'   durable runs currently fail closed because durable compiled integration is
#'   deferred.
#' @return A `ledgr_backtest` object.
#' @section Early exit:
#' If a run stops by an error or an interrupt after its row was created, for
#' example during feature computation or under an R time limit, its status is
#' recorded `FAILED` with the reason in `error_msg`, and the condition still
#' reaches the caller. Calling `ledgr_run()` again with the same experiment and
#' `run_id` resumes it. The `ledgr.interrupt` soft stop instead returns normally
#' and leaves the run `RUNNING`.
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
#'
#' Seeds and random state:
#' `vignette("reproducibility", package = "ledgr")`
#' `system.file("doc", "reproducibility.html", package = "ledgr")`
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
  ledgr_rng_force_args()
  ledgr_rng_preserve_caller(ledgr_run_impl(
    exp = exp,
    params = params,
    feature_params = feature_params,
    run_id = run_id,
    seed = seed,
    compiled_accounting_model = compiled_accounting_model
  ))
}

ledgr_run_impl <- function(exp,
                           params,
                           feature_params,
                           run_id,
                           seed,
                           compiled_accounting_model) {
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
                                 window = NULL,
                                 history_substrate = NULL) {
  if (!inherits(exp, "ledgr_experiment")) {
    rlang::abort("`exp` must be a ledgr_experiment object.", class = "ledgr_invalid_args")
  }
  release <- ledgr_snapshot_hold(exp$snapshot)
  on.exit(release(), add = TRUE)
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
  final_execution <- window$final_execution_ts_utc
  if (is.null(window)) {
    # The recorded start is the clamped scoring start (LDG-3004): an opening
    # dated before the sealed start begins at the sealed start.
    start <- ledgr_experiment_scoring_start(exp, exp$snapshot$metadata$start_date) %||% exp$snapshot$metadata$start_date
    end <- exp$snapshot$metadata$end_date
  } else {
    start <- window$scoring_start_utc
    end <- window$scoring_end_utc
  }
  if (is.null(start) || is.null(end) || anyNA(c(start, end))) {
    rlang::abort("Experiment snapshot must provide start/end metadata, or opening$date must provide start.", class = "ledgr_invalid_experiment")
  }

  if (is.null(history_substrate)) {
    history_substrate <- ledgr_history_substrate_for_experiment(
      exp,
      meta = ledgr_precompute_snapshot_meta(exp$snapshot),
      end = end,
      coverage_start = start
    )
  }

  config <- ledgr_config(
    snapshot = exp$snapshot,
    universe = exp$universe,
    strategy = exp$strategy,
    strategy_params = params_info$value,
    feature_params = feature_params_info$value,
    backtest = ledgr_backtest_config(
      start = start,
      end = end,
      initial_cash = exp$opening$cash,
      final_execution = final_execution
    ),
    features = feature_result$features,
    alias_map = feature_result$alias_map,
    alias_identity_map = feature_result$alias_identity_map,
    execution_mode = exp$execution_mode,
    timing_model = exp$timing_model,
    cost_model_hash = exp$cost_model_hash,
    cost_plan_json = exp$cost_plan_json,
    risk_chain_hash = exp$risk_chain_hash,
    risk_plan_json = exp$risk_plan_json,
    control = exp$control %||% list(),
    db_path = exp$snapshot$db_path,
    run_id = run_id,
    opening = exp$opening,
    seed = seed,
    compiled_accounting_model = compiled_accounting_model,
    availability = exp$availability,
    universe_rule = exp$universe_rule,
    valuation_policy = exp$valuation_policy,
    corporate_action_policy = exp$corporate_action_policy,
    history_policy = exp$history_policy,
    price_basis = exp$data_identity$price_basis,
    snapshot_hash = exp$snapshot_hash %||% ledgr_snapshot_stored_hash(exp$snapshot)
  )

  result <- ledgr_run_config(
    config,
    metric_context = exp$metric_context,
    history_substrate = history_substrate
  )
  new_ledgr_backtest(
    run_id = result$run_id,
    db_path = result$db_path,
    config = config
  )
}
