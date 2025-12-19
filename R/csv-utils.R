ledgr_read_csv_strict <- function(path, encoding = "UTF-8", strict = TRUE) {
  if (!is.character(path) || length(path) != 1 || is.na(path) || !nzchar(path)) {
    rlang::abort("CSV path must be a non-empty character scalar.", class = "LEDGR_CSV_FORMAT_ERROR")
  }
  if (!file.exists(path)) {
    rlang::abort(sprintf("CSV file not found: %s", path), class = "LEDGR_CSV_FORMAT_ERROR")
  }
  if (!is.character(encoding) || length(encoding) != 1 || is.na(encoding) || !nzchar(encoding)) {
    rlang::abort("`encoding` must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }
  if (!is.logical(strict) || length(strict) != 1 || is.na(strict)) {
    rlang::abort("`strict` must be TRUE or FALSE.", class = "ledgr_invalid_args")
  }

  df <- tryCatch(
    utils::read.csv(
      path,
      header = TRUE,
      sep = ",",
      stringsAsFactors = FALSE,
      check.names = FALSE,
      fileEncoding = encoding
    ),
    error = function(e) {
      rlang::abort(
        sprintf("Failed to read CSV: %s", conditionMessage(e)),
        class = "LEDGR_CSV_FORMAT_ERROR"
      )
    }
  )

  if (!is.data.frame(df)) {
    rlang::abort("CSV did not parse into a data.frame.", class = "LEDGR_CSV_FORMAT_ERROR")
  }

  # UTF-8 BOM tolerated: strip from first column name if present.
  if (ncol(df) > 0) {
    names(df)[[1]] <- sub("^\ufeff", "", names(df)[[1]])
  }

  df
}

ledgr_csv_require_columns <- function(df, required, label = "CSV") {
  if (!is.data.frame(df)) {
    rlang::abort("Internal error: expected a data.frame.", class = "ledgr_internal_error")
  }
  required <- as.character(required)
  missing <- setdiff(required, names(df))
  if (length(missing) > 0) {
    rlang::abort(
      sprintf("%s is missing required columns: %s", label, paste(missing, collapse = ", ")),
      class = "LEDGR_CSV_FORMAT_ERROR"
    )
  }
  invisible(TRUE)
}

ledgr_csv_parse_ts_utc <- function(x, label) {
  if (!is.character(x)) x <- as.character(x)
  if (anyNA(x) || any(!nzchar(x))) {
    rlang::abort(sprintf("%s must be non-empty ISO8601 UTC strings.", label), class = "LEDGR_CSV_FORMAT_ERROR")
  }
  iso <- "^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}Z$"
  bad <- which(!grepl(iso, x))
  if (length(bad) > 0) {
    rlang::abort(sprintf("%s must be ISO8601 UTC with trailing Z (e.g. 2020-01-01T00:00:00Z).", label), class = "LEDGR_CSV_FORMAT_ERROR")
  }
  parsed <- as.POSIXct(x, tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ")
  if (anyNA(parsed)) {
    rlang::abort(sprintf("%s contains unparseable timestamps.", label), class = "LEDGR_CSV_FORMAT_ERROR")
  }
  parsed
}

ledgr_csv_parse_num <- function(x, label, required = TRUE, round_digits = NULL) {
  if (is.null(x)) {
    if (isTRUE(required)) rlang::abort(sprintf("Missing numeric field: %s", label), class = "LEDGR_CSV_FORMAT_ERROR")
    return(rep(NA_real_, 0))
  }
  out <- suppressWarnings(as.numeric(x))
  if (isTRUE(required)) {
    if (anyNA(out) || any(!is.finite(out))) {
      rlang::abort(sprintf("%s must be finite numeric values using decimal '.' only.", label), class = "LEDGR_CSV_FORMAT_ERROR")
    }
  } else {
    bad <- which(!is.na(out) & !is.finite(out))
    if (length(bad) > 0) {
      rlang::abort(sprintf("%s must be finite when provided.", label), class = "LEDGR_CSV_FORMAT_ERROR")
    }
  }

  if (!is.null(round_digits)) {
    out <- round(out, digits = as.integer(round_digits))
  }
  out
}

ledgr_snapshot_require_created <- function(con, snapshot_id) {
  if (!DBI::dbIsValid(con)) {
    rlang::abort("`con` must be a valid DBI connection.", class = "ledgr_invalid_con")
  }
  if (!is.character(snapshot_id) || length(snapshot_id) != 1 || is.na(snapshot_id) || !nzchar(snapshot_id)) {
    rlang::abort("`snapshot_id` must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }

  row <- DBI::dbGetQuery(
    con,
    "SELECT status FROM snapshots WHERE snapshot_id = ?",
    params = list(snapshot_id)
  )
  if (nrow(row) != 1) {
    rlang::abort(sprintf("Snapshot not found: %s", snapshot_id), class = "LEDGR_SNAPSHOT_NOT_FOUND")
  }
  status <- row$status[[1]]
  if (!identical(status, "CREATED")) {
    rlang::abort(
      sprintf("LEDGR_SNAPSHOT_NOT_MUTABLE: snapshot status must be CREATED for import (got %s).", status),
      class = "LEDGR_SNAPSHOT_NOT_MUTABLE"
    )
  }

  invisible(TRUE)
}

