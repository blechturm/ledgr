#' Review sweep candidates without selecting one
#'
#' `ledgr_sweep_review()` packages the common sweep-inspection shape into a
#' small list of tables. It ranks completed candidates by an explicit expression,
#' returns the top rows, and separates failed or warning-bearing rows for review.
#' It does not select or promote a candidate.
#'
#' @param sweep A `ledgr_sweep_results` object, reopened sweep, or compatible
#'   tibble-like candidate table.
#' @param rank_by Ranking expression evaluated against completed candidate rows.
#'   Use `desc(metric)` or `-metric` for descending numeric rankings.
#' @param n Number of top completed candidates to keep in `top`.
#' @return A `ledgr_sweep_review` list with `ranked`, `top`, `issues`,
#'   `counts`, `rank_by`, and `n`. For classed sweep input, `ranked` retains
#'   the source sweep lineage needed for explicit candidate extraction; `top`
#'   is always a lineage-free presentation table. `top` carries the valuation
#'   flags beside the ranking columns, so a completed candidate that froze a
#'   holding or used an assumed terminal outcome stays rankable but visible.
#'   `issues` shows each incomplete or failed candidate's `stop_reason` and
#'   `affected_instrument_ids`. `counts` lists attempted, done, incomplete,
#'   and failed candidates; it is disclosure only.
#' @examples
#' \dontrun{
#' review <- ledgr_sweep_review(sweep, rank_by = desc(sharpe_ratio), n = 5)
#' review$top
#' review$issues
#' }
#' @export
ledgr_sweep_review <- function(sweep, rank_by, n = 5L) {
  ledgr_rng_force_args(lazy = "rank_by")
  rank_missing <- missing(rank_by)
  rank_expr <- substitute(rank_by)
  rank_env <- parent.frame()
  ledgr_rng_preserve_caller(ledgr_sweep_review_impl(
    sweep = sweep,
    n = n,
    rank_expr = rank_expr,
    rank_env = rank_env,
    rank_missing = rank_missing
  ))
}

ledgr_sweep_review_impl <- function(sweep, n, rank_expr, rank_env, rank_missing) {
  if (isTRUE(rank_missing)) {
    rlang::abort(
      "`rank_by` must be supplied so the ranking rule stays visible.",
      class = "ledgr_invalid_args"
    )
  }
  if (!is.numeric(n) || length(n) != 1L || is.na(n) || !is.finite(n) || n < 1L || n != as.integer(n)) {
    rlang::abort("`n` must be a whole number >= 1.", class = "ledgr_invalid_args")
  }
  n <- as.integer(n)

  view <- tibble::as_tibble(sweep)
  required <- c("candidate_id", "status")
  missing <- setdiff(required, names(view))
  if (length(missing) > 0L) {
    rlang::abort(
      sprintf("`sweep` is missing required column(s): %s.", paste(missing, collapse = ", ")),
      class = "ledgr_invalid_sweep_review_input"
    )
  }

  completed <- view[as.character(view$status) == "DONE" & !is.na(view$status), , drop = FALSE]
  ranked <- ledgr_sweep_review_rank(completed, rank_expr, rank_env)
  if (inherits(sweep, "ledgr_sweep_results")) {
    ranked <- ledgr_sweep_results_restore(ranked, sweep)
  }
  top_cols <- unique(c(ledgr_sweep_review_top_cols(), all.vars(rank_expr)))
  top_data <- lapply(names(ranked), function(name) ranked[[name]])
  names(top_data) <- names(ranked)
  top_view <- tibble::as_tibble(top_data)
  top <- top_view[seq_len(min(n, nrow(top_view))), intersect(top_cols, names(top_view)), drop = FALSE]
  top <- ledgr_sweep_review_parameter_view(top)
  issues <- ledgr_sweep_review_issue_rows(view)
  counts <- ledgr_selection_counts(
    view$status,
    valuation_state = view[["valuation_state"]],
    assumed = view[["assumed_terminal_outcomes"]]
  )

  out <- list(
    ranked = ranked,
    top = top,
    issues = issues,
    counts = counts,
    rank_by = paste(deparse(rank_expr), collapse = " "),
    n = n
  )
  structure(out, class = c("ledgr_sweep_review", "list"))
}

#' @export
print.ledgr_sweep_review <- function(x, ...) {
  if (!inherits(x, "ledgr_sweep_review")) {
    rlang::abort("`x` must be a ledgr_sweep_review object.", class = "ledgr_invalid_args")
  }
  cat("# ledgr sweep review\n", sep = "")
  cat("# i rank_by: ", x$rank_by, "\n", sep = "")
  cat("# i top rows: ", nrow(x$top), "\n", sep = "")
  if (!is.null(x$counts)) {
    cat(paste0("# i ", ledgr_selection_count_lines(x$counts)), sep = "\n")
  }
  cat("\n")
  cat("Top candidates:\n")
  print(x$top, ...)
  cat("\nIssue rows:\n")
  print(x$issues, ...)
  invisible(x)
}

ledgr_sweep_review_rank <- function(completed, rank_expr, caller_env) {
  if (nrow(completed) < 1L) {
    completed$rank <- integer()
    return(completed)
  }

  eval_env <- list2env(as.list(completed), parent = caller_env)
  if (!exists("desc", envir = eval_env, inherits = TRUE)) {
    assign("desc", function(x) -xtfrm(x), envir = eval_env)
  }
  rank_key <- tryCatch(
    eval(rank_expr, envir = eval_env),
    error = function(e) {
      rlang::abort(
        "`rank_by` could not be evaluated against completed sweep candidates.",
        class = "ledgr_invalid_sweep_review_rank",
        parent = e
      )
    }
  )
  if (is.null(rank_key) || is.list(rank_key) || length(rank_key) != nrow(completed)) {
    rlang::abort(
      "`rank_by` must evaluate to one atomic value per completed candidate.",
      class = "ledgr_invalid_sweep_review_rank"
    )
  }

  ord <- order(rank_key, na.last = TRUE)
  ranked <- completed[ord, , drop = FALSE]
  ranked$rank <- seq_len(nrow(ranked))
  ranked[, c("rank", setdiff(names(ranked), "rank")), drop = FALSE]
}

ledgr_sweep_review_issue_rows <- function(view) {
  status <- as.character(view$status)
  failed <- is.na(status) | status != "DONE"
  warned <- rep(FALSE, nrow(view))
  if ("warnings" %in% names(view)) {
    warned <- vapply(view$warnings, function(x) length(x) > 0L, logical(1))
  }
  issues <- view[failed | warned, , drop = FALSE]
  issues <- issues[, intersect(ledgr_sweep_review_issue_cols(), names(issues)), drop = FALSE]
  ledgr_sweep_review_parameter_view(issues)
}

ledgr_sweep_review_parameter_view <- function(x) {
  if (!"params" %in% names(x)) {
    return(x)
  }
  strategy <- vapply(x$params, ledgr_sweep_params_summary, character(1))
  feature <- if ("feature_params" %in% names(x)) {
    vapply(x$feature_params, ledgr_sweep_params_summary, character(1))
  } else {
    rep("{}", nrow(x))
  }
  x$params <- NULL
  x$feature_params <- NULL
  x$strategy_params <- strategy
  x$feature_params <- feature
  front <- c("rank", "strategy_params", "feature_params", "candidate_id")
  x[, c(intersect(front, names(x)), setdiff(names(x), front)), drop = FALSE]
}

ledgr_sweep_review_top_cols <- function() {
  c(
    "rank", "params", "feature_params", "candidate_id", "candidate_row", "status", "final_equity",
    "total_return", "sharpe_ratio", "max_drawdown", "n_trades",
    "valuation_state", "max_frozen_equity_weight", "frozen_at_end_value",
    "assumed_terminal_outcomes", "execution_seed", "params", "feature_params"
  )
}

ledgr_sweep_review_issue_cols <- function() {
  c(
    "params", "feature_params", "candidate_id", "candidate_row", "status",
    "stop_reason", "affected_instrument_ids", "error_class", "error_msg", "warnings"
  )
}

#' Create a disposable ledgr store path
#'
#' `ledgr_temp_store()` returns a path for a temporary `.duckdb` store and clears
#' any stale file already at that exact path. It does not initialize, open, seal,
#' or manage a ledgr store.
#'
#' @param path Optional `.duckdb` path to clear and return. When `NULL`, a fresh
#'   temporary path is generated.
#' @param pattern Prefix used when `path = NULL`.
#' @param tmpdir Temporary directory used when `path = NULL`.
#' @return A character scalar path ending in `.duckdb`.
#' @examples
#' db_path <- ledgr_temp_store()
#' file.exists(db_path)
#' @export
ledgr_temp_store <- function(path = NULL, pattern = "ledgr_store_", tmpdir = tempdir()) {
  if (is.null(path)) {
    path <- tempfile(pattern = pattern, tmpdir = tmpdir, fileext = ".duckdb")
  }
  if (!is.character(path) || length(path) != 1L || is.na(path) || !nzchar(path)) {
    rlang::abort("`path` must be a non-empty character scalar or NULL.", class = "ledgr_invalid_args")
  }
  if (!grepl("[.]duckdb$", path)) {
    rlang::abort("`path` must end in `.duckdb`.", class = "ledgr_invalid_args")
  }
  if (dir.exists(path)) {
    rlang::abort("`path` points to a directory, not a disposable `.duckdb` file.", class = "ledgr_invalid_args")
  }

  stale <- c(path, paste0(path, c(".wal", ".tmp")))
  stale <- stale[file.exists(stale) & !dir.exists(stale)]
  if (length(stale) > 0L) {
    ok <- unlink(stale, force = TRUE) == 0L
    if (!all(ok)) {
      rlang::abort("Failed to remove stale temporary store file(s).", class = "ledgr_temp_store_unlink_failed")
    }
  }
  path
}
