ledgr_read_csv_strict <- function(path, encoding = "UTF-8", strict = TRUE) {
  if (!is.character(path) || length(path) != 1 || is.na(path) || !nzchar(path)) {
    rlang::abort("CSV path must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }
  if (!file.exists(path)) {
    rlang::abort(sprintf("CSV file not found: %s", path), class = "ledgr_invalid_args")
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
        class = "ledgr_invalid_args"
      )
    }
  )

  if (!is.data.frame(df)) {
    rlang::abort("CSV did not parse into a data.frame.", class = "ledgr_invalid_args")
  }

  # UTF-8 BOM tolerated: strip from first column name if present.
  if (ncol(df) > 0) {
    names(df)[[1]] <- sub("^\ufeff", "", names(df)[[1]])
  }

  df
}
