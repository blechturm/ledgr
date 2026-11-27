# Worker side of install.R: loop_workers.R's worker boot sources this file
# and calls lean_load_edited(.lean, home, edits, marker); here that call
# installs the explicit-state fork the parent installed and leaves a marker.
lean_load_edited <- function(env, home, edits, marker = NULL) {
  spec <- edits[[1L]]
  sys.source(file.path(spec$dir, "transform.R"), envir = env, keep.source = FALSE)
  sys.source(file.path(spec$dir, "take_return.R"), envir = env, keep.source = FALSE)
  env$es_install(env, spec$set, spec$gut)
  if (nzchar(spec$marks)) {
    dir.create(spec$marks, recursive = TRUE, showWarnings = FALSE)
    writeLines(c(spec$set, as.character(env$.lean_debug), paste(deparse(body(env$lean_fold_envelope_plain)[[2L]]), collapse = "")),
               file.path(spec$marks, paste0("worker_", Sys.getpid(), ".txt")))
  }
  invisible(env)
}
