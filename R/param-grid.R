#' Create a typed parameter grid
#'
#' `ledgr_param_grid()` creates a validated parameter-grid object for sweep
#' candidate identity. The grid stores parameter combinations and labels;
#' it does not execute candidates by itself.
#'
#' Each argument must be a JSON-safe list of strategy parameters. Named
#' arguments preserve their names as grid labels. Unnamed arguments receive a
#' stable `grid_<hash>` label derived from ledgr's canonical JSON encoding of
#' the parameter list. Grid labels are labels only; they are not run IDs.
#'
#' Indicator parameters can live in the same list as strategy parameters when an
#' experiment uses `features = function(params) ...`. There is no separate
#' indicator-sweep API in v0.1.8.
#'
#' @section Articles:
#' Exploratory sweeps and promotion:
#' `vignette("sweeps", package = "ledgr")`
#' `system.file("doc", "sweeps.html", package = "ledgr")`
#'
#' @param ... Parameter-list entries.
#' @return A `ledgr_param_grid` object with `labels` and `params` fields.
#' @examples
#' grid <- ledgr_param_grid(
#'   conservative = list(threshold = 0.01, qty = 1),
#'   list(threshold = 0.02, qty = 2)
#' )
#' grid$labels
#' grid$params
#' @export
ledgr_param_grid <- function(...) {
  params <- list(...)
  if (length(params) == 0L) {
    rlang::abort("`ledgr_param_grid()` requires at least one parameter-list entry.", class = "ledgr_invalid_args")
  }

  supplied_names <- names(params)
  if (is.null(supplied_names)) {
    supplied_names <- rep("", length(params))
  }

  labels <- character(length(params))
  for (i in seq_along(params)) {
    if (!is.list(params[[i]]) || is.data.frame(params[[i]])) {
      rlang::abort(
        sprintf("Parameter grid entry %d must be a list.", i),
        class = "ledgr_invalid_param_grid"
      )
    }
    canonical_json(params[[i]])

    if (nzchar(supplied_names[[i]])) {
      labels[[i]] <- supplied_names[[i]]
    } else {
      labels[[i]] <- ledgr_param_grid_auto_label(params[[i]])
    }
  }

  if (any(!nzchar(trimws(labels)))) {
    rlang::abort("Parameter grid labels must be non-empty.", class = "ledgr_invalid_param_grid")
  }
  duplicate_labels <- unique(labels[duplicated(labels)])
  if (length(duplicate_labels) > 0L) {
    rlang::abort(
      sprintf("Duplicate parameter grid labels: %s", paste(duplicate_labels, collapse = ", ")),
      class = "ledgr_duplicate_param_grid_labels"
    )
  }

  structure(
    list(labels = labels, params = unname(params)),
    class = c("ledgr_param_grid", "list")
  )
}

ledgr_param_grid_auto_label <- function(params) {
  hash <- digest::digest(unname(canonical_json(params)), algo = "sha256")
  paste0("grid_", substr(hash, 1L, 12L))
}

#' Create feature, strategy, and executable sweep grids
#'
#' These helpers keep feature-materialization parameters and strategy-runtime
#' parameters in separate namespaces before composing executable sweep
#' candidates.
#'
#' @param ... Named grid columns for `ledgr_feature_grid()` and
#'   `ledgr_strategy_grid()`, or named executable candidate specs for
#'   `ledgr_grid_named()` / `ledgr_grid_add_baseline()`.
#' @param .filter Optional narrow filter expression evaluated against generated
#'   grid columns.
#' @param features A `ledgr_feature_grid` object. Omitted to use one empty
#'   feature-parameter row.
#' @param strategy A `ledgr_strategy_grid` or `ledgr_param_grid` object. Omitted
#'   to use one empty strategy-parameter row.
#' @param grid A `ledgr_executable_grid` object.
#' @return A grid object.
#' @examples
#' fg <- ledgr_feature_grid(fast_n = c(10L, 20L), slow_n = 40L, .filter = fast_n < slow_n)
#' sg <- ledgr_strategy_grid(qty = c(50L, 100L))
#' ledgr_grid_cross(features = fg, strategy = sg)
#' @export
ledgr_feature_grid <- function(..., .filter = NULL) {
  filter_expr <- substitute(.filter)
  ledgr_build_cross_grid(
    list(...),
    filter_expr = filter_expr,
    filter_missing = missing(.filter),
    label_prefix = "feature",
    class = c("ledgr_feature_grid", "list")
  )
}

#' @rdname ledgr_feature_grid
#' @export
ledgr_strategy_grid <- function(..., .filter = NULL) {
  filter_expr <- substitute(.filter)
  grid <- ledgr_build_cross_grid(
    list(...),
    filter_expr = filter_expr,
    filter_missing = missing(.filter),
    label_prefix = "strategy",
    class = c("ledgr_strategy_grid", "ledgr_param_grid", "list")
  )
  grid
}

#' @rdname ledgr_feature_grid
#' @export
ledgr_grid_cross <- function(features, strategy) {
  features_missing <- missing(features)
  strategy_missing <- missing(strategy)
  if (features_missing && strategy_missing) {
    rlang::abort(
      "`ledgr_grid_cross()` requires `features`, `strategy`, or both. Use `ledgr_param_grid(candidate = list())` for one empty legacy candidate.",
      class = c("ledgr_invalid_executable_grid", "ledgr_invalid_args")
    )
  }
  if (features_missing) {
    features <- ledgr_empty_feature_grid()
  }
  if (strategy_missing) {
    strategy <- ledgr_empty_strategy_grid()
  }
  if (!inherits(features, "ledgr_feature_grid")) {
    rlang::abort("`features` must be a ledgr_feature_grid object.", class = c("ledgr_invalid_executable_grid", "ledgr_invalid_args"))
  }
  if (!inherits(strategy, "ledgr_param_grid")) {
    rlang::abort("`strategy` must be a ledgr_strategy_grid or ledgr_param_grid object.", class = c("ledgr_invalid_executable_grid", "ledgr_invalid_args"))
  }

  labels <- character(length(features$params) * length(strategy$params))
  params <- vector("list", length(labels))
  k <- 0L
  for (i in seq_along(features$params)) {
    for (j in seq_along(strategy$params)) {
      k <- k + 1L
      labels[[k]] <- paste(features$labels[[i]], strategy$labels[[j]], sep = "/")
      params[[k]] <- ledgr_executable_candidate_spec(
        feature = features$params[[i]],
        strategy = strategy$params[[j]]
      )
    }
  }
  ledgr_new_executable_grid(labels, params)
}

#' @rdname ledgr_feature_grid
#' @export
ledgr_grid_named <- function(...) {
  specs <- list(...)
  labels <- names(specs)
  if (length(specs) == 0L) {
    rlang::abort("`ledgr_grid_named()` requires at least one named candidate.", class = c("ledgr_invalid_executable_grid", "ledgr_invalid_args"))
  }
  if (is.null(labels) || anyNA(labels) || any(!nzchar(labels))) {
    rlang::abort("All `ledgr_grid_named()` candidates must be named.", class = c("ledgr_invalid_executable_grid", "ledgr_invalid_args"))
  }
  params <- lapply(specs, ledgr_executable_candidate_spec_from_user)
  ledgr_new_executable_grid(labels, params)
}

#' @rdname ledgr_feature_grid
#' @export
ledgr_grid_add_baseline <- function(grid, ...) {
  if (!inherits(grid, "ledgr_executable_grid")) {
    rlang::abort("`grid` must be a ledgr_executable_grid object.", class = c("ledgr_invalid_executable_grid", "ledgr_invalid_args"))
  }
  additions <- ledgr_grid_named(...)
  ledgr_new_executable_grid(
    c(grid$labels, additions$labels),
    c(grid$params, additions$params)
  )
}

ledgr_build_cross_grid <- function(args, filter_expr, filter_missing, label_prefix, class) {
  ledgr_validate_grid_columns(args)
  expanded <- expand.grid(args, KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  if (nrow(expanded) < 1L) {
    rlang::abort("Grid construction produced no rows.", class = c("ledgr_invalid_grid", "ledgr_invalid_args"))
  }
  if (!isTRUE(filter_missing)) {
    keep <- ledgr_eval_grid_filter(filter_expr, expanded)
    expanded <- expanded[keep, , drop = FALSE]
  }
  if (nrow(expanded) < 1L) {
    rlang::abort("`.filter` removed all grid rows.", class = c("ledgr_grid_filter_invalid", "ledgr_invalid_args"))
  }
  params <- lapply(seq_len(nrow(expanded)), function(i) {
    out <- lapply(names(expanded), function(nm) expanded[[nm]][[i]])
    names(out) <- names(expanded)
    out
  })
  labels <- vapply(params, function(row) {
    paste0(label_prefix, "_", substr(digest::digest(unname(canonical_json(row)), algo = "sha256"), 1L, 12L))
  }, character(1))
  ledgr_validate_grid_labels(labels, class = "ledgr_duplicate_grid_labels")
  structure(
    list(labels = unname(labels), params = unname(params)),
    class = class
  )
}

ledgr_validate_grid_columns <- function(args) {
  if (!is.list(args) || length(args) == 0L) {
    rlang::abort("Grid helpers require at least one named parameter column.", class = c("ledgr_invalid_grid", "ledgr_invalid_args"))
  }
  nms <- names(args)
  if (is.null(nms) || anyNA(nms) || any(!nzchar(nms))) {
    rlang::abort("Grid parameter columns must be named.", class = c("ledgr_invalid_grid", "ledgr_invalid_args"))
  }
  if (anyDuplicated(nms)) {
    dup <- unique(nms[duplicated(nms)])
    rlang::abort(sprintf("Duplicate grid parameter column: %s.", dup[[1L]]), class = c("ledgr_invalid_grid", "ledgr_invalid_args"))
  }
  for (nm in nms) {
    value <- args[[nm]]
    if (is.null(value) || is.function(value) || is.environment(value) || is.data.frame(value) || is.list(value) || !is.atomic(value) || length(value) < 1L) {
      rlang::abort(
        sprintf("Grid column `%s` must be a non-empty atomic vector of JSON-safe scalar values.", nm),
        class = c("ledgr_invalid_grid", "ledgr_invalid_args")
      )
    }
    for (i in seq_along(value)) {
      canonical_json(list(value = value[[i]]))
    }
  }
  invisible(TRUE)
}

ledgr_eval_grid_filter <- function(expr, data) {
  ledgr_validate_grid_filter_expr(expr, names(data))
  env <- list2env(as.list(data), parent = baseenv())
  value <- tryCatch(
    eval(expr, envir = env),
    error = function(e) {
      rlang::abort(
        sprintf("`.filter` could not be evaluated: %s", conditionMessage(e)),
        class = c("ledgr_grid_filter_invalid", "ledgr_invalid_args")
      )
    }
  )
  if (!is.logical(value) || !(length(value) %in% c(1L, nrow(data))) || anyNA(value)) {
    rlang::abort(
      "`.filter` must evaluate to a non-NA logical vector of length one or the number of grid rows.",
      class = c("ledgr_grid_filter_invalid", "ledgr_invalid_args")
    )
  }
  if (length(value) == 1L) {
    value <- rep(value, nrow(data))
  }
  value
}

ledgr_validate_grid_filter_expr <- function(expr, columns) {
  symbols <- setdiff(all.names(expr, functions = TRUE, unique = TRUE), c("TRUE", "FALSE", "NA", "NA_real_", "NA_integer_", "NA_character_", "NULL"))
  allowed <- unique(c(
    columns,
    "(", "{", "<", ">", "<=", ">=", "==", "!=", "&", "|", "!", "+", "-", "*", "/", "^", "%%", "%/%", "%in%",
    "abs", "exp", "log", "log10", "sqrt", "min", "max", "pmin", "pmax", "round", "floor", "ceiling", "is.na", "is.finite", "c"
  ))
  unknown <- setdiff(symbols, allowed)
  if (length(unknown) > 0L) {
    rlang::abort(
      sprintf("`.filter` references unsupported or unknown symbol `%s`.", unknown[[1L]]),
      class = c("ledgr_grid_filter_invalid", "ledgr_invalid_args")
    )
  }
  invisible(TRUE)
}

ledgr_validate_grid_labels <- function(labels, class = "ledgr_duplicate_param_grid_labels") {
  if (!is.character(labels) || anyNA(labels) || any(!nzchar(labels))) {
    rlang::abort("Grid labels must be non-empty strings.", class = c("ledgr_invalid_grid", "ledgr_invalid_args"))
  }
  duplicate_labels <- unique(labels[duplicated(labels)])
  if (length(duplicate_labels) > 0L) {
    rlang::abort(
      sprintf("Duplicate grid labels: %s", paste(duplicate_labels, collapse = ", ")),
      class = class
    )
  }
  invisible(TRUE)
}

ledgr_empty_feature_grid <- function() {
  # These labels are visible in composed candidate labels when one side is omitted.
  structure(list(labels = "features_empty", params = list(list())), class = c("ledgr_feature_grid", "list"))
}

ledgr_empty_strategy_grid <- function() {
  # These labels are visible in composed candidate labels when one side is omitted.
  structure(list(labels = "strategy_empty", params = list(list())), class = c("ledgr_strategy_grid", "ledgr_param_grid", "list"))
}

ledgr_executable_candidate_spec <- function(feature = list(), strategy = list()) {
  if (!is.list(feature) || is.data.frame(feature)) {
    rlang::abort("Executable candidate `feature` params must be a list.", class = c("ledgr_invalid_executable_grid", "ledgr_invalid_args"))
  }
  if (!is.list(strategy) || is.data.frame(strategy)) {
    rlang::abort("Executable candidate `strategy` params must be a list.", class = c("ledgr_invalid_executable_grid", "ledgr_invalid_args"))
  }
  canonical_json(feature)
  canonical_json(strategy)
  list(feature_params = feature, strategy_params = strategy)
}

ledgr_executable_candidate_spec_from_user <- function(spec) {
  if (!is.list(spec) || is.data.frame(spec)) {
    rlang::abort("Executable candidates must be lists containing `feature`, `strategy`, or both.", class = c("ledgr_invalid_executable_grid", "ledgr_invalid_args"))
  }
  allowed <- c("feature", "strategy")
  unknown <- setdiff(names(spec) %||% character(), allowed)
  if (length(unknown) > 0L) {
    rlang::abort(
      sprintf("Unknown executable candidate field `%s`; use `feature` and/or `strategy`.", unknown[[1L]]),
      class = c("ledgr_invalid_executable_grid", "ledgr_invalid_args")
    )
  }
  ledgr_executable_candidate_spec(
    feature = spec$feature %||% list(),
    strategy = spec$strategy %||% list()
  )
}

ledgr_new_executable_grid <- function(labels, params) {
  ledgr_validate_grid_labels(labels, class = "ledgr_duplicate_executable_grid_labels")
  if (!is.list(params) || length(params) != length(labels)) {
    rlang::abort("Executable grid params must match labels.", class = c("ledgr_invalid_executable_grid", "ledgr_invalid_args"))
  }
  for (param in params) {
    ledgr_executable_candidate_spec(
      feature = param$feature_params %||% list(),
      strategy = param$strategy_params %||% list()
    )
  }
  structure(
    list(labels = unname(labels), params = unname(params)),
    class = c("ledgr_executable_grid", "ledgr_param_grid", "list")
  )
}

ledgr_grid_candidate_feature_params <- function(params) {
  if (is.list(params) && !is.data.frame(params) && is.list(params$feature_params)) {
    return(params$feature_params)
  }
  params
}

ledgr_grid_candidate_strategy_params <- function(params) {
  if (is.list(params) && !is.data.frame(params) && is.list(params$strategy_params)) {
    return(params$strategy_params)
  }
  params
}

#' Print a parameter grid
#'
#' @param x A `ledgr_param_grid` object.
#' @param ... Unused.
#' @return The input object, invisibly.
#' @export
print.ledgr_param_grid <- function(x, ...) {
  if (!inherits(x, "ledgr_param_grid")) {
    rlang::abort("`x` must be a ledgr_param_grid object.", class = "ledgr_invalid_args")
  }
  n <- length(x$params)
  cat("ledgr_param_grid\n")
  cat("================\n")
  cat("Combinations: ", n, "\n", sep = "")
  shown <- utils::head(x$labels, 6L)
  cat("Labels:       ", paste(shown, collapse = ", "), "\n", sep = "")
  if (n > length(shown)) {
    cat("              ... ", n - length(shown), " more\n", sep = "")
  }
  cat("\n")
  cat("Grid labels identify sweep candidates; they are not committed run IDs.\n")
  invisible(x)
}
