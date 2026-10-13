ledgr_experiment_store_schema_version <- 119L
ledgr_saved_sweep_schema_version <- 4L

ledgr_experiment_store_table_exists <- function(con, table_name) {
  DBI::dbGetQuery(
    con,
    paste0(
      "SELECT COUNT(*) AS n FROM information_schema.tables ",
      "WHERE table_schema = 'main' AND table_name = ?"
    ),
    params = list(table_name)
  )$n[[1L]] > 0L
}

ledgr_experiment_store_columns <- function(con, table_name) {
  DBI::dbGetQuery(
    con,
    paste0(
      "SELECT column_name FROM information_schema.columns ",
      "WHERE table_schema = 'main' AND table_name = ? ",
      "ORDER BY ordinal_position"
    ),
    params = list(table_name)
  )$column_name
}

ledgr_experiment_store_version <- function(con) {
  ledgr_store_assert_current(con)
  ledgr_experiment_store_schema_version
}
