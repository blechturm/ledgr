# Read an ingestion CSV with DuckDB.
#
# DuckDB is a reader here and nothing more. Every column ledgr persists or
# hashes as text is forced to VARCHAR, so ledgr keeps owning instrument ids,
# every accepted timestamp form, and every stored metadata string; DuckDB
# never parses a timestamp and never turns an all-numeric field into a number.
# The numeric bar and instrument columns are left inferred, which makes them
# double rather than integer.
#
# The forced set is exactly the text columns of snapshot_bars and
# snapshot_instruments, plus `metadata`, which `ledgr_snapshot_from_df()`
# accepts as an alternative spelling of `meta_json`. An all-numeric value in
# any of them, `0001` for instance, is a string to ledgr and would otherwise
# have been inferred as a number and stored without its leading zeros,
# changing the snapshot hash. That defect is what LDG-2801 fixed for
# `instrument_id`; close review W9-F2 found the same hole in the rest.
#
# The column names are sniffed first so the type map names only columns that
# are present. Without that, a file missing `ts_utc` would fail inside DuckDB
# with a binder error instead of reaching ledgr's own missing-column message.
#
# Null tokens. An empty field is missing and ledgr rejects it where the column
# must be non-empty. A literal `NA` is the two-character string, not a missing
# value, because `NA` is a real ticker and CSV says missing with an empty
# field. `utils::read.csv()` read it as missing, so this widens the accepted
# domain deliberately; see W9-F3 in the cut 5 closeout.
#
# LDG-2801. Replaces utils::read.csv(), which took about 4.9 seconds on a
# 630,000-row bars file against about 0.3 seconds here.
ledgr_csv_text_columns <- function() {
  c(
    "instrument_id", "ts_utc",
    "symbol", "currency", "asset_class",
    "meta_json", "metadata"
  )
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

  forced <- intersect(ledgr_csv_text_columns(), present)
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
