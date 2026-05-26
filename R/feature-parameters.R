#' Declare a feature parameter reference
#'
#' `ledgr_param()` creates a serializable placeholder used in parameterized
#' feature declarations. It is resolved with concrete feature parameter values
#' before precompute, run, or sweep execution.
#'
#' First-pass support is limited to scalar tuning arguments in
#' `ledgr_ind_sma()`, `ledgr_ind_ema()`, `ledgr_ind_rsi()`,
#' `ledgr_ind_returns()`, `ledgr_ind_ttr()`, and
#' `ledgr_ind_ttr_outputs()`. Custom `ledgr_indicator()` construction remains
#' concrete-only.
#'
#' @param name Non-empty parameter name.
#' @return A `ledgr_param_ref` object.
#' @examples
#' ledgr_param("fast_n")
#' @export
ledgr_param <- function(name) {
  if (!is.character(name) || length(name) != 1L || is.na(name) || !nzchar(name)) {
    rlang::abort("`name` must be a non-empty character scalar.", class = c("ledgr_invalid_param_reference", "ledgr_invalid_args"))
  }
  structure(list(name = unname(name)), class = "ledgr_param_ref")
}

#' @export
print.ledgr_param_ref <- function(x, ...) {
  cat("ledgr_param\n")
  cat("===========\n")
  cat("Name: ", x$name, "\n", sep = "")
  invisible(x)
}

ledgr_is_param_ref <- function(x) {
  inherits(x, "ledgr_param_ref")
}

ledgr_param_name <- function(x) {
  if (!ledgr_is_param_ref(x) || !is.character(x$name) || length(x$name) != 1L || is.na(x$name) || !nzchar(x$name)) {
    rlang::abort("Invalid ledgr parameter reference.", class = c("ledgr_invalid_param_reference", "ledgr_invalid_args"))
  }
  unname(x$name)
}

ledgr_contains_param_ref <- function(x) {
  if (ledgr_is_param_ref(x)) return(TRUE)
  if (is.list(x)) {
    return(any(vapply(x, ledgr_contains_param_ref, logical(1))))
  }
  FALSE
}

ledgr_abort_unsupported_param_placement <- function(argument, context) {
  rlang::abort(
    sprintf(
      "`ledgr_param()` is not supported in `%s` for %s. Use it only in documented scalar tuning arguments.",
      argument,
      context
    ),
    class = c("ledgr_unsupported_param_placement", "ledgr_invalid_args")
  )
}

ledgr_assert_no_param_refs <- function(values, context) {
  for (nm in names(values)) {
    if (ledgr_contains_param_ref(values[[nm]])) {
      ledgr_abort_unsupported_param_placement(nm, context)
    }
  }
  invisible(TRUE)
}

ledgr_validate_direct_param_args <- function(args, supported, context) {
  nms <- names(args)
  if (is.null(nms)) nms <- rep("", length(args))
  for (i in seq_along(args)) {
    arg_name <- nms[[i]]
    if (!nzchar(arg_name)) arg_name <- as.character(i)
    value <- args[[i]]
    if (!ledgr_contains_param_ref(value)) next
    if (!arg_name %in% supported) {
      ledgr_abort_unsupported_param_placement(arg_name, context)
    }
    if (!ledgr_is_param_ref(value)) {
      rlang::abort(
        sprintf(
          "`ledgr_param()` must be supplied directly as scalar argument `%s` for %s; nested parameter references are not supported.",
          arg_name,
          context
        ),
        class = c("ledgr_unsupported_param_placement", "ledgr_invalid_args")
      )
    }
  }
  invisible(TRUE)
}

ledgr_param_rows_from_args <- function(args, alias = NA_character_, constructor = NA_character_) {
  nms <- names(args)
  if (is.null(nms)) nms <- rep("", length(args))
  rows <- list()
  for (i in seq_along(args)) {
    arg_name <- nms[[i]]
    if (!nzchar(arg_name)) arg_name <- as.character(i)
    value <- args[[i]]
    if (ledgr_is_param_ref(value)) {
      rows[[length(rows) + 1L]] <- data.frame(
        param_name = ledgr_param_name(value),
        alias = alias,
        argument = arg_name,
        constructor = constructor,
        stringsAsFactors = FALSE
      )
    }
  }
  rows
}

ledgr_feature_param_value <- function(params, name) {
  if (!is.list(params)) {
    rlang::abort("`feature_params` must be a list.", class = c("ledgr_invalid_feature_params", "ledgr_invalid_args"))
  }
  if (is.null(names(params)) || !name %in% names(params)) {
    rlang::abort(
      sprintf("Missing feature parameter `%s`; add it to `feature_params` before resolving parameterized features.", name),
      class = c("ledgr_param_missing", "ledgr_invalid_feature_params", "ledgr_invalid_args")
    )
  }
  value <- params[[name]]
  if (is.null(value) || is.list(value) || length(value) != 1L) {
    rlang::abort(
      sprintf("Feature parameter `%s` must be a scalar value.", name),
      class = c("ledgr_param_non_scalar", "ledgr_invalid_feature_params", "ledgr_invalid_args")
    )
  }
  value
}

ledgr_validate_feature_params_for_declarations <- function(features, feature_params = list()) {
  rows <- ledgr_parameters(features)
  if (nrow(rows) == 0L) {
    return(invisible(TRUE))
  }
  if (!is.list(feature_params) || is.data.frame(feature_params)) {
    rlang::abort("`feature_params` must be a list.", class = c("ledgr_invalid_feature_params", "ledgr_invalid_args"))
  }
  param_names <- names(feature_params)
  if (is.null(param_names)) {
    param_names <- character(length(feature_params))
  }
  for (i in seq_len(nrow(rows))) {
    name <- rows$param_name[[i]]
    alias <- rows$alias[[i]]
    argument <- rows$argument[[i]]
    if (!name %in% param_names) {
      rlang::abort(
        sprintf(
          "Missing feature parameter `%s` required by alias `%s` argument `%s`; add it to `feature_params`.",
          name,
          alias,
          argument
        ),
        class = c("ledgr_param_missing", "ledgr_invalid_feature_params", "ledgr_invalid_args")
      )
    }
    value <- feature_params[[name]]
    if (is.null(value) || is.list(value) || length(value) != 1L) {
      rlang::abort(
        sprintf(
          "Feature parameter `%s` for alias `%s` argument `%s` must be a scalar value.",
          name,
          alias,
          argument
        ),
        class = c("ledgr_param_non_scalar", "ledgr_invalid_feature_params", "ledgr_invalid_args")
      )
    }
  }
  invisible(TRUE)
}

ledgr_resolve_param_args <- function(args, feature_params) {
  lapply(args, function(value) {
    if (ledgr_is_param_ref(value)) {
      return(ledgr_feature_param_value(feature_params, ledgr_param_name(value)))
    }
    value
  })
}

ledgr_new_parameterized_indicator <- function(constructor, args, supported_args) {
  ledgr_validate_direct_param_args(args, supported_args, constructor)
  structure(
    list(
      constructor = constructor,
      args = args,
      supported_args = supported_args
    ),
    class = c("ledgr_parameterized_indicator", "ledgr_unresolved_feature_declaration")
  )
}

ledgr_new_parameterized_bundle <- function(constructor, args, supported_args, output_aliases) {
  ledgr_validate_direct_param_args(args, supported_args, constructor)
  if (!is.character(output_aliases) || length(output_aliases) < 1L || anyNA(output_aliases) || any(!nzchar(output_aliases))) {
    rlang::abort("Parameterized bundles must declare non-empty flat output aliases.", class = c("ledgr_invalid_parameterized_bundle", "ledgr_invalid_args"))
  }
  structure(
    list(
      constructor = constructor,
      args = args,
      supported_args = supported_args,
      output_aliases = unname(output_aliases)
    ),
    class = c("ledgr_parameterized_indicator_bundle", "ledgr_unresolved_feature_declaration")
  )
}

ledgr_new_parameterized_bundle_output <- function(bundle, output_alias) {
  if (!inherits(bundle, "ledgr_parameterized_indicator_bundle")) {
    rlang::abort("`bundle` must be a parameterized indicator bundle.", class = "ledgr_invalid_args")
  }
  structure(
    list(bundle = bundle, output_alias = output_alias),
    class = c("ledgr_parameterized_bundle_output", "ledgr_unresolved_feature_declaration")
  )
}

ledgr_feature_declaration_is_unresolved <- function(x) {
  inherits(x, "ledgr_unresolved_feature_declaration")
}

ledgr_abort_unresolved_feature_id <- function() {
  rlang::abort(
    "`ledgr_feature_id()` requires concrete features. Resolve parameterized declarations with concrete `feature_params` first.",
    class = c("ledgr_unresolved_feature_id", "ledgr_invalid_args")
  )
}

ledgr_resolve_feature_declaration <- function(x, feature_params) {
  if (inherits(x, "ledgr_indicator")) return(x)
  if (inherits(x, "ledgr_indicator_bundle")) return(x)
  if (inherits(x, "ledgr_parameterized_indicator")) {
    args <- ledgr_resolve_param_args(x$args, feature_params)
    out <- do.call(ledgr_param_constructor(x$constructor), args)
    if (!inherits(out, "ledgr_indicator")) {
      rlang::abort("Parameterized indicator resolution did not produce a concrete indicator.", class = "ledgr_invalid_feature_resolution")
    }
    return(out)
  }
  if (inherits(x, "ledgr_parameterized_indicator_bundle")) {
    return(ledgr_resolve_parameterized_bundle(x, feature_params))
  }
  if (inherits(x, "ledgr_parameterized_bundle_output")) {
    indicators <- ledgr_resolve_parameterized_bundle_outputs(x$bundle, feature_params)
    out <- indicators[[x$output_alias]]
    if (is.null(out)) {
      rlang::abort(
        sprintf("Resolved bundle did not contain output alias `%s`.", x$output_alias),
        class = c("ledgr_ambiguous_bundle_output", "ledgr_invalid_feature_resolution")
      )
    }
    return(out)
  }
  rlang::abort("Unsupported feature declaration.", class = "ledgr_invalid_feature_resolution")
}

ledgr_resolve_parameterized_bundle <- function(x, feature_params) {
  indicators <- ledgr_resolve_parameterized_bundle_outputs(x, feature_params)
  ledgr_new_indicator_bundle(
    unname(indicators),
    metadata = list(parameterized = TRUE, constructor = x$constructor)
  )
}

ledgr_resolve_parameterized_bundle_outputs <- function(x, feature_params) {
  args <- ledgr_resolve_param_args(x$args, feature_params)
  bundle <- do.call(ledgr_param_constructor(x$constructor), args)
  if (!inherits(bundle, "ledgr_indicator_bundle")) {
    rlang::abort("Parameterized bundle resolution did not produce a concrete indicator bundle.", class = "ledgr_invalid_feature_resolution")
  }
  indicators <- ledgr_indicator_bundle_indicators(bundle)
  aliases <- ledgr_feature_id(indicators)
  suffix <- paste0("p", substr(digest::digest(canonical_json(args), algo = "sha256"), 1L, 8L))
  for (i in seq_along(indicators)) {
    indicators[[i]]$id <- paste(aliases[[i]], suffix, sep = "_")
  }
  stats::setNames(indicators, aliases)
}

ledgr_param_constructor_registry <- function() {
  list(
    ledgr_ind_sma = ledgr_ind_sma,
    ledgr_ind_ema = ledgr_ind_ema,
    ledgr_ind_rsi = ledgr_ind_rsi,
    ledgr_ind_returns = ledgr_ind_returns,
    ledgr_ind_ttr = ledgr_ind_ttr,
    ledgr_ind_ttr_outputs = ledgr_ind_ttr_outputs
  )
}

ledgr_param_constructor <- function(name) {
  registry <- ledgr_param_constructor_registry()
  if (!is.character(name) || length(name) != 1L || is.na(name) || !name %in% names(registry)) {
    rlang::abort(
      sprintf("Unknown parameterized constructor `%s`.", as.character(name)[[1L]] %||% "<missing>"),
      class = c("ledgr_invalid_param_constructor", "ledgr_invalid_feature_resolution")
    )
  }
  registry[[name]]
}

#' Inspect parameter references in feature declarations
#'
#' @param features A feature map, parameterized declaration, indicator, bundle,
#'   or list of feature declarations.
#' @return A tibble with at least `param_name`, `alias`, and `argument`.
#' @export
ledgr_parameters <- function(features) {
  rows <- ledgr_parameter_rows(features)
  if (length(rows) == 0L) {
    return(tibble::tibble(
      param_name = character(),
      alias = character(),
      argument = character(),
      constructor = character()
    ))
  }
  tibble::as_tibble(do.call(rbind, rows))
}

ledgr_parameter_rows <- function(features, alias = NA_character_) {
  if (inherits(features, "ledgr_feature_map")) {
    ledgr_validate_feature_map_object(features)
    out <- list()
    for (entry_alias in features$aliases) {
      out <- c(out, ledgr_parameter_rows(features$indicators[[entry_alias]], alias = entry_alias))
    }
    return(out)
  }
  if (inherits(features, "ledgr_parameterized_indicator")) {
    return(ledgr_param_rows_from_args(features$args, alias = alias, constructor = features$constructor))
  }
  if (inherits(features, "ledgr_parameterized_indicator_bundle")) {
    return(ledgr_param_rows_from_args(features$args, alias = alias, constructor = features$constructor))
  }
  if (inherits(features, "ledgr_parameterized_bundle_output")) {
    return(ledgr_param_rows_from_args(features$bundle$args, alias = alias, constructor = features$bundle$constructor))
  }
  if (inherits(features, "ledgr_indicator") || inherits(features, "ledgr_indicator_bundle")) {
    return(list())
  }
  if (is.list(features)) {
    out <- list()
    nms <- names(features)
    if (is.null(nms)) nms <- rep(NA_character_, length(features))
    for (i in seq_along(features)) {
      out <- c(out, ledgr_parameter_rows(features[[i]], alias = nms[[i]]))
    }
    return(out)
  }
  list()
}
