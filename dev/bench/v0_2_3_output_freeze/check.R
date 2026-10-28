# A0 checker: re-runs every workload on the current tree into a scratch
# directory and compares each canonical record with records/ byte for byte.
# Exits non-zero on any difference, naming workload, path, table, first
# differing row and column. Also writes agreement.csv: today's agreement
# between the persistent and memory handlers on shared workloads.
#
# Usage: Rscript check.R [--records=<dir>] [--out=<scratch dir>] [--pkg=<root>]
#                        [--agreement=<file>] [--compare-only] [--gut=<name>]
#   --compare-only skips the re-run and compares an existing --out directory.
#   --gut applies one corruption from a0_guts (lib.R); used by gut.R.

local({
  file_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  here <- if (length(file_arg)) dirname(sub("^--file=", "", file_arg[[1L]])) else getwd()
  source(file.path(here, "lib.R"))
  source(file.path(here, "agreement.R"))
})

# Byte comparison of two record directories through their manifests. Returns
# a data frame of differences (empty when identical).
a0_compare_records <- function(expected_dir, actual_dir) {
  read_manifest <- function(d) utils::read.csv(file.path(d, "manifest.csv"), colClasses = "character")
  exp_m <- read_manifest(expected_dir)
  act_m <- read_manifest(actual_dir)
  diffs <- list()
  add <- function(file, row, column, expected, actual) {
    parts <- strsplit(file, "/", fixed = TRUE)[[1L]]
    diffs[[length(diffs) + 1L]] <<- data.frame(
      workload = if (length(parts) == 3L) parts[[1L]] else "", path = if (length(parts) == 3L) parts[[2L]] else "",
      table = sub("[.]csv$", "", parts[[length(parts)]]), first_row = row, column = column,
      expected = substr(expected, 1L, 120L), actual = substr(actual, 1L, 120L), stringsAsFactors = FALSE)
  }
  for (f in setdiff(exp_m$file, act_m$file)) add(f, NA, "<file>", "present", "missing")
  for (f in setdiff(act_m$file, exp_m$file)) add(f, NA, "<file>", "absent", "new file")
  disk_sha <- function(d, f) digest::digest(file = file.path(d, f), algo = "sha256")
  for (f in intersect(exp_m$file, act_m$file)) {
    # The committed record must still match its own manifest (no edited or
    # line-ending-converted record files), then the bytes must match.
    expected_sha <- disk_sha(expected_dir, f)
    if (!identical(expected_sha, exp_m$sha256[exp_m$file == f])) {
      add(f, NA, "<manifest>", exp_m$sha256[exp_m$file == f], paste("record file on disk hashes to", expected_sha))
      next
    }
    if (identical(expected_sha, disk_sha(actual_dir, f))) next
    read <- function(d) utils::read.csv(file.path(d, f), colClasses = "character", na.strings = character(), check.names = FALSE)
    e <- read(expected_dir); a <- read(actual_dir)
    if (!identical(names(e), names(a))) {
      add(f, 0L, "<header>", paste(names(e), collapse = ","), paste(names(a), collapse = ","))
      next
    }
    n <- max(nrow(e), nrow(a))
    found <- FALSE
    for (i in seq_len(n)) {
      if (i > nrow(e) || i > nrow(a)) {
        add(f, i, "<row count>", sprintf("%d rows", nrow(e)), sprintf("%d rows", nrow(a)))
        found <- TRUE
        break
      }
      bad <- names(e)[unlist(e[i, ]) != unlist(a[i, ])]
      if (length(bad)) {
        col <- bad[[1L]]
        ev <- e[i, col]; av <- a[i, col]
        at <- which(strsplit(ev, "")[[1L]][seq_len(min(nchar(ev), nchar(av)))] != strsplit(av, "")[[1L]][seq_len(min(nchar(ev), nchar(av)))])
        start <- if (length(at)) max(1L, at[[1L]] - 30L) else max(1L, min(nchar(ev), nchar(av)) - 30L)
        add(f, i, paste(bad, collapse = "|"), substring(ev, start), substring(av, start))
        found <- TRUE
        break
      }
    }
    if (!found) add(f, NA, "<bytes>", "hash differs", "no cell differs (encoding or line ending)")
  }
  if (length(diffs)) do.call(rbind, diffs) else data.frame()
}

if (sys.nframe() == 0L) {
  a0_load()
  here <- a0_script_dir()
  records_dir <- a0_arg("records", file.path(here, "records"))
  out_dir <- a0_arg("out", file.path(tempdir(), "a0_check"))
  agreement_file <- a0_arg("agreement", file.path(here, "agreement.csv"))
  gut_name <- a0_arg("gut")
  gut <- if (is.null(gut_name)) NULL else a0_guts[[gut_name]]
  if (!is.null(gut_name) && is.null(gut)) stop(sprintf("unknown --gut=%s", gut_name), call. = FALSE)
  if (!"--compare-only" %in% commandArgs(trailingOnly = TRUE)) {
    if (dir.exists(out_dir)) invisible(file.remove(list.files(out_dir, recursive = TRUE, full.names = TRUE)))
    results <- a0_run_all(file.path(tempdir(), "a0_check_work"), gut = gut)
    a0_write_records(results$tables, out_dir)
    if (is.null(gut)) {
      agreement <- a0_agreement(results)
      a0_write_table(agreement, agreement_file)
      cat(sprintf("a0 agreement: %d checks, %d differ (written to %s)\n",
        nrow(agreement), sum(agreement$agrees == "FALSE"), agreement_file))
    } else {
      cat(sprintf("a0 gut %s applied: %s\n", gut_name, gut$what))
    }
  }
  diffs <- a0_compare_records(records_dir, out_dir)
  if (nrow(diffs) == 0L) {
    cat("a0 check: PASS, every record is byte-identical\n")
    quit(status = 0L)
  }
  cat(sprintf("a0 check: FAIL, %d record file(s) differ\n", nrow(diffs)))
  for (i in seq_len(nrow(diffs))) {
    d <- diffs[i, ]
    cat(sprintf("  %s / %s / %s: row %s, column %s\n    expected: %s\n    actual:   %s\n",
      d$workload, d$path, d$table, d$first_row, d$column, d$expected, d$actual))
  }
  quit(status = 1L)
}
