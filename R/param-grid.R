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
