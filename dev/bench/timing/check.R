# Shared timing harness (LDG-3155): the gate checker.
#
# Checks one attempt record against a per-cut protocol folder and, in gate
# mode, applies its threshold map: for every cell, the median of the
# candidate's seconds over the median of the base's seconds must be at most
# the cell's bound. One attempt is checked as recorded; nothing is retried,
# dropped or re-paired. Before any ratio counts, a record fails on:
#
#   - an invalid protocol (pairs below 8, a threshold map that does not name
#     every cell exactly once) or a record whose protocol copy differs;
#   - an attempt that did not complete, a later attempt without a recorded
#     disposition, a test hook, unenforced host checks, uncommitted harness
#     or protocol files;
#   - a missing, duplicate, unexpected, failed or unrun row, or fewer
#     complete pairs than the protocol states;
#   - invalid seconds, a wrong clock, or a row whose ledgr did not come from
#     its own arm's library and commit;
#   - a power plan other than High performance, affinity other than 0xFFFF
#     on the root or on any process from a measured one up to the root, or a
#     foreign R process, in any host snapshot or any measured process;
#   - an executed order (by process creation time) that does not alternate:
#     the two arms of a cell back to back, base first in odd pairs and
#     candidate first in even pairs;
#   - different work reported within a cell.
#
# --aa checks a self-versus-self record (both arms one commit): validity
# only, with each cell's ratio reported as a noise observation. In gate mode
# an A/A record always fails. Exit status 0 means PASS (gate) or VALID (A/A).
#
# Usage: Rscript dev/bench/timing/check.R --protocol=<folder> --record=<attempt dir> [--aa]

timing_check <- function(protocol_dir, record, aa = FALSE) {
  reasons <- character()
  details <- character()
  fail <- function(reason, detail = "") {
    reasons <<- c(reasons, reason)
    details <<- c(details, detail)
  }
  result <- function(cells = NULL) {
    list(ok = !length(reasons), failures = data.frame(reason = reasons, detail = details), cells = cells)
  }

  # Protocol and record files.
  protocol <- timing_read_protocol(protocol_dir)
  for (p in protocol$problems) fail("protocol", p)
  if (is.null(protocol$cells) || is.na(protocol$pairs)) return(result())
  files <- c("session.csv", "plan.csv", "raw.csv", "host.csv", file.path("protocol", timing_protocol_files))
  if (!all(file.exists(file.path(record, files)))) {
    fail("record files", paste(files[!file.exists(file.path(record, files))], collapse = ", "))
    return(result())
  }
  for (f in timing_protocol_files) {
    if (!identical(timing_file_text(file.path(record, "protocol", f)), timing_file_text(file.path(protocol$dir, f)))) {
      fail("protocol changed", f)
    }
  }

  # The attempt.
  s <- timing_read_kv(file.path(record, "session.csv"))
  for (field in c("protocol", "attempt", "mode", "host_policy", "test_hook", "disposition", "status", "status_reason",
                  "harness_clean", "base_commit", "base_product", "base_lib", "candidate_commit", "candidate_product",
                  "candidate_lib", "root_id", "root_affinity", "plan_guid")) {
    if (is.null(s[[field]])) {
      fail("session field missing", field)
      s[[field]] <- NA_character_
    }
  }
  if (!identical(s$protocol, protocol$id)) fail("protocol changed", sprintf("record ran protocol %s", s$protocol))
  if (!identical(s$status, "complete")) fail("attempt status", sprintf("%s: %s", s$status, s$status_reason))
  if (!identical(s$attempt, "1") && s$disposition %in% c("none", "", NA)) {
    fail("disposition", sprintf("attempt %s has no recorded maintainer disposition", s$attempt))
  }
  if (!identical(s$test_hook, "none")) fail("test hook", s$test_hook)
  if (!identical(s$host_policy, "enforce")) fail("host policy", sprintf("host checks were %s, not enforced", s$host_policy))
  if (!identical(s$harness_clean, "TRUE")) fail("harness changed", "harness or protocol files were uncommitted")
  same_tree <- identical(s$base_commit, s$candidate_commit) || identical(s$base_product, s$candidate_product)
  if (aa && !(same_tree && identical(s$mode, "aa"))) fail("not an A/A record", "--aa needs both arms on one commit")
  if (!aa && (same_tree || !identical(s$mode, "gate"))) {
    fail("A/A record presented as a gate", sprintf("base %s, candidate %s", s$base_commit, s$candidate_commit))
  }
  if (identical(s$base_lib, s$candidate_lib)) fail("arm identity", "both arms name one library")
  if (!identical(s$plan_guid, timing_plan_guid)) fail("power plan", sprintf("session %s", s$plan_guid))
  if (!identical(s$root_affinity, sprintf("%.0f", timing_affinity))) fail("affinity", sprintf("root %s", s$root_affinity))

  # Host snapshots taken by the root before, during and after the window.
  host <- timing_read_csv(file.path(record, "host.csv"))
  host$foreign_r[is.na(host$foreign_r)] <- ""
  where <- sprintf("host %s slot %s", host$phase, host$slot)
  for (i in which(host$plan_guid != timing_plan_guid | is.na(host$plan_guid))) fail("power plan", where[[i]])
  root_aff <- vapply(host$root_chain, function(ch) timing_parse_chain(ch)$affinity[1L], 0)
  for (i in which(is.na(root_aff) | root_aff != timing_affinity)) fail("affinity", paste(where[[i]], "root"))
  for (i in which(nzchar(host$foreign_r))) fail("foreign R", paste(where[[i]], host$foreign_r[[i]]))

  # Rows: completeness.
  raw <- timing_read_csv(file.path(record, "raw.csv"))
  if (!identical(names(raw), timing_raw_fields)) {
    fail("raw columns", paste(names(raw), collapse = ","))
    return(result())
  }
  raw$foreign_r[is.na(raw$foreign_r)] <- ""
  key <- paste(raw$pair, raw$cell, raw$arm, sep = "|")
  plan <- timing_plan(protocol)
  expected <- paste(plan$pair, plan$cell, plan$arm, sep = "|")
  ok <- raw$outcome %in% "ok"
  for (i in which(!ok)) {
    reason <- if (raw$outcome[[i]] %in% c("not_run", "interrupted")) "unrun slot" else "failed execution"
    fail(reason, sprintf("%s %s %s", key[[i]], raw$outcome[[i]], raw$error[[i]]))
  }
  for (k in setdiff(expected, key)) fail("missing row", k)
  for (k in unique(key[duplicated(key)])) fail("duplicate row", k)
  for (k in setdiff(key, expected)) fail("unexpected row", k)
  complete_pairs <- sum(table(factor(raw$pair[ok & !duplicated(key)], levels = seq_len(protocol$pairs))) == 2L * nrow(protocol$cells))
  if (complete_pairs < protocol$pairs) {
    fail("fewer pairs", sprintf("%d complete pairs; the protocol states %d", complete_pairs, protocol$pairs))
  }

  # Rows: each measured process.
  r <- raw[ok, , drop = FALSE]
  k <- key[ok]
  secs <- suppressWarnings(as.numeric(r$seconds))
  for (i in which(!is.finite(secs) | secs <= 0)) fail("invalid seconds", sprintf("%s %s", k[[i]], r$seconds[[i]]))
  for (i in which(!r$exit_status %in% "0")) fail("failed execution", sprintf("%s exit %s", k[[i]], r$exit_status[[i]]))
  want_clock <- protocol$cells$clock[match(r$cell, protocol$cells$cell)]
  for (i in which(is.na(r$clock) | r$clock != want_clock)) fail("clock", sprintf("%s clock %s, cell declares %s", k[[i]], r$clock[[i]], want_clock[[i]]))
  arm_commit <- ifelse(r$arm == "base", s$base_commit, s$candidate_commit)
  arm_lib <- ifelse(r$arm == "base", s$base_lib, s$candidate_lib)
  wrong_arm <- r$ledgr_commit != arm_commit | tolower(dirname(r$ledgr_path)) != tolower(arm_lib)
  for (i in which(is.na(wrong_arm) | wrong_arm)) fail("arm identity", sprintf("%s loaded %s at %s", k[[i]], r$ledgr_path[[i]], r$ledgr_commit[[i]]))
  for (i in which(r$plan_guid != timing_plan_guid | is.na(r$plan_guid))) fail("power plan", sprintf("%s %s", k[[i]], r$plan_guid[[i]]))
  chain_problem <- vapply(r$chain, timing_chain_problem, "", root_id = s$root_id)
  for (i in which(nzchar(chain_problem))) fail("affinity", sprintf("%s %s", k[[i]], chain_problem[[i]]))
  for (i in which(nzchar(r$foreign_r))) fail("foreign R", sprintf("%s %s", k[[i]], r$foreign_r[[i]]))

  # Executed order, read from the operating system's process creation times.
  created <- suppressWarnings(as.numeric(r$created))
  if (anyNA(created) || anyDuplicated(created)) {
    fail("executed order", "process creation times are missing or repeated")
  } else {
    by_created <- order(created)
    if (!identical(by_created, order(as.numeric(r$seq))) || !identical(by_created, order(as.numeric(r$launched)))) {
      fail("executed order", "process creation order differs from the runner's launch order")
    }
    position <- integer(nrow(r))
    position[by_created] <- seq_len(nrow(r))
    cell_key <- paste(r$pair, r$cell, sep = "|")
    for (ck in unique(cell_key)) {
      b <- position[cell_key == ck & r$arm == "base"]
      cn <- position[cell_key == ck & r$arm == "candidate"]
      if (length(b) != 1L || length(cn) != 1L) next
      base_first <- as.integer(sub("\\|.*", "", ck)) %% 2L == 1L
      if (abs(b - cn) != 1L || (b < cn) != base_first) {
        fail("executed order", sprintf("%s ran base at %d and candidate at %d; expected %s first, back to back", ck, b,
          cn, if (base_first) "base" else "candidate"))
      }
    }
  }

  # Work and the per-cell statistic.
  cells <- protocol$cells[c("cell", "clock", "bound")]
  cells$n_base <- cells$n_candidate <- 0L
  cells$median_base <- cells$median_candidate <- NA_real_
  for (j in seq_len(nrow(cells))) {
    in_cell <- r$cell == cells$cell[[j]]
    work <- unique(r$work[in_cell])
    if (length(work) > 1L) fail("work differs", sprintf("%s work %s", cells$cell[[j]], paste(work, collapse = " / ")))
    valid <- in_cell & is.finite(secs) & secs > 0
    cells$n_base[j] <- sum(valid & r$arm == "base")
    cells$n_candidate[j] <- sum(valid & r$arm == "candidate")
    cells$median_base[j] <- if (cells$n_base[j]) stats::median(secs[valid & r$arm == "base"]) else NA_real_
    cells$median_candidate[j] <- if (cells$n_candidate[j]) stats::median(secs[valid & r$arm == "candidate"]) else NA_real_
  }
  cells$ratio <- cells$median_candidate / cells$median_base
  if (aa) {
    cells$noise <- ifelse(abs(cells$ratio - 1) > abs(cells$bound - 1), "beyond bound margin", "within margin")
  } else {
    cells$verdict <- ifelse(is.na(cells$ratio), "NO_DATA", ifelse(cells$ratio <= cells$bound, "PASS", "FAIL"))
    for (j in which(cells$verdict == "FAIL")) {
      fail("ratio above bound", sprintf("%s ratio %.6f > %s", cells$cell[[j]], cells$ratio[[j]], format(cells$bound[[j]])))
    }
  }
  for (j in which(is.na(cells$ratio))) fail("missing cell", sprintf("%s has no valid base or candidate row", cells$cell[[j]]))
  result(cells)
}

timing_check_main <- function() {
  opt <- timing_args()
  if (!is.character(opt("protocol")) || !is.character(opt("record"))) {
    stop("usage: check.R --protocol=<folder> --record=<attempt dir> [--aa]", call. = FALSE)
  }
  aa <- isTRUE(opt("aa"))
  res <- timing_check(opt("protocol"), opt("record"), aa = aa)
  options(width = 200)
  if (!is.null(res$cells)) {
    cat(if (aa) "A/A cells (ratio = median candidate / median base; a noise observation, not a gate):\n" else
      "Cells (ratio = median candidate / median base; PASS when ratio <= bound):\n")
    print(res$cells, row.names = FALSE, digits = 7)
  }
  if (res$ok) {
    cat(if (aa) "\nA/A VALID (validity and noise only; never gate evidence)\n" else "\nCHECK PASS\n")
    return(0L)
  }
  counts <- table(factor(res$failures$reason, levels = unique(res$failures$reason)))
  cat(sprintf("\nCHECK FAIL (%d): %s\n", nrow(res$failures), paste(names(counts), counts, collapse = "; ")))
  for (i in seq_len(nrow(res$failures))) cat(sprintf("  %s: %s\n", res$failures$reason[[i]], res$failures$detail[[i]]))
  1L
}

if (sys.nframe() == 0L) {
  here <- normalizePath(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]])),
    winslash = "/")
  source(file.path(here, "host.R"))
  source(file.path(here, "protocol.R"))
  quit(save = "no", status = timing_check_main())
}
