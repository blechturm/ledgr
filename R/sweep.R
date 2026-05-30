.ledgr_sweep_id_state <- new.env(parent = emptyenv())
.ledgr_sweep_id_state$counter <- 0L

#' Run a parameter sweep
#'
#' `ledgr_sweep()` evaluates a `ledgr_param_grid` against a `ledgr_experiment`
#' without writing candidate runs to the experiment store. Sweep is an
#' exploratory surface: it returns candidate summaries, does not rank candidates
#' automatically, and does not create committed run artifacts.
#'
#' @param exp A `ledgr_experiment`.
#' @param param_grid A `ledgr_param_grid`.
#' @param precomputed_features Optional `ledgr_precomputed_features` object.
#' @param seed Optional integer-like master seed. When supplied, each candidate
#'   receives a deterministic derived execution seed.
#' @param stop_on_error Logical. When `FALSE`, candidate-level execution errors
#'   are captured as failed rows; when `TRUE`, they are rethrown.
#' @param workers Whole-number worker count. The default `1` uses the
#'   sequential reference path. Values greater than `1` dispatch candidates
#'   through the optional `mirai` backend.
#' @param worker_packages Optional character vector of packages to attach on
#'   parallel workers for unqualified package calls in strategy code.
#' @return A `ledgr_sweep_results` tibble.
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
#'
#' Failed candidates are retained as rows when `stop_on_error = FALSE`. Contract
#' errors such as invalid grids, invalid precomputed feature payloads, and Tier 3
#' strategy preflight failures still abort. Compatibility note: old
#' feature-factory experiments use a flat parameter-grid contract. Executable
#' grids with separate `feature_params` require active aliases through
#' `ledgr_feature_map()`. Failed rows can be inspected with
#' `ledgr_candidate(..., allow_failed = TRUE)`, but [ledgr_promote()] rejects
#' failed candidates. When `stop_on_error = TRUE` rethrows a strategy failure,
#' assert with `inherits(e, "ledgr_strategy_error")` rather than exact
#' class-vector equality.
#'
#' Current sweep mode intentionally does not ship automatic ranking,
#' `ledgr_tune()`, walk-forward/PBO/CSCV helpers, risk-layer insertion, public
#' cost-model factories, paper/live adapters, intraday-specific support, or
#' full sweep artifact persistence.
#'
#' @section Articles:
#' Exploratory sweeps and promotion:
#' `vignette("sweeps", package = "ledgr")`
#' `system.file("doc", "sweeps.html", package = "ledgr")`
#' @export
ledgr_sweep <- function(exp,
                        param_grid,
                        precomputed_features = NULL,
                        seed = NULL,
                        stop_on_error = FALSE,
                        workers = 1L,
                        worker_packages = NULL) {
  if (!inherits(exp, "ledgr_experiment")) {
    rlang::abort("`exp` must be a ledgr_experiment object.", class = "ledgr_invalid_args")
  }
  if (!inherits(param_grid, "ledgr_param_grid")) {
    rlang::abort("`param_grid` must be a ledgr_param_grid object.", class = "ledgr_invalid_args")
  }
  if (!is.logical(stop_on_error) || length(stop_on_error) != 1L || is.na(stop_on_error)) {
    rlang::abort("`stop_on_error` must be TRUE or FALSE.", class = "ledgr_invalid_args")
  }
  workers <- ledgr_parallel_workers_normalize(workers)
  seed <- ledgr_seed_normalize(seed)

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
      resolve_features = FALSE
    )
  }

  meta <- ledgr_precompute_snapshot_meta(exp$snapshot)
  range <- ledgr_precompute_scoring_range(meta)
  bars_by_id <- ledgr_precompute_fetch_bars(
    exp$snapshot,
    exp$universe,
    range$warmup_start,
    range$scoring_end
  )
  bars_by_id <- ledgr_sweep_normalize_bars_by_id(bars_by_id, exp$universe)
  ledgr_precompute_validate_static_coverage(bars_by_id, exp$universe)
  bars_mat <- ledgr_sweep_bars_matrix(bars_by_id, exp$universe)
  pulses_posix <- as.POSIXct(bars_by_id[[exp$universe[[1L]]]]$ts_utc, tz = "UTC")
  pulses_iso <- format(pulses_posix, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  static_bars_views <- ledgr_bars_pulse_views(
    bars_mat = bars_mat,
    instrument_ids = exp$universe,
    pulses_posix = pulses_posix
  )
  metric_context <- ledgr_metric_context_resolve(exp$metric_context)
  metric_kernel <- ledgr_metric_kernel(context = metric_context, pulses = pulses_posix)

  if (is.null(precomputed_features)) {
    resolved <- ledgr_resolve_feature_candidates(exp, param_grid, stop_on_error = FALSE)
    runtime_projection <- ledgr_projection_from_payload(
      payload = ledgr_precompute_payload(
        ledgr_precompute_unique_feature_defs(resolved$candidates),
        bars_by_id
      ),
      universe = exp$universe,
      pulses_posix = pulses_posix,
      feature_engine_version = ledgr_feature_engine_version(),
      alias_index = NULL
    )
  } else {
    resolved <- ledgr_sweep_resolved_from_precomputed(precomputed_features, param_grid)
    runtime_projection <- precomputed_features$projection
    if (is.null(runtime_projection)) {
      runtime_projection <- ledgr_projection_from_payload(
        payload = precomputed_features$payload,
        universe = exp$universe,
        pulses_posix = pulses_posix,
        feature_engine_version = precomputed_features$feature_engine_version,
        alias_index = NULL
      )
    }
  }

  sweep_id <- ledgr_generate_sweep_id()
  rows <- vector("list", length(param_grid$params))
  source_info <- ledgr_strategy_source_info(exp$strategy)
  strategy_hash <- source_info$hash
  strategy_name <- ledgr_sweep_strategy_name(exp$strategy)
  tasks <- ledgr_sweep_candidate_tasks(
    exp = exp,
    param_grid = param_grid,
    resolved = resolved,
    seed = seed,
    bars_by_id = bars_by_id,
    bars_mat = bars_mat,
    static_bars_views = static_bars_views,
    pulses_posix = pulses_posix,
    pulses_iso = pulses_iso,
    metric_kernel = metric_kernel,
    precomputed_features = precomputed_features,
    runtime_projection = runtime_projection,
    snapshot_hash = meta$snapshot_hash,
    strategy_hash = strategy_hash
  )
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

  out <- tibble::as_tibble(do.call(rbind, rows))
  feature_union <- ledgr_sweep_feature_union(resolved$candidate_features)
  attr(out, "sweep_id") <- sweep_id
  attr(out, "snapshot_id") <- exp$snapshot$snapshot_id
  attr(out, "snapshot_hash") <- meta$snapshot_hash
  attr(out, "scoring_range") <- list(start = range$scoring_start, end = range$scoring_end)
  attr(out, "universe") <- exp$universe
  attr(out, "master_seed") <- seed
  attr(out, "seed_contract") <- "ledgr_seed_v1"
  attr(out, "evaluation_scope") <- "exploratory"
  attr(out, "strategy_hash") <- strategy_hash
  attr(out, "strategy_name") <- strategy_name
  attr(out, "strategy_source_capture_method") <- source_info$capture_method
  attr(out, "strategy_preflight") <- preflight
  attr(out, "feature_union") <- feature_union
  attr(out, "feature_union_hash") <- ledgr_feature_set_hash(feature_union)
  attr(out, "feature_engine_version") <- runtime_projection$feature_engine_version
  attr(out, "candidate_features") <- resolved$candidate_features
  attr(out, "metric_context") <- metric_context
  attr(out, "metric_context_hash") <- ledgr_metric_context_hash(metric_context)
  attr(out, "metric_context_version") <- as.integer(metric_context$metric_context_version)
  attr(out, "execution_assumptions") <- list(
    execution_mode = exp$execution_mode,
    fill_model = exp$fill_model,
    opening = exp$opening,
    precomputed_features = !is.null(precomputed_features),
    stop_on_error = stop_on_error
  )
  class(out) <- c("ledgr_sweep_results", class(out))
  out
}

#' Select one sweep candidate for promotion
#'
#' Selects a single row from a sweep result table and packages its params, seed,
#' and provenance for promotion or inspection.
#'
#' @param results A `ledgr_sweep_results` object or tibble-like object with
#'   `run_id`, `params`, `execution_seed`, and `provenance` columns.
#' @param which Candidate selector. A character scalar selects by `run_id`; an
#'   integer-like scalar selects by row position.
#' @param allow_failed Logical. Failed candidates error by default.
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
ledgr_candidate <- function(results, which = 1L, allow_failed = FALSE) {
  if (!is.logical(allow_failed) || length(allow_failed) != 1L || is.na(allow_failed)) {
    rlang::abort("`allow_failed` must be TRUE or FALSE.", class = "ledgr_invalid_args")
  }
  is_sweep_results <- inherits(results, "ledgr_sweep_results")
  view <- tibble::as_tibble(results)
  required <- c("run_id", "params", "execution_seed", "provenance")
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
  if (!isTRUE(allow_failed) && identical(status, "FAILED")) {
    rlang::abort(
      sprintf("Candidate '%s' has status FAILED. Use `allow_failed = TRUE` for diagnostic extraction.", row$run_id[[1]]),
      class = "ledgr_failed_sweep_candidate"
    )
  }

  if (!is_sweep_results) {
    message("Note: input is not a `ledgr_sweep_results` object; sweep-level metadata will not be available in the candidate.")
  }

  sweep_meta <- ledgr_candidate_sweep_meta(results, is_sweep_results)
  out <- list(
    run_id = as.character(row$run_id[[1]]),
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

  structure(
    list(
      reproduction_key_version = "ledgr_candidate_reproduction_key_v1",
      source_sweep = list(
        sweep_id = meta$sweep_id %||% NULL,
        evaluation_scope = meta$evaluation_scope %||% provenance$evaluation_scope %||% NULL
      ),
      candidate = list(
        run_id = candidate$run_id,
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
    ),
    class = c("ledgr_candidate_reproduction_key", "list")
  )
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
#'
#' The default `require_same_snapshot = TRUE` protects same-snapshot replay. For
#' train/test evaluation, pass a candidate selected on the train snapshot to a
#' test-snapshot experiment and set `require_same_snapshot = FALSE` deliberately.
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
  if (identical(candidate$status, "FAILED")) {
    rlang::abort(
      sprintf(
        "Cannot promote failed candidate '%s'. Use `allow_failed = TRUE` only for diagnostic extraction.",
        candidate$run_id
      ),
      class = "ledgr_promote_failed_candidate"
    )
  }

  if (isTRUE(require_same_snapshot)) {
    ledgr_candidate_validate_same_snapshot(exp, candidate)
  }

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
  ledgr_promote_write_context_or_warn(bt, candidate, note)
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
  cat("Run label:        ", x$run_id, "\n", sep = "")
  cat("Status:           ", x$status %||% NA_character_, "\n", sep = "")
  cat("Execution seed:   ", seed, "\n", sep = "")
  cat("Strategy:         ", strategy, "\n", sep = "")
  cat("Snapshot hash:    ", snapshot_hash, "\n", sep = "")
  cat("Feature-set hash: ", feature_hash, "\n", sep = "")
  cat("Evaluation scope: ", evaluation_scope, "\n", sep = "")
  cat("Params:           ", canonical_json(x$params), "\n", sep = "")
  invisible(x)
}

#' Print sweep results
#'
#' @param x A `ledgr_sweep_results` object.
#' @param ... Passed to the tibble print method.
#' @return The input object, invisibly.
#' @export
print.ledgr_sweep_results <- function(x, ...) {
  status <- as.character(x$status)
  n_done <- sum(status == "DONE", na.rm = TRUE)
  n_failed <- sum(status == "FAILED", na.rm = TRUE)
  visible <- c(
    "run_id", "status", "sharpe_ratio", "total_return",
    "max_drawdown", "n_trades", "execution_seed"
  )
  hidden <- setdiff(names(x), visible)
  ledgr_print_curated_tibble(
    sprintf("# ledgr sweep -- %s", attr(x, "sweep_id") %||% "<unknown>"),
    x,
    cols = visible,
    footer = c(
      sprintf("%d combinations: %d done, %d failed.", nrow(x), n_done, n_failed),
      "Rows are printed in their current table order; rank or arrange explicitly before selecting candidates.",
      sprintf("Hidden columns (%d): %s", length(hidden), paste(hidden, collapse = ", "))
    ),
    ...
  )
}

ledgr_candidate_row_index <- function(view, which) {
  if (is.character(which) && length(which) == 1L && !is.na(which) && nzchar(which)) {
    matches <- base::which(as.character(view$run_id) == which)
    if (length(matches) != 1L) {
      rlang::abort(
        sprintf("Expected exactly one candidate with run_id '%s'; found %d.", which, length(matches)),
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
  rlang::abort("`which` must be a character run_id or integer row position.", class = "ledgr_invalid_args")
}

ledgr_candidate_sweep_meta <- function(results, is_sweep_results) {
  if (!isTRUE(is_sweep_results)) {
    return(NULL)
  }
  keys <- c(
    "sweep_id", "snapshot_id", "snapshot_hash", "scoring_range", "universe",
    "master_seed", "seed_contract", "evaluation_scope", "strategy_hash",
    "strategy_name", "strategy_source_capture_method", "strategy_preflight",
    "feature_union", "feature_union_hash", "feature_engine_version", "metric_context",
    "metric_context_hash", "metric_context_version", "execution_assumptions"
  )
  stats::setNames(lapply(keys, function(key) attr(results, key, exact = TRUE)), keys)
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
                                        precomputed_features,
                                        runtime_projection,
                                        snapshot_hash,
                                        strategy_hash) {
  exp_payload <- ledgr_sweep_exp_payload(exp)
  tasks <- vector("list", length(param_grid$params))
  for (i in seq_along(param_grid$params)) {
    label <- param_grid$labels[[i]]
    raw_params <- param_grid$params[[i]]
    tasks[[i]] <- list(
      index = i,
      exp = exp_payload,
      run_id = label,
      raw_params = raw_params,
      params = ledgr_grid_candidate_strategy_params(raw_params),
      feature_params = ledgr_grid_candidate_feature_params(raw_params),
      execution_seed = if (is.null(seed)) {
        NA_integer_
      } else {
        ledgr_derive_seed(seed, list(run_id = label, params = raw_params))
      },
      bars_by_id = bars_by_id,
      bars_mat = bars_mat,
      static_bars_views = static_bars_views,
      pulses_posix = pulses_posix,
      pulses_iso = pulses_iso,
      metric_kernel = metric_kernel,
      candidate = resolved$candidates[[i]],
      candidate_feature_row = resolved$candidate_features[i, , drop = FALSE],
      precomputed_features = precomputed_features,
      runtime_projection = runtime_projection,
      snapshot_hash = snapshot_hash,
      strategy_hash = strategy_hash,
      master_seed = seed
    )
  }
  tasks
}

ledgr_sweep_exp_payload <- function(exp) {
  list(
    strategy = exp$strategy,
    universe = exp$universe,
    opening = exp$opening,
    fill_model = exp$fill_model
  )
}

ledgr_sweep_eval_candidate_task <- function(task, stop_on_error = FALSE) {
  feature_row <- task$candidate_feature_row
  if (identical(feature_row$status[[1]], "failed")) {
    if (isTRUE(stop_on_error)) {
      stop(task$candidate$error)
    }
    row <- ledgr_sweep_failure_row(
      run_id = task$run_id,
      params = task$params,
      feature_params = task$feature_params,
      execution_seed = task$execution_seed,
      error_class = feature_row$error_class[[1]],
      error_msg = feature_row$error_msg[[1]],
      feature_fingerprints = feature_row$feature_fingerprints[[1]],
      provenance = ledgr_sweep_provenance(
        snapshot_hash = task$snapshot_hash,
        strategy_hash = task$strategy_hash,
        feature_set_hash = feature_row$feature_set_hash[[1]],
        alias_map_json = feature_row$alias_map_json[[1]],
        alias_map_hash = feature_row$alias_map_hash[[1]],
        alias_map_version = feature_row$alias_map_version[[1]],
        master_seed = task$master_seed
      ),
      warnings = list()
    )
    return(list(row = row, warnings = list(), error = task$candidate$error))
  }

  warnings <- list()
  err <- NULL
  row <- tryCatch(
    withCallingHandlers(
      ledgr_sweep_run_candidate(
        exp = task$exp,
        run_id = task$run_id,
        params = task$params,
        feature_params = task$feature_params,
        execution_seed = task$execution_seed,
        bars_by_id = task$bars_by_id,
        bars_mat = task$bars_mat,
        static_bars_views = task$static_bars_views,
        pulses_posix = task$pulses_posix,
        pulses_iso = task$pulses_iso,
        metric_kernel = task$metric_kernel,
        candidate = task$candidate,
        candidate_feature_row = feature_row,
        precomputed_features = task$precomputed_features,
        runtime_projection = task$runtime_projection,
        snapshot_hash = task$snapshot_hash,
        strategy_hash = task$strategy_hash,
        master_seed = task$master_seed
      ),
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
      ledgr_sweep_failure_row(
        run_id = task$run_id,
        params = task$raw_params,
        execution_seed = task$execution_seed,
        error_class = ledgr_condition_class(e),
        error_msg = conditionMessage(e),
        feature_fingerprints = feature_row$feature_fingerprints[[1]],
        provenance = ledgr_sweep_provenance(
          snapshot_hash = task$snapshot_hash,
          strategy_hash = task$strategy_hash,
          feature_set_hash = feature_row$feature_set_hash[[1]],
          alias_map_json = feature_row$alias_map_json[[1]],
          alias_map_hash = feature_row$alias_map_hash[[1]],
          alias_map_version = feature_row$alias_map_version[[1]],
          master_seed = task$master_seed
        ),
        warnings = warnings
      )
    }
  )
  row$warnings[[1]] <- warnings
  list(row = row, warnings = warnings, error = err)
}

ledgr_sweep_eval_candidate_tasks_parallel <- function(tasks, workers) {
  workers <- ledgr_parallel_workers_normalize(workers)
  if (length(tasks) == 0L) {
    return(list())
  }
  mirai <- getExportedValue("mirai", "mirai")
  promises <- lapply(tasks, function(task) {
    mirai(
      {
        get("ledgr_sweep_worker_eval_candidate_task", envir = asNamespace("ledgr"))(task)
      },
      task = task
    )
  })
  lapply(seq_along(promises), function(i) {
    result <- promises[[i]][]
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
}

ledgr_sweep_worker_eval_candidate_task <- function(task) {
  ledgr_sweep_eval_candidate_task(task, stop_on_error = FALSE)
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
                                      precomputed_features,
                                      runtime_projection,
                                      snapshot_hash,
                                      strategy_hash,
                                      master_seed) {
  feature_defs <- candidate$feature_defs
  feature_fingerprints <- candidate_feature_row$feature_fingerprints[[1]]
  if (is.null(runtime_projection)) {
    rlang::abort("Sweep candidate execution requires `runtime_projection`.", class = "ledgr_invalid_fold_execution")
  }

  output_handler <- ledgr_memory_output_handler(run_id)
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
  telemetry <- ledgr_sweep_telemetry_env()
  cost_resolver <- ledgr_cost_spread_commission_internal(
    spread_bps = exp$fill_model$spread_bps,
    commission_fixed = exp$fill_model$commission_fixed
  )
  signature <- ledgr_strategy_signature(exp$strategy)
  execution <- ledgr_execution_spec(
    run_id = run_id,
    instrument_ids = exp$universe,
    strategy_fn = exp$strategy,
    strategy_params = params,
    strategy_call_signature = signature,
    strategy_is_functional = TRUE,
    pulses_posix = pulses_posix,
    pulses_iso = pulses_iso,
    start_idx = 1L,
    max_pulses = Inf,
    checkpoint_every = 0L,
    telemetry_stride = 0L,
    state = list(cash = exp$opening$cash, positions = initial_positions),
    state_prev = NULL,
    bars_by_id = bars_by_id,
    bars_mat = bars_mat,
    static_bars_views = static_bars_views,
    static_feature_views = NULL,
    feature_defs = feature_defs,
    runtime_projection = runtime_projection,
    active_alias_map = candidate$alias_map,
    cost_resolver = cost_resolver,
    event_seq_start = as.integer(nrow(opening_rows)) + 1L,
    telemetry = telemetry,
    seed = if (is.na(execution_seed)) NULL else execution_seed,
    event_mode = "buffered",
    use_fast_context = TRUE
  )
  ledgr_execute_fold(execution, output_handler)

  events <- if (is.function(output_handler$typed_events)) {
    output_handler$typed_events()
  } else {
    output_handler$events()
  }
  summary <- ledgr_sweep_summary_from_ordered_events(
    events = events,
    pulses_posix = pulses_posix,
    close_mat = bars_mat$close,
    initial_cash = exp$opening$cash,
    instrument_ids = exp$universe,
    run_id = run_id,
    metric_kernel = metric_kernel
  )

  ledgr_sweep_success_row(
    run_id = run_id,
    params = params,
    feature_params = feature_params,
    execution_seed = execution_seed,
    final_equity = summary$final_equity,
    metrics = summary$metrics,
    feature_fingerprints = feature_fingerprints,
    provenance = ledgr_sweep_provenance(
      snapshot_hash = snapshot_hash,
      strategy_hash = strategy_hash,
      feature_set_hash = candidate_feature_row$feature_set_hash[[1]],
      alias_map_json = candidate_feature_row$alias_map_json[[1]],
      alias_map_hash = candidate_feature_row$alias_map_hash[[1]],
      alias_map_version = candidate_feature_row$alias_map_version[[1]],
      master_seed = master_seed
    ),
    warnings = list()
  )
}

ledgr_memory_output_handler <- function(run_id) {
  state <- new.env(parent = emptyenv())
  state$event_count <- 0L
  state$event_capacity <- 0L
  state$event_max_capacity <- .Machine$integer.max
  state$event_cols <- NULL
  state$status <- "RUNNING"
  handler <- list()

  init_event_cols <- function(capacity) {
    state$event_capacity <- as.integer(max(0L, capacity))
    state$event_cols <- list(
      event_id = character(state$event_capacity),
      run_id = character(state$event_capacity),
      ts_utc = as.POSIXct(rep(NA_character_, state$event_capacity), tz = "UTC"),
      event_type = character(state$event_capacity),
      instrument_id = character(state$event_capacity),
      side = character(state$event_capacity),
      qty = numeric(state$event_capacity),
      price = numeric(state$event_capacity),
      fee = numeric(state$event_capacity),
      meta_json = character(state$event_capacity),
      event_seq = integer(state$event_capacity),
      cash_delta = numeric(state$event_capacity),
      position_delta = numeric(state$event_capacity),
      meta = vector("list", state$event_capacity)
    )
    invisible(TRUE)
  }

  ensure_event_capacity <- function(required) {
    required <- as.integer(required)
    next_capacity <- ledgr_event_buffer_next_capacity(
      current_capacity = state$event_capacity,
      required = required,
      max_events = state$event_max_capacity
    )
    if (required <= state$event_capacity) {
      return(invisible(TRUE))
    }
    old_cols <- state$event_cols
    old_count <- state$event_count
    init_event_cols(next_capacity)
    if (!is.null(old_cols) && old_count > 0L) {
      idx <- seq_len(old_count)
      for (name in names(old_cols)) {
        state$event_cols[[name]][idx] <- old_cols[[name]][idx]
      }
    }
    invisible(TRUE)
  }

  append_event_row_list <- function(row,
                                    cash_delta = NA_real_,
                                    position_delta = NA_real_,
                                    meta = NULL) {
    ensure_event_capacity(state$event_count + 1L)
    state$event_count <- state$event_count + 1L
    i <- state$event_count
    state$event_cols$event_id[[i]] <- row$event_id
    state$event_cols$run_id[[i]] <- row$run_id
    state$event_cols$ts_utc[[i]] <- row$ts_utc
    state$event_cols$event_type[[i]] <- row$event_type
    state$event_cols$instrument_id[[i]] <- row$instrument_id
    state$event_cols$side[[i]] <- row$side
    state$event_cols$qty[[i]] <- as.numeric(row$qty)
    state$event_cols$price[[i]] <- as.numeric(row$price)
    state$event_cols$fee[[i]] <- as.numeric(row$fee)
    state$event_cols$meta_json[[i]] <- row$meta_json
    state$event_cols$event_seq[[i]] <- as.integer(row$event_seq)
    state$event_cols$cash_delta[[i]] <- as.numeric(cash_delta)
    state$event_cols$position_delta[[i]] <- as.numeric(position_delta)
    state$event_cols$meta[i] <- list(meta)
    invisible(TRUE)
  }

  event_meta_json <- function(i, include_meta_json) {
    value <- state$event_cols$meta_json[[i]]
    # Typed consumers intentionally keep fill metadata as parsed lists. Legacy
    # materialization serializes those lists only when a caller asks for rows.
    if (!isTRUE(include_meta_json) || (is.character(value) && length(value) == 1L && !is.na(value) && nzchar(value))) {
      return(value)
    }
    meta <- state$event_cols$meta[[i]]
    if (is.null(meta)) {
      meta <- list(
        cash_delta = as.numeric(state$event_cols$cash_delta[[i]]),
        position_delta = as.numeric(state$event_cols$position_delta[[i]]),
        realized_pnl = NULL
      )
    }
    canonical_json(meta)
  }

  materialize_events <- function(include_meta_json = TRUE) {
    if (is.null(state$event_cols) || state$event_count == 0L) {
      return(ledgr_empty_event_table())
    }
    idx <- seq_len(state$event_count)
    meta_json <- vapply(idx, event_meta_json, character(1), include_meta_json = include_meta_json)
    out <- tibble::as_tibble(data.frame(
      event_id = state$event_cols$event_id[idx],
      run_id = state$event_cols$run_id[idx],
      ts_utc = state$event_cols$ts_utc[idx],
      event_type = state$event_cols$event_type[idx],
      instrument_id = state$event_cols$instrument_id[idx],
      side = state$event_cols$side[idx],
      qty = state$event_cols$qty[idx],
      price = state$event_cols$price[idx],
      fee = state$event_cols$fee[idx],
      meta_json = meta_json,
      event_seq = state$event_cols$event_seq[idx],
      stringsAsFactors = FALSE
    ))
    attr(out, "ledgr_event_cash_delta") <- state$event_cols$cash_delta[idx]
    attr(out, "ledgr_event_position_delta") <- state$event_cols$position_delta[idx]
    attr(out, "ledgr_event_meta") <- state$event_cols$meta[idx]
    class(out) <- unique(c("ledgr_memory_events", class(out)))
    out
  }

  handler$run_transaction <- function(fn) fn()
  handler$record_run_status <- function(status, error_msg = NA_character_) {
    state$status <- status
    state$error_msg <- error_msg
    invisible(TRUE)
  }
  handler$write_telemetry <- function(...) invisible(TRUE)
  handler$store_session_telemetry <- function(...) invisible(TRUE)
  handler$record_failure <- function(msg) {
    handler$record_run_status("FAILED", msg)
    invisible(TRUE)
  }
  handler$abort_run <- function(msg, class = "ledgr_run_failed") {
    handler$record_failure(msg)
    rlang::abort(msg, class = class)
  }
  handler$init_buffers <- function(max_events) {
    state$event_max_capacity <- ledgr_event_buffer_checked_capacity(
      state$event_count + as.integer(max_events),
      "`max_events`"
    )
    ensure_event_capacity(state$event_count + 1L)
    invisible(TRUE)
  }
  handler$append_event_rows <- function(rows) {
    if (!is.null(rows) && nrow(rows) > 0L) {
      n <- nrow(rows)
      start <- state$event_count + 1L
      end <- state$event_count + n
      ensure_event_capacity(end)
      idx <- start:end
      state$event_cols$event_id[idx] <- as.character(rows$event_id)
      state$event_cols$run_id[idx] <- as.character(rows$run_id)
      state$event_cols$ts_utc[idx] <- as.POSIXct(rows$ts_utc, tz = "UTC")
      state$event_cols$event_type[idx] <- as.character(rows$event_type)
      state$event_cols$instrument_id[idx] <- as.character(rows$instrument_id)
      state$event_cols$side[idx] <- as.character(rows$side)
      state$event_cols$qty[idx] <- as.numeric(rows$qty)
      state$event_cols$price[idx] <- as.numeric(rows$price)
      state$event_cols$fee[idx] <- as.numeric(rows$fee)
      state$event_cols$meta_json[idx] <- as.character(rows$meta_json)
      state$event_cols$event_seq[idx] <- as.integer(rows$event_seq)
      for (j in seq_len(n)) {
        meta <- ledgr_lot_parse_meta(rows$meta_json[[j]])
        pos <- start + j - 1L
        state$event_cols$meta[pos] <- list(meta)
        state$event_cols$cash_delta[[pos]] <- as.numeric(meta$cash_delta %||% NA_real_)
        state$event_cols$position_delta[[pos]] <- as.numeric(meta$position_delta %||% NA_real_)
      }
      state$event_count <- end
    }
    invisible(TRUE)
  }
  handler$buffer_event <- function(write_res) {
    if (inherits(write_res, "ledgr_ledger_write_result") &&
        identical(write_res$status, "WROTE")) {
      append_event_row_list(
        write_res$row,
        cash_delta = write_res$cash_delta,
        position_delta = write_res$position_delta,
        meta = write_res$meta
      )
    }
    invisible(TRUE)
  }
  handler$pending_event_count <- function() 0L
  handler$flush_pending <- function() invisible(TRUE)
  handler$write_fill_events <- function(fill_intent, event_seq, use_transaction = FALSE) {
    write_res <- ledgr_fill_event_payload(
      run_id = run_id,
      fill_intent = fill_intent,
      event_seq = event_seq,
      serialize_meta_json = FALSE
    )
    handler$buffer_event(write_res)
    write_res
  }
  handler$buffer_strategy_state <- function(...) invisible(TRUE)
  handler$write_strategy_state <- function(...) invisible(TRUE)
  handler$typed_events <- function() {
    materialize_events(include_meta_json = FALSE)
  }
  handler$events <- function() {
    materialize_events(include_meta_json = TRUE)
  }
  structure(handler, class = "ledgr_memory_output_handler")
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

ledgr_sweep_success_row <- function(run_id,
                                    params,
                                    feature_params = list(),
                                    execution_seed,
                                    final_equity,
                                    metrics,
                                    feature_fingerprints,
                                    provenance,
                                    warnings) {
  ledgr_sweep_row(
    run_id = run_id,
    status = "DONE",
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
    provenance = provenance
  )
}

ledgr_sweep_failure_row <- function(run_id,
                                    params,
                                    feature_params = list(),
                                    execution_seed,
                                    error_class,
                                    error_msg,
                                    feature_fingerprints,
                                    provenance,
                                    warnings) {
  ledgr_sweep_row(
    run_id = run_id,
    status = "FAILED",
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
    provenance = provenance
  )
}

ledgr_sweep_row <- function(run_id,
                            status,
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
                            provenance) {
  tibble::tibble(
    run_id = run_id,
    status = status,
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
    provenance = list(provenance)
  )
}

ledgr_sweep_provenance <- function(snapshot_hash,
                                   strategy_hash,
                                   feature_set_hash,
                                   alias_map_json = NA_character_,
                                   alias_map_hash = NA_character_,
                                   alias_map_version = NA_integer_,
                                   master_seed) {
  list(
    provenance_version = "ledgr_provenance_v1",
    snapshot_hash = snapshot_hash,
    strategy_hash = strategy_hash,
    feature_set_hash = feature_set_hash,
    alias_map_json = alias_map_json,
    alias_map_hash = alias_map_hash,
    alias_map_version = alias_map_version,
    master_seed = master_seed,
    seed_contract = "ledgr_seed_v1",
    evaluation_scope = "exploratory"
  )
}

ledgr_sweep_feature_union <- function(candidate_features) {
  if (!"feature_fingerprints" %in% names(candidate_features)) {
    return(character())
  }
  values <- unlist(candidate_features$feature_fingerprints, use.names = FALSE)
  sort(unique(as.character(values)))
}

ledgr_sweep_telemetry_env <- function() {
  telemetry <- new.env(parent = emptyenv())
  telemetry$t_pre <- NA_real_
  telemetry$t_post <- NA_real_
  telemetry$t_loop <- NA_real_
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
  telemetry$feature_cache_hits <- 0L
  telemetry$feature_cache_misses <- 0L
  telemetry
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

ledgr_sweep_compute_feature_matrix <- function(feature_defs, bars_by_id, universe) {
  if (length(feature_defs) == 0L) {
    return(list())
  }
  def_ids <- vapply(feature_defs, function(def) def$id, character(1))
  out <- vector("list", length(feature_defs))
  for (d in seq_along(feature_defs)) {
    def <- feature_defs[[d]]
    mat <- matrix(NA_real_, nrow = length(universe), ncol = nrow(bars_by_id[[universe[[1L]]]]))
    for (j in seq_along(universe)) {
      mat[j, ] <- as.numeric(ledgr_compute_feature_series(bars_by_id[[universe[[j]]]], def))
    }
    out[[d]] <- mat
  }
  names(out) <- def_ids
  out
}

ledgr_sweep_feature_matrix_from_precomputed <- function(precomputed,
                                                        feature_fingerprints,
                                                        bars_by_id,
                                                        universe) {
  if (length(feature_fingerprints) == 0L) {
    return(list())
  }
  out <- vector("list", length(feature_fingerprints))
  feature_ids <- character(length(feature_fingerprints))
  for (d in seq_along(feature_fingerprints)) {
    fingerprint <- feature_fingerprints[[d]]
    payload <- precomputed$payload[[fingerprint]]
    if (is.null(payload)) {
      rlang::abort(
        sprintf("Missing precomputed payload for feature fingerprint %s.", fingerprint),
        class = "ledgr_precomputed_feature_mismatch"
      )
    }
    mat <- matrix(NA_real_, nrow = length(universe), ncol = nrow(bars_by_id[[universe[[1L]]]]))
    for (j in seq_along(universe)) {
      mat[j, ] <- as.numeric(payload$values[[universe[[j]]]])
    }
    out[[d]] <- mat
    feature_ids[[d]] <- payload$feature_id
  }
  names(out) <- feature_ids
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
