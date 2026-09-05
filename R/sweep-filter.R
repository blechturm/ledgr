ledgr_sweep_filter_schema_version <- 1L

#' Evaluate a sweep against a business objective
#'
#' `ledgr_sweep_filter()` evaluates every completed sweep candidate against
#' every criterion in a [ledgr_business_objective()]. It returns eligibility
#' evidence, not a selected candidate. Ineligible candidates remain in the
#' default table, candidate order remains sweep order, and no ranking,
#' promotion, persistence, or identity mutation occurs.
#'
#' This function is not a replacement for `dplyr::filter()`. Its result is a
#' long candidate-by-criterion audit table. [ledgr_candidate()],
#' [ledgr_promote()], and walk-forward selection reject that result explicitly.
#'
#' @param sweep_results A `ledgr_sweep_results` object.
#' @param objective A `ledgr_business_objective` object.
#' @return A `ledgr_sweep_filter_result` object with `tear_down` and `metadata`.
#'   `as_tibble()` and `print()` expose the complete tear-down table, including
#'   failed criteria and ineligible candidates.
#' @examples
#' \dontrun{
#' objective <- ledgr_business_objective(
#'   ledgr_objective_max_drawdown(0.20),
#'   ledgr_objective_min_trades(30)
#' )
#' evidence <- ledgr_sweep_filter(sweep, objective)
#' as_tibble(evidence)
#' }
#' @export
ledgr_sweep_filter <- function(sweep_results, objective) {
  sweep_results <- ledgr_sweep_filter_validate_sweep(sweep_results)
  objective <- ledgr_business_objective_validate(objective)
  status <- as.character(sweep_results$status)
  completed_mask <- !is.na(status) & status == "DONE"
  completed <- sweep_results[completed_mask, , drop = FALSE]
  if (nrow(completed) == 0L) {
    rlang::abort(
      "`sweep_results` has no completed candidates to evaluate.",
      class = c("ledgr_sweep_filter_no_completed_candidates", "ledgr_invalid_args")
    )
  }

  context <- ledgr_sweep_filter_context(sweep_results, completed, objective$criteria)
  rows <- vector("list", nrow(completed) * length(objective$criteria))
  row_index <- 0L
  for (candidate_index in seq_len(nrow(completed))) {
    candidate_id <- as.character(completed$candidate_id[[candidate_index]])
    for (criterion_index in seq_along(objective$criteria)) {
      row_index <- row_index + 1L
      step <- objective$criteria[[criterion_index]]
      evidence <- ledgr_sweep_filter_evidence(
        context,
        step,
        candidate_id,
        candidate_index
      )
      verdict <- ledgr_objective_step_evaluate(
        step,
        evidence = evidence,
        candidate_id = candidate_id
      )
      rows[[row_index]] <- list(
        candidate_id = candidate_id,
        candidate_row = as.integer(completed$candidate_row[[candidate_index]]),
        criterion_id = step$criterion_id,
        criterion_hash = step$criterion_hash,
        evidence_key = step$evidence_key,
        observed_value = as.numeric(verdict$value),
        threshold = ledgr_sweep_filter_threshold_label(verdict$threshold),
        passed = isTRUE(verdict$passed),
        reason = verdict$reason,
        evidence_source = verdict$evidence_source,
        criterion_params = step$params,
        details = verdict$details
      )
    }
  }

  identity <- ledgr_return_panel_sweep_identity(sweep_results)
  tear_down <- ledgr_sweep_filter_table(rows, objective, identity)
  eligible_by_candidate <- vapply(
    split(tear_down$passed, factor(
      tear_down$candidate_id,
      levels = as.character(completed$candidate_id)
    )),
    all,
    logical(1)
  )
  tear_down$eligible <- unname(eligible_by_candidate[tear_down$candidate_id])

  out <- list(
    tear_down = tear_down,
    metadata = list(
      source = "completed_sweep_evidence",
      schema_version = ledgr_sweep_filter_schema_version,
      sweep_id = identity$sweep_id,
      business_objective_hash = objective$business_objective_hash,
      business_objective_schema_version = objective$business_objective_schema_version,
      composition = objective$composition,
      criterion_ids = vapply(objective$criteria, `[[`, character(1), "criterion_id"),
      completed_candidate_ids = as.character(completed$candidate_id),
      excluded_candidate_ids = as.character(
        sweep_results$candidate_id[!completed_mask]
      ),
      input_identity = identity,
      objective = list(
        plan_json = objective$plan_json,
        business_objective_hash = objective$business_objective_hash
      )
    )
  )
  class(out) <- c("ledgr_sweep_filter_result", "list")
  ledgr_sweep_filter_result_validate(out)
}

#' @export
as_tibble.ledgr_sweep_filter_result <- function(x, ...) {
  x <- ledgr_sweep_filter_result_validate(x)
  tibble::as_tibble(x$tear_down)
}

#' @export
print.ledgr_sweep_filter_result <- function(x, ...) {
  x <- ledgr_sweep_filter_result_validate(x)
  table <- tibble::as_tibble(x$tear_down)
  cat("# ledgr sweep eligibility evidence\n")
  cat(sprintf("# i candidates: %d\n", length(x$metadata$completed_candidate_ids)))
  cat(sprintf("# i criteria: %d\n", length(x$metadata$criterion_ids)))
  cat("# i composition: all criteria must pass\n\n")
  dots <- list(...)
  if (is.null(dots$n)) dots$n <- nrow(table)
  do.call(print, c(list(table), dots))
  invisible(x)
}

#' @export
ledgr_candidate.ledgr_sweep_filter_result <- function(results, ...) {
  ledgr_sweep_filter_abort_selection("candidate")
}

ledgr_sweep_filter_validate_sweep <- function(x) {
  required <- c(
    "candidate_id", "candidate_row", "status", "max_drawdown", "n_trades",
    "params", "feature_params"
  )
  if (!inherits(x, "ledgr_sweep_results") || !is.data.frame(x) ||
      !all(required %in% names(x)) || nrow(x) == 0L) {
    rlang::abort(
      "`sweep_results` must be a non-empty ledgr_sweep_results object with its canonical candidate columns.",
      class = c("ledgr_invalid_sweep_filter_input", "ledgr_invalid_args")
    )
  }
  candidate_ids <- as.character(x$candidate_id)
  candidate_rows <- as.integer(x$candidate_row)
  if (anyNA(candidate_ids) || any(!nzchar(candidate_ids)) || anyDuplicated(candidate_ids) ||
      anyNA(candidate_rows) || anyDuplicated(candidate_rows)) {
    rlang::abort(
      "Sweep-filter candidate ids and candidate rows must be unique and complete.",
      class = c("ledgr_invalid_sweep_filter_input", "ledgr_invalid_args")
    )
  }
  x
}

ledgr_sweep_filter_context <- function(sweep, completed, criteria) {
  criterion_ids <- vapply(criteria, `[[`, character(1), "criterion_id")
  needs_return_panel <- any(
    criterion_ids == "positive_trajectory" | grepl("^diagnostic_", criterion_ids)
  )
  panel <- if (needs_return_panel) {
    ledgr_sweep_returns_panel(
      sweep,
      candidates = as.character(completed$candidate_id),
      value = "returns",
      complete = TRUE
    )
  } else {
    NULL
  }
  if (!is.null(panel)) {
    ledgr_sweep_filter_validate_diagnostic_sources(criteria, panel)
  }

  needs_trades <- criterion_ids %in% c("even_trades", "even_profit", "stable_runs")
  trades <- if (any(needs_trades)) {
    ledgr_sweep_trades(sweep, candidates = as.character(completed$candidate_id))
  } else {
    NULL
  }

  stable_regions <- list()
  stable_indexes <- which(criterion_ids == "stable_region")
  for (i in stable_indexes) {
    step <- criteria[[i]]
    stable_regions[[step$criterion_hash]] <- ledgr_sweep_filter_stable_region(
      completed,
      step
    )
  }

  list(
    sweep = sweep,
    completed = completed,
    return_panel = panel,
    trades = trades,
    scoring_range = attr(sweep, "scoring_range", exact = TRUE),
    stable_regions = stable_regions
  )
}

ledgr_sweep_filter_validate_diagnostic_sources <- function(criteria, panel) {
  diagnostic <- criteria[vapply(
    criteria,
    function(step) grepl("^diagnostic_", step$criterion_id),
    logical(1)
  )]
  for (step in diagnostic) {
    source_panel_hash <- step$evidence_snapshot$source_metadata$panel_hash %||% NA_character_
    if (!is.character(source_panel_hash) || length(source_panel_hash) != 1L ||
        is.na(source_panel_hash) || !identical(source_panel_hash, panel$panel_hash)) {
      rlang::abort(
        sprintf(
          "Diagnostic evidence for criterion `%s` was computed from a different return panel.",
          step$criterion_id
        ),
        class = c("ledgr_sweep_filter_diagnostic_source_mismatch", "ledgr_invalid_args"),
        criterion_id = step$criterion_id,
        expected_panel_hash = panel$panel_hash,
        observed_panel_hash = source_panel_hash
      )
    }
  }
  invisible(TRUE)
}

ledgr_sweep_filter_evidence <- function(context,
                                        step,
                                        candidate_id,
                                        candidate_index) {
  switch(
    step$evidence_key,
    "summary.max_drawdown" = context$completed$max_drawdown[[candidate_index]],
    "summary.n_trades" = context$completed$n_trades[[candidate_index]],
    retained_equity = {
      long <- context$return_panel$long
      long[as.character(long$candidate_id) == candidate_id, "equity", drop = FALSE]
    },
    closed_trades = list(
      trades = context$trades[
        as.character(context$trades$candidate_id) == candidate_id,
        ,
        drop = FALSE
      ],
      scoring_range = context$scoring_range
    ),
    candidate_metric_lattice = context$stable_regions[[step$criterion_hash]],
    if (grepl("^diagnostic\\.", step$evidence_key)) NULL else {
      ledgr_objective_abort_missing(step$criterion_id, step$evidence_key, candidate_id)
    }
  )
}

ledgr_sweep_filter_stable_region <- function(completed, step) {
  metric <- step$params$metric
  if (!(metric %in% names(completed))) {
    ledgr_objective_abort_missing("stable_region", paste0("summary.", metric))
  }
  grid <- ledgr_sweep_filter_parameter_grid(
    completed,
    parameter_columns = step$params$parameter_columns
  )
  ledgr_stable_region_detect(
    grid = grid,
    metric = completed[[metric]],
    parameter_columns = setdiff(names(grid), "candidate_id"),
    direction = step$params$direction,
    min_neighbors = step$params$min_neighbors
  )
}

ledgr_sweep_filter_parameter_grid <- function(completed, parameter_columns = NULL) {
  records <- lapply(seq_len(nrow(completed)), function(i) {
    strategy <- completed$params[[i]]
    feature <- completed$feature_params[[i]]
    if (!is.list(strategy) || is.data.frame(strategy) ||
        !is.list(feature) || is.data.frame(feature)) {
      rlang::abort(
        "Stable-region sweep parameters must be named scalar lists.",
        class = c("ledgr_stable_region_invalid_grid", "ledgr_invalid_args")
      )
    }
    strategy_names <- names(strategy) %||% character()
    feature_names <- names(feature) %||% character()
    overlap <- intersect(strategy_names, feature_names)
    if (length(overlap) > 0L) {
      rlang::abort(
        sprintf(
          "Stable-region parameter names are ambiguous across strategy and feature namespaces: %s.",
          paste(overlap, collapse = ", ")
        ),
        class = c("ledgr_sweep_filter_ambiguous_parameter", "ledgr_stable_region_invalid_grid", "ledgr_invalid_args"),
        parameter_columns = overlap
      )
    }
    c(strategy, feature)
  })

  available <- unique(unlist(lapply(records, names), use.names = FALSE))
  if (is.null(parameter_columns)) {
    consistent <- available[vapply(available, function(column) {
      all(vapply(records, function(record) column %in% names(record), logical(1)))
    }, logical(1))]
    parameter_columns <- consistent[vapply(consistent, function(column) {
      values <- lapply(records, `[[`, column)
      length(unique(vapply(values, ledgr_sweep_filter_parameter_key, character(1)))) > 1L
    }, logical(1))]
  }
  if (is.null(parameter_columns) || length(parameter_columns) == 0L) {
    rlang::abort(
      "Stable-region filtering requires at least one varying scalar parameter axis.",
      class = c("ledgr_stable_region_invalid_grid", "ledgr_invalid_args")
    )
  }
  parameter_columns <- ledgr_objective_parameter_columns(parameter_columns)
  missing <- parameter_columns[vapply(parameter_columns, function(column) {
    any(!vapply(records, function(record) column %in% names(record), logical(1)))
  }, logical(1))]
  if (length(missing) > 0L) {
    rlang::abort(
      sprintf("Stable-region parameter columns are missing from the sweep: %s.", paste(missing, collapse = ", ")),
      class = c("ledgr_sweep_filter_parameter_missing", "ledgr_stable_region_invalid_grid", "ledgr_invalid_args"),
      parameter_columns = missing
    )
  }

  columns <- lapply(parameter_columns, function(column) {
    ledgr_sweep_filter_parameter_column(lapply(records, `[[`, column), column)
  })
  names(columns) <- parameter_columns
  data.frame(
    candidate_id = as.character(completed$candidate_id),
    columns,
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
}

ledgr_sweep_filter_parameter_key <- function(x) {
  if (length(x) != 1L || is.list(x) || is.data.frame(x)) return("<non-scalar>")
  paste(paste(class(x), collapse = "/"), as.character(x), sep = ":")
}

ledgr_sweep_filter_parameter_column <- function(values, column) {
  valid <- vapply(values, function(value) {
    length(value) == 1L && !is.list(value) && !is.data.frame(value) && !is.na(value)
  }, logical(1))
  if (!all(valid)) {
    rlang::abort(
      sprintf("Stable-region parameter `%s` must be one non-missing scalar per candidate.", column),
      class = c("ledgr_stable_region_invalid_grid", "ledgr_invalid_args"),
      parameter_columns = column
    )
  }
  reference_class <- class(values[[1L]])
  compatible <- vapply(values, function(value) identical(class(value), reference_class), logical(1))
  if (!all(compatible)) {
    numeric_mix <- all(vapply(values, is.numeric, logical(1)))
    if (!numeric_mix) {
      rlang::abort(
        sprintf("Stable-region parameter `%s` has inconsistent value classes.", column),
        class = c("ledgr_stable_region_invalid_grid", "ledgr_invalid_args"),
        parameter_columns = column
      )
    }
  }
  do.call(c, unname(values))
}

ledgr_sweep_filter_threshold_label <- function(x) {
  if (is.character(x)) return(as.character(x))
  if (is.logical(x)) return(if (isTRUE(x)) "TRUE" else "FALSE")
  if (is.numeric(x)) {
    if (is.infinite(x)) return(if (x > 0) "Inf" else "-Inf")
    return(format(x, digits = 15L, scientific = FALSE, trim = TRUE))
  }
  as.character(x)
}

ledgr_sweep_filter_table <- function(rows, objective, identity) {
  tibble::tibble(
    candidate_id = vapply(rows, `[[`, character(1), "candidate_id"),
    candidate_row = vapply(rows, `[[`, integer(1), "candidate_row"),
    criterion_id = vapply(rows, `[[`, character(1), "criterion_id"),
    observed_value = vapply(rows, `[[`, numeric(1), "observed_value"),
    threshold = vapply(rows, `[[`, character(1), "threshold"),
    passed = vapply(rows, `[[`, logical(1), "passed"),
    reason = vapply(rows, `[[`, character(1), "reason"),
    evidence_source = vapply(rows, `[[`, character(1), "evidence_source"),
    eligible = rep(FALSE, length(rows)),
    criterion_hash = vapply(rows, `[[`, character(1), "criterion_hash"),
    evidence_key = vapply(rows, `[[`, character(1), "evidence_key"),
    business_objective_hash = rep(objective$business_objective_hash, length(rows)),
    sweep_id = rep(identity$sweep_id, length(rows)),
    snapshot_hash = rep(identity$snapshot_hash, length(rows)),
    metric_context_hash = rep(identity$metric_context_hash, length(rows)),
    cost_model_hash = rep(identity$cost_model_hash, length(rows)),
    risk_chain_hash = rep(identity$risk_chain_hash, length(rows)),
    criterion_params = lapply(rows, `[[`, "criterion_params"),
    details = lapply(rows, `[[`, "details")
  )
}

ledgr_sweep_filter_result_validate <- function(x) {
  required <- c(
    "candidate_id", "candidate_row", "criterion_id", "criterion_hash",
    "evidence_key", "observed_value", "threshold", "passed", "reason",
    "evidence_source", "eligible", "business_objective_hash", "sweep_id",
    "snapshot_hash", "metric_context_hash", "cost_model_hash", "risk_chain_hash",
    "criterion_params", "details"
  )
  if (!inherits(x, "ledgr_sweep_filter_result") || !is.list(x) ||
      !is.data.frame(x$tear_down) || !is.list(x$metadata) ||
      !all(required %in% names(x$tear_down)) ||
      !identical(as.integer(x$metadata$schema_version), ledgr_sweep_filter_schema_version) ||
      !identical(x$metadata$composition, "all_pass") ||
      nrow(x$tear_down) == 0L) {
    rlang::abort(
      "`x` has an invalid ledgr sweep-filter result shape.",
      class = c("ledgr_invalid_sweep_filter_result", "ledgr_invalid_args")
    )
  }
  expected_rows <- length(x$metadata$completed_candidate_ids) * length(x$metadata$criterion_ids)
  expected_candidate_ids <- rep(
    x$metadata$completed_candidate_ids,
    each = length(x$metadata$criterion_ids)
  )
  expected_criterion_ids <- rep(
    x$metadata$criterion_ids,
    times = length(x$metadata$completed_candidate_ids)
  )
  expected_eligible <- vapply(
    split(
      x$tear_down$passed,
      factor(
        x$tear_down$candidate_id,
        levels = x$metadata$completed_candidate_ids
      )
    ),
    all,
    logical(1)
  )
  if (nrow(x$tear_down) != expected_rows ||
      anyNA(x$tear_down$passed) || anyNA(x$tear_down$eligible) ||
      !identical(as.character(x$tear_down$candidate_id), expected_candidate_ids) ||
      !identical(as.character(x$tear_down$criterion_id), expected_criterion_ids) ||
      !identical(
        as.logical(x$tear_down$eligible),
        unname(expected_eligible[x$tear_down$candidate_id])
      ) ||
      !all(as.character(x$tear_down$business_objective_hash) == x$metadata$business_objective_hash)) {
    rlang::abort(
      "Sweep-filter result rows do not match their objective or candidate metadata.",
      class = c("ledgr_invalid_sweep_filter_result", "ledgr_invalid_args")
    )
  }
  x
}

ledgr_sweep_filter_abort_selection <- function(operation) {
  classes <- switch(
    operation,
    candidate = "ledgr_sweep_filter_not_candidate",
    promote = "ledgr_sweep_filter_promotion_forbidden",
    walk_forward = "ledgr_sweep_filter_walk_forward_forbidden"
  )
  rlang::abort(
    sprintf(
      "A ledgr_sweep_filter_result is all-candidates eligibility evidence and cannot be used for %s.",
      switch(
        operation,
        candidate = "candidate extraction",
        promote = "promotion",
        walk_forward = "walk-forward selection"
      )
    ),
    class = c(classes, "ledgr_sweep_filter_evidence_only", "ledgr_invalid_args")
  )
}
