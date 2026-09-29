ledgr_strategy_type_check_universe <- function(universe) {
  if (is.null(universe)) {
    return(NULL)
  }
  if (!is.character(universe) ||
      anyNA(universe) ||
      any(!nzchar(universe)) ||
      anyDuplicated(universe)) {
    rlang::abort(
      "`universe` must be NULL or a unique character vector of non-empty IDs.",
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

# The eligibility plane over the decision axis: `ctx$vec$admissible` when the
# context carries it; otherwise every ID of a dense context, or the current
# members of an availability context, is eligible.
ledgr_strategy_eligible <- function(ctx, axis) {
  admissible <- ctx$vec$admissible
  if (!is.null(admissible) && length(admissible) == length(axis)) {
    return(as.logical(admissible))
  }
  if (isTRUE(ctx$availability_active)) {
    return(axis %in% as.character(ctx$members %||% character()))
  }
  rep(TRUE, length(axis))
}

ledgr_strategy_context_abort <- function(message,
                                         class = "ledgr_invalid_strategy_helper") {
  rlang::abort(message, class = class)
}

ledgr_strategy_context_parts <- function(ctx, helper) {
  if (!inherits(ctx, "ledgr_pulse_context") ||
      (!is.list(ctx) && !is.environment(ctx))) {
    ledgr_strategy_context_abort(
      sprintf("`ctx` must be a ledgr pulse context for `%s()`.", helper)
    )
  }
  axis <- ctx$universe
  allow_empty <- isTRUE(ctx$availability_active)
  if (!is.character(axis) || (!allow_empty && length(axis) < 1L) || anyNA(axis) ||
      any(!nzchar(axis)) || anyDuplicated(axis)) {
    ledgr_strategy_context_abort(
      sprintf("`ctx$universe` is invalid for `%s()`.", helper)
    )
  }
  vec <- ctx$vec
  if (!is.list(vec) || !identical(as.character(vec$id), axis)) {
    ledgr_strategy_context_abort(
      sprintf("`ctx$vec$id` must match `ctx$universe` for `%s()`.", helper)
    )
  }
  members <- if (isTRUE(ctx$availability_active)) {
    as.character(ctx$members %||% character())
  } else {
    axis
  }
  expected_members <- axis[axis %in% members]
  if (anyNA(members) || any(!nzchar(members)) || anyDuplicated(members) ||
      !identical(members, expected_members)) {
    ledgr_strategy_context_abort(
      sprintf("`ctx$members` is invalid for `%s()`.", helper)
    )
  }
  list(axis = axis, members = members)
}

ledgr_strategy_context_dots <- function(dots, helper, allowed, required = FALSE) {
  dot_names <- names(dots)
  if (length(dots) > 0L &&
      (is.null(dot_names) || anyNA(dot_names) || any(!nzchar(dot_names)))) {
    ledgr_strategy_context_abort(
      sprintf("Context payloads for `%s()` must be named.", helper)
    )
  }
  if (anyDuplicated(dot_names)) {
    ledgr_strategy_context_abort(
      sprintf("Context payloads for `%s()` must not be duplicated.", helper)
    )
  }
  unknown <- setdiff(dot_names, c("values", "ids", "where"))
  if (length(unknown) > 0L) {
    ledgr_strategy_context_abort(
      sprintf("Unknown context payload for `%s()`: %s.", helper,
              paste(unknown, collapse = ", "))
    )
  }
  invalid <- setdiff(dot_names, allowed)
  if (length(invalid) > 0L) {
    ledgr_strategy_context_abort(
      sprintf("`%s` is not a valid payload for `%s()`.", invalid[[1L]], helper)
    )
  }
  if (length(dots) > 1L) {
    ledgr_strategy_context_abort(
      sprintf("`%s()` accepts exactly one context payload.", helper)
    )
  }
  if (isTRUE(required) && length(dots) == 0L) {
    ledgr_strategy_context_abort(
      sprintf("`%s()` requires the named `values` payload in context mode.", helper)
    )
  }
  if (length(dots) == 1L && is.null(dots[[1L]])) {
    ledgr_strategy_context_abort(
      sprintf("`%s` must not be NULL in context mode.", dot_names[[1L]])
    )
  }
  dots
}

# `required` is a logical mask over `members`: named payloads must cover the
# required IDs, and only their missing decisions are refused. By default every
# member is required.
ledgr_strategy_context_align <- function(payload,
                                         argument,
                                         expected_type,
                                         axis,
                                         members,
                                         missing_decisions = c("error", "exclude"),
                                         required = NULL) {
  missing_decisions <- match.arg(missing_decisions)
  valid_type <- switch(
    expected_type,
    numeric = is.numeric(payload),
    logical = is.logical(payload),
    FALSE
  )
  if (!valid_type || is.factor(payload) || is.object(payload) ||
      is.list(payload) || !is.null(dim(payload))) {
    ledgr_strategy_context_abort(
      sprintf("`%s` must be a plain %s vector.", argument, expected_type),
      class = "ledgr_invalid_strategy_type"
    )
  }
  payload_names <- names(payload)
  if (is.null(payload_names)) {
    if (length(payload) != length(axis)) {
      ledgr_strategy_context_abort(
        sprintf("Unnamed `%s` has size %d; expected decision-axis size %d.",
                argument, length(payload), length(axis)),
        class = "ledgr_invalid_strategy_type"
      )
    }
    aligned <- stats::setNames(payload, axis)
  } else {
    if (length(payload_names) != length(payload) || anyNA(payload_names) ||
        any(!nzchar(payload_names)) || anyDuplicated(payload_names)) {
      ledgr_strategy_context_abort(
        sprintf("`%s` must have unique, non-empty instrument names.", argument),
        class = "ledgr_invalid_strategy_type"
      )
    }
    unknown <- setdiff(payload_names, axis)
    if (length(unknown) > 0L) {
      ledgr_strategy_context_abort(
        sprintf("`%s` names unknown instrument IDs: %s.", argument,
                paste(unknown, collapse = ", ")),
        class = "ledgr_invalid_strategy_type"
      )
    }
    missing_members <- setdiff(if (is.null(required)) members else members[required], payload_names)
    if (length(missing_members) > 0L) {
      ledgr_strategy_context_abort(
        sprintf("`%s` is missing current member IDs: %s.", argument,
                paste(missing_members, collapse = ", ")),
        class = "ledgr_invalid_strategy_type"
      )
    }
    aligned <- payload
  }
  if (identical(expected_type, "numeric") && any(is.infinite(payload))) {
    bad <- if (is.null(payload_names)) axis[is.infinite(payload)] else payload_names[is.infinite(payload)]
    ledgr_strategy_context_abort(
      sprintf("`%s` contains infinite scores for: %s.", argument,
              paste(bad, collapse = ", ")),
      class = "ledgr_invalid_strategy_type"
    )
  }
  projected <- aligned[match(members, names(aligned))]
  names(projected) <- members
  refused <- if (is.null(required)) is.na(projected) else is.na(projected) & required
  if (identical(expected_type, "logical") && any(refused)) {
    if (identical(missing_decisions, "exclude")) {
      projected[is.na(projected)] <- FALSE
    } else {
      ledgr_strategy_context_abort(
        sprintf(
          paste0(
            "`%s` contains missing decisions for current members: %s. ",
            "Use `missing = \"exclude\"` to treat them as not selected; ",
            "a rebalance then targets those instruments to zero."
          ),
          argument,
          paste(members[refused], collapse = ", ")
        ),
        class = "ledgr_invalid_strategy_type"
      )
    }
  }
  projected
}

ledgr_strategy_context_ids <- function(ids, axis, members) {
  if (!is.character(ids) || is.factor(ids) || is.object(ids) ||
      is.list(ids) || !is.null(dim(ids)) || anyNA(ids) ||
      any(!nzchar(ids)) || anyDuplicated(ids)) {
    ledgr_strategy_context_abort(
      "`ids` must be a unique character vector of non-empty instrument IDs.",
      class = "ledgr_invalid_strategy_type"
    )
  }
  unknown <- setdiff(ids, axis)
  if (length(unknown) > 0L) {
    ledgr_strategy_context_abort(
      sprintf("`ids` names unknown instrument IDs: %s.",
              paste(unknown, collapse = ", ")),
      class = "ledgr_invalid_strategy_type"
    )
  }
  nonmembers <- setdiff(ids, members)
  if (length(nonmembers) > 0L) {
    ledgr_strategy_context_abort(
      sprintf("`ids` names known nonmembers: %s.",
              paste(nonmembers, collapse = ", "))
    )
  }
  stats::setNames(members %in% ids, members)
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
#' directly. A zero-length named signal represents an empty decision domain.
#'
#' In context mode, `ledgr_signal(ctx, values = ...)` returns one value per
#' instrument in `ctx$universe` and carries `ctx$vec$admissible` as its
#' `eligible` attribute. Unnamed `values` align by position and must have one
#' value per instrument; named `values` may come in any order and must cover
#' every eligible instrument, and uncovered instruments are `NA`.
#'
#' @param x Named numeric vector of signal scores, or a pulse context.
#' @param universe Optional universe used to reject extra instrument names.
#' @param origin Optional helper/source label for printing.
#' @param ... In context mode, exactly one named `values` payload.
#' @return A `ledgr_signal` object.
#' @examples
#' ledgr_signal(c(AAA = 0.03, BBB = NA_real_), origin = "return_5")
#'
#' @section Articles:
#' Strategy helper pipelines:
#' `vignette("strategy-development", package = "ledgr")`
#' `system.file("doc", "strategy-development.html", package = "ledgr")`
#' @export
ledgr_signal <- function(x, universe = NULL, origin = NULL, ...) {
  dots <- list(...)
  if (inherits(x, "ledgr_pulse_context")) {
    if (!missing(universe)) {
      ledgr_strategy_context_abort(
        "`universe` must not be supplied in context mode."
      )
    }
    parts <- ledgr_strategy_context_parts(x, "ledgr_signal")
    dots <- ledgr_strategy_context_dots(
      dots, "ledgr_signal", allowed = "values", required = TRUE
    )
    eligible <- ledgr_strategy_eligible(x, parts$axis)
    values <- ledgr_strategy_context_align(
      dots$values, "values", "numeric", parts$axis, parts$axis,
      required = eligible
    )
    signal <- ledgr_signal(values, origin = origin)
    attr(signal, "eligible") <- eligible
    return(signal)
  }
  if ((is.list(x) || is.environment(x)) && !inherits(x, "ledgr_signal")) {
    ledgr_strategy_context_abort(
      "`x` resembles a strategy context but is not a valid ledgr pulse context."
    )
  }
  if (length(dots) > 0L) {
    ledgr_strategy_context_abort(
      "Context payload arguments are not valid in value mode."
    )
  }
  if (!is.numeric(x)) {
    rlang::abort("`x` must be a named numeric vector.", class = "ledgr_invalid_strategy_type")
  }
  if (length(x) == 0L && is.null(names(x))) names(x) <- character()
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
#' In context mode, the selection covers the whole decision axis and is `FALSE`
#' for every ineligible instrument, whatever the payload: no payload selects
#' every eligible instrument, `where` decides eligible instruments only, and
#' `ids` naming an ineligible instrument leave it unselected.
#'
#' @param x Named logical vector where `TRUE` means selected, or a pulse context.
#' @param universe Optional universe used to reject extra instrument names.
#' @param origin Optional helper/source label for printing.
#' @param ... In context mode, at most one named `ids` or `where` payload.
#' @param missing In context mode, whether missing decisions for eligible
#'   instruments fail (`"error"`, the default) or count as not selected
#'   (`"exclude"`). A subsequent rebalance targets excluded held members to zero; use
#'   `ctx$hold()` when the intended action is to preserve positions. This is a
#'   decision policy, unlike `ctx$idx(id, missing = "na")`, which controls a
#'   missing instrument lookup.
#' @return A `ledgr_selection` object.
#' @examples
#' ledgr_selection(c(AAA = TRUE, BBB = FALSE), universe = c("AAA", "BBB"))
#' ctx <- structure(
#'   list(
#'     universe = c("AAA", "BBB"),
#'     vec = list(id = c("AAA", "BBB")),
#'     availability_active = FALSE
#'   ),
#'   class = "ledgr_pulse_context"
#' )
#' ledgr_selection(ctx, where = c(TRUE, NA), missing = "exclude")
#'
#' @section Articles:
#' Strategy helper pipelines:
#' `vignette("strategy-development", package = "ledgr")`
#' `system.file("doc", "strategy-development.html", package = "ledgr")`
#' @export
ledgr_selection <- function(x,
                            universe = NULL,
                            origin = NULL,
                            ...,
                            missing = c("error", "exclude")) {
  missing_supplied <- !missing(missing)
  dots <- list(...)
  if (inherits(x, "ledgr_pulse_context")) {
    if (!missing(universe)) {
      ledgr_strategy_context_abort(
        "`universe` must not be supplied in context mode."
      )
    }
    parts <- ledgr_strategy_context_parts(x, "ledgr_selection")
    missing <- tryCatch(
      match.arg(missing),
      error = function(err) {
        ledgr_strategy_context_abort(
          "`missing` must be one of \"error\" or \"exclude\".",
          class = "ledgr_invalid_strategy_helper"
        )
      }
    )
    dots <- ledgr_strategy_context_dots(
      dots, "ledgr_selection", allowed = c("ids", "where")
    )
    axis <- parts$axis
    eligible <- ledgr_strategy_eligible(x, axis)
    values <- if (length(dots) == 0L) {
      stats::setNames(eligible, axis)
    } else if (identical(names(dots), "ids")) {
      in_ids <- ledgr_strategy_context_ids(dots$ids, axis, axis)
      if (all(eligible)) in_ids else in_ids & eligible
    } else {
      all_eligible <- all(eligible)
      decided <- ledgr_strategy_context_align(
        dots$where,
        "where",
        "logical",
        axis,
        axis,
        missing_decisions = missing,
        required = if (all_eligible) NULL else eligible
      )
      if (all_eligible) decided else decided & eligible
    }
    return(ledgr_selection(values, origin = origin))
  }
  if ((is.list(x) || is.environment(x)) && !inherits(x, "ledgr_selection")) {
    ledgr_strategy_context_abort(
      "`x` resembles a strategy context but is not a valid ledgr pulse context."
    )
  }
  if (isTRUE(missing_supplied)) {
    ledgr_strategy_context_abort(
      "`missing` is available only when `x` is a ledgr pulse context."
    )
  }
  if (length(dots) > 0L) {
    ledgr_strategy_context_abort(
      "Context payload arguments are not valid in value mode."
    )
  }
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
#' quantity vector consumed by ledgr's existing strategy-result validator. A
#' zero-length target is valid when no non-empty universe is supplied; a
#' supplied non-empty universe still requires one target per instrument.
#'
#' @param x Full named numeric target-quantity vector.
#' @param universe Optional universe. When supplied, names must exactly match it.
#' @param origin Optional helper/source label for printing.
#' @return A `ledgr_target` object.
#' @examples
#' target <- ledgr_target(c(AAA = 1, BBB = 0), universe = c("AAA", "BBB"))
#' target[["AAA"]]
#' c(target)
#'
#' @section Articles:
#' Strategy helper pipelines:
#' `vignette("strategy-development", package = "ledgr")`
#' `system.file("doc", "strategy-development.html", package = "ledgr")`
#' @export
ledgr_target <- function(x, universe = NULL, origin = NULL) {
  if (!is.numeric(x)) {
    rlang::abort("`x` must be a named numeric vector.", class = "ledgr_invalid_strategy_type")
  }
  if (length(x) == 0L && is.null(names(x))) names(x) <- character()
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
