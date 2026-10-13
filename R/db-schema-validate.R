#' Validate the current ledgr DuckDB schema
#'
#' Compares every current table, ordered column, type, nullability, default,
#' constraint and index with ledgr's current schema catalogue.
#'
#' @param con A DBI connection to DuckDB.
#' @return Invisibly returns `TRUE` on success.
#' @examples
#' db_path <- tempfile(fileext = ".duckdb")
#' con <- ledgr_db_init(db_path)
#' ledgr_validate_schema(con)
#' DBI::dbDisconnect(con, shutdown = TRUE)
#' @export
ledgr_validate_schema <- function(con) {
  if (!DBI::dbIsValid(con)) {
    stop("`con` must be a valid DBI connection.", call. = FALSE)
  }
  ledgr_store_assert_current(con)
  actual <- ledgr_schema_normalized_catalogue(con)
  ledgr_schema_validate_catalogue(actual)
  invisible(TRUE)
}

.ledgr_current_schema_catalogue_cache <- new.env(parent = emptyenv())
.ledgr_schema_validation_cache <- new.env(parent = emptyenv())

ledgr_current_schema_catalogue <- function() {
  cached <- .ledgr_current_schema_catalogue_cache$catalogue
  if (!is.null(cached)) {
    return(cached)
  }
  con <- DBI::dbConnect(
    duckdb::duckdb(shared_home = FALSE),
    dbdir = ":memory:"
  )
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  ledgr_schema_render_current(con)
  catalogue <- ledgr_schema_normalized_catalogue(con)
  .ledgr_current_schema_catalogue_cache$catalogue <- catalogue
  catalogue
}

ledgr_schema_normalize_display_type <- function(x) {
  normalize_one <- function(one) {
    one <- toupper(trimws(one))
    one <- gsub("\\s+", " ", one)
    if (one %in% c("VARCHAR", "CHAR", "BPCHAR", "STRING")) return("TEXT")
    if (one %in% c(
      "INTEGER", "INT", "INT4", "BIGINT", "INT8", "SMALLINT", "INT2",
      "UBIGINT", "UINTEGER", "USMALLINT"
    )) return("INTEGER")
    if (one %in% c(
      "DOUBLE", "DOUBLE PRECISION", "FLOAT", "FLOAT4", "FLOAT8", "REAL",
      "DECIMAL", "NUMERIC"
    )) return("DOUBLE")
    if (one %in% c(
      "TIMESTAMP", "TIMESTAMP WITH TIME ZONE", "TIMESTAMPTZ"
    )) return("TIMESTAMP")
    one
  }
  vapply(x, normalize_one, character(1), USE.NAMES = FALSE)
}

ledgr_schema_constraint_signature <- function(x) {
  if (nrow(x) == 0L) return(character())
  do.call(paste, c(x, sep = "\r"))
}

ledgr_schema_abort_enum_difference <- function(expected, actual) {
  rules <- list(
    list("runs", "status", c("CREATED", "RUNNING", "DONE", "INCOMPLETE", "FAILED")),
    list("snapshots", "status", c("CREATED", "SEALED", "FAILED")),
    list("sweep_candidates", "status", c("DONE", "INCOMPLETE", "FAILED")),
    list("walk_forward_scores", "status", c("DONE", "INCOMPLETE", "FAILED")),
    list("walk_forward_folds", "selection_source", c("train", "previous", "none")),
    list("snapshot_trading_status", "status", c("active", "halted", "quotation_only")),
    list("snapshot_lifetime", "assertion", c("known_active", "known_inactive", "unknown")),
    list(
      "snapshot_equity_corporate_actions", "provenance_tier",
      c("snapshot_bound", "upstream_vintage_bound")
    ),
    list("snapshot_sessions", "status", c("open", "closed"))
  )
  for (rule in rules) {
    table_name <- rule[[1L]]
    column_name <- rule[[2L]]
    subset_check <- function(catalogue) {
      catalogue$constraints[
        catalogue$constraints$table_name == table_name &
          catalogue$constraints$constraint_type == "CHECK" &
          grepl(column_name, catalogue$constraints$expression, fixed = TRUE),
        ,
        drop = FALSE
      ]
    }
    if (!identical(
      ledgr_schema_constraint_signature(subset_check(expected)),
      ledgr_schema_constraint_signature(subset_check(actual))
    )) {
      stop(
        sprintf(
          "%s.%s must enforce status values (%s).",
          table_name,
          column_name,
          paste(rule[[3L]], collapse = ", ")
        ),
        call. = FALSE
      )
    }
  }
  invisible(TRUE)
}

ledgr_schema_abort_catalogue_difference <- function(expected, actual) {
  expected_tables <- expected$tables$table_name
  actual_tables <- actual$tables$table_name
  missing_tables <- setdiff(expected_tables, actual_tables)
  if (length(missing_tables) > 0L) {
    stop(sprintf("Missing table: %s", missing_tables[[1L]]), call. = FALSE)
  }
  extra_tables <- setdiff(actual_tables, expected_tables)
  if (length(extra_tables) > 0L) {
    stop(
      sprintf("Schema catalogue mismatch: extra table %s.", extra_tables[[1L]]),
      call. = FALSE
    )
  }

  column_key <- function(x) paste(x$table_name, x$column_name, sep = ".")
  expected_column_key <- column_key(expected$columns)
  actual_column_key <- column_key(actual$columns)
  missing_column_key <- setdiff(expected_column_key, actual_column_key)
  if (length(missing_column_key) > 0L) {
    table_name <- sub("[.].*$", "", missing_column_key[[1L]])
    missing <- expected$columns$column_name[
      expected$columns$table_name == table_name &
        !(expected_column_key %in% actual_column_key)
    ]
    stop(
      sprintf(
        "Missing columns in %s: %s",
        table_name,
        paste(missing, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  extra_column_key <- setdiff(actual_column_key, expected_column_key)
  if (length(extra_column_key) > 0L) {
    stop(
      sprintf(
        "Schema catalogue mismatch: extra column %s.",
        extra_column_key[[1L]]
      ),
      call. = FALSE
    )
  }

  actual_at <- match(expected_column_key, actual_column_key)
  actual_columns <- actual$columns[actual_at, , drop = FALSE]
  different_type <- which(
    expected$columns$data_type != actual_columns$data_type
  )
  if (length(different_type) > 0L) {
    i <- different_type[[1L]]
    expected_type <- ledgr_schema_normalize_display_type(
      expected$columns$data_type[[i]]
    )
    actual_type <- ledgr_schema_normalize_display_type(
      actual_columns$data_type[[i]]
    )
    if (identical(expected_type, actual_type)) {
      stop(
        sprintf(
          paste0(
            "Schema catalogue mismatch: column %s differs in data_type ",
            "(expected %s, got %s)."
          ),
          expected_column_key[[i]], expected$columns$data_type[[i]],
          actual_columns$data_type[[i]]
        ),
        call. = FALSE
      )
    }
    stop(
      sprintf(
        "Column type mismatch: %s expected %s, got %s",
        expected_column_key[[i]], expected_type, actual_type
      ),
      call. = FALSE
    )
  }

  ledgr_schema_abort_enum_difference(expected, actual)

  nullable <- which(
    expected$columns$is_nullable == "NO" &
      actual_columns$is_nullable != "NO"
  )
  if (length(nullable) > 0L) {
    table_name <- expected$columns$table_name[[nullable[[1L]]]]
    columns <- expected$columns$column_name[
      expected$columns$table_name == table_name &
        expected$columns$is_nullable == "NO" &
        actual_columns$is_nullable != "NO"
    ]
    stop(
      sprintf(
        "Expected NOT NULL constraints missing for %s: %s",
        table_name,
        paste(columns, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  column_attributes <- c("ordinal_position", "is_nullable", "column_default")
  for (attribute in column_attributes) {
    different <- which(
      as.character(expected$columns[[attribute]]) !=
        as.character(actual_columns[[attribute]])
    )
    if (length(different) > 0L) {
      i <- different[[1L]]
      stop(
        sprintf(
          paste0(
            "Schema catalogue mismatch: column %s differs in %s ",
            "(expected %s, got %s)."
          ),
          expected_column_key[[i]], attribute,
          expected$columns[[attribute]][[i]],
          actual_columns[[attribute]][[i]]
        ),
        call. = FALSE
      )
    }
  }

  expected_constraints <- expected$constraints
  actual_constraints <- actual$constraints
  tables <- expected_tables
  for (table_name in tables) {
    expected_pk <- expected_constraints[
      expected_constraints$table_name == table_name &
        expected_constraints$constraint_type == "PRIMARY KEY",
      "column_names",
      drop = TRUE
    ]
    actual_pk <- actual_constraints[
      actual_constraints$table_name == table_name &
        actual_constraints$constraint_type == "PRIMARY KEY",
      "column_names",
      drop = TRUE
    ]
    if (!identical(expected_pk, actual_pk)) {
      stop(
        sprintf(
          "Primary key mismatch for %s: expected (%s), got (%s)",
          table_name,
          paste(strsplit(expected_pk, "|", fixed = TRUE)[[1L]], collapse = ", "),
          if (length(actual_pk) == 0L) "" else paste(
            strsplit(actual_pk, "|", fixed = TRUE)[[1L]],
            collapse = ", "
          )
        ),
        call. = FALSE
      )
    }
    expected_unique <- expected_constraints[
      expected_constraints$table_name == table_name &
        expected_constraints$constraint_type == "UNIQUE",
      "column_names",
      drop = TRUE
    ]
    actual_unique <- actual_constraints[
      actual_constraints$table_name == table_name &
        actual_constraints$constraint_type == "UNIQUE",
      "column_names",
      drop = TRUE
    ]
    missing_unique <- setdiff(expected_unique, actual_unique)
    if (length(missing_unique) > 0L) {
      stop(
        sprintf(
          "Missing UNIQUE constraint on %s: (%s)",
          table_name,
          paste(
            strsplit(missing_unique[[1L]], "|", fixed = TRUE)[[1L]],
            collapse = ", "
          )
        ),
        call. = FALSE
      )
    }
  }

  expected_constraint_signature <- ledgr_schema_constraint_signature(
    expected_constraints
  )
  actual_constraint_signature <- ledgr_schema_constraint_signature(
    actual_constraints
  )
  missing_constraint <- which(
    !(expected_constraint_signature %in% actual_constraint_signature)
  )
  if (length(missing_constraint) > 0L) {
    row <- expected_constraints[missing_constraint[[1L]], , drop = FALSE]
    stop(
      sprintf(
        "Schema catalogue mismatch: constraint %s.%s differs.",
        row$table_name[[1L]], row$constraint_type[[1L]]
      ),
      call. = FALSE
    )
  }
  extra_constraint <- which(
    !(actual_constraint_signature %in% expected_constraint_signature)
  )
  if (length(extra_constraint) > 0L) {
    row <- actual_constraints[extra_constraint[[1L]], , drop = FALSE]
    stop(
      sprintf(
        "Schema catalogue mismatch: extra constraint %s.%s.",
        row$table_name[[1L]], row$constraint_type[[1L]]
      ),
      call. = FALSE
    )
  }

  index_key <- function(x) paste(x$table_name, x$index_name, sep = ".")
  expected_index_key <- index_key(expected$indexes)
  actual_index_key <- index_key(actual$indexes)
  missing_index <- setdiff(expected_index_key, actual_index_key)
  if (length(missing_index) > 0L) {
    stop(
      sprintf(
        "Schema catalogue mismatch: missing index %s.",
        missing_index[[1L]]
      ),
      call. = FALSE
    )
  }
  extra_index <- setdiff(actual_index_key, expected_index_key)
  if (length(extra_index) > 0L) {
    stop(
      sprintf("Schema catalogue mismatch: extra index %s.", extra_index[[1L]]),
      call. = FALSE
    )
  }
  actual_index_at <- match(expected_index_key, actual_index_key)
  actual_indexes <- actual$indexes[actual_index_at, , drop = FALSE]
  for (attribute in c("is_unique", "is_primary", "expressions", "sql")) {
    different <- which(
      as.character(expected$indexes[[attribute]]) !=
        as.character(actual_indexes[[attribute]])
    )
    if (length(different) > 0L) {
      i <- different[[1L]]
      stop(
        sprintf(
          "Schema catalogue mismatch: index %s differs in %s.",
          expected_index_key[[i]], attribute
        ),
        call. = FALSE
      )
    }
  }

  stop("Schema catalogue mismatch.", call. = FALSE)
}

ledgr_schema_validate_catalogue <- function(
  actual,
  expected = ledgr_current_schema_catalogue()
) {
  if (!identical(expected, actual)) {
    ledgr_schema_abort_catalogue_difference(expected, actual)
  }
  invisible(TRUE)
}

ledgr_schema_validation_signature <- function(con) {
  row <- DBI::dbGetQuery(
    con,
    paste0(
      "SELECT ",
      "(SELECT md5(string_agg(table_name || ':' || sql, ',' ",
      "ORDER BY table_name)) FROM duckdb_tables() ",
      "WHERE database_name = current_database() ",
      "AND schema_name = 'main') AS tables, ",
      "(SELECT md5(string_agg(",
      "index_name || ':' || sql, ',' ORDER BY index_name)) ",
      "FROM duckdb_indexes() WHERE database_name = current_database() ",
      "AND schema_name = 'main') AS indexes, ",
      "(SELECT md5(string_agg(",
      "view_name || ':' || coalesce(sql, ''), ',' ORDER BY view_name)) ",
      "FROM duckdb_views() WHERE database_name = current_database() ",
      "AND schema_name = 'main' AND NOT internal AND NOT temporary) AS views"
    )
  )
  paste(unname(unlist(row[1L, ], use.names = FALSE)), collapse = "\r")
}

ledgr_validate_schema_once <- function(con) {
  signature <- ledgr_schema_validation_signature(con)
  if (isTRUE(.ledgr_schema_validation_cache[[signature]])) {
    return(invisible(TRUE))
  }
  actual <- ledgr_schema_normalized_catalogue(con)
  ledgr_schema_validate_catalogue(actual)
  assign(signature, TRUE, envir = .ledgr_schema_validation_cache)
  invisible(TRUE)
}
