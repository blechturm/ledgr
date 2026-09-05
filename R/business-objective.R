ledgr_business_objective_schema_version <- 1L
ledgr_objective_criterion_schema_version <- 1L

#' Business-objective criterion chain
#'
#' `ledgr_business_objective()` composes one or more ledgr-owned criterion
#' steps with logical AND. The object is a serializable eligibility plan. It
#' does not evaluate a sweep, rank candidates, select a winner, promote a
#' candidate, or participate in run, sweep, or walk-forward identity.
#'
#' @param ... Criterion steps created by the `ledgr_objective_*()` functions.
#' @return A `ledgr_business_objective` object with ordered `criteria`,
#'   canonical `plan_json`, and `business_objective_hash` fields.
#' @examples
#' objective <- ledgr_business_objective(
#'   ledgr_objective_max_drawdown(0.20),
#'   ledgr_objective_min_trades(30),
#'   ledgr_objective_positive_trajectory(0)
#' )
#' objective
#' @export
ledgr_business_objective <- function(...) {
  criteria <- list(...)
  if (length(criteria) == 0L) {
    rlang::abort(
      "`ledgr_business_objective()` requires at least one ledgr objective criterion.",
      class = c("ledgr_invalid_business_objective", "ledgr_invalid_args")
    )
  }
  criteria <- lapply(criteria, ledgr_objective_criterion_validate)
  ids <- vapply(criteria, `[[`, character(1), "criterion_id")
  duplicate_ids <- unique(ids[duplicated(ids)])
  if (length(duplicate_ids) > 0L) {
    rlang::abort(
      sprintf("Business-objective criterion ids must be unique: %s.", paste(duplicate_ids, collapse = ", ")),
      class = c("ledgr_duplicate_objective_criterion", "ledgr_invalid_business_objective", "ledgr_invalid_args"),
      criterion_ids = duplicate_ids
    )
  }

  payload <- ledgr_business_objective_payload(criteria)
  plan_json <- as.character(canonical_json(payload))
  structure(
    list(
      business_objective_schema_version = ledgr_business_objective_schema_version,
      composition = "all_pass",
      criteria = unname(criteria),
      plan_json = plan_json,
      business_objective_hash = digest::digest(plan_json, algo = "sha256")
    ),
    class = c("ledgr_business_objective", "list")
  )
}

#' @export
print.ledgr_business_objective <- function(x, ...) {
  x <- ledgr_business_objective_validate(x)
  cat("ledgr business objective\n")
  cat("========================\n")
  cat("Composition: all criteria must pass\n")
  cat("Criteria:    ", length(x$criteria), "\n", sep = "")
  for (i in seq_along(x$criteria)) {
    criterion <- x$criteria[[i]]
    cat(i, ". ", criterion$criterion_id, " [", criterion$evidence_key, "]\n", sep = "")
  }
  cat("Hash:        ", substr(x$business_objective_hash, 1L, 12L), "\n", sep = "")
  invisible(x)
}

#' Business-objective criteria
#'
#' These constructors create ledgr-owned, serializable criterion steps for
#' [ledgr_business_objective()]. Each step thresholds already-computed evidence
#' and returns eligibility evidence only. Steps do not rank, select, promote,
#' persist, or alter execution or walk-forward identity.
#'
#' `ledgr_objective_even_trades()` divides the sweep scoring interval into four
#' equal-duration bins and measures the largest bin's share of closed trades.
#' `ledgr_objective_even_profit()` measures the largest single trade's share of
#' total absolute closed-trade realized P&L. `ledgr_objective_stable_runs()`
#' measures the longest consecutive WIN or LOSS run in `trade_seq` order;
#' BREAKEVEN rows reset a run.
#'
#' `ledgr_objective_stable_region()` implements ledgr's strict-lattice
#' operationalization of Pardo's broad-plateau idea. It is not a transcription
#' of a Pardo formula and does not support sparse or unordered parameter spaces.
#' Lattice-boundary candidates have fewer available neighbors and cannot pass
#' when `min_neighbors` exceeds that available count; the detector retains the
#' available-neighbor count as audit evidence.
#'
#' `ledgr_objective_diagnostic_threshold()` embeds a hashed snapshot of one
#' already-computed [ledgr_dsr()] or [ledgr_min_track_record()] result. It never
#' recomputes the diagnostic. Admissible columns are `dsr_probability` and
#' `status` for DSR, and `min_track_record_length` and `status` for MinTRL.
#' Numeric diagnostic thresholds treat `Inf` and `-Inf` as determinate boundary
#' evidence; missing values and `NaN` fail closed.
#'
#' @param max_concentration Finite scalar in `(0, 1]` giving the largest
#'   acceptable concentration share.
#' @param max_drawdown Finite scalar in `[0, 1]` giving the largest acceptable
#'   retained maximum drawdown.
#' @param max_streak Positive whole number giving the largest acceptable
#'   consecutive winning or losing run.
#' @param n Non-negative whole-number minimum closed-trade count.
#' @param slope_min Finite minimum slope in log-equity units per retained
#'   observation.
#' @param min_neighbors Positive whole-number minimum count of supporting
#'   Manhattan-distance-1 lattice neighbors.
#' @param metric Non-empty sweep-summary metric column used by the strict
#'   lattice detector.
#' @param direction Either `"maximize"` or `"minimize"`; values are normalized
#'   so larger detector scores are better.
#' @param parameter_columns Optional non-empty character vector naming the
#'   candidate parameter axes. `NULL` uses all resolved varying parameter
#'   columns supplied to the detector.
#' @param x A `ledgr_dsr` or `ledgr_min_track_record` result.
#' @param column An admissible candidate-level diagnostic output column.
#' @param threshold A finite numeric threshold for numeric columns, or one
#'   required status string for a `status` column.
#' @param comparison Optional comparison. Numeric defaults are `"at_least"`
#'   for `dsr_probability` and `"at_most"` for
#'   `min_track_record_length`; status columns require equality.
#' @return A classed internal-contract `ledgr_objective_criterion` object.
#' @references Pardo, R. (2008). *The Evaluation and Optimization of Trading
#'   Strategies*, Chapter 11. Stable-region adjacency and tolerance are ledgr's
#'   documented operationalization, not a Pardo-authored formula.
#' @examples
#' ledgr_objective_even_trades(0.30)
#' ledgr_objective_even_profit(0.40)
#' ledgr_objective_stable_region(min_neighbors = 2)
#' ledgr_objective_max_drawdown(0.20)
#' ledgr_objective_stable_runs(10)
#' ledgr_objective_min_trades(30)
#' ledgr_objective_positive_trajectory(0)
#' @name ledgr_objective_criteria
NULL

#' @rdname ledgr_objective_criteria
#' @export
ledgr_objective_even_trades <- function(max_concentration = 0.30) {
  ledgr_objective_criterion_new(
    "even_trades",
    "closed_trades",
    list(max_concentration = max_concentration, time_bins = 4L)
  )
}

#' @rdname ledgr_objective_criteria
#' @export
ledgr_objective_even_profit <- function(max_concentration = 0.40) {
  ledgr_objective_criterion_new(
    "even_profit",
    "closed_trades",
    list(max_concentration = max_concentration)
  )
}

#' @rdname ledgr_objective_criteria
#' @export
ledgr_objective_stable_region <- function(min_neighbors = 2L,
                                          metric = "sharpe_ratio",
                                          direction = c("maximize", "minimize"),
                                          parameter_columns = NULL) {
  direction <- match.arg(direction)
  ledgr_objective_criterion_new(
    "stable_region",
    "candidate_metric_lattice",
    list(
      min_neighbors = min_neighbors,
      metric = metric,
      direction = direction,
      parameter_columns = parameter_columns
    )
  )
}

#' @rdname ledgr_objective_criteria
#' @export
ledgr_objective_max_drawdown <- function(max_drawdown = 0.20) {
  ledgr_objective_criterion_new(
    "max_drawdown",
    "summary.max_drawdown",
    list(max_drawdown = max_drawdown)
  )
}

#' @rdname ledgr_objective_criteria
#' @export
ledgr_objective_stable_runs <- function(max_streak = 10L) {
  ledgr_objective_criterion_new(
    "stable_runs",
    "closed_trades",
    list(max_streak = max_streak)
  )
}

#' @rdname ledgr_objective_criteria
#' @export
ledgr_objective_min_trades <- function(n = 30L) {
  ledgr_objective_criterion_new(
    "min_trades",
    "summary.n_trades",
    list(n = n)
  )
}

#' @rdname ledgr_objective_criteria
#' @export
ledgr_objective_positive_trajectory <- function(slope_min = 0) {
  ledgr_objective_criterion_new(
    "positive_trajectory",
    "retained_equity",
    list(slope_min = slope_min)
  )
}

#' @rdname ledgr_objective_criteria
#' @export
ledgr_objective_diagnostic_threshold <- function(x,
                                                 column,
                                                 threshold,
                                                 comparison = NULL) {
  snapshot <- ledgr_objective_diagnostic_snapshot(x, column)
  if (is.null(comparison)) {
    comparison <- snapshot$default_comparison
  }
  criterion_id <- paste("diagnostic", snapshot$diagnostic_id, snapshot$column, sep = "_")
  ledgr_objective_criterion_new(
    criterion_id = criterion_id,
    evidence_key = paste("diagnostic", snapshot$diagnostic_id, snapshot$column, sep = "."),
    params = list(
      diagnostic_id = snapshot$diagnostic_id,
      column = snapshot$column,
      threshold = threshold,
      comparison = comparison,
      source_hash = snapshot$source_hash
    ),
    evidence_snapshot = snapshot
  )
}

#' @export
print.ledgr_objective_criterion <- function(x, ...) {
  x <- ledgr_objective_criterion_validate(x)
  cat("ledgr objective criterion\n")
  cat("Criterion: ", x$criterion_id, "\n", sep = "")
  cat("Evidence:  ", x$evidence_key, "\n", sep = "")
  cat("Hash:      ", substr(x$criterion_hash, 1L, 12L), "\n", sep = "")
  invisible(x)
}

ledgr_objective_criterion_new <- function(criterion_id,
                                          evidence_key,
                                          params,
                                          evidence_snapshot = NULL) {
  criterion_id <- ledgr_objective_validate_id(criterion_id)
  evidence_key <- ledgr_objective_validate_evidence_key(evidence_key)
  params <- ledgr_objective_normalize_params(criterion_id, params, evidence_snapshot)
  evidence_snapshot <- ledgr_objective_validate_snapshot(
    criterion_id,
    evidence_snapshot,
    params
  )
  payload <- list(
    criterion_schema_version = ledgr_objective_criterion_schema_version,
    criterion_id = criterion_id,
    evidence_key = evidence_key,
    params = params,
    evidence_snapshot = evidence_snapshot
  )
  plan_json <- tryCatch(
    as.character(canonical_json(payload)),
    error = function(e) {
      rlang::abort(
        "Objective criterion parameters must be canonically serializable.",
        class = c("ledgr_objective_non_serializable_params", "ledgr_invalid_objective_criterion", "ledgr_invalid_args"),
        parent = e
      )
    }
  )
  structure(
    list(
      criterion_schema_version = ledgr_objective_criterion_schema_version,
      criterion_id = criterion_id,
      evidence_key = evidence_key,
      params = params,
      evidence_snapshot = evidence_snapshot,
      evaluate = ledgr_objective_evaluator(criterion_id, params, evidence_snapshot),
      criterion_hash = digest::digest(plan_json, algo = "sha256")
    ),
    class = c(paste0("ledgr_objective_", criterion_id), "ledgr_objective_criterion", "list")
  )
}

ledgr_business_objective_payload <- function(criteria) {
  list(
    business_objective_schema_version = ledgr_business_objective_schema_version,
    composition = "all_pass",
    criteria = lapply(criteria, ledgr_objective_criterion_payload)
  )
}

ledgr_objective_criterion_payload <- function(criterion) {
  criterion <- ledgr_objective_criterion_validate(criterion, verify_hash = FALSE)
  list(
    criterion_schema_version = criterion$criterion_schema_version,
    criterion_id = criterion$criterion_id,
    evidence_key = criterion$evidence_key,
    params = criterion$params,
    evidence_snapshot = criterion$evidence_snapshot
  )
}

ledgr_business_objective_validate <- function(x) {
  if (!inherits(x, "ledgr_business_objective") ||
      !is.list(x) ||
      !identical(as.integer(x$business_objective_schema_version), ledgr_business_objective_schema_version) ||
      !identical(x$composition, "all_pass") ||
      !is.list(x$criteria) ||
      length(x$criteria) == 0L ||
      !is.character(x$plan_json) || length(x$plan_json) != 1L || is.na(x$plan_json) ||
      !is.character(x$business_objective_hash) || length(x$business_objective_hash) != 1L) {
    rlang::abort(
      "`x` has an invalid ledgr business-objective shape.",
      class = c("ledgr_invalid_business_objective", "ledgr_invalid_args")
    )
  }
  criteria <- lapply(x$criteria, ledgr_objective_criterion_validate)
  expected_json <- as.character(canonical_json(ledgr_business_objective_payload(criteria)))
  expected_hash <- digest::digest(expected_json, algo = "sha256")
  if (!identical(x$plan_json, expected_json) ||
      !identical(x$business_objective_hash, expected_hash)) {
    rlang::abort(
      "Business-objective plan JSON or hash does not match its criterion steps.",
      class = c("ledgr_business_objective_hash_mismatch", "ledgr_invalid_business_objective", "ledgr_invalid_args")
    )
  }
  x$criteria <- unname(criteria)
  x
}

ledgr_objective_criterion_validate <- function(x, verify_hash = TRUE) {
  if (!inherits(x, "ledgr_objective_criterion") ||
      !is.list(x) ||
      !identical(as.integer(x$criterion_schema_version), ledgr_objective_criterion_schema_version) ||
      !is.character(x$criterion_id) || length(x$criterion_id) != 1L ||
      !is.character(x$evidence_key) || length(x$evidence_key) != 1L ||
      !is.list(x$params) ||
      !is.function(x$evaluate) ||
      !is.character(x$criterion_hash) || length(x$criterion_hash) != 1L) {
    rlang::abort(
      "Expected a criterion created by a ledgr objective constructor.",
      class = c("ledgr_invalid_objective_criterion", "ledgr_invalid_args")
    )
  }
  ledgr_objective_validate_id(x$criterion_id)
  ledgr_objective_validate_evidence_key(x$evidence_key)
  params <- ledgr_objective_normalize_params(
    x$criterion_id,
    x$params,
    x$evidence_snapshot
  )
  snapshot <- ledgr_objective_validate_snapshot(
    x$criterion_id,
    x$evidence_snapshot,
    params
  )
  if (isTRUE(verify_hash)) {
    expected <- digest::digest(
      as.character(canonical_json(list(
        criterion_schema_version = x$criterion_schema_version,
        criterion_id = x$criterion_id,
        evidence_key = x$evidence_key,
        params = params,
        evidence_snapshot = snapshot
      ))),
      algo = "sha256"
    )
    if (!identical(x$criterion_hash, expected)) {
      rlang::abort(
        "Objective criterion hash does not match its serialized payload.",
        class = c("ledgr_objective_criterion_hash_mismatch", "ledgr_invalid_objective_criterion", "ledgr_invalid_args")
      )
    }
  }
  x$params <- params
  x$evidence_snapshot <- snapshot
  x$evaluate <- ledgr_objective_evaluator(x$criterion_id, params, snapshot)
  x
}

ledgr_business_objective_from_plan_json <- function(plan_json) {
  if (!is.character(plan_json) || length(plan_json) != 1L || is.na(plan_json) || !nzchar(plan_json)) {
    rlang::abort(
      "`plan_json` must be a non-empty character scalar.",
      class = c("ledgr_invalid_business_objective", "ledgr_invalid_args")
    )
  }
  payload <- tryCatch(
    ledgr_json_read_nested(plan_json),
    error = function(e) {
      rlang::abort(
        "`plan_json` is not valid business-objective JSON.",
        class = c("ledgr_invalid_business_objective", "ledgr_invalid_args"),
        parent = e
      )
    }
  )
  if (!is.list(payload) ||
      !identical(as.integer(payload$business_objective_schema_version), ledgr_business_objective_schema_version) ||
      !identical(payload$composition, "all_pass") ||
      !is.list(payload$criteria) ||
      length(payload$criteria) == 0L) {
    rlang::abort(
      "`plan_json` has an invalid business-objective payload.",
      class = c("ledgr_invalid_business_objective", "ledgr_invalid_args")
    )
  }
  criteria <- lapply(payload$criteria, function(step) {
    if (!is.list(step) ||
        !identical(as.integer(step$criterion_schema_version), ledgr_objective_criterion_schema_version)) {
      rlang::abort(
        "`plan_json` contains an invalid objective criterion payload.",
        class = c("ledgr_invalid_objective_criterion", "ledgr_invalid_business_objective", "ledgr_invalid_args")
      )
    }
    ledgr_objective_criterion_new(
      criterion_id = step$criterion_id,
      evidence_key = step$evidence_key,
      params = step$params,
      evidence_snapshot = step$evidence_snapshot
    )
  })
  do.call(ledgr_business_objective, criteria)
}

ledgr_objective_validate_id <- function(criterion_id) {
  if (!is.character(criterion_id) || length(criterion_id) != 1L ||
      is.na(criterion_id) || !grepl("^[a-z][a-z0-9_]*$", criterion_id)) {
    rlang::abort(
      "Objective criterion ids must be non-empty lower-snake-case strings.",
      class = c("ledgr_invalid_objective_criterion", "ledgr_invalid_args")
    )
  }
  known <- criterion_id %in% c(
    "even_trades", "even_profit", "stable_region", "max_drawdown",
    "stable_runs", "min_trades", "positive_trajectory"
  ) || grepl("^diagnostic_(dsr|min_track_record)_(dsr_probability|min_track_record_length|status)$", criterion_id)
  if (!known) {
    rlang::abort(
      sprintf("Unsupported ledgr objective criterion id: %s.", criterion_id),
      class = c("ledgr_unknown_objective_criterion", "ledgr_invalid_objective_criterion", "ledgr_invalid_args")
    )
  }
  criterion_id
}

ledgr_objective_validate_evidence_key <- function(evidence_key) {
  if (!is.character(evidence_key) || length(evidence_key) != 1L ||
      is.na(evidence_key) || !nzchar(evidence_key) || grepl("[^ -~]", evidence_key)) {
    rlang::abort(
      "Objective criterion evidence keys must be non-empty ASCII strings.",
      class = c("ledgr_invalid_objective_criterion", "ledgr_invalid_args")
    )
  }
  evidence_key
}

ledgr_objective_normalize_params <- function(criterion_id, params, snapshot = NULL) {
  if (!is.list(params)) {
    rlang::abort(
      "Objective criterion parameters must be a named list.",
      class = c("ledgr_objective_non_serializable_params", "ledgr_invalid_objective_criterion", "ledgr_invalid_args")
    )
  }
  switch(
    criterion_id,
    even_trades = list(
      max_concentration = ledgr_objective_fraction(params$max_concentration, "max_concentration", zero = FALSE),
      time_bins = ledgr_objective_time_bins(params$time_bins)
    ),
    even_profit = list(
      max_concentration = ledgr_objective_fraction(params$max_concentration, "max_concentration", zero = FALSE)
    ),
    stable_region = list(
      min_neighbors = ledgr_stable_region_validate_min_neighbors(params$min_neighbors),
      metric = ledgr_objective_string(params$metric, "metric"),
      direction = ledgr_objective_choice(params$direction, "direction", c("maximize", "minimize")),
      parameter_columns = ledgr_objective_parameter_columns(params$parameter_columns)
    ),
    max_drawdown = list(
      max_drawdown = ledgr_objective_fraction(params$max_drawdown, "max_drawdown", zero = TRUE)
    ),
    stable_runs = list(
      max_streak = ledgr_objective_whole(params$max_streak, "max_streak", minimum = 1L)
    ),
    min_trades = list(
      n = ledgr_objective_whole(params$n, "n", minimum = 0L)
    ),
    positive_trajectory = list(
      slope_min = ledgr_objective_finite(params$slope_min, "slope_min")
    ),
    ledgr_objective_normalize_diagnostic_params(criterion_id, params, snapshot)
  )
}

ledgr_objective_normalize_diagnostic_params <- function(criterion_id, params, snapshot) {
  if (!grepl("^diagnostic_", criterion_id)) {
    rlang::abort(
      sprintf("Unsupported ledgr objective criterion id: %s.", criterion_id),
      class = c("ledgr_unknown_objective_criterion", "ledgr_invalid_objective_criterion", "ledgr_invalid_args")
    )
  }
  diagnostic_id <- ledgr_objective_choice(params$diagnostic_id, "diagnostic_id", c("dsr", "min_track_record"))
  column <- ledgr_objective_string(params$column, "column")
  allowed <- ledgr_objective_diagnostic_allowed_columns(diagnostic_id)
  if (!(column %in% names(allowed))) {
    rlang::abort(
      sprintf("Column `%s` is not an admissible %s objective threshold.", column, diagnostic_id),
      class = c("ledgr_invalid_diagnostic_threshold", "ledgr_invalid_objective_criterion", "ledgr_invalid_args")
    )
  }
  comparison <- if (identical(allowed[[column]], "status")) {
    ledgr_objective_choice(params$comparison, "comparison", "equals")
  } else {
    ledgr_objective_choice(params$comparison, "comparison", c("at_least", "at_most"))
  }
  threshold <- if (identical(allowed[[column]], "status")) {
    ledgr_objective_string(params$threshold, "threshold")
  } else {
    ledgr_objective_finite(params$threshold, "threshold")
  }
  source_hash <- ledgr_objective_sha256(params$source_hash, "source_hash")
  list(
    diagnostic_id = diagnostic_id,
    column = column,
    threshold = threshold,
    comparison = comparison,
    source_hash = source_hash
  )
}

ledgr_objective_finite <- function(x, arg) {
  if (!is.numeric(x) || length(x) != 1L || is.na(x) || !is.finite(x)) {
    rlang::abort(
      sprintf("`%s` must be a finite numeric scalar.", arg),
      class = c("ledgr_invalid_objective_criterion", "ledgr_invalid_args")
    )
  }
  as.numeric(x)
}

ledgr_objective_fraction <- function(x, arg, zero) {
  x <- ledgr_objective_finite(x, arg)
  invalid_lower <- if (isTRUE(zero)) x < 0 else x <= 0
  if (invalid_lower || x > 1) {
    interval <- if (isTRUE(zero)) "[0, 1]" else "(0, 1]"
    rlang::abort(
      sprintf("`%s` must be in %s.", arg, interval),
      class = c("ledgr_invalid_objective_criterion", "ledgr_invalid_args")
    )
  }
  x
}

ledgr_objective_whole <- function(x, arg, minimum) {
  if (!is.numeric(x) || length(x) != 1L || is.na(x) || !is.finite(x) ||
      x != as.integer(x) || x < minimum) {
    rlang::abort(
      sprintf("`%s` must be a whole number at least %d.", arg, minimum),
      class = c("ledgr_invalid_objective_criterion", "ledgr_invalid_args")
    )
  }
  as.integer(x)
}

ledgr_objective_time_bins <- function(x) {
  x <- ledgr_objective_whole(x, "time_bins", minimum = 2L)
  if (!identical(x, 4L)) {
    rlang::abort(
      "V1 `even_trades` criteria require exactly four equal-duration bins.",
      class = c("ledgr_invalid_objective_criterion", "ledgr_invalid_args")
    )
  }
  x
}

ledgr_objective_string <- function(x, arg) {
  if (!is.character(x) || length(x) != 1L || is.na(x) || !nzchar(trimws(x))) {
    rlang::abort(
      sprintf("`%s` must be a non-empty character scalar.", arg),
      class = c("ledgr_invalid_objective_criterion", "ledgr_invalid_args")
    )
  }
  as.character(x)
}

ledgr_objective_choice <- function(x, arg, choices) {
  x <- ledgr_objective_string(x, arg)
  if (!(x %in% choices)) {
    rlang::abort(
      sprintf("`%s` must be one of: %s.", arg, paste(choices, collapse = ", ")),
      class = c("ledgr_invalid_objective_criterion", "ledgr_invalid_args")
    )
  }
  x
}

ledgr_objective_parameter_columns <- function(x) {
  if (is.null(x)) {
    return(NULL)
  }
  if (!is.character(x) || length(x) == 0L || anyNA(x) ||
      any(!nzchar(x)) || anyDuplicated(x)) {
    rlang::abort(
      "`parameter_columns` must be NULL or a unique non-empty character vector.",
      class = c("ledgr_invalid_objective_criterion", "ledgr_invalid_args")
    )
  }
  as.character(x)
}

ledgr_objective_sha256 <- function(x, arg) {
  if (!is.character(x) || length(x) != 1L || is.na(x) || !grepl("^[0-9a-f]{64}$", x)) {
    rlang::abort(
      sprintf("`%s` must be a lowercase SHA-256 value.", arg),
      class = c("ledgr_invalid_objective_criterion", "ledgr_invalid_args")
    )
  }
  x
}

ledgr_objective_validate_snapshot <- function(criterion_id, snapshot, params) {
  is_diagnostic <- grepl("^diagnostic_", criterion_id)
  if (!is_diagnostic) {
    if (!is.null(snapshot)) {
      rlang::abort(
        "Only diagnostic-threshold criteria may carry an evidence snapshot.",
        class = c("ledgr_invalid_objective_criterion", "ledgr_invalid_args")
      )
    }
    return(NULL)
  }
  required <- c(
    "snapshot_schema_version", "diagnostic_id", "column", "value_type",
    "default_comparison", "source_metadata", "source_hash", "records"
  )
  if (!is.list(snapshot) || !all(required %in% names(snapshot)) ||
      !identical(as.integer(snapshot$snapshot_schema_version), 1L) ||
      !identical(snapshot$diagnostic_id, params$diagnostic_id) ||
      !identical(snapshot$column, params$column) ||
      !identical(snapshot$source_hash, params$source_hash) ||
      !is.list(snapshot$source_metadata) || !is.list(snapshot$records)) {
    rlang::abort(
      "Diagnostic-threshold evidence snapshot is invalid or does not match its criterion parameters.",
      class = c("ledgr_invalid_diagnostic_threshold", "ledgr_invalid_objective_criterion", "ledgr_invalid_args")
    )
  }
  record_ids <- vapply(snapshot$records, function(record) {
    if (!is.list(record) || !is.character(record$candidate_id) || length(record$candidate_id) != 1L ||
        is.na(record$candidate_id) || !nzchar(record$candidate_id) || !is.list(record$value)) {
      rlang::abort(
        "Diagnostic-threshold evidence records are invalid.",
        class = c("ledgr_invalid_diagnostic_threshold", "ledgr_invalid_objective_criterion", "ledgr_invalid_args")
      )
    }
    record$candidate_id
  }, character(1))
  if (anyDuplicated(record_ids)) {
    rlang::abort(
      "Diagnostic-threshold candidate ids must be unique.",
      class = c("ledgr_invalid_diagnostic_threshold", "ledgr_invalid_objective_criterion", "ledgr_invalid_args")
    )
  }
  source_payload <- snapshot
  source_payload$source_hash <- NULL
  expected_hash <- digest::digest(as.character(canonical_json(source_payload)), algo = "sha256")
  if (!identical(snapshot$source_hash, expected_hash)) {
    rlang::abort(
      "Diagnostic-threshold source hash does not match its evidence snapshot.",
      class = c("ledgr_diagnostic_source_hash_mismatch", "ledgr_invalid_diagnostic_threshold", "ledgr_invalid_args")
    )
  }
  snapshot
}

ledgr_objective_diagnostic_snapshot <- function(x, column) {
  diagnostic_id <- if (inherits(x, "ledgr_dsr")) {
    "dsr"
  } else if (inherits(x, "ledgr_min_track_record")) {
    "min_track_record"
  } else {
    rlang::abort(
      "`x` must be a ledgr_dsr or ledgr_min_track_record result.",
      class = c("ledgr_invalid_diagnostic_threshold", "ledgr_invalid_args")
    )
  }
  column <- ledgr_objective_string(column, "column")
  allowed <- ledgr_objective_diagnostic_allowed_columns(diagnostic_id)
  if (!(column %in% names(allowed))) {
    rlang::abort(
      sprintf("Column `%s` is not an admissible %s objective threshold.", column, diagnostic_id),
      class = c("ledgr_invalid_diagnostic_threshold", "ledgr_invalid_args")
    )
  }
  summary <- tibble::as_tibble(x)
  if (!all(c("candidate_id", column, "panel_hash") %in% names(summary)) ||
      anyDuplicated(as.character(summary$candidate_id))) {
    rlang::abort(
      "Diagnostic result does not expose unique candidate evidence and panel provenance.",
      class = c("ledgr_invalid_diagnostic_threshold", "ledgr_invalid_args")
    )
  }
  records <- lapply(seq_len(nrow(summary)), function(i) {
    list(
      candidate_id = as.character(summary$candidate_id[[i]]),
      value = ledgr_objective_encode_scalar(summary[[column]][[i]])
    )
  })
  snapshot <- list(
    snapshot_schema_version = 1L,
    diagnostic_id = diagnostic_id,
    column = column,
    value_type = unname(allowed[[column]]),
    default_comparison = ledgr_objective_diagnostic_default_comparison(diagnostic_id, column),
    source_metadata = list(
      diagnostic = as.character(x$metadata$diagnostic %||% diagnostic_id),
      schema_version = as.integer(x$metadata$schema_version %||% 1L),
      native_version = as.character(x$metadata$native_version %||% NA_character_),
      panel_hash = as.character(unique(summary$panel_hash)[[1L]])
    ),
    records = records
  )
  snapshot$source_hash <- digest::digest(as.character(canonical_json(snapshot)), algo = "sha256")
  snapshot
}

ledgr_objective_diagnostic_allowed_columns <- function(diagnostic_id) {
  switch(
    diagnostic_id,
    dsr = c(dsr_probability = "numeric", status = "status"),
    min_track_record = c(min_track_record_length = "numeric", status = "status"),
    character()
  )
}

ledgr_objective_diagnostic_default_comparison <- function(diagnostic_id, column) {
  if (identical(column, "status")) {
    return("equals")
  }
  if (identical(diagnostic_id, "min_track_record")) "at_most" else "at_least"
}

ledgr_objective_encode_scalar <- function(x) {
  if (length(x) != 1L) {
    rlang::abort(
      "Diagnostic threshold evidence must be scalar per candidate.",
      class = c("ledgr_invalid_diagnostic_threshold", "ledgr_invalid_args")
    )
  }
  if (is.numeric(x)) {
    if (is.nan(x)) return(list(kind = "non_finite", value = "NaN"))
    if (is.na(x)) return(list(kind = "non_finite", value = "NA"))
    if (is.infinite(x)) return(list(kind = "non_finite", value = if (x > 0) "Inf" else "-Inf"))
    return(list(kind = "numeric", value = as.numeric(x)))
  }
  if (is.character(x) && !is.na(x) && nzchar(x)) {
    return(list(kind = "character", value = as.character(x)))
  }
  rlang::abort(
    "Diagnostic threshold evidence must be numeric or non-empty character data.",
    class = c("ledgr_invalid_diagnostic_threshold", "ledgr_invalid_args")
  )
}

ledgr_objective_decode_scalar <- function(x) {
  if (!is.list(x) || !is.character(x$kind) || length(x$kind) != 1L) {
    rlang::abort(
      "Diagnostic threshold evidence encoding is invalid.",
      class = c("ledgr_invalid_diagnostic_threshold", "ledgr_invalid_args")
    )
  }
  if (identical(x$kind, "numeric")) return(as.numeric(x$value))
  if (identical(x$kind, "character")) return(as.character(x$value))
  if (identical(x$kind, "non_finite")) {
    if (identical(x$value, "NA")) return(NA_real_)
    if (identical(x$value, "NaN")) return(NaN)
    if (identical(x$value, "Inf")) return(Inf)
    if (identical(x$value, "-Inf")) return(-Inf)
  }
  rlang::abort(
    "Diagnostic threshold evidence encoding is unsupported.",
    class = c("ledgr_invalid_diagnostic_threshold", "ledgr_invalid_args")
  )
}

ledgr_objective_evaluator <- function(criterion_id, params, snapshot) {
  force(criterion_id)
  force(params)
  force(snapshot)
  function(evidence, candidate_id = NULL) {
    ledgr_objective_evaluate_builtin(
      criterion_id,
      params,
      snapshot,
      evidence,
      candidate_id
    )
  }
}

ledgr_objective_step_evaluate <- function(step, evidence = NULL, candidate_id = NULL) {
  step <- ledgr_objective_criterion_validate(step)
  verdict <- step$evaluate(evidence, candidate_id = candidate_id)
  ledgr_objective_verdict_validate(verdict, step$criterion_id)
}

ledgr_objective_evaluate_builtin <- function(criterion_id,
                                             params,
                                             snapshot,
                                             evidence,
                                             candidate_id) {
  switch(
    criterion_id,
    max_drawdown = ledgr_objective_eval_max_drawdown(evidence, params, candidate_id),
    min_trades = ledgr_objective_eval_min_trades(evidence, params, candidate_id),
    positive_trajectory = ledgr_objective_eval_positive_trajectory(evidence, params, candidate_id),
    even_trades = ledgr_objective_eval_even_trades(evidence, params, candidate_id),
    even_profit = ledgr_objective_eval_even_profit(evidence, params, candidate_id),
    stable_runs = ledgr_objective_eval_stable_runs(evidence, params, candidate_id),
    stable_region = ledgr_objective_eval_stable_region(evidence, params, candidate_id),
    ledgr_objective_eval_diagnostic(snapshot, params, candidate_id)
  )
}

ledgr_objective_verdict <- function(value,
                                    threshold,
                                    passed,
                                    reason,
                                    evidence_source,
                                    details = list()) {
  list(
    value = as.numeric(value),
    threshold = threshold,
    passed = isTRUE(passed),
    reason = as.character(reason),
    evidence_source = as.character(evidence_source),
    details = details
  )
}

ledgr_objective_verdict_validate <- function(x, criterion_id) {
  if (!is.list(x) || !is.numeric(x$value) || length(x$value) != 1L ||
      is.na(x$value) ||
      (is.infinite(x$value) && !grepl("^diagnostic_", criterion_id)) ||
      !is.logical(x$passed) || length(x$passed) != 1L || is.na(x$passed) ||
      !is.character(x$reason) || length(x$reason) != 1L || !nzchar(x$reason) ||
      !is.character(x$evidence_source) || length(x$evidence_source) != 1L ||
      !is.list(x$details)) {
    rlang::abort(
      sprintf("Criterion `%s` returned an invalid verdict.", criterion_id),
      class = c("ledgr_invalid_objective_verdict", "ledgr_invalid_args")
    )
  }
  x
}

ledgr_objective_evidence_numeric <- function(evidence, criterion_id, evidence_key, candidate_id) {
  if (is.null(evidence) || length(evidence) == 0L) {
    ledgr_objective_abort_missing(criterion_id, evidence_key, candidate_id)
  }
  if (!is.numeric(evidence) || length(evidence) != 1L || is.na(evidence) || !is.finite(evidence)) {
    ledgr_objective_abort_non_finite(criterion_id, evidence_key, candidate_id)
  }
  as.numeric(evidence)
}

ledgr_objective_diagnostic_numeric <- function(evidence,
                                               criterion_id,
                                               evidence_key,
                                               candidate_id) {
  if (is.null(evidence) || length(evidence) == 0L) {
    ledgr_objective_abort_missing(criterion_id, evidence_key, candidate_id)
  }
  if (!is.numeric(evidence) || length(evidence) != 1L || is.na(evidence) || is.nan(evidence)) {
    ledgr_objective_abort_non_finite(criterion_id, evidence_key, candidate_id)
  }
  as.numeric(evidence)
}

ledgr_objective_eval_max_drawdown <- function(evidence, params, candidate_id) {
  value <- ledgr_objective_evidence_numeric(evidence, "max_drawdown", "summary.max_drawdown", candidate_id)
  if (value < 0) ledgr_objective_abort_invalid("max_drawdown", "summary.max_drawdown", candidate_id)
  passed <- value <= params$max_drawdown
  ledgr_objective_verdict(
    value, params$max_drawdown, passed,
    if (passed) "criterion_passed" else "max_drawdown_exceeded",
    "summary.max_drawdown"
  )
}

ledgr_objective_eval_min_trades <- function(evidence, params, candidate_id) {
  value <- ledgr_objective_evidence_numeric(evidence, "min_trades", "summary.n_trades", candidate_id)
  if (value < 0 || value != as.integer(value)) {
    ledgr_objective_abort_invalid("min_trades", "summary.n_trades", candidate_id)
  }
  passed <- value >= params$n
  ledgr_objective_verdict(
    value, params$n, passed,
    if (passed) "criterion_passed" else "minimum_trades_not_met",
    "summary.n_trades"
  )
}

ledgr_objective_eval_positive_trajectory <- function(evidence, params, candidate_id) {
  equity <- if (is.data.frame(evidence) && "equity" %in% names(evidence)) evidence$equity else evidence
  if (is.null(equity) || length(equity) == 0L) {
    ledgr_objective_abort_missing("positive_trajectory", "retained_equity", candidate_id)
  }
  if (!is.numeric(equity) || length(equity) < 2L || anyNA(equity) ||
      any(!is.finite(equity)) || any(equity <= 0)) {
    ledgr_objective_abort_non_finite("positive_trajectory", "retained_equity", candidate_id)
  }
  index <- seq.int(0, length(equity) - 1L)
  centered_index <- index - mean(index)
  slope <- sum(centered_index * (log(equity) - mean(log(equity)))) / sum(centered_index^2)
  if (!is.finite(slope)) {
    ledgr_objective_abort_non_finite("positive_trajectory", "retained_equity", candidate_id)
  }
  passed <- slope >= params$slope_min
  ledgr_objective_verdict(
    slope, params$slope_min, passed,
    if (passed) "criterion_passed" else "positive_trajectory_not_met",
    "retained_equity",
    details = list(observations = length(equity), index_origin = 0L)
  )
}

ledgr_objective_closed_trades <- function(evidence, criterion_id, candidate_id) {
  trades <- if (is.list(evidence) && !is.data.frame(evidence)) evidence$trades else evidence
  if (!is.data.frame(trades) || nrow(trades) == 0L) {
    ledgr_objective_abort_missing(criterion_id, "closed_trades", candidate_id)
  }
  trades
}

ledgr_objective_eval_even_trades <- function(evidence, params, candidate_id) {
  trades <- ledgr_objective_closed_trades(evidence, "even_trades", candidate_id)
  if (!"close_ts_utc" %in% names(trades)) {
    ledgr_objective_abort_missing("even_trades", "closed_trades.close_ts_utc", candidate_id)
  }
  range <- if (is.list(evidence) && !is.data.frame(evidence)) evidence$scoring_range else NULL
  if (!is.list(range) || is.null(range$start) || is.null(range$end)) {
    ledgr_objective_abort_missing("even_trades", "scoring_range", candidate_id)
  }
  ts <- as.POSIXct(trades$close_ts_utc, tz = "UTC")
  start <- as.POSIXct(range$start, tz = "UTC")
  end <- as.POSIXct(range$end, tz = "UTC")
  if (anyNA(ts) || anyNA(c(start, end)) || end <= start || any(ts < start | ts > end)) {
    ledgr_objective_abort_invalid("even_trades", "closed_trades.close_ts_utc", candidate_id)
  }
  breaks <- seq(as.numeric(start), as.numeric(end), length.out = params$time_bins + 1L)
  bins <- findInterval(as.numeric(ts), breaks, all.inside = TRUE)
  concentration <- max(tabulate(bins, nbins = params$time_bins)) / length(ts)
  passed <- concentration <= params$max_concentration
  ledgr_objective_verdict(
    concentration, params$max_concentration, passed,
    if (passed) "criterion_passed" else "trade_time_concentration_exceeded",
    "closed_trades.close_ts_utc",
    details = list(time_bins = params$time_bins, bin_counts = as.list(tabulate(bins, nbins = params$time_bins)))
  )
}

ledgr_objective_eval_even_profit <- function(evidence, params, candidate_id) {
  trades <- ledgr_objective_closed_trades(evidence, "even_profit", candidate_id)
  if (!"realized_pnl" %in% names(trades)) {
    ledgr_objective_abort_missing("even_profit", "closed_trades.realized_pnl", candidate_id)
  }
  pnl <- as.numeric(trades$realized_pnl)
  if (anyNA(pnl) || any(!is.finite(pnl)) || sum(abs(pnl)) <= 0) {
    ledgr_objective_abort_non_finite("even_profit", "closed_trades.realized_pnl", candidate_id)
  }
  concentration <- max(abs(pnl)) / sum(abs(pnl))
  passed <- concentration <= params$max_concentration
  ledgr_objective_verdict(
    concentration, params$max_concentration, passed,
    if (passed) "criterion_passed" else "realized_pnl_concentration_exceeded",
    "closed_trades.realized_pnl",
    details = list(concentration_basis = "absolute_realized_pnl")
  )
}

ledgr_objective_eval_stable_runs <- function(evidence, params, candidate_id) {
  trades <- ledgr_objective_closed_trades(evidence, "stable_runs", candidate_id)
  if (!all(c("trade_seq", "win_loss") %in% names(trades))) {
    ledgr_objective_abort_missing("stable_runs", "closed_trades.win_loss", candidate_id)
  }
  seq_value <- as.integer(trades$trade_seq)
  outcome <- as.character(trades$win_loss)
  if (anyNA(seq_value) || anyDuplicated(seq_value) || anyNA(outcome) ||
      any(!(outcome %in% c("WIN", "LOSS", "BREAKEVEN")))) {
    ledgr_objective_abort_invalid("stable_runs", "closed_trades.win_loss", candidate_id)
  }
  outcome <- outcome[order(seq_value)]
  current <- NA_character_
  length_current <- 0L
  longest <- 0L
  for (value in outcome) {
    if (identical(value, "BREAKEVEN")) {
      current <- NA_character_
      length_current <- 0L
    } else if (identical(value, current)) {
      length_current <- length_current + 1L
    } else {
      current <- value
      length_current <- 1L
    }
    longest <- max(longest, length_current)
  }
  passed <- longest <= params$max_streak
  ledgr_objective_verdict(
    longest, params$max_streak, passed,
    if (passed) "criterion_passed" else "maximum_trade_streak_exceeded",
    "closed_trades.win_loss",
    details = list(order_key = "trade_seq")
  )
}

ledgr_objective_eval_stable_region <- function(evidence, params, candidate_id) {
  result <- if (inherits(evidence, "ledgr_stable_region_evidence")) {
    evidence
  } else if (is.data.frame(evidence)) {
    structure(list(summary = evidence), class = c("ledgr_stable_region_evidence", "list"))
  } else {
    ledgr_objective_abort_missing("stable_region", "candidate_metric_lattice", candidate_id)
  }
  if (is.null(candidate_id) || !is.character(candidate_id) || length(candidate_id) != 1L) {
    ledgr_objective_abort_missing("stable_region", "candidate_id", candidate_id)
  }
  row <- result$summary[as.character(result$summary$candidate_id) == candidate_id, , drop = FALSE]
  if (nrow(row) != 1L || !all(c("good_neighbors", "eligible") %in% names(row))) {
    ledgr_objective_abort_missing("stable_region", "candidate_metric_lattice", candidate_id)
  }
  good <- ledgr_objective_evidence_numeric(row$good_neighbors[[1L]], "stable_region", "good_neighbors", candidate_id)
  passed <- good >= params$min_neighbors
  ledgr_objective_verdict(
    good, params$min_neighbors, passed,
    if (passed) "criterion_passed" else "stable_region_support_not_met",
    "candidate_metric_lattice",
    details = as.list(row[1L, setdiff(names(row), c("candidate_id", "good_neighbors", "eligible")), drop = FALSE])
  )
}

ledgr_objective_eval_diagnostic <- function(snapshot, params, candidate_id) {
  if (is.null(candidate_id) || !is.character(candidate_id) || length(candidate_id) != 1L) {
    ledgr_objective_abort_missing("diagnostic_threshold", "candidate_id", candidate_id)
  }
  ids <- vapply(snapshot$records, `[[`, character(1), "candidate_id")
  index <- match(candidate_id, ids)
  if (is.na(index)) {
    ledgr_objective_abort_missing(
      paste0("diagnostic_", params$diagnostic_id, "_", params$column),
      paste("diagnostic", params$diagnostic_id, params$column, sep = "."),
      candidate_id
    )
  }
  observed <- ledgr_objective_decode_scalar(snapshot$records[[index]]$value)
  if (identical(snapshot$value_type, "numeric")) {
    value <- ledgr_objective_diagnostic_numeric(
      observed,
      paste0("diagnostic_", params$diagnostic_id, "_", params$column),
      paste("diagnostic", params$diagnostic_id, params$column, sep = "."),
      candidate_id
    )
    passed <- if (identical(params$comparison, "at_least")) {
      value >= params$threshold
    } else {
      value <= params$threshold
    }
    details <- list(source_hash = params$source_hash, source_metadata = snapshot$source_metadata)
  } else {
    if (!is.character(observed) || length(observed) != 1L || is.na(observed) || !nzchar(observed)) {
      ledgr_objective_abort_non_finite(
        paste0("diagnostic_", params$diagnostic_id, "_", params$column),
        paste("diagnostic", params$diagnostic_id, params$column, sep = "."),
        candidate_id
      )
    }
    passed <- identical(observed, params$threshold)
    value <- as.numeric(passed)
    details <- list(
      observed_status = observed,
      source_hash = params$source_hash,
      source_metadata = snapshot$source_metadata
    )
  }
  ledgr_objective_verdict(
    value, params$threshold, passed,
    if (passed) "criterion_passed" else "diagnostic_threshold_not_met",
    paste("diagnostic", params$diagnostic_id, params$column, sep = "."),
    details = details
  )
}

ledgr_objective_abort_missing <- function(criterion_id, evidence_key, candidate_id = NULL) {
  rlang::abort(
    sprintf("Criterion `%s` requires missing evidence `%s`.", criterion_id, evidence_key),
    class = c("ledgr_objective_missing_evidence", "ledgr_invalid_args"),
    criterion_id = criterion_id,
    evidence_key = evidence_key,
    candidate_id = candidate_id
  )
}

ledgr_objective_abort_non_finite <- function(criterion_id, evidence_key, candidate_id = NULL) {
  rlang::abort(
    sprintf("Criterion `%s` requires finite evidence `%s`.", criterion_id, evidence_key),
    class = c("ledgr_objective_non_finite_evidence", "ledgr_invalid_args"),
    criterion_id = criterion_id,
    evidence_key = evidence_key,
    candidate_id = candidate_id
  )
}

ledgr_objective_abort_invalid <- function(criterion_id, evidence_key, candidate_id = NULL) {
  rlang::abort(
    sprintf("Criterion `%s` received invalid evidence `%s`.", criterion_id, evidence_key),
    class = c("ledgr_objective_invalid_evidence", "ledgr_invalid_args"),
    criterion_id = criterion_id,
    evidence_key = evidence_key,
    candidate_id = candidate_id
  )
}

ledgr_stable_region_detect <- function(grid,
                                       metric,
                                       parameter_columns = NULL,
                                       direction = c("maximize", "minimize"),
                                       min_neighbors = 2L) {
  direction <- match.arg(direction)
  min_neighbors <- ledgr_stable_region_validate_min_neighbors(min_neighbors)
  if (!is.data.frame(grid) || !"candidate_id" %in% names(grid)) {
    rlang::abort(
      "Stable-region evidence requires a data frame with `candidate_id`.",
      class = c("ledgr_stable_region_invalid_grid", "ledgr_invalid_args")
    )
  }
  candidate_ids <- as.character(grid$candidate_id)
  if (anyNA(candidate_ids) || any(!nzchar(candidate_ids)) || anyDuplicated(candidate_ids)) {
    rlang::abort(
      "Stable-region candidate ids must be unique and non-empty.",
      class = c("ledgr_stable_region_invalid_grid", "ledgr_invalid_args")
    )
  }
  metric_name <- if (is.character(metric) && length(metric) == 1L && metric %in% names(grid)) metric else NULL
  metric_values <- if (is.null(metric_name)) metric else grid[[metric_name]]
  if (!is.numeric(metric_values) || length(metric_values) != nrow(grid) ||
      anyNA(metric_values) || any(!is.finite(metric_values))) {
    rlang::abort(
      "Stable-region metric evidence must be one finite numeric value per candidate.",
      class = c("ledgr_stable_region_invalid_metric", "ledgr_invalid_args")
    )
  }
  if (is.null(parameter_columns)) {
    parameter_columns <- setdiff(names(grid), c("candidate_id", metric_name %||% character()))
  }
  parameter_columns <- ledgr_objective_parameter_columns(parameter_columns)
  if (is.null(parameter_columns) || !all(parameter_columns %in% names(grid))) {
    rlang::abort(
      "Stable-region parameter columns must name at least one grid axis.",
      class = c("ledgr_stable_region_invalid_grid", "ledgr_invalid_args"),
      parameter_columns = parameter_columns
    )
  }
  levels_by_axis <- lapply(parameter_columns, function(column) {
    ledgr_stable_region_levels(grid[[column]], column)
  })
  names(levels_by_axis) <- parameter_columns
  collapsed <- parameter_columns[vapply(levels_by_axis, length, integer(1)) < 2L]
  if (length(collapsed) > 0L) {
    rlang::abort(
      sprintf("Stable-region axes must contain at least two levels: %s.", paste(collapsed, collapse = ", ")),
      class = c("ledgr_stable_region_collapsed_axis", "ledgr_stable_region_invalid_grid", "ledgr_invalid_args"),
      axes = collapsed
    )
  }
  index_list <- Map(
    function(values, levels, column) ledgr_stable_region_level_index(values, levels, column),
    grid[parameter_columns],
    levels_by_axis,
    parameter_columns
  )
  index <- as.data.frame(index_list, stringsAsFactors = FALSE)
  names(index) <- parameter_columns
  keys <- do.call(paste, c(index, sep = "\r"))
  duplicate_keys <- unique(keys[duplicated(keys)])
  if (length(duplicate_keys) > 0L) {
    rlang::abort(
      "Stable-region parameter tuples must be unique.",
      class = c("ledgr_stable_region_duplicate_tuple", "ledgr_stable_region_invalid_grid", "ledgr_invalid_args"),
      duplicate_keys = duplicate_keys,
      parameter_columns = parameter_columns
    )
  }
  expected_count <- prod(vapply(levels_by_axis, length, integer(1)))
  full <- expand.grid(
    lapply(levels_by_axis, seq_along),
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  names(full) <- parameter_columns
  full_keys <- do.call(paste, c(full, sep = "\r"))
  missing_keys <- setdiff(full_keys, keys)
  if (nrow(grid) != expected_count || length(missing_keys) > 0L || !setequal(keys, full_keys)) {
    rlang::abort(
      "Stable-region grid must contain every full-factorial parameter tuple exactly once.",
      class = c("ledgr_stable_region_incomplete_grid", "ledgr_stable_region_invalid_grid", "ledgr_invalid_args"),
      expected_count = expected_count,
      observed_count = nrow(grid),
      missing_keys = missing_keys,
      parameter_columns = parameter_columns
    )
  }

  row_by_key <- stats::setNames(seq_len(nrow(grid)), keys)
  score <- if (identical(direction, "maximize")) as.numeric(metric_values) else -as.numeric(metric_values)
  neighbors <- vector("list", nrow(grid))
  adjacent_differences <- numeric()
  for (i in seq_len(nrow(grid))) {
    local <- integer()
    for (axis in parameter_columns) {
      for (delta in c(-1L, 1L)) {
        neighbor_index <- index[i, , drop = FALSE]
        neighbor_index[[axis]] <- neighbor_index[[axis]] + delta
        if (neighbor_index[[axis]] < 1L ||
            neighbor_index[[axis]] > length(levels_by_axis[[axis]])) {
          next
        }
        key <- do.call(paste, c(neighbor_index, sep = "\r"))
        j <- unname(row_by_key[[key]])
        local <- c(local, j)
        if (i < j) adjacent_differences <- c(adjacent_differences, abs(score[[i]] - score[[j]]))
      }
    }
    neighbors[[i]] <- sort(unique(local))
  }
  if (length(adjacent_differences) == 0L) {
    rlang::abort(
      "Stable-region grid produced no adjacent lattice pairs.",
      class = c("ledgr_stable_region_no_adjacent_pairs", "ledgr_stable_region_invalid_grid", "ledgr_invalid_args")
    )
  }
  tau <- as.numeric(stats::median(adjacent_differences))
  available <- good <- integer(nrow(grid))
  support <- smoothness <- numeric(nrow(grid))
  eligible <- logical(nrow(grid))
  for (i in seq_len(nrow(grid))) {
    local_scores <- score[neighbors[[i]]]
    good_mask <- local_scores >= score[[i]] - tau
    available[[i]] <- length(local_scores)
    good[[i]] <- sum(good_mask)
    support[[i]] <- good[[i]] / available[[i]]
    smoothness[[i]] <- max(local_scores) - min(local_scores)
    eligible[[i]] <- good[[i]] >= min_neighbors
  }
  summary <- tibble::tibble(
    candidate_id = candidate_ids,
    metric = as.numeric(metric_values),
    direction = direction,
    tau = tau,
    available_neighbors = available,
    good_neighbors = good,
    support_ratio = support,
    local_smoothness_range = smoothness,
    eligible = eligible
  )
  structure(
    list(
      summary = summary,
      metadata = list(
        detector_version = "ledgr_stable_region_strict_lattice_v1",
        adjacency_rule = "manhattan_1_level_index",
        tolerance_rule = "median_absolute_adjacent_score_difference",
        min_neighbors = min_neighbors,
        metric = metric_name %||% "supplied_metric",
        direction = direction,
        parameter_columns = parameter_columns,
        level_sets = levels_by_axis
      )
    ),
    class = c("ledgr_stable_region_evidence", "list")
  )
}

ledgr_stable_region_validate_min_neighbors <- function(x) {
  tryCatch(
    ledgr_objective_whole(x, "min_neighbors", 1L),
    ledgr_invalid_objective_criterion = function(e) {
      rlang::abort(
        "`min_neighbors` must be a positive whole number.",
        class = c("ledgr_stable_region_invalid_min_neighbors", "ledgr_invalid_objective_criterion", "ledgr_invalid_args"),
        parent = e
      )
    }
  )
}

ledgr_stable_region_levels <- function(x, column) {
  if (is.factor(x) && !is.ordered(x)) {
    rlang::abort(
      sprintf("Stable-region axis `%s` is an unordered factor.", column),
      class = c("ledgr_stable_region_unordered_axis", "ledgr_stable_region_invalid_grid", "ledgr_invalid_args"),
      axis = column
    )
  }
  if (is.ordered(x)) return(levels(x))
  if (is.logical(x)) return(c(FALSE, TRUE)[c(FALSE, TRUE) %in% unique(x)])
  if (inherits(x, "Date") || inherits(x, "POSIXt")) return(sort(unique(x)))
  if (is.numeric(x) || is.integer(x)) return(sort(unique(x)))
  rlang::abort(
    sprintf("Stable-region axis `%s` has an unsupported type.", column),
    class = c("ledgr_stable_region_unsupported_axis", "ledgr_stable_region_invalid_grid", "ledgr_invalid_args"),
    axis = column
  )
}

ledgr_stable_region_level_index <- function(x, levels, column) {
  index <- match(as.character(x), as.character(levels))
  if (anyNA(index)) {
    rlang::abort(
      sprintf("Stable-region axis `%s` contains an unmatched level.", column),
      class = c("ledgr_stable_region_invalid_grid", "ledgr_invalid_args"),
      axis = column
    )
  }
  as.integer(index)
}
