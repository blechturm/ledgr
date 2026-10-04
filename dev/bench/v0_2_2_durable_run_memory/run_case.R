args <- commandArgs(TRUE)
if (length(args) != 6L) {
  stop(paste("Usage: run_case.R <repo> <fixture_db> <availability>",
             "<persist_features> <marked> <out_json>"))
}
repo <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
fixture_db <- normalizePath(args[[2L]], winslash = "/", mustWork = TRUE)
availability <- identical(args[[3L]], "true")
persist_features <- identical(args[[4L]], "true")
marked <- identical(args[[5L]], "true")
out_json <- args[[6L]]
script <- dirname(normalizePath(sub("^--file=", "", grep(
  "^--file=", commandArgs(FALSE), value = TRUE
)[[1L]]), winslash = "/"))
source(file.path(script, "helpers.R"), local = TRUE)
product_tree_status <- memory_product_status(repo)
if (nzchar(product_tree_status)) stop("Product tree is dirty:\n", product_tree_status)
suppressMessages(pkgload::load_all(repo, quiet = TRUE, compile = FALSE))

work_db <- tempfile(fileext = ".duckdb")
if (!file.copy(fixture_db, work_db, overwrite = TRUE)) stop("Fixture copy failed")
on.exit(unlink(c(work_db, paste0(work_db, ".wal"))), add = TRUE)
snapshot <- ledgr_snapshot_open(work_db)
on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

phase_rows <- list()
if (marked) {
  ns <- asNamespace("ledgr")
  markers <- sort(memory_phase_markers(ns))
  pending <- paste0("start_", names(markers))
  mark <- function(label) {
    clock <- Sys.time()
    heap <- gc(full = TRUE)
    phase_rows[[length(phase_rows) + 1L]] <<- data.frame(
      marker = label,
      timestamp_utc = format(clock, "%Y-%m-%dT%H:%M:%OS3Z", tz = "UTC"),
      live_mib = sum(heap[, 2L]),
      peak_since_last_mib = sum(heap[, 6L]),
      stringsAsFactors = FALSE
    )
    gc(reset = TRUE, full = TRUE)
    invisible(NULL)
  }
  mark_next <- function() {
    label <- pending[[1L]]
    pending <<- pending[-1L]
    mark(label)
  }
  trace("ledgr_run_fold", where = ns, print = FALSE, at = unname(markers),
        tracer = quote(mark_next()))
  on.exit(untrace("ledgr_run_fold", where = ns), add = TRUE)
  mark("before_run")
}

ledgr_feature_cache_clear()
experiment <- memory_experiment(snapshot, persist_features, availability)
started <- proc.time()[["elapsed"]]
bt <- ledgr_run(experiment, run_id = paste0("memory_", Sys.getpid()))
elapsed <- proc.time()[["elapsed"]] - started
on.exit(close(bt), add = TRUE)
if (marked) mark("after_run")
info <- ledgr_run_info(snapshot, bt$run_id)
out <- list(
  commit = memory_git_commit(repo),
  product_tree_status = product_tree_status,
  availability = availability,
  persist_features = persist_features,
  marked = marked,
  status = info$status,
  elapsed_s = elapsed,
  identities = memory_run_identities(bt, persist_features),
  phases = if (length(phase_rows)) do.call(rbind, phase_rows) else NULL,
  package_version = as.character(utils::packageVersion("ledgr")),
  r_version = paste(R.version$major, R.version$minor, sep = "."),
  duckdb_version = as.character(utils::packageVersion("duckdb")),
  collapse_version = as.character(utils::packageVersion("collapse"))
)
dir.create(dirname(out_json), recursive = TRUE, showWarnings = FALSE)
jsonlite::write_json(out, out_json, auto_unbox = TRUE, pretty = TRUE,
                     null = "null", digits = 16)
cat("DURABLE_MEMORY_CASE_OK", availability, persist_features, marked, "\n")
