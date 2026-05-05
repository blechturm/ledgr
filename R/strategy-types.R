ledgr_strategy_type_check_universe <- function(universe) {
  if (is.null(universe)) {
    return(NULL)
  }
  if (!is.character(universe) ||
      length(universe) < 1L ||
      anyNA(universe) ||
      any(!nzchar(universe)) ||
      anyDuplicated(universe)) {
    rlang::abort(
      "`universe` must be NULL or a unique non-empty character vector.",
      class = "ledgr_invalid_strategy_type"
    )
  }
  universe
}

ledgr_strategy_type_check_names <- function(x, label, universe = NULL, full_universe = FALSE) {
  if (length(x) == 0L && is.null(names(x))) {
    names(x) <- character()
  }
  x_names <- names(x)
  if (is.null(x_names) ||
      length(x_names) != length(x) ||
      anyNA(x_names) ||
      any(!nzchar(x_names)) ||
      anyDuplicated(x_names)) {
    rlang::abort(
      sprintf("`%s` must have unique non-empty instrument names.", label),
      class = "ledgr_invalid_strategy_type"
    )
  }

  universe <- ledgr_strategy_type_check_universe(universe)
  if (!is.null(universe)) {
    missing <- setdiff(universe, x_names)
    extra <- setdiff(x_names, universe)
    if (length(extra) > 0L || (isTRUE(full_universe) && length(missing) > 0L)) {
      details <- c(
        if (length(missing) > 0L) sprintf("missing instruments: %s", paste(missing, collapse = ", ")),
        if (length(extra) > 0L) sprintf("extra instruments: %s", paste(extra, collapse = ", "))
      )
      rlang::abort(
        sprintf("`%s` is incompatible with `universe`; %s.", label, paste(details, collapse = "; ")),
        class = "ledgr_invalid_strategy_type"
      )
    }
  }

  x_names
}

ledgr_strategy_type_origin <- function(origin) {
  if (is.null(origin)) {
    return(NULL)
  }
  if (!is.character(origin) || length(origin) != 1L || is.na(origin) || !nzchar(origin)) {
    rlang::abort("`origin` must be NULL or a non-empty character scalar.", class = "ledgr_invalid_strategy_type")
  }
  origin
}

ledgr_strategy_type_empty_universe <- function(x) {
  universe <- attr(x, "universe", exact = TRUE)
  if (is.character(universe) && length(universe) > 0L) return(universe)
  names(x)
}

ledgr_strategy_type_stats <- function(x) {
  if (is.logical(x)) {
    return(sprintf("%d selected", sum(x, na.rm = TRUE)))
  }
  non_na <- sum(!is.na(x))
  sprintf("non-NA: %d/%d", non_na, length(x))
}

ledgr_print_strategy_vector <- function(x, type, ...) {
  origin <- attr(x, "origin", exact = TRUE)
  cat(sprintf("<%s> [%d asset%s]\n", type, length(x), if (length(x) == 1L) "" else "s"))
  if (!is.null(origin)) {
    cat("origin: ", origin, "\n", sep = "")
  }
  cat(ledgr_strategy_type_stats(x), "\n", sep = "")
  if (length(x) > 0L) {
    print(utils::head(stats::setNames(unclass(x), names(x)), 6L))
  }
  invisible(x)
}

#' Create a strategy signal vector
#'
#' `ledgr_signal()` creates a named numeric score vector for strategy helper
#' pipelines. Signals are intermediate objects; strategies must not return them
#' directly.
#'
#' @param x Named numeric vector of signal scores.
#' @param universe Optional universe used to reject extra instrument names.
#' @param origin Optional helper/source label for printing.
#' @return A `ledgr_signal` object.
#' @examples
#' ledgr_signal(c(AAA = 0.03, BBB = NA_real_), origin = "return_5")
#'
#' @section Articles:
#' Strategy helper pipelines:
#' `vignette("strategy-development", package = "ledgr")`
#' `system.file("doc", "strategy-development.html", package = "ledgr")`
#' @export
ledgr_signal <- function(x, universe = NULL, origin = NULL) {
  # Empty selections and weights are meaningful degenerate helper states; an
  # empty signal has no ranked/scored instruments and is treated as invalid.
  if (!is.numeric(x) || length(x) < 1L) {
    rlang::abort("`x` must be a non-empty named numeric vector.", class = "ledgr_invalid_strategy_type")
  }
  ledgr_strategy_type_check_names(x, "x", universe = universe, full_universe = FALSE)
  if (any(is.infinite(x))) {
    rlang::abort("`x` must not contain infinite signal values.", class = "ledgr_invalid_strategy_type")
  }
  structure(
    as.numeric(x) |> stats::setNames(names(x)),
    class = c("ledgr_signal", "numeric"),
    origin = ledgr_strategy_type_origin(origin)
  )
}

#' Create a strategy selection vector
#'
#' `ledgr_selection()` creates a named logical vector for strategy helper
#' pipelines. Selections are intermediate objects; strategies must not return
#' them directly.
#'
#' @param x Named logical vector where `TRUE` means selected.
#' @param universe Optional universe used to reject extra instrument names.
#' @param origin Optional helper/source label for printing.
#' @return A `ledgr_selection` object.
#' @examples
#' ledgr_selection(c(AAA = TRUE, BBB = FALSE), universe = c("AAA", "BBB"))
#'
#' @section Articles:
#' Strategy helper pipelines:
#' `vignette("strategy-development", package = "ledgr")`
#' `system.file("doc", "strategy-development.html", package = "ledgr")`
#' @export
ledgr_selection <- function(x, universe = NULL, origin = NULL) {
  if (!is.logical(x)) {
    rlang::abort("`x` must be a named logical vector.", class = "ledgr_invalid_strategy_type")
  }
  if (length(x) == 0L && is.null(names(x))) {
    names(x) <- character()
  }
  ledgr_strategy_type_check_names(x, "x", universe = universe, full_universe = FALSE)
  if (anyNA(x)) {
    rlang::abort("`x` must not contain missing selection values.", class = "ledgr_invalid_strategy_type")
  }
  structure(
    as.logical(x) |> stats::setNames(names(x)),
    class = c("ledgr_selection", "logical"),
    origin = ledgr_strategy_type_origin(origin),
    universe = if (length(x) == 0L) universe else NULL
  )
}

#' Create a strategy weight vector
#'
#' `ledgr_weights()` creates a named numeric portfolio-weight vector for
#' strategy helper pipelines. Weights are intermediate objects; strategies must
#' not return them directly.
#'
#' @param x Named numeric vector of weights.
#' @param universe Optional universe used to reject extra instrument names.
#' @param origin Optional helper/source label for printing.
#' @return A `ledgr_weights` object.
#' @examples
#' ledgr_weights(c(AAA = 0.5, BBB = 0.5), universe = c("AAA", "BBB"))
#'
#' @section Articles:
#' Strategy helper pipelines:
#' `vignette("strategy-development", package = "ledgr")`
#' `system.file("doc", "strategy-development.html", package = "ledgr")`
#' @export
ledgr_weights <- function(x, universe = NULL, origin = NULL) {
  if (!is.numeric(x)) {
    rlang::abort("`x` must be a named numeric vector.", class = "ledgr_invalid_strategy_type")
  }
  if (length(x) == 0L && is.null(names(x))) {
    names(x) <- character()
  }
  ledgr_strategy_type_check_names(x, "x", universe = universe, full_universe = FALSE)
  if (any(!is.finite(x))) {
    rlang::abort("`x` must contain finite numeric weights.", class = "ledgr_invalid_strategy_type")
  }
  structure(
    as.numeric(x) |> stats::setNames(names(x)),
    class = c("ledgr_weights", "numeric"),
    origin = ledgr_strategy_type_origin(origin),
    universe = if (length(x) == 0L) universe else NULL
  )
}

#' Create a strategy target vector
#'
#' `ledgr_target()` creates a thin wrapper around the full named numeric target
#' quantity vector consumed by ledgr's existing strategy-result validator.
#'
#' @param x Full named numeric target-quantity vector.
#' @param universe Optional universe. When supplied, names must exactly match it.
#' @param origin Optional helper/source label for printing.
#' @return A `ledgr_target` object.
#' @examples
#' ledgr_target(c(AAA = 1, BBB = 0), universe = c("AAA", "BBB"))
#'
#' @section Articles:
#' Strategy helper pipelines:
#' `vignette("strategy-development", package = "ledgr")`
#' `system.file("doc", "strategy-development.html", package = "ledgr")`
#' @export
ledgr_target <- function(x, universe = NULL, origin = NULL) {
  if (!is.numeric(x) || length(x) < 1L) {
    rlang::abort("`x` must be a non-empty named numeric vector.", class = "ledgr_invalid_strategy_type")
  }
  ledgr_strategy_type_check_names(x, "x", universe = universe, full_universe = !is.null(universe))
  if (any(!is.finite(x))) {
    rlang::abort("`x` must contain finite numeric target quantities.", class = "ledgr_invalid_strategy_type")
  }
  structure(
    as.numeric(x) |> stats::setNames(names(x)),
    class = c("ledgr_target", "numeric"),
    origin = ledgr_strategy_type_origin(origin)
  )
}

#' @export
print.ledgr_signal <- function(x, ...) {
  ledgr_print_strategy_vector(x, "ledgr_signal", ...)
}

#' @export
print.ledgr_selection <- function(x, ...) {
  ledgr_print_strategy_vector(x, "ledgr_selection", ...)
}

#' @export
print.ledgr_weights <- function(x, ...) {
  ledgr_print_strategy_vector(x, "ledgr_weights", ...)
}

#' @export
print.ledgr_target <- function(x, ...) {
  ledgr_print_strategy_vector(x, "ledgr_target", ...)
}
