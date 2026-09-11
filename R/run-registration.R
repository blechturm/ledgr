ledgr_run_registration <- function(con,
                                   cfg,
                                   run_id,
                                   seed,
                                   snapshot_id,
                                   metric_context) {
  config_json <- canonical_json(cfg)
  cfg_hash <- config_hash(cfg)

  if (is.null(run_id)) {
    if (!is.null(cfg$run_id) && is.character(cfg$run_id) && length(cfg$run_id) == 1 && nzchar(cfg$run_id) && !is.na(cfg$run_id)) {
      run_id <- cfg$run_id
    } else {
      run_id <- paste0(
        "run_",
        substr(digest::digest(paste0(cfg_hash, ":", if (is.null(seed)) "NULL" else seed), algo = "sha256"), 1, 16)
      )
    }
  }

  if (!is.character(run_id) || length(run_id) != 1 || is.na(run_id) || !nzchar(run_id)) {
    rlang::abort("`run_id` must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }

  engine_version <- as.character(utils::packageVersion("ledgr"))
  metric_context <- ledgr_metric_context_resolve(metric_context)
  metric_context_storage <- ledgr_metric_context_storage(metric_context)

  run_row <- DBI::dbGetQuery(
    con,
    "SELECT run_id, status, config_hash, snapshot_id, metric_context_hash FROM runs WHERE run_id = ?",
    params = list(run_id)
  )
  if (nrow(run_row) > 0) {
    found_run_ids <- as.character(run_row$run_id)
    if (length(found_run_ids) != 1L || !identical(found_run_ids[[1]], run_id)) {
      rlang::abort(
        sprintf(
          "Run lookup returned unexpected run_id. Requested %s, got %s.",
          run_id,
          paste(found_run_ids, collapse = ", ")
        ),
        class = "ledgr_run_lookup_mismatch"
      )
    }
  }

  is_resume <- nrow(run_row) > 0

  if (!is_resume) {
    run_created_at_utc <- as.POSIXct(Sys.time(), tz = "UTC")
    DBI::dbExecute(
      con,
      "
      INSERT INTO runs (
        run_id,
        created_at_utc,
        engine_version,
        config_json,
        config_hash,
        snapshot_id,
        metric_context_json,
        metric_context_hash,
        metric_context_version,
        status,
        error_msg
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ",
      params = list(
        run_id,
        run_created_at_utc,
        engine_version,
        config_json,
        cfg_hash,
        snapshot_id,
        metric_context_storage$json,
        metric_context_storage$hash,
        metric_context_storage$version,
        "CREATED",
        NA_character_
      )
    )
    inserted_run <- DBI::dbGetQuery(
      con,
      "SELECT run_id FROM runs WHERE run_id = ?",
      params = list(run_id)
    )
    if (nrow(inserted_run) != 1L || !identical(as.character(inserted_run$run_id[[1]]), run_id)) {
      rlang::abort(
        sprintf("Run registration verification failed for run_id=%s.", run_id),
        class = "ledgr_run_registration_failed"
      )
    }
  } else {
    stored_cfg_hash <- run_row$config_hash[[1]]
    if (!identical(stored_cfg_hash, cfg_hash)) {
      rlang::abort("Refusing to resume: config_hash does not match stored run.", class = "ledgr_run_hash_mismatch")
    }
    stored_snapshot_id <- run_row$snapshot_id[[1]]
    stored_metric_context_hash <- run_row$metric_context_hash[[1]]
    # Metric context is not execution identity, but a resume call that supplies a
    # conflicting context is ambiguous. Fail loudly rather than silently ignoring it.
    if (is.character(stored_metric_context_hash) && length(stored_metric_context_hash) == 1L &&
      !is.na(stored_metric_context_hash) && nzchar(stored_metric_context_hash) &&
      !identical(stored_metric_context_hash, metric_context_storage$hash)) {
      rlang::abort("Refusing to resume: metric_context_hash does not match stored run.", class = "ledgr_run_hash_mismatch")
    }
    if (!is.character(stored_snapshot_id) || length(stored_snapshot_id) != 1 || is.na(stored_snapshot_id) || !nzchar(stored_snapshot_id)) {
      rlang::abort("Refusing to resume: stored run has no snapshot_id.", class = "ledgr_run_hash_mismatch")
    }
    if (!identical(stored_snapshot_id, snapshot_id)) {
      rlang::abort("Refusing to resume: snapshot_id does not match stored run.", class = "ledgr_run_hash_mismatch")
    }
  }

  list(
    run_id = run_id,
    is_resume = is_resume,
    is_done = is_resume && identical(run_row$status[[1]], "DONE"),
    status = if (is_resume) as.character(run_row$status[[1]]) else "CREATED",
    config_json = config_json,
    config_hash = cfg_hash,
    engine_version = engine_version,
    metric_context = metric_context,
    metric_context_storage = metric_context_storage
  )
}

ledgr_run_registration_provenance <- function(con,
                                              output_handler,
                                              run_id,
                                              cfg,
                                              is_resume) {
  if (isTRUE(is_resume)) {
    return(invisible(FALSE))
  }

  run_created_at <- DBI::dbGetQuery(
    con,
    "SELECT created_at_utc FROM runs WHERE run_id = ?",
    params = list(run_id)
  )$created_at_utc[[1]]
  tryCatch(
    ledgr_write_strategy_provenance(con, run_id, cfg, created_at_utc = run_created_at),
    error = function(e) {
      output_handler$abort_run(
        conditionMessage(e),
        class = "ledgr_run_provenance_failed"
      )
    }
  )
  invisible(TRUE)
}
