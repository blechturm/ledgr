#' Construct a ledgr indicator
#'
#' @param id Unique indicator identifier.
#' @param fn Scalar indicator function evaluated on one bounded window of bars
#'   ending at the current bar, returning a numeric value or a list. Two forms
#'   are accepted: `function(window)`, and `function(window, params)`. When the
#'   function declares a second argument, ledgr also passes the indicator's
#'   `params`.
#' @param requires_bars Minimum lookback period (integer).
#' @param params Named list of deterministic parameters for fingerprinting.
#' @param stable_after Number of bars after which the indicator output is stable.
#' @param series_fn Optional vectorized indicator function:
#'   function(bars, params) -> numeric vector aligned to `bars`.
#' @param source Indicator source label. Built-in ledgr indicators use
#'   `"ledgr"`, TTR-backed indicators use `"TTR"`, and user/adapted indicators
#'   use `"custom"`.
#' @param gap_contract Optional gap declaration. `"strict_window"` declares a
#'   bounded window and is equivalent to `history_class = "bounded"`; it
#'   contradicts `history_class = "history_dependent"`.
#' @param history_class Optional history class: `"bounded"` or
#'   `"history_dependent"`. `NULL` with no `gap_contract` is disclosed as
#'   `"history_dependent"`: ledgr never infers that a definition is bounded.
#' @param required_fields Optional character vector of the bar fields the
#'   calculation requires, from `"open"`, `"high"`, `"low"`, `"close"` and
#'   `"volume"`. `NULL` requires the four price fields.
#' @param tolerance Optional comparison tolerance for a bounded definition that
#'   supplies both `fn` and `series_fn`. `NULL` (the default) means exact. A
#'   nonzero tolerance is a scaled bound, `abs(a - b) / max(1, abs(b))`, and
#'   enters the definition's availability-aware identity.
#' @param input_carry Optional input-carry declaration. `"excluded"` marks a
#'   return or volatility indicator: it never consumes a price carried by the
#'   experiment's history policy, so a gap leaves its inputs missing. `NULL`
#'   (disclosed as the default) and `"eligible"` consume the policy-treated
#'   input. Package built-ins and registered TTR forms take this from the
#'   package catalogue.
#'
#' @details Indicator fingerprints bind deterministic direct captures of `fn`
#'   and `series_fn`. Atomic values and deterministic lists are supported;
#'   environments, connections, and other unsupported captures refuse as
#'   non-deterministic. A captured function contributes its function identity,
#'   but its own captures are not recursively included. Put explicitly varying
#'   research inputs in `params`.
#'
#'   On availability-aware experiments the history declarations decide how
#'   the indicator is calculated. A bounded definition depends only on its
#'   last `requires_bars` expected sessions: `fn` receives exactly that window
#'   and an incomplete window is missing. A history-dependent definition is
#'   calculated once per contiguous segment of available input and restarts
#'   after a gap. `stable_after` is the first-valid boundary after each start
#'   or restart; it does not promise convergence. The declarations enter the
#'   availability-aware feature identity; dense execution ignores them.
#'
#'   Availability-aware preparation also checks every definition for
#'   look-ahead before any run, sweep candidate or precompute payload uses
#'   it: on the instrument with the most calculated values, at no more than
#'   four fixed sessions, the value recomputed from the history ending there
#'   must equal the prepared value, or preparation refuses with
#'   `ledgr_feature_lookahead_detected`. A custom bounded definition that
#'   supplies both `fn` and `series_fn` must also agree, at the same
#'   sessions, between `fn` on its window and `series_fn` within `tolerance`,
#'   or preparation refuses with `ledgr_indicator_gap_parity`. Both checks
#'   are samples, not proofs of causality.
#'
#' @return A `ledgr_indicator` object.
#' @examples
#' last_close <- ledgr_indicator(
#'   id = "last_close",
#'   fn = function(window) tail(window$close, 1),
#'   requires_bars = 1
#' )
#' last_close$id
#'
#' mean_close <- ledgr_indicator(
#'   id = "mean_close_3",
#'   fn = function(window, params) mean(tail(window$close, params$n)),
#'   requires_bars = 3,
#'   params = list(n = 3)
#' )
#' mean_close$id
#' @export
ledgr_indicator <- function(id,
                            fn,
                            requires_bars,
                            params = list(),
                            stable_after = requires_bars,
                            series_fn = NULL,
                            source = "custom",
                            gap_contract = NULL,
                            history_class = NULL,
                            required_fields = NULL,
                            tolerance = NULL,
                            input_carry = NULL) {
  ledgr_assert_no_param_refs(
    list(
      id = id, requires_bars = requires_bars, params = params,
      stable_after = stable_after, history_class = history_class,
      required_fields = required_fields, tolerance = tolerance,
      input_carry = input_carry
    ),
    "ledgr_indicator()"
  )
  if (!is.character(id) || length(id) != 1 || !nzchar(id)) {
    rlang::abort("`id` must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }
  if (!is.function(fn)) {
    rlang::abort("`fn` must be a function.", class = "ledgr_invalid_args")
  }
  if (!is.numeric(requires_bars) || length(requires_bars) != 1 || is.na(requires_bars)) {
    rlang::abort("`requires_bars` must be a non-missing numeric scalar.", class = "ledgr_invalid_args")
  }
  if (requires_bars < 1 || requires_bars %% 1 != 0) {
    rlang::abort("`requires_bars` must be an integer >= 1.", class = "ledgr_invalid_args")
  }
  if (!is.numeric(stable_after) || length(stable_after) != 1 || is.na(stable_after)) {
    rlang::abort("`stable_after` must be a non-missing numeric scalar.", class = "ledgr_invalid_args")
  }
  if (stable_after < requires_bars || stable_after %% 1 != 0) {
    rlang::abort("`stable_after` must be an integer >= requires_bars.", class = "ledgr_invalid_args")
  }
  if (!is.list(params)) {
    rlang::abort("`params` must be a named list.", class = "ledgr_invalid_args")
  }
  if (length(params) > 0 && (is.null(names(params)) || any(!nzchar(names(params))))) {
    rlang::abort("`params` must be a named list with non-empty names.", class = "ledgr_invalid_args")
  }
  if (!ledgr_are_params_deterministic(params)) {
    rlang::abort(
      "`params` must contain only deterministic, stable values. Use strings for timestamps.",
      class = "ledgr_invalid_args"
    )
  }
  if (!is.character(source) || length(source) != 1L || is.na(source) || !(source %in% c("ledgr", "TTR", "custom"))) {
    rlang::abort("`source` must be one of 'ledgr', 'TTR', or 'custom'.", class = "ledgr_invalid_args")
  }
  declarations <- ledgr_indicator_declare(
    history_class = history_class,
    gap_contract = gap_contract,
    required_fields = required_fields,
    tolerance = tolerance,
    input_carry = input_carry,
    has_series_fn = !is.null(series_fn),
    id = id
  )
  ledgr_assert_indicator_fn_pure(fn)
  ledgr_assert_indicator_safe(fn)
  if (!is.null(series_fn)) {
    if (!is.function(series_fn)) {
      rlang::abort("`series_fn` must be NULL or a function.", class = "ledgr_invalid_args")
    }
    ledgr_assert_indicator_fn_pure(series_fn)
    ledgr_assert_indicator_safe(series_fn)
  }

  indicator <- structure(
    list(
      id = id,
      fn = fn,
      series_fn = series_fn,
      requires_bars = as.integer(requires_bars),
      stable_after = as.integer(stable_after),
      params = params,
      source = source,
      gap_contract = NULL
    ),
    class = "ledgr_indicator"
  )
  ledgr_indicator_apply_declarations(indicator, declarations)
}

#' Get feature IDs from ledgr indicators
#'
#' Returns the exact feature ID strings that strategies should pass to
#' `ctx$feature(instrument_id, name)`. This helper reads the existing indicator
#' IDs; it does not generate aliases or change the ID scheme.
#'
#' @param x A `ledgr_indicator` object, a `ledgr_indicator_bundle`, a list of
#'   `ledgr_indicator`/`ledgr_indicator_bundle` objects, or a
#'   `ledgr_feature_map`.
#'
#' @return A character vector. List input returns a plain unnamed character
#'   vector in list order. Feature-map input returns IDs named by alias.
#' @examples
#' sma_20 <- ledgr_ind_sma(20)
#' ledgr_feature_id(sma_20)
#'
#' features <- list(ledgr_ind_sma(20), ledgr_ind_returns(5))
#' ledgr_feature_id(features)
#'
#' mapped <- ledgr_feature_map(
#'   trend = ledgr_ind_sma(20),
#'   momentum = ledgr_ind_returns(5)
#' )
#' ledgr_feature_id(mapped)
#'
#' @section Articles:
#' Indicators, feature IDs, and warmup:
#' `vignette("indicators", package = "ledgr")`
#' `system.file("doc", "indicators.html", package = "ledgr")`
#' @export
ledgr_feature_id <- function(x) {
  if (ledgr_feature_declaration_is_unresolved(x)) {
    ledgr_abort_unresolved_feature_id()
  }
  if (inherits(x, "ledgr_indicator")) {
    return(unname(as.character(x$id)))
  }
  if (inherits(x, "ledgr_indicator_bundle")) {
    return(ledgr_feature_id(ledgr_indicator_bundle_indicators(x)))
  }
  if (inherits(x, "ledgr_feature_map")) {
    ledgr_validate_feature_map_object(x)
    if (any(vapply(x$indicators, ledgr_feature_declaration_is_unresolved, logical(1)))) {
      ledgr_abort_unresolved_feature_id()
    }
    return(x$feature_ids)
  }
  if (is.list(x)) {
    if (any(vapply(x, ledgr_feature_declaration_is_unresolved, logical(1)))) {
      ledgr_abort_unresolved_feature_id()
    }
    flattened <- ledgr_flatten_feature_list(x, context = "`x`")
    ids <- vapply(flattened, function(ind) as.character(ind$id), character(1))
    return(unname(ids))
  }
  rlang::abort(
    "`x` must be a ledgr_indicator, ledgr_indicator_bundle, ledgr_feature_map, or list of those feature declarations.",
    class = "ledgr_invalid_args"
  )
}

#' Print a ledgr indicator
#'
#' @param x A `ledgr_indicator` object.
#' @param ... Unused.
#'
#' @return Invisibly returns `x`.
#' @examples
#' ledgr_ind_sma(20)
#' @export
print.ledgr_indicator <- function(x, ...) {
  cat("ledgr indicator\n")
  cat("  ID:            ", x$id, "\n", sep = "")
  cat("  Requires bars: ", x$requires_bars, "\n", sep = "")
  cat("  Stable after:  ", x$stable_after, "\n", sep = "")
  cat("  Series fn:     ", if (is.null(x$series_fn)) "no" else "yes", "\n", sep = "")
  declarations <- ledgr_feature_def_declarations(x)
  source_label <- switch(
    declarations$history_source,
    catalogue = "package catalogue",
    declared = "declared",
    default = "default for an undeclared definition"
  )
  cat("  History class: ", declarations$history_class, " (", source_label, ")\n", sep = "")
  cat("  Required:      ", paste(declarations$required_fields, collapse = ", "), "\n", sep = "")
  carry_label <- if (identical(declarations$input_carry, "excluded")) {
    "excluded (return or volatility family)"
  } else {
    "eligible"
  }
  carry_source <- switch(
    declarations$input_carry_source,
    catalogue = "package catalogue",
    declared = "declared",
    default = "default for an undeclared definition"
  )
  cat("  Input carry:   ", carry_label, " (", carry_source, ")\n", sep = "")
  if (declarations$tolerance > 0) {
    cat("  Tolerance:     ", format(declarations$tolerance), "\n", sep = "")
  }
  invisible(x)
}

ledgr_indicator_fingerprint <- function(indicator) {
  if (!inherits(indicator, "ledgr_indicator")) {
    rlang::abort("`indicator` must be a ledgr_indicator object.", class = "ledgr_invalid_args")
  }
  payload <- list(
    id = indicator$id,
    fn = ledgr_function_fingerprint(
      indicator$fn,
      include_captures = TRUE,
      label = sprintf("indicator `%s`", indicator$id),
      capture_overrides = ledgr_indicator_capture_overrides(indicator, "fn")
    ),
    series_fn = if (is.null(indicator$series_fn)) {
      NULL
    } else {
      ledgr_function_fingerprint(
        indicator$series_fn,
        include_captures = TRUE,
        label = sprintf("indicator `%s` series_fn", indicator$id),
        capture_overrides = ledgr_indicator_capture_overrides(indicator, "series_fn")
      )
    },
    requires_bars = indicator$requires_bars,
    stable_after = indicator$stable_after,
    params = ledgr_stable_payload(indicator$params, sprintf("indicator `%s` params", indicator$id))
  )
  digest::digest(canonical_json(payload), algo = "sha256")
}

ledgr_indicator_capture_overrides <- function(indicator, member) {
  route <- attr(indicator, "ledgr_constructor_capture_identity", exact = TRUE)
  if (is.null(route)) return(list())
  if (!identical(
    route,
    list(type = "csv_data_hash_v1", fn_capture = "values")
  )) {
    rlang::abort("Invalid constructor-owned indicator capture identity.", class = "ledgr_internal_error")
  }
  if (!identical(member, "fn")) return(list())
  data_hash <- indicator$params$data_hash
  if (!is.character(data_hash) || length(data_hash) != 1L || is.na(data_hash) || !nzchar(data_hash)) {
    rlang::abort("CSV indicator capture identity requires params$data_hash.", class = "ledgr_internal_error")
  }
  list(values = list(type = "params_data_hash", data_hash = data_hash))
}

.ledgr_indicator_registry <- new.env(parent = emptyenv())

#' Register an indicator in the global registry
#'
#' @param indicator A `ledgr_indicator` object.
#' @param name Optional registry name (defaults to indicator id).
#' @param overwrite Replace an existing registration with the same name.
#'
#' @return The indicator, invisibly.
#' @examples
#' local({
#'   registry <- get(".ledgr_indicator_registry", asNamespace("ledgr"))
#'   if (exists("example_last_close", envir = registry, inherits = FALSE)) {
#'     rm(list = "example_last_close", envir = registry)
#'   }
#'   on.exit(if (exists("example_last_close", envir = registry, inherits = FALSE)) {
#'     rm(list = "example_last_close", envir = registry)
#'   }, add = TRUE)
#'   ind <- ledgr_indicator(
#'     id = "example_last_close",
#'     fn = function(window) tail(window$close, 1),
#'     requires_bars = 1
#'   )
#'   ledgr_indicator_register(ind)
#' })
#' @export
ledgr_indicator_register <- function(indicator, name = NULL, overwrite = FALSE) {
  if (!inherits(indicator, "ledgr_indicator")) {
    rlang::abort("`indicator` must be a ledgr_indicator object.", class = "ledgr_invalid_args")
  }
  if (is.null(name)) {
    name <- indicator$id
  }
  if (!is.character(name) || length(name) != 1 || !nzchar(name)) {
    rlang::abort("`name` must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }
  if (!is.logical(overwrite) || length(overwrite) != 1 || is.na(overwrite)) {
    rlang::abort("`overwrite` must be TRUE or FALSE.", class = "ledgr_invalid_args")
  }

  if (exists(name, envir = .ledgr_indicator_registry, inherits = FALSE) && !isTRUE(overwrite)) {
    existing <- get(name, envir = .ledgr_indicator_registry, inherits = FALSE)
    # History declarations are not part of the dense fingerprint, but they
    # change availability-aware calculation, so they decide sameness here too.
    same_logic <- function(x) {
      ledgr_active_feature_fingerprint(ledgr_precompute_feature_def_from_indicator(x))
    }
    if (identical(same_logic(existing), same_logic(indicator))) {
      return(invisible(indicator))
    }
    rlang::abort(
      sprintf(
        "Indicator '%s' is already registered with different logic. Existing registration is unchanged, so downstream lookups still use the previous definition. Use overwrite = TRUE only for an intentional same-ID replacement, or choose a distinct indicator id/name.",
        name
      ),
      class = "ledgr_invalid_args"
    )
  }

  assign(name, indicator, envir = .ledgr_indicator_registry)
  invisible(indicator)
}

#' Deregister an indicator from the session registry
#'
#' Removes an indicator registration from the current R session. This only
#' affects the in-memory registry used for interactive lookup and tests; it does
#' not alter any persisted snapshots, runs, or ledger artifacts.
#'
#' @param name Indicator registry name.
#' @param missing_ok If `TRUE`, missing names are ignored. If `FALSE`, missing
#'   names are an error.
#'
#' @return Invisibly returns `TRUE` when an indicator was removed and `FALSE`
#'   when the indicator was already absent and `missing_ok = TRUE`.
#' @examples
#' local({
#'   ind <- ledgr_indicator(
#'     id = "example_deregister",
#'     fn = function(window) tail(window$close, 1),
#'     requires_bars = 1
#'   )
#'   ledgr_indicator_register(ind)
#'   ledgr_indicator_remove("example_deregister")
#' })
#' @export
ledgr_indicator_remove <- function(name, missing_ok = TRUE) {
  if (!is.character(name) || length(name) != 1 || !nzchar(name)) {
    rlang::abort("`name` must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }
  if (!is.logical(missing_ok) || length(missing_ok) != 1 || is.na(missing_ok)) {
    rlang::abort("`missing_ok` must be TRUE or FALSE.", class = "ledgr_invalid_args")
  }

  if (!exists(name, envir = .ledgr_indicator_registry, inherits = FALSE)) {
    if (isTRUE(missing_ok)) {
      return(invisible(FALSE))
    }
    rlang::abort(
      sprintf("Indicator '%s' is not registered.", name),
      class = "ledgr_invalid_args"
    )
  }

  rm(list = name, envir = .ledgr_indicator_registry)
  invisible(TRUE)
}

#' Get an indicator by name
#'
#' @param name Indicator name.
#'
#' @return A `ledgr_indicator` object.
#' @examples
#' local({
#'   registry <- get(".ledgr_indicator_registry", asNamespace("ledgr"))
#'   if (exists("example_lookup", envir = registry, inherits = FALSE)) {
#'     rm(list = "example_lookup", envir = registry)
#'   }
#'   on.exit(if (exists("example_lookup", envir = registry, inherits = FALSE)) {
#'     rm(list = "example_lookup", envir = registry)
#'   }, add = TRUE)
#'   ind <- ledgr_indicator(
#'     id = "example_lookup",
#'     fn = function(window) tail(window$close, 1),
#'     requires_bars = 1
#'   )
#'   ledgr_indicator_register(ind)
#'   ledgr_indicator_get("example_lookup")$id
#' })
#' @export
ledgr_indicator_get <- function(name) {
  if (!is.character(name) || length(name) != 1 || !nzchar(name)) {
    rlang::abort("`name` must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }
  if (!exists(name, envir = .ledgr_indicator_registry, inherits = FALSE)) {
    available <- sort(
      ls(envir = .ledgr_indicator_registry),
      method = "radix"
    )
    if (length(available) == 0) {
      msg <- sprintf("Indicator '%s' not found in registry.", name)
    } else {
      msg <- paste0(
        sprintf("Indicator '%s' not found in registry.\n", name),
        "Available indicators: ", paste(available, collapse = ", "), "\n\n",
        "Register custom indicators with:\n  ledgr_indicator_register(my_indicator)"
      )
    }
    rlang::abort(msg, class = "ledgr_invalid_args")
  }

  get(name, envir = .ledgr_indicator_registry, inherits = FALSE)
}

#' List registered indicators
#'
#' @param pattern Optional regex filter for names.
#'
#' @return Character vector of indicator names.
#' @examples
#' local({
#'   registry <- get(".ledgr_indicator_registry", asNamespace("ledgr"))
#'   if (exists("example_list", envir = registry, inherits = FALSE)) {
#'     rm(list = "example_list", envir = registry)
#'   }
#'   on.exit(if (exists("example_list", envir = registry, inherits = FALSE)) {
#'     rm(list = "example_list", envir = registry)
#'   }, add = TRUE)
#'   ind <- ledgr_indicator(
#'     id = "example_list",
#'     fn = function(window) tail(window$close, 1),
#'     requires_bars = 1
#'   )
#'   ledgr_indicator_register(ind)
#'   ledgr_indicator_list("example")
#' })
#' @export
ledgr_indicator_list <- function(pattern = NULL) {
  if (!is.null(pattern) && (!is.character(pattern) || length(pattern) != 1 || !nzchar(pattern))) {
    rlang::abort("`pattern` must be NULL or a non-empty character scalar.", class = "ledgr_invalid_args")
  }
  names <- sort(ls(envir = .ledgr_indicator_registry), method = "radix")
  if (!is.null(pattern)) {
    names <- grep(pattern, names, value = TRUE)
  }
  names
}
