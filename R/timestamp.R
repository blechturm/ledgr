#' Normalize timestamps to ISO 8601 UTC
#'
#' Normalizes Date, POSIXct, or ISO 8601 strings into canonical UTC strings
#' with trailing `Z`. Supported inputs are:
#' - `Date` (interpreted as midnight UTC)
#' - `POSIXct`/`POSIXt`
#' - `"YYYY-MM-DD"`
#' - `"YYYY-MM-DDTHH:MM:SS"`
#' - `"YYYY-MM-DDTHH:MM:SSZ"`
#'
#' @param x A timestamp to normalize.
#' @return A length-1 character string in ISO 8601 UTC format.
#' @export
iso_utc <- function(x) {
  validate_hms <- function(ts_chr) {
    h <- as.integer(substr(ts_chr, 12, 13))
    m <- as.integer(substr(ts_chr, 15, 16))
    s <- as.integer(substr(ts_chr, 18, 19))
    if (anyNA(c(h, m, s)) || h < 0L || h > 23L || m < 0L || m > 59L || s < 0L || s > 59L) {
      rlang::abort("Unsupported timestamp format in `x`.", class = "ledgr_invalid_timestamp")
    }
    invisible(TRUE)
  }

  if (inherits(x, "POSIXt")) {
    ts <- as.POSIXct(x, tz = "UTC")
    if (length(ts) != 1 || is.na(ts)) {
      rlang::abort("`x` must be a scalar POSIXct convertible to UTC.", class = "ledgr_invalid_timestamp")
    }
    return(format(ts, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
  }

  if (inherits(x, "Date")) {
    if (length(x) != 1 || is.na(x)) {
      rlang::abort("`x` must be a scalar Date.", class = "ledgr_invalid_timestamp")
    }
    return(sprintf("%sT00:00:00Z", format(x, "%Y-%m-%d")))
  }

  if (!is.character(x) || length(x) != 1 || is.na(x) || !nzchar(x)) {
    rlang::abort(
      "`x` must be a non-empty ISO 8601 string, Date, or POSIXct.",
      class = "ledgr_invalid_timestamp"
    )
  }

  if (grepl("^\\d{4}-\\d{2}-\\d{2}$", x)) {
    d <- as.Date(x, format = "%Y-%m-%d")
    if (is.na(d)) {
      rlang::abort("Unsupported timestamp format in `x`.", class = "ledgr_invalid_timestamp")
    }
    return(sprintf("%sT00:00:00Z", format(d, "%Y-%m-%d")))
  }

  if (grepl("^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}Z$", x)) {
    validate_hms(x)
    ts <- as.POSIXct(x, tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ")
    if (is.na(ts)) {
      rlang::abort("Unsupported timestamp format in `x`.", class = "ledgr_invalid_timestamp")
    }
    return(format(ts, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
  }

  if (grepl("^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}$", x)) {
    validate_hms(paste0(x, "Z"))
    ts <- as.POSIXct(x, tz = "UTC", format = "%Y-%m-%dT%H:%M:%S")
    if (is.na(ts)) {
      rlang::abort("Unsupported timestamp format in `x`.", class = "ledgr_invalid_timestamp")
    }
    return(format(ts, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
  }

  rlang::abort("Unsupported timestamp format in `x`.", class = "ledgr_invalid_timestamp")
}
