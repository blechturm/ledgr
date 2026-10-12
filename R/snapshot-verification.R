.ledgr_snapshot_verified <- new.env(parent = emptyenv())

ledgr_snapshot_verified_generation <- function() {
  pid <- Sys.getpid()
  if (!identical(.ledgr_snapshot_verified$pid, pid) ||
      !is.environment(.ledgr_snapshot_verified$entries)) {
    .ledgr_snapshot_verified$pid <- pid
    .ledgr_snapshot_verified$nonce <- digest::digest(
      paste(pid, format(new.env(parent = emptyenv())), sep = ":"),
      algo = "sha256"
    )
    .ledgr_snapshot_verified$entries <- new.env(parent = emptyenv())
  }
  .ledgr_snapshot_verified
}

ledgr_snapshot_verified_reset <- function() {
  .ledgr_snapshot_verified$pid <- NULL
  .ledgr_snapshot_verified$nonce <- NULL
  .ledgr_snapshot_verified$entries <- NULL
  invisible(ledgr_snapshot_verified_generation()$nonce)
}

ledgr_snapshot_connection_store_key <- function(con) {
  info <- tryCatch(DBI::dbGetInfo(con), error = function(e) NULL)
  if (!is.list(info)) return(NULL)
  db_path <- info$dbname %||% info$database %||% NULL
  ledgr_store_key(db_path)
}

ledgr_snapshot_verified_key <- function(store_key, snapshot_id, root, rule) {
  if (is.null(store_key)) return(NULL)
  digest::digest(
    list(
      store_key = store_key,
      snapshot_id = snapshot_id,
      root = root,
      rule = as.integer(rule)
    ),
    algo = "sha256"
  )
}

ledgr_snapshot_verified_contains <- function(store_key, snapshot_id, root, rule) {
  key <- ledgr_snapshot_verified_key(store_key, snapshot_id, root, rule)
  if (is.null(key)) return(FALSE)
  entries <- ledgr_snapshot_verified_generation()$entries
  exists(key, envir = entries, inherits = FALSE)
}

ledgr_snapshot_verified_register <- function(store_key, snapshot_id, root, rule) {
  key <- ledgr_snapshot_verified_key(store_key, snapshot_id, root, rule)
  if (is.null(key)) return(invisible(FALSE))
  entries <- ledgr_snapshot_verified_generation()$entries
  assign(
    key,
    list(
      store_key = store_key,
      snapshot_id = snapshot_id,
      root = root,
      rule = as.integer(rule)
    ),
    envir = entries
  )
  invisible(TRUE)
}

ledgr_snapshot_verified_remove <- function(store_key, snapshot_id,
                                           root = NULL, rule = NULL) {
  if (is.null(store_key)) return(invisible(FALSE))
  entries <- ledgr_snapshot_verified_generation()$entries
  keys <- ls(entries, all.names = TRUE)
  if (length(keys) == 0L) return(invisible(FALSE))
  remove <- vapply(
    keys,
    function(key) {
      entry <- entries[[key]]
      identical(entry$store_key, store_key) &&
        identical(entry$snapshot_id, snapshot_id) &&
        (is.null(root) || identical(entry$root, root)) &&
        (is.null(rule) || identical(entry$rule, as.integer(rule)))
    },
    logical(1)
  )
  if (any(remove)) rm(list = keys[remove], envir = entries)
  invisible(any(remove))
}

ledgr_snapshot_verified_store_key <- function(snapshot_db_path = NULL,
                                              con = NULL,
                                              connection_is_snapshot_store = FALSE) {
  if (!is.null(snapshot_db_path)) return(ledgr_store_key(snapshot_db_path))
  if (isTRUE(connection_is_snapshot_store) && !is.null(con)) {
    return(ledgr_snapshot_connection_store_key(con))
  }
  NULL
}

ledgr_snapshot_verification_envelope <- function(con, snapshot_id) {
  row <- DBI::dbGetQuery(
    con,
    paste(
      "SELECT status, snapshot_hash, hash_rule_version",
      "FROM snapshots WHERE snapshot_id = ?"
    ),
    params = list(snapshot_id)
  )
  if (nrow(row) != 1L) {
    rlang::abort(
      sprintf("Snapshot not found: %s", snapshot_id),
      class = "LEDGR_SNAPSHOT_NOT_FOUND"
    )
  }
  row
}

ledgr_snapshot_ensure_verified <- function(con,
                                           snapshot_id,
                                           snapshot_db_path = NULL,
                                           connection_is_snapshot_store = FALSE,
                                           force = FALSE,
                                           corruption_class = "LEDGR_SNAPSHOT_CORRUPTED",
                                           corruption_message = paste(
                                             "LEDGR_SNAPSHOT_CORRUPTED: stored",
                                             "snapshot_hash does not match recomputed hash."
                                           )) {
  if (!DBI::dbIsValid(con)) {
    rlang::abort("`con` must be a valid DBI connection.", class = "ledgr_invalid_con")
  }
  if (!is.character(snapshot_id) || length(snapshot_id) != 1L ||
      is.na(snapshot_id) || !nzchar(snapshot_id)) {
    rlang::abort(
      "`snapshot_id` must be a non-empty character scalar.",
      class = "ledgr_invalid_args"
    )
  }
  store_key <- ledgr_snapshot_verified_store_key(
    snapshot_db_path,
    con,
    connection_is_snapshot_store
  )
  envelope <- tryCatch(
    ledgr_snapshot_verification_envelope(con, snapshot_id),
    error = function(e) {
      ledgr_snapshot_verified_remove(store_key, snapshot_id)
      stop(e)
    }
  )
  root <- envelope$snapshot_hash[[1L]]
  rule <- envelope$hash_rule_version[[1L]]
  if (!identical(envelope$status[[1L]], "SEALED")) {
    ledgr_snapshot_verified_remove(store_key, snapshot_id, root, rule)
    rlang::abort(
      sprintf(
        "LEDGR_SNAPSHOT_NOT_SEALED: snapshot status must be SEALED (got %s).",
        envelope$status[[1L]]
      ),
      class = "LEDGR_SNAPSHOT_NOT_SEALED"
    )
  }
  if (!is.character(root) || length(root) != 1L || is.na(root) || !nzchar(root)) {
    ledgr_snapshot_verified_remove(store_key, snapshot_id, root, rule)
    rlang::abort(
      "LEDGR_SNAPSHOT_NOT_SEALED: SEALED snapshot is missing snapshot_hash.",
      class = "LEDGR_SNAPSHOT_NOT_SEALED"
    )
  }
  tryCatch(
    ledgr_snapshot_require_hash_rule3(rule),
    error = function(e) {
      ledgr_snapshot_verified_remove(store_key, snapshot_id, root, rule)
      stop(e)
    }
  )
  if (!isTRUE(force) &&
      ledgr_snapshot_verified_contains(store_key, snapshot_id, root, rule)) {
    return(root)
  }
  computed <- tryCatch(
    ledgr_snapshot_hash(con, snapshot_id),
    error = function(e) {
      ledgr_snapshot_verified_remove(store_key, snapshot_id, root, rule)
      stop(e)
    }
  )
  if (!identical(computed, root)) {
    ledgr_snapshot_verified_remove(store_key, snapshot_id, root, rule)
    rlang::abort(corruption_message, class = corruption_class)
  }
  ledgr_snapshot_verified_register(store_key, snapshot_id, root, rule)
  root
}

ledgr_snapshot_ensure_handle <- function(snapshot, force = FALSE,
                                         corruption_class = "LEDGR_SNAPSHOT_CORRUPTED",
                                         corruption_message = paste(
                                           "LEDGR_SNAPSHOT_CORRUPTED: stored",
                                           "snapshot_hash does not match recomputed hash."
                                         )) {
  if (!inherits(snapshot, "ledgr_snapshot")) {
    rlang::abort(
      "`snapshot` must be a ledgr_snapshot object.",
      class = "ledgr_invalid_snapshot"
    )
  }
  release <- ledgr_snapshot_hold(snapshot)
  on.exit(release(), add = TRUE)
  ledgr_snapshot_ensure_verified(
    get_connection(snapshot),
    snapshot$snapshot_id,
    snapshot_db_path = snapshot$db_path,
    force = force,
    corruption_class = corruption_class,
    corruption_message = corruption_message
  )
}

ledgr_backtest_ensure_snapshot <- function(bt, con = NULL) {
  if (!inherits(bt, "ledgr_backtest")) {
    rlang::abort("`bt` must be a ledgr_backtest object.", class = "ledgr_invalid_backtest")
  }
  cfg <- bt$config
  if (!is.list(cfg$data) || !identical(cfg$data$source, "snapshot")) {
    return(invisible(NULL))
  }
  opened <- NULL
  if (is.null(con)) {
    opened <- ledgr_backtest_read_connection(bt)
    con <- opened$con
    on.exit(opened$close(), add = TRUE)
  }
  run_db_path <- cfg$db_path
  snapshot_db_path <- ledgr_snapshot_db_path_from_config(cfg, run_db_path)
  ledgr_prepare_snapshot_source_tables(con, snapshot_db_path, run_db_path)
  ledgr_snapshot_ensure_verified(
    con,
    cfg$data$snapshot_id,
    snapshot_db_path = snapshot_db_path
  )
}
