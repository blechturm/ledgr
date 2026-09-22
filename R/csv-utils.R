# Read an ingestion CSV with DuckDB.
#
# DuckDB is a reader here and nothing more. The columns that carry identity,
# `instrument_id`, `ts_utc` and `symbol`, are forced to VARCHAR so ledgr keeps
# owning instrument ids and every accepted timestamp form; DuckDB never parses
# a timestamp and never turns an all-numeric ticker into a number. Everything
# else is inferred, which makes price columns double rather than integer.
#
# The column names are sniffed first so the type map names only columns that
# are present. Without that, a file missing `ts_utc` would fail inside DuckDB
# with a binder error instead of reaching ledgr's own missing-column message.
#
# LDG-2801. Replaces utils::read.csv(), which took about 4.9 seconds on a
# 630,000-row bars file against about 0.3 seconds here, and which silently
# read a leading-zero instrument id as an integer.
ledgr_csv_identity_columns <- function() {
  c("instrument_id", "ts_utc", "symbol")
}

ledgr_csv_duckdb_path <- function(path) {
  # DuckDB takes forward slashes on every platform, and a single quote in a
  # path would otherwise close the string literal.
  gsub("'", "''", chartr("\\", "/", path), fixed = TRUE)
}

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
  if (!identical(encoding, "UTF-8")) {
    rlang::abort(
      sprintf("ledgr reads CSV files as UTF-8; `encoding = \"%s\"` is not supported.", encoding),
      class = "ledgr_invalid_args"
    )
  }
  if (!is.logical(strict) || length(strict) != 1 || is.na(strict)) {
    rlang::abort("`strict` must be TRUE or FALSE.", class = "ledgr_invalid_args")
  }

  quoted <- ledgr_csv_duckdb_path(path)
  fail <- function(e) {
    rlang::abort(
      sprintf("Failed to read CSV: %s", conditionMessage(e)),
      class = "ledgr_invalid_args"
    )
  }

  con <- tryCatch(DBI::dbConnect(duckdb::duckdb()), error = fail)
  on.exit(try(DBI::dbDisconnect(con, shutdown = TRUE), silent = TRUE), add = TRUE)

  present <- tryCatch(
    names(DBI::dbGetQuery(
      con,
      sprintf("SELECT * FROM read_csv_auto('%s') LIMIT 0", quoted)
    )),
    error = fail
  )

  forced <- intersect(ledgr_csv_identity_columns(), present)
  sql <- if (length(forced) > 0L) {
    sprintf(
      "SELECT * FROM read_csv_auto('%s', types = {%s})",
      quoted,
      paste(sprintf("'%s': 'VARCHAR'", forced), collapse = ", ")
    )
  } else {
    sprintf("SELECT * FROM read_csv_auto('%s')", quoted)
  }

  df <- tryCatch(DBI::dbGetQuery(con, sql), error = fail)

  if (!is.data.frame(df)) {
    rlang::abort("CSV did not parse into a data.frame.", class = "ledgr_invalid_args")
  }

  df
}
