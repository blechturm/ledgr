# LDG-2007 SPIKE-4 WAL artifact follow-up.
#
# This is exploratory spike code, not package code. Run from the repository root:
# Rscript dev/spikes/ledgr_parallelism_spike/run_spike4_wal.R

repo_root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
local_lib <- if (.Platform$OS.type == "unix") {
  file.path(repo_root, "lib-wsl")
} else {
  file.path(repo_root, "lib")
}
if (dir.exists(local_lib)) {
  old_libs <- Sys.getenv("R_LIBS", unset = "")
  old_user <- Sys.getenv("R_LIBS_USER", unset = "")
  joined <- paste(c(local_lib, old_libs), collapse = .Platform$path.sep)
  joined <- paste(Filter(nzchar, strsplit(joined, .Platform$path.sep, fixed = TRUE)[[1]]), collapse = .Platform$path.sep)
  Sys.setenv(R_LIBS = joined, R_LIBS_USER = paste(c(local_lib, old_user), collapse = .Platform$path.sep))
  .libPaths(c(local_lib, .libPaths()))
}

required <- c("mirai", "DBI", "duckdb")
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing) > 0L) {
  stop("Missing required packages: ", paste(missing, collapse = ", "), call. = FALSE)
}

library(mirai)

episode_dir <- file.path(repo_root, "dev", "spikes", "ledgr_parallelism_spike")
results_dir <- file.path(episode_dir, "results")
dir.create(results_dir, recursive = TRUE, showWarnings = FALSE)

platform <- paste(Sys.info()[["sysname"]], Sys.info()[["release"]])
platform_slug <- tolower(gsub("[^A-Za-z0-9]+", "-", platform))

shutdown_daemons <- function() try(mirai::daemons(0), silent = TRUE)
start_daemons <- function(n, dispatcher = FALSE) {
  shutdown_daemons()
  mirai::daemons(n, dispatcher = dispatcher)
  invisible(TRUE)
}

list_db_artifacts <- function(db_path) {
  parent <- dirname(db_path)
  stem <- basename(db_path)
  files <- list.files(parent, all.files = TRUE, no.. = TRUE, full.names = FALSE)
  sort(files[startsWith(files, stem)])
}

run_probe <- function(n_workers = 4L, n_tasks = 8L) {
  temp_parent <- tempfile("ldg2007-duckdb-wal-dir-")
  dir.create(temp_parent, recursive = TRUE, showWarnings = FALSE)
  db_path <- file.path(temp_parent, "snapshot.duckdb")

  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = db_path)
  on.exit(try(DBI::dbDisconnect(con, shutdown = TRUE), silent = TRUE), add = TRUE)
  bars <- data.frame(
    instrument_id = rep(sprintf("ID%03d", 1:10), each = 1000),
    ts_utc = rep(seq_len(1000), 10),
    open = runif(10000),
    volume = sample(1000:10000, 10000, replace = TRUE)
  )
  DBI::dbWriteTable(con, "bars", bars)
  DBI::dbExecute(con, "CHECKPOINT")
  DBI::dbDisconnect(con, shutdown = TRUE)

  before <- list_db_artifacts(db_path)

  start_daemons(n_workers, dispatcher = FALSE)
  on.exit(shutdown_daemons(), add = TRUE)
  tasks <- lapply(seq_len(n_tasks), function(i) {
    mirai::mirai({
      con <- DBI::dbConnect(duckdb::duckdb(), dbdir = db_path, read_only = TRUE)
      on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
      DBI::dbGetQuery(con, "select count(*) as n, sum(volume) as volume from bars")
    }, db_path = db_path)
  })
  query_results <- lapply(tasks, function(task) task[])
  after <- list_db_artifacts(db_path)

  unexpected <- setdiff(after, before)
  wal_like <- after[grepl("wal|tmp|lock", after, ignore.case = TRUE)]
  list(
    db_path = db_path,
    before = before,
    after = after,
    unexpected = unexpected,
    wal_like = wal_like,
    query_results = query_results,
    consistent_counts = all(vapply(query_results, function(x) is.data.frame(x) && identical(as.numeric(x$n), 10000), logical(1))),
    consistent_volume = length(unique(vapply(query_results, function(x) as.numeric(x$volume), numeric(1)))) == 1L
  )
}

results <- list(
  metadata = list(platform = platform, timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"), r_version = R.version.string),
  packages = setNames(lapply(required, function(p) as.character(utils::packageVersion(p))), required),
  spike_4_wal = run_probe()
)

shutdown_daemons()
out_file <- file.path(results_dir, paste0(platform_slug, "-spike4-wal-", format(Sys.time(), "%Y%m%d-%H%M%S"), ".rds"))
saveRDS(results, out_file)
cat("Saved results:", out_file, "\n")
cat("before:", paste(results$spike_4_wal$before, collapse = ", "), "\n")
cat("after:", paste(results$spike_4_wal$after, collapse = ", "), "\n")
cat("unexpected:", paste(results$spike_4_wal$unexpected, collapse = ", "), "\n")
cat("wal_like:", paste(results$spike_4_wal$wal_like, collapse = ", "), "\n")
