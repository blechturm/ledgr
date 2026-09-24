ledgr_schema_catalogue <- function(con, schema = "main") {
  tables <- DBI::dbGetQuery(
    con,
    "
    SELECT table_name
    FROM information_schema.tables
    WHERE table_schema = ?
    ORDER BY table_name
    ",
    params = list(schema)
  )
  columns <- DBI::dbGetQuery(
    con,
    "
    SELECT table_name, column_name, data_type, is_nullable, ordinal_position
    FROM information_schema.columns
    WHERE table_schema = ?
    ORDER BY table_name, ordinal_position
    ",
    params = list(schema)
  )
  keys <- DBI::dbGetQuery(
    con,
    "
    SELECT
      tc.table_name,
      tc.constraint_name,
      tc.constraint_type,
      kcu.column_name,
      kcu.ordinal_position
    FROM information_schema.table_constraints tc
    LEFT JOIN information_schema.key_column_usage kcu
      ON tc.constraint_catalog = kcu.constraint_catalog
     AND tc.constraint_schema = kcu.constraint_schema
     AND tc.constraint_name = kcu.constraint_name
     AND tc.table_schema = kcu.table_schema
     AND tc.table_name = kcu.table_name
    WHERE tc.table_schema = ?
      AND tc.constraint_type IN ('PRIMARY KEY', 'UNIQUE')
    ORDER BY tc.table_name, tc.constraint_name, kcu.ordinal_position
    ",
    params = list(schema)
  )
  check_result <- tryCatch(
    list(
      data = DBI::dbGetQuery(
        con,
        "
        SELECT table_name, constraint_type, expression
        FROM duckdb_constraints()
        WHERE schema_name = ?
          AND constraint_type = 'CHECK'
        ORDER BY table_name, constraint_index
        ",
        params = list(schema)
      ),
      error = NULL
    ),
    error = function(e) {
      list(
        data = data.frame(
          table_name = character(),
          constraint_type = character(),
          expression = character()
        ),
        error = e
      )
    }
  )

  list(
    tables = tables,
    columns = columns,
    keys = keys,
    checks = check_result$data,
    checks_error = check_result$error
  )
}

ledgr_schema_catalogue_table_exists <- function(catalogue, table_name) {
  table_name %in% catalogue$tables$table_name
}

ledgr_schema_catalogue_columns <- function(catalogue, table_name) {
  rows <- catalogue$columns$table_name == table_name
  catalogue$columns[rows, , drop = FALSE]
}

ledgr_schema_catalogue_key_columns <- function(catalogue,
                                               table_name,
                                               constraint_type) {
  rows <- catalogue$keys$table_name == table_name &
    catalogue$keys$constraint_type == constraint_type
  catalogue$keys[rows, , drop = FALSE]
}

ledgr_schema_catalogue_checks <- function(catalogue, table_name) {
  rows <- catalogue$checks$table_name == table_name
  catalogue$checks[rows, , drop = FALSE]
}
