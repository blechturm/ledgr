e1_dir <- function() {
  script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  if (!length(script_arg)) return(normalizePath(".", winslash = "/"))
  dirname(normalizePath(sub("^--file=", "", script_arg[[1L]]), winslash = "/"))
}

source(
  file.path(dirname(e1_dir()), "history_mirai_payload_attribution", "common.R"),
  local = globalenv()
)

e1_mori_fields <- function(mode) {
  base <- c(
    "bars_by_id", "pulses_posix", "execution_opportunities_posix",
    "runtime_projection", "availability_data", "corporate_action_rows"
  )
  if (identical(mode, "D_SHARE")) {
    c(base, "bars_mat", "static_bars_views")
  } else if (identical(mode, "D_REBUILD")) {
    base
  } else {
    character()
  }
}

e1_rebuilt_fields <- function(mode) {
  if (identical(mode, "D_REBUILD")) {
    c("bars_mat", "static_bars_views", "pulses_iso")
  } else if (identical(mode, "D_SHARE")) {
    "pulses_iso"
  } else {
    character()
  }
}

e1_prepare_parts <- function(tasks, mode, gut = "none") {
  split <- e0_task_split(tasks)
  mori_fields <- intersect(e1_mori_fields(mode), names(split$shared))
  rebuild_fields <- intersect(e1_rebuilt_fields(mode), names(split$shared))
  regular <- split$shared[setdiff(names(split$shared), c(mori_fields, rebuild_fields))]
  mori_values <- split$shared[mori_fields]
  if (identical(gut, "corrupt-runtime-projection")) {
    projection <- mori_values$runtime_projection
    projection$feature_engine_version <- paste0(
      projection$feature_engine_version, "-E1-GUT"
    )
    mori_values$runtime_projection <- projection
  }
  list(
    regular = regular,
    mori_values = mori_values,
    variants = split$variants,
    mori_fields = mori_fields,
    rebuild_fields = rebuild_fields,
    original_names = lapply(tasks, names),
    expected_tasks = tasks
  )
}

e1_share_leaves <- function(x) {
  if (is.atomic(x)) return(mori::share(x))
  if (is.list(x)) {
    out <- lapply(x, e1_share_leaves)
    attributes(out) <- attributes(x)
    return(out)
  }
  x
}

e1_unwrap_shared_containers <- function(x) {
  if (is.atomic(x)) return(x)
  if (is.list(x)) {
    out <- lapply(seq_along(x), function(i) {
      e1_unwrap_shared_containers(x[[i]])
    })
    attributes(out) <- attributes(x)
    return(out)
  }
  x
}

e1_shared_leaf_counts <- function(x) {
  if (is.atomic(x)) {
    return(c(shared = as.integer(mori::is_shared(x)), atomic = 1L))
  }
  if (!is.list(x)) return(c(shared = 0L, atomic = 0L))
  if (!length(x)) return(c(shared = 0L, atomic = 0L))
  Reduce(`+`, lapply(x, e1_shared_leaf_counts), init = c(shared = 0L, atomic = 0L))
}

e1_shared_names <- function(x) {
  if (is.atomic(x)) {
    name <- mori::shared_name(x)
    return(if (is.null(name)) character() else name)
  }
  if (!is.list(x) || !length(x)) return(character())
  unlist(lapply(x, e1_shared_names), use.names = FALSE)
}

e1_reconstruct_task <- function(regular, mori_values, variant, expected_names,
                                mode) {
  mori_values <- e1_unwrap_shared_containers(mori_values)
  task <- regular
  if (length(mori_values)) task[names(mori_values)] <- mori_values
  task[names(variant)] <- variant
  if (identical(mode, "D_REBUILD")) {
    task$bars_mat <- get(
      "ledgr_sweep_bars_matrix", envir = asNamespace("ledgr")
    )(task$bars_by_id, task$exp$universe)
    task$static_bars_views <- get(
      "ledgr_bars_pulse_views", envir = asNamespace("ledgr")
    )(
      bars_mat = task$bars_mat,
      instrument_ids = task$exp$universe,
      pulses_posix = task$pulses_posix
    )
  }
  task$pulses_iso <- format(
    task$pulses_posix, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"
  )
  task[expected_names]
}

e1_materialize <- function(x) {
  rlang::duplicate(x, shallow = FALSE)
}

e1_field_fingerprint <- function(x) {
  digest::digest(
    serialize(e1_materialize(x), NULL, ascii = FALSE, xdr = TRUE, version = 3L),
    algo = "sha256", serialize = FALSE
  )
}

e1_task_field_fingerprints <- function(task) {
  stats::setNames(vapply(task, e1_field_fingerprint, character(1)), names(task))
}

e1_shared_state <- function(task, fields, when, candidate_id) {
  if (!length(fields)) return(data.frame())
  rows <- lapply(fields, function(field) {
    x <- task[[field]]
    first <- if (is.list(x) && length(x)) x[[1L]] else NULL
    leaves <- e1_shared_leaf_counts(x)
    data.frame(
      candidate_id = candidate_id,
      when = when,
      field = field,
      root_shared = mori::is_shared(x),
      first_child_shared = if (is.null(first)) NA else mori::is_shared(first),
      shared_atomic_leaves = unname(leaves[["shared"]]),
      total_atomic_leaves = unname(leaves[["atomic"]]),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

e1_memory_point <- function(label, tasks = NULL, promises = NULL, results = NULL,
                            shared_owner = NULL) {
  info <- ps::ps_memory_info()
  data.frame(
    label = label,
    epoch = as.numeric(Sys.time()),
    wset_bytes = unname(info[["wset"]]),
    private_commit_bytes = unname(info[["mem_private"]]),
    tasks_object_bytes = if (is.null(tasks)) 0 else as.numeric(object.size(tasks)),
    promise_handle_object_bytes = if (is.null(promises)) 0 else as.numeric(object.size(promises)),
    collected_result_object_bytes = if (is.null(results)) 0 else as.numeric(object.size(results)),
    shared_owner_object_bytes = if (is.null(shared_owner)) 0 else as.numeric(object.size(shared_owner)),
    stringsAsFactors = FALSE
  )
}

e1_daemon_pids <- function(workers, path = NULL) {
  started <- proc.time()[["elapsed"]]
  map <- mirai::everywhere(Sys.getpid(), .min = workers)
  pids <- as.integer(unlist(map[mirai::.flat], use.names = FALSE))
  if (!is.null(path)) e0_write_csv(data.frame(pid = pids), path)
  list(pids = pids, elapsed_sec = proc.time()[["elapsed"]] - started)
}

e1_result_identity <- function(out, arm) e0_result_identity(out, arm)

e1_empty_shared_state <- function() {
  data.frame(
    candidate_id = character(), when = character(), field = character(),
    root_shared = logical(), first_child_shared = logical(),
    shared_atomic_leaves = integer(), total_atomic_leaves = integer(),
    stringsAsFactors = FALSE
  )
}
