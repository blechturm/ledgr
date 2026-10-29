# Shared timing harness (LDG-3155): the per-cut protocol folder, the slot
# plan and record files. The folder layout (matrix.csv, thresholds.csv,
# workloads.R, protocol.md) is tabled in the benchmark manual's
# "Before/After Regression Gates". `args` ("name=value;...") reaches a
# workload as a named list of strings; the workload returns
# list(seconds = <named clocks>, work = <string>), and the cell's `clock`
# names the entry recorded.

timing_protocol_files <- c("matrix.csv", "thresholds.csv", "workloads.R", "protocol.md")
timing_arms <- c("base", "candidate")

# The harness files a window executes. The runner freezes copies of these
# and of the protocol files into the attempt before the first slot.
timing_harness_files <- c("host.ps1", "host.R", "protocol.R", "measure.R", "runner.R", "check.R")

# Columns of plan.csv and host.csv.
timing_plan_fields <- c("slot", "pair", "cell", "arm")
timing_host_fields <- c("phase", "slot", "at", "plan_guid", "cpu_percent", "root_chain", "foreign_r",
  "cpu_max_ms", "cpu_top", "cpu_unreadable")

# Columns of raw.csv: one row per slot that ran, plus one per unrun slot when
# a window stops early. `arm` and `clock` are independent fields.
timing_raw_fields <- c("seq", "slot", "pair", "cell", "arm", "clock", "seconds", "outcome", "error", "work",
  "launched", "pid", "created", "affinity", "chain", "foreign_r", "plan_guid", "ledgr_path", "ledgr_commit",
  "exit_status")

timing_args <- function(args = commandArgs(trailingOnly = TRUE)) {
  function(name, default = NULL) {
    hit <- grep(paste0("^--", name, "(=|$)"), args, value = TRUE)
    if (!length(hit)) return(default)
    if (!grepl("=", hit[[1L]], fixed = TRUE)) return(TRUE)
    sub(paste0("^--", name, "="), "", hit[[1L]])
  }
}

timing_parse_args <- function(text) {
  if (is.na(text) || !nzchar(trimws(text))) return(list())
  parts <- strsplit(strsplit(text, ";", fixed = TRUE)[[1L]], "=", fixed = TRUE)
  stats::setNames(lapply(parts, function(p) paste(p[-1L], collapse = "=")), vapply(parts, `[`, "", 1L))
}

timing_read_csv <- function(path) {
  utils::read.csv(path, colClasses = "character", na.strings = "NA", stringsAsFactors = FALSE)
}

# Reads and validates a protocol folder. Never stops: problems are returned
# so the checker can report them and the runner can refuse.
timing_read_protocol <- function(dir) {
  dir <- normalizePath(dir, winslash = "/", mustWork = FALSE)
  out <- list(id = basename(dir), dir = dir, pairs = NA_integer_, cells = NULL, problems = character())
  missing <- timing_protocol_files[!file.exists(file.path(dir, timing_protocol_files))]
  extra <- setdiff(list.files(dir, all.files = TRUE, no.. = TRUE), timing_protocol_files)
  if (length(missing)) out$problems <- c(out$problems, paste("missing file:", missing))
  if (length(extra)) out$problems <- c(out$problems, paste("file outside the protocol layout:", extra))
  if (length(missing)) return(out)

  m <- timing_read_csv(file.path(dir, "matrix.csv"))
  t <- timing_read_csv(file.path(dir, "thresholds.csv"))
  if (!identical(names(m), c("cell", "workload", "clock", "args", "pairs"))) {
    out$problems <- c(out$problems, "matrix.csv columns must be cell,workload,clock,args,pairs")
    return(out)
  }
  if (!identical(names(t), c("cell", "bound"))) {
    out$problems <- c(out$problems, "thresholds.csv columns must be cell,bound")
    return(out)
  }
  m$args[is.na(m$args)] <- ""
  if (!nrow(m)) out$problems <- c(out$problems, "matrix.csv has no cells")
  if (anyDuplicated(m$cell) || any(is.na(m$cell) | !nzchar(m$cell))) {
    out$problems <- c(out$problems, "matrix.csv cells must be unique and named")
  }
  if (any(is.na(m$workload) | !nzchar(m$workload) | is.na(m$clock) | !nzchar(m$clock))) {
    out$problems <- c(out$problems, "matrix.csv: every cell needs a workload and a clock")
  }
  pairs <- unique(trimws(m$pairs))
  if (length(pairs) != 1L || !grepl("^[0-9]{1,6}$", pairs) || as.integer(pairs) < 8L) {
    out$problems <- c(out$problems, sprintf("matrix.csv pairs must be one integer of at least 8 (found %s)",
      paste(pairs, collapse = ",")))
  } else {
    out$pairs <- as.integer(pairs)
  }
  bound <- suppressWarnings(as.numeric(t$bound))
  if (any(!is.finite(bound) | bound <= 0)) out$problems <- c(out$problems, "thresholds.csv bounds must be positive numbers")
  for (cell in m$cell[!m$cell %in% t$cell]) out$problems <- c(out$problems, paste("threshold map omits cell", cell))
  for (cell in unique(t$cell[duplicated(t$cell)])) out$problems <- c(out$problems, paste("threshold map names cell twice:", cell))
  for (cell in setdiff(t$cell, m$cell)) out$problems <- c(out$problems, paste("threshold map names unknown cell", cell))
  m$bound <- bound[match(m$cell, t$cell)]
  out$cells <- m[c("cell", "workload", "clock", "args", "bound")]
  out
}

# The planned slots. Pair k runs every cell in matrix order; within a cell
# the two arms run back to back, base first in odd pairs and candidate first
# in even pairs, so drift over the window reaches both arms equally.
timing_plan <- function(protocol) {
  n_cells <- nrow(protocol$cells)
  pair <- rep(seq_len(protocol$pairs), each = 2L * n_cells)
  cell <- rep(rep(protocol$cells$cell, each = 2L), protocol$pairs)
  first <- rep(c(TRUE, FALSE), n_cells * protocol$pairs)
  base_first <- pair %% 2L == 1L
  arm <- ifelse(first == base_first, "base", "candidate")
  data.frame(slot = seq_along(pair), pair = pair, cell = cell, arm = arm, stringsAsFactors = FALSE)
}

# A new attempt directory under a label: numbered one above the highest
# existing suffix, so a gap never leads back to an existing attempt, and
# created exclusively, so nothing is written into a directory that exists.
timing_new_attempt <- function(label_dir) {
  dir.create(label_dir, recursive = TRUE, showWarnings = FALSE)
  existing <- list.files(label_dir, pattern = "^attempt-[0-9]+$")
  n <- if (length(existing)) max(as.integer(sub("^attempt-", "", existing))) + 1L else 1L
  timing_create_attempt(file.path(label_dir, sprintf("attempt-%d", n)))
}
timing_create_attempt <- function(path) {
  if (file.exists(path) || !dir.create(path, showWarnings = FALSE)) {
    stop(sprintf("attempt directory %s already exists or could not be created", path), call. = FALSE)
  }
  normalizePath(path, winslash = "/")
}

# Execution inputs: the six harness files and four protocol files, as files
# on disk (`timing_input_files`) and as repository paths at the harness
# commit (`timing_input_sources`; NA when the folder lies outside the repo).
timing_input_files <- function(harness_dir, protocol_dir) {
  c(file.path(harness_dir, timing_harness_files), file.path(protocol_dir, timing_protocol_files))
}
timing_input_sources <- function(harness_source, protocol_source) {
  at <- function(dir, files) if (is.na(dir) || dir %in% "NA") rep(NA_character_, length(files)) else file.path(dir, files)
  c(at(harness_source, timing_harness_files), at(protocol_source, timing_protocol_files))
}
timing_repo_path <- function(path, repo) {
  full <- normalizePath(path, winslash = "/", mustWork = FALSE)
  if (startsWith(tolower(full), tolower(paste0(repo, "/")))) substring(full, nchar(repo) + 2L) else NA_character_
}

# The one input check, used by the runner before and after a window and by
# the checker on a record: each file's text must equal its source's text at
# `commit` (line endings ignored, as timing_file_text reads them). Returns
# "verified" or the sources that differ, are missing or cannot be read.
timing_verify_inputs <- function(repo, commit, files, sources) {
  bad <- character()
  for (i in seq_along(files)) {
    committed <- if (is.na(sources[[i]])) NULL else suppressWarnings(system2("git", c("-C", shQuote(repo), "show",
      shQuote(paste0(commit, ":", sources[[i]]))), stdout = TRUE, stderr = FALSE))
    if (is.null(committed) || !is.null(attr(committed, "status")) || !file.exists(files[[i]]) ||
        !identical(timing_file_text(files[[i]]), paste(committed, collapse = "\n"))) {
      bad <- c(bad, if (is.na(sources[[i]])) files[[i]] else sources[[i]])
    }
  }
  if (length(bad)) sprintf("differs from %s: %s", substr(commit, 1L, 12L), paste(bad, collapse = ", ")) else "verified"
}

# Line-ending-insensitive text of a file, for comparing a record's protocol
# copy with the protocol folder.
timing_file_text <- function(path) {
  paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
}

# Key/value files (session.csv).
timing_write_kv <- function(values, path) {
  utils::write.csv(data.frame(key = names(values), value = unname(unlist(values)), stringsAsFactors = FALSE),
    path, row.names = FALSE, fileEncoding = "UTF-8")
}
timing_read_kv <- function(path) {
  d <- timing_read_csv(path)
  stats::setNames(as.list(d$value), d$key)
}

timing_append_csv <- function(row, path) {
  utils::write.table(row, path, sep = ",", row.names = FALSE, col.names = !file.exists(path),
    append = file.exists(path), qmethod = "double", fileEncoding = "UTF-8", na = "NA")
}
