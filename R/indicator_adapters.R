#' Adapt an R package function into a ledgr indicator
#'
#' @param pkg_fn R function (or "pkg::fn" string) to adapt.
#' @param id Indicator identifier.
#' @param requires_bars Minimum lookback period.
#' @param ... Additional arguments passed to the package function.
#'
#' @return A `ledgr_indicator` object.
#' @examples
#' median_close <- ledgr_adapter_r(stats::median, id = "median_close", requires_bars = 3)
#' median_close$id
#' @export
ledgr_adapter_r <- function(pkg_fn, id, requires_bars, ...) {
  pkg_fn_label <- NULL
  if (is.character(pkg_fn)) {
    if (length(pkg_fn) != 1 || is.na(pkg_fn) || !nzchar(pkg_fn) || !grepl("::", pkg_fn, fixed = TRUE)) {
      rlang::abort("`pkg_fn` must be a function or \"pkg::fn\" string.", class = "ledgr_invalid_args")
    }
    parts <- strsplit(pkg_fn, "::", fixed = TRUE)[[1]]
    pkg_name <- parts[[1]]
    fn_name <- parts[[2]]
    pkg_fn_label <- pkg_fn
    if (!requireNamespace(pkg_name, quietly = TRUE)) {
      rlang::abort(
        sprintf("Package '%s' required for ledgr_adapter_r.", pkg_name),
        class = "ledgr_invalid_args"
      )
    }
    pkg_fn <- getExportedValue(pkg_name, fn_name)
  } else if (!is.function(pkg_fn)) {
    rlang::abort("`pkg_fn` must be a function or \"pkg::fn\" string.", class = "ledgr_invalid_args")
  } else {
    env_name <- environmentName(environment(pkg_fn))
    pkg_fn_label <- paste0(env_name, "::", ledgr_function_fingerprint(pkg_fn, include_captures = FALSE, label = "`pkg_fn`"))
    if (!is.null(env_name) && grepl("^namespace:", env_name)) {
      pkg_name <- sub("^namespace:", "", env_name)
      if (!requireNamespace(pkg_name, quietly = TRUE)) {
        rlang::abort(
          sprintf("Package '%s' required for ledgr_adapter_r.", pkg_name),
          class = "ledgr_invalid_args"
        )
      }
    }
  }

  args <- list(...)
  params <- c(
    list(
      adapter = "r",
      pkg_fn = pkg_fn_label,
      pkg_fn_hash = ledgr_function_fingerprint(pkg_fn, include_captures = FALSE, label = "`pkg_fn`")
    ),
    args
  )
  ledgr_indicator(
    id = id,
    fn = function(window) {
      result <- do.call(pkg_fn, c(list(window$close), args))
      utils::tail(result, 1)
    },
    requires_bars = as.integer(requires_bars),
    stable_after = as.integer(requires_bars),
    params = params
  )
}

#' Adapt a CSV of precomputed indicators
#'
#' @param csv_path Path to CSV file with indicator values.
#' @param value_col Column name containing indicator values.
#' @param date_col Column name containing timestamps (default "ts_utc").
#' @param instrument_col Column name containing instruments (default "instrument_id").
#' @param id Indicator identifier.
#'
#' @return A `ledgr_indicator` object.
#' @examples
#' csv_path <- tempfile(fileext = ".csv")
#' utils::write.csv(data.frame(
#'   ts_utc = c("2020-01-01T00:00:00Z", "2020-01-02T00:00:00Z"),
#'   instrument_id = "AAA",
#'   my_value = c(1.5, 2.5)
#' ), csv_path, row.names = FALSE)
#' ind <- ledgr_adapter_csv(csv_path, value_col = "my_value", id = "my_csv_value")
#' ind$id
#' @export
ledgr_adapter_csv <- function(csv_path,
                              value_col,
                              date_col = "ts_utc",
                              instrument_col = "instrument_id",
                              id) {
  if (!is.character(csv_path) || length(csv_path) != 1 || is.na(csv_path) || !nzchar(csv_path)) {
    rlang::abort("`csv_path` must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }
  if (!file.exists(csv_path)) {
    rlang::abort("`csv_path` does not exist.", class = "ledgr_invalid_args")
  }
  if (!is.character(value_col) || length(value_col) != 1 || is.na(value_col) || !nzchar(value_col)) {
    rlang::abort("`value_col` must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }
  if (!is.character(date_col) || length(date_col) != 1 || is.na(date_col) || !nzchar(date_col)) {
    rlang::abort("`date_col` must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }
  if (!is.character(instrument_col) || length(instrument_col) != 1 || is.na(instrument_col) || !nzchar(instrument_col)) {
    rlang::abort("`instrument_col` must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }

  indicator_data <- utils::read.csv(csv_path, stringsAsFactors = FALSE)
  required <- c(date_col, instrument_col, value_col)
  missing <- setdiff(required, names(indicator_data))
  if (length(missing) > 0) {
    rlang::abort(
      sprintf(
        "CSV missing required columns: %s",
        paste(missing, collapse = ", ")
      ),
      class = "ledgr_invalid_args"
    )
  }

  ts_norm <- vapply(indicator_data[[date_col]], iso_utc, character(1))
  instrument_ids <- as.character(indicator_data[[instrument_col]])
  if (anyNA(instrument_ids) || any(!nzchar(instrument_ids))) {
    rlang::abort("CSV instrument_id values must be non-empty strings.", class = "ledgr_invalid_args")
  }
  key <- paste(ts_norm, instrument_ids, sep = "||")
  if (anyDuplicated(key)) {
    rlang::abort("CSV contains duplicate (ts_utc, instrument_id) rows.", class = "ledgr_invalid_args")
  }

  values <- indicator_data[[value_col]]
  names(values) <- key
  data_hash <- digest::digest(indicator_data, algo = "sha256")
  na_value <- NA_real_

  ledgr_indicator(
    id = id,
    fn = function(window) {
      current_ts <- iso_utc(window$ts_utc[nrow(window)])
      current_inst <- as.character(window$instrument_id[nrow(window)])
      key <- paste(current_ts, current_inst, sep = "||")
      if (!key %in% names(values)) {
        warning(
          sprintf("No CSV value for ts_utc=%s instrument_id=%s.", current_ts, current_inst),
          call. = FALSE
        )
        return(na_value)
      }
      values[[key]]
    },
    requires_bars = 1L,
    stable_after = 1L,
    params = list(
      adapter = "csv",
      csv_path = csv_path,
      value_col = value_col,
      date_col = date_col,
      instrument_col = instrument_col,
      data_hash = data_hash
    )
  )
}
