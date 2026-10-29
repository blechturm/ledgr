# Shared timing harness (LDG-3155): checker demonstrations.
#
# Builds one clean synthetic gate record for protocol smoke-1 (two cells,
# eight pairs, distinct base and candidate commits, every host field on the
# registered settings, the harness files frozen beside it), then one
# corrupted copy per case. Each record is checked by a fresh
# `Rscript check.R` process, and its real exit status and failure reasons
# are compared with the case's expectation. The controls (the clean gate
# record, the A/A record under --aa, and a later gate attempt under a
# maintainer disposition) must exit 0, so the failing cases are not vacuous.
# The interrupted record that runner.R wrote is checked as well, and two
# cases exercise attempt allocation (protocol.R) directly.
#
# Writes demo/check_demo_results.csv. Exits 1 if any case behaves otherwise.
#
# Usage: Rscript dev/bench/timing/demo/check_demo.R

here <- normalizePath(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]])),
  winslash = "/")
harness <- dirname(here)
source(file.path(harness, "host.R"))
source(file.path(harness, "protocol.R"))
protocol_dir <- file.path(harness, "protocols", "smoke-1")
protocol <- timing_read_protocol(protocol_dir)
work <- file.path(tempdir(), "check_demo")
interrupted <- file.path(harness, "records", "smoke-1", "interrupt-demo", "attempt-2")

root_id <- "1000@1700000000000"
commit <- c(base = strrep("b", 40), candidate = strrep("c", 40))
lib <- c(base = "C:/demo/arm_base/lib", candidate = "C:/demo/arm_candidate/lib")

# A clean gate record. `ratio` sets each cell's candidate/base median ratio;
# `alternate = FALSE` runs base first in every pair, as a runner that never
# alternated would, with every self-report consistent with that order.
make_record <- function(dir, ratio = c(small_cold = 1.02, small_warm = 0.96), alternate = TRUE) {
  dir.create(file.path(dir, "protocol"), recursive = TRUE)
  dir.create(file.path(dir, "harness"))
  file.copy(file.path(protocol_dir, timing_protocol_files), file.path(dir, "protocol"))
  file.copy(file.path(harness, timing_harness_files), file.path(dir, "harness"))
  timing_write_kv(list(protocol = protocol$id, label = "demo", attempt = "1", mode = "gate", host_policy = "enforce",
    test_hook = "none", disposition = "none", disposition_role = "none", disposition_ref = "none",
    status = "complete", status_reason = "", started_utc = "2023-11-14T22:13:20Z", finished_utc = "2023-11-14T22:23:20Z",
    harness_commit = strrep("a", 40), inputs_start = "verified", inputs_end = "verified",
    base_commit = commit[["base"]], base_product = "R=1;src=1;DESCRIPTION=1;NAMESPACE=1", base_lib = lib[["base"]],
    candidate_commit = commit[["candidate"]], candidate_product = "R=2;src=1;DESCRIPTION=1;NAMESPACE=1",
    candidate_lib = lib[["candidate"]], root_id = root_id, root_affinity = "65535", plan_guid = timing_plan_guid,
    cpu = "demo", logical_cores = "24", R_version = R.version.string, os = "demo", dependencies = "demo"),
    file.path(dir, "session.csv"))
  plan <- timing_plan(protocol)
  utils::write.csv(plan, file.path(dir, "plan.csv"), row.names = FALSE)

  run <- plan
  if (!alternate) {
    even <- which(run$pair %% 2L == 0L)
    swap <- even + ifelse(seq_along(even) %% 2L == 1L, 1L, -1L)
    run <- plan[replace(seq_len(nrow(plan)), even, swap), ]
  }
  n <- nrow(run)
  launched <- 1700000000 + 10 * seq_len(n)
  created <- launched * 1000 + 50
  pid <- 2000 + seq_len(n)
  base_secs <- 1 + 0.01 * (run$pair %% 3L)
  secs <- ifelse(run$arm == "base", base_secs, base_secs * ratio[run$cell])
  raw <- data.frame(seq = seq_len(n), slot = run$slot, pair = run$pair, cell = run$cell, arm = run$arm,
    clock = protocol$cells$clock[match(run$cell, protocol$cells$cell)], seconds = sprintf("%.17g", secs),
    outcome = "ok", error = NA, work = "1240;1240", launched = sprintf("%.6f", launched), pid = pid,
    created = sprintf("%.0f", created), affinity = "65535",
    chain = sprintf("%d@%.0f=65535;%s=65535", pid, created, root_id), foreign_r = "", plan_guid = timing_plan_guid,
    ledgr_path = paste0(lib[run$arm], "/ledgr"), ledgr_commit = commit[run$arm], exit_status = "0")
  utils::write.csv(raw, file.path(dir, "raw.csv"), row.names = FALSE)
  host <- data.frame(phase = c("before", rep("during", n), "after"), slot = c(NA, run$slot, NA),
    at = sprintf("%.6f", c(1700000000, launched - 1, launched[n] + 10)), plan_guid = timing_plan_guid, cpu_percent = 3,
    root_chain = paste0(root_id, "=65535;900@1699999990000=65535"), foreign_r = "")
  utils::write.csv(host, file.path(dir, "host.csv"), row.names = FALSE)
}

# Edits one record file in place.
edit <- function(dir, file, f) {
  path <- file.path(dir, file)
  d <- if (file == "session.csv") timing_read_kv(path) else timing_read_csv(path)
  d <- f(d)
  if (file == "session.csv") timing_write_kv(d, path) else utils::write.csv(d, path, row.names = FALSE)
}

# A protocol folder variant in the work directory, named like the original.
variant <- function(name, file, f) {
  dir <- file.path(work, "protocols", name, protocol$id)
  dir.create(dir, recursive = TRUE)
  file.copy(file.path(protocol_dir, timing_protocol_files), dir)
  utils::write.csv(f(timing_read_csv(file.path(dir, file))), file.path(dir, file), row.names = FALSE)
  dir
}

# A mocked host.ps1 snapshot in which the measured PID was reused between
# the CIM and Get-Process enumerations: CIM lists the process created at
# `created`, but the affinity came from a process object created later.
pid_reuse_chain <- function(pid, created) {
  out <- c(sprintf("host,%s,3,demo", timing_plan_guid),
    "proc,900,4,1699999990000,65535,1699999990000,powershell.exe",
    "proc,1000,900,1700000000000,65535,1700000000000,Rscript.exe",
    sprintf("proc,%s,1000,%s,65535,%.0f,Rscript.exe", pid, created, as.numeric(created) + 2500))
  probe <- timing_parse_probe(out, at = 1700000000)
  timing_chain(probe$procs, as.numeric(pid))
}

later_attempt <- function(role, ref) {
  list("session.csv", function(s) {
    s[c("attempt", "disposition", "disposition_role", "disposition_ref")] <- list("2", "attempt 1 host departure", role, ref)
    s
  })
}

cases <- list(
  list(case = "control", shows = "a clean gate record passes", exit = 0L),
  list(case = "ratio_0.98_on_0.97", shows = "0.98 on a 0.97 cell", exit = 1L, reason = "ratio above bound",
    ratio = c(small_cold = 1.02, small_warm = 0.98)),
  list(case = "ratio_1.031_on_1.03", shows = "1.031 on a 1.03 cell", exit = 1L, reason = "ratio above bound",
    ratio = c(small_cold = 1.031, small_warm = 0.96)),
  list(case = "missing_cell", shows = "a missing cell", exit = 1L, reason = "missing cell",
    edit = list("raw.csv", function(d) d[d$cell != "small_warm", ])),
  list(case = "duplicate_row", shows = "a duplicate row", exit = 1L, reason = "duplicate row",
    edit = list("raw.csv", function(d) rbind(d, d[5L, ]))),
  list(case = "fewer_pairs", shows = "fewer pairs than the protocol states", exit = 1L, reason = "fewer pairs",
    edit = list("raw.csv", function(d) d[d$pair != "8", ])),
  list(case = "non_alternating", shows = "a non-alternating executed order", exit = 1L, reason = "executed order",
    alternate = FALSE),
  list(case = "wrong_power_plan", shows = "a wrong power plan in one measured process", exit = 1L,
    reason = "power plan",
    edit = list("raw.csv", function(d) { d$plan_guid[7L] <- "381b4222-f694-41f0-9685-ff5bb260df2e"; d })),
  list(case = "descendant_affinity", shows = "wrong affinity on a descendant between a measured process and the root",
    exit = 1L, reason = "affinity",
    edit = list("raw.csv", function(d) {
      d$chain[9L] <- sub(";", ";1500@1700000000500=16777215;", d$chain[9L], fixed = TRUE)
      d
    })),
  list(case = "foreign_r", shows = "a foreign R process seen by a measured process", exit = 1L, reason = "foreign R",
    edit = list("raw.csv", function(d) { d$foreign_r[11L] <- "ark.exe:27816@1792959389346"; d })),
  list(case = "aa_as_gate", shows = "an A/A record presented as a gate", exit = 1L,
    reason = "A/A record presented as a gate", same_commit = TRUE),
  list(case = "aa_control", shows = "the same A/A record checked with --aa is valid", exit = 0L, same_commit = TRUE,
    aa = TRUE),
  list(case = "protocol_pairs_7", shows = "a protocol stating fewer than eight pairs", exit = 1L, reason = "protocol",
    protocol = function() variant("pairs_7", "matrix.csv", function(d) { d$pairs <- "7"; d })),
  list(case = "threshold_map_omits_cell", shows = "a threshold map that omits a cell", exit = 1L, reason = "protocol",
    protocol = function() variant("omits_cell", "thresholds.csv", function(d) d[d$cell != "small_warm", ])),
  # Round 1 (ldg3155_harness_review.md).
  list(case = "F1_empty_host", shows = "a host file with only its header", exit = 1L, reason = "missing snapshot",
    edit = list("host.csv", function(d) d[0L, ])),
  list(case = "F1_missing_pre_slot_probe", shows = "one executed slot without its pre-slot snapshot", exit = 1L,
    reason = "missing snapshot", edit = list("host.csv", function(d) d[-6L, ])),
  list(case = "F1_empty_saved_plan", shows = "a saved plan with only its header", exit = 1L, reason = "plan",
    edit = list("plan.csv", function(d) d[0L, ])),
  list(case = "F2_root_only_chain", shows = "a row with affinity 16777215 whose chain holds only the pinned root",
    exit = 1L, reason = "affinity",
    edit = list("raw.csv", function(d) { d$affinity[3L] <- "16777215"; d$chain[3L] <- paste0(root_id, "=65535"); d })),
  list(case = "F2_contradictory_affinity", shows = "a raw affinity that contradicts the chain's first entry", exit = 1L,
    reason = "affinity", edit = list("raw.csv", function(d) { d$affinity[4L] <- "16777215"; d })),
  list(case = "F2_different_child", shows = "a chain that starts at a different process", exit = 1L, reason = "affinity",
    edit = list("raw.csv", function(d) { d$chain[5L] <- sub("^[0-9]+@", "4242@", d$chain[5L]); d })),
  list(case = "F5_pid_reuse_mock", shows = "an affinity read from a process that reused the measured PID", exit = 1L,
    reason = "affinity",
    edit = list("raw.csv", function(d) {
      d$chain[6L] <- pid_reuse_chain(d$pid[6L], d$created[6L])
      d$affinity[6L] <- sprintf("%.0f", timing_parse_chain(d$chain[6L])$affinity[1L])
      d
    })),
  list(case = "F6_pairs_8.9", shows = "a protocol stating 8.9 pairs", exit = 1L, reason = "protocol",
    protocol = function() variant("pairs_8.9", "matrix.csv", function(d) { d$pairs <- "8.9"; d })),
  list(case = "F6_all_na_work", shows = "every work string missing", exit = 1L, reason = "work missing",
    edit = list("raw.csv", function(d) { d$work <- NA; d })),
  list(case = "disposition_agent_gate", shows = "a later gate attempt under an agent-authored disposition", exit = 1L,
    reason = "disposition", edit = later_attempt("agent", "none")),
  list(case = "disposition_maintainer_control", shows = "a later gate attempt under a maintainer disposition passes",
    exit = 0L, edit = later_attempt("maintainer", "tickets.yml LDG-0000 disposition 1")),
  list(case = "interrupted_record", shows = "the runner's interrupted attempt (killed child, unrun slots)", exit = 1L,
    reason = "unrun slot", record = interrupted, aa = TRUE)
)

rscript <- file.path(R.home("bin"), "Rscript")
results <- do.call(rbind, lapply(cases, function(x) {
  record <- if (is.null(x$record)) file.path(work, x$case) else x$record
  if (is.null(x$record)) {
    make_record(record, ratio = if (is.null(x$ratio)) c(small_cold = 1.02, small_warm = 0.96) else x$ratio,
      alternate = !identical(x$alternate, FALSE))
    if (isTRUE(x[["same_commit"]])) {
      edit(record, "session.csv", function(s) {
        s[c("mode", "candidate_commit", "candidate_product")] <- list("aa", s$base_commit, s$base_product)
        s
      })
      edit(record, "raw.csv", function(d) { d$ledgr_commit <- commit[["base"]]; d })
    }
    if (!is.null(x$edit)) edit(record, x$edit[[1L]], x$edit[[2L]])
  }
  proto <- if (is.null(x$protocol)) protocol_dir else x$protocol()
  out <- suppressWarnings(system2(rscript, c("--no-init-file", shQuote(file.path(harness, "check.R")),
    shQuote(paste0("--protocol=", proto)), shQuote(paste0("--record=", record)), if (isTRUE(x[["aa"]])) "--aa"),
    stdout = TRUE, stderr = TRUE))
  status <- if (is.null(attr(out, "status"))) 0L else as.integer(attr(out, "status"))
  found <- unique(sub("^  ([^:]+):.*$", "\\1", grep("^  [^ :][^:]*:", out, value = TRUE)))
  want <- if (is.null(x$reason)) "" else x$reason
  data.frame(case = x$case, demonstrates = x$shows, expected_exit = x$exit, exit = status, expected_reason = want,
    reasons_found = paste(found, collapse = "; "),
    as_expected = status == x$exit && (!nzchar(want) || want %in% found), stringsAsFactors = FALSE)
}))

# F4: attempt allocation, exercised directly. A label holding only attempt-2
# gets attempt-3 and attempt-2 is untouched; an occupied destination is
# refused before anything is written into it.
label <- file.path(work, "alloc", "label")
dir.create(file.path(label, "attempt-2"), recursive = TRUE)
writeLines("kept", file.path(label, "attempt-2", "session.csv"))
made <- tryCatch(basename(timing_new_attempt(label)), error = function(e) conditionMessage(e))
kept <- identical(readLines(file.path(label, "attempt-2", "session.csv")), "kept") &&
  identical(list.files(file.path(label, "attempt-2")), "session.csv")
refused <- tryCatch({ timing_create_attempt(file.path(label, "attempt-2")); "created" }, error = function(e) conditionMessage(e))
results <- rbind(results,
  data.frame(case = "F4_noncontiguous_attempt", demonstrates = "a label holding only attempt-2 allocates attempt-3 and keeps attempt-2",
    expected_exit = NA, exit = NA, expected_reason = "attempt-3", reasons_found = sprintf("%s; attempt-2 kept %s", made, kept),
    as_expected = identical(made, "attempt-3") && kept, stringsAsFactors = FALSE),
  data.frame(case = "F4_occupied_destination", demonstrates = "creating an attempt directory that already exists is refused",
    expected_exit = NA, exit = NA, expected_reason = "already exists", reasons_found = refused,
    as_expected = grepl("already exists", refused) && kept, stringsAsFactors = FALSE))

utils::write.csv(results, file.path(here, "check_demo_results.csv"), row.names = FALSE, fileEncoding = "UTF-8")
print(results[c("case", "exit", "expected_exit", "reasons_found", "as_expected")], row.names = FALSE, right = FALSE)
quit(save = "no", status = if (all(results$as_expected)) 0L else 1L)
