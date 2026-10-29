# Shared timing harness (LDG-3155): the gate checker.
#
# Checks one attempt record against a per-cut protocol folder and, in gate
# mode, applies its threshold map: for every cell, the median of the
# candidate's seconds over the median of the base's seconds must be at most
# the cell's bound. One attempt is checked as recorded; nothing is retried,
# dropped or re-paired. Before any ratio counts, the record must be valid:
# the protocol, the attempt and its disposition, the saved inputs against
# the harness commit, the plan and every slot, the host snapshots' coverage
# of the window, each process's identity, affinity and power plan, no other
# process above 1.0 CPU-second per interval, the alternating executed order
# and invariant work. Each section below says what it requires; the manual's
# "Before/After Regression Gates" states the rules. CPU load and the
# foreign-R names are observations and never fail.
#
# --aa checks a self-versus-self record (both arms one commit): validity
# only, with each cell's ratio reported as a noise observation. In gate mode
# an A/A record always fails. Exit status 0 means PASS (gate) or VALID (A/A).
#
# Usage: Rscript dev/bench/timing/check.R --protocol=<folder> --record=<attempt dir> [--aa]

timing_check <- function(protocol_dir, record, aa = FALSE, repo) {
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
                  "harness_commit", "harness_source", "protocol_source", "inputs_start", "inputs_end",
                  "base_commit", "base_product", "base_lib",
                  "candidate_commit", "candidate_product", "candidate_lib", "root_id", "root_affinity", "plan_guid")) {
    if (is.null(s[[field]])) {
      fail("session field missing", field)
      s[[field]] <- NA_character_
    }
  }
  for (field in c("disposition_role", "disposition_ref")) if (is.null(s[[field]])) s[[field]] <- "none"
  if (!identical(s$protocol, protocol$id)) fail("protocol changed", sprintf("record ran protocol %s", s$protocol))
  if (!identical(s$status, "complete")) fail("attempt status", sprintf("%s: %s", s$status, s$status_reason))
  blank <- function(x) is.na(x) || !nzchar(trimws(x)) || identical(trimws(x), "none")
  if (!identical(s$attempt, "1")) {
    if (blank(s$disposition) || !s$disposition_role %in% c("maintainer", "agent")) {
      fail("disposition", sprintf("attempt %s has no recorded disposition with an author role", s$attempt))
    } else if (!aa && (s$disposition_role != "maintainer" || blank(s$disposition_ref))) {
      fail("disposition", sprintf("gate attempt %s needs a maintainer disposition with a decision reference (role %s, ref %s)",
        s$attempt, s$disposition_role, s$disposition_ref))
    }
  }
  if (!identical(s$test_hook, "none")) fail("test hook", s$test_hook)
  if (!identical(s$host_policy, "enforce")) fail("host policy", sprintf("host checks were %s, not enforced", s$host_policy))
  if (!identical(s$inputs_start, "verified")) fail("inputs changed", sprintf("at start: %s", s$inputs_start))
  if (!identical(s$inputs_end, "verified")) fail("inputs changed", sprintf("at end: %s", s$inputs_end))
  # The saved copies themselves, compared with the recorded commit here and
  # now, so a copy changed after the runner finished is still caught.
  commit_found <- is.null(attr(suppressWarnings(system2("git", c("-C", shQuote(repo), "cat-file", "-e",
    paste0(s$harness_commit, "^{commit}")), stdout = TRUE, stderr = TRUE)), "status"))
  saved <- if (!commit_found) sprintf("harness commit %s is not available", s$harness_commit) else
    timing_verify_inputs(repo, s$harness_commit, timing_input_files(file.path(record, "harness"), file.path(record, "protocol")),
      timing_input_sources(s$harness_source, s$protocol_source))
  if (saved != "verified") fail("inputs changed", sprintf("saved copies: %s", saved))
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
  at_plan <-match(raw$slot, as.character(plan$slot))
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

  # The executed timeline in the runner's launch sequence: each executed
  # slot's launch and the later of its launch and its process creation.
  ex <- raw[!raw$outcome %in% "not_run", , drop = FALSE]
  ex <- ex[order(suppressWarnings(as.numeric(ex$seq))), , drop = FALSE]
  ex_launch <- suppressWarnings(as.numeric(ex$launched))
  ex_end <- pmax(ex_launch, suppressWarnings(as.numeric(ex$created)) / 1000, na.rm = TRUE)
  after_at <- NA_real_

  # Host snapshots: one before the first launch, one before each executed
  # slot (after the previous slot's launch and creation), one after the last.
  host <- timing_read_csv(file.path(record, "host.csv"))
  if (!identical(names(host), timing_host_fields)) {
    fail("host snapshots", sprintf("host.csv columns %s", paste(names(host), collapse = ",")))
  } else {
    where <-sprintf("host %s slot %s", host$phase, host$slot)
    if (sum(host$phase %in% "before") != 1L || !identical(host$phase[1L], "before")) fail("host snapshots", "not exactly one 'before' snapshot first")
    if (sum(host$phase %in% "after") != 1L || !identical(host$phase[nrow(host)], "after")) fail("host snapshots", "not exactly one 'after' snapshot last")
    for (i in which(!host$phase %in% c("before", "during", "after"))) fail("unexpected snapshot", where[[i]])
    for (i in which(host$phase %in% c("before", "after") & !is.na(host$slot))) fail("unexpected snapshot", paste(where[[i]], "names a slot"))
    during <- host$slot[host$phase %in% "during"]
    executed <- raw$slot[!raw$outcome %in% "not_run"]
    for (sl in unique(during[duplicated(during)])) fail("duplicate snapshot", sprintf("slot %s", sl))
    for (sl in setdiff(during, as.character(plan$slot))) fail("unexpected snapshot", sprintf("slot %s", sl))
    for (sl in setdiff(executed, during)) fail("missing snapshot", sprintf("before slot %s", sl))
    at <- suppressWarnings(as.numeric(host$at))
    if (any(!is.finite(at) | at < 1e9) || is.unsorted(at)) fail("host snapshots", "snapshot times missing, invalid or out of order")
    after_at <- at[host$phase %in% "after"][1L]
    if (nrow(ex)) {
      d_slot <- host$slot[host$phase %in% "during"]
      if (!identical(d_slot[d_slot %in% ex$slot], ex$slot)) fail("host snapshots", "pre-slot snapshots are not in execution order")
      d_at <- at[host$phase %in% "during"][match(ex$slot, d_slot)]
      prev_end <- c(-Inf, ex_end[-nrow(ex)])
      for (i in which(is.finite(d_at) & ((is.finite(ex_launch) & d_at > ex_launch) | d_at < prev_end))) {
        fail("host snapshots", sprintf("snapshot before slot %s at %.3f is outside its window (%.3f to %.3f)",
          ex$slot[[i]], d_at[[i]], prev_end[[i]], ex_launch[[i]]))
      }
      if (isTRUE(at[host$phase %in% "before"][1L] > ex_launch[1L])) fail("host snapshots", "the 'before' snapshot follows the first launch")
      if (!isTRUE(after_at >= max(ex_end, na.rm = TRUE))) fail("host snapshots", "the 'after' snapshot precedes the last launch or creation")
    }
    root_entry <- lapply(host$root_chain, function(ch) timing_parse_chain(ch)[1L, ])
    for (i in seq_len(nrow(host))) {
      e <- root_entry[[i]]
      if (!identical(e$id, s$root_id)) fail("root identity", sprintf("%s chain starts at %s, not the session root %s", where[[i]], e$id, s$root_id))
      if (!isTRUE(e$affinity == timing_affinity)) fail("affinity", paste(where[[i]], "root", e$affinity))
    }
    for (i in which(host$plan_guid != timing_plan_guid | is.na(host$plan_guid))) fail("power plan", where[[i]])
    # Busy processes: every snapshot after the first records the largest CPU
    # increase of any process outside the measured chain since the previous one.
    cpu <- suppressWarnings(as.numeric(host$cpu_max_ms))
    for (i in which(host$phase != "before" & !is.finite(cpu))) fail("host snapshots", paste(where[[i]], "has no CPU interval"))
    for (i in which(cpu > timing_cpu_limit_ms)) fail("busy process", sprintf("%s +%.0f ms: %s", where[[i]], cpu[[i]], host$cpu_top[[i]]))
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
  # Process identity: the chain starts at this row's process (PID plus
  # creation time) with this row's affinity, no identity repeats, and the
  # process was created inside its own slot: no earlier than the runner's
  # launch time and no later than the next launch (or, for the last slot,
  # the 'after' snapshot). The launch time is a sub-millisecond R clock read;
  # the creation time is floored to whole milliseconds, so a creation in the
  # launch's own millisecond can read below it. The allowance is that
  # flooring plus one millisecond of clock granularity, nothing more.
  launched_ms <- 1000 * suppressWarnings(as.numeric(r$launched))
  created <- ifelse(is_count(r$created), suppressWarnings(as.numeric(r$created)), NA_real_)
  next_bound <- 1000 * c(ex_launch[-1L], after_at)[match(r$slot, ex$slot)]
  identity <- paste0(r$pid, "@", r$created)
  identity_ok <- is_count(r$pid) & !is.na(created) & is.finite(launched_ms) & created >= floor(launched_ms) - 1 &
    is.finite(next_bound) & created <= next_bound & !duplicated(identity)
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

timing_check_main <- function(here) {
  opt <- timing_args()
  if (!is.character(opt("protocol")) || !is.character(opt("record"))) {
    stop("usage: check.R --protocol=<folder> --record=<attempt dir> [--aa]", call. = FALSE)
  }
  aa <- isTRUE(opt("aa"))
  res <- timing_check(opt("protocol"), opt("record"), aa = aa,
    repo = normalizePath(file.path(here, "..", "..", ".."), winslash = "/"))
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
  quit(save = "no", status = timing_check_main(here))
}
