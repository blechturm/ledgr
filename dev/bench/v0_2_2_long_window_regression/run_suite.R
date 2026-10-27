args <- commandArgs(TRUE)
if (length(args) < 4L) {
  stop(paste(
    "Usage: run_suite.R <accepted_repo> <candidate_repo> <out_dir>",
    "<pairs> [ordinary|release] [--release]"
  ))
}
accepted_repo <- normalizePath(args[[1L]], winslash = "/")
candidate_repo <- normalizePath(args[[2L]], winslash = "/")
out_dir <- normalizePath(args[[3L]], winslash = "/", mustWork = FALSE)
pairs <- as.integer(args[[4L]])
profile <- if (length(args) >= 5L) args[[5L]] else "ordinary"
release_flag <- "--release" %in% args
if (identical(profile, "release") && !release_flag) {
  stop("Release-only cases require the explicit --release flag.")
}
if (!identical(profile, "ordinary") && !identical(profile, "release")) {
  stop("Profile must be ordinary or release.")
}
if (!requireNamespace("processx", quietly = TRUE) ||
    !requireNamespace("ps", quietly = TRUE)) {
  stop("The maintained runner requires the development packages processx and ps.")
}

script <- dirname(normalizePath(sub("^--file=", "", grep(
  "^--file=", commandArgs(FALSE), value = TRUE
)[[1L]]), winslash = "/"))
source(file.path(script, "helpers.R"), local = TRUE)
git_commit <- lwreg_git_commit
accepted_commit <- git_commit(accepted_repo)
candidate_commit <- git_commit(candidate_repo)
accepted_tree_status <- lwreg_product_tree_status(accepted_repo)
candidate_tree_status <- lwreg_product_tree_status(candidate_repo)
if (nzchar(accepted_tree_status) || nzchar(candidate_tree_status)) {
  stop("Product trees must be clean before the suite runs.")
}
manifest <- lwreg_manifest(script)
selected <- manifest[manifest$profile == profile, , drop = FALSE]
orientation <- if (identical(profile, "ordinary")) {
  manifest[manifest$profile == "orientation", , drop = FALSE]
} else manifest[FALSE, , drop = FALSE]
if (!nrow(selected)) stop("No cases for profile: ", profile)
if (identical(profile, "ordinary") && pairs < 5L) {
  stop("The ordinary record requires at least five pairs.")
}

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
raw_dir <- file.path(out_dir, "raw")
dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)
cache_root <- Sys.getenv(
  "LWREG_CACHE",
  file.path(tempdir(), paste0("lwreg-cache-", Sys.getpid()))
)
dir.create(cache_root, recursive = TRUE, showWarnings = FALSE)

process_rows <- list()
append_process <- function(row) {
  process_rows[[length(process_rows) + 1L]] <<- row
  utils::write.csv(do.call(rbind, process_rows),
                   file.path(out_dir, "processes.csv"), row.names = FALSE)
}

run_child <- function(kind, shape_id, arm, pair, attempt, repo, child_args) {
  stdout <- file.path(
    raw_dir,
    sprintf("%s_%s_%s_%02d_%s.stdout", kind, shape_id, arm, pair, attempt)
  )
  stderr <- sub("stdout$", "stderr", stdout)
  started <- Sys.time()
  process <- processx::process$new(
    file.path(R.home("bin"), "Rscript"), child_args,
    stdout = stdout, stderr = stderr, cleanup = TRUE
  )
  peak_rss <- 0
  while (process$is_alive()) {
    memory <- tryCatch(
      ps::ps_memory_info(ps::ps_handle(process$get_pid()))[["rss"]],
      error = function(e) NA_real_
    )
    if (is.finite(memory)) peak_rss <- max(peak_rss, memory)
    process$poll_io(100)
  }
  status <- process$get_exit_status()
  elapsed <- as.numeric(difftime(Sys.time(), started, units = "secs"))
  read_log <- function(path) {
    lines <- sub("[ \t]+$", "", readLines(path, warn = FALSE))
    paste(lines, collapse = "\n")
  }
  stdout_text <- read_log(stdout)
  stderr_text <- read_log(stderr)
  process <- NULL
  invisible(gc(verbose = FALSE))
  removed <- unlink(c(stdout, stderr))
  if (any(removed != 0L)) {
    stop("Could not remove captured child logs: ", stdout, ", ", stderr)
  }
  append_process(data.frame(
    kind = kind, shape_id = shape_id, arm = arm, pair = pair,
    attempt = attempt, repo_commit = git_commit(repo), exit_status = status,
    elapsed_s = elapsed, peak_rss_bytes = peak_rss,
    stdout_text = stdout_text, stderr_text = stderr_text,
    stringsAsFactors = FALSE
  ))
  if (!identical(status, 0L)) {
    stop("Child failed: ", shape_id, " ", arm, "; ", stderr_text)
  }
  invisible(stdout)
}

start_suite <- Sys.time()
fixture_rows <- rbind(selected, orientation)
fixture_probes <- list()
for (i in seq_len(nrow(fixture_rows))) {
  row <- fixture_rows[i, , drop = FALSE]
  probes <- list()
  repos <- c(accepted = accepted_repo, candidate = candidate_repo)
  # Each arm builds the same deterministic source fixture in its own current
  # store format. Pre-CRAN store changes refuse older stores rather than
  # migrating them, so sharing one arm's database would test compatibility
  # instead of the declared long-window semantics.
  for (arm in names(repos)) {
    fixture_dir <- file.path(cache_root, row$shape_id, arm)
    dir.create(fixture_dir, recursive = TRUE, showWarnings = FALSE)
    run_child(
      "fixture", row$shape_id, arm, 0L, "initial", repos[[arm]],
      c(file.path(script, "build_fixture.R"), repos[[arm]],
        row$shape_id, fixture_dir)
    )
    probes[[arm]] <- jsonlite::read_json(
      file.path(fixture_dir, "fixture_probe.json"), simplifyVector = TRUE
    )
  }
  if (!identical(probes$accepted, probes$candidate)) {
    stop("Accepted and candidate fixture probes differ: ", row$shape_id)
  }
  fixture_probes[[row$shape_id]] <- probes$accepted
}
jsonlite::write_json(fixture_probes, file.path(out_dir, "fixture_probes.json"),
                     auto_unbox = TRUE, pretty = TRUE, null = "null")

execute_pair <- function(row, pair, attempt) {
  order <- if (pair %% 2L) c("accepted", "candidate") else {
    c("candidate", "accepted")
  }
  repos <- c(accepted = accepted_repo, candidate = candidate_repo)
  for (arm in order) {
    out_json <- file.path(
      raw_dir,
      sprintf("%s_%s_%02d_%s.json", row$shape_id, arm, pair, attempt)
    )
    run_child(
      "case", row$shape_id, arm, pair, attempt, repos[[arm]],
      c(file.path(script, "run_case.R"), repos[[arm]],
        file.path(cache_root, row$shape_id, arm, "snapshot.duckdb"),
        row$shape_id, out_json)
    )
  }
}

for (i in seq_len(nrow(selected))) {
  row <- selected[i, , drop = FALSE]
  for (pair in seq_len(if (identical(profile, "ordinary")) pairs else 1L)) {
    execute_pair(row, pair, "initial")
  }
}

if (nrow(orientation)) {
  row <- orientation[1L, , drop = FALSE]
  out_json <- file.path(raw_dir, "baseline_757_accepted_01_orientation.json")
  run_child(
    "orientation", row$shape_id, "accepted", 1L, "orientation",
    accepted_repo,
    c(file.path(script, "run_case.R"), accepted_repo,
      file.path(cache_root, row$shape_id, "accepted", "snapshot.duckdb"),
      row$shape_id, out_json)
  )
}

case_files <- list.files(raw_dir, pattern = "\\.json$", full.names = TRUE)
measurements <- do.call(rbind, lapply(case_files, function(path) {
  name <- basename(path)
  fields <- strsplit(sub("\\.json$", "", name), "_", fixed = TRUE)[[1L]]
  value <- jsonlite::read_json(path, simplifyVector = TRUE)
  arm <- if (grepl("_accepted_", name, fixed = TRUE)) "accepted" else {
    "candidate"
  }
  pair <- as.integer(sub(".*_([0-9][0-9])_.*", "\\1", name))
  attempt <- sub(".*_[0-9][0-9]_([^.]*)\\.json$", "\\1", name)
  data.frame(
    file = name, shape_id = value$shape_id, arm = arm, pair = pair,
    attempt = attempt, cold_s = value$cold$elapsed_s,
    warm_s = value$warm$elapsed_s, stringsAsFactors = FALSE
  )
}))
utils::write.csv(measurements, file.path(out_dir, "measurements.csv"),
                 row.names = FALSE)

if (identical(profile, "ordinary")) {
  initial <- measurements[measurements$attempt == "initial", , drop = FALSE]
  retry_shapes <- character()
  for (shape in selected$shape_id) {
    part <- initial[initial$shape_id == shape, , drop = FALSE]
    a <- part[part$arm == "accepted", ]
    c <- part[part$arm == "candidate", ]
    a <- a[order(a$pair), ]; c <- c[order(c$pair), ]
    if (median(c$cold_s / a$cold_s) > 1.10 ||
        median(c$warm_s / a$warm_s) > 1.10) {
      retry_shapes <- c(retry_shapes, shape)
    }
  }
  for (shape in retry_shapes) {
    row <- selected[selected$shape_id == shape, , drop = FALSE]
    for (pair in seq_len(pairs)) execute_pair(row, pair, "retry")
  }
}

suite <- list(
  profile = profile,
  pairs = pairs,
  accepted_commit = accepted_commit,
  candidate_commit = candidate_commit,
  accepted_tree_status = accepted_tree_status,
  candidate_tree_status = candidate_tree_status,
  started_at_utc = format(start_suite, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  elapsed_s = as.numeric(difftime(Sys.time(), start_suite, units = "secs"))
)
case_files <- list.files(raw_dir, pattern = "\\.json$", full.names = TRUE)
measurements <- do.call(rbind, lapply(case_files, function(path) {
  name <- basename(path)
  value <- jsonlite::read_json(path, simplifyVector = TRUE)
  arm <- if (grepl("_accepted_", name, fixed = TRUE)) "accepted" else {
    "candidate"
  }
  pair <- as.integer(sub(".*_([0-9][0-9])_.*", "\\1", name))
  attempt <- sub(".*_[0-9][0-9]_([^.]*)\\.json$", "\\1", name)
  data.frame(
    file = name, shape_id = value$shape_id, arm = arm, pair = pair,
    attempt = attempt, cold_s = value$cold$elapsed_s,
    warm_s = value$warm$elapsed_s, stringsAsFactors = FALSE
  )
}))
utils::write.csv(measurements, file.path(out_dir, "measurements.csv"),
                 row.names = FALSE)
jsonlite::write_json(suite, file.path(out_dir, "suite.json"),
                     auto_unbox = TRUE, pretty = TRUE)
cat("LWREG_SUITE_OK", profile, sprintf("%.2f", suite$elapsed_s), "\n")
