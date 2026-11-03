#' Inspect feature contracts
#'
#' `ledgr_feature_contracts()` shows what ledgr will compute before a run. It
#' accepts the same feature declarations used by experiments: a feature map, a
#' named or unnamed list of indicators and indicator bundles, one indicator, or
#' one indicator bundle.
#'
#' Parameterized feature maps are resolved for inspection when concrete
#' `feature_params` are supplied. Without them, unresolved declarations fail
#' with `ledgr_feature_factory_requires_params`.
#'
#' @param features A `ledgr_feature_map`, a list of `ledgr_indicator` or
#'   `ledgr_indicator_bundle` objects, one `ledgr_indicator`, or one
#'   `ledgr_indicator_bundle`.
#' @param feature_params `NULL` or a JSON-safe list used to resolve a
#'   parameterized feature map before inspection.
#'
#' @return A tibble with columns `alias`, `feature_id`, `source`,
#'   `requires_bars`, and `stable_after`.
#' @examples
#' features <- ledgr_feature_map(
#'   ret_5 = ledgr_ind_returns(5),
#'   sma_10 = ledgr_ind_sma(10)
#' )
#'
#' ledgr_feature_contracts(features)
#'
#' @section Articles:
#' Indicators, feature IDs, and pulse feature views:
#'
#' `vignette("indicators", package = "ledgr")`
#' `system.file("doc", "indicators.html", package = "ledgr")`
#' @export
ledgr_feature_contracts <- function(features, feature_params = NULL) {
  features <- ledgr_feature_contract_resolve(features, feature_params)
  normalized <- ledgr_feature_contract_input(
    features,
    feature_map_validated = inherits(features, "ledgr_feature_map")
  )
  indicators <- normalized$indicators
  aliases <- normalized$aliases
  feature_ids <- vapply(indicators, function(ind) as.character(ind$id), character(1))

  tibble::tibble(
    alias = aliases,
    feature_id = unname(feature_ids),
    source = vapply(indicators, ledgr_indicator_source, character(1)),
    requires_bars = vapply(indicators, function(ind) as.integer(ind$requires_bars), integer(1)),
    stable_after = vapply(indicators, function(ind) as.integer(ind$stable_after), integer(1))
  )
}

#' Check feature warmup feasibility against a snapshot
#'
#' `ledgr_feature_contract_check()` joins declared feature contracts to the
#' actual per-instrument bar counts in a sealed snapshot. It is a pre-run
#' inspection helper: it tells you whether each feature can become usable for
#' each instrument in this snapshot. It does not compute feature values and does
#' not mutate the snapshot.
#'
#' Feature factories of the form `function(params)` are intentionally rejected
#' here because the helper cannot know which concrete parameter set to use.
#' Materialize the factory first, then pass the resulting indicators or feature
#' map. The error class is `ledgr_feature_factory_requires_params`.
#' Unresolved parameterized feature maps use the same class when
#' `feature_params` is omitted. Supplying concrete values resolves the same map
#' through the validator and resolver used by execution.
#'
#' @param snapshot A sealed `ledgr_snapshot`.
#' @param features A `ledgr_feature_map`, a list of `ledgr_indicator` or
#'   `ledgr_indicator_bundle` objects, one `ledgr_indicator`, or one
#'   `ledgr_indicator_bundle`.
#' @param feature_params `NULL` or a JSON-safe list used to resolve a
#'   parameterized feature map before inspection.
#'
#' @return A tibble with one row per `(instrument_id, feature_id)` pair. It
#'   includes `alias`, `instrument_id`, `feature_id`, `source`,
#'   `requires_bars`, `stable_after`, `available_bars`, and
#'   `warmup_achievable`. `warmup_achievable` is `TRUE` when the instrument has
#'   at least `stable_after` bars.
#' @examples
#' bars <- data.frame(
#'   ts_utc = ledgr_utc("2020-01-01") + 86400 * 0:4,
#'   instrument_id = "AAA",
#'   open = 100:104,
#'   high = 101:105,
#'   low = 99:103,
#'   close = 100:104,
#'   volume = 1000
#' )
#' snapshot <- ledgr_snapshot_from_df(bars)
#' features <- list(ledgr_ind_returns(3), ledgr_ind_sma(10))
#' ledgr_feature_contract_check(snapshot, features)
#' ledgr_snapshot_close(snapshot)
#'
#' @section Articles:
#' Indicators, feature IDs, and pulse feature views:
#'
#' `vignette("indicators", package = "ledgr")`
#' `system.file("doc", "indicators.html", package = "ledgr")`
#' @export
ledgr_feature_contract_check <- function(snapshot,
                                         features,
                                         feature_params = NULL) {
  release <- ledgr_snapshot_hold(snapshot)
  on.exit(release(), add = TRUE)
  ledgr_feature_contract_check_validate_snapshot(snapshot)
  if (is.function(features) && !inherits(features, "ledgr_indicator")) {
    rlang::abort(
      paste(
        "`features` must be materialized before feature-contract feasibility can be checked.",
        "Pass the concrete indicators or feature map returned by the feature factory for a specific params list."
      ),
      class = c("ledgr_feature_factory_requires_params", "ledgr_invalid_args")
    )
  }

  contracts <- ledgr_feature_contracts(
    features,
    feature_params = feature_params
  )
  ledgr_snapshot_ensure_handle(snapshot)
  counts <- ledgr_snapshot_bar_counts(snapshot)

  if (nrow(contracts) == 0L || nrow(counts) == 0L) {
    return(tibble::tibble(
      alias = character(),
      instrument_id = character(),
      feature_id = character(),
      source = character(),
      requires_bars = integer(),
      stable_after = integer(),
      available_bars = integer(),
      warmup_achievable = logical()
    ))
  }

  contract_idx <- rep(seq_len(nrow(contracts)), each = nrow(counts))
  count_idx <- rep(seq_len(nrow(counts)), times = nrow(contracts))
  out <- tibble::tibble(
    alias = contracts$alias[contract_idx],
    instrument_id = counts$instrument_id[count_idx],
    feature_id = contracts$feature_id[contract_idx],
    source = contracts$source[contract_idx],
    requires_bars = as.integer(contracts$requires_bars[contract_idx]),
    stable_after = as.integer(contracts$stable_after[contract_idx]),
    available_bars = as.integer(counts$available_bars[count_idx])
  )
  out$warmup_achievable <- out$available_bars >= out$stable_after
  out <- out[order(
    out$instrument_id,
    out$feature_id,
    method = "radix"
  ), , drop = FALSE]
  rownames(out) <- NULL
  out
}

ledgr_feature_contract_check_validate_snapshot <- function(snapshot) {
  if (!inherits(snapshot, "ledgr_snapshot")) {
    rlang::abort("`snapshot` must be a ledgr_snapshot.", class = "ledgr_invalid_args")
  }
  info <- ledgr_snapshot_info(snapshot)
  if (!identical(info$status[[1]], "SEALED")) {
    rlang::abort(
      sprintf("`snapshot` must be SEALED for feature-contract feasibility checks; current status is %s.", info$status[[1]]),
      class = c("ledgr_snapshot_not_sealed", "ledgr_invalid_snapshot")
    )
  }
  invisible(TRUE)
}

ledgr_snapshot_bar_counts <- function(snapshot) {
  release <- ledgr_snapshot_hold(snapshot)
  on.exit(release(), add = TRUE)
  con <- get_connection(snapshot)
  rows <- DBI::dbGetQuery(
    con,
    "
    SELECT
      i.instrument_id,
      COALESCE(COUNT(b.ts_utc), 0) AS available_bars
    FROM snapshot_instruments i
    LEFT JOIN snapshot_bars b
      ON i.snapshot_id = b.snapshot_id
     AND i.instrument_id = b.instrument_id
    WHERE i.snapshot_id = ?
    GROUP BY i.instrument_id
    ORDER BY i.instrument_id
    ",
    params = list(snapshot$snapshot_id)
  )
  tibble::tibble(
    instrument_id = as.character(rows$instrument_id),
    available_bars = as.integer(rows$available_bars)
  )
}

ledgr_feature_contract_resolve <- function(features, feature_params = NULL) {
  if (!is.null(feature_params) &&
      (!is.list(feature_params) || is.data.frame(feature_params))) {
    rlang::abort(
      "`feature_params` must be NULL or a list.",
      class = "ledgr_invalid_args"
    )
  }
  if (is.function(features) && !inherits(features, "ledgr_indicator")) {
    rlang::abort(
      paste(
        "`features` must be materialized before feature contracts can be inspected.",
        "Feature factories cannot be resolved by this helper."
      ),
      class = c("ledgr_feature_factory_requires_params", "ledgr_invalid_args")
    )
  }
  if (!inherits(features, "ledgr_feature_map")) return(features)

  ledgr_validate_feature_map_object(features)
  unresolved <- vapply(
    features$indicators,
    ledgr_feature_declaration_is_unresolved,
    logical(1)
  )
  if (any(unresolved) && is.null(feature_params)) {
    rlang::abort(
      paste(
        "`features` contains parameterized declarations.",
        "Supply concrete values through `feature_params` before inspection."
      ),
      class = c("ledgr_feature_factory_requires_params", "ledgr_invalid_args")
    )
  }
  if (is.null(feature_params)) return(features)

  ledgr_validate_feature_params_for_declarations(features, feature_params)
  ledgr_resolve_feature_map(features, feature_params = feature_params)
}

ledgr_feature_contract_input <- function(features,
                                         feature_map_validated = FALSE) {
  if (inherits(features, "ledgr_feature_map")) {
    if (!isTRUE(feature_map_validated)) {
      ledgr_validate_feature_map_object(features)
    }
    unresolved <- vapply(
      features$indicators,
      ledgr_feature_declaration_is_unresolved,
      logical(1)
    )
    if (any(unresolved)) {
      rlang::abort(
        paste(
          "`features` must be materialized before feature contracts can be inspected.",
          "Resolve parameterized declarations with concrete `feature_params`, then pass the resulting indicators or feature map."
        ),
        class = c("ledgr_feature_factory_requires_params", "ledgr_invalid_args")
      )
    }
    return(list(
      indicators = unname(features$indicators),
      aliases = unname(as.character(features$aliases))
    ))
  }

  if (inherits(features, "ledgr_indicator")) {
    return(list(
      indicators = list(features),
      aliases = NA_character_
    ))
  }
  if (inherits(features, "ledgr_indicator_bundle")) {
    indicators <- ledgr_indicator_bundle_indicators(features)
    return(list(
      indicators = indicators,
      aliases = rep(NA_character_, length(indicators))
    ))
  }

  flattened <- ledgr_flatten_feature_list(features, context = "`features`")

  aliases <- names(flattened)
  if (is.null(aliases)) {
    aliases <- rep(NA_character_, length(flattened))
  } else {
    aliases <- as.character(aliases)
    aliases[is.na(aliases) | !nzchar(aliases)] <- NA_character_
  }

  list(
    indicators = unname(flattened),
    aliases = aliases
  )
}

ledgr_indicator_source <- function(indicator) {
  source <- indicator$source
  if (is.character(source) && length(source) == 1L && !is.na(source) && source %in% c("ledgr", "TTR", "custom")) {
    return(source)
  }
  "custom"
}

#' Inspect pulse feature rows
#'
#' `ledgr_pulse_features()` returns the long feature rows available at one
#' pulse. With a feature map or active alias map, the result is filtered and
#' ordered to the map and includes aliases. Without a map, all rows are returned
#' with `alias = NA`.
#'
#' @param pulse A `ledgr_pulse_context`.
#' @param feature_map Optional `ledgr_feature_map` or named alias map. Filters
#'   and orders feature columns.
#'
#' @return A tibble with columns `ts_utc`, `instrument_id`, `feature_id`,
#'   `feature_value`, and `alias`.
#' @examples
#' \dontshow{
#' bars <- data.frame(
#'   ts_utc = ledgr_utc("2020-01-01") + 86400 * 0:2,
#'   instrument_id = "AAA",
#'   open = 100:102,
#'   high = 101:103,
#'   low = 99:101,
#'   close = 100:102,
#'   volume = 1000
#' )
#' snapshot <- ledgr_snapshot_from_df(bars)
#' features <- ledgr_feature_map(sma = ledgr_ind_sma(2))
#' pulse <- ledgr_pulse_snapshot(
#'   snapshot,
#'   universe = "AAA",
#'   ts_utc = ledgr_utc("2020-01-03"),
#'   features = features
#' )
#' }
#' ledgr_pulse_features(pulse, features)
#' \dontshow{
#' close(pulse)
#' ledgr_snapshot_close(snapshot)
#' }
#'
#' @section Articles:
#' Indicators, feature IDs, and pulse feature views:
#'
#' `vignette("indicators", package = "ledgr")`
#' `system.file("doc", "indicators.html", package = "ledgr")`
#' @export
ledgr_pulse_features <- function(pulse, feature_map = NULL) {
  ledgr_validate_feature_inspection_pulse(pulse)
  lookup <- unclass(pulse)[[".pulse_lookup"]]
  mapping <- ledgr_pulse_inspection_feature_map(lookup, feature_map)
  feature_ids <- unname(mapping$feature_map)
  instruments <- as.character(pulse$universe %||% character())
  n_instrument <- length(instruments)
  n_feature <- length(feature_ids)

  values <- if (n_instrument == 0L || n_feature == 0L) {
    matrix(numeric(), nrow = n_instrument, ncol = n_feature)
  } else {
    matrix(
      unlist(lapply(feature_ids, lookup$feature_vector), use.names = FALSE),
      nrow = n_instrument,
      ncol = n_feature
    )
  }
  alias <- if (isTRUE(mapping$mapped)) names(mapping$feature_map) else rep(NA_character_, n_feature)
  tibble::tibble(
    ts_utc = rep(ledgr_utc(pulse$ts_utc), n_instrument * n_feature),
    instrument_id = rep(instruments, each = n_feature),
    feature_id = rep(feature_ids, times = n_instrument),
    feature_value = as.numeric(t(values)),
    alias = rep(alias, times = n_instrument)
  )
}

ledgr_validate_feature_inspection_pulse <- function(pulse) {
  if (!inherits(pulse, "ledgr_pulse_context")) {
    rlang::abort("`pulse` must be a ledgr_pulse_context.", class = "ledgr_invalid_args")
  }
  invisible(TRUE)
}

ledgr_pulse_inspection_feature_map <- function(lookup, feature_map = NULL) {
  if (!is.environment(lookup) || !is.list(lookup$feature_lookup) ||
      !is.function(lookup$feature_vector)) {
    rlang::abort(
      "Pulse context feature inspection is not initialized.",
      class = "ledgr_invalid_pulse_context"
    )
  }
  prepared <- lookup$feature_lookup$name_lookup
  available <- as.character(prepared$feature_ids %||% character())
  if (!is.null(feature_map)) {
    return(list(
      feature_map = ledgr_explicit_feature_lookup(feature_map, prepared),
      mapped = TRUE
    ))
  }
  active <- prepared$alias_map
  if (!is.null(active)) {
    return(list(feature_map = active, mapped = TRUE))
  }
  available <- sort(available, method = "radix")
  list(feature_map = stats::setNames(available, available), mapped = FALSE)
}

#' Inspect a pulse as one wide row
#'
#' `ledgr_pulse_wide()` returns one row for a pulse. It includes pulse metadata,
#' portfolio state, per-instrument OHLCV columns, and per-instrument feature
#' columns. OHLCV columns use `{instrument_id}__ohlcv_{field}`. Feature columns
#' use `{instrument_id}__feature_{feature_id}`. The delimiter `__` is reserved
#' for this naming contract and must not appear in instrument IDs or feature IDs
#' used in the wide output. A feature map or active alias map filters and orders
#' feature columns and uses aliases as feature keys.
#'
#' @param pulse A `ledgr_pulse_context`.
#' @param feature_map Optional `ledgr_feature_map` or named alias map. Filters
#'   and orders feature columns.
#'
#' @return A one-row tibble with `ts_utc`, `cash`, `equity`, one OHLCV
#'   block per instrument, and feature columns for the requested pulse.
#' @examples
#' \dontshow{
#' bars <- data.frame(
#'   ts_utc = ledgr_utc("2020-01-01") + 86400 * 0:2,
#'   instrument_id = "AAA",
#'   open = 100:102,
#'   high = 101:103,
#'   low = 99:101,
#'   close = 100:102,
#'   volume = 1000
#' )
#' snapshot <- ledgr_snapshot_from_df(bars)
#' features <- ledgr_feature_map(sma = ledgr_ind_sma(2))
#' pulse <- ledgr_pulse_snapshot(
#'   snapshot,
#'   universe = "AAA",
#'   ts_utc = ledgr_utc("2020-01-03"),
#'   features = features
#' )
#' }
#' ledgr_pulse_wide(pulse, features)
#' \dontshow{
#' close(pulse)
#' ledgr_snapshot_close(snapshot)
#' }
#'
#' @section Articles:
#' Indicators, feature IDs, and pulse feature views:
#'
#' `vignette("indicators", package = "ledgr")`
#' `system.file("doc", "indicators.html", package = "ledgr")`
#' @export
ledgr_pulse_wide <- function(pulse, feature_map = NULL) {
  ledgr_validate_feature_inspection_pulse(pulse)
  rows <- ledgr_pulse_features(pulse, feature_map)
  instruments <- sort(as.character(pulse$universe), method = "radix")
  feature_keys <- unique(ifelse(is.na(rows$alias), rows$feature_id, rows$alias))
  ledgr_validate_pulse_wide_names(instruments = instruments, feature_ids = feature_keys)
  fields <- c("open", "high", "low", "close", "volume")
  bars <- matrix(unlist(lapply(fields, function(field) {
    value <- pulse[[field]]
    if (!is.numeric(value) || is.null(names(value))) {
      rlang::abort(
        sprintf("Pulse context is missing named bar column `%s`.", field),
        class = "ledgr_invalid_pulse_context"
      )
    }
    as.numeric(value[instruments])
  }), use.names = FALSE), nrow = length(instruments), ncol = length(fields))
  features <- if (length(instruments) == 0L || length(feature_keys) == 0L) {
    matrix(numeric(), nrow = length(instruments), ncol = length(feature_keys))
  } else {
    value_matrix <- matrix(
      rows$feature_value,
      nrow = length(pulse$universe),
      ncol = length(feature_keys),
      byrow = TRUE
    )
    value_matrix[match(instruments, pulse$universe), , drop = FALSE]
  }
  values <- cbind(bars, features)
  suffixes <- c(paste0("ohlcv_", fields), paste0("feature_", feature_keys))
  value_names <- as.vector(t(outer(instruments, suffixes, paste, sep = "__")))
  out <- c(
    list(
      ts_utc = if (!is.null(pulse$ts_utc)) ledgr_utc(pulse$ts_utc) else as.POSIXct(NA_real_, origin = "1970-01-01", tz = "UTC"),
      cash = as.numeric(pulse$cash),
      equity = as.numeric(pulse$equity)
    ),
    stats::setNames(as.list(as.numeric(t(values))), value_names)
  )
  tibble::as_tibble(out)
}

ledgr_validate_pulse_wide_names <- function(instruments, feature_ids = character()) {
  instruments <- as.character(instruments)
  feature_ids <- as.character(feature_ids)

  bad_instrument <- unique(instruments[grepl("__", instruments, fixed = TRUE)])
  if (length(bad_instrument) > 0L) {
    rlang::abort(
      sprintf("Instrument ID `%s` contains reserved wide-column delimiter `__`.", bad_instrument[[1L]]),
      class = c("ledgr_invalid_pulse_wide_names", "ledgr_invalid_args")
    )
  }

  bad_feature <- unique(feature_ids[grepl("__", feature_ids, fixed = TRUE)])
  if (length(bad_feature) > 0L) {
    rlang::abort(
      sprintf("Feature ID or alias `%s` contains reserved wide-column delimiter `__`.", bad_feature[[1L]]),
      class = c("ledgr_invalid_pulse_wide_names", "ledgr_invalid_args")
    )
  }

  invisible(TRUE)
}
