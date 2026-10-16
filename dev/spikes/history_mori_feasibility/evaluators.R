e1_parallel_eval_c <- function(tasks, workers, capture) {
  split <- e0_task_split(tasks)
  pid <- e1_daemon_pids(workers, capture$daemon_pid_path)
  capture$daemon_pids <- pid$pids
  capture$pid_probe_sec <- pid$elapsed_sec
  points <- list(e1_memory_point("before_stage", tasks = tasks))
  stage_start <- proc.time()[["elapsed"]]
  staged <- do.call(
    mirai::everywhere,
    list(.expr = quote(TRUE), .ledgr_e1_regular = split$shared, .min = workers)
  )
  invisible(staged[mirai::.flat])
  capture$stage_sec <- proc.time()[["elapsed"]] - stage_start
  points[[length(points) + 1L]] <- e1_memory_point("after_stage", tasks = tasks)
  on.exit({
    clean <- mirai::everywhere({
      if (exists(".ledgr_e1_regular", .GlobalEnv, inherits = FALSE)) {
        rm(".ledgr_e1_regular", envir = .GlobalEnv)
      }
      gc()
      TRUE
    }, .min = workers)
    try(invisible(clean[mirai::.flat]), silent = TRUE)
  }, add = TRUE)

  submit_start <- proc.time()[["elapsed"]]
  promises <- lapply(seq_along(split$variants), function(i) {
    variant <- split$variants[[i]]
    expected_names <- names(tasks[[i]])
    mirai::mirai({
      before_private <- unname(ps::ps_memory_info()[["mem_private"]])
      task <- .ledgr_e1_regular
      task[names(variant)] <- variant
      task <- task[expected_names]
      result <- get(
        "ledgr_sweep_worker_eval_candidate_task", envir = asNamespace("ledgr")
      )(task)
      list(
        result = result,
        result_serialized_bytes = length(serialize(
          result, NULL, ascii = FALSE, xdr = TRUE, version = 3L
        )),
        daemon_private_before = before_private,
        daemon_private_after = unname(ps::ps_memory_info()[["mem_private"]]),
        daemon_wset_after = unname(ps::ps_memory_info()[["wset"]])
      )
    }, variant = variant, expected_names = expected_names)
  })
  capture$submit_sec <- proc.time()[["elapsed"]] - submit_start
  points[[length(points) + 1L]] <- e1_memory_point(
    "after_submit", tasks = tasks, promises = promises
  )

  results <- vector("list", length(promises))
  transfers <- vector("list", length(promises))
  collect_start <- proc.time()[["elapsed"]]
  for (i in seq_along(promises)) {
    envelope <- promises[[i]][]
    if (inherits(envelope, "errorValue")) {
      stop("E1 C worker failed: ", as.character(envelope), call. = FALSE)
    }
    results[[i]] <- envelope$result
    transfers[[i]] <- data.frame(
      candidate_id = tasks[[i]]$candidate_id,
      candidate_status = envelope$result$row$status[[1L]],
      error_class = if (is.null(envelope$result$error)) "" else paste(class(envelope$result$error), collapse = ";"),
      error_message = if (is.null(envelope$result$error)) "" else conditionMessage(envelope$result$error),
      result_serialized_bytes = envelope$result_serialized_bytes,
      envelope_object_bytes = as.numeric(object.size(envelope)),
      daemon_private_before = envelope$daemon_private_before,
      daemon_private_after = envelope$daemon_private_after,
      daemon_wset_after = envelope$daemon_wset_after,
      stringsAsFactors = FALSE
    )
    points[[length(points) + 1L]] <- e1_memory_point(
      paste0("after_collect_", i), tasks, promises, results
    )
  }
  capture$collect_sec <- proc.time()[["elapsed"]] - collect_start
  promises <- NULL
  invisible(gc())
  points[[length(points) + 1L]] <- e1_memory_point(
    "after_drop_promises_gc", tasks = tasks, results = results
  )
  capture$retention <- do.call(rbind, points)
  capture$transfer <- do.call(rbind, transfers)
  results
}

e1_parallel_eval_mori <- function(tasks, workers, capture, mode,
                                  verify = FALSE, gut = "none") {
  parts <- e1_prepare_parts(tasks, mode, gut)
  if (!length(parts$mori_values)) stop("No mori fields selected.", call. = FALSE)
  missing <- setdiff(names(tasks[[1L]]), c(
    names(parts$regular), names(parts$mori_values),
    names(parts$variants[[1L]]), parts$rebuild_fields
  ))
  if (length(missing)) {
    stop("E1_TASK_RECONSTRUCTION_MISSING fields=", paste(missing, collapse = ";"),
         call. = FALSE)
  }

  pid <- e1_daemon_pids(workers, capture$daemon_pid_path)
  capture$daemon_pids <- pid$pids
  capture$pid_probe_sec <- pid$elapsed_sec
  points <- list(e1_memory_point("before_share", tasks = tasks))
  share_start <- proc.time()[["elapsed"]]
  owner <- mori::share(parts$mori_values)
  capture$share_sec <- proc.time()[["elapsed"]] - share_start
  capture$shared_names <- unique(sub("\\[.*$", "", e1_shared_names(owner)))
  capture$shared_wire_bytes <- e0_serialized_bytes(owner)
  capture$shared_regular_bytes <- e0_serialized_bytes(parts$mori_values)
  points[[length(points) + 1L]] <- e1_memory_point(
    "after_share", tasks = tasks, shared_owner = owner
  )

  stage_start <- proc.time()[["elapsed"]]
  staged <- do.call(
    mirai::everywhere,
    list(
      .expr = quote(TRUE), .ledgr_e1_regular = parts$regular,
      .ledgr_e1_mori = owner, .min = workers
    )
  )
  invisible(staged[mirai::.flat])
  capture$stage_sec <- proc.time()[["elapsed"]] - stage_start
  points[[length(points) + 1L]] <- e1_memory_point(
    "after_stage", tasks = tasks, shared_owner = owner
  )
  on.exit({
    clean <- mirai::everywhere({
      if (exists(".ledgr_e1_regular", .GlobalEnv, inherits = FALSE)) {
        rm(".ledgr_e1_regular", envir = .GlobalEnv)
      }
      if (exists(".ledgr_e1_mori", .GlobalEnv, inherits = FALSE)) {
        rm(".ledgr_e1_mori", envir = .GlobalEnv)
      }
      gc()
      TRUE
    }, .min = workers)
    try(invisible(clean[mirai::.flat]), silent = TRUE)
  }, add = TRUE)

  expected <- if (isTRUE(verify)) {
    tasks
  } else {
    vector("list", length(tasks))
  }
  submit_start <- proc.time()[["elapsed"]]
  promises <- lapply(seq_along(parts$variants), function(i) {
    variant <- parts$variants[[i]]
    expected_names <- parts$original_names[[i]]
    expected_task <- expected[[i]]
    mori_fields <- parts$mori_fields
    candidate_id <- tasks[[i]]$candidate_id
    mirai::mirai({
      before_private <- unname(ps::ps_memory_info()[["mem_private"]])
      task <- e1_reconstruct_task(
        .ledgr_e1_regular, .ledgr_e1_mori, variant, expected_names, mode
      )
      shared_before <- e1_shared_state(
        task, mori_fields, "before_eval", candidate_id
      )
      exact <- TRUE
      mismatched <- character()
      fields_compared <- 0L
      if (verify) {
        mismatched <- expected_names[!vapply(expected_names, function(field) {
          identical(task[[field]], expected_task[[field]])
        }, logical(1))]
        exact <- identical(task, expected_task)
        fields_compared <- length(expected_names)
      }
      if (!exact) {
        stop(
          "E1_TASK_RECONSTRUCTION_MISMATCH fields=",
          paste(mismatched, collapse = ";"), call. = FALSE
        )
      }
      result <- get(
        "ledgr_sweep_worker_eval_candidate_task", envir = asNamespace("ledgr")
      )(task)
      shared_after <- e1_shared_state(
        task, mori_fields, "after_eval", candidate_id
      )
      list(
        result = result,
        exact = exact,
        verified = verify,
        fields_compared = fields_compared,
        mismatched = paste(mismatched, collapse = ";"),
        shared_state = rbind(shared_before, shared_after),
        result_serialized_bytes = length(serialize(
          result, NULL, ascii = FALSE, xdr = TRUE, version = 3L
        )),
        daemon_private_before = before_private,
        daemon_private_after = unname(ps::ps_memory_info()[["mem_private"]]),
        daemon_wset_after = unname(ps::ps_memory_info()[["wset"]])
      )
    },
    variant = variant, expected_names = expected_names,
    expected_task = expected_task, mori_fields = mori_fields,
    candidate_id = candidate_id, mode = mode, verify = verify,
    e1_reconstruct_task = e1_reconstruct_task,
    e1_unwrap_shared_containers = e1_unwrap_shared_containers,
    e1_shared_state = e1_shared_state,
    e1_shared_leaf_counts = e1_shared_leaf_counts,
    e1_task_field_fingerprints = e1_task_field_fingerprints,
    e1_field_fingerprint = e1_field_fingerprint,
    e1_materialize = e1_materialize)
  })
  capture$submit_sec <- proc.time()[["elapsed"]] - submit_start
  points[[length(points) + 1L]] <- e1_memory_point(
    "after_submit", tasks = tasks, promises = promises, shared_owner = owner
  )

  results <- vector("list", length(promises))
  transfers <- vector("list", length(promises))
  shared_states <- vector("list", length(promises))
  reconstruction <- vector("list", length(promises))
  collect_start <- proc.time()[["elapsed"]]
  for (i in seq_along(promises)) {
    envelope <- promises[[i]][]
    if (inherits(envelope, "errorValue")) {
      stop("E1 ", mode, " worker failed: ", as.character(envelope), call. = FALSE)
    }
    results[[i]] <- envelope$result
    shared_states[[i]] <- envelope$shared_state
    reconstruction[[i]] <- data.frame(
      candidate_id = tasks[[i]]$candidate_id,
      exact = envelope$exact,
      verified = envelope$verified,
      fields_compared = envelope$fields_compared,
      mismatched_fields = envelope$mismatched,
      stringsAsFactors = FALSE
    )
    transfers[[i]] <- data.frame(
      candidate_id = tasks[[i]]$candidate_id,
      candidate_status = envelope$result$row$status[[1L]],
      error_class = if (is.null(envelope$result$error)) "" else paste(class(envelope$result$error), collapse = ";"),
      error_message = if (is.null(envelope$result$error)) "" else conditionMessage(envelope$result$error),
      result_serialized_bytes = envelope$result_serialized_bytes,
      envelope_object_bytes = as.numeric(object.size(envelope)),
      daemon_private_before = envelope$daemon_private_before,
      daemon_private_after = envelope$daemon_private_after,
      daemon_wset_after = envelope$daemon_wset_after,
      stringsAsFactors = FALSE
    )
    points[[length(points) + 1L]] <- e1_memory_point(
      paste0("after_collect_", i), tasks, promises, results, owner
    )
  }
  capture$collect_sec <- proc.time()[["elapsed"]] - collect_start
  promises <- NULL
  invisible(gc())
  points[[length(points) + 1L]] <- e1_memory_point(
    "after_drop_promises_gc", tasks = tasks, results = results,
    shared_owner = owner
  )
  capture$retention <- do.call(rbind, points)
  capture$transfer <- do.call(rbind, transfers)
  capture$shared_state <- do.call(rbind, shared_states)
  capture$reconstruction <- do.call(rbind, reconstruction)
  capture$mori_fields <- parts$mori_fields
  capture$rebuild_fields <- parts$rebuild_fields
  results
}
