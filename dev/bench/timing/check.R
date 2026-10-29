# Shared timing harness (LDG-3155): the gate checker.
#
# Checks one attempt record against a per-cut protocol folder and, in gate
# mode, applies its threshold map: for every cell, the median of the
# candidate's seconds over the median of the base's seconds must be at most
# the cell's bound. One attempt is checked as recorded; nothing is retried,
# dropped or re-paired. Before any ratio counts, a record fails on:
#
#   - an invalid protocol (pairs not an integer of at least 8, a threshold
#     map that does not name every cell exactly once) or a record whose
#     protocol copy differs;
#   - an attempt that did not complete; a later attempt without a recorded
#     disposition (for a gate, one by the maintainer with a decision
#     reference); a test hook; unenforced host checks; executed inputs that
#     were not verified against the harness commit at start and end;
#   - a saved plan that is not the protocol's plan; a missing, duplicate,
#     unexpected, failed or unrun slot or row; fewer complete pairs than the
#     protocol states;
#   - host snapshots that do not cover the window: exactly one before, one
#     after and one before each executed slot, each with a valid time and the
#     session's root first in its chain;
#   - invalid seconds, a wrong clock, a missing work string, or a row whose
#     ledgr did not come from its own arm's library and commit;
#   - a process identity that does not hold together: the chain must start
#     at the row's PID and creation time, with the row's affinity, and the
#     process must have been created just after the runner launched it;
#   - a power plan other than High performance, affinity other than 0xFFFF
#     on the root or on any process from a measured one up to the root, or a
#     foreign R process, in any host snapshot or any measured process;
#   - an executed order (by process creation time) that does not alternate:
#     the two arms of a cell back to back, base first in odd pairs and
#     candidate first in even pairs;
#   - different work reported within a cell.
# CPU load in the host snapshots is a noise observation and never fails.
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
  is_count <- function(x) !is.na(x) & grepl("^[0-9]+$", x)

  # Protocol and record files.
  protocol <- timing_read_protocol(protocol_dir)
  for (p in protocol$problems) fail("protocol", p)
  if (is.null(protocol$cells) || is.na(protocol$pairs)) return(result())
  files <- c("session.csv", "plan.csv", "raw.csv", "host.csv", file.path("protocol", timing_protocol_files),
    file.path("harness", timing_harness_files))
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
                  "harness_commit", "inputs_start", "inputs_end", "base_commit", "base_product", "base_lib",
                  "candidate_commit", "candidate_product", "candidate_lib", "root_id", "root_affinity", "plan_guid")) {
    if (is.null(s[[field]])) {
      fail("session field missing", field)
      s[[field]] <- NA_character_
    }
  }
  for (field in c("disposition_role", "disposition_ref")) if (is.null(s[[field]])) s[[field]] <- "none"
  if (!identical(s$protocol, protocol$id)) fail("protocol changed", sprintf("record ran protocol %s", s$protocol))
  if (!identical(s$status, "complete")) fail("attempt status", sprintf("%s: %s", s$status, s$status_reason))
  if (!identical(s$attempt, "1")) {
    if (s$disposition %in% c("none", "", NA) || !s$disposition_role %in% c("maintainer", "agent")) {
      fail("disposition", sprintf("attempt %s has no recorded disposition with an author role", s$attempt))
    } else if (!aa && (s$disposition_role != "maintainer" || s$disposition_ref %in% c("none", "", NA))) {
      fail("disposition", sprintf("gate attempt %s needs a maintainer disposition with a decision reference (role %s, ref %s)",
        s$attempt, s$disposition_role, s$disposition_ref))
    }
  }
  if (!identical(s$test_hook, "none")) fail("test hook", s$test_hook)
  if (!identical(s$host_policy, "enforce")) fail("host policy", sprintf("host checks were %s, not enforced", s$host_policy))
  if (!identical(s$inputs_start, "verified")) fail("inputs changed", sprintf("at start: %s", s$inputs_start))
  if (!identical(s$inputs_end, "verified")) fail("inputs changed", sprintf("at end: %s", s$inputs_end))
  same_tree <- identical(s$base_commit, s$candidate_commit) || identical(s$base_product, s$candidate_product)
  if (aa && !(same_tree && identical(s$mode, "aa"))) fail("not an A/A record", "--aa needs both arms on one commit")
  if (!aa && (same_tree || !identical(s$mode, "gate"))) {
    fail("A/A record presented as a gate", sprintf("base %s, candidate %s", s$base_commit, s$candidate_commit))
  }
  if (identical(s$base_lib, s$candidate_lib)) fail("arm identity", "both arms name one library")
  if (!identical(s$plan_guid, timing_plan_guid)) fail("power plan", sprintf("session %s", s$plan_guid))
  if (!identical(s$root_affinity, sprintf("%.0f", timing_affinity))) fail("affinity", sprintf("root %s", s$root_affinity))

  # The saved plan must be the protocol's plan, slot for slot.
  plan <- timing_plan(protocol)
  saved <- timing_read_csv(file.path(record, "plan.csv"))
  if (!identical(names(saved), timing_plan_fields)) {
    fail("plan", sprintf("plan.csv columns %s", paste(names(saved), collapse = ",")))
  } else if (nrow(saved) != nrow(plan) || !isTRUE(all(as.matrix(saved) == as.matrix(format(plan, trim = TRUE))))) {
    fail("plan", sprintf("plan.csv (%d slots) is not the protocol's plan (%d slots)", nrow(saved), nrow(plan)))
  }

  # Rows: every planned slot exactly once, with the plan's assignment.
  raw <- timing_read_csv(file.path(record, "raw.csv"))
  if (!identical(names(raw), timing_raw_fields)) {
    fail("raw columns", paste(names(raw), collapse = ","))
    return(result())
  }
  raw$foreign_r[is.na(raw$foreign_r)] <- ""
  at_plan <- match(raw$slot, as.character(plan$slot))
  for (i in which(is.na(at_plan))) fail("unexpected slot", sprintf("slot %s", raw$slot[[i]]))
  for (sl in unique(raw$slot[duplicated(raw$slot)])) fail("duplicate slot", sprintf("slot %s", sl))
  for (sl in setdiff(as.character(plan$slot), raw$slot)) fail("missing slot", sprintf("slot %s", sl))
  assigned <- paste(plan$pair, plan$cell, plan$arm, sep = "|")[at_plan]
  key <- paste(raw$pair, raw$cell, raw$arm, sep = "|")
  for (i in which(!is.na(at_plan) & assigned != key)) fail("plan", sprintf("slot %s ran %s, planned %s", raw$slot[[i]], key[[i]], assigned[[i]]))
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

  # Host snapshots: one before, one after, one before each executed slot.
  host <- timing_read_csv(file.path(record, "host.csv"))
  if (!identical(names(host), timing_host_fields)) {
    fail("host snapshots", sprintf("host.csv columns %s", paste(names(host), collapse = ",")))
  } else {
    host$foreign_r[is.na(host$foreign_r)] <- ""
    where <- sprintf("host %s slot %s", host$phase, host$slot)
    if (sum(host$phase %in% "before") != 1L || !identical(host$phase[1L], "before")) fail("host snapshots", "not exactly one 'before' snapshot first")
    if (sum(host$phase %in% "after") != 1L || !identical(host$phase[nrow(host)], "after")) fail("host snapshots", "not exactly one 'after' snapshot last")
    for (i in which(!host$phase %in% c("before", "during", "after"))) fail("unexpected snapshot", where[[i]])
    during <- host$slot[host$phase %in% "during"]
    executed <- raw$slot[!raw$outcome %in% "not_run"]
    for (sl in unique(during[duplicated(during)])) fail("duplicate snapshot", sprintf("slot %s", sl))
    for (sl in setdiff(during, as.character(plan$slot))) fail("unexpected snapshot", sprintf("slot %s", sl))
    for (sl in setdiff(executed, during)) fail("missing snapshot", sprintf("before slot %s", sl))
    at <- suppressWarnings(as.numeric(host$at))
    if (any(!is.finite(at) | at < 1e9) || is.unsorted(at)) fail("host snapshots", "snapshot times missing, invalid or out of order")
    launched <- suppressWarnings(as.numeric(raw$launched[match(host$slot, raw$slot)]))
    for (i in which(host$phase %in% "during" & is.finite(launched) & at > launched)) fail("host snapshots", paste(where[[i]], "taken after its slot launched"))
    root_entry <- lapply(host$root_chain, function(ch) timing_parse_chain(ch)[1L, ])
    for (i in seq_len(nrow(host))) {
      e <- root_entry[[i]]
      if (!identical(e$id, s$root_id)) fail("root identity", sprintf("%s chain starts at %s, not the session root %s", where[[i]], e$id, s$root_id))
      if (!isTRUE(e$affinity == timing_affinity)) fail("affinity", paste(where[[i]], "root", e$affinity))
    }
    for (i in which(host$plan_guid != timing_plan_guid | is.na(host$plan_guid))) fail("power plan", where[[i]])
    for (i in which(nzchar(host$foreign_r))) fail("foreign R", paste(where[[i]], host$foreign_r[[i]]))
  }

  # Rows: each measured process.
  r <- raw[ok, , drop = FALSE]
  k <- key[ok]
  secs <- suppressWarnings(as.numeric(r$seconds))
  for (i in which(!is.finite(secs) | secs <= 0)) fail("invalid seconds", sprintf("%s %s", k[[i]], r$seconds[[i]]))
  for (i in which(!r$exit_status %in% "0")) fail("failed execution", sprintf("%s exit %s", k[[i]], r$exit_status[[i]]))
  want_clock <- protocol$cells$clock[match(r$cell, protocol$cells$cell)]
  for (i in which(is.na(r$clock) | r$clock != want_clock)) fail("clock", sprintf("%s clock %s, cell declares %s", k[[i]], r$clock[[i]], want_clock[[i]]))
  for (i in which(is.na(r$work) | !nzchar(trimws(r$work)))) fail("work missing", k[[i]])
  arm_commit <- ifelse(r$arm == "base", s$base_commit, s$candidate_commit)
  arm_lib <- ifelse(r$arm == "base", s$base_lib, s$candidate_lib)
  wrong_arm <- r$ledgr_commit != arm_commit | tolower(dirname(r$ledgr_path)) != tolower(arm_lib)
  for (i in which(is.na(wrong_arm) | wrong_arm)) fail("arm identity", sprintf("%s loaded %s at %s", k[[i]], r$ledgr_path[[i]], r$ledgr_commit[[i]]))
  for (i in which(r$plan_guid != timing_plan_guid | is.na(r$plan_guid))) fail("power plan", sprintf("%s %s", k[[i]], r$plan_guid[[i]]))
  for (i in which(nzchar(r$foreign_r))) fail("foreign R", sprintf("%s %s", k[[i]], r$foreign_r[[i]]))

  # Process identity: the chain starts at this row's process (PID plus
  # creation time) with this row's affinity, the process was created just
  # after the runner launched it, and no identity repeats.
  launched_ms <- 1000 * suppressWarnings(as.numeric(r$launched))
  created <- ifelse(is_count(r$created), suppressWarnings(as.numeric(r$created)), NA_real_)
  identity <- paste0(r$pid, "@", r$created)
  identity_ok <- is_count(r$pid) & !is.na(created) & is.finite(launched_ms) &
    created >= launched_ms - 1000 & created <= launched_ms + 60000 & !duplicated(identity)
  for (i in which(!identity_ok)) {
    fail("process identity", sprintf("%s pid %s created %s launched %s", k[[i]], r$pid[[i]], r$created[[i]], r$launched[[i]]))
  }
  for (i in seq_len(nrow(r))) {
    first <- timing_parse_chain(r$chain[[i]])[1L, ]
    if (!identical(first$id, identity[[i]])) {
      fail("affinity", sprintf("%s chain starts at %s, not the measured process %s", k[[i]], first$id, identity[[i]]))
    } else if (!identical(sprintf("%.0f", first$affinity), r$affinity[[i]]) || !isTRUE(first$affinity == timing_affinity)) {
      fail("affinity", sprintf("%s measured process affinity %s, chain %s", k[[i]], r$affinity[[i]], first$affinity))
    }
    problem <- timing_chain_problem(r$chain[[i]], s$root_id)
    if (nzchar(problem)) fail("affinity", sprintf("%s %s", k[[i]], problem))
  }

  # Executed order, read from the operating system's process creation times
  # of the rows whose identity holds.
  v <- which(identity_ok)
  if (length(v) < nrow(r)) {
    fail("executed order", "order is unproven for rows without a valid process identity")
  }
  if (length(v)) {
    by_created <- order(created[v])
    if (!identical(by_created, order(as.numeric(r$seq[v]))) || !identical(by_created, order(launched_ms[v]))) {
      fail("executed order", "process creation order differs from the runner's launch order")
    }
    position <- integer(length(v))
    position[by_created] <- seq_along(v)
    cell_key <- paste(r$pair[v], r$cell[v], sep = "|")
    for (ck in unique(cell_key)) {
      b <- position[cell_key == ck & r$arm[v] == "base"]
      cn <- position[cell_key == ck & r$arm[v] == "candidate"]
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
    work <- unique(r$work[in_cell & !is.na(r$work)])
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
