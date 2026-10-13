#' Create the current ledgr DuckDB schema
#'
#' Creates the current ledgr schema in a proven-empty store, or verifies that
#' an existing store is current.
#'
#' @param con A DBI connection to DuckDB.
#' @return Invisibly returns `TRUE` on success.
#' @examples
#' db_path <- tempfile(fileext = ".duckdb")
#' con <- DBI::dbConnect(duckdb::duckdb(shared_home = FALSE), dbdir = db_path)
#' ledgr_create_schema(con)
#' DBI::dbDisconnect(con, shutdown = TRUE)
#' @noRd
ledgr_create_schema <- function(con) {
  if (!DBI::dbIsValid(con)) {
    stop("`con` must be a valid DBI connection.", call. = FALSE)
  }
  ledgr_store_create_current(con)
}
