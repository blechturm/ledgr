# WS1 timing protocol (LDG-3127): the record checker.
#
# Validates one runner.R record against the frozen matrix and evaluates the
# per-cell bound: for every workload x path cell, median(candidate seconds) /
# median(base seconds) <= 1.03, unless that cell has a linked maintainer
# exception. Any invalid record fails before a ratio can pass: missing,
# duplicate or unexpected rows; non-finite or non-positive seconds; failed,
# skipped or incomplete executions; unexpected statuses or candidate counts;
# unpinned host rows; differing work between arms; a smoke record; a pair
# count other than the frozen eight; a changed protocol file; malformed arm
# identities (commit, tree, product digest, library) or missing host and
# toolchain fields; a row that loaded ledgr from the other arm's library; arms
# that do not alternate as declared. A PASS checks the record's internal
# consistency; it does not authenticate that the runner produced it. Exit status 0 means PASS, 1 means FAIL.
#
# Usage: Rscript dev/bench/v0_2_3_ws1_timing/check.R --record=<dir>
#   [--exceptions=<csv with workload,path,link>] [--out=<summary csv>]

ws1_check_here <- function() {
  file_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  if (length(file_arg)) return(normalizePath(dirname(sub("^--file=", "", file_arg[[1L]])), winslash = "/"))
  if (exists("ws1_here", envir = globalenv())) return(get("ws1_here", envir = globalenv()))
  normalizePath(file.path(getwd(), "dev", "bench", "v0_2_3_ws1_timing"), winslash = "/")
}

ws1_check_record <- function(record, root, exceptions = NULL) {
  failures <- data.frame(reason = character(), detail = character(), stringsAsFactors = FALSE)
  fail <- function(reason, detail) {
    failures[nrow(failures) + 1L, ] <<- list(reason, detail)
  }
  meta_path <- file.path(record, "meta.csv")
  raw_path <- file.path(record, "raw.csv")
  if (!file.exists(meta_path) || !file.exists(raw_path)) {
    fail("missing record file", "meta.csv and raw.csv are both required")
    return(list(ok = FALSE, failures = failures, cells = NULL, h6 = NULL))
  }
  meta_df <- utils::read.csv(meta_path, colClasses = "character")
  meta <- stats::setNames(meta_df$value, meta_df$key)
  m <- function(key) if (key %in% names(meta)) meta[[key]] else NA_character_

  # Record-level validity.
  if (!identical(m("protocol_version"), ws1_timing_protocol_version)) {
    fail("protocol version", sprintf("record %s, checker %s", m("protocol_version"), ws1_timing_protocol_version))
  }
  if (!identical(m("smoke"), "FALSE")) fail("smoke record", "a --smoke record is not gate evidence")
  if (is.na(m("finished_utc"))) fail("record incomplete", "runner.R did not finish (no finished_utc)")
  if (!identical(m("power_plan_guid"), ws1_timing_power_plan_guid)) {
    fail("host not registered", sprintf("runner power plan %s", m("power_plan_guid")))
  }
  if (!identical(suppressWarnings(as.numeric(m("runner_affinity"))), ws1_timing_affinity)) {
    fail("host not registered", sprintf("runner affinity %s", m("runner_affinity")))
  }
  if (!identical(m("runner_worktree_clean_protocol"), "TRUE")) {
    fail("protocol changed", "the runner's protocol files were not clean in git")
  }
  for (f in ws1_timing_protocol_files) {
    current <- ws1_timing_file_digest(file.path(root, f))
    if (!identical(m(paste0("sha256:", f)), current)) fail("protocol changed", f)
  }
  retain <- digest::digest(ws1_timing_retain_text(root), algo = "sha256", serialize = FALSE)
  if (!identical(m("retain_sha256"), retain)) fail("protocol changed", "A0 a0_retain definition")
  # Arm identities and host/toolchain fields must be well formed and present.
  sha <- "^[0-9a-f]{40}$"
  product <- "^R=[0-9a-f]{40};src=[0-9a-f]{40};DESCRIPTION=[0-9a-f]{40};NAMESPACE=[0-9a-f]{40}$"
  for (arm in ws1_timing_arms) {
    for (field in c("commit", "tree")) {
      key <- paste0(arm, "_", field)
      if (is.na(m(key)) || !grepl(sha, m(key))) fail("arm identity", sprintf("%s=%s", key, m(key)))
    }
    if (is.na(m(paste0(arm, "_product"))) || !grepl(product, m(paste0(arm, "_product")))) {
      fail("arm identity", sprintf("%s_product=%s", arm, m(paste0(arm, "_product"))))
    }
    if (is.na(m(paste0(arm, "_lib"))) || !nzchar(m(paste0(arm, "_lib")))) {
      fail("arm identity", sprintf("%s_lib is missing", arm))
    }
  }
  if (identical(m("base_lib"), m("candidate_lib"))) fail("arm identity", "both arms name the same library")
  for (field in c("runner_commit", "started_utc", "R_version", "cxx", "gxx_version", "dependencies",
                  "library_paths", "cpu", "logical_cores", "power_plan")) {
    if (is.na(m(field)) || !nzchar(trimws(m(field)))) fail("host or toolchain field missing", field)
  }
  pairs <- suppressWarnings(as.integer(m("pairs")))
  if (!identical(pairs, ws1_timing_pairs)) {
    fail("pair count", sprintf("record declares %s pairs; the protocol fixes %d", m("pairs"), ws1_timing_pairs))
    pairs <- ws1_timing_pairs
  }

  raw <- utils::read.csv(raw_path, colClasses = "character", na.strings = "NA")
  if (!identical(names(raw), ws1_timing_raw_fields)) {
    fail("raw columns", paste(names(raw), collapse = ","))
    return(list(ok = FALSE, failures = failures, cells = NULL, h6 = NULL))
  }

  # Completeness: exactly one row per pair x cell x arm, nothing else.
  cells <- ws1_timing_cells()
  grid <- merge(merge(data.frame(pair = as.character(seq_len(pairs))), cells), data.frame(arm = ws1_timing_arms))
  key <- function(d) paste(d$pair, d$workload, d$path, d$arm, sep = "|")
  expected <- key(grid)
  got <- key(raw)
  for (k in setdiff(expected, got)) fail("missing row", k)
  for (k in unique(got[duplicated(got)])) fail("duplicate row", k)
  for (k in setdiff(got, expected)) fail("unexpected row", k)

  # Alternation: in each cell the two arms are adjacent in sequence, base
  # first in odd pairs and candidate first in even pairs.
  seq_no <- suppressWarnings(as.integer(raw$seq))
  if (anyNA(seq_no) || anyDuplicated(seq_no)) fail("sequence", "seq must be unique integers")
  cell_key <- paste(raw$pair, raw$workload, raw$path, sep = "|")
  for (ck in unique(cell_key[!duplicated(got)])) {
    rows <- which(cell_key == ck)
    b <- seq_no[rows][raw$arm[rows] == "base"]
    cn <- seq_no[rows][raw$arm[rows] == "candidate"]
    if (length(b) != 1L || length(cn) != 1L || anyNA(c(b, cn))) next
    odd <- as.integer(strsplit(ck, "|", fixed = TRUE)[[1L]][[1L]]) %% 2L == 1L
    if (abs(b - cn) != 1L || (odd && b > cn) || (!odd && cn > b)) {
      fail("arm order", sprintf("%s base seq %d, candidate seq %d", ck, b, cn))
    }
  }

  # Each row loaded ledgr from its own arm's library.
  arm_lib <- c(base = m("base_lib"), candidate = m("candidate_lib"))
  for (i in seq_len(nrow(raw))) {
    lib <- arm_lib[raw$arm[[i]]]
    if (is.na(lib) || is.na(raw$ledgr_path[[i]]) || !startsWith(tolower(raw$ledgr_path[[i]]), tolower(lib))) {
      fail("arm identity", sprintf("%s ledgr_path=%s", got[[i]], raw$ledgr_path[[i]]))
    }
  }

  # Row validity.
  secs <- suppressWarnings(as.numeric(raw$seconds))
  declared <- ws1_timing_workloads[match(raw$workload, ws1_timing_workloads$workload), , drop = FALSE]
  for (i in seq_len(nrow(raw))) {
    k <- got[[i]]
    if (!identical(raw$outcome[[i]], "ok") || !identical(raw$exit_status[[i]], "0")) {
      fail("failed or skipped execution", sprintf("%s outcome=%s exit=%s %s", k, raw$outcome[[i]],
        raw$exit_status[[i]], if (is.na(raw$error[[i]])) "" else raw$error[[i]]))
    }
    if (is.na(secs[[i]]) || !is.finite(secs[[i]]) || secs[[i]] <= 0) {
      fail("invalid seconds", sprintf("%s seconds=%s", k, raw$seconds[[i]]))
    }
    if (!is.na(declared$workload[[i]])) {
      if (!identical(raw$candidates[[i]], as.character(declared$candidates[[i]])) ||
          !identical(raw$statuses[[i]], declared$statuses[[i]])) {
        fail("incomplete or unexpected status", sprintf("%s candidates=%s statuses=%s; expected %d %s", k,
          raw$candidates[[i]], raw$statuses[[i]], declared$candidates[[i]], declared$statuses[[i]]))
      }
    }
    if (!identical(suppressWarnings(as.numeric(raw$affinity[[i]])), ws1_timing_affinity) ||
        !identical(raw$power_plan_guid[[i]], ws1_timing_power_plan_guid)) {
      fail("host not registered", sprintf("%s affinity=%s plan=%s", k, raw$affinity[[i]], raw$power_plan_guid[[i]]))
    }
  }

  # Per-cell statistic: ratio of medians over valid rows.
  valid <- raw$outcome == "ok" & raw$exit_status == "0" & !is.na(secs) & is.finite(secs) & secs > 0
  exc <- if (is.null(exceptions)) NULL else utils::read.csv(exceptions, colClasses = "character")
  out <- lapply(seq_len(nrow(cells)), function(j) {
    in_cell <- raw$workload == cells$workload[[j]] & raw$path == cells$path[[j]]
    trades <- unique(raw$n_trades[in_cell])
    if (length(trades) > 1L) {
      fail("work differs between rows", sprintf("%s|%s n_trades=%s", cells$workload[[j]], cells$path[[j]],
        paste(trades, collapse = "/")))
    }
    b <- secs[in_cell & valid & raw$arm == "base"]
    cnd <- secs[in_cell & valid & raw$arm == "candidate"]
    mb <- if (length(b)) stats::median(b) else NA_real_
    mc <- if (length(cnd)) stats::median(cnd) else NA_real_
    ratio <- mc / mb
    excepted <- !is.null(exc) && any(exc$workload == cells$workload[[j]] & exc$path == cells$path[[j]] &
      nzchar(trimws(exc$link)))
    verdict <- if (is.na(ratio)) "NO_DATA" else if (ratio <= ws1_timing_bound) "PASS" else if (excepted) "EXCEPTED" else "FAIL"
    if (verdict == "FAIL") {
      fail("ratio above bound", sprintf("%s|%s ratio=%.6f > %.2f", cells$workload[[j]], cells$path[[j]], ratio,
        ws1_timing_bound))
    }
    if (verdict == "NO_DATA") fail("missing row", sprintf("%s|%s has no valid base or candidate row",
      cells$workload[[j]], cells$path[[j]]))
    data.frame(workload = cells$workload[[j]], path = cells$path[[j]], n_base = length(b),
      n_candidate = length(cnd), median_base = mb, median_candidate = mc, ratio = ratio,
      verdict = verdict, stringsAsFactors = FALSE)
  })
  cell_table <- do.call(rbind, out)
  if (is.null(cell_table) || nrow(cell_table) != nrow(cells)) {
    fail("empty matrix", "the checker evaluated fewer cells than the frozen matrix declares")
  }

  # H6: committed-run over sweep median seconds, per workload and arm.
  h6 <- do.call(rbind, lapply(ws1_timing_workloads$workload, function(w) {
    row <- cell_table[cell_table$workload == w, , drop = FALSE]
    data.frame(workload = w,
      base_run_over_sweep = row$median_base[row$path == "run"] / row$median_base[row$path == "sweep"],
      candidate_run_over_sweep = row$median_candidate[row$path == "run"] / row$median_candidate[row$path == "sweep"],
      stringsAsFactors = FALSE)
  }))
  list(ok = nrow(failures) == 0L, failures = failures, cells = cell_table, h6 = h6)
}

ws1_check_main <- function(args = commandArgs(trailingOnly = TRUE)) {
  here <- ws1_check_here()
  root <- normalizePath(file.path(here, "..", "..", ".."), winslash = "/")
  source(file.path(here, "matrix.R"), local = FALSE)
  opt <- function(name) {
    hit <- grep(paste0("^--", name, "="), args, value = TRUE)
    if (length(hit)) sub(paste0("^--", name, "="), "", hit[[1L]]) else NULL
  }
  record <- opt("record")
  if (is.null(record)) stop("check.R: --record=<dir> is required", call. = FALSE)
  res <- ws1_check_record(record, root, exceptions = opt("exceptions"))
  old <- options(width = 200, digits = 7)
  on.exit(options(old), add = TRUE)
  if (!is.null(res$cells)) {
    cat("Cells (ratio = median candidate / median base):\n")
    print(res$cells, row.names = FALSE)
    cat("\nH6 (committed-run median / sweep median):\n")
    print(res$h6, row.names = FALSE)
  }
  if (!is.null(opt("out")) && !is.null(res$cells)) {
    utils::write.csv(res$cells, opt("out"), row.names = FALSE, fileEncoding = "UTF-8")
  }
  if (res$ok) {
    cat("\nCHECK PASS\n")
    return(0L)
  }
  cat(sprintf("\nCHECK FAIL (%d)\n", nrow(res$failures)))
  for (i in seq_len(nrow(res$failures))) cat(sprintf("  %s: %s\n", res$failures$reason[[i]], res$failures$detail[[i]]))
  1L
}

if (sys.nframe() == 0L) {
  quit(status = ws1_check_main())
}
