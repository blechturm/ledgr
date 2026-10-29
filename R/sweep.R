.ledgr_sweep_id_state <- new.env(parent = emptyenv())
.ledgr_sweep_id_state$counter <- 0L

#' Run a parameter sweep
#'
#' `ledgr_sweep()` evaluates a rectangular strategy grid or a composed ledgr
#' grid against a `ledgr_experiment`
#' without writing candidate runs to the experiment store. Sweep is an
#' exploratory surface: it returns candidate summaries, does not rank candidates
#' automatically, and does not create committed run artifacts.
#'
#' @param exp A `ledgr_experiment`.
#' @param param_grid An ordinary rectangular data frame, a
#'   `ledgr_strategy_grid`, or a `ledgr_executable_grid`.
#' @param precomputed_features Optional `ledgr_precomputed_features` object.
#' @param retain A `ledgr_sweep_retention` object. The default keeps the
#'   current scalar-only sweep output. Retention metadata is not execution
#'   identity.
#' @param seed Optional integer-like master seed. When supplied, each candidate
#'   receives a deterministic derived execution seed, used as in
#'   [ledgr_run()]. A strategy that draws through
#'   `withr::with_seed(ctx$pulse_seed, ...)` gets the same results for any
#'   `workers` value. The result and each candidate's provenance record the
#'   pulse-seed rule as `seed_contract = "ledgr_seed_v2"`.
#' @param stop_on_error Logical. When `FALSE`, candidate-level execution errors
#'   are captured as failed rows; when `TRUE`, they are rethrown.
#' @param workers Whole-number worker count. The default `1` uses the
#'   sequential reference path. Values greater than `1` dispatch candidates
#'   through the optional `mirai` backend.
#' @param worker_packages Optional character vector of packages to attach on
#'   parallel workers for unqualified package calls in strategy code.
#' @param compiled_accounting_model Optional accounting accelerator selector.
#'   `NULL` uses the canonical R accounting path. `"spot_fifo"` opts into the
#'   scoped spot-asset FIFO accelerator for memory-backed sweep candidates.
#' @return A `ledgr_sweep_results` tibble. Each row keeps its `status` and
#'   `completion_json`; the columns directly after `completion_json` are
#'   derived from it: `stop_reason`, `affected_instrument_ids`, and the
#'   valuation flags `valuation_state`, `frozen_instrument_sessions`,
#'   `max_frozen_equity_weight`, `frozen_at_end_value`, and
#'   `assumed_terminal_outcomes` (`NA` without availability evidence). Print
#'   reports attempted, done, incomplete, and failed counts. Only `DONE` rows
#'   enter ranking, filtering, promotion, and validation panels.
#' @details
#' For larger grids, precompute shared feature payloads with
#' [ledgr_precompute_features()]. When a grid has more than 20 combinations and
#' `precomputed_features = NULL`, ledgr warns because feature computation may be
#' repeated per candidate.
#'
#' The result carries row-level `execution_seed` and `provenance`. Provenance
#' records what ran, including the candidate feature-set hash; it does not
#' prove that parameter selection was out-of-sample. The normal discipline is to
#' sweep on a train snapshot, select a candidate with [ledgr_candidate()], and
#' evaluate the locked params on a held-out test snapshot with [ledgr_promote()]
#' or [ledgr_run()]. Same-snapshot promotion is useful for audit and replay, but
#' remains in-sample.
#'
#' Sweep candidate metrics use the experiment's metric context. The returned
#' table has exactly one sweep-level metric context, available with
#' `ledgr_metric_context(results)`, and promotion context records that source
#' sweep context separately from the committed run's own metric context.
#' Candidate warnings, including `LEDGR_LAST_BAR_NO_FILL`, are row-level
#' diagnostics. Inspect them before promotion; committed runs expose their own
#' result tables and promotion context.
#' Hash fields in sweep provenance and reproduction keys are summarized in
#' [ledgr_identity_fields].
#'
#' Failed candidates are retained as rows when `stop_on_error = FALSE`. Contract
#' errors such as invalid grids, invalid precomputed feature payloads, and Tier 3
#' strategy preflight failures still abort. Feature factories consume the
#' strategy-parameter namespace. Grids with separate `feature_params` require
#' active aliases through
#' `ledgr_feature_map()`. Failed rows can be inspected with
#' `ledgr_candidate(..., allow_failed = TRUE)`, but [ledgr_promote()] rejects
#' failed candidates. When `stop_on_error = TRUE` rethrows a strategy failure,
#' assert with `inherits(e, "ledgr_strategy_error")` rather than exact
#' class-vector equality.
#'
#' Parallel sweep interruption is discard-all in v0.1.8.8. If a parallel sweep
#' is interrupted before all workers return, ledgr stops the worker backend and
#' throws `ledgr_parallel_sweep_interrupted`; no partially promotable sweep
#' result is returned. Partial-result recovery is intentionally deferred.
#'
#' Current sweep mode intentionally does not ship automatic ranking,
#' `ledgr_tune()`, per-fold walk-forward PBO, CPCV, DSR, risk-layer insertion,
#' cost-grid composition, paper/live adapters, intraday-specific support, or
#' full per-candidate committed-run artifacts. Saved sweeps are compact
#' candidate evidence, not batches of committed runs.
#'
#' @section Articles:
#' Exploratory sweeps and promotion:
#' `vignette("sweeps", package = "ledgr")`
#' `system.file("doc", "sweeps.html", package = "ledgr")`
#' Selection-integrity diagnostics:
#' `vignette("selection-integrity", package = "ledgr")`
#' `system.file("doc", "selection-integrity.html", package = "ledgr")`
#' @export
ledgr_sweep <- function(exp,
                        param_grid,
                        precomputed_features = NULL,
                        retain = ledgr_sweep_retention(),
                        seed = NULL,
                        stop_on_error = FALSE,
                        workers = 1L,
                        worker_packages = NULL,
                        compiled_accounting_model = NULL) {
  ledgr_rng_force_args()
  ledgr_rng_preserve_caller(ledgr_sweep_impl(
    exp = exp,
    param_grid = param_grid,
    precomputed_features = precomputed_features,
    retain = retain,
    seed = seed,
    stop_on_error = stop_on_error,
    workers = workers,
    worker_packages = worker_packages,
    compiled_accounting_model = compiled_accounting_model,
    window = NULL
  ))
}

ledgr_sweep_window <- function(exp,
                               param_grid,
                               window,
                               precomputed_features = NULL,
                               retain = ledgr_sweep_retention(),
                               seed = NULL,
                               stop_on_error = FALSE,
                               workers = 1L,
                               worker_packages = NULL,
                               compiled_accounting_model = NULL,
                               execution_seed_resolver = NULL,
                               history_substrate = NULL) {
  window <- ledgr_experiment_window_resolve(exp, window)
  ledgr_sweep_impl(
    exp = exp,
    param_grid = param_grid,
    precomputed_features = precomputed_features,
    retain = retain,
    seed = seed,
    stop_on_error = stop_on_error,
    workers = workers,
    worker_packages = worker_packages,
    compiled_accounting_model = compiled_accounting_model,
    window = window,
    execution_seed_resolver = execution_seed_resolver,
    history_substrate = history_substrate
  )
}

ledgr_sweep_impl <- function(exp,
                             param_grid,
                             precomputed_features = NULL,
                             retain = ledgr_sweep_retention(),
                             seed = NULL,
                             stop_on_error = FALSE,
                             workers = 1L,
                             worker_packages = NULL,
                             compiled_accounting_model = NULL,
                             window = NULL,
                             execution_seed_resolver = NULL,
                             history_substrate = NULL) {
  if (!inherits(exp, "ledgr_experiment")) {
    rlang::abort("`exp` must be a ledgr_experiment object.", class = "ledgr_invalid_args")
  }
  param_grid <- ledgr_executable_grid_normalize(param_grid)
  release <- ledgr_snapshot_hold(exp$snapshot)
  on.exit(release(), add = TRUE)
  if (!is.logical(stop_on_error) || length(stop_on_error) != 1L || is.na(stop_on_error)) {
    rlang::abort("`stop_on_error` must be TRUE or FALSE.", class = "ledgr_invalid_args")
  }
  window <- ledgr_experiment_window_resolve(exp, window)
  retain <- ledgr_sweep_retention_normalize(retain)
  workers <- ledgr_parallel_workers_normalize(workers)
  seed <- ledgr_seed_normalize(seed)
  compiled_accounting_model <- ledgr_public_compiled_accounting_model(compiled_accounting_model)
  availability_active <- isTRUE(exp$availability$active)
  if (availability_active && identical(compiled_accounting_model, "spot_fifo")) {
    rlang::abort(
      "Compiled spot-FIFO execution is unavailable for availability-aware sweeps.",
      class = c("ledgr_compiled_availability_unsupported", "ledgr_invalid_args")
    )
  }
  if (!is.null(precomputed_features) &&
    !identical(availability_active, !is.null(precomputed_features$history_axis))) {
    rlang::abort(
      if (availability_active) {
        "Availability-aware sweeps do not accept a dense precomputed feature payload."
      } else {
        "Dense sweeps do not accept an availability-aware precomputed feature payload."
      },
      class = c("ledgr_precomputed_feature_mismatch", "ledgr_invalid_args")
    )
  }
  if (!is.null(execution_seed_resolver) && !is.function(execution_seed_resolver)) {
    rlang::abort("`execution_seed_resolver` must be NULL or a function.", class = "ledgr_invalid_args")
  }

  preflight <- ledgr_strategy_preflight(exp$strategy)
  if (!isTRUE(preflight$allowed)) {
    ledgr_abort_strategy_preflight(preflight)
  }
  if (workers > 1L) {
    ledgr_abort_strategy_ambient_rng_for_parallel(preflight)
  }
  worker_setup <- ledgr_parallel_worker_setup(
    workers = workers,
    preflight = preflight,
    worker_packages = worker_packages,
    dry_run = workers <= 1L
  )
  if (isTRUE(worker_setup$initialized)) {
    on.exit(ledgr_parallel_mirai_stop(), add = TRUE)
  }
  ledgr_validate_feature_factory_grid(exp, param_grid)

  ledgr_warn_large_grid_without_precomputed_features(param_grid, precomputed_features)
  if (!is.null(precomputed_features)) {
    ledgr_validate_precomputed_features(
      precomputed = precomputed_features,
      exp = exp,
      param_grid = param_grid,
      window = window,
      resolve_features = TRUE
    )
  }

  ledgr_snapshot_ensure_handle(exp$snapshot)
  meta <- ledgr_precompute_snapshot_meta(exp$snapshot)
  range <- if (is.null(window)) {
    ledgr_precompute_scoring_range(meta, start = ledgr_experiment_scoring_start(exp, meta$start))
  } else {
    ledgr_precompute_scoring_range(
      meta,
      start = window$scoring_start_utc,
      end = window$scoring_end_utc
    )
  }
  bars_by_id <- list()
  availability_config <- NULL
  execution_opportunities_posix <- NULL
  history_axis <- NULL
  snapshot_con <- get_connection(exp$snapshot)
  corporate_action_rows <- ledgr_corporate_action_rows(
    snapshot_con,
    exp$snapshot$snapshot_id
  )
  if (availability_active) {
    availability_config <- ledgr_sweep_availability_config(exp)
    if (is.null(history_substrate)) {
      history_substrate <- ledgr_history_substrate_for_experiment(
        exp, meta,
        end = range$scoring_end
      )
    } else {
      ledgr_history_substrate_validate_owner(
        history_substrate,
        snapshot_hash = meta$snapshot_hash,
        history_policy = availability_config$history_policy,
        instrument_ids = exp$universe,
        required_start = meta$start,
        required_end = range$scoring_end
      )
    }
    provider_shell <- list(sessions = history_substrate$sessions)
    ledgr_availability_require_coverage(provider_shell, ledgr_snapshot_bar_range(snapshot_con, exp$snapshot$snapshot_id, range$scoring_start, range$scoring_end))
    history_axis <- history_substrate$axis
    calendar <- ledgr_availability_calendar(
      provider_shell, range$scoring_start, range$scoring_end
    )
    pulses_posix <- calendar$pulses_posix
    pulses_iso <- calendar$pulses_iso
    execution_opportunities_posix <- calendar$execution_opportunities_posix
  } else {
    bars_by_id <- ledgr_precompute_fetch_bars(
      exp$snapshot,
      exp$universe,
      range$scoring_start,
      range$scoring_end
    )
    bars_by_id <- ledgr_sweep_normalize_bars_by_id(
      bars_by_id, exp$universe
    )
    ledgr_precompute_validate_static_coverage(bars_by_id, exp$universe)
    pulses_posix <- as.POSIXct(bars_by_id[[exp$universe[[1L]]]]$ts_utc, tz = "UTC")
    pulses_iso <- format(pulses_posix, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  }
  # Bars, pulses and feature state all start at the scoring start, as in a
  # durable run. Next-bar fills need at least two scoring pulses.
  if (length(pulses_posix) < 2L) {
    rlang::abort(
      paste0(
        "Execution window must contain at least two pulses for next-bar ",
        "fill semantics."
      ),
      class = c("ledgr_run_window_too_short", "ledgr_invalid_config")
    )
  }

  if (is.null(precomputed_features)) {
    resolved <- ledgr_resolve_feature_candidates(exp, param_grid, stop_on_error = FALSE)
    unique_defs <- ledgr_precompute_unique_feature_defs(resolved$candidates)
    payload <- if (availability_active) {
      ledgr_history_precompute_payload(
        unique_defs,
        history_substrate,
        calculation_start = ledgr_history_calculation_start(history_substrate),
        calculation_end = range$scoring_end
      )
    } else {
      ledgr_precompute_payload(unique_defs, bars_by_id)
    }
    runtime_projection <- ledgr_projection_from_payload(
      payload = payload,
      universe = exp$universe,
      pulses_posix = if (availability_active) history_axis else pulses_posix,
      feature_engine_version = ledgr_feature_engine_version(availability_active),
      alias_index = NULL
    )
    # The projection holds every value the sweep reads; release the payload
    # at its last read so the two are never both kept (audit F01).
    rm(payload)
    # Cut 16 decision (26), amended: collect before staging two or more workers.
    if (workers > 1L) invisible(gc(verbose = FALSE))
  } else if (availability_active) {
    # An availability payload is reused only on the exact causal axis, cutoff,
    # calculation start and policy this sweep prepares; candidates keep their
    # full resolved definitions.
    ledgr_precompute_validate_history_axis(
      precomputed_features,
      ledgr_precompute_history_axis(
        history_substrate,
        ledgr_history_calculation_start(history_substrate),
        range$scoring_end
      )
    )
    resolved <- ledgr_resolve_feature_candidates(exp, param_grid, stop_on_error = FALSE)
    runtime_projection <- ledgr_projection_slice(
      precomputed_features$projection,
      history_axis
    )
  } else {
    resolved <- ledgr_sweep_resolved_from_precomputed(precomputed_features, param_grid)
    runtime_projection <- precomputed_features$projection
    if (!is.null(runtime_projection)) {
      runtime_projection <- ledgr_projection_slice(
        runtime_projection,
        if (availability_active) history_axis else pulses_posix
      )
    } else {
      runtime_projection <- ledgr_projection_from_payload(
        payload = precomputed_features$payload,
        universe = exp$universe,
        pulses_posix = if (availability_active) history_axis else pulses_posix,
        feature_engine_version = precomputed_features$feature_engine_version,
        alias_index = NULL
      )
    }
  }
  if (availability_active) {
    history_substrate <- ledgr_history_substrate_bind_features(
      history_substrate,
      runtime_projection
    )
  }
  bars_mat <- if (availability_active) {
    NULL
  } else {
    ledgr_sweep_bars_matrix(bars_by_id, exp$universe)
  }
  static_bars_views <- if (availability_active) {
    NULL
  } else {
    ledgr_bars_pulse_views(
      bars_mat = bars_mat,
      instrument_ids = exp$universe,
      pulses_posix = pulses_posix
    )
  }
  if (availability_active) bars_by_id <- list()
  metric_context <- ledgr_metric_context_resolve(exp$metric_context)
  metric_kernel <- ledgr_metric_kernel(context = metric_context, pulses = pulses_posix)

  sweep_id <- ledgr_generate_sweep_id()
  rows <- vector("list", length(param_grid$params))
  source_info <- ledgr_strategy_source_info(exp$strategy)
  strategy_hash <- source_info$hash
  strategy_name <- ledgr_sweep_strategy_name(exp$strategy)
  execution_seed_override <- ledgr_sweep_execution_seed_override(
    resolver = execution_seed_resolver,
    param_grid = param_grid,
    resolved = resolved,
    strategy_hash = strategy_hash,
    metric_context_hash = ledgr_metric_context_hash(metric_context),
    cost_model_hash = exp$cost_model_hash %||% NULL,
    risk_chain_hash = exp$risk_chain_hash %||% ledgr_risk_chain_hash(exp$risk_chain %||% ledgr_risk_none())
  )
  tasks <- ledgr_sweep_candidate_tasks(
    exp = exp,
    param_grid = param_grid,
    resolved = resolved,
    seed = seed,
    bars_by_id = bars_by_id,
    bars_mat = bars_mat,
    static_bars_views = static_bars_views,
    history_substrate = history_substrate,
    pulses_posix = pulses_posix,
    pulses_iso = pulses_iso,
    metric_kernel = metric_kernel,
    retain = retain,
    runtime_projection = runtime_projection,
    snapshot_hash = meta$snapshot_hash,
    strategy_hash = strategy_hash,
    compiled_accounting_model = compiled_accounting_model,
    execution_seed_override = execution_seed_override,
    availability_config = availability_config,
    execution_opportunities_posix = execution_opportunities_posix,
    corporate_action_rows = corporate_action_rows
  )
  staged_invariant_bytes <- 0
  staged_payload_census <- ledgr_sweep_history_payload_census(list())
  if (workers > 1L && availability_active) {
    staged <- ledgr_sweep_stage_history_tasks(tasks, sweep_id)
    tasks <- staged$tasks
    staged_invariant_bytes <- staged$bytes
    staged_payload_census <- staged$census
    ledgr_parallel_mirai_stage_history(
      staged$invariant,
      staged$identity,
      workers = workers
    )
  }
  results <- if (workers <= 1L) {
    lapply(tasks, ledgr_sweep_eval_candidate_task, stop_on_error = stop_on_error)
  } else {
    ledgr_sweep_eval_candidate_tasks_parallel(tasks, workers = workers)
  }
  if (isTRUE(stop_on_error)) {
    for (result in results) {
      if (!is.null(result$error)) {
        stop(result$error)
      }
    }
  }
  rows <- lapply(results, `[[`, "row")

  out <- ledgr_add_completion_columns(tibble::as_tibble(do.call(rbind, rows)))
  feature_union <- ledgr_sweep_feature_union(resolved$candidate_features)
  attr(out, "sweep_id") <- sweep_id
  attr(out, "snapshot_id") <- exp$snapshot$snapshot_id
  attr(out, "snapshot_hash") <- meta$snapshot_hash
  attr(out, "identity_rule_version") <- ledgr_identity_rule_version
  # The pulses actually scored, as a reopened sweep reconstructs them.
  attr(out, "scoring_range") <- list(start = pulses_iso[[1L]], end = pulses_iso[[length(pulses_iso)]])
  attr(out, "universe") <- exp$universe
  attr(out, "master_seed") <- seed
  attr(out, "seed_contract") <- ledgr_seed_contract_current()
  attr(out, "evaluation_scope") <- "exploratory"
  attr(out, "strategy_hash") <- strategy_hash
  strategy_schedule <- ledgr_strategy_schedule_declaration(exp$strategy)
  if (!is.null(strategy_schedule)) {
    attr(out, "strategy_schedule") <- strategy_schedule
    attr(out, "strategy_schedule_hash") <- ledgr_strategy_schedule_hash(strategy_schedule)
  }
  attr(out, "strategy_name") <- strategy_name
  attr(out, "strategy_source_capture_method") <- source_info$capture_method
  attr(out, "strategy_preflight") <- preflight
  attr(out, "feature_union") <- feature_union
  attr(out, "feature_union_hash") <- ledgr_feature_set_hash(feature_union)
  attr(out, "feature_engine_version") <- runtime_projection$feature_engine_version
  attr(out, "staged_invariant_bytes") <- as.numeric(staged_invariant_bytes)
  attr(out, "staged_payload_census") <- staged_payload_census
  attr(out, "history_worker_support") <- if (!availability_active) {
    NA_character_
  } else if (workers <= 2L) {
    "measured"
  } else {
    "unmeasured"
  }
  attr(out, "candidate_features") <- resolved$candidate_features
  attr(out, "metric_context") <- metric_context
  attr(out, "metric_context_hash") <- ledgr_metric_context_hash(metric_context)
  attr(out, "metric_context_version") <- as.integer(metric_context$metric_context_version)
  attr(out, "cost_model_hash") <- exp$cost_model_hash %||% NULL
  attr(out, "cost_plan_json") <- exp$cost_plan_json %||% NULL
  attr(out, "risk_chain_hash") <- exp$risk_chain_hash %||% ledgr_risk_chain_hash(exp$risk_chain %||% ledgr_risk_none())
  attr(out, "risk_plan_json") <- exp$risk_plan_json %||% ledgr_risk_plan_json(exp$risk_chain %||% ledgr_risk_none())
  attr(out, "sweep_retention") <- retain
  if (identical(retain$returns, "completed")) {
    attr(out, "sweep_returns") <- ledgr_sweep_collect_retained_returns(results, sweep_id)
  }
  if (identical(retain$trades, "closed")) {
    attr(out, "sweep_trades") <- ledgr_sweep_collect_retained_trades(results, sweep_id)
  }
  execution_assumptions <- list(
    execution_mode = exp$execution_mode,
    timing_model = exp$timing_model,
    execution_timing_version = if (availability_active) {
      ledgr_availability_execution_timing_rule_version
    } else {
      NULL
    },
    cost_model_hash = exp$cost_model_hash %||% NULL,
    opening = exp$opening,
    compiled_accounting_model = compiled_accounting_model,
    precomputed_features = !is.null(precomputed_features),
    stop_on_error = stop_on_error,
    promotion_identities = ledgr_promotion_identities(exp, strategy_hash)
  )
  if (!is.null(strategy_schedule)) {
    execution_assumptions$strategy_schedule <- strategy_schedule
    execution_assumptions$schedule_hash <- ledgr_strategy_schedule_hash(strategy_schedule)
  }
  attr(out, "execution_assumptions") <- execution_assumptions
  attr(out, "ledgr_complete_names") <- names(out)
  class(out) <- c("ledgr_sweep_results", class(out))
  out
}

#' Select one sweep candidate for promotion
#'
#' Selects a single row from a sweep result table and packages its params, seed,
#' and provenance for promotion or inspection.
#'
#' @param results A `ledgr_sweep_results` object, a tibble-like object with
#'   `candidate_id`, `params`, `execution_seed`, and `provenance` columns, or a
#'   `ledgr_walk_forward_results` object.
#' @param which Candidate selector. A character scalar selects by
#'   `candidate_id`; an integer-like scalar selects by row position.
#' @param allow_failed Logical. Failed candidates error by default.
#' @param ... Method-specific arguments.
#' @param fold_seq For walk-forward results, integer fold sequence to extract,
#'   or `"latest"`.
#' @param selection_rationale Optional plain-text rationale. Required for
#'   walk-forward results when `fold_seq = "latest"`.
#' @param snapshot Optional sealed snapshot override for walk-forward results
#'   whose experiment store has moved. The override must have the same
#'   `snapshot_id` and `snapshot_hash` as the result locator; its `db_path` may
#'   differ.
#' @return A `ledgr_sweep_candidate` object.
#' @details The returned candidate carries `selection_view`, the tibble-like
#'   view passed to `ledgr_candidate()`. Promotion-context storage uses that
#'   view to record the filtered/sorted candidate table the user selected from.
#' `ledgr_candidate()` is the supported way to extract params, execution seed,
#' and row-level provenance for promotion. The selected candidate also carries
#' the compact reproduction key exposed by
#' [ledgr_candidate_reproduction_key()]. It avoids making users manually pull
#' `params[[1]]`, `execution_seed`, and provenance fields from a tibble row.
#'
#' @section Articles:
#' Exploratory sweeps and promotion:
#' `vignette("sweeps", package = "ledgr")`
#' `system.file("doc", "sweeps.html", package = "ledgr")`
#' @export
ledgr_candidate <- function(results, ...) {
  UseMethod("ledgr_candidate")
}

#' @rdname ledgr_candidate
#' @export
ledgr_candidate.default <- function(results, which = 1L, allow_failed = FALSE, ...) {
  ledgr_rng_force_args()
  ledgr_rng_preserve_caller(ledgr_candidate_default_impl(
    results = results,
    which = which,
    allow_failed = allow_failed,
    ...
  ))
}

ledgr_candidate_default_impl <- function(results, which, allow_failed, ...) {
  dots <- list(...)
  if (length(dots) > 0L) {
    rlang::abort("Unused argument(s) supplied to `ledgr_candidate()`.", class = "ledgr_invalid_args")
  }
  if (!is.logical(allow_failed) || length(allow_failed) != 1L || is.na(allow_failed)) {
    rlang::abort("`allow_failed` must be TRUE or FALSE.", class = "ledgr_invalid_args")
  }
  is_sweep_results <- inherits(results, "ledgr_sweep_results")
  view <- tibble::as_tibble(results)
  required <- c("candidate_id", "params", "execution_seed", "provenance")
  missing <- setdiff(required, names(view))
  if (length(missing) > 0L) {
    rlang::abort(
      sprintf("`results` is missing required candidate column(s): %s.", paste(missing, collapse = ", ")),
      class = "ledgr_invalid_sweep_candidate_input"
    )
  }
  if (nrow(view) < 1L) {
    rlang::abort("`results` must contain at least one candidate row.", class = "ledgr_invalid_sweep_candidate_input")
  }

  row_idx <- ledgr_candidate_row_index(view, which)
  row <- view[row_idx, , drop = FALSE]
  status <- if ("status" %in% names(row)) as.character(row$status[[1]]) else NA_character_
  if (identical(status, "INCOMPLETE")) {
    rlang::abort(
      sprintf("Candidate '%s' is INCOMPLETE and cannot be selected.", row$candidate_id[[1]]),
      class = "ledgr_incomplete_sweep_candidate"
    )
  }
  if (!isTRUE(allow_failed) && identical(status, "FAILED")) {
    rlang::abort(
      sprintf("Candidate '%s' has status FAILED. Use `allow_failed = TRUE` for diagnostic extraction.", row$candidate_id[[1]]),
      class = "ledgr_failed_sweep_candidate"
    )
  }

  if (!is_sweep_results) {
    message("Note: input is not a `ledgr_sweep_results` object; sweep-level metadata will not be available in the candidate.")
  }

  sweep_meta <- ledgr_candidate_sweep_meta(results, is_sweep_results)
  out <- list(
    candidate_id = as.character(row$candidate_id[[1]]),
    candidate_row = if ("candidate_row" %in% names(row)) as.integer(row$candidate_row[[1]]) else row_idx,
    status = status,
    params = row$params[[1]],
    feature_params = if ("feature_params" %in% names(row)) row$feature_params[[1]] else list(),
    execution_seed = as.integer(row$execution_seed[[1]]),
    provenance = row$provenance[[1]],
    row = row,
    selection_view = view,
    sweep_meta = sweep_meta
  )
  if ("warnings" %in% names(row)) out$warnings <- row$warnings[[1]]
  if ("feature_fingerprints" %in% names(row)) out$feature_fingerprints <- row$feature_fingerprints[[1]]
  structure(out, class = c("ledgr_sweep_candidate", "list"))
}

#' Return the compact reproduction key for a sweep candidate
#'
#' @param candidate A `ledgr_sweep_candidate`.
#' @return A `ledgr_candidate_reproduction_key` list.
#' @details
#' Sweep results are compact evaluation records, not durable run artifacts.
#' `ledgr_candidate_reproduction_key()` exposes the small key carried by a
#' selected candidate: snapshot identity, selector, strategy identity, feature
#' fingerprints, engine versions, seed metadata, candidate params, and metric
#' context. [ledgr_promote()] consumes the same candidate object to explicitly
#' rerun the candidate through [ledgr_run()] when durable ledger and equity
#' artifacts are needed.
#'
#' @section Articles:
#' Exploratory sweeps and promotion:
#' `vignette("sweeps", package = "ledgr")`
#' `system.file("doc", "sweeps.html", package = "ledgr")`
#' @export
ledgr_candidate_reproduction_key <- function(candidate) {
  ledgr_rng_force_args()
  ledgr_rng_preserve_caller(ledgr_candidate_reproduction_key_impl(candidate = candidate))
}

ledgr_candidate_reproduction_key_impl <- function(candidate) {
  if (!inherits(candidate, "ledgr_sweep_candidate")) {
    rlang::abort("`candidate` must be a ledgr_sweep_candidate object.", class = "ledgr_invalid_args")
  }
  meta <- candidate$sweep_meta
  if (!is.list(meta)) {
    meta <- list()
  }
  provenance <- candidate$provenance
  if (!is.list(provenance)) {
    provenance <- list()
  }
  current_provenance_versions <- c(
    ledgr_sweep_provenance_version,
    paste0("ledgr_walk_forward_candidate_", ledgr_walk_forward_candidate_schema_version)
  )
  provenance_version <- provenance$provenance_version
  if (!is.character(provenance_version) || length(provenance_version) != 1L ||
      is.na(provenance_version) ||
      !provenance_version %in% current_provenance_versions) {
    rlang::abort(
      sprintf(
        "Candidate provenance version %s is not current; required one of %s.",
        provenance_version %||% "<missing>",
        paste(current_provenance_versions, collapse = ", ")
      ),
      class = c("ledgr_sweep_schema_incompatible", "ledgr_invalid_args")
    )
  }
  schedule_identity <- provenance[c(
    "strategy_schedule", "schedule_hash",
    "resolved_schedule", "resolved_schedule_hash"
  )]
  schedule_identity <- schedule_identity[!vapply(schedule_identity, is.null, logical(1))]

  out <- list(
      reproduction_key_version = ledgr_candidate_reproduction_key_version,
      source_sweep = list(
        sweep_id = meta$sweep_id %||% NULL,
        evaluation_scope = meta$evaluation_scope %||% provenance$evaluation_scope %||% NULL
      ),
      candidate = list(
        candidate_id = candidate$candidate_id,
        candidate_row = candidate$candidate_row %||% NULL,
        status = candidate$status %||% NA_character_,
        params = candidate$params,
        feature_params = candidate$feature_params %||% list()
      ),
      snapshot = list(
        snapshot_id = meta$snapshot_id %||% NULL,
        snapshot_hash = provenance$snapshot_hash %||% meta$snapshot_hash %||% NULL
      ),
      selector = list(
        scoring_range = meta$scoring_range %||% NULL,
        universe = meta$universe %||% NULL
      ),
      strategy = list(
        strategy_hash = provenance$strategy_hash %||% meta$strategy_hash %||% NULL,
        strategy_name = meta$strategy_name %||% NULL,
        source_capture_method = meta$strategy_source_capture_method %||% NULL,
        preflight = meta$strategy_preflight %||% NULL
      ),
      features = list(
        feature_set_hash = provenance$feature_set_hash %||% NULL,
        feature_union = meta$feature_union %||% NULL,
        feature_union_hash = meta$feature_union_hash %||% NULL,
        feature_fingerprints = candidate$feature_fingerprints %||% NULL,
        alias_map_hash = provenance$alias_map_hash %||% NULL,
        alias_map_version = provenance$alias_map_version %||% NULL
      ),
      cost = list(
        cost_model_hash = provenance$cost_model_hash %||% meta$cost_model_hash %||% NULL,
        cost_plan_json = provenance$cost_plan_json %||% meta$cost_plan_json %||% NULL
      ),
      risk = list(
        risk_chain_hash = provenance$risk_chain_hash %||% meta$risk_chain_hash %||% NULL,
        risk_plan_json = provenance$risk_plan_json %||% meta$risk_plan_json %||% NULL
      ),
      engine = list(
        feature_engine_version = meta$feature_engine_version %||% ledgr_feature_engine_version(),
        provenance_version = provenance$provenance_version %||% NULL
      ),
      seed = list(
        execution_seed = candidate$execution_seed,
        master_seed = provenance$master_seed %||% meta$master_seed %||% NULL,
        seed_contract = provenance$seed_contract %||% meta$seed_contract %||% NULL
      ),
      metric_context = list(
        metric_context_hash = meta$metric_context_hash %||% NULL,
        metric_context_version = meta$metric_context_version %||% NULL
      ),
      execution_assumptions = meta$execution_assumptions %||% NULL
    )
  # A walk-forward candidate also names its pulse-seed rule; a sweep's
  # `seed_contract` already is that rule, so its key has no second marker.
  if (!is.null(provenance$pulse_seed_contract)) {
    out$seed$pulse_seed_contract <- provenance$pulse_seed_contract
  }
  if (length(schedule_identity) > 0L) {
    out$strategy_schedule <- schedule_identity
  }
  structure(out, class = c("ledgr_candidate_reproduction_key", "list"))
}

#' Promote a sweep candidate to a committed run
#'
#' Replays a selected sweep candidate through `ledgr_run()` so the result becomes
#' a durable experiment-store run artifact.
#'
#' @param exp A `ledgr_experiment`.
#' @param candidate A `ledgr_sweep_candidate`.
#' @param run_id Non-empty run identifier for the committed run.
#' @param note Optional plain-text note. Stored by the promotion-context ticket.
#' @param require_same_snapshot Logical. If `TRUE`, require the candidate
#'   provenance snapshot hash to match `exp`. Defaults to `TRUE`; train/test
#'   promotion must opt into cross-snapshot execution with `FALSE`.
#' @return A committed `ledgr_backtest`.
#' @details
#' `ledgr_promote()` commits a selected sweep candidate by calling
#' [ledgr_run()] with the candidate strategy params, feature params, and exact
#' `execution_seed`. This is the slow/materialized path: the sweep keeps only
#' compact candidate summaries and the reproduction key available through
#' [ledgr_candidate_reproduction_key()], while promotion explicitly pays the
#' cost to create durable ledger, equity, telemetry, and promotion-context
#' artifacts. Runs created this way store durable promotion context that can be read with
#' [ledgr_promotion_context()] or [ledgr_run_promotion_context()].
#' Hash fields carried from the candidate into promotion evidence are
#' summarized in [ledgr_identity_fields].
#' Promotion replays the selected candidate's cost model and risk chain even
#' when `exp` was configured with different `cost_model` or `risk_chain`
#' values.
#'
#' Promotion compares the candidate's strategy, feature-set, universe,
#' valuation-policy, corporate-action-policy and opening identities with the
#' promoting experiment's. It does not refuse a difference: it warns with
#' `ledgr_promote_identity_mismatch`, naming the differing identities, and
#' records both sides in the promotion context's `identity_check`. A
#' walk-forward candidate, or a sweep saved before these identities were
#' recorded, compares only the strategy and feature set and lists the rest as
#' `not_recorded`.
#'
#' The default `require_same_snapshot = TRUE` protects same-snapshot replay. For
#' train/test evaluation, pass a candidate selected on the train snapshot to a
#' test-snapshot experiment and set `require_same_snapshot = FALSE` deliberately.
#'
#' Promotion first checks the candidate's pulse-seed rule marker: a sweep
#' candidate needs `seed_contract = "ledgr_seed_v2"`, a walk-forward candidate
#' needs `pulse_seed_contract = "ledgr_seed_v2"`. An old or missing marker is
#' refused with `ledgr_seed_rule_mismatch` before any run is created; re-run
#' the sweep or walk-forward session with this ledgr version.
#'
#' @section Articles:
#' Exploratory sweeps and promotion:
#' `vignette("sweeps", package = "ledgr")`
#' `system.file("doc", "sweeps.html", package = "ledgr")`
#' @export
ledgr_promote <- function(exp,
                          candidate,
                          run_id,
                          note = NULL,
                          require_same_snapshot = TRUE) {
  ledgr_rng_force_args()
  ledgr_rng_preserve_caller(ledgr_promote_impl(
    exp = exp,
    candidate = candidate,
    run_id = run_id,
    note = note,
    require_same_snapshot = require_same_snapshot
  ))
}

ledgr_promote_impl <- function(exp,
                               candidate,
                               run_id,
                               note,
                               require_same_snapshot) {
  if (inherits(candidate, "ledgr_sweep_filter_result")) {
    ledgr_sweep_filter_abort_selection("promote")
  }
  if (!inherits(exp, "ledgr_experiment")) {
    rlang::abort("`exp` must be a ledgr_experiment object.", class = "ledgr_invalid_args")
  }
  if (!inherits(candidate, "ledgr_sweep_candidate")) {
    rlang::abort("`candidate` must be a ledgr_sweep_candidate object.", class = "ledgr_invalid_args")
  }
  if (!is.character(run_id) || length(run_id) != 1L || is.na(run_id) || !nzchar(run_id)) {
    rlang::abort("`run_id` must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }
  if (!is.null(note) && (!is.character(note) || length(note) != 1L || is.na(note) || !nzchar(note))) {
    rlang::abort("`note` must be NULL or a non-empty character scalar.", class = "ledgr_invalid_args")
  }
  if (!is.logical(require_same_snapshot) || length(require_same_snapshot) != 1L || is.na(require_same_snapshot)) {
    rlang::abort("`require_same_snapshot` must be TRUE or FALSE.", class = "ledgr_invalid_args")
  }
  # Refuse an old or missing pulse-seed rule marker before any hold or run.
  ledgr_candidate_validate_seed_rule(candidate)
  release <- ledgr_snapshot_hold(exp$snapshot)
  on.exit(release(), add = TRUE)
  if (identical(candidate$status, "INCOMPLETE")) {
    rlang::abort(
      sprintf("Cannot promote incomplete candidate '%s'.", candidate$candidate_id),
      class = "ledgr_promote_incomplete_candidate"
    )
  }
  if (identical(candidate$status, "FAILED")) {
    rlang::abort(
      sprintf(
        "Cannot promote failed candidate '%s'. Use `allow_failed = TRUE` only for diagnostic extraction.",
        candidate$candidate_id
      ),
      class = "ledgr_promote_failed_candidate"
    )
  }
  ledgr_snapshot_ensure_handle(exp$snapshot)

  if (isTRUE(require_same_snapshot)) {
    ledgr_candidate_validate_same_snapshot(exp, candidate)
  }
  exp <- ledgr_promote_experiment_with_candidate_cost(exp, candidate)
  exp <- ledgr_promote_experiment_with_candidate_risk(exp, candidate)
  promoting_identities <- ledgr_promotion_identities(exp)

  seed <- candidate$execution_seed
  if (length(seed) != 1L || is.na(seed)) {
    seed <- NULL
  }
  bt <- ledgr_run(
    exp = exp,
    params = candidate$params,
    feature_params = candidate$feature_params %||% list(),
    run_id = run_id,
    seed = seed
  )
  # Promotion records both sides' identities and warns on a difference; it
  # does not refuse (Cut 12 decision 4, LDG-3005).
  candidate_identities <- candidate$sweep_meta$execution_assumptions$promotion_identities %||%
    list(strategy_hash = candidate$sweep_meta$strategy_hash %||% candidate$provenance$strategy_hash)
  candidate_identities$feature_set_hash <- candidate$provenance$feature_set_hash
  candidate_schedule_hash <- candidate$provenance$schedule_hash %||%
    candidate$sweep_meta$strategy_schedule_hash
  if (!is.null(candidate_schedule_hash)) {
    candidate_identities$schedule_hash <- candidate_schedule_hash
  }
  # The committed config carries the hash; no store read is needed.
  promoting_identities$feature_set_hash <- bt$config$features$feature_set_hash %||% NA_character_
  identity_check <- ledgr_promotion_identity_check(candidate_identities, promoting_identities)
  ledgr_promote_write_context_or_warn(bt, candidate, note, identity_check)
  if (length(identity_check$mismatched) > 0L) {
    rlang::warn(
      sprintf(
        paste(
          "Promoted run '%s' differs from candidate '%s' in: %s.",
          "Its results are not the candidate's; both identities are recorded in ledgr_promotion_context(bt)$identity_check."
        ),
        bt$run_id, candidate$candidate_id, paste(identity_check$mismatched, collapse = ", ")
      ),
      class = "ledgr_promote_identity_mismatch"
    )
  }
  attr(bt, "promotion_note") <- note
  bt
}

#' Print a sweep candidate
#'
#' @param x A `ledgr_sweep_candidate` object.
#' @param ... Unused.
#' @return The input object, invisibly.
#' @export
print.ledgr_sweep_candidate <- function(x, ...) {
  strategy <- ledgr_candidate_strategy_label(x)
  seed <- if (length(x$execution_seed) == 1L && !is.na(x$execution_seed)) {
    as.character(x$execution_seed)
  } else {
    "-"
  }
  feature_hash <- x$provenance$feature_set_hash %||% NA_character_
  snapshot_hash <- x$provenance$snapshot_hash %||% NA_character_
  evaluation_scope <- x$provenance$evaluation_scope %||% NA_character_

  cat("ledgr_sweep_candidate\n")
  cat("=====================\n")
  cat("Strategy params:  ", ledgr_sweep_params_summary(x$params), "\n", sep = "")
  cat("Feature params:   ", ledgr_sweep_params_summary(x$feature_params %||% list()), "\n", sep = "")
  cat("Candidate ID:     ", x$candidate_id, "\n", sep = "")
  cat("Status:           ", x$status %||% NA_character_, "\n", sep = "")
  cat("Execution seed:   ", seed, "\n", sep = "")
  cat("Strategy:         ", strategy, "\n", sep = "")
  cat("Snapshot hash:    ", snapshot_hash, "\n", sep = "")
  cat("Feature-set hash: ", feature_hash, "\n", sep = "")
  cat("Evaluation scope: ", evaluation_scope, "\n", sep = "")
  invisible(x)
}

#' Print sweep results
#'
#' @param x A `ledgr_sweep_results` object.
#' @param ... Passed to the tibble print method.
#' @return The input object, invisibly.
#' @export
print.ledgr_sweep_results <- function(x, ...) {
  if (!all(c("params", "feature_params") %in% names(x))) {
    degraded <- x
    class(degraded) <- setdiff(class(degraded), "ledgr_sweep_results")
    print(degraded, ...)
    return(invisible(x))
  }
  count_lines <- ledgr_selection_table_lines(x)
  retention <- attr(x, "sweep_retention", exact = TRUE)
  retention_returns <- if (inherits(retention, "ledgr_sweep_retention")) retention$returns else "unknown"
  retention_trades <- if (inherits(retention, "ledgr_sweep_retention")) retention$trades else "unknown"
  saved <- attr(x, "saved_sweep", exact = TRUE)
  saved_line <- if (is.list(saved) && isTRUE(saved$saved)) {
    sprintf(
      "Saved artifact: schema v%s, engine %s.",
      as.character(saved$sweep_schema_version %||% NA_integer_),
      as.character(saved$engine_version %||% NA_character_)
    )
  } else {
    "Saved artifact: not saved."
  }
  display <- x
  display$strategy_params <- vapply(display$params, ledgr_sweep_params_summary, character(1))
  display$feature_params <- vapply(display$feature_params, ledgr_sweep_params_summary, character(1))
  attr(display, "ledgr_complete_names") <- names(display)
  visible <- c(
    "strategy_params", "feature_params", "candidate_id", "candidate_row", "status", "sharpe_ratio", "total_return",
    "max_drawdown", "n_trades", "execution_seed"
  )
  # Freeze and assumed-terminal flags travel beside the ranking columns
  # whenever any candidate carries them.
  flagged <- function(name, test) {
    value <- display[[name]]
    !is.null(value) && any(test(value), na.rm = TRUE)
  }
  if (flagged("valuation_state", function(v) v %in% "frozen") ||
    flagged("assumed_terminal_outcomes", function(v) v > 0L) ||
    flagged("status", function(v) !as.character(v) %in% "DONE")) {
    visible <- c(visible, "stop_reason", "valuation_state", "assumed_terminal_outcomes")
  }
  hidden <- setdiff(names(display), visible)
  ledgr_print_curated_tibble(
    sprintf("# ledgr sweep -- %s", attr(x, "sweep_id") %||% "<unknown>"),
    display,
    cols = visible,
    footer = c(
      count_lines,
      sprintf("Retention returns: %s.", retention_returns),
      sprintf("Retention trades: %s.", retention_trades),
      sprintf("Snapshot hash: %s.", attr(x, "snapshot_hash") %||% "<unknown>"),
      sprintf("Cost model hash: %s.", attr(x, "cost_model_hash") %||% "<unknown>"),
      sprintf("Metric context hash: %s.", attr(x, "metric_context_hash") %||% "<unknown>"),
      saved_line,
      "Rows are printed in their current table order; rank or arrange explicitly before selecting candidates.",
      sprintf("Hidden columns (%d): %s", length(hidden), paste(hidden, collapse = ", "))
    ),
    footer_requires_complete = c(rep(FALSE, 7L + length(count_lines)), TRUE),
    ...
  )
}

ledgr_sweep_params_summary <- function(params, max_bytes = 56L) {
  if (!is.list(params) || is.data.frame(params)) {
    return("<invalid; use ledgr_candidate()>")
  }
  if (length(params) == 0L) {
    return("{}")
  }
  text <- as.character(canonical_json(params))
  if (nchar(text, type = "bytes") <= max_bytes) {
    return(text)
  }
  "<truncated; use ledgr_candidate()>"
}

ledgr_candidate_row_index <- function(view, which) {
  if (is.character(which) && length(which) == 1L && !is.na(which) && nzchar(which)) {
    matches <- base::which(as.character(view$candidate_id) == which)
    if (length(matches) != 1L) {
      rlang::abort(
        sprintf("Expected exactly one candidate with candidate_id '%s'; found %d.", which, length(matches)),
        class = "ledgr_sweep_candidate_not_found"
      )
    }
    return(matches[[1]])
  }
  if (is.numeric(which) && length(which) == 1L && !is.na(which) &&
    is.finite(which) && which == as.integer(which)) {
    idx <- as.integer(which)
    if (idx < 1L || idx > nrow(view)) {
      rlang::abort("Candidate row position is out of bounds.", class = "ledgr_sweep_candidate_not_found")
    }
    return(idx)
  }
  rlang::abort("`which` must be a character candidate_id or integer row position.", class = "ledgr_invalid_args")
}

ledgr_candidate_sweep_meta <- function(results, is_sweep_results) {
  if (!isTRUE(is_sweep_results)) {
    return(NULL)
  }
  keys <- c(
    "sweep_id", "snapshot_id", "snapshot_hash", "scoring_range", "universe",
    "master_seed", "seed_contract", "evaluation_scope", "strategy_hash",
    "strategy_name", "strategy_source_capture_method", "strategy_preflight",
    "strategy_schedule", "strategy_schedule_hash",
    "feature_union", "feature_union_hash", "feature_engine_version", "metric_context",
    "metric_context_hash", "metric_context_version", "risk_chain_hash", "risk_plan_json",
    "execution_assumptions"
  )
  # Optional keys enter the metadata only when the results carry them. A
  # walk-forward candidate's results carry `pulse_seed_contract`.
  keys <- c(keys, "pulse_seed_contract")
  optional_keys <- c("strategy_schedule", "strategy_schedule_hash", "pulse_seed_contract")
  keys <- keys[
    !keys %in% optional_keys |
      vapply(keys, function(key) !is.null(attr(results, key, exact = TRUE)), logical(1))
  ]
  stats::setNames(lapply(keys, function(key) attr(results, key, exact = TRUE)), keys)
}

ledgr_promote_experiment_with_candidate_risk <- function(exp, candidate) {
  risk_identity <- ledgr_candidate_risk_identity(candidate)
  exp$risk_chain <- risk_identity$risk_chain
  exp$risk_chain_hash <- risk_identity$risk_chain_hash
  exp$risk_plan_json <- risk_identity$risk_plan_json
  exp
}

ledgr_promote_experiment_with_candidate_cost <- function(exp, candidate) {
  cost_identity <- ledgr_candidate_cost_identity(candidate)
  exp$cost_model <- cost_identity$cost_model
  exp$cost_model_hash <- cost_identity$cost_model_hash
  exp$cost_plan_json <- cost_identity$cost_plan_json
  exp
}

ledgr_candidate_cost_identity <- function(candidate) {
  provenance <- candidate$provenance
  if (!is.list(provenance)) {
    provenance <- list()
  }
  meta <- candidate$sweep_meta
  if (!is.list(meta)) {
    meta <- list()
  }
  row <- candidate$row
  cost_model_hash <- provenance$cost_model_hash %||% meta$cost_model_hash %||% NULL
  cost_plan_json <- provenance$cost_plan_json %||% meta$cost_plan_json %||% NULL
  if (is.null(cost_model_hash) && is.data.frame(row) && "cost_model_hash" %in% names(row)) {
    cost_model_hash <- as.character(row$cost_model_hash[[1]])
  }
  if (is.null(cost_model_hash) || is.null(cost_plan_json)) {
    rlang::abort(
      "Candidate cost_model_hash and cost_plan_json are required for promotion.",
      class = c("ledgr_candidate_cost_identity_mismatch", "ledgr_invalid_args")
    )
  }
  if (!is.character(cost_model_hash) || length(cost_model_hash) != 1L ||
    is.na(cost_model_hash) || !grepl("^[0-9a-f]{64}$", cost_model_hash)) {
    rlang::abort(
      "Candidate cost_model_hash is missing or invalid.",
      class = c("ledgr_candidate_cost_identity_mismatch", "ledgr_invalid_args")
    )
  }
  if (!is.character(cost_plan_json) || length(cost_plan_json) != 1L ||
    is.na(cost_plan_json) || !nzchar(cost_plan_json)) {
    rlang::abort(
      "Candidate cost_plan_json is missing or invalid.",
      class = c("ledgr_candidate_cost_identity_mismatch", "ledgr_invalid_args")
    )
  }
  cost_model <- tryCatch(
    ledgr_cost_plan_reconstruct(cost_plan_json),
    error = function(e) {
      rlang::abort(
        "Candidate cost_plan_json cannot be reconstructed.",
        class = c("ledgr_candidate_cost_identity_mismatch", "ledgr_invalid_args"),
        parent = e
      )
    }
  )
  # The stored cost_plan_json is the durable byte identity. Reconstructing a
  # singleton cost model can normalize it to a chain-shaped runtime model, so
  # validate by hashing the canonicalized stored bytes rather than the model.
  canonical_plan <- as.character(canonical_json(cost_plan_json))
  if (!identical(digest::digest(canonical_plan, algo = "sha256"), cost_model_hash)) {
    rlang::abort(
      "Candidate cost_model_hash does not match cost_plan_json.",
      class = c("ledgr_candidate_cost_identity_mismatch", "ledgr_invalid_args")
    )
  }
  list(
    cost_model = cost_model,
    cost_model_hash = cost_model_hash,
    cost_plan_json = canonical_plan
  )
}

ledgr_candidate_risk_identity <- function(candidate) {
  provenance <- candidate$provenance
  if (!is.list(provenance)) {
    provenance <- list()
  }
  meta <- candidate$sweep_meta
  if (!is.list(meta)) {
    meta <- list()
  }
  row <- candidate$row
  risk_chain_hash <- provenance$risk_chain_hash %||% meta$risk_chain_hash %||% NULL
  risk_plan_json <- provenance$risk_plan_json %||% meta$risk_plan_json %||% NULL
  if (is.null(risk_chain_hash) && is.data.frame(row) && "risk_chain_hash" %in% names(row)) {
    risk_chain_hash <- as.character(row$risk_chain_hash[[1]])
  }
  if (is.null(risk_chain_hash) && is.null(risk_plan_json)) {
    risk_chain <- ledgr_risk_none()
    return(list(
      risk_chain = risk_chain,
      risk_chain_hash = ledgr_risk_chain_hash(risk_chain),
      risk_plan_json = ledgr_risk_plan_json(risk_chain)
    ))
  }
  if (!is.character(risk_chain_hash) || length(risk_chain_hash) != 1L ||
    is.na(risk_chain_hash) || !grepl("^[0-9a-f]{64}$", risk_chain_hash)) {
    rlang::abort(
      "Candidate risk_chain_hash is missing or invalid.",
      class = c("ledgr_candidate_risk_identity_mismatch", "ledgr_invalid_args")
    )
  }
  if (!is.character(risk_plan_json) || length(risk_plan_json) != 1L ||
    is.na(risk_plan_json) || !nzchar(risk_plan_json)) {
    rlang::abort(
      "Candidate risk_plan_json is missing or invalid.",
      class = c("ledgr_candidate_risk_identity_mismatch", "ledgr_invalid_args")
    )
  }
  risk_chain <- tryCatch(
    ledgr_risk_plan_reconstruct(risk_plan_json),
    error = function(e) {
      rlang::abort(
        "Candidate risk_plan_json cannot be reconstructed.",
        class = c("ledgr_candidate_risk_identity_mismatch", "ledgr_invalid_args"),
        parent = e
      )
    }
  )
  canonical_plan <- ledgr_risk_plan_json(risk_chain)
  if (!identical(canonical_plan, as.character(canonical_json(risk_plan_json))) ||
    !identical(ledgr_risk_chain_hash(risk_chain), risk_chain_hash)) {
    rlang::abort(
      "Candidate risk_chain_hash does not match risk_plan_json.",
      class = c("ledgr_candidate_risk_identity_mismatch", "ledgr_invalid_args")
    )
  }
  list(
    risk_chain = risk_chain,
    risk_chain_hash = risk_chain_hash,
    risk_plan_json = canonical_plan
  )
}

ledgr_candidate_validate_same_snapshot <- function(exp, candidate) {
  provenance <- candidate$provenance
  if (!is.list(provenance) ||
    is.null(provenance$snapshot_hash) ||
    !is.character(provenance$snapshot_hash) ||
    length(provenance$snapshot_hash) != 1L ||
    is.na(provenance$snapshot_hash) ||
    !nzchar(provenance$snapshot_hash)) {
    rlang::abort(
      "`require_same_snapshot = TRUE` needs candidate provenance with `snapshot_hash`.",
      class = "ledgr_candidate_missing_snapshot_hash"
    )
  }
  meta <- ledgr_precompute_snapshot_meta(exp$snapshot)
  if (!identical(provenance$snapshot_hash, meta$snapshot_hash)) {
    rlang::abort(
      paste(
        "Candidate snapshot hash does not match the target experiment snapshot.",
        "For a deliberate train/test promotion, call `ledgr_promote(..., require_same_snapshot = FALSE)`.",
        "Same-snapshot replay keeps the default `require_same_snapshot = TRUE`."
      ),
      class = "ledgr_candidate_snapshot_mismatch"
    )
  }
  invisible(TRUE)
}

ledgr_candidate_strategy_label <- function(candidate) {
  meta <- candidate$sweep_meta
  name <- if (is.list(meta)) meta$strategy_name else NULL
  hash <- if (is.list(meta)) meta$strategy_hash else candidate$provenance$strategy_hash
  has_name <- is.character(name) && length(name) == 1L && !is.na(name) && nzchar(name)
  has_hash <- is.character(hash) && length(hash) == 1L && !is.na(hash) && nzchar(hash)
  if (has_name && has_hash) {
    return(sprintf("%s (%s)", name, substr(hash, 1L, 12L)))
  }
  if (has_hash) {
    return(substr(hash, 1L, 12L))
  }
  if (has_name) {
    return(name)
  }
  "<unknown>"
}

ledgr_sweep_strategy_name <- function(strategy) {
  name <- attr(strategy, "name", exact = TRUE)
  if (is.character(name) && length(name) == 1L && !is.na(name) && nzchar(name)) {
    return(name)
  }
  name <- attr(strategy, "ledgr_strategy_name", exact = TRUE)
  if (is.character(name) && length(name) == 1L && !is.na(name) && nzchar(name)) {
    return(name)
  }
  NULL
}

ledgr_generate_sweep_id <- function() {
  .ledgr_sweep_id_state$counter <- as.integer(.ledgr_sweep_id_state$counter %||% 0L) + 1L
  payload <- list(
    pid = Sys.getpid(),
    counter = .ledgr_sweep_id_state$counter,
    time = ledgr_normalize_ts_utc(Sys.time())
  )
  paste0("sweep_", substr(digest::digest(canonical_json(payload), algo = "sha256"), 1L, 16L))
}

ledgr_sweep_candidate_tasks <- function(exp,
                                        param_grid,
                                        resolved,
                                        seed,
                                        bars_by_id,
                                        bars_mat,
                                        static_bars_views,
                                        pulses_posix,
                                        pulses_iso,
                                        metric_kernel,
                                        retain,
                                        runtime_projection,
                                        snapshot_hash,
                                        strategy_hash,
                                        history_substrate = NULL,
                                        compiled_accounting_model = NULL,
                                        execution_seed_override = NULL,
                                        availability_config = NULL,
                                        execution_opportunities_posix = NULL,
                                        corporate_action_rows = NULL) {
  exp_payload <- ledgr_sweep_exp_payload(exp)
  compiled_accounting_model <- ledgr_public_compiled_accounting_model(compiled_accounting_model)
  execution_seed_override <- ledgr_sweep_validate_execution_seed_override(
    execution_seed_override,
    length(param_grid$params)
  )
  tasks <- vector("list", length(param_grid$params))
  for (i in seq_along(param_grid$params)) {
    label <- param_grid$labels[[i]]
    candidate_spec <- param_grid$params[[i]]
    raw_params <- param_grid$identity_params[[i]]
    params <- ledgr_grid_candidate_strategy_params(candidate_spec)
    tasks[[i]] <- list(
      index = i,
      exp = exp_payload,
      run_id = label,
      candidate_id = label,
      candidate_row = i,
      raw_params = raw_params,
      params = params,
      feature_params = ledgr_grid_candidate_feature_params(candidate_spec),
      execution_seed = if (!is.null(execution_seed_override)) {
        execution_seed_override[[i]]
      } else if (is.null(seed)) {
        NA_integer_
      } else {
        ledgr_derive_seed(seed, list(run_id = label, params = raw_params))
      },
      bars_by_id = bars_by_id,
      bars_mat = bars_mat,
      static_bars_views = static_bars_views,
      history_substrate = history_substrate,
      pulses_posix = pulses_posix,
      pulses_iso = pulses_iso,
      metric_kernel = metric_kernel,
      retain = retain,
      candidate = resolved$candidates[[i]],
      candidate_feature_row = resolved$candidate_features[i, , drop = FALSE],
      runtime_projection = if (isTRUE(exp$availability$active)) NULL else runtime_projection,
      snapshot_hash = snapshot_hash,
      strategy_hash = strategy_hash,
      master_seed = seed,
      compiled_accounting_model = compiled_accounting_model,
      availability_config = availability_config,
      execution_opportunities_posix = execution_opportunities_posix,
      corporate_action_rows = corporate_action_rows
    )
  }
  tasks
}

ledgr_sweep_history_invariant_fields <- function() {
  c(
    "exp", "bars_by_id", "bars_mat", "static_bars_views",
    "history_substrate", "pulses_posix", "pulses_iso", "metric_kernel",
    "retain", "runtime_projection", "snapshot_hash",
    "strategy_hash", "master_seed", "compiled_accounting_model",
    "availability_config",
    "execution_opportunities_posix", "corporate_action_rows"
  )
}

ledgr_sweep_history_payload_census <- function(tasks) {
  if (length(tasks) == 0L) {
    return(data.frame(
      field = character(), payload_class = character(), bytes = numeric(),
      stringsAsFactors = FALSE
    ))
  }
  fields <- names(tasks[[1L]])
  invariant <- ledgr_sweep_history_invariant_fields()
  payload_class <- ifelse(
    fields %in% invariant,
    "staged_invariant",
    "candidate_varying"
  )
  payload_class[fields == "pulses_iso"] <- "worker_reconstructed"
  bytes <- vapply(
    tasks[[1L]],
    function(value) as.numeric(utils::object.size(value)),
    numeric(1)
  )
  bytes[fields == "pulses_iso"] <- 0
  data.frame(
    field = fields,
    payload_class = payload_class,
    bytes = bytes,
    stringsAsFactors = FALSE
  )
}

ledgr_sweep_stage_history_tasks <- function(tasks, owner_id) {
  if (length(tasks) == 0L) {
    return(list(
      tasks = tasks, invariant = NULL, identity = NULL, bytes = 0,
      census = ledgr_sweep_history_payload_census(tasks)
    ))
  }
  invariant_names <- ledgr_sweep_history_invariant_fields()
  census <- ledgr_sweep_history_payload_census(tasks)
  invariant <- tasks[[1L]][invariant_names]
  invariant$pulses_iso <- NULL
  # Each daemon prepares its own derived history planes; a parent memo is
  # never serialized into the staged invariant.
  invariant$history_substrate$history_memo <- new.env(parent = emptyenv())
  identity <- ledgr_history_stage_identity(invariant$history_substrate, owner_id)
  invariant$staged_owner_id <- as.character(owner_id)
  invariant$staged_invariant_identity <- identity
  compact <- lapply(tasks, function(task) {
    task[invariant_names] <- NULL
    task$staged_invariant_identity <- identity
    task
  })
  list(
    tasks = compact,
    invariant = invariant,
    identity = identity,
    bytes = as.numeric(utils::object.size(invariant)),
    census = census
  )
}

ledgr_sweep_execution_seed_override <- function(resolver,
                                                param_grid,
                                                resolved,
                                                strategy_hash,
                                                metric_context_hash,
                                                cost_model_hash,
                                                risk_chain_hash) {
  if (is.null(resolver)) {
    return(NULL)
  }
  out <- resolver(
    param_grid = param_grid,
    resolved = resolved,
    strategy_hash = strategy_hash,
    metric_context_hash = metric_context_hash,
    cost_model_hash = cost_model_hash,
    risk_chain_hash = risk_chain_hash
  )
  ledgr_sweep_validate_execution_seed_override(out, length(param_grid$params))
}

ledgr_sweep_validate_execution_seed_override <- function(x, n) {
  if (is.null(x)) {
    return(NULL)
  }
  if (!is.numeric(x) || length(x) != n) {
    rlang::abort(
      "`execution_seed_resolver` must return one integer or NA seed per sweep candidate.",
      class = "ledgr_invalid_args"
    )
  }
  out <- rep(NA_integer_, n)
  for (i in seq_len(n)) {
    value <- x[[i]]
    if (length(value) != 1L || is.na(value)) {
      out[[i]] <- NA_integer_
    } else if (!is.finite(value) || value != as.integer(value)) {
      rlang::abort(
        "`execution_seed_resolver` must return one integer or NA seed per sweep candidate.",
        class = "ledgr_invalid_args"
      )
    } else {
      out[[i]] <- as.integer(value)
    }
  }
  out
}

ledgr_sweep_exp_payload <- function(exp) {
  risk_chain <- exp$risk_chain %||% ledgr_risk_none()
  list(
    strategy = exp$strategy,
    universe = exp$universe,
    opening = exp$opening,
    timing_model = exp$timing_model,
    cost_model_hash = exp$cost_model_hash %||% NULL,
    cost_plan_json = exp$cost_plan_json %||% NULL,
    risk_chain = risk_chain,
    risk_chain_hash = exp$risk_chain_hash %||% ledgr_risk_chain_hash(risk_chain),
    risk_plan_json = exp$risk_plan_json %||% ledgr_risk_plan_json(risk_chain),
    availability = exp$availability %||% NULL,
    universe_rule = exp$universe_rule %||% NULL,
    valuation_policy = exp$valuation_policy %||% NULL,
    corporate_action_policy = exp$corporate_action_policy %||%
      ledgr_corporate_actions_research(),
    history_policy = exp$history_policy
  )
}

ledgr_sweep_eval_candidate_task <- function(task, stop_on_error = FALSE) {
  feature_row <- task$candidate_feature_row
  strategy_schedule <- ledgr_strategy_schedule_declaration(task$exp$strategy)
  if (identical(feature_row$status[[1]], "failed")) {
    if (isTRUE(stop_on_error)) {
      stop(task$candidate$error)
    }
    row <- ledgr_sweep_failure_row(
      candidate_id = task$candidate_id,
      candidate_row = task$candidate_row,
      params = task$params,
      feature_params = task$feature_params,
      execution_seed = task$execution_seed,
      error_class = feature_row$error_class[[1]],
      error_msg = feature_row$error_msg[[1]],
      feature_fingerprints = feature_row$feature_fingerprints[[1]],
      risk_chain_hash = task$exp$risk_chain_hash,
      provenance = ledgr_sweep_provenance(
        snapshot_hash = task$snapshot_hash,
        strategy_hash = task$strategy_hash,
        feature_set_hash = feature_row$feature_set_hash[[1]],
        alias_map_json = feature_row$alias_map_json[[1]],
        alias_map_hash = feature_row$alias_map_hash[[1]],
        alias_map_version = feature_row$alias_map_version[[1]],
        cost_model_hash = task$exp$cost_model_hash %||% NULL,
        cost_plan_json = task$exp$cost_plan_json %||% NULL,
        risk_chain_hash = task$exp$risk_chain_hash,
        risk_plan_json = task$exp$risk_plan_json,
        master_seed = task$master_seed,
        schedule_identity = ledgr_strategy_schedule_identity_or_authored(
          strategy_schedule,
          task$params
        )
      ),
      warnings = list()
    )
    return(list(
      row = row,
      warnings = list(),
      error = task$candidate$error,
      retained_returns = NULL,
      retained_trades = NULL
    ))
  }

  warnings <- list()
  err <- NULL
  schedule_identity <- NULL
  candidate_result <- tryCatch(
    withCallingHandlers(
      {
        schedule_identity <- ledgr_strategy_schedule_identity(
          strategy_schedule,
          task$params
        )
        ledgr_sweep_run_candidate(
          exp = task$exp,
          run_id = task$run_id,
          candidate_id = task$candidate_id,
          candidate_row = task$candidate_row,
          params = task$params,
          feature_params = task$feature_params,
          execution_seed = task$execution_seed,
          bars_by_id = task$bars_by_id,
          bars_mat = task$bars_mat,
          static_bars_views = task$static_bars_views,
          history_substrate = task$history_substrate,
          pulses_posix = task$pulses_posix,
          pulses_iso = task$pulses_iso,
          metric_kernel = task$metric_kernel,
          candidate = task$candidate,
          candidate_feature_row = feature_row,
          runtime_projection = task$runtime_projection,
          snapshot_hash = task$snapshot_hash,
          strategy_hash = task$strategy_hash,
          master_seed = task$master_seed,
          retain = task$retain,
          compiled_accounting_model = task$compiled_accounting_model,
          availability_provider = task$availability_provider,
          availability_config = task$availability_config,
          execution_opportunities_posix = task$execution_opportunities_posix,
          corporate_action_rows = task$corporate_action_rows,
          schedule_identity = schedule_identity
        )
      },
      warning = function(w) {
        warnings <<- c(warnings, list(w))
        invokeRestart("muffleWarning")
      }
    ),
    error = function(e) {
      err <<- e
      if (isTRUE(stop_on_error)) {
        stop(e)
      }
      list(
        row = ledgr_sweep_failure_row(
          candidate_id = task$candidate_id,
          candidate_row = task$candidate_row,
          params = task$params,
          feature_params = task$feature_params,
          execution_seed = task$execution_seed,
          error_class = ledgr_condition_class(e),
          error_msg = conditionMessage(e),
          feature_fingerprints = feature_row$feature_fingerprints[[1]],
          risk_chain_hash = task$exp$risk_chain_hash,
          provenance = ledgr_sweep_provenance(
            snapshot_hash = task$snapshot_hash,
            strategy_hash = task$strategy_hash,
            feature_set_hash = feature_row$feature_set_hash[[1]],
            alias_map_json = feature_row$alias_map_json[[1]],
            alias_map_hash = feature_row$alias_map_hash[[1]],
            alias_map_version = feature_row$alias_map_version[[1]],
            cost_model_hash = task$exp$cost_model_hash %||% NULL,
            cost_plan_json = task$exp$cost_plan_json %||% NULL,
            risk_chain_hash = task$exp$risk_chain_hash,
            risk_plan_json = task$exp$risk_plan_json,
            master_seed = task$master_seed,
            schedule_identity = schedule_identity %||%
              ledgr_strategy_schedule_authored_identity(strategy_schedule)
          ),
          warnings = warnings
        ),
        retained_returns = NULL,
        retained_trades = NULL
      )
    }
  )
  row <- candidate_result$row
  row$warnings[[1]] <- warnings
  list(
    row = row,
    warnings = warnings,
    error = err,
    retained_returns = candidate_result$retained_returns,
    retained_trades = candidate_result$retained_trades
  )
}

ledgr_sweep_eval_candidate_tasks_parallel <- function(tasks,
                                                      workers,
                                                      submit = NULL,
                                                      value = NULL,
                                                      cleanup = ledgr_parallel_mirai_stop) {
  workers <- ledgr_parallel_workers_normalize(workers)
  if (length(tasks) == 0L) {
    return(list())
  }
  if (is.null(submit)) {
    mirai <- getExportedValue("mirai", "mirai")
    submit <- function(task) {
      mirai(
        {
          get("ledgr_sweep_worker_eval_candidate_task", envir = asNamespace("ledgr"))(task)
        },
        task = task
      )
    }
  }
  if (is.null(value)) {
    value <- function(promise) promise[]
  }
  tryCatch(
    {
      promises <- lapply(tasks, submit)
      lapply(seq_along(promises), function(i) {
        result <- value(promises[[i]])
        if (inherits(result, "errorValue")) {
          rlang::abort(
            sprintf(
              "Parallel worker failed before returning candidate '%s': %s",
              tasks[[i]]$run_id,
              as.character(result)
            ),
            class = c("ledgr_parallel_worker_failed", "ledgr_parallel_error")
          )
        }
        result
      })
    },
    interrupt = function(e) {
      if (is.function(cleanup)) {
        try(cleanup(), silent = TRUE)
      }
      ledgr_abort_parallel_sweep_interrupted(e)
    }
  )
}

ledgr_abort_parallel_sweep_interrupted <- function(parent = NULL) {
  rlang::abort(
    paste0(
      "Parallel sweep interrupted before all candidates completed. ",
      "Discarding partial worker results; no promotable sweep result was returned."
    ),
    class = c("ledgr_parallel_sweep_interrupted", "ledgr_parallel_error"),
    parent = parent
  )
}

ledgr_sweep_worker_eval_candidate_task <- function(task) {
  if (!is.null(task$staged_invariant_identity)) {
    invariant <- ledgr_history_worker_take(task$staged_invariant_identity)
    identity <- invariant$staged_invariant_identity
    invariant$staged_invariant_identity <- NULL
    task$staged_invariant_identity <- NULL
    task <- c(task, invariant)
    task$staged_invariant_identity <- identity
  }
  ledgr_sweep_eval_candidate_task(task, stop_on_error = FALSE)
}

ledgr_sweep_candidate_execution <- function(exp,
                                            run_id,
                                            params,
                                            feature_params,
                                            execution_seed,
                                            bars_by_id,
                                            bars_mat,
                                            static_bars_views,
                                            pulses_posix,
                                            pulses_iso,
                                            metric_kernel,
                                            candidate,
                                            candidate_feature_row,
                                            runtime_projection,
                                            snapshot_hash,
                                            strategy_hash,
                                            master_seed,
                                            candidate_id,
                                            candidate_row,
                                            retain,
                                            history_substrate = NULL,
                                            availability_provider = NULL,
                                            compiled_accounting_model = NULL,
                                            availability_config = NULL,
                                            execution_opportunities_posix = NULL,
                                            corporate_action_rows = NULL) {
  feature_defs <- candidate$feature_defs
  feature_fingerprints <- candidate_feature_row$feature_fingerprints[[1]]
  if (isTRUE(exp$availability$active)) {
    runtime_projection <- history_substrate$feature_projection
  }
  if (is.null(runtime_projection)) {
    rlang::abort("Sweep candidate execution requires `runtime_projection`.", class = "ledgr_invalid_fold_execution")
  }

  output_handler <- ledgr_output_handler(ledgr_output_sink_memory(run_id))
  availability_provider <- if (
    isTRUE(exp$availability$active) && is.null(availability_provider)
  ) {
    ledgr_availability_provider_from_substrate(
      history_substrate,
      availability_config,
      snapshot_hash
    )
  } else if (!isTRUE(exp$availability$active)) {
    NULL
  } else {
    availability_provider
  }
  opening_positions <- exp$opening$positions
  opening_cost_basis <- exp$opening$cost_basis
  if (is.null(opening_cost_basis) && length(opening_positions) > 0L) {
    opening_cost_basis <- stats::setNames(rep(NA_real_, length(opening_positions)), names(opening_positions))
  }
  opening_rows <- ledgr_opening_position_event_rows(
    run_id = run_id,
    ts_utc = pulses_posix[[1L]],
    positions = opening_positions,
    cost_basis = opening_cost_basis,
    event_seq_start = 1L
  )
  output_handler$append_event_rows(opening_rows)

  initial_positions <- stats::setNames(rep(0, length(exp$universe)), exp$universe)
  if (length(opening_positions) > 0L) {
    initial_positions[names(opening_positions)] <- as.numeric(opening_positions)
  }
  initial_lot_state <- ledgr_lot_state_from_opening(
    instrument_ids = exp$universe,
    positions = opening_positions,
    cost_basis = opening_cost_basis
  )
  telemetry <- ledgr_sweep_telemetry_env()
  cost_resolver <- ledgr_cost_resolver_from_plan_json(exp$cost_plan_json)
  risk_plan <- ledgr_risk_plan_compile(exp$risk_chain, params = params)
  strategy_fn <- ledgr_strategy_schedule_inner(exp$strategy)
  signature <- ledgr_strategy_signature(strategy_fn)
  schedule <- ledgr_compile_strategy_schedule(
    declaration = ledgr_strategy_schedule_declaration(exp$strategy),
    strategy_params = params,
    sessions = if (isTRUE(exp$availability$active)) history_substrate$sessions else NULL,
    pulses_posix = pulses_posix
  )
  if (!is.null(schedule$decision_due) &&
      identical(schedule$decision_pulse_count, 0L) &&
      !any(as.numeric(initial_positions) != 0)) {
    ledgr_schedule_abort(
      "The resolved strategy schedule has no decision pulse and the run has no opening or carried position.",
      "ledgr_schedule_no_decision"
    )
  }
  corporate_action_plan <- ledgr_corporate_action_plan(
    rows = corporate_action_rows,
    policy_identity = ledgr_corporate_action_policy_identity(
      exp$corporate_action_policy
    ),
    pulses_posix = pulses_posix,
    instrument_ids = exp$universe,
    existing_events = opening_rows,
    start_idx = 1L,
    dispositions_active = isTRUE(exp$availability$active)
  )
  execution <- ledgr_execution_spec(
    run_id = run_id,
    instrument_ids = exp$universe,
    strategy_fn = strategy_fn,
    strategy_params = params,
    strategy_call_signature = signature,
    strategy_is_functional = TRUE,
    pulses_posix = pulses_posix,
    pulses_iso = pulses_iso,
    start_idx = 1L,
    max_pulses = Inf,
    checkpoint_every = 0L,
    telemetry_stride = 0L,
    state = list(cash = exp$opening$cash, positions = initial_positions, lot_state = initial_lot_state),
    state_prev = NULL,
    bars_by_id = bars_by_id,
    bars_mat = bars_mat,
    static_bars_views = static_bars_views,
    history_substrate = history_substrate,
    static_feature_views = NULL,
    feature_defs = feature_defs,
    runtime_projection = if (isTRUE(exp$availability$active)) NULL else runtime_projection,
    active_alias_map = candidate$alias_map,
    risk_plan = risk_plan,
    cost_resolver = cost_resolver,
    event_seq_start = as.integer(nrow(opening_rows)) + 1L,
    telemetry = telemetry,
    seed = if (is.na(execution_seed)) NULL else execution_seed,
    event_mode = "buffered",
    use_fast_context = TRUE,
    compiled_accounting_model = compiled_accounting_model,
    availability_provider = availability_provider,
    execution_opportunities_posix = execution_opportunities_posix,
    corporate_action_plan = corporate_action_plan,
    corporate_action_policy = exp$corporate_action_policy,
    decision_due = schedule$decision_due,
    decision_pulse_count = schedule$decision_pulse_count,
    scheduled_skip_count = schedule$scheduled_skip_count
  )
  list(
    execution = execution,
    output_handler = output_handler,
    feature_fingerprints = feature_fingerprints,
    telemetry = telemetry
  )
}

ledgr_sweep_run_candidate <- function(exp,
                                      run_id,
                                      params,
                                      feature_params,
                                      execution_seed,
                                      bars_by_id,
                                      bars_mat,
                                      static_bars_views,
                                      pulses_posix,
                                      pulses_iso,
                                      metric_kernel,
                                      candidate,
                                      candidate_feature_row,
                                      runtime_projection,
                                      snapshot_hash,
                                      strategy_hash,
                                      master_seed,
                                      candidate_id,
                                      candidate_row,
                                      retain,
                                      history_substrate = NULL,
                                      availability_provider = NULL,
                                      compiled_accounting_model = NULL,
                                      availability_config = NULL,
                                      execution_opportunities_posix = NULL,
                                      corporate_action_rows = NULL,
                                      schedule_identity = NULL) {
  prepared <- ledgr_sweep_candidate_execution(
    exp = exp,
    run_id = run_id,
    params = params,
    feature_params = feature_params,
    execution_seed = execution_seed,
    bars_by_id = bars_by_id,
    bars_mat = bars_mat,
    static_bars_views = static_bars_views,
    pulses_posix = pulses_posix,
    pulses_iso = pulses_iso,
    metric_kernel = metric_kernel,
    candidate = candidate,
    candidate_feature_row = candidate_feature_row,
    runtime_projection = runtime_projection,
    snapshot_hash = snapshot_hash,
    strategy_hash = strategy_hash,
    master_seed = master_seed,
    candidate_id = candidate_id,
    candidate_row = candidate_row,
    retain = retain,
    history_substrate = history_substrate,
    availability_provider = availability_provider,
    compiled_accounting_model = compiled_accounting_model,
    availability_config = availability_config,
    execution_opportunities_posix = execution_opportunities_posix,
    corporate_action_rows = corporate_action_rows
  )
  execution <- prepared$execution
  output_handler <- prepared$output_handler
  feature_fingerprints <- prepared$feature_fingerprints
  telemetry <- prepared$telemetry
  engine_start <- ledgr_time_now()
  fold_result <- ledgr_execute_fold(execution, output_handler)
  telemetry$t_engine <- ledgr_time_elapsed(engine_start, ledgr_time_now())

  results_start <- ledgr_time_now()
  summary <- if (is.function(output_handler$inline_summary)) {
    output_handler$inline_summary(
      run_id = run_id,
      metric_kernel = metric_kernel
    )
  } else {
    events <- if (is.function(output_handler$typed_events)) {
      output_handler$typed_events()
    } else {
      output_handler$events()
    }
    ledgr_sweep_summary_from_ordered_events(
      events = events,
      pulses_posix = pulses_posix,
      close_mat = bars_mat$close,
      initial_cash = exp$opening$cash,
      instrument_ids = exp$universe,
      run_id = run_id,
      metric_kernel = metric_kernel,
      execution_opportunities_posix = execution_opportunities_posix
    )
  }
  if (nrow(summary$fills) > 0L) {
    summary$fills <- ledgr_fills_add_recording_pulse(
      summary$fills,
      ledgr_fill_recording_pulses_from_opportunities(
        summary$fills,
        pulses_posix,
        execution_opportunities_posix
      )
    )
  }
  telemetry$t_results <- ledgr_time_elapsed(results_start, ledgr_time_now())
  telemetry$t_fills_extract <- 0

  completion <- output_handler$completion()
  candidate_diagnostics <- if (isTRUE(exp$availability$active)) output_handler$diagnostics() else NULL
  candidate_flags <- if (isTRUE(exp$availability$active)) {
    ledgr_assumption_flags_from_memory(exp$valuation_policy, candidate_diagnostics, summary$equity)
  } else {
    NULL
  }
  row <- ledgr_sweep_success_row(
    candidate_id = candidate_id,
    candidate_row = candidate_row,
    params = params,
    feature_params = feature_params,
    execution_seed = execution_seed,
    final_equity = summary$final_equity,
    metrics = summary$metrics,
    feature_fingerprints = feature_fingerprints,
    risk_chain_hash = exp$risk_chain_hash,
    provenance = ledgr_sweep_provenance(
      snapshot_hash = snapshot_hash,
      strategy_hash = strategy_hash,
      feature_set_hash = candidate_feature_row$feature_set_hash[[1]],
      alias_map_json = candidate_feature_row$alias_map_json[[1]],
      alias_map_hash = candidate_feature_row$alias_map_hash[[1]],
      alias_map_version = candidate_feature_row$alias_map_version[[1]],
      cost_model_hash = exp$cost_model_hash %||% NULL,
      cost_plan_json = exp$cost_plan_json %||% NULL,
      risk_chain_hash = exp$risk_chain_hash,
      risk_plan_json = exp$risk_plan_json,
      master_seed = master_seed,
      schedule_identity = schedule_identity
    ),
    t_engine = telemetry$t_engine,
    t_results = telemetry$t_results,
    t_fills_extract = telemetry$t_fills_extract,
    warnings = list(),
    status = fold_result$status,
    completion_json = ledgr_completion_json(
      completion,
      affected_instrument_ids = ledgr_stopped_instrument_ids(candidate_diagnostics),
      assumptions = candidate_flags
    )
  )
  retained_returns <- if (identical(retain$returns, "completed")) {
    ledgr_sweep_retained_returns_from_equity(
      summary$equity,
      candidate_id = candidate_id,
      candidate_row = candidate_row
    )
  } else {
    NULL
  }
  retained_trades <- if (identical(retain$trades, "closed")) {
    ledgr_sweep_retained_trades_from_fills(
      summary$fills,
      candidate_id = candidate_id,
      candidate_row = candidate_row
    )
  } else {
    NULL
  }
  list(row = row, retained_returns = retained_returns, retained_trades = retained_trades)
}

ledgr_event_row_df <- function(row) {
  data.frame(
    event_id = row$event_id,
    run_id = row$run_id,
    ts_utc = row$ts_utc,
    event_type = row$event_type,
    instrument_id = row$instrument_id,
    side = row$side,
    qty = row$qty,
    price = row$price,
    fee = row$fee,
    meta_json = row$meta_json,
    event_seq = row$event_seq,
    stringsAsFactors = FALSE
  )
}

ledgr_empty_event_table <- function() {
  tibble::tibble(
    event_id = character(),
    run_id = character(),
    ts_utc = as.POSIXct(character(), tz = "UTC"),
    event_type = character(),
    instrument_id = character(),
    side = character(),
    qty = numeric(),
    price = numeric(),
    fee = numeric(),
    meta_json = character(),
    event_seq = integer()
  )
}

ledgr_sweep_success_row <- function(candidate_id,
                                    candidate_row,
                                    params,
                                    feature_params = list(),
                                    execution_seed,
                                    final_equity,
                                    metrics,
                                    feature_fingerprints,
                                    risk_chain_hash,
                                    provenance,
                                    warnings,
                                    status = "DONE",
                                    completion_json = NA_character_,
                                    t_engine = NA_real_,
                                    t_results = NA_real_,
                                    t_fills_extract = NA_real_) {
  ledgr_sweep_row(
    candidate_id = candidate_id,
    candidate_row = candidate_row,
    status = status,
    completion_json = completion_json,
    final_equity = final_equity,
    total_return = metrics$total_return,
    annualized_return = metrics$annualized_return,
    volatility = metrics$volatility,
    sharpe_ratio = metrics$sharpe_ratio,
    max_drawdown = metrics$max_drawdown,
    n_trades = metrics$n_trades,
    win_rate = metrics$win_rate,
    avg_trade = metrics$avg_trade,
    time_in_market = metrics$time_in_market,
    execution_seed = execution_seed,
    error_class = NA_character_,
    error_msg = NA_character_,
    params = params,
    feature_params = feature_params,
    warnings = warnings,
    feature_fingerprints = feature_fingerprints,
    risk_chain_hash = risk_chain_hash,
    provenance = provenance,
    t_engine = t_engine,
    t_results = t_results,
    t_fills_extract = t_fills_extract
  )
}

ledgr_sweep_failure_row <- function(candidate_id,
                                    candidate_row,
                                    params,
                                    feature_params = list(),
                                    execution_seed,
                                    error_class,
                                    error_msg,
                                    feature_fingerprints,
                                    risk_chain_hash,
                                    provenance,
                                    warnings) {
  ledgr_sweep_row(
    candidate_id = candidate_id,
    candidate_row = candidate_row,
    status = "FAILED",
    completion_json = NA_character_,
    final_equity = NA_real_,
    total_return = NA_real_,
    annualized_return = NA_real_,
    volatility = NA_real_,
    sharpe_ratio = NA_real_,
    max_drawdown = NA_real_,
    n_trades = NA_integer_,
    win_rate = NA_real_,
    avg_trade = NA_real_,
    time_in_market = NA_real_,
    execution_seed = execution_seed,
    error_class = error_class,
    error_msg = error_msg,
    params = params,
    feature_params = feature_params,
    warnings = warnings,
    feature_fingerprints = feature_fingerprints,
    risk_chain_hash = risk_chain_hash,
    provenance = provenance,
    t_engine = NA_real_,
    t_results = NA_real_,
    t_fills_extract = NA_real_
  )
}

ledgr_sweep_row <- function(candidate_id,
                            candidate_row,
                            status,
                            completion_json,
                            final_equity,
                            total_return,
                            annualized_return,
                            volatility,
                            sharpe_ratio,
                            max_drawdown,
                            n_trades,
                            win_rate,
                            avg_trade,
                            time_in_market,
                            execution_seed,
                            error_class,
                            error_msg,
                            params,
                            feature_params,
                            warnings,
                            feature_fingerprints,
                            risk_chain_hash,
                            provenance,
                            t_engine = NA_real_,
                            t_results = NA_real_,
                            t_fills_extract = NA_real_) {
  tibble::tibble(
    candidate_id = candidate_id,
    candidate_row = as.integer(candidate_row),
    status = status,
    completion_json = as.character(completion_json),
    final_equity = final_equity,
    total_return = total_return,
    annualized_return = annualized_return,
    volatility = volatility,
    sharpe_ratio = sharpe_ratio,
    max_drawdown = max_drawdown,
    n_trades = as.integer(n_trades),
    win_rate = win_rate,
    avg_trade = avg_trade,
    time_in_market = time_in_market,
    execution_seed = as.integer(execution_seed),
    error_class = error_class,
    error_msg = error_msg,
    params = list(params),
    feature_params = list(feature_params),
    warnings = list(warnings),
    feature_fingerprints = list(feature_fingerprints),
    risk_chain_hash = as.character(risk_chain_hash),
    provenance = list(provenance),
    t_engine = as.numeric(t_engine),
    t_results = as.numeric(t_results),
    t_fills_extract = as.numeric(t_fills_extract)
  )
}

ledgr_sweep_provenance <- function(snapshot_hash,
                                   strategy_hash,
                                   feature_set_hash,
                                   alias_map_json = NA_character_,
                                   alias_map_hash = NA_character_,
                                   alias_map_version = NA_integer_,
                                   cost_model_hash = NULL,
                                   cost_plan_json = NULL,
                                   risk_chain_hash = NULL,
                                   risk_plan_json = NULL,
                                   master_seed,
                                   schedule_identity = NULL) {
  out <- list(
    provenance_version = ledgr_sweep_provenance_version,
    snapshot_hash = snapshot_hash,
    strategy_hash = strategy_hash,
    feature_set_hash = feature_set_hash,
    alias_map_json = alias_map_json,
    alias_map_hash = alias_map_hash,
    alias_map_version = alias_map_version,
    master_seed = master_seed,
    seed_contract = ledgr_seed_contract_current(),
    evaluation_scope = "exploratory"
  )
  if (!is.null(cost_model_hash)) out$cost_model_hash <- cost_model_hash
  if (!is.null(cost_plan_json)) out$cost_plan_json <- cost_plan_json
  if (!is.null(risk_chain_hash)) out$risk_chain_hash <- risk_chain_hash
  if (!is.null(risk_plan_json)) out$risk_plan_json <- risk_plan_json
  if (!is.null(schedule_identity)) out <- c(out, schedule_identity)
  out
}

ledgr_sweep_feature_union <- function(candidate_features) {
  if (!"feature_fingerprints" %in% names(candidate_features)) {
    return(character())
  }
  values <- unlist(candidate_features$feature_fingerprints, use.names = FALSE)
  sort(unique(as.character(values)), method = "radix")
}

ledgr_sweep_telemetry_env <- function() {
  telemetry <- new.env(parent = emptyenv())
  telemetry$t_pre <- NA_real_
  telemetry$t_post <- NA_real_
  telemetry$t_loop <- NA_real_
  telemetry$t_engine <- NA_real_
  telemetry$t_results <- NA_real_
  telemetry$t_fills_extract <- NA_real_
  telemetry$telemetry_stride <- 0L
  telemetry$telemetry_samples <- 0L
  telemetry$t_pulse <- numeric()
  telemetry$t_bars <- numeric()
  telemetry$t_ctx <- numeric()
  telemetry$t_fill <- numeric()
  telemetry$t_state <- numeric()
  telemetry$t_feats <- numeric()
  telemetry$t_strat <- numeric()
  telemetry$t_target <- numeric()
  telemetry$t_event <- numeric()
  telemetry$t_exec <- numeric()
  telemetry
}

ledgr_sweep_availability_config <- function(exp) {
  list(
    data = list(snapshot_id = exp$snapshot$snapshot_id),
    universe = list(instrument_ids = exp$universe),
    history_policy = exp$history_policy,
    availability = list(
      active = TRUE,
      declared_families = exp$availability$declared_families,
      universe_rule = if (is.null(exp$universe_rule)) NULL else unclass(exp$universe_rule),
      valuation_policy = unclass(exp$valuation_policy),
      provider_version = ledgr_availability_provider_version(),
      execution_timing_version = ledgr_availability_execution_timing_rule_version
    )
  )
}

ledgr_sweep_align_availability_bars <- function(bars_by_id, universe, pulses_posix) {
  out <- vector("list", length(universe))
  names(out) <- universe
  for (id in universe) {
    bars <- bars_by_id[[id]]
    aligned <- data.frame(
      instrument_id = rep(id, length(pulses_posix)),
      ts_utc = as.POSIXct(pulses_posix, tz = "UTC"),
      open = NA_real_,
      high = NA_real_,
      low = NA_real_,
      close = NA_real_,
      volume = NA_real_,
      gap_type = rep("MISSING_EXPECTED_SESSION", length(pulses_posix)),
      is_synthetic = rep(FALSE, length(pulses_posix)),
      stringsAsFactors = FALSE
    )
    if (!is.null(bars) && nrow(bars) > 0L) {
      bars <- bars[order(bars$ts_utc), , drop = FALSE]
      matched <- match(as.POSIXct(bars$ts_utc, tz = "UTC"), pulses_posix)
      keep <- !is.na(matched)
      aligned[matched[keep], names(bars)] <- bars[keep, names(bars), drop = FALSE]
      aligned$instrument_id <- rep(id, nrow(aligned))
      aligned$ts_utc <- as.POSIXct(pulses_posix, tz = "UTC")
    }
    out[[id]] <- aligned
  }
  out
}

ledgr_sweep_normalize_bars_by_id <- function(bars_by_id, universe) {
  for (id in universe) {
    b <- bars_by_id[[id]]
    if (is.null(b)) next
    b <- b[order(b$ts_utc), , drop = FALSE]
    if (!"gap_type" %in% names(b)) {
      b$gap_type <- ""
    }
    if (!"is_synthetic" %in% names(b)) {
      b$is_synthetic <- FALSE
    }
    bars_by_id[[id]] <- b
  }
  bars_by_id
}

ledgr_sweep_bars_matrix <- function(bars_by_id, universe) {
  first <- bars_by_id[[universe[[1L]]]]
  n_inst <- length(universe)
  n_pulses <- nrow(first)
  out <- list(
    open = matrix(NA_real_, nrow = n_inst, ncol = n_pulses),
    high = matrix(NA_real_, nrow = n_inst, ncol = n_pulses),
    low = matrix(NA_real_, nrow = n_inst, ncol = n_pulses),
    close = matrix(NA_real_, nrow = n_inst, ncol = n_pulses),
    volume = matrix(NA_real_, nrow = n_inst, ncol = n_pulses),
    gap_type = matrix("", nrow = n_inst, ncol = n_pulses),
    is_synthetic = matrix(FALSE, nrow = n_inst, ncol = n_pulses)
  )
  for (j in seq_along(universe)) {
    b <- bars_by_id[[universe[[j]]]]
    out$open[j, ] <- as.numeric(b$open)
    out$high[j, ] <- as.numeric(b$high)
    out$low[j, ] <- as.numeric(b$low)
    out$close[j, ] <- as.numeric(b$close)
    out$volume[j, ] <- as.numeric(b$volume)
    out$gap_type[j, ] <- as.character(b$gap_type)
    out$is_synthetic[j, ] <- as.logical(b$is_synthetic)
  }
  out
}

ledgr_sweep_resolved_from_precomputed <- function(precomputed, param_grid) {
  candidates <- vector("list", length(param_grid$params))
  for (i in seq_along(param_grid$params)) {
    row <- precomputed$candidate_features[i, , drop = FALSE]
    feature_ids <- row$feature_ids[[1]]
    fingerprints <- row$feature_fingerprints[[1]]
    feature_defs <- Map(function(id, fingerprint) {
      list(id = id, fingerprint = fingerprint)
    }, feature_ids, fingerprints)
    candidates[[i]] <- list(
      label = param_grid$labels[[i]],
      params = param_grid$params[[i]],
      feature_defs = feature_defs,
      feature_ids = feature_ids,
      fingerprints = fingerprints,
      feature_set_hash = row$feature_set_hash[[1]],
      alias_map = if ("alias_map" %in% names(row)) row$alias_map[[1]] else NULL,
      alias_map_json = if ("alias_map_json" %in% names(row)) row$alias_map_json[[1]] else NA_character_,
      alias_map_hash = if ("alias_map_hash" %in% names(row)) row$alias_map_hash[[1]] else NA_character_,
      alias_map_version = if ("alias_map_version" %in% names(row)) row$alias_map_version[[1]] else NA_integer_
    )
  }
  list(candidates = candidates, candidate_features = precomputed$candidate_features)
}
