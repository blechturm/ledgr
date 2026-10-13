.ledgr_store_format_cache <- new.env(parent = emptyenv())

ledgr_store_format_bindings <- function(namespace = asNamespace("ledgr")) {
  candidates <- ls(namespace, all.names = TRUE, pattern =
    "^ledgr_[a-z_]+_(schema|rule)_version$")
  values <- mget(candidates, envir = namespace, inherits = FALSE)
  keep <- vapply(values, function(value) {
    is.atomic(value) && length(value) == 1L && !is.na(value)
  }, logical(1))
  values <- values[keep]
  values[order(names(values), method = "radix")]
}

ledgr_store_format_json <- function(bindings = ledgr_store_format_bindings()) {
  if (!is.list(bindings) || is.null(names(bindings)) ||
      anyNA(names(bindings)) || any(!nzchar(names(bindings))) ||
      anyDuplicated(names(bindings))) {
    rlang::abort(
      "Store-format bindings must be a uniquely named list.",
      class = "ledgr_internal_error"
    )
  }
  scalar <- vapply(bindings, function(value) {
    is.atomic(value) && length(value) == 1L && !is.na(value)
  }, logical(1))
  if (!all(scalar)) {
    rlang::abort(
      "Store-format bindings must contain non-missing atomic scalars.",
      class = "ledgr_internal_error"
    )
  }
  bindings <- bindings[order(names(bindings), method = "radix")]
  ledgr_json_write_canonical_v2(bindings)
}

ledgr_store_current_fingerprint <- function() {
  cached <- .ledgr_store_format_cache[["fingerprint"]]
  if (!is.null(cached)) return(cached)
  value <- ledgr_store_format_json()
  assign("fingerprint", value, envir = .ledgr_store_format_cache)
  value
}

ledgr_store_path <- function(con, path = NULL) {
  if (!is.null(path)) {
    candidate <- path
  } else {
    info <- tryCatch(DBI::dbGetInfo(con), error = function(e) list())
    candidate <- info$dbname
  }
  if (!is.character(candidate) || length(candidate) != 1L ||
      is.na(candidate) || !nzchar(candidate)) {
    candidate <- ":memory:"
  }
  if (identical(candidate, ":memory:")) return(candidate)
  normalizePath(candidate, winslash = "/", mustWork = FALSE)
}

ledgr_store_rebuild_abort <- function(cause,
                                      path,
                                      recorded_version = NA_integer_,
                                      recorded_fingerprint = NA_character_,
                                      differing_constants = character()) {
  labels <- c(
    older = "uses an older store format",
    newer = "uses a newer store format",
    missing_marker = "is missing a required store-format marker",
    invalid_marker = "has an invalid store-format marker",
    fingerprint_mismatch = "has a different store-format fingerprint"
  )
  rlang::abort(
    sprintf(
      "The ledgr store at `%s` %s; rebuild it with this ledgr version.",
      path,
      unname(labels[[cause]])
    ),
    class = c("ledgr_store_rebuild_required", "ledgr_invalid_store"),
    cause = cause,
    path = path,
    recorded_version = as.integer(recorded_version),
    recorded_fingerprint = as.character(recorded_fingerprint),
    differing_constants = as.character(differing_constants)
  )
}

ledgr_store_catalog <- function(catalog = NULL) {
  if (is.null(catalog)) return(NULL)
  if (!is.character(catalog) || length(catalog) != 1L ||
      is.na(catalog) || !nzchar(catalog)) {
    rlang::abort(
      "`catalog` must be NULL or a non-empty character scalar.",
      class = "ledgr_internal_error"
    )
  }
  catalog
}

ledgr_store_read_markers <- function(con, catalog = NULL) {
  catalog <- ledgr_store_catalog(catalog)
  metadata_id <- if (is.null(catalog)) {
    DBI::Id(schema = "main", table = "ledgr_schema_metadata")
  } else {
    DBI::Id(
      catalog = catalog,
      schema = "main",
      table = "ledgr_schema_metadata"
    )
  }
  metadata <- DBI::dbQuoteIdentifier(con, metadata_id)
  rows <- tryCatch(
    DBI::dbGetQuery(
      con,
      paste0(
        "SELECT key, value FROM ", metadata, " ",
        "WHERE key IN ",
        "('experiment_store_schema_version', 'format_fingerprint')"
      )
    ),
    error = function(error) {
      if (inherits(error, "duckdb_error") &&
          identical(error$error_type, "CATALOG") &&
          identical(unname(error$extra_info[["error_subtype"]]),
                    "MISSING_ENTRY")) {
        return(NULL)
      }
      stop(error)
    }
  )
  if (is.null(rows)) return(character())
  stats::setNames(as.character(rows$value), as.character(rows$key))
}

ledgr_store_parse_fingerprint <- function(value) {
  if (!is.character(value) || length(value) != 1L || is.na(value) ||
      !isTRUE(yyjsonr::validate_json_str(value))) {
    return(NULL)
  }
  parsed <- tryCatch(ledgr_json_read_config(value), error = function(e) NULL)
  if (!is.list(parsed) || is.null(names(parsed)) || anyDuplicated(names(parsed))) {
    return(NULL)
  }
  scalar <- vapply(parsed, function(one) {
    is.atomic(one) && length(one) == 1L && !is.na(one)
  }, logical(1))
  if (!all(scalar)) return(NULL)
  parsed[order(names(parsed), method = "radix")]
}

ledgr_store_differing_constants <- function(recorded, current) {
  keys <- sort(unique(c(names(recorded), names(current))), method = "radix")
  differs <- vapply(keys, function(key) {
    if (!key %in% names(recorded) || !key %in% names(current)) return(TRUE)
    !identical(recorded[[key]], current[[key]])
  }, logical(1))
  keys[differs]
}

ledgr_store_assert_current <- function(con, path = NULL, catalog = NULL) {
  if (!DBI::dbIsValid(con)) {
    rlang::abort("`con` must be a valid DBI connection.", class = "ledgr_invalid_con")
  }
  path <- ledgr_store_path(con, path)
  markers <- ledgr_store_read_markers(con, catalog = catalog)
  marker <- function(key) {
    if (!key %in% names(markers)) return(NULL)
    unname(markers[[key]])
  }
  version_text <- marker("experiment_store_schema_version")
  fingerprint <- marker("format_fingerprint")
  if (is.null(version_text)) {
    ledgr_store_rebuild_abort("missing_marker", path)
  }
  version <- suppressWarnings(as.integer(version_text))
  valid_version <- length(version) == 1L && !is.na(version) &&
    identical(as.character(version), version_text)
  if (!isTRUE(valid_version)) {
    ledgr_store_rebuild_abort("invalid_marker", path)
  }
  if (version < ledgr_experiment_store_schema_version) {
    ledgr_store_rebuild_abort("older", path, version)
  }
  if (version > ledgr_experiment_store_schema_version) {
    ledgr_store_rebuild_abort("newer", path, version)
  }
  if (is.null(fingerprint)) {
    ledgr_store_rebuild_abort("missing_marker", path, version)
  }
  current_fingerprint <- ledgr_store_current_fingerprint()
  if (identical(fingerprint, current_fingerprint)) {
    return(invisible(TRUE))
  }
  recorded <- ledgr_store_parse_fingerprint(fingerprint)
  if (is.null(recorded)) {
    ledgr_store_rebuild_abort(
      "invalid_marker", path, version, fingerprint
    )
  }
  current <- ledgr_store_format_bindings()
  differing <- ledgr_store_differing_constants(recorded, current)
  if (length(differing) > 0L) {
    ledgr_store_rebuild_abort(
      "fingerprint_mismatch", path, version, fingerprint, differing
    )
  }
  invisible(TRUE)
}

ledgr_store_create_current <- function(con, path = NULL) {
  path <- ledgr_store_path(con, path)
  tables <- DBI::dbGetQuery(
    con,
    paste0(
      "SELECT table_name FROM information_schema.tables ",
      "WHERE table_catalog = current_database() ",
      "AND table_schema = 'main'"
    )
  )$table_name
  if (length(tables) > 0L) {
    ledgr_store_assert_current(con, path)
    return(invisible(FALSE))
  }
  statements <- ledgr_current_schema_statements()
  now <- as.POSIXct(Sys.time(), tz = "UTC")
  DBI::dbWithTransaction(con, {
    for (statement in statements) DBI::dbExecute(con, statement)
    DBI::dbExecute(
      con,
      paste0(
        "INSERT INTO ledgr_schema_metadata (key, value, updated_at_utc) ",
        "VALUES ('experiment_store_schema_version', ?, ?)"
      ),
      params = list(as.character(ledgr_experiment_store_schema_version), now)
    )
    DBI::dbExecute(
      con,
      paste0(
        "INSERT INTO ledgr_schema_metadata (key, value, updated_at_utc) ",
        "VALUES ('format_fingerprint', ?, ?)"
      ),
      params = list(ledgr_store_current_fingerprint(), now)
    )
  })
  invisible(TRUE)
}

ledgr_store_open <- function(path, mode = c("open", "create"),
                             attempts = 50L, sleep_s = 0.05) {
  mode <- match.arg(mode)
  if (identical(mode, "open") && !identical(path, ":memory:") &&
      !file.exists(path)) {
    ledgr_store_rebuild_abort(
      "missing_marker",
      normalizePath(path, winslash = "/", mustWork = FALSE)
    )
  }
  opened <- ledgr_open_duckdb_with_retry(path, attempts, sleep_s)
  ok <- FALSE
  on.exit({
    if (!ok) {
      try(
        DBI::dbDisconnect(opened$con, shutdown = !is.null(opened$drv)),
        silent = TRUE
      )
      if (!is.null(opened$drv)) try(duckdb::duckdb_shutdown(opened$drv), silent = TRUE)
    }
  }, add = TRUE)
  if (identical(mode, "create")) {
    opened$created_current <- isTRUE(
      ledgr_store_create_current(opened$con, path)
    )
  } else {
    ledgr_store_assert_current(opened$con, path)
    opened$created_current <- FALSE
  }
  ok <- TRUE
  opened
}
