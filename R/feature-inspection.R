#' Inspect feature contracts
#'
#' `ledgr_feature_contracts()` shows what ledgr will compute before a run. It
#' accepts the same feature declarations used by experiments: a feature map, a
#' named or unnamed list of indicators, or one indicator.
#'
#' @param features A `ledgr_feature_map`, a list of `ledgr_indicator` objects,
#'   or one `ledgr_indicator`.
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
ledgr_feature_contracts <- function(features) {
  normalized <- ledgr_feature_contract_input(features)
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
#'
#' @param snapshot A sealed `ledgr_snapshot`.
#' @param features A `ledgr_feature_map`, a list of `ledgr_indicator` objects,
#'   or one `ledgr_indicator`.
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
ledgr_feature_contract_check <- function(snapshot, features) {
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

  contracts <- ledgr_feature_contracts(features)
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
  out <- out[order(out$instrument_id, out$feature_id), , drop = FALSE]
  rownames(out) <- NULL
  out
}

ledgr_feature_contract_check_validate_snapshot <- function(snapshot) {
  if (!inherits(snapshot, "ledgr_snapshot")) {
    rlang::abort("`snapshot` must be a ledgr_snapshot.", class = "ledgr_invalid_args")
  }
  con <- get_connection(snapshot)
  if (!DBI::dbIsValid(con)) {
    rlang::abort("`snapshot` must have a valid database connection.", class = "ledgr_invalid_snapshot")
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

ledgr_feature_contract_input <- function(features) {
  if (inherits(features, "ledgr_feature_map")) {
    ledgr_validate_feature_map_object(features)
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

  if (!is.list(features)) {
    rlang::abort(
      "`features` must be a ledgr_feature_map, ledgr_indicator, or list of ledgr_indicator objects.",
      class = "ledgr_invalid_args"
    )
  }

  bad <- which(!vapply(features, inherits, logical(1), what = "ledgr_indicator"))
  if (length(bad) > 0L) {
    rlang::abort(
      "`features` must contain ledgr_indicator objects.",
      class = "ledgr_invalid_args"
    )
  }

  aliases <- names(features)
  if (is.null(aliases)) {
    aliases <- rep(NA_character_, length(features))
  } else {
    aliases <- as.character(aliases)
    aliases[is.na(aliases) | !nzchar(aliases)] <- NA_character_
  }

  list(
    indicators = unname(features),
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
#' pulse. With a feature map, the result is filtered and ordered to the map and
#' includes aliases. Without a map, all rows are returned with `alias = NA`.
#'
#' @param pulse A `ledgr_pulse_context`.
#' @param feature_map Optional `ledgr_feature_map`. Filters and orders feature
#'   columns; does not rename them to aliases.
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
  table <- ledgr_pulse_feature_table(pulse)

  if (is.null(feature_map)) {
    out <- ledgr_pulse_feature_rows(table)
    out <- out[order(out$instrument_id, out$feature_id), , drop = FALSE]
    rownames(out) <- NULL
    out$alias <- NA_character_
    return(out)
  }

  ledgr_validate_feature_map_object(feature_map)
  ledgr_pulse_feature_rows_for_map(table, pulse$universe, feature_map)
}

ledgr_validate_feature_inspection_pulse <- function(pulse) {
  if (!inherits(pulse, "ledgr_pulse_context")) {
    rlang::abort("`pulse` must be a ledgr_pulse_context.", class = "ledgr_invalid_args")
  }
  invisible(TRUE)
}

ledgr_pulse_feature_table <- function(pulse) {
  table <- pulse$feature_table
  if (is.null(table)) {
    table <- data.frame()
  }
  if (!is.data.frame(table)) {
    rlang::abort("Pulse feature table must be a data frame.", class = "ledgr_invalid_pulse_context")
  }
  table
}

ledgr_pulse_feature_rows <- function(table) {
  if (nrow(table) == 0L) {
    return(tibble::tibble(
      ts_utc = as.POSIXct(character(), tz = "UTC"),
      instrument_id = character(),
      feature_id = character(),
      feature_value = numeric()
    ))
  }

  required <- c("ts_utc", "instrument_id", "feature_name", "feature_value")
  missing <- setdiff(required, names(table))
  if (length(missing) > 0L) {
    rlang::abort(
      sprintf("Pulse feature table is missing required columns: %s.", paste(missing, collapse = ", ")),
      class = "ledgr_invalid_pulse_context"
    )
  }

  tibble::tibble(
    ts_utc = ledgr_utc(table$ts_utc),
    instrument_id = as.character(table$instrument_id),
    feature_id = as.character(table$feature_name),
    feature_value = as.numeric(table$feature_value)
  )
}

ledgr_pulse_feature_rows_for_map <- function(table, universe, feature_map) {
  rows <- ledgr_pulse_feature_rows(table)
  if (nrow(rows) == 0L) {
    rlang::abort(
      "Feature map requests unavailable feature IDs. Available feature IDs: <none>.",
      class = "ledgr_unknown_feature_id"
    )
  }

  rows <- rows[order(rows$instrument_id, rows$feature_id), , drop = FALSE]
  rownames(rows) <- NULL
  mapped_feature_ids <- ledgr_feature_id(feature_map)
  aliases <- names(mapped_feature_ids)
  feature_ids <- unname(mapped_feature_ids)
  missing <- setdiff(feature_ids, unique(rows$feature_id))
  if (length(missing) > 0L) {
    rlang::abort(
      sprintf(
        "Feature map requests unavailable feature ID `%s`. Available feature IDs: %s.",
        missing[[1L]],
        ledgr_feature_names_message(unique(rows$feature_id))
      ),
      class = "ledgr_unknown_feature_id"
    )
  }
  universe <- as.character(universe)
  if (length(universe) == 0L) {
    rlang::abort(
      "Pulse context universe must not be empty.",
      class = "ledgr_invalid_pulse_context"
    )
  }

  out <- vector("list", length(universe) * length(feature_ids))
  idx <- 0L
  for (instrument_id in universe) {
    for (i in seq_along(feature_ids)) {
      row_idx <- which(rows$instrument_id == instrument_id & rows$feature_id == feature_ids[[i]])
      if (length(row_idx) == 0L) {
        next
      }
      row <- rows[row_idx[[length(row_idx)]], , drop = FALSE]
      row$alias <- aliases[[i]]
      idx <- idx + 1L
      out[[idx]] <- row
    }
  }

  if (idx == 0L) {
    rows <- rows[0, , drop = FALSE]
    rows$alias <- character()
    return(rows)
  }

  out <- do.call(rbind, out[seq_len(idx)])
  rownames(out) <- NULL
  out
}

#' Inspect a pulse as one wide row
#'
#' `ledgr_pulse_wide()` returns one row for a pulse. It includes pulse metadata,
#' portfolio state, per-instrument OHLCV columns, and per-instrument feature
#' columns. OHLCV columns use `{instrument_id}__ohlcv_{field}`. Feature columns
#' use `{instrument_id}__feature_{feature_id}`. The delimiter `__` is reserved
#' for this naming contract and must not appear in instrument IDs or feature IDs
#' used in the wide output. A feature map filters and orders feature columns but
#' does not rename them to aliases.
#'
#' @param pulse A `ledgr_pulse_context`.
#' @param feature_map Optional `ledgr_feature_map`. Filters and orders feature
#'   columns; does not rename them to aliases.
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
  instruments <- sort(as.character(pulse$universe))

  out <- tibble::tibble(
    ts_utc = if (!is.null(pulse$ts_utc)) ledgr_utc(pulse$ts_utc) else as.POSIXct(NA_real_, origin = "1970-01-01", tz = "UTC"),
    cash = as.numeric(pulse$cash),
    equity = as.numeric(pulse$equity)
  )

  ledgr_validate_pulse_wide_names(instruments = instruments, feature_ids = rows$feature_id)
  for (instrument_id in instruments) {
    out <- ledgr_pulse_wide_add_ohlcv(out, pulse, instrument_id)

    if (nrow(rows) > 0L) {
      instrument_rows <- rows[rows$instrument_id == instrument_id, , drop = FALSE]
      if (nrow(instrument_rows) > 0L) {
        for (i in seq_len(nrow(instrument_rows))) {
          col <- paste0(instrument_id, "__feature_", instrument_rows$feature_id[[i]])
          out[[col]] <- instrument_rows$feature_value[[i]]
        }
      }
    }
  }

  out
}

ledgr_pulse_wide_add_ohlcv <- function(out, pulse, instrument_id) {
  fields <- c("open", "high", "low", "close", "volume")
  for (field in fields) {
    accessor <- pulse[[field]]
    if (!is.function(accessor)) {
      rlang::abort(
        sprintf("Pulse context is missing bar accessor `%s`.", field),
        class = "ledgr_invalid_pulse_context"
      )
    }
    col <- paste0(instrument_id, "__ohlcv_", field)
    out[[col]] <- accessor(instrument_id)
  }
  out
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
      sprintf("Feature ID `%s` contains reserved wide-column delimiter `__`.", bad_feature[[1L]]),
      class = c("ledgr_invalid_pulse_wide_names", "ledgr_invalid_args")
    )
  }

  invisible(TRUE)
}
