#' Print an indicator bundle
#'
#' @param x A `ledgr_indicator_bundle` object.
#' @param ... Unused.
#' @return The input object, invisibly.
#' @keywords internal
#' @export
print.ledgr_indicator_bundle <- function(x, ...) {
  ledgr_validate_indicator_bundle_object(x)
  indicators <- ledgr_indicator_bundle_indicators(x)
  ids <- vapply(indicators, function(ind) as.character(ind$id), character(1))
  cat("ledgr_indicator_bundle\n")
  cat("======================\n")
  cat("Features: ", length(indicators), "\n", sep = "")
  if (!is.null(x$metadata$source)) {
    cat("Source:   ", x$metadata$source, "\n", sep = "")
  }
  if (!is.null(x$metadata$family)) {
    cat("Family:   ", x$metadata$family, "\n", sep = "")
  }
  shown <- utils::head(ids, 6L)
  for (id in shown) {
    cat("  ", id, "\n", sep = "")
  }
  if (length(ids) > length(shown)) {
    cat("  ...\n")
  }
  invisible(x)
}

ledgr_new_indicator_bundle <- function(indicators, metadata = list()) {
  if (!is.list(indicators) || length(indicators) < 1L) {
    rlang::abort(
      "`indicators` must be a non-empty list of ledgr_indicator objects.",
      class = c("ledgr_invalid_indicator_bundle", "ledgr_invalid_args")
    )
  }
  bad <- which(!vapply(indicators, inherits, logical(1), what = "ledgr_indicator"))
  if (length(bad) > 0L) {
    rlang::abort(
      sprintf("Indicator bundle entry %s must be a ledgr_indicator object.", bad[[1L]]),
      class = c("ledgr_invalid_indicator_bundle", "ledgr_invalid_args")
    )
  }
  ids <- ledgr_feature_id(indicators)
  ledgr_abort_duplicate_feature_ids(ids)
  structure(
    list(
      indicators = unname(indicators),
      metadata = metadata
    ),
    class = "ledgr_indicator_bundle"
  )
}

ledgr_validate_indicator_bundle_object <- function(x) {
  if (!inherits(x, "ledgr_indicator_bundle")) {
    rlang::abort(
      "`x` must be a ledgr_indicator_bundle object.",
      class = c("ledgr_invalid_indicator_bundle", "ledgr_invalid_args")
    )
  }
  if (!is.list(x$metadata)) {
    rlang::abort(
      "`x$metadata` must be a list.",
      class = c("ledgr_invalid_indicator_bundle", "ledgr_invalid_args")
    )
  }
  indicators <- x$indicators
  if (!is.list(indicators) || length(indicators) < 1L) {
    rlang::abort(
      "`x$indicators` must be a non-empty list.",
      class = c("ledgr_invalid_indicator_bundle", "ledgr_invalid_args")
    )
  }
  bad <- which(!vapply(indicators, inherits, logical(1), what = "ledgr_indicator"))
  if (length(bad) > 0L) {
    rlang::abort(
      sprintf("Indicator bundle entry %s must be a ledgr_indicator object.", bad[[1L]]),
      class = c("ledgr_invalid_indicator_bundle", "ledgr_invalid_args")
    )
  }
  ids <- vapply(indicators, function(ind) as.character(ind$id), character(1))
  ledgr_abort_duplicate_feature_ids(ids)
  invisible(TRUE)
}

ledgr_indicator_bundle_indicators <- function(x) {
  ledgr_validate_indicator_bundle_object(x)
  unname(x$indicators)
}

ledgr_feature_declaration_error <- function(message, class) {
  rlang::abort(message, class = unique(c(class, "ledgr_invalid_args")))
}

ledgr_flatten_feature_list <- function(features,
                                       context = "`features`",
                                       class = "ledgr_invalid_args") {
  if (inherits(features, "ledgr_indicator")) {
    return(list(features))
  }
  if (inherits(features, "ledgr_indicator_bundle")) {
    return(ledgr_indicator_bundle_indicators(features))
  }
  if (!is.list(features)) {
    ledgr_feature_declaration_error(
      sprintf("%s must be a ledgr_indicator, ledgr_indicator_bundle, or list of those objects.", context),
      class
    )
  }

  original_names <- names(features)
  if (is.null(original_names)) {
    original_names <- rep("", length(features))
  }
  out <- list()
  out_names <- character()
  for (i in seq_along(features)) {
    item <- features[[i]]
    item_name <- original_names[[i]]
    if (is.na(item_name)) item_name <- ""

    if (inherits(item, "ledgr_indicator")) {
      out[[length(out) + 1L]] <- item
      out_names <- c(out_names, item_name)
      next
    }
    if (inherits(item, "ledgr_indicator_bundle")) {
      bundle_indicators <- ledgr_indicator_bundle_indicators(item)
      out <- c(out, bundle_indicators)
      out_names <- c(out_names, ledgr_feature_id(bundle_indicators))
      next
    }

    ledgr_feature_declaration_error(
      sprintf(
        "%s entries must be ledgr_indicator objects or ledgr_indicator_bundle objects; invalid index: %s.",
        context,
        i
      ),
      class
    )
  }

  if (length(out) == 0L) {
    return(list())
  }
  names(out) <- out_names
  unname_or_named <- out
  if (all(!nzchar(out_names))) {
    names(unname_or_named) <- NULL
  }
  ids <- vapply(out, function(ind) as.character(ind$id), character(1))
  ledgr_abort_duplicate_feature_ids(ids)
  unname_or_named
}
